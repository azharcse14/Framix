// Method channel `framix/media` (P1-011): the system pickers plus the metadata the engine
// needs. Picked files are stored in Application Support/media and reported as the relative
// path `media/<uuid>.<ext>` (the container path changes between installs). The engine
// validates every field; nothing here decides what is allowed.
import AVFoundation
import Flutter
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

@MainActor
final class MediaPicker: NSObject {
  private static var shared: MediaPicker?
  private var pending: FlutterResult?

  static func register(with registrar: FlutterApplicationRegistrar) {
    let picker = MediaPicker()
    shared = picker
    let channel = FlutterMethodChannel(
      name: "framix/media", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      MainActor.assumeIsolated { picker.handle(call, result) }
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "pickGallery" || call.method == "pickFiles" else {
      return result(FlutterMethodNotImplemented)
    }
    guard pending == nil, let presenter = Self.topViewController() else {
      return result(FlutterError(code: "busy", message: nil, details: nil))
    }
    pending = result
    if call.method == "pickGallery" {
      var config = PHPickerConfiguration()
      config.selectionLimit = 0
      config.selection = .ordered
      config.filter = .any(of: [.images, .videos])
      config.preferredAssetRepresentationMode = .current
      let picker = PHPickerViewController(configuration: config)
      picker.delegate = self
      presenter.present(picker, animated: true)
    } else {
      let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.movie, .image], asCopy: true)
      picker.allowsMultipleSelection = true
      picker.delegate = self
      presenter.present(picker, animated: true)
    }
  }

  private func finish(_ items: [[String: Any]]) {
    pending?(items)
    pending = nil
  }

  /// Probes stored files in pick order; files the probe can't read are deleted and skipped.
  private func probeAndFinish(_ stored: [Stored]) {
    Task {
      var items: [[String: Any]] = []
      for file in stored {
        if let item = await Self.probe(file) {
          items.append(item)
        } else {
          try? FileManager.default.removeItem(at: file.url)
        }
      }
      finish(items)
    }
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    var top = scene?.keyWindow?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  /// A picked file stored in the app's media folder.
  struct Stored: Sendable {
    let relative: String
    let url: URL
    let isVideo: Bool
  }

  /// Copies (or moves) `source` into Application Support/media under a fresh name.
  nonisolated static func store(_ source: URL, isVideo: Bool, move: Bool) throws -> Stored {
    let manager = FileManager.default
    let dir = try manager.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    ).appendingPathComponent("media", isDirectory: true)
    try manager.createDirectory(at: dir, withIntermediateDirectories: true)
    let ext = source.pathExtension.lowercased()
    let safeExt =
      (1...5).contains(ext.count) && ext.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
      ? ext : "bin"
    let name = "\(UUID().uuidString.lowercased()).\(safeExt)"
    let dest = dir.appendingPathComponent(name)
    if move {
      try manager.moveItem(at: source, to: dest)
    } else {
      try manager.copyItem(at: source, to: dest)
    }
    return Stored(relative: "media/\(name)", url: dest, isVideo: isVideo)
  }

  nonisolated static func probe(_ file: Stored) async -> [String: Any]? {
    if file.isVideo {
      let asset = AVURLAsset(url: file.url)
      guard let duration = try? await asset.load(.duration),
        let track = try? await asset.loadTracks(withMediaType: .video).first,
        let (size, transform, formats) = try? await track.load(
          .naturalSize, .preferredTransform, .formatDescriptions)
      else { return nil }
      let degrees = Int((atan2(transform.b, transform.a) * 180 / .pi).rounded())
      let codec = formats.first.map { fourCC(CMFormatDescriptionGetMediaSubType($0)) } ?? ""
      return [
        "uri": file.relative, "kind": "video",
        "durationValue": Int(duration.value), "durationTimescale": Int(duration.timescale),
        "width": Int(abs(size.width)), "height": Int(abs(size.height)),
        "rotation": (degrees % 360 + 360) % 360, "codec": codec,
      ]
    }
    guard let source = CGImageSourceCreateWithURL(file.url as CFURL, nil),
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = props[kCGImagePropertyPixelWidth] as? Int,
      let height = props[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    // EXIF orientation to clockwise degrees (mirrored variants keep their rotation).
    let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
    let rotation = [3: 180, 4: 180, 5: 90, 6: 90, 7: 270, 8: 270][orientation] ?? 0
    return [
      "uri": file.relative, "kind": "image", "durationValue": 0, "durationTimescale": 0,
      "width": width, "height": height, "rotation": rotation, "codec": "",
    ]
  }

  nonisolated static func fourCC(_ code: FourCharCode) -> String {
    let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
    return String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""
  }
}

/// Collects stored files from concurrent provider callbacks, keeping pick order.
private final class StoredSlots: @unchecked Sendable {
  // @unchecked: every access goes through `lock`.
  private let lock = NSLock()
  private var slots: [MediaPicker.Stored?]

  init(count: Int) { slots = Array(repeating: nil, count: count) }

  func set(_ index: Int, _ value: MediaPicker.Stored) {
    lock.lock()
    slots[index] = value
    lock.unlock()
  }

  func inOrder() -> [MediaPicker.Stored] {
    lock.lock()
    defer { lock.unlock() }
    return slots.compactMap { $0 }
  }
}

extension MediaPicker: PHPickerViewControllerDelegate {
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    let slots = StoredSlots(count: results.count)
    let group = DispatchGroup()
    for (index, result) in results.enumerated() {
      let provider = result.itemProvider
      let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
      group.enter()
      // The temp file is deleted when this callback returns, so store it inside.
      _ = provider.loadFileRepresentation(for: isVideo ? .movie : .image) { url, _, _ in
        defer { group.leave() }
        if let url, let stored = try? MediaPicker.store(url, isVideo: isVideo, move: false) {
          slots.set(index, stored)
        }
      }
    }
    group.notify(queue: .main) {
      MainActor.assumeIsolated { self.probeAndFinish(slots.inOrder()) }
    }
  }
}

extension MediaPicker: UIDocumentPickerDelegate {
  func documentPicker(
    _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
  ) {
    let stored = urls.compactMap { url -> Stored? in
      let isVideo = UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) ?? false
      // asCopy gave us our own copy, so move it instead of copying again.
      return try? Self.store(url, isVideo: isVideo, move: true)
    }
    probeAndFinish(stored)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish([])
  }
}

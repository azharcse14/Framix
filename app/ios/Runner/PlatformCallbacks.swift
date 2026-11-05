// The callbacks only iOS can serve, registered into the engine at startup
// (docs/adr/0003-platform-callbacks.md). Thin adapter: the engine decides what to draw and when.
import AVFoundation
import CoreVideo
import Flutter
import IOSurface
import ImageIO
import Metal
import UniformTypeIdentifiers

/// A Flutter texture whose CVPixelBuffer shares one IOSurface with the Metal texture the engine
/// (wgpu) renders into, so Flutter samples exactly the bytes the GPU wrote.
final class PreviewTexture: NSObject, FlutterTexture, @unchecked Sendable {
  // @unchecked: both fields are immutable after init; copyPixelBuffer runs on the raster thread.
  let pixelBuffer: CVPixelBuffer
  let metalTexture: MTLTexture

  init?(device: MTLDevice, width: Int, height: Int) {
    let attributes: [CFString: Any] = [
      kCVPixelBufferMetalCompatibilityKey: true,
      kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any](),
    ]
    var buffer: CVPixelBuffer?
    guard
      CVPixelBufferCreate(
        kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
        attributes as CFDictionary, &buffer) == kCVReturnSuccess,
      let buffer,
      let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue()
    else { return nil }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    guard
      let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0)
    else { return nil }
    pixelBuffer = buffer
    metalTexture = texture
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    .passRetained(pixelBuffer)
  }
}

/// Fills the engine's `EnginePlatform` vtable. The engine calls it on its own thread; every
/// callback hops to the main queue and returns at once.
@MainActor
enum PlatformCallbacks {
  private static var registry: FlutterTextureRegistry?
  /// Textures the engine holds, until it releases them.
  private static var textures: [Int64: PreviewTexture] = [:]

  /// Registers with the engine library Dart loads (same image, so the same registration).
  static func register(with registrar: FlutterApplicationRegistrar) {
    registry = registrar.textures()
    typealias Register = @convention(c) (UnsafePointer<EnginePlatform>?) -> Int32
    guard
      let frameworks = Bundle.main.privateFrameworksPath,
      let library = dlopen("\(frameworks)/framix_ffi.framework/framix_ffi", RTLD_NOW),
      let symbol = dlsym(library, "engine_platform_register")
    else {
      return assertionFailure("engine library or engine_platform_register not found")
    }
    var platform = EnginePlatform(
      version: UInt32(ENGINE_PLATFORM_VERSION), ctx: nil,
      create_preview_texture: createPreviewTexture, frame_available: frameAvailable,
      request_thumbnail: requestThumbnail, encoder_open: encoderOpen,
      encoder_frame: encoderFrame, encoder_finish: encoderFinish, decoder_open: decoderOpen,
      decoder_frame: decoderFrame, decoder_close: decoderClose, request_proxy: requestProxy,
      free_bytes: freeBytes, release_preview_texture: releasePreviewTexture)
    let code = unsafeBitCast(symbol, to: Register.self)(&platform)
    assert(code == ENGINE_OK, "engine_platform_register failed: \(code)")
  }

  /// Answers `done` exactly once: OK with the texture, or a failure status.
  fileprivate static func makeTexture(
    width: Int, height: Int, done: EnginePreviewTextureDone, doneCtx: UnsafeMutableRawPointer?
  ) {
    guard
      let registry, let device = MTLCreateSystemDefaultDevice(),
      let texture = PreviewTexture(device: device, width: width, height: height)
    else { return done(doneCtx, ENGINE_ERR_GPU, 0, nil) }
    let id = registry.register(texture)
    textures[id] = texture
    done(doneCtx, ENGINE_OK, id, Unmanaged.passUnretained(texture.metalTexture).toOpaque())
  }

  fileprivate static func markFrameAvailable(_ id: Int64) {
    registry?.textureFrameAvailable(id)
  }

  /// The engine no longer draws into texture `id`: Flutter forgets it and its IOSurface goes.
  fileprivate static func releaseTexture(_ id: Int64) {
    guard let texture = textures.removeValue(forKey: id) else { return }
    // Flutter forgets it before it can be freed.
    withExtendedLifetime(texture) { registry?.unregisterTexture(id) }
  }
}

// C callbacks capture nothing; pointers cross to the main queue as integers.
private let createPreviewTexture:
  @convention(c) (
    UnsafeMutableRawPointer?, UInt32, UInt32, EnginePreviewTextureDone?, UnsafeMutableRawPointer?
  ) -> Void = { _, width, height, done, doneCtx in
    guard let done else { return }
    let ctx = UInt(bitPattern: doneCtx)
    DispatchQueue.main.async {
      MainActor.assumeIsolated {
        PlatformCallbacks.makeTexture(
          width: Int(width), height: Int(height), done: done,
          doneCtx: UnsafeMutableRawPointer(bitPattern: ctx))
      }
    }
  }

/// Thumbnail requests arrive on the engine thread; the work runs detached and answers `done`
/// exactly once from there.
private let requestThumbnail:
  @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<UInt8>?, Int, UInt32, Int64, UInt32,
    EngineThumbnailDone?, UnsafeMutableRawPointer?
  ) -> Void = { _, uri, uriLength, kind, timeUs, maxSide, done, doneCtx in
    guard let done else { return }
    guard let uri,
      let reference = String(
        bytes: UnsafeBufferPointer(start: uri, count: uriLength), encoding: .utf8)
    else { return done(doneCtx, ENGINE_ERR_GPU, nil, 0) }
    let ctx = UInt(bitPattern: doneCtx)
    let image = kind == UInt32(ENGINE_MEDIA_IMAGE)
    Task.detached(priority: .utility) {
      let path = try? await Thumbnails.file(
        for: reference, image: image, timeUs: timeUs, maxSide: Int(maxSide))
      let doneCtx = UnsafeMutableRawPointer(bitPattern: ctx)
      guard let path else { return done(doneCtx, ENGINE_ERR_GPU, nil, 0) }
      var bytes = Array(path.utf8)
      bytes.withUnsafeMutableBufferPointer { buffer in
        done(doneCtx, ENGINE_OK, buffer.baseAddress, buffer.count)
      }
    }
  }

/// Thumbnail files in Caches/thumbs, named by the media reference, time and size.
enum Thumbnails {
  static func file(for reference: String, image: Bool, timeUs: Int64, maxSide: Int) async throws
    -> String
  {
    let manager = FileManager.default
    let file = try CacheFiles.url("thumbs", reference, "-\(timeUs)-\(maxSide).jpg")
    if manager.fileExists(atPath: file.path) { return file.path }

    let source = try MediaFiles.url(for: reference)
    let picture = image
      ? try photo(source, maxSide: maxSide)
      : try await frame(source, timeUs: timeUs, maxSide: maxSide)
    let partial = file.deletingLastPathComponent().appendingPathComponent(
      "\(file.lastPathComponent).part")
    guard
      let out = CGImageDestinationCreateWithURL(
        partial as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(
      out, picture, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    guard CGImageDestinationFinalize(out) else { throw CocoaError(.fileWriteUnknown) }
    try? manager.removeItem(at: file)
    try manager.moveItem(at: partial, to: file)
    return file.path
  }

  private static func frame(_ url: URL, timeUs: Int64, maxSide: Int) async throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    return try await generator.image(at: CMTime(value: timeUs, timescale: 1_000_000)).image
  }

  private static func photo(_ url: URL, maxSide: Int) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let thumb = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ] as CFDictionary)
    else { throw CocoaError(.fileReadCorruptFile) }
    return thumb
  }
}

/// The engine has stopped drawing into the texture; the release runs on the main queue (P1-055).
private let releasePreviewTexture:
  @convention(c) (UnsafeMutableRawPointer?, Int64, UnsafeMutableRawPointer?) -> Void = {
    _, id, _ in
    DispatchQueue.main.async {
      MainActor.assumeIsolated { PlatformCallbacks.releaseTexture(id) }
    }
  }

private let frameAvailable: @convention(c) (UnsafeMutableRawPointer?, Int64) -> Void = { _, id in
  DispatchQueue.main.async {
    MainActor.assumeIsolated { PlatformCallbacks.markFrameAvailable(id) }
  }
}

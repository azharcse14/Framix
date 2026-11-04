import AVFoundation
import CoreVideo
import CryptoKit
import ImageIO
import Metal

/// The decoder behind the engine's `decoder_open`, `decoder_frame` and `decoder_close`
/// (docs/adr/0006-decoder-port.md). Each engine thread (preview, export worker) owns one, and
/// every call blocks that thread until the frame is ready. Video frames stay on the decoder's
/// IOSurfaces (no copy); a photo is decoded once into one RGBA texture. The engine places the
/// picture (rotation, crop, fit), so frames are handed over as stored.
final class FrameDecoder {
  private let device: MTLDevice
  private var video: VideoReader?
  private var photo: (reference: String, texture: MTLTexture)?
  /// The last video frame; its buffer and plane textures live until the next call.
  private var held: VideoFrame?

  init?() {
    guard let device = MTLCreateSystemDefaultDevice() else { return nil }
    self.device = device
  }

  /// Fills `out` with the frame of `reference` at `timeUs` (photos: their one frame), read from
  /// its proxy of longest side `proxySide` when that is not 0.
  func frame(
    reference: String, image: Bool, timeUs: Int64, proxySide: UInt32,
    into out: inout EngineFrame
  ) -> Bool {
    // A missing proxy (cache cleared) falls back to the original rather than black.
    let proxyURL = image || proxySide == 0
      ? nil : try? Proxies.url(for: reference, maxSide: Int(proxySide))
    let proxy = proxyURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    guard let url = proxy ? proxyURL : try? MediaFiles.url(for: reference) else { return false }
    if image {
      guard let texture = photoTexture(reference, url) else { return false }
      out = EngineFrame(
        format: UInt32(ENGINE_FRAME_RGBA), planes: (opaque(texture), nil),
        matrix: UInt32(ENGINE_YCBCR_UNKNOWN), range: UInt32(ENGINE_RANGE_UNKNOWN))
      return true
    }
    let time = CMTime(value: timeUs, timescale: 1_000_000)
    // The proxy is another file: its reader and frames must not pass for the original's.
    let source = proxy ? "\(reference)@\(proxySide)" : reference
    guard let frame = videoFrame(source, url, at: time) else { return false }
    out = EngineFrame(
      format: UInt32(ENGINE_FRAME_NV12), planes: (opaque(frame.luma), opaque(frame.chroma)),
      matrix: frame.matrix, range: UInt32(ENGINE_RANGE_VIDEO))
    return true
  }

  private func opaque(_ texture: MTLTexture) -> UnsafeMutableRawPointer {
    // The decoder keeps the texture alive until its next call (decoder_frame's contract).
    Unmanaged.passUnretained(texture).toOpaque()
  }

  // MARK: Video

  private func videoFrame(_ reference: String, _ url: URL, at time: CMTime) -> VideoFrame? {
    if let held, held.reference == reference, held.covers(time) { return held }
    // ponytail: reads forward while the target is under a second ahead, else reopens at it;
    // keyframe-aware seeking is ENG-006.
    if video?.reference != reference || video?.reaches(time) != true {
      held = nil
      video = VideoReader(reference: reference, url: url, from: time)
    }
    if let frame = readForward(reference, to: time) { return frame }
    // Nothing at or after `time`: it is past the last video frame (audio can outlast the
    // video), so read the last second before it to find the frame still showing.
    let back = CMTimeMaximum(.zero, CMTimeSubtract(time, CMTime(value: 1, timescale: 1)))
    video = VideoReader(reference: reference, url: url, from: back)
    return readForward(reference, to: time)
  }

  /// Reads up to the frame showing at `time`. A reader that ends (or fails) is dropped, so the
  /// next call reopens it; its last frame, if it started by `time`, keeps showing after it.
  private func readForward(_ reference: String, to time: CMTime) -> VideoFrame? {
    guard let video else { return nil }
    var last: Sample?
    while let sample = video.next() {
      // The first frame that is still showing at `time`.
      if CMTimeCompare(sample.end, time) > 0 {
        held = VideoFrame(reference: reference, sample: sample, device: device)
        return held
      }
      last = sample
    }
    self.video = nil
    // A reader that failed (not ended) may have stopped anywhere: no frame to hold.
    guard video.completed, let last, CMTimeCompare(last.start, time) <= 0 else { return nil }
    let lasting = Sample(pixels: last.pixels, start: last.start, end: .positiveInfinity)
    held = VideoFrame(reference: reference, sample: lasting, device: device)
    return held
  }

  // MARK: Photo

  /// ponytail: photos are capped at 4096 px a side; a preview quality setting is ENG-008.
  private static let photoMaxSide = 4096

  private func photoTexture(_ reference: String, _ url: URL) -> MTLTexture? {
    if let photo, photo.reference == reference { return photo.texture }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      // Stored orientation: the engine applies the EXIF rotation itself.
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: false,
          kCGImageSourceThumbnailMaxPixelSize: Self.photoMaxSide,
        ] as CFDictionary)
    else { return nil }
    let (width, height) = (image.width, image.height)
    let rowBytes = width * 4
    guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    var pixels = [UInt8](repeating: 0, count: rowBytes * height)
    let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
      guard
        let context = CGContext(
          data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: rowBytes, space: sRGB,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = .shaderRead
    guard drawn, let texture = device.makeTexture(descriptor: descriptor) else { return nil }
    texture.replace(
      region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels,
      bytesPerRow: rowBytes)
    photo = (reference, texture)
    return texture
  }
}

/// The engine's media references are relative to Application Support (MediaPicker.store).
enum MediaFiles {
  static func url(for reference: String) throws -> URL {
    try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
    ).appendingPathComponent(reference)
  }
}

/// Cache files (thumbnails, proxies) in Caches/<dir>, named by the SHA-256 of the media
/// reference plus `suffix`, so each is made once and reused.
enum CacheFiles {
  static func url(_ dir: String, _ reference: String, _ suffix: String) throws -> URL {
    let manager = FileManager.default
    let folder = try manager.url(
      for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    ).appendingPathComponent(dir, isDirectory: true)
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    let name = SHA256.hash(data: Data(reference.utf8)).map { String(format: "%02x", $0) }
      .joined()
    return folder.appendingPathComponent(name + suffix)
  }
}

/// Preview proxies (docs/adr/0007-proxy-media.md): the video's frames, same times, stored size
/// scaled so the longest side is `maxSide`, H.264 without audio. The engine applies rotation,
/// so the file has no transform.
enum Proxies {
  static func url(for reference: String, maxSide: Int) throws -> URL {
    try CacheFiles.url("proxies", reference, "-\(maxSide).mov")
  }

  /// Every proxy is made here, one at a time, even across engine project switches (which
  /// forget a running request but cannot stop it).
  static let queue = DispatchQueue(label: "framix.proxies", qos: .utility)

  /// True once the proxy file is complete (made now or earlier). Blocks the calling thread,
  /// which must not be the main one or a Swift concurrency one.
  static func make(_ reference: String, maxSide: Int) -> Bool {
    guard let file = try? url(for: reference, maxSide: maxSide) else { return false }
    let manager = FileManager.default
    if manager.fileExists(atPath: file.path) { return true }
    // Written beside the file under its own name and renamed when complete, so an existing
    // file is a whole one.
    let partial = file.deletingLastPathComponent().appendingPathComponent(
      "\(UUID().uuidString).part.mov")
    guard let source = try? MediaFiles.url(for: reference),
      let reader = VideoReader(reference: reference, url: source, from: .zero),
      let written = write(reader, to: partial, maxSide: maxSide), written
    else {
      try? manager.removeItem(at: partial)
      return false
    }
    try? manager.removeItem(at: file)
    return (try? manager.moveItem(at: partial, to: file)) != nil
  }

  /// Encodes every frame `reader` gives into `url`; nil if nothing could be written.
  private static func write(_ reader: VideoReader, to url: URL, maxSide: Int) -> Bool? {
    guard let first = reader.next(),
      let writer = try? AVAssetWriter(outputURL: url, fileType: .mov)
    else { return nil }
    let (width, height) = scaled(
      CVPixelBufferGetWidth(first.pixels), CVPixelBufferGetHeight(first.pixels), to: maxSide)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoScalingModeKey: AVVideoScalingModeResize,
        // ponytail: 3 kbit/s per pixel of the long side (5.8 Mbit/s at 1920); tune on devices.
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: maxSide * 3000],
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
      ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input, sourcePixelBufferAttributes: nil)
    guard writer.canAdd(input) else { return nil }
    writer.add(input)
    guard writer.startWriting() else { return nil }
    // Same times as the original, so the engine's source times find the same frames.
    writer.startSession(atSourceTime: .zero)
    var sample: Sample? = first
    while let frame = sample {
      // ponytail: 1 ms polls like ExportEncoder; the encoder drains at its own pace.
      while !input.isReadyForMoreMediaData {
        guard writer.status == .writing else { return false }
        usleep(1000)
      }
      // Frees each frame's autoreleased buffers now, not after the whole file.
      let appended = autoreleasepool {
        adaptor.append(frame.pixels, withPresentationTime: frame.start)
      }
      guard appended else {
        writer.cancelWriting()
        return false
      }
      sample = autoreleasepool { reader.next() }
    }
    guard reader.completed else {
      writer.cancelWriting()
      return false
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    return writer.status == .completed
  }

  /// `width` x `height` scaled so the longest side is `maxSide`, rounded to even sides.
  private static func scaled(_ width: Int, _ height: Int, to maxSide: Int) -> (Int, Int) {
    let long = max(width, height, 1)
    func side(_ value: Int) -> Int { max(2, (value * maxSide / long) & ~1) }
    return (side(width), side(height))
  }
}

/// One decoded video frame: its pixel buffer, the Metal views of its two IOSurface planes, and
/// when it shows.
private struct VideoFrame {
  let reference: String
  let pixels: CVPixelBuffer
  let luma: MTLTexture
  let chroma: MTLTexture
  let start: CMTime
  let end: CMTime
  /// The file's `ENGINE_YCBCR_*` tag; the engine chooses what an untagged frame means.
  let matrix: UInt32

  init?(reference: String, sample: Sample, device: MTLDevice) {
    let pixels = sample.pixels
    guard
      CVPixelBufferGetPixelFormatType(pixels) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      let surface = CVPixelBufferGetIOSurface(pixels)?.takeUnretainedValue()
    else { return nil }
    func plane(_ index: Int, _ format: MTLPixelFormat) -> MTLTexture? {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: format, width: CVPixelBufferGetWidthOfPlane(pixels, index),
        height: CVPixelBufferGetHeightOfPlane(pixels, index), mipmapped: false)
      descriptor.usage = .shaderRead
      return device.makeTexture(descriptor: descriptor, iosurface: surface, plane: index)
    }
    guard let luma = plane(0, .r8Unorm), let chroma = plane(1, .rg8Unorm) else { return nil }
    let tag = CVBufferCopyAttachment(pixels, kCVImageBufferYCbCrMatrixKey, nil) as? String
    self.reference = reference
    self.pixels = pixels
    self.luma = luma
    self.chroma = chroma
    start = sample.start
    end = sample.end
    matrix =
      if tag == kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String {
        UInt32(ENGINE_YCBCR_601)
      } else if tag == kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String {
        UInt32(ENGINE_YCBCR_709)
      } else {
        UInt32(ENGINE_YCBCR_UNKNOWN)
      }
  }

  func covers(_ time: CMTime) -> Bool {
    CMTimeCompare(start, time) <= 0 && CMTimeCompare(time, end) < 0
  }
}

/// A decoded sample's pixels and the span it shows.
private struct Sample: @unchecked Sendable {
  // @unchecked: CVPixelBuffer is not Sendable; a decoded buffer is never written again, and
  // a Sample crosses threads only from `blocking`'s task to the thread waiting on it.
  let pixels: CVPixelBuffer
  let start: CMTime
  let end: CMTime
}

extension Sample {
  init?(_ buffer: CMSampleBuffer) {
    guard let pixels = CMSampleBufferGetImageBuffer(buffer) else { return nil }
    self.pixels = pixels
    start = CMSampleBufferGetPresentationTimeStamp(buffer)
    let duration = CMSampleBufferGetDuration(buffer)
    end = duration.isValid ? CMTimeAdd(start, duration) : start
  }
}

/// Reads one video's frames forward from a start time, as NV12 on IOSurfaces (VideoToolbox).
private final class VideoReader {
  let reference: String
  private let source: SampleSource
  /// Where reading stands: the start of the last frame read (or the start time).
  private var position: CMTime

  init?(reference: String, url: URL, from time: CMTime) {
    let asset = AVURLAsset(url: url)
    guard let track = blocking({ try await asset.loadTracks(withMediaType: .video).first }) ?? nil,
      let reader = try? AVAssetReader(asset: asset)
    else { return nil }
    let output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
      ])
    reader.timeRange = CMTimeRange(start: time, duration: .positiveInfinity)
    guard reader.canAdd(output) else { return nil }
    if #available(iOS 26, *) {
      guard let source = ProviderSource(reader: reader, output: output) else { return nil }
      self.source = source
    } else {
      guard let source = LegacySource(reader: reader, output: output) else { return nil }
      self.source = source
    }
    self.reference = reference
    position = time
  }

  /// True while `time` is at most a second ahead of where reading stands.
  func reaches(_ time: CMTime) -> Bool {
    CMTimeCompare(time, position) >= 0
      && CMTimeCompare(CMTimeSubtract(time, position), CMTime(value: 1, timescale: 1)) < 0
  }

  /// True once the reader read to the end of its range (not when it failed).
  var completed: Bool { source.reader.status == .completed }

  func next() -> Sample? {
    guard let sample = source.next() else { return nil }
    position = sample.start
    return sample
  }
}

private protocol SampleSource {
  var reader: AVAssetReader { get }
  func next() -> Sample?
}

/// iOS 26+: AVAssetReaderOutput.Provider.
@available(iOS 26, *)
private final class ProviderSource: SampleSource, @unchecked Sendable {
  // @unchecked: used by one engine thread at a time, and only inside `blocking` while that
  // thread waits.
  let reader: AVAssetReader
  private let frames: AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>

  init?(reader: AVAssetReader, output: AVAssetReaderTrackOutput) {
    frames = reader.outputProvider(for: output)
    self.reader = reader
    guard (try? reader.start()) != nil else { return nil }
  }

  func next() -> Sample? {
    blocking { [self] in
      guard let sample = try await frames.next() else { return nil }
      return sample.withUnsafeSampleBuffer { Sample($0) }
    } ?? nil
  }
}

/// iOS 17-25: the synchronous reader calls (deprecated in the iOS 27 SDK, which has the
/// Provider above). Remove once the minimum is iOS 26.
private final class LegacySource: SampleSource {
  let reader: AVAssetReader
  private let output: AVAssetReaderTrackOutput

  init?(reader: AVAssetReader, output: AVAssetReaderTrackOutput) {
    reader.add(output)
    guard reader.startReading() else { return nil }
    self.reader = reader
    self.output = output
  }

  func next() -> Sample? {
    while let buffer = output.copyNextSampleBuffer() {
      // Marker-only buffers carry no picture.
      if let sample = Sample(buffer) { return sample }
    }
    return nil
  }
}

/// Runs `work` and blocks the calling (engine, never main) thread until it is done.
private func blocking<T>(_ work: @escaping @Sendable () async throws -> T) -> T? {
  let box = BlockingResult<T>()
  let done = DispatchSemaphore(value: 0)
  Task.detached {
    box.value = try? await work()
    done.signal()
  }
  done.wait()
  return box.value
}

/// [`blocking`]'s answer.
private final class BlockingResult<T>: @unchecked Sendable {
  // @unchecked: written by the task before `signal`, read after `wait`.
  var value: T?
}

// C callbacks for the engine (preview or export thread). The decoder crosses as a retained
// pointer: retained on open, released exactly once by close.

let decoderOpen: @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? = { _ in
  FrameDecoder().map { Unmanaged.passRetained($0).toOpaque() }
}

let decoderFrame:
  @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafePointer<UInt8>?, Int, UInt32, Int64,
    UInt32, UnsafeMutablePointer<EngineFrame>?
  ) -> Int32 = { _, decoder, uri, uriLength, kind, timeUs, proxySide, out in
    guard let decoder, let uri, let out,
      let reference = String(
        bytes: UnsafeBufferPointer(start: uri, count: uriLength), encoding: .utf8)
    else { return ENGINE_ERR_NULL }
    let image = kind == UInt32(ENGINE_MEDIA_IMAGE)
    let ok = Unmanaged<FrameDecoder>.fromOpaque(decoder).takeUnretainedValue()
      .frame(
        reference: reference, image: image, timeUs: timeUs, proxySide: proxySide,
        into: &out.pointee)
    return ok ? ENGINE_OK : ENGINE_ERR_GPU
  }

/// Proxy requests arrive on the engine thread; the encode runs on `Proxies.queue` (it blocks)
/// and answers `done` exactly once from there.
let requestProxy:
  @convention(c) (
    UnsafeMutableRawPointer?, UnsafePointer<UInt8>?, Int, UInt32, EngineProxyDone?,
    UnsafeMutableRawPointer?
  ) -> Void = { _, uri, uriLength, maxSide, done, doneCtx in
    guard let done else { return }
    guard let uri,
      let reference = String(
        bytes: UnsafeBufferPointer(start: uri, count: uriLength), encoding: .utf8)
    else { return done(doneCtx, ENGINE_ERR_NULL) }
    let ctx = UInt(bitPattern: doneCtx)
    Proxies.queue.async {
      let made = Proxies.make(reference, maxSide: Int(maxSide))
      done(UnsafeMutableRawPointer(bitPattern: ctx), made ? ENGINE_OK : ENGINE_ERR_GPU)
    }
  }

let decoderClose: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void = {
  _, decoder in
  guard let decoder else { return }
  Unmanaged<FrameDecoder>.fromOpaque(decoder).release()
}

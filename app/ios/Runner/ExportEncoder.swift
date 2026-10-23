import AVFoundation
import CoreVideo
import Metal

/// The hardware encoder behind the engine's `encoder_open`, `encoder_frame` and
/// `encoder_finish` (docs/adr/0005-export-encoder.md): H.264 MP4 through AVAssetWriter. Rust
/// renders each frame into a pool buffer's IOSurface, so frames never copy. Every call comes
/// from the engine's export worker thread and may block.
final class ExportEncoder {
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor
  private let device: MTLDevice
  private let width: Int
  private let height: Int
  /// The frame Rust is drawing (buffer, its texture, its time); appended on the next call.
  private var pending: (buffer: CVPixelBuffer, texture: MTLTexture, time: CMTime)?

  init?(width: Int, height: Int, fps: Int, kbps: Int, url: URL) {
    // The engine only sends .mp4 paths; an old export there is replaced.
    guard url.pathExtension == "mp4", let device = MTLCreateSystemDefaultDevice() else {
      return nil
    }
    try? FileManager.default.removeItem(at: url)
    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: kbps * 1000,
          AVVideoExpectedSourceFrameRateKey: fps,
        ],
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
      ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
      ])
    guard writer.canAdd(input) else { return nil }
    writer.add(input)
    guard writer.startWriting() else { return nil }
    writer.startSession(atSourceTime: .zero)
    self.writer = writer
    self.input = input
    self.adaptor = adaptor
    self.device = device
    self.width = width
    self.height = height
  }

  /// Appends the pending frame, then returns a render target on a fresh pool buffer for the
  /// frame at `timeUs`; nil on failure.
  func frame(timeUs: Int64) -> MTLTexture? {
    guard appendPending(), let pool = adaptor.pixelBufferPool else { return nil }
    var buffer: CVPixelBuffer?
    guard
      CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
      let buffer,
      let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue()
    else { return nil }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0)
    else { return nil }
    pending = (buffer, texture, CMTime(value: timeUs, timescale: 1_000_000))
    return texture
  }

  /// `ok`: appends the last frame and closes the file, true once it is complete. Otherwise
  /// cancels and removes the file (true).
  func finish(ok: Bool) -> Bool {
    if ok, appendPending() {
      input.markAsFinished()
      let done = DispatchSemaphore(value: 0)
      writer.finishWriting { done.signal() }
      done.wait()
      if writer.status == .completed { return true }
      // A file that did not complete is not a usable video.
      try? FileManager.default.removeItem(at: writer.outputURL)
      return false
    }
    writer.cancelWriting()
    try? FileManager.default.removeItem(at: writer.outputURL)
    return !ok
  }

  /// Appends the frame Rust finished drawing (its GPU work is done when draw returns).
  private func appendPending() -> Bool {
    guard let frame = pending else { return true }
    pending = nil
    // The worker thread may wait (1 ms polls): the encoder drains at its own pace. Cancel
    // (P1-035) replaces this with requestMediaDataWhenReady.
    while !input.isReadyForMoreMediaData {
      guard writer.status == .writing else { return false }
      usleep(1000)
    }
    return adaptor.append(frame.buffer, withPresentationTime: frame.time)
  }
}

// C callbacks for the engine (export worker thread). The encoder crosses as a retained
// pointer: retained on open, released exactly once by finish.

let encoderOpen:
  @convention(c) (
    UnsafeMutableRawPointer?, UInt32, UInt32, UInt32, UInt32, UnsafePointer<UInt8>?, Int
  ) -> UnsafeMutableRawPointer? = { _, width, height, fps, kbps, path, pathLength in
    guard let path,
      let file = String(
        bytes: UnsafeBufferPointer(start: path, count: pathLength), encoding: .utf8),
      let encoder = ExportEncoder(
        width: Int(width), height: Int(height), fps: Int(fps), kbps: Int(kbps),
        url: URL(fileURLWithPath: file))
    else { return nil }
    return Unmanaged.passRetained(encoder).toOpaque()
  }

let encoderFrame:
  @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int64) ->
    UnsafeMutableRawPointer? = { _, encoder, timeUs in
      guard let encoder else { return nil }
      let target = Unmanaged<ExportEncoder>.fromOpaque(encoder).takeUnretainedValue()
        .frame(timeUs: timeUs)
      // The encoder keeps the texture alive until the next call.
      return target.map { Unmanaged.passUnretained($0).toOpaque() }
    }

let encoderFinish:
  @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Bool) -> Int32 = {
    _, encoder, ok in
    guard let encoder else { return ENGINE_ERR_NULL }
    let finished = Unmanaged<ExportEncoder>.fromOpaque(encoder).takeRetainedValue()
      .finish(ok: ok)
    return finished ? ENGINE_OK : ENGINE_ERR_GPU
  }

// SPIKE (P1-001): wgpu output shown in a Flutter Texture without copies. Off main until reviewed;
// the real platform layer (native/ios, C ABI callbacks) comes with P1-005.
import CoreVideo
import Flutter
import IOSurface
import Metal

/// A Flutter texture whose CVPixelBuffer shares one IOSurface with the Metal texture that Rust
/// (wgpu) renders into, so Flutter samples exactly the bytes the GPU wrote.
final class SpikePreviewTexture: NSObject, FlutterTexture, @unchecked Sendable {
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

/// Method channel `framix/spike_preview`: `create` makes a texture and returns its Flutter id
/// and the `id<MTLTexture>` address for Rust; `frameAvailable` asks Flutter to redraw it.
@MainActor
enum SpikePreview {
  private static var textures: [Int64: SpikePreviewTexture] = [:]

  static func register(with registrar: FlutterApplicationRegistrar) {
    let registry = registrar.textures()
    let channel = FlutterMethodChannel(
      name: "framix/spike_preview", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      MainActor.assumeIsolated {
        handle(call, result, registry)
      }
    }
  }

  private static func handle(
    _ call: FlutterMethodCall, _ result: FlutterResult, _ registry: FlutterTextureRegistry
  ) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "create":
      guard
        let width = args?["width"] as? Int, let height = args?["height"] as? Int,
        let device = MTLCreateSystemDefaultDevice(),
        let texture = SpikePreviewTexture(device: device, width: width, height: height)
      else { return result(FlutterError(code: "create", message: nil, details: nil)) }
      let id = registry.register(texture)
      textures[id] = texture
      let address = Int(bitPattern: Unmanaged.passUnretained(texture.metalTexture).toOpaque())
      result(["textureId": id, "metalTexture": address])
    case "frameAvailable":
      guard let id = args?["textureId"] as? Int64, textures[id] != nil else {
        return result(FlutterError(code: "frameAvailable", message: nil, details: nil))
      }
      registry.textureFrameAvailable(id)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

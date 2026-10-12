---
paths:
  - "native/ios/**"
---
# Swift / iOS
- Swift 6 language mode, strict concurrency.
- Thin adapter only: wrap AVFoundation, VideoToolbox, Vision, Core ML and hand results to Rust via the registered C ABI callbacks. No business logic.
- UIScene life cycle: plugin and Texture registration in didInitializeImplicitFlutterEngine; lifecycle events come from the scene delegate.
- Preview frames: IOSurface-backed, Metal-compatible CVPixelBuffer.
- Background export: BGContinuedProcessingTask on iOS 26+, short background time path on iOS 17-25.

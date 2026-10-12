---
paths:
  - "native/android/**"
---
# Kotlin / Android
- Thin adapter only: wrap MediaCodec, MediaExtractor, MediaMuxer, ML Kit and hand results to Rust via JNI into the same Rust library. No business logic.
- Preview through TextureRegistry.SurfaceProducer; recreate the surface on its callbacks after background.
- Never block the main thread (ANR at 5 s). Long export runs in a foreground service of type mediaProcessing; respect its daily time limit.
- All native libraries 16 KB page aligned; never hardcode a 4096 page size.
- Export sharing through FileProvider; no component exported unless required.

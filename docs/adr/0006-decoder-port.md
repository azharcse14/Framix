# 0006. Preview and export get frames from a blocking platform decoder
Status: accepted
Date: 2026-10-24
Task: P1-060

## Context
The preview and export drew a test pattern: there was no way for the engine to ask for the
picture under the playhead. Decoding belongs to the platform (VideoToolbox, MediaCodec), the
picture must stay on the GPU, and placement (rotation, crop, flips, fit, scale, position) is
an engine rule that preview and export must apply the same way.

## Decision
- `framix_app::preview::Decoder` is a port: `frame(media, source_time) -> Frame`, where a
  `Frame` is NV12 (two plane textures plus the raw matrix and range tags) or one RGBA texture.
  Handles stay valid until the next call or until the decoder is dropped, so there is no
  release call.
- The platform vtable (v4) gains `decoder_open`, `decoder_frame` and `decoder_close`. They are
  **synchronous** and may block. Each thread that draws owns its own decoder: the engine
  thread for the preview, the export worker for export.
- `Timeline::layer_at(time)` picks the clip (top visible video track) and its source time.
  `placement::canvas_to_source` and `target_to_canvas` turn the clip's transform and the
  canvas into two affine maps that the shaders sample with, so the placement rule lives once,
  in `core`.
- The engine redraws the preview when the layer under the playhead changes, even if the
  playhead did not move (a trim, a transform). A decode error draws black and keeps the
  preview; a GPU error drops it.
- iOS: `AVAssetReader` reads NV12 IOSurface frames forward from the target; planes are wrapped
  as Metal textures without a copy. Photos are decoded once with ImageIO, without applying
  EXIF rotation (the engine applies it). iOS 26+ uses `AVAssetReaderOutput.Provider`; iOS
  17-25 uses `copyNextSampleBuffer`, which the iOS 27 SDK deprecates.

## Consequences
- Decoding blocks the engine thread for the preview. This is a known exception to "no heavy
  work on the command thread" until P1-053 moves drawing to the render thread.
- Seeking reopens the reader for backward or far (over 1 s) jumps; keyframe-aware seeking and
  caching are ENG-006.
- Only one layer is drawn; compositing several tracks is a later task.
- Android registers decoder stubs that fail, so its preview stays on the test pattern until
  its own decoder task.
- The legacy iOS path is removed when the minimum becomes iOS 26.

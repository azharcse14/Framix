# 0005. Export runs on a worker that calls blocking platform encoder functions
Status: accepted
Date: 2026-10-23
Task: P1-034

## Context
Export renders every frame of the project and hands it to the platform's hardware encoder
(VideoToolbox through AVAssetWriter on iOS, MediaCodec on Android). Frames must not be copied
to the CPU, and the engine thread must stay responsive while an export runs. ADR 0003 says
platform callbacks run on the engine thread and return at once, answering through `done`
callbacks. An encoder is a different shape: frame after frame, each waiting for the encoder to
take the previous one.

## Decision
- An accepted `ExportProject` runs on its own worker thread (`framix-export`) on a snapshot of
  the timeline. The engine thread answers `CommandAccepted` and, when the worker reports back,
  exactly one `ExportFinished`.
- The platform vtable (v3) gains three **synchronous** calls, made only from that worker:
  `encoder_open` (size, fps, kbps, path; returns an encoder or null), `encoder_frame` (appends
  the previous frame, returns the render target for the next one) and `encoder_finish`
  (appends the last frame and closes the file, or cancels it; frees the encoder). They may
  block; the worker waits for them.
- The render target is a BGRA texture on the encoder's own buffer: an `id<MTLTexture>` on the
  IOSurface of an AVAssetWriter pixel-buffer-pool buffer on iOS. Rust draws into it with the
  same renderer as the preview (one render path for preview and export), and the GPU is done
  before `draw` returns, so the platform can append the buffer as it is.
- The frame count covers the timeline: a partial last frame is encoded whole. Frame times are
  integer ticks, passed to the platform as whole microseconds.
- Size, frame rate and bitrate come from the project's export settings (`core::export`).

## Consequences
- The engine thread never waits on the encoder. The worker does, so a slow encoder slows only
  the export.
- `engine_destroy` does not wait for a running export: it sets the export's cancel flag, so the
  worker stops at its next frame and cancels the file, and its result goes nowhere. Progress
  (once per percent) and `CancelExport` came with P1-035.
- Android (P1-069): MediaCodec H.264 + MediaMuxer. `encoder_frame` returns the codec's input
  Surface as an `ANativeWindow*`, the same every frame; Rust draws into it with the preview's
  window path (`Gpu::draw_to_android_window`) and presents, which queues the frame into the codec.
  - A queued frame carries its queue time, not its frame time (wgpu cannot set it), so the codec
    runs without B-frames and Kotlin gives each output frame the next time `encoder_frame`
    reported. Reordered or lost frames fail the export rather than mistime it.
  - `Gpu` keeps two window surfaces (preview and export), so a preview draw during an export
    does not disconnect the codec's window. The export forgets its surface only after
    `encoder_finish`: dropping it earlier disconnects the window, which can drop frames the codec
    has not taken yet.
- The iOS encoder uses `AVAssetWriterInputPixelBufferAdaptor`, which works from iOS 17 and is
  not deprecated at the iOS 17 deployment target.

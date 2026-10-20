# 0004. Android preview: wgpu renders into the SurfaceProducer's window, not into our own AHardwareBuffers
Status: proposed
Date: 2026-10-20
Task: P1-003

## Context
The preview must reach Flutter's Texture without a copy (P1-001). Android offers two paths:

1. **Surface path (P1-001, today):** `TextureRegistry.createSurfaceProducer()` gives a
   `Surface`; Rust turns it into an `ANativeWindow` (`ANativeWindow_fromSurface`) and wgpu
   presents into it as a normal Vulkan/GLES surface (`Gpu::draw_to_android_window`).
2. **Own-AHB path:** Android has no public API that makes an `android.media.Image` from a
   HardwareBuffer we allocated, so this path needs our own buffer queue:
   - an `ImageWriter` dequeues a buffer (`getHardwareBuffer`);
   - wgpu renders into it as an imported image (the P1-056 import plus COLOR_ATTACHMENT usage);
   - the buffer is queued into our own `ImageReader`, and Kotlin hands each acquired `Image` to
     Flutter through `createImageTexture()` / `ImageTextureEntry.pushImage`.

In Flutter 3.47, `createSurfaceProducer()` on API 29+ (our minimum) returns an
`ImageReaderSurfaceProducer` (FlutterRenderer.java): the Surface belongs to an `ImageReader`,
and Flutter samples its HardwareBuffers directly. The one exception is Huawei on API 29 and
below, a known HardwareBuffer defect (`hasAndroidHardwareBufferDefect`), where Flutter falls back
to a `SurfaceTexture` producer. Emulator measurements say nothing about real-phone cost, so this
decision rests on structure. Timings come with the device check (P1-051).

| | Surface path | Own-AHB path |
| --- | --- | --- |
| Copies | None: wgpu's swapchain images are the ImageReader's AHBs | None |
| Code | wgpu surface; already works (P1-001) | ImageWriter → render-target import → our ImageReader → pushImage: an extra queue hop, plus our own buffer recycling |
| Sync | The window queue carries the producer's fences. Flutter waits on them only on API 33+ (`maybeWaitOnFence`); on API 29-32 it samples without waiting | We pass fences ourselves (Vulkan semaphore to sync fd to Image fence), and the release back to the foreign queue (P1-053). `pushImage` has the same API 33 limit |
| Buffer count / back-pressure | ImageReader's own, managed by Flutter | Ours to size and throttle |
| Huawei API ≤ 29 fallback | Still works: the SurfaceTexture producer is a window too | Breaks: it would rely on the ImageReader/HardwareBuffer path whose defect makes Flutter fall back there |
| GLES backend (P1-004) | Same code: wgpu GLES presents to the window | Needs an EGLImage render-target import as well |
| Lifecycle | With `SurfaceLifecycle.manual` Flutter never resets the Surface, and its callbacks never fire. The Surface does change after `setSize` (a new ImageReader), so the wgpu surface is recreated whenever `getSurface()` returns a different Surface | We own buffers across background/foreground; Flutter only sees pushed Images |
| Control | Present timing is wgpu's (FIFO / mailbox) | Exact per-frame control (timestamps, which buffer) |

## Decision
- Keep the surface path as the only Android preview output. `Gpu::draw_to_android_window` stays
  the one render target on Android; the platform vtable (P1-052) gives Rust the producer's
  Surface.
- Create producers with `SurfaceLifecycle.manual` (the default), so a backgrounded app keeps its
  last preview frame. Flutter then never resets the Surface and sends no lifecycle callbacks:
  - `SurfaceProducer.Callback` only fires for `resetInBackground`;
  - the Huawei SurfaceTexture producer ignores `setCallback`.
- Kotlin calls `getSurface()` before each draw, as TextureRegistry asks. Rust recreates the wgpu
  surface when that Surface differs from the last one (after `setSize` changes the size) or is no longer
  valid. This is part of P1-055.
- Do not build the own-AHB output path. Revisit it only if the real-device check (P1-051) shows
  a cost the surface path cannot fix: dropped or late frames from wgpu's present mode, or more
  memory from ImageReader buffering.
- The AHB import from P1-056 stays an input path (decoder frames into wgpu), not an output path.

## Consequences
- No new Android output code. The fences and buffer recycling we would otherwise own stay
  inside the window queue.
- The same path covers Vulkan, GLES (P1-004) and Huawei's SurfaceTexture fallback.
- Frame pacing depends on wgpu's surface present mode. Preview and export share the render path
  (performance.md); only the final target differs: export renders offscreen to the encoder.
- The spike notes that "the frame survives the swapchain drop after present only by
  observation". P1-055 must keep a wgpu surface alive for the current Surface, and recreate it
  when the Surface changes.
- On API 29-32 Flutter samples producer buffers without waiting on their fences. The
  real-device check (P1-051) must look for torn or partial frames there.

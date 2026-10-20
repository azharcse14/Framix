# 0004. Android preview: wgpu renders into the SurfaceProducer's window, not into our own AHardwareBuffers
Status: proposed
Date: 2026-10-20
Task: P1-003

## Context
The preview must reach Flutter's Texture without a copy (P1-001). Android offers two paths:

1. **Surface path (P1-001, today):** `TextureRegistry.createSurfaceProducer()` gives a
   `Surface`; Rust turns it into an `ANativeWindow` (`ANativeWindow_fromSurface`) and wgpu
   presents into it as a normal Vulkan/GLES surface (`Gpu::draw_to_android_window`).
2. **Own-AHB path:** the engine allocates AHardwareBuffers, wgpu renders into them as imported
   images (the import from P1-056, plus COLOR_ATTACHMENT usage), and Kotlin hands each finished
   buffer to Flutter as an `android.media.Image` through `createImageTexture()` /
   `ImageTextureEntry.pushImage`, via an `ImageWriter`.

In Flutter 3.47, `createSurfaceProducer()` on API 29+ (our minimum) returns an
`ImageReaderSurfaceProducer` (FlutterRenderer.java): the Surface belongs to an `ImageReader`,
and Flutter samples its HardwareBuffers directly. The one exception is Huawei on API 29 and
below, a known HardwareBuffer defect (`hasAndroidHardwareBufferDefect`), where Flutter falls back
to a `SurfaceTexture` producer. Emulator measurements say nothing about real-phone cost, so this
decision rests on structure. Timings come with the device check (P1-051).

| | Surface path | Own-AHB path |
| --- | --- | --- |
| Copies | None: wgpu's swapchain images are the ImageReader's AHBs | None |
| Code | wgpu surface; already works (P1-001) | AHB pool, render-target import, ImageWriter queue, our own buffer recycling |
| Sync | The window queue carries acquire/release fences for us | We pass fences ourselves (Vulkan semaphore to sync fd to Image fence), including release back to the foreign queue (P1-053) |
| Buffer count / back-pressure | ImageReader's own, managed by Flutter | Ours to size and throttle |
| Huawei API ≤ 29 fallback | Still works: the SurfaceTexture producer is a window too | Breaks: no ImageReader-backed texture to push into |
| GLES backend (P1-004) | Same code: wgpu GLES presents to the window | Needs an EGLImage render-target import as well |
| Lifecycle | SurfaceProducer callbacks (`onSurfaceCleanup` / `onSurfaceAvailable`) tell us when to drop and recreate the wgpu surface | We own buffers across background/foreground; Flutter only sees pushed Images |
| Control | Present timing is wgpu's (FIFO / mailbox) | Exact per-frame control (timestamps, which buffer) |

## Decision
- Keep the surface path as the only Android preview output. `Gpu::draw_to_android_window` stays
  the one render target on Android; the platform vtable (P1-052) gives Rust the producer's
  Surface.
- Create producers with `SurfaceLifecycle.manual` (the default). Drop the wgpu surface on
  `onSurfaceCleanup` and recreate it on `onSurfaceAvailable`; this is part of P1-055.
- Do not build the own-AHB output path. Revisit it only if the real-device check (P1-051) shows
  a cost the surface path cannot fix: dropped or late frames from wgpu's present mode, or more
  memory from ImageReader buffering.
- The AHB import from P1-056 stays an input path (decoder frames into wgpu), not an output path.

## Consequences
- No new Android output code. The fences and buffer recycling we would otherwise own stay
  inside the window queue.
- The same path covers Vulkan, GLES (P1-004) and Huawei's SurfaceTexture fallback.
- Frame pacing depends on wgpu's surface present mode. Export does not use this path (it
  renders offscreen), so preview pacing is the only exposure.
- The spike notes that "the frame survives the swapchain drop after present only by
  observation". P1-055 must keep the wgpu surface alive while the producer lives, and recreate
  it from the lifecycle callbacks.

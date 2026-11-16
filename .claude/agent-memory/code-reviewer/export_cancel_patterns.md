---
name: export-cancel-patterns
description: Export worker cancel/progress review findings (P1-035) - races and Dart reply correlation
metadata:
  type: project
---

- Cancel flag is only checked before each frame, so a cancel during the last frame or `encoder.finish(true)` yields ExportFinished ok even though CancelExport was Accepted. Proto comment must say "may still finish".
- Export worker is not joined on engine_destroy; old worker's `finish(false)` removes the file at the path and can delete a new export's output to the same path (hot restart). Residual risk, ADR 0005 says non-blocking.
- Dart cubit "first reply after start" (`_starting`) is wrong if `engine.send` throws (flag stays true) or start is called while running (refused -> ExportFailed overwrites Running). Prefer set the flag after send and guard start on ExportRunning.
- ffi `serve` mapping ExportError -> event is logic in the ffi layer and untested; belongs in app::Engine.
- check.sh `flutter test` can fail once with "Failed to code sign binary" when another flutter command holds the lock; rerun before calling it Critical.

- Surface-input platform encoders (P1-069 Android MediaCodec, 2026-11-16): checked clean = JNI refs (global encoder ref, ANativeWindow fromSurface +1 / cache WindowRef +1), per-call attach/detach via with_kotlin, muxer only on the HandlerThread until join, forget-after-finish (BufferQueue disconnect frees queued buffers, so the claim is right). Gaps to look for in similar designs:
  (a) producer blocks in dequeueBuffer while holding Gpu `window_surface` (old Android Vulkan loaders ignore the vkAcquireNextImageKHR timeout); a codec that errors (onError, reclaim on background) stops consuming, so the export worker AND the preview render thread hang; fail() only sets a flag. Ask that failure abandons the consumer (release the codec) and a cancel path that can't be stuck.
  (b) buffers carry queue (wall-clock) time, not frame time: encoder rate control sees render speed, not fps; ask for a bitrate check in the device test.
  (c) Android draw_into draws the test pattern for media until the decoder lands, so wiring the encoder makes export "succeed" with placeholder frames (was: open fails). Ask for a refusal or a note on the decoder task.
  (d) export worker JNI attach/detach per frame = per-frame Thread peer allocation on a hot path.
- 2-slot LRU window caches: a third window (second preview, preview recreate twice) between two export frames evicts the export swapchain mid-run; detected only at the end (FIFO leftover). Suggest pinning the active export window.

**How to apply:** look for these when reviewing export/cancel/worker changes.

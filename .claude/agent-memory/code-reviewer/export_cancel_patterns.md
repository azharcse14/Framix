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

**How to apply:** look for these when reviewing export/cancel/worker changes.

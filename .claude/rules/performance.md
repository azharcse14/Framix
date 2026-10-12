# Performance

## Hot paths (render loop, audio callback, decode, playback, scrubbing, export)
- No heap allocation per frame or per audio buffer; reuse buffers and GPU textures from pools.
- Audio callback: no allocation, locks, I/O, or logging.
- Port trait calls happen per frame or per buffer, never per pixel or sample; inner loops use concrete types or generics.
- No O(n^2) over clips or keyframes; time lookups use sorted structures and binary search.
- FFI calls return immediately and are batched; never send frames or large buffers to Dart.
- Preview and export share one render path, so what you see is what you export.

## Flutter
- const constructors; BlocSelector/buildWhen for high-frequency state; RepaintBoundary around timeline and preview; no heavy work in build().
- Never block the UI isolate.

## Measure, don't guess
- Any hot-path change: run the criterion benchmark before and after and report both numbers. A regression over 5% blocks the change unless justified.
- Measure only in release/profile builds.
- Outside hot paths, clear code beats clever code.

## Budgets
- Follow docs/plan.md (Resource optimization): render on demand (0 fps idle), frame cache and memory budgets, lazy thumbnails.

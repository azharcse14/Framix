# 0007. The preview decodes big videos from a smaller proxy file
Status: accepted
Date: 2026-10-30
Task: P1-039

## Context
Since P1-060 the preview decodes the real frame under the playhead on the engine thread.
Decoding 2K/4K there is slow and memory heavy, so scrubbing stutters on phones. Export must
still read the original, full quality.

## Decision
- The rule lives in `core`: `Media::proxy_side()` gives a proxy to every video whose longest
  stored side is over 1920 px: over 2560 px gets a 1920 px proxy, otherwise 1280 px. Photos
  and smaller videos get none. No UI and no project file change: proxies are cache.
- `framix_app::proxy` owns the schedule, like thumbnails: after every edit the engine asks
  for the media that need one and were never asked for, makes **one at a time** (a proxy is a
  whole-file encode), and forgets everything on a new or opened project (a generation number
  drops late answers, since media ids restart). A platform that refuses a request gets no more.
- `Layer::proxy_side` carries the choice to the renderer and the Decoder port
  (`Decoder::frame(media, time, proxy_side)`). `Timeline::layer_at` always gives None; only the
  engine's preview path fills it in once the proxy is ready, so export, which draws from a
  timeline snapshot, never reads a proxy. `LayerKey` includes it, so a ready proxy redraws.
- Platform vtable v5: `request_proxy(uri, max_side, done)` returns at once and answers
  `done(status)` once the file is complete; `decoder_frame` gains `proxy_side` (0 = original).
  The proxy has the original's stored shape and timestamps, so placement (which works in UV)
  and source times are unchanged.
- iOS: `Proxies.make` reads the original with the decoder's `VideoReader` and writes H.264
  `.mov` through `AVAssetWriter` into Caches/proxies, named by the SHA-256 of the reference and
  the side. Every proxy is made on one serial queue (a project switch forgets a running
  request but cannot stop it), into a uniquely named `.part.mov` that is renamed when complete,
  so an existing file is a whole one and is reused. A missing proxy file falls back to the
  original. Android answers every request with a failure until its decoder (P1-070).

## Consequences
- Until a proxy is ready the preview decodes the original; then it switches with one redraw.
- Proxies take disk space with no limit or cleanup yet (RES-018, RES-019, SYS-005) and are not
  yet excluded from backups (PLAT-013; Caches is not backed up on iOS).
- No progress or status reaches Dart; a toggle or a "make proxy?" offer is OVL-022.
- Audio still plays from the original; the proxy has no audio track.
- A failed proxy (e.g. the encoder stopped in the background) is not retried until the
  project is reopened; persisted, resumable jobs are OVL-002.
- Proxies are written as 8-bit BT.709; HDR (HLG/BT.2020) sources may look different in the
  preview than in the export until HDR handling (ENG-011) covers proxies.

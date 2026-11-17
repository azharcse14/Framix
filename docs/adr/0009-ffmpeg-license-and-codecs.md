# 0009. FFmpeg ships as an LGPL-only, dynamically linked demuxer; codecs stay on the platform
Status: accepted
Date: 2026-11-17
Task: LEG-003 (gates SYS-024, P1-059)

This is an engineering reading of the licenses, not legal advice. docs/plan.md (Legal) asks
for a lawyer before commercial launch; the open items are LEG-016, LEG-017 and LEG-018.

## Context
docs/plan.md makes FFmpeg (through rsmpeg) an optional fallback: platform APIs demux and
decode first (AVAssetReader/VideoToolbox, MediaExtractor/MediaCodec), and FFmpeg probes and
demuxes what the platform cannot read (P1-059). SYS-024 owns the minimal build. Two questions
had to be answered first: which FFmpeg license we take on, and which codec patents.

- **FFmpeg license.** FFmpeg is LGPL-2.1-or-later; some optional parts and external
  libraries are GPL, and `--enable-version3` moves the build to (L)GPL-3. Its legal page gives
  a checklist for LGPL use: build without `--enable-gpl` and `--enable-nonfree`, link
  dynamically, ship the exact source of the binaries with a diff and the configure line,
  mention the LGPL in the about box and EULA, do not forbid reverse engineering, do not rename
  the libraries to obscure names, and use no GPL library such as libx264.
  <https://ffmpeg.org/legal.html>
- **LGPL-2.1 section 6.** A work that uses the library may carry its own terms only if they
  "permit modification of the work for the customer's own use and reverse engineering for
  debugging such modifications", and it must take one of the routes (a)-(e); route (b) is "a
  suitable shared library mechanism" that uses the library at run time and works with a
  modified, interface-compatible version. Route (c) is a written source offer valid for at
  least three years. Section 10 forbids further restrictions on recipients.
  <https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>
- **Rust bindings.** rsmpeg (0.18.0+ffmpeg.8.0, Aug 2025) and its sys crate rusty_ffmpeg
  (0.17.0+ffmpeg.8.1, Apr 2026) are MIT. rusty_ffmpeg links either way: `FFMPEG_DLL_PATH`
  links shared libraries, `FFMPEG_LIBS_DIR` static ones.
  <https://crates.io/crates/rsmpeg>, <https://crates.io/crates/rusty_ffmpeg>,
  <https://github.com/CCExtractor/rusty_ffmpeg#readme>
- **Store terms.** Apple's standard EULA forbids reverse engineering and modification, but
  yields "to the extent as may be permitted by the licensing terms governing use of any
  open-sourced components" in the app.
  <https://www.apple.com/legal/internet-services/itunes/dev/stdeula/>. Whether a code-signed
  App Store app meets the LGPL relinking right has been argued for years without an
  authoritative answer (FFmpeg trac #1229, closed wontfix:
  <https://trac.ffmpeg.org/ticket/1229>). Google Play has no store EULA in the app's place.
- **Codec patents.** FFmpeg's legal page says it does not know whether FFmpeg uses patented
  algorithms and warns commercial users about H.264/MPEG-4. The pools are Via LA (formed from
  MPEG LA and Via Licensing in 2023) for AVC/H.264 and AAC, and Access Advance for HEVC (which
  bought Via LA's HEVC/VVC pool in Dec 2025). The AVC program licenses makers of end-user
  encoder/decoder products (first 100,000 units a year free, then per unit); the AAC program
  likewise licenses makers of end-user encoder/decoder products and warns that open-source
  implementations may need patent licenses.
  <https://www.via-la.com/licensing-2/avc-h-264/>, <https://www.via-la.com/licensing-2/aac/>,
  <https://accessadvance.com/licensing-programs/hevc-advance/>,
  <https://accessadvance.com/2025/12/15/access-advance-and-via-licensing-alliance-announce-hevc-vvc-program-acquisition/>
- **Platform codecs.** VideoToolbox/AVFoundation ship with iOS under Apple's software license,
  which carries its own AVC/MPEG-4 notices (<https://www.apple.com/legal/sla/>). Android
  lists H.264, HEVC, AAC, VP8/VP9 and AV1 as platform formats; the codec implementations come
  with the device (Google's or the OEM's), and Via LA states its AAC program does not cover
  Android OEMs, who license AAC themselves.
  <https://developer.android.com/guide/topics/media/platform/supported-formats>.
  Our reading: the vendor that ships the codec licenses it; an app that only calls the OS
  codec does not ship a patented implementation. We could not find a primary source that says
  this outright for apps, so LEG-017 asks a lawyer to confirm it.

## Decision
**1. LGPL only.** The FFmpeg build that ships is configured without `--enable-gpl`,
`--enable-nonfree` and `--enable-version3`, and with no external library (no libx264, x265,
fdk-aac, libmp3lame, OpenSSL, ...). `avformat_license()`, `avcodec_license()` and
`avutil_license()` must return "LGPL version 2.1 or later", and `avformat_configuration()`
must not contain those three flags; SYS-024 makes the build script check this. A GPL or
nonfree component needs a new ADR.

**2. Dynamic linking on both platforms.** FFmpeg is never linked statically into the Rust
engine (no `FFMPEG_LIBS_DIR`/static archives in release builds; link through shared libraries).
- iOS: each FFmpeg library (libavformat, libavcodec, libavutil) is its own dynamic framework,
  embedded and signed in the app bundle; the engine library loads them through the dynamic
  linker. Framework names keep the FFmpeg library names (a prefix or suffix is fine).
- Android: `libavformat.so`, `libavcodec.so`, `libavutil.so` ship beside the engine library in
  the APK/AAB for arm64-v8a and x86_64, 16 KB aligned (PLAT-003), names unchanged.
- The app does nothing to stop a user from swapping in a modified, interface-compatible build
  (no hash pinning of the FFmpeg libraries). On both stores the swap needs re-signing the app;
  whether that meets section 6(b) is open (LEG-016). Section 6(c) is the backstop: the source
  offer below stays valid for at least three years after each release.

**3. Configure flags policy.** Start from `--disable-everything` and enable only what P1-059
needs:
- Allowed: demuxers for containers the platform may not read (e.g. mov/mp4, matroska/webm,
  avi, mpegts, flv, ogg, wav, mp3, aac/adts, flac), the parsers those demuxers need, and
  bitstream filters that only re-wrap data for the platform decoder (`h264_mp4toannexb`,
  `hevc_mp4toannexb`, `extract_extradata`). These read container structure and headers; they
  do not decode pictures or sound.
- Protocols: none, or `file` only. Input comes through a custom AVIOContext over the file
  descriptor P1-012 hands the engine; `--disable-network`.
- Off: all encoders, all muxers, all hwaccels (VideoToolbox/MediaCodec are reached through our
  own vtable, ADR 0003/0006), avdevice, avfilter, swscale, swresample and postproc, programs
  and docs. Enabling one of these is a SYS-024/P1-059 change that must restate why.
- No software decoder or encoder for a patented codec (H.264, HEVC, VVC, MPEG-2, MPEG-4
  Part 2, AAC, AC-3/E-AC-3, ...). Reason: shipping our own implementation is exactly what the
  AVC/AAC/HEVC pools license per unit, the platform already decodes and encodes these in
  hardware (RES-003), and size (plan.md App size). A file whose codec the device cannot decode
  is reported as unsupported; we do not fall back to software decode for it. This narrows
  docs/plan.md (Tech decisions "Software video fallback", App size row "H.264/H.265/AAC"):
  RES-003's software fallback applies only to royalty-free codecs. Changing this needs a new
  ADR and the answer to LEG-017.
- Royalty-free FFmpeg native decoders (PCM, FLAC, Vorbis, Opus, MP3 (patents expired), VP8,
  VP9) may be enabled later by a task that needs them; none is on by default. VP9/AV1 have
  third-party pool claims, so LEG-017 covers them before one ships. AV1 software decode would
  need dav1d, a new dependency: not part of this decision.

**4. Attribution and source obligations (app and website).**
- The in-app Licenses page (LEG-004) names FFmpeg ("FFmpeg", correct spelling), says it is used
  under LGPL-2.1-or-later, includes the license text, and links to the source download. The
  About/Settings version screen mentions the same.
- Our Terms of Service / EULA (LEG-006) mention FFmpeg's LGPL use, say we do not own FFmpeg
  and where its owners are, and do not forbid reverse engineering of the app to the extent
  LGPL-2.1 section 6 needs it. Apple's standard EULA already yields to open-source terms; a
  custom App Store EULA must keep that carve-out. Translations (en, bn) get the same text.
- For every build that ships FFmpeg, we publish the exact FFmpeg source tarball, our
  `changes.diff`, the configure line and the build script, at a public URL (LEG-018) linked
  from the Licenses page and the website pages that link to the store listings, and keep it at
  least three years. It must be the exact source the shipped binaries were built from.
- LEG-004's license list includes rsmpeg/rusty_ffmpeg (MIT) like any other crate.

**5. Patent position.** H.264, HEVC and AAC are decoded and encoded only by the OS
(VideoToolbox/AVFoundation, MediaCodec), whose vendors ship and license those codecs. FFmpeg
in Framix only probes and demuxes. We do not take a pool license now. LEG-017 confirms this
with a lawyer before commercial launch, including whether our exports (encoded by the OS) or
a paid subscription change anything.

## Consequences
- SYS-024 and P1-059 can proceed: the build script implements section 3 and the license check
  in section 1; P1-059 adds rsmpeg (MIT; still needs the user's yes as a new dependency).
- Formats the device has no decoder for (e.g. HEVC on a phone without one, ProRes on Android)
  stay unsupported instead of decoding slowly in software.
- Two or three extra frameworks/.so files ship; each must be 16 KB aligned on Android and
  signed on iOS.
- Release work grows by one step: publish the FFmpeg source bundle for each shipped build.
- Open, owner human: LEG-016 (LGPL on the stores), LEG-017 (codec patents), LEG-018 (source
  hosting). Until LEG-016 and LEG-017 are answered, FFmpeg may be developed and tested but a
  commercial release containing it waits on them.

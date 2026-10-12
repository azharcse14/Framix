# Test media corpus

Stored with git LFS (see .gitattributes). Only files we recorded ourselves or that are explicitly licensed for this use. Tests read from here and never download media.

Cases to cover (task REL-007):
- iPhone HDR/Dolby Vision HEVC, ProRes, Android OEM camera files
- VFR screen recording, slow-mo 120/240 fps
- WhatsApp-compressed video
- Rotated, 10-bit, odd resolution, anamorphic
- Audio-only, video without audio, 5.1 audio
- One-hour file, 3 GB+ file, deliberately broken files
- Mixed Bangla, English, and emoji text samples

Name files by what they test, e.g. `vfr_screen_rec_iphone_60s.mp4`, and add a line per file to `MANIFEST.md` (source, device, license, what it covers).

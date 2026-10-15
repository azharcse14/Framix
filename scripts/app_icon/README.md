App icon (REL-024): edit `draw_icon.swift`, then run `scripts/app_icon/generate.sh` (macOS) to rewrite the iOS AppIcon and Android adaptive foreground PNGs.

The output depends on the macOS version (CoreGraphics rendering), so this is run by hand and must not be wired into check.sh.

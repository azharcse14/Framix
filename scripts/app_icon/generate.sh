#!/usr/bin/env bash
# Regenerates every app icon file from draw_icon.swift (macOS only: swift + sips).
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
swift scripts/app_icon/draw_icon.swift "$tmp"

cp "$tmp/ios_1024.png" app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

res=app/android/app/src/main/res
# density: adaptive foreground px (108 dp); minSdk 29 always uses mipmap-anydpi-v26.
for entry in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  IFS=: read -r density fg <<<"$entry"
  sips -z "$fg" "$fg" "$tmp/foreground.png" --out "$res/mipmap-$density/ic_launcher_foreground.png" >/dev/null
done

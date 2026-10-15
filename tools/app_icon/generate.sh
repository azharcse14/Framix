#!/usr/bin/env bash
# Regenerates every app icon file from draw_icon.swift (macOS only: swift + sips).
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
swift tools/app_icon/draw_icon.swift "$tmp"

cp "$tmp/ios_1024.png" app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

res=app/android/app/src/main/res
# density: adaptive foreground px (108 dp), legacy icon px (48 dp)
for entry in mdpi:108:48 hdpi:162:72 xhdpi:216:96 xxhdpi:324:144 xxxhdpi:432:192; do
  IFS=: read -r density fg legacy <<<"$entry"
  sips -z "$fg" "$fg" "$tmp/foreground.png" --out "$res/mipmap-$density/ic_launcher_foreground.png" >/dev/null
  sips -z "$legacy" "$legacy" "$tmp/legacy.png" --out "$res/mipmap-$density/ic_launcher.png" >/dev/null
done

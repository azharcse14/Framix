#!/usr/bin/env bash
# Builds the minimal LGPL FFmpeg that P1-059 probes and demuxes with (ADR 0009): demuxers,
# their parsers and three re-wrap bitstream filters; no decoder, encoder, muxer, hwaccel or
# protocol; shared libavformat, libavcodec and libavutil only.
#
# Usage: scripts/build_ffmpeg.sh [target...]        build (default: every target)
#        scripts/build_ffmpeg.sh --print-flags <target>   configure arguments, one per line
#        scripts/build_ffmpeg.sh --check-policy < report  verify a build report (see below)
# Targets: macos-arm64 (host, for cargo test), android-arm64-v8a, android-x86_64, ios-arm64,
# ios-sim-arm64. Once both iOS targets exist, ios-xcframework/ holds one XCFramework per library.
#
# Output: $FFMPEG_OUT/<target>/{lib or frameworks, include, manifest.txt} (default
# third_party/ffmpeg/out, gitignored). manifest.txt keeps the source hash, toolchain and
# configure line for the LGPL source offer (LEG-018). Source and build trees go to
# $FFMPEG_WORK (default third_party/ffmpeg/work); build trees are deleted after each target.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

FFMPEG_VERSION=8.0.3
FFMPEG_SHA256=6136812ea6d4e68bdba27e33c2a94382711cdf4f8602ffef056ff792bd6f9818
FFMPEG_URL=${FFMPEG_URL:-https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz}
NDK_VERSION=28.2.13676358 # r28c, docs/toolchain.md
ANDROID_API=29
IOS_MIN=17.0
LGPL="LGPL version 2.1 or later"
TARGETS="macos-arm64 android-arm64-v8a android-x86_64 ios-arm64 ios-sim-arm64"
LIBS="avutil avcodec avformat" # dependency order
OUT=${FFMPEG_OUT:-$ROOT/third_party/ffmpeg/out}
WORK=${FFMPEG_WORK:-$ROOT/third_party/ffmpeg/work}

die() { echo "✗ build_ffmpeg: $*" >&2; exit 1; }

# ADR 0009 section 3. Any change here must restate why (SYS-024/P1-059).
policy_flags() {
  printf '%s\n' --disable-everything --disable-autodetect --disable-network --disable-programs \
    --disable-doc --disable-avdevice --disable-avfilter --disable-swscale --disable-swresample \
    --disable-static --enable-shared --enable-avformat --enable-avcodec
  # x86 SIMD needs nasm (not installed); a build without decoders gains nothing from it.
  echo --disable-x86asm
  local d
  for d in mov matroska avi mpegts flv ogg wav mp3 aac flac; do echo "--enable-demuxer=$d"; done
  for d in h264 hevc aac ac3 mpegaudio mpegvideo mpeg4video flac vorbis opus vp8 vp9 av1; do
    echo "--enable-parser=$d"
  done
  for d in h264_mp4toannexb hevc_mp4toannexb extract_extradata; do echo "--enable-bsf=$d"; done
}

# Toolchain arguments. Tool names only, never paths: the whole line is compiled into
# avformat_configuration() and ships in the binary. build_target puts the NDK on PATH.
target_flags() {
  case $1 in
    macos-arm64) echo --install-name-dir=@rpath ;;
    android-arm64-v8a) android_flags aarch64 aarch64-linux-android ;;
    android-x86_64) android_flags x86_64 x86_64-linux-android ;;
    ios-arm64) ios_flags iphoneos "arm64-apple-ios$IOS_MIN" ;;
    ios-sim-arm64) ios_flags iphonesimulator "arm64-apple-ios$IOS_MIN-simulator" ;;
    *) die "unknown target '$1' (targets: $TARGETS)" ;;
  esac
}
# Android: configure's android target sets the SONAME to libavX.so (no version), which is what
# the APK packages. 16 KB pages: NDK r28 already defaults to it; stated so it never regresses.
android_flags() {
  printf '%s\n' --enable-cross-compile --target-os=android "--arch=$1" \
    "--cc=$2$ANDROID_API-clang" --nm=llvm-nm --ar=llvm-ar --ranlib=llvm-ranlib \
    --strip=llvm-strip --enable-pic --extra-ldflags=-Wl,-z,max-page-size=16384
}
ios_flags() {
  printf '%s\n' --enable-cross-compile --target-os=darwin --arch=arm64 \
    "--cc=xcrun -sdk $1 clang" "--extra-cflags=--target=$2" "--extra-ldflags=--target=$2" \
    --install-name-dir=@rpath
}
print_flags() { target_flags "$1" >/dev/null && policy_flags && target_flags "$1"; }

# Reads a build report (key=value lines: <lib>_license, configuration, decoders, encoders,
# muxers, protocols, optional hwaccels) and fails unless it meets ADR 0009 section 1 and 3.
check_policy() {
  local report bad=0 lib key v cfg
  report=$(cat)
  val() { grep -m1 "^$1=" <<<"$report" | cut -d= -f2-; }
  has() { grep -q "^$1=" <<<"$report"; }
  for lib in $LIBS; do
    v=$(val "${lib}_license")
    if [ "$v" = "$LGPL" ]; then echo "ok ${lib}_license() = $v"; else echo "✗ ${lib}_license() = '$v'" >&2; bad=1; fi
  done
  cfg=$(val configuration)
  if ! has configuration; then echo "✗ no configuration" >&2; bad=1; fi
  for key in --disable-everything --disable-autodetect --disable-network; do
    grep -Eq -- "(^| )$key( |$)" <<<"$cfg" || { echo "✗ configuration lacks $key" >&2; bad=1; }
  done
  if v=$(grep -Eo -- "(^|[ '])--enable-(gpl|nonfree|version3|lib[a-z0-9_-]*)([ '=]|$)" <<<"$cfg"); then
    echo "✗ forbidden in configuration:" $v >&2; bad=1
  fi
  for key in decoders encoders muxers protocols hwaccels; do
    if ! has $key; then
      [ $key = hwaccels ] && continue
      echo "✗ no $key count" >&2; bad=1
    elif [ "$(val $key)" = 0 ]; then echo "ok $key = 0"
    else echo "✗ $key = $(val $key), want 0" >&2; bad=1; fi
  done
  [ $bad -eq 0 ] && echo "ok configuration: --disable-autodetect, no gpl/nonfree/version3/lib*"
  return $bad
}

# Downloads the pinned tarball and extracts it only after the SHA-256 matches (fail closed).
fetch_source() {
  SRC="$WORK/ffmpeg-$FFMPEG_VERSION"
  local tarball="$WORK/ffmpeg-$FFMPEG_VERSION.tar.xz" sum
  mkdir -p "$WORK"
  if [ ! -f "$tarball" ]; then
    curl -fsSL --retry 3 -o "$tarball.part" "$FFMPEG_URL" || die "download failed: $FFMPEG_URL"
    mv "$tarball.part" "$tarball"
  fi
  sum=$(shasum -a 256 "$tarball" | cut -d' ' -f1)
  if [ "$sum" != "$FFMPEG_SHA256" ]; then
    rm -f "$tarball"
    die "SHA-256 mismatch for $FFMPEG_URL: got $sum, want $FFMPEG_SHA256"
  fi
  if [ ! -f "$SRC/configure" ]; then
    rm -rf "$SRC" "$SRC.tmp" && mkdir "$SRC.tmp"
    tar -xJf "$tarball" -C "$SRC.tmp"
    mv "$SRC.tmp/ffmpeg-$FFMPEG_VERSION" "$SRC" && rmdir "$SRC.tmp"
  fi
}

ndk_dir() {
  local ndk=${ANDROID_NDK_HOME:-${ANDROID_HOME:-$HOME/Library/Android/sdk}/ndk/$NDK_VERSION}
  grep -qx "Pkg.Revision = $NDK_VERSION" "$ndk/source.properties" 2>/dev/null ||
    die "need Android NDK $NDK_VERSION (sdkmanager 'ndk;$NDK_VERSION'); looked in $ndk"
  echo "$ndk"
}

# Build report from what was compiled in (cross targets cannot run the check program).
header_report() {
  local b=$1 lic cfg lib
  lic=$(sed -n 's/^#define FFMPEG_LICENSE "\(.*\)"$/\1/p' "$b/config.h")
  cfg=$(sed -n 's/^#define FFMPEG_CONFIGURATION "\(.*\)"$/\1/p' "$b/config.h")
  for lib in $LIBS; do echo "${lib}_license=$lic"; done
  echo "configuration=$cfg"
  components "$b"
}
components() {
  local kind
  for kind in DECODER ENCODER MUXER PROTOCOL HWACCEL; do
    printf '%ss=%s\n' "$(tr A-Z a-z <<<$kind)" \
      "$(grep -c "^#define CONFIG_[A-Z0-9_]*_$kind 1$" "$1/config_components.h" || true)"
  done
}

# Host build: call the real API, as ADR 0009 section 1 asks.
host_report() {
  local b=$1 stage=$2
  cat >"$b/check.c" <<'EOF'
#include <stdio.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
int main(void) {
  void *it = NULL;
  const AVCodec *c;
  int dec = 0, enc = 0, mux = 0, prot = 0;
  while ((c = av_codec_iterate(&it))) { dec += av_codec_is_decoder(c); enc += av_codec_is_encoder(c); }
  it = NULL; while (av_muxer_iterate(&it)) mux++;
  it = NULL; while (avio_enum_protocols(&it, 0)) prot++;
  it = NULL; while (avio_enum_protocols(&it, 1)) prot++;
  printf("avformat_license=%s\navcodec_license=%s\navutil_license=%s\n",
         avformat_license(), avcodec_license(), avutil_license());
  printf("configuration=%s\ndecoders=%d\nencoders=%d\nmuxers=%d\nprotocols=%d\n",
         avformat_configuration(), dec, enc, mux, prot);
  return 0;
}
EOF
  clang -Wall -Werror -o "$b/check" "$b/check.c" -I"$stage/include" -L"$stage/lib" \
    -lavformat -lavcodec -lavutil -Wl,-rpath,"$stage/lib"
  "$b/check"
  echo "hwaccels=$(grep -c '^#define CONFIG_[A-Z0-9_]*_HWACCEL 1$' "$b/config_components.h" || true)"
}

# The libraries that ship must carry the verified configuration and license strings.
check_binaries() {
  local cfg=$1; shift
  local f
  for f in "$@"; do
    grep -qF -- "$cfg" "$f" || die "$(basename "$f") lacks the verified configuration string"
    grep -qF -- "$LGPL" "$f" || die "$(basename "$f") lacks '$LGPL'"
  done
}

check_android() {
  local readelf=$1 lib f
  for lib in $LIBS; do
    f="lib$lib.so"
    "$readelf" -dW "$f" | grep -q "(SONAME).*\[$f\]" || die "$f: SONAME is not $f"
    if "$readelf" -dW "$f" | grep '(NEEDED)' | grep -q '\.so\.'; then die "$f: versioned NEEDED"; fi
    if "$readelf" -lW "$f" | awk '$1 == "LOAD" && $NF != "0x4000" { bad = 1 } END { exit !bad }'; then
      die "$f: a LOAD segment is not 16 KB aligned"
    fi
    echo "ok $f: SONAME $f, LOAD align 0x4000"
  done
}

# Wraps each dylib as lib<name>.framework with install name @rpath/lib<name>.framework/lib<name>.
make_frameworks() {
  local stage=$1 dest=$2 platform=$3 lib dep dylib ver fw
  mkdir -p "$dest"
  for lib in $LIBS; do
    dylib=$(cd "$stage/lib" && ls lib$lib.*.*.*.dylib)
    ver=${dylib#lib$lib.}; ver=${ver%.dylib}
    fw="$dest/lib$lib.framework"
    mkdir -p "$fw"
    cp "$stage/lib/$dylib" "$fw/lib$lib"
    install_name_tool -id "@rpath/lib$lib.framework/lib$lib" "$fw/lib$lib"
    for dep in $LIBS; do
      local old
      old=$(otool -L "$fw/lib$lib" | awk -v d="@rpath/lib$dep." 'index($1, d) == 1 { print $1 }')
      [ -n "$old" ] && install_name_tool -change "$old" "@rpath/lib$dep.framework/lib$dep" "$fw/lib$lib"
    done
    cat >"$fw/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>lib$lib</string>
  <key>CFBundleIdentifier</key><string>com.travela.framix.ffmpeg.lib$lib</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>lib$lib</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>$ver</string>
  <key>CFBundleVersion</key><string>$ver</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
  <key>MinimumOSVersion</key><string>$IOS_MIN</string>
</dict>
</plist>
EOF
    plutil -lint -s "$fw/Info.plist"
    # install_name_tool voids the linker's ad-hoc signature; Xcode re-signs on embed.
    codesign --force --sign - "$fw" 2>/dev/null
    if otool -L "$fw/lib$lib" | tail -n +2 | grep -q '@rpath/libav[a-z]*\.[0-9]'; then
      die "lib$lib.framework still links a versioned dylib"
    fi
  done
  echo "ok frameworks: @rpath/libX.framework/libX, MinimumOSVersion $IOS_MIN"
}

write_manifest() {
  local t=$1 report=$2 toolchain=$3
  {
    echo "ffmpeg_version=$FFMPEG_VERSION"
    echo "source_url=$FFMPEG_URL"
    echo "source_sha256=$FFMPEG_SHA256"
    echo "source_changes=none (unpatched release tarball)"
    echo "target=$t"
    echo "built_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "build_script=scripts/build_ffmpeg.sh @ $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "$toolchain"
    echo "$report"
  } >"$OUT/$t/manifest.txt"
}

build_target() {
  local t=$1 b="$WORK/build/$1" stage="$WORK/build/$1/stage" flags=() l report cfg toolchain readelf=""
  while IFS= read -r l; do flags+=("$l"); done < <(print_flags "$t")
  echo "▶ FFmpeg $FFMPEG_VERSION for $t"
  rm -rf "$b" && mkdir -p "$b"
  local path=$PATH
  case $t in
    android-*)
      local bin
      bin="$(ndk_dir)/toolchains/llvm/prebuilt/darwin-x86_64/bin"
      path="$bin:$PATH" readelf="$bin/llvm-readelf"
      toolchain="ndk=$NDK_VERSION api=$ANDROID_API
compiler=$("$bin/clang" --version | head -1)" ;;
    ios-*)
      local sdk=iphoneos
      [ "$t" = ios-sim-arm64 ] && sdk=iphonesimulator
      toolchain="xcode=$(xcodebuild -version | tr '\n' ' ')sdk=$sdk $(xcrun --sdk $sdk --show-sdk-version) min_ios=$IOS_MIN
compiler=$(xcrun -sdk $sdk clang --version | head -1)" ;;
    *) toolchain="compiler=$(clang --version | head -1)" ;;
  esac
  (cd "$b" && PATH=$path "$SRC/configure" "${flags[@]}" >configure.log 2>&1) ||
    { tail -20 "$b/ffbuild/config.log" >&2 || true; die "$t: configure failed ($b/configure.log)"; }
  (cd "$b" && PATH=$path make -j"$(sysctl -n hw.ncpu)" >make.log 2>&1 &&
    PATH=$path make install DESTDIR="$b/destdir" >>make.log 2>&1) ||
    { tail -30 "$b/make.log" >&2; die "$t: make failed ($b/make.log)"; }
  mv "$b/destdir/usr/local" "$stage"

  if [ "$t" = macos-arm64 ]; then report=$(host_report "$b" "$stage"); else report=$(header_report "$b"); fi
  echo "$report" | check_policy || die "$t: build breaks ADR 0009"
  cfg=$(grep -m1 '^configuration=' <<<"$report" | cut -d= -f2-)

  rm -rf "$OUT/$t" && mkdir -p "$OUT/$t"
  cp -R "$stage/include" "$OUT/$t/"
  case $t in
    android-*)
      mkdir "$OUT/$t/lib"
      for l in $LIBS; do cp "$stage/lib/lib$l.so" "$OUT/$t/lib/"; done
      (cd "$OUT/$t/lib" && check_android "$readelf" && check_binaries "$cfg" lib*.so) ;;
    ios-*)
      local platform=iPhoneOS
      [ "$t" = ios-sim-arm64 ] && platform=iPhoneSimulator
      make_frameworks "$stage" "$OUT/$t/frameworks" "$platform"
      check_binaries "$cfg" "$OUT/$t"/frameworks/*.framework/lib* ;;
    macos-arm64)
      cp -R "$stage/lib" "$OUT/$t/" && rm -rf "$OUT/$t/lib/pkgconfig"
      check_binaries "$cfg" "$OUT/$t"/lib/libav*.*.*.*.dylib ;;
  esac
  write_manifest "$t" "$report" "$toolchain"
  rm -rf "$b"
  echo "✓ $t -> $OUT/$t"
}

make_xcframeworks() {
  local lib dest="$OUT/ios-xcframework"
  rm -rf "$dest" && mkdir -p "$dest"
  for lib in $LIBS; do
    xcodebuild -create-xcframework -framework "$OUT/ios-arm64/frameworks/lib$lib.framework" \
      -framework "$OUT/ios-sim-arm64/frameworks/lib$lib.framework" \
      -output "$dest/lib$lib.xcframework" >/dev/null
  done
  echo "✓ ios-xcframework -> $dest"
}

case ${1:-} in
  --print-flags) [ $# -eq 2 ] || die "usage: --print-flags <target>"; print_flags "$2"; exit ;;
  --check-policy) check_policy; exit ;;
esac
targets=("$@")
[ $# -gt 0 ] || targets=($TARGETS)
for t in "${targets[@]}"; do target_flags "$t" >/dev/null; done
fetch_source
for t in "${targets[@]}"; do build_target "$t"; done
if [ -d "$OUT/ios-arm64/frameworks" ] && [ -d "$OUT/ios-sim-arm64/frameworks" ]; then make_xcframeworks; fi

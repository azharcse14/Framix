#!/usr/bin/env bash
# Regression test (SYS-069): scripts/build_ffmpeg.sh must configure FFmpeg exactly as ADR 0009
# section 3 allows, reject a build whose license, configuration or components break section 1,
# and refuse a source tarball whose SHA-256 is not the pinned one. A real build takes minutes,
# so this tests the flag list (--print-flags), the verifier (--check-policy, fed fake reports)
# and the hash check (a fake tarball over file://); no network, no compiler.
set -u
src="$(cd "$(dirname "$0")" && pwd)/build_ffmpeg.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
err() { echo "✗ build_ffmpeg_test: $*" >&2; fail=1; }

targets="macos-arm64 android-arm64-v8a android-x86_64 ios-arm64 ios-sim-arm64"
policy="--disable-everything --disable-autodetect --disable-network --disable-programs
--disable-doc --disable-avdevice --disable-avfilter --disable-swscale --disable-swresample
--disable-static --enable-shared --enable-avformat --enable-avcodec
--enable-bsf=h264_mp4toannexb --enable-bsf=hevc_mp4toannexb --enable-bsf=extract_extradata"
for t in $targets; do
  if ! flags=$("$src" --print-flags "$t" 2>&1); then err "$t: --print-flags failed: $flags"; continue; fi
  for f in $policy; do grep -qx -- "$f" <<<"$flags" || err "$t: missing $f"; done
  for d in mov matroska avi mpegts flv ogg wav mp3 aac flac; do
    grep -qx -- "--enable-demuxer=$d" <<<"$flags" || err "$t: missing demuxer $d"
  done
  if bad=$(grep -E -- '^--enable-(gpl|nonfree|version3|lib|encoder|decoder|muxer|hwaccel|protocol|indev|outdev|filter|avdevice|avfilter|swscale|swresample|static|programs|network|autodetect)' <<<"$flags"); then
    err "$t: forbidden flags: $bad"
  fi
  # The configure line is compiled into avformat_configuration(): no local paths in it.
  grep -qF -- "$HOME" <<<"$flags" && err "$t: flags contain \$HOME"
  case $t in
    android-*)
      grep -qx -- '--target-os=android' <<<"$flags" || err "$t: not --target-os=android (unversioned SONAME)"
      grep -q -- '^--extra-ldflags=.*-Wl,-z,max-page-size=16384' <<<"$flags" || err "$t: no 16 KB page size"
      grep -q -- '^--cc=.*-linux-android29-clang$' <<<"$flags" || err "$t: not API 29 clang" ;;
    ios-*)
      grep -qx -- '--install-name-dir=@rpath' <<<"$flags" || err "$t: install name not @rpath"
      grep -q -- 'ios17\.0' <<<"$flags" || err "$t: minimum iOS is not 17.0" ;;
    macos-*)
      grep -qx -- '--install-name-dir=@rpath' <<<"$flags" || err "$t: install name not @rpath" ;;
  esac
done
grep -q -- '-simulator' <<<"$("$src" --print-flags ios-sim-arm64 2>/dev/null)" || err "ios-sim-arm64: not a simulator target"
grep -q -- '-simulator' <<<"$("$src" --print-flags ios-arm64 2>/dev/null)" && err "ios-arm64: simulator target"
"$src" --print-flags windows-x86 >/dev/null 2>&1 && err "unknown target accepted"

# Verifier: a report as the build produces it; each case breaks one rule.
lgpl="LGPL version 2.1 or later"
good_config="--disable-everything --disable-autodetect --disable-network --enable-shared --enable-demuxer=mov --extra-ldflags='-Wl,-z,max-page-size=16384'"
report() { # report <license> <configuration> <decoders> <muxers> <protocols>
  printf 'avformat_license=%s\navcodec_license=%s\navutil_license=%s\nconfiguration=%s\n' "$1" "$1" "$1" "$2"
  printf 'decoders=%s\nencoders=0\nmuxers=%s\nprotocols=%s\nhwaccels=0\n' "$3" "$4" "$5"
}
expect() { # expect <name> <pass|fail> <report>
  local got=pass
  "$src" --check-policy <<<"$3" >/dev/null 2>&1 || got=fail
  [ "$got" = "$2" ] || err "--check-policy $1: got $got, want $2"
}
expect "good build" pass "$(report "$lgpl" "$good_config" 0 0 0)"
expect "GPL license" fail "$(report "GPL version 2 or later" "$good_config" 0 0 0)"
expect "LGPL 3 license" fail "$(report "LGPL version 3 or later" "$good_config" 0 0 0)"
expect "one library GPL" fail "$(report "$lgpl" "$good_config" 0 0 0 | sed 's/^avcodec_license=.*/avcodec_license=GPL version 2 or later/')"
for f in --enable-gpl --enable-nonfree --enable-version3 --enable-libx264 --enable-libdav1d; do
  expect "$f" fail "$(report "$lgpl" "$good_config $f" 0 0 0)"
done
expect "no --disable-autodetect" fail "$(report "$lgpl" "${good_config/--disable-autodetect /}" 0 0 0)"
expect "a decoder" fail "$(report "$lgpl" "$good_config" 1 0 0)"
expect "a muxer" fail "$(report "$lgpl" "$good_config" 0 2 0)"
expect "a protocol" fail "$(report "$lgpl" "$good_config" 0 0 1)"
expect "missing license line" fail "$(report "$lgpl" "$good_config" 0 0 0 | grep -v '^avutil_license=')"
expect "missing decoder count" fail "$(report "$lgpl" "$good_config" 0 0 0 | grep -v '^decoders=')"
expect "empty report" fail ""

# A tarball whose hash is not the pinned one is never extracted or configured.
mkdir -p "$tmp/fake/ffmpeg-x"
printf '#!/bin/sh\ntouch "%s/configured"\n' "$tmp" >"$tmp/fake/ffmpeg-x/configure"
chmod +x "$tmp/fake/ffmpeg-x/configure"
tar -cJf "$tmp/fake.tar.xz" -C "$tmp/fake" ffmpeg-x
if out=$(FFMPEG_URL="file://$tmp/fake.tar.xz" FFMPEG_WORK="$tmp/work" FFMPEG_OUT="$tmp/out" \
  "$src" macos-arm64 2>&1); then
  err "build passed with a tarball that does not match the pinned SHA-256"
fi
grep -qi 'sha-256' <<<"$out" || err "hash failure not reported: $out"
[ -e "$tmp/configured" ] && err "configure ran from an unverified tarball"
[ -n "$(find "$tmp/work" -name configure 2>/dev/null)" ] && err "unverified tarball was extracted"
[ -e "$tmp/out" ] && [ -n "$(ls -A "$tmp/out")" ] && err "output written from an unverified tarball"

[ $fail -eq 0 ] && echo "✓ build_ffmpeg_test"
exit $fail

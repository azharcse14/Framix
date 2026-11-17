#!/usr/bin/env bash
# Regression test (SYS-057): gen_ffi.sh must run protoc-gen-dart on the pinned Dart through
# `pub global run`, never through the ~/.pub-cache/bin shim (it runs a snapshot named after
# whichever Dart last wrote it, so the pinned Dart printed "Can't load Kernel binary: Invalid
# SDK hash." on every run), and must fail when protoc or its plugin prints anything on stderr.
# The pinned protoc_plugin version check stays. Runs on a copy with fake fvm, dart, and tools.
set -u
src="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/bin" "$tmp/sdk/bin" "$tmp/app" "$tmp/home/.pub-cache/bin"
cp "$src"/gen_ffi.sh "$src"/flutter_sdk.sh "$src"/app_lock.sh "$tmp/scripts/"
[ -f "$src/protoc_gen_dart.sh" ] && cp "$src/protoc_gen_dart.sh" "$tmp/scripts/"
printf '{\n  "flutter": "1.2.3"\n}\n' >"$tmp/.fvmrc"
log="$tmp/dart.log"

cat >"$tmp/bin/fvm" <<EOF
#!/bin/sh
[ "\$1" = dart ] && { shift; exec "$tmp/sdk/bin/dart" "\$@"; }
echo '  "frameworkVersion": "1.2.3",'
echo '  "flutterRoot": "$tmp/sdk",'
EOF
# The pinned Dart. A snapshot from another SDK fails the way the real VM does (exit 253).
cat >"$tmp/sdk/bin/dart" <<EOF
#!/bin/sh
echo "\$*" >>"$log"
case "\$*" in
  "pub global list") echo "protoc_plugin \${FAKE_PLUGIN_VERSION:-25.1.0}" ;;
  *.snapshot*) echo "Can't load Kernel binary: Invalid SDK hash." >&2; exit 253 ;;
  "pub global run protoc_plugin:protoc_plugin"*) cat >/dev/null; [ -z "\${FAKE_PLUGIN_STDERR:-}" ] || echo "\$FAKE_PLUGIN_STDERR" >&2 ;;
esac
exit 0
EOF
# Another SDK's bare dart on PATH: the plugin must never run on it.
printf '#!/bin/sh\necho "other $*" >>"%s"\nexit 1\n' "$log" >"$tmp/bin/dart"
# The pub binstub as another Dart wrote it (the real one, trimmed).
cat >"$tmp/home/.pub-cache/bin/protoc-gen-dart" <<'EOF'
#!/usr/bin/env sh
dart "/pub-cache/global_packages/protoc_plugin/bin/protoc_plugin.dart-9.9.9.snapshot" "$@"
[ $? != 253 ] && exit $?
dart pub global run protoc_plugin:protoc_plugin "$@"
EOF
printf '#!/bin/sh\n[ "$1" = --version ] && echo "cbindgen 0.29.4"\nexit 0\n' >"$tmp/bin/cbindgen"
# protoc runs the plugin given by --plugin=protoc-gen-dart=<path>, else protoc-gen-dart on PATH.
cat >"$tmp/bin/protoc" <<'EOF'
#!/bin/sh
[ "$1" = --version ] && { echo "libprotoc 36.2"; exit 0; }
plugin=protoc-gen-dart
for a in "$@"; do case "$a" in --plugin=protoc-gen-dart=*) plugin=${a#--plugin=protoc-gen-dart=} ;; esac; done
echo request | "$plugin"
EOF
chmod +x "$tmp/bin/"* "$tmp/sdk/bin/dart" "$tmp/home/.pub-cache/bin/protoc-gen-dart"

fail=0
expect() { [ "$2" = "$3" ] || { echo "✗ gen_ffi_test: $1: got '$2', want '$3'" >&2; fail=1; }; }
gen() { : >"$log"; HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" "$tmp/scripts/gen_ffi.sh" 2>"$tmp/err" >/dev/null && echo ok || echo FAIL; }

expect "clean run" "$(gen)" ok
expect "clean run prints nothing on stderr" "$(cat "$tmp/err")" ""
expect "plugin never runs a snapshot or another SDK's dart" "$(grep -c -e '\.snapshot' -e '^other ' "$log")" 0
expect "plugin runs through the pinned dart's pub global run" \
  "$(grep -q '^pub global run protoc_plugin:protoc_plugin' "$log" && echo yes)" yes

expect "plugin stderr fails the run" "$(FAKE_PLUGIN_STDERR="Can't load Kernel binary: Invalid SDK hash." gen)" FAIL
expect "plugin stderr is shown" "$(grep -q 'Invalid SDK hash' "$tmp/err" && echo yes)" yes

expect "other protoc_plugin version" "$(FAKE_PLUGIN_VERSION=25.0.0 gen)" FAIL


# SYS-061: the warm-up run. On a pinned SDK with no snapshot yet, the first plugin run has pub
# print "Resolving dependencies..." on stdout; protoc would parse that as the plugin's reply and
# fail. The fake plugin does that once per SDK (marker file), and the fake protoc rejects any
# reply other than the one for its request, as the real one does.
cat >"$tmp/sdk/bin/dart" <<EOF
#!/bin/sh
echo "\$*" >>"$log"
case "\$*" in
  "pub global list") echo "protoc_plugin 25.1.0" ;;
  "pub global run protoc_plugin:protoc_plugin"*)
    [ -e "$tmp/sdk/snapshot" ] || { echo "Resolving dependencies..."; : >"$tmp/sdk/snapshot"; }
    [ -z "\$(cat)" ] || echo response ;;
esac
exit 0
EOF
cat >"$tmp/bin/protoc" <<'EOF'
#!/bin/sh
[ "$1" = --version ] && { echo "libprotoc 36.2"; exit 0; }
[ -z "${FAKE_PROTOC_EXIT:-}" ] || { [ -z "${FAKE_PROTOC_STDERR:-}" ] || echo "$FAKE_PROTOC_STDERR" >&2; exit "$FAKE_PROTOC_EXIT"; }
for a in "$@"; do case "$a" in --plugin=protoc-gen-dart=*) plugin=${a#--plugin=protoc-gen-dart=} ;; esac; done
[ "$(echo request | "$plugin")" = response ] || { echo "--dart_out: protoc-gen-dart: Plugin output is unparseable." >&2; exit 1; }
EOF
rm -f "$tmp/sdk/snapshot"
expect "first run on an SDK without a plugin snapshot" "$(gen)" ok
expect "first run prints nothing on stderr" "$(cat "$tmp/err")" ""
expect "second run" "$(gen)" ok

# SYS-061: protoc failing silently (non-zero exit, empty stderr) must still fail the run.
expect "protoc exits non-zero without stderr" "$(FAKE_PROTOC_EXIT=1 gen)" FAIL
expect "protoc non-zero exit fails the run" \
  "$(FAKE_PROTOC_EXIT=3 FAKE_PROTOC_STDERR="proto/framix/v1/engine.proto: syntax error" gen)" FAIL
expect "protoc stderr is shown" "$(grep -q 'syntax error' "$tmp/err" && echo yes)" yes

# SYS-064: a warm-up that fails silently (non-zero exit, empty stderr) must fail the run, even
# when the protoc run after it would succeed. The plugin fails only on the empty warm-up request.
cat >"$tmp/sdk/bin/dart" <<EOF
#!/bin/sh
case "\$*" in
  "pub global list") echo "protoc_plugin 25.1.0" ;;
  "pub global run protoc_plugin:protoc_plugin"*) [ -n "\$(cat)" ] || exit \${FAKE_WARMUP_EXIT:-1}; echo response ;;
esac
exit 0
EOF
expect "warm-up control: same fakes, warm-up exits 0" "$(FAKE_WARMUP_EXIT=0 gen)" ok
expect "warm-up exits non-zero without stderr" "$(gen)" FAIL

[ $fail -eq 0 ] && echo "✓ gen_ffi_test"
exit $fail

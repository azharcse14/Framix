#!/usr/bin/env bash
# Regression test (SYS-059): a failed protoc run in gen_ffi.sh must leave the committed Dart
# Protobuf files in place. It used to delete app/lib/core/engine/proto first, so one failure
# (protoc-gen-dart output broken by pub's "Resolving dependencies...") left them deleted:
# `git diff` showed them removed and every later reader (analyze, codegen_lock_test) saw
# engine.pb.dart missing. Runs gen_ffi.sh with a fake protoc that fails to generate, under the
# app lock (so no concurrent check sees the test's own changes), and restores the dir after.
set -u
cd "$(dirname "$0")/.." || exit 1
[ -n "${FRAMIX_APP_LOCK:-}" ] || exec scripts/app_lock.sh scripts/gen_ffi_failure_test.sh
proto=app/lib/core/engine/proto
pb=$proto/framix/v1/engine.pb.dart
tmp=$(mktemp -d)
cp -Rp "$proto" "$tmp/proto"
trap 'rm -rf "$proto" && cp -Rp "$tmp/proto" "$proto"; rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
cat >"$tmp/bin/protoc" <<'EOF'
#!/bin/sh
[ "$1" = --version ] && { echo "libprotoc 36.2"; exit 0; }
echo "--dart_out: protoc-gen-dart: Plugin output is unparseable (fake protoc)" >&2
exit 1
EOF
chmod +x "$tmp/bin/protoc"

if PATH="$tmp/bin:$PATH" scripts/gen_ffi.sh >/dev/null 2>&1; then
  echo "✗ gen_ffi_failure_test: gen_ffi.sh passed although protoc failed" >&2
  exit 1
fi
if ! cmp -s "$pb" "$tmp/proto/framix/v1/engine.pb.dart"; then
  echo "✗ gen_ffi_failure_test: a failed protoc run left $pb missing or changed" >&2
  exit 1
fi
echo "✓ gen_ffi_failure_test"

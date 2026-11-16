#!/usr/bin/env bash
# Regression test (SYS-047): gen_ffi.sh must hold the per-checkout app lock that
# flutter_test.sh holds. It deletes and rewrites app/lib/core/engine/proto, so a `flutter test`
# or `flutter analyze` beside it read "engine.pb.dart: No such file or directory".
# This runs gen_ffi.sh and, alongside it, a reader that takes the same lock the way
# flutter_test.sh does; the reader must never see the generated file missing.
set -u
cd "$(dirname "$0")/.." || exit 1
lock_file="$PWD/app/.dart_tool/flutter_test.lock"
pb=app/lib/core/engine/proto/framix/v1/engine.pb.dart
mkdir -p app/.dart_tool
if command -v lockf >/dev/null 2>&1; then locked=(lockf -k "$lock_file"); else locked=(flock "$lock_file"); fi

scripts/gen_ffi.sh >/dev/null & gen=$!
missing=0
while kill -0 "$gen" 2>/dev/null; do
  "${locked[@]}" test -f "$pb" || missing=$((missing + 1))
  sleep 0.01
done
wait "$gen" || { echo "✗ codegen_lock_test: gen_ffi.sh failed" >&2; exit 1; }
if [ "$missing" -ne 0 ]; then
  echo "✗ codegen_lock_test: a locked reader saw $pb missing $missing time(s) during gen_ffi.sh" >&2
  exit 1
fi
echo "✓ codegen_lock_test"

#!/usr/bin/env bash
# Regression test (SYS-059): protoc in gen_ffi.sh runs under the app lock and writes into a temp
# dir, so a run that fails halfway (here: a partial engine.pb.dart, then exit 1) leaves the
# committed proto dir byte-identical. A fake protoc on PATH checks the lock is held (a
# non-blocking lock attempt must fail), records that it ran, and writes the partial file into
# its --dart_out. Not run under the lock itself (that would make the check vacuous); the backup
# and restore take it.
set -u
cd "$(dirname "$0")/.." || exit 1
proto=app/lib/core/engine/proto
lock_file="$PWD/app/.dart_tool/flutter_test.lock"
tmp=$(mktemp -d)
scripts/app_lock.sh cp -Rp "$proto" "$tmp/proto" || exit 1
trap 'scripts/app_lock.sh sh -c "rm -rf \"\$1\" && cp -Rp \"\$2\" \"\$1\"" sh "$proto" "$tmp/proto"; rm -rf "$tmp"' EXIT
if command -v lockf >/dev/null 2>&1; then try_lock="lockf -t 0 -k"; else try_lock="flock -n"; fi
mkdir "$tmp/bin"
cat >"$tmp/bin/protoc" <<EOF
#!/bin/sh
[ "\$1" = --version ] && { echo "libprotoc 36.2"; exit 0; }
if $try_lock "$lock_file" true 2>/dev/null; then echo unlocked >"$tmp/marker"; else echo locked >"$tmp/marker"; fi
for a in "\$@"; do case "\$a" in --dart_out=*) out=\${a#--dart_out=} ;; esac; done
mkdir -p "\$out/framix/v1" && printf '// partial\n' >"\$out/framix/v1/engine.pb.dart"
exit 1
EOF
chmod +x "$tmp/bin/protoc"

fail=0
expect() { [ "$2" = "$3" ] || { echo "✗ gen_ffi_partial_test: $1: got '$2', want '$3'" >&2; fail=1; }; }
expect "gen_ffi.sh fails when protoc fails" \
  "$(PATH="$tmp/bin:$PATH" scripts/gen_ffi.sh >/dev/null 2>&1 && echo ok || echo FAIL)" FAIL
expect "protoc ran under the app lock" "$(cat "$tmp/marker" 2>/dev/null || echo 'never ran')" locked
expect "proto dir unchanged" "$(diff -r "$tmp/proto" "$proto" >/dev/null 2>&1 && echo same || echo changed)" same
[ $fail -eq 0 ] && echo "✓ gen_ffi_partial_test"
exit $fail

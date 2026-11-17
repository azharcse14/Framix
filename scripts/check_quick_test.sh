#!/usr/bin/env bash
# Regression test (SYS-055): check.sh --quick must still see engine/ as touched when the
# changed-file list is large. touched() piped the list into `grep -q` under pipefail; grep
# exits at the first match, the writer gets SIGPIPE (141), and every step was skipped while
# check.sh printed "all checks passed". Runs check.sh on a temp repo with stub tools.
set -u
src="$(cd "$(dirname "$0")" && pwd)/check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/bin" "$tmp/engine"
cp "$src" "$tmp/scripts/"
printf 'raise SystemExit(0)\n' >"$tmp/scripts/task.py"
printf '#!/bin/sh\nexit 0\n' | tee "$tmp/scripts/gen_ffi.sh" >"$tmp/scripts/app_lock.sh"
printf '#!/bin/sh\necho "$*" >>"%s/cargo.log"\n' "$tmp" >"$tmp/bin/cargo"
chmod +x "$tmp/scripts/"*.sh "$tmp/bin/cargo"
touch "$tmp/engine/Cargo.toml"
git -C "$tmp" init -q -b main
git -C "$tmp" add -A
git -C "$tmp" -c user.name=t -c user.email=t@t commit -qm init
fail=0

# The engine/ change sorts first; well over a pipe buffer (64 KiB) of paths follows it.
echo x >"$tmp/engine/lib.rs"
mkdir "$tmp/zz"
name=$(printf 'f%.0s' $(seq 200))
for i in $(seq 600); do : >"$tmp/zz/$i$name"; done

out=$(PATH="$tmp/bin:$PATH" "$tmp/scripts/check.sh" --quick 2>&1)
if ! grep -q '^fmt' "$tmp/cargo.log" 2>/dev/null; then
  echo "✗ check_quick_test: large changed list: engine/ not seen as touched (cargo never ran)" >&2
  printf '%s\n' "$out" | tail -5 >&2
  fail=1
fi

[ $fail -eq 0 ] && echo "✓ check_quick_test"
exit $fail

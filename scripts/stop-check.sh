#!/usr/bin/env bash
# Claude Code Stop hook: refuse to finish while checks fail.
# Exit 2 sends stderr back to Claude; stop_hook_active prevents an endless loop.
input=$(cat)
active=$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(str(json.load(sys.stdin).get("stop_hook_active", False)).lower())
except Exception: print("false")')
[ "$active" = "true" ] && exit 0
dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
if ! out=$("$dir"/scripts/check.sh --quick 2>&1); then
  echo "Checks failed. Fix before finishing (task stays in_progress):" >&2
  printf '%s\n' "$out" | tail -40 >&2
  exit 2
fi
exit 0

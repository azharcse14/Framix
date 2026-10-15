#!/usr/bin/env bash
# Regenerates every FFI artifact: C header (cbindgen) and Dart bindings (ffigen).
# check.sh runs this and fails if any output differs from what is committed.
# Protobuf codegen joins with P1-006.
set -euo pipefail
cd "$(dirname "$0")/.."

CBINDGEN_VERSION=0.29.4
if [ "$(cbindgen --version 2>/dev/null)" != "cbindgen $CBINDGEN_VERSION" ]; then
  echo "need cbindgen $CBINDGEN_VERSION: cargo install cbindgen --version $CBINDGEN_VERSION --locked" >&2
  exit 1
fi
if command -v fvm >/dev/null 2>&1; then DART=(fvm dart); else DART=(dart); fi

cbindgen --quiet --config engine/ffi/cbindgen.toml --crate framix_ffi \
  --output engine/ffi/include/framix_engine.h engine/ffi
# A declaration ffigen can't bind is only reported as a warning and silently left out.
out=$(cd app && "${DART[@]}" run ffigen --config ffigen.yaml 2>&1)
if grep -E '\[(WARNING|SEVERE)\]' <<<"$out" >&2; then exit 1; fi

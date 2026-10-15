#!/usr/bin/env bash
# Regenerates every FFI artifact: C header (cbindgen) and Dart bindings (ffigen).
# Protobuf codegen joins with P1-006.
set -euo pipefail
cd "$(dirname "$0")/.."

cbindgen --config engine/ffi/cbindgen.toml --crate framix_ffi \
  --output engine/ffi/include/framix_engine.h engine/ffi
(cd app && dart run ffigen --config ffigen.yaml)

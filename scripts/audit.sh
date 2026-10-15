#!/usr/bin/env bash
# Security audit: known advisories in Rust crates (cargo audit, fails on a vulnerability) and
# outdated Dart packages (report only). Needs the network, so check.sh does not run it.
# GitHub Dependabot alerts are a repository setting, enabled by the owner on GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."

CARGO_AUDIT_VERSION=0.22.2
if [ "$(cargo-audit --version 2>/dev/null)" != "cargo-audit $CARGO_AUDIT_VERSION" ]; then
  echo "need cargo-audit $CARGO_AUDIT_VERSION: cargo install cargo-audit --version $CARGO_AUDIT_VERSION --locked" >&2
  exit 1
fi
if command -v fvm >/dev/null 2>&1; then DART=(fvm dart); else DART=(dart); fi

echo "▶ cargo audit"
cargo audit --file engine/Cargo.lock
echo "▶ (app) dart pub outdated"
(cd app && "${DART[@]}" pub outdated)

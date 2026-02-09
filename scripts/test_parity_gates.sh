#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> semantic parity"
scripts/test_semantic_parity.sh

echo "==> demo roundtrip regression"
scripts/test_demo_roundtrip.sh

echo "All parity gates passed."

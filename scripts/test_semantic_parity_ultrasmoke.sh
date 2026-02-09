#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SKIP_PARITY_FINGERPRINT_CHECK=1 scripts/test_semantic_parity_fast.sh --skip-validate "$@"

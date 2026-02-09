#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PARITY_JSON_REPORT="${PARITY_JSON_REPORT:-_build/semantic_parity/report.json}"

echo "==> semantic parity"
scripts/test_semantic_parity.sh --json-report "$PARITY_JSON_REPORT"
python3 scripts/semantic_parity_report_summary.py "$PARITY_JSON_REPORT"

echo "==> demo roundtrip regression"
scripts/test_demo_roundtrip.sh

echo "All parity gates passed."

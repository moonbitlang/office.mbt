#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_PATH="${SEMANTIC_PARITY_REPORT:-_build/semantic_parity/report.json}"

scripts/test_semantic_parity.sh --json-report "$REPORT_PATH" "$@"
python3 scripts/semantic_parity_report_summary.py "$REPORT_PATH" --as-json --compact

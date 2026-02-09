#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PARITY_JSON_REPORT="${PARITY_JSON_REPORT:-_build/semantic_parity/report.json}"
SKIP_PREFLIGHT="${SKIP_PARITY_WRAPPER_PREFLIGHT:-0}"

echo "Parity gate configuration:"
echo "- PARITY_JSON_REPORT=${PARITY_JSON_REPORT}"
echo "- SKIP_PARITY_WRAPPER_PREFLIGHT=${SKIP_PREFLIGHT}"
echo "- SHOW_PARITY_ENV=${SHOW_PARITY_ENV:-0}"
echo "- SEMANTIC_PARITY_ARGS=${SEMANTIC_PARITY_ARGS:-<unset>}"
echo "- SEMANTIC_PARITY_SUMMARY_ARGS=${SEMANTIC_PARITY_SUMMARY_ARGS:-<unset>}"

if [[ "$SKIP_PREFLIGHT" == "1" ]]; then
  echo "==> parity wrapper preflight (skipped)"
else
  echo "==> parity wrapper preflight"
  scripts/check_parity_wrappers.sh
fi

echo "==> semantic parity"
scripts/test_semantic_parity.sh --json-report "$PARITY_JSON_REPORT"
python3 scripts/semantic_parity_report_summary.py "$PARITY_JSON_REPORT"

echo "==> demo roundtrip regression"
scripts/test_demo_roundtrip.sh

echo "All parity gates passed."

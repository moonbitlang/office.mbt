#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_PATH="${SEMANTIC_PARITY_REPORT:-_build/semantic_parity/report.json}"
SUMMARY_ARGS="${SEMANTIC_PARITY_SUMMARY_ARGS:-}"

scripts/test_semantic_parity.sh --json-report "$REPORT_PATH" "$@"
if [[ -n "$SUMMARY_ARGS" ]]; then
  # Intentionally split env-provided args for flexible CI templating.
  # shellcheck disable=SC2206
  EXTRA_SUMMARY_ARGS=($SUMMARY_ARGS)
  python3 scripts/semantic_parity_report_summary.py "$REPORT_PATH" --as-json --compact "${EXTRA_SUMMARY_ARGS[@]}"
else
  python3 scripts/semantic_parity_report_summary.py "$REPORT_PATH" --as-json --compact
fi

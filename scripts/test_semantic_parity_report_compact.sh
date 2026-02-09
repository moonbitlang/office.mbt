#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_PATH="${SEMANTIC_PARITY_REPORT:-_build/semantic_parity/report.json}"
SUMMARY_ARGS="${SEMANTIC_PARITY_SUMMARY_ARGS:-}"
PARITY_ARGS="${SEMANTIC_PARITY_ARGS:-}"
REDACT_SUMMARY="${REDACT_PARITY_SUMMARY:-0}"

if [[ -n "$PARITY_ARGS" ]]; then
  # Intentionally split env-provided args for flexible CI templating.
  # shellcheck disable=SC2206
  EXTRA_PARITY_ARGS=($PARITY_ARGS)
  scripts/test_semantic_parity.sh --json-report "$REPORT_PATH" "${EXTRA_PARITY_ARGS[@]}" "$@"
else
  scripts/test_semantic_parity.sh --json-report "$REPORT_PATH" "$@"
fi
BASE_SUMMARY_ARGS=(--as-json --compact)
if [[ "$REDACT_SUMMARY" == "1" ]]; then
  BASE_SUMMARY_ARGS+=(--redact-sensitive)
fi

if [[ -n "$SUMMARY_ARGS" ]]; then
  # Intentionally split env-provided args for flexible CI templating.
  # shellcheck disable=SC2206
  EXTRA_SUMMARY_ARGS=($SUMMARY_ARGS)
  python3 scripts/semantic_parity_report_summary.py "$REPORT_PATH" "${BASE_SUMMARY_ARGS[@]}" "${EXTRA_SUMMARY_ARGS[@]}"
else
  python3 scripts/semantic_parity_report_summary.py "$REPORT_PATH" "${BASE_SUMMARY_ARGS[@]}"
fi

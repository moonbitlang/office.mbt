#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PARITY_JSON_REPORT="${PARITY_JSON_REPORT:-_build/semantic_parity/report.json}"
SKIP_PREFLIGHT="${SKIP_PARITY_WRAPPER_PREFLIGHT:-0}"
SKIP_DOCS_PREFLIGHT="${SKIP_PARITY_DOCS_PREFLIGHT:-0}"
SKIP_DOCS_COVERAGE_PREFLIGHT="${SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT:-0}"
SKIP_ENV_HELPER_PREFLIGHT="${SKIP_PARITY_ENV_HELPER_PREFLIGHT:-0}"
SKIP_PREFLIGHT_STATUS_HELPER_PREFLIGHT="${SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT:-0}"
SHOW_PREFLIGHT_STATUS="${SHOW_PARITY_PREFLIGHT_STATUS:-0}"

echo "Parity gate configuration:"
echo "- PARITY_JSON_REPORT=${PARITY_JSON_REPORT}"
echo "- SKIP_PARITY_WRAPPER_PREFLIGHT=${SKIP_PREFLIGHT}"
echo "- SKIP_PARITY_DOCS_PREFLIGHT=${SKIP_DOCS_PREFLIGHT}"
echo "- SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT=${SKIP_DOCS_COVERAGE_PREFLIGHT}"
echo "- SKIP_PARITY_ENV_HELPER_PREFLIGHT=${SKIP_ENV_HELPER_PREFLIGHT}"
echo "- SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT=${SKIP_PREFLIGHT_STATUS_HELPER_PREFLIGHT}"
echo "- SHOW_PARITY_PREFLIGHT_STATUS=${SHOW_PREFLIGHT_STATUS}"
echo "- SHOW_PARITY_ENV=${SHOW_PARITY_ENV:-0}"
echo "- SEMANTIC_PARITY_ARGS=${SEMANTIC_PARITY_ARGS:-<unset>}"
echo "- SEMANTIC_PARITY_SUMMARY_ARGS=${SEMANTIC_PARITY_SUMMARY_ARGS:-<unset>}"

case "$SHOW_PREFLIGHT_STATUS" in
  0)
    ;;
  1)
    echo "==> preflight status resolution"
    scripts/show_parity_preflight_status.sh
    ;;
  json)
    echo "==> preflight status resolution (json)"
    scripts/show_parity_preflight_status.sh --json
    ;;
  *)
    echo "Invalid SHOW_PARITY_PREFLIGHT_STATUS=${SHOW_PREFLIGHT_STATUS} (expected 0, 1, or json)"
    exit 2
    ;;
esac

if [[ "$SKIP_PREFLIGHT" == "1" ]]; then
  echo "==> parity wrapper preflight (skipped)"
else
  echo "==> parity wrapper preflight"
  scripts/check_parity_wrappers.sh
fi

if [[ "$SKIP_ENV_HELPER_PREFLIGHT" == "1" ]]; then
  echo "==> parity env helper preflight (skipped)"
else
  echo "==> parity env helper preflight"
  scripts/check_parity_env_helper.sh
fi

if [[ "$SKIP_PREFLIGHT_STATUS_HELPER_PREFLIGHT" == "1" ]]; then
  echo "==> parity preflight-status helper preflight (skipped)"
else
  echo "==> parity preflight-status helper preflight"
  scripts/check_parity_preflight_status_helper.sh
fi

if [[ "$SKIP_DOCS_PREFLIGHT" == "1" ]]; then
  echo "==> parity docs preflight (skipped)"
else
  echo "==> parity docs preflight"
  scripts/check_parity_docs_refs.sh
  if [[ "$SKIP_DOCS_COVERAGE_PREFLIGHT" == "1" ]]; then
    echo "==> parity docs wrapper coverage preflight (skipped)"
  else
    echo "==> parity docs wrapper coverage preflight"
    scripts/check_parity_docs_wrapper_coverage.sh
  fi
fi

echo "==> semantic parity"
scripts/test_semantic_parity.sh --json-report "$PARITY_JSON_REPORT"
python3 scripts/semantic_parity_report_summary.py "$PARITY_JSON_REPORT"

echo "==> demo roundtrip regression"
scripts/test_demo_roundtrip.sh

echo "All parity gates passed."

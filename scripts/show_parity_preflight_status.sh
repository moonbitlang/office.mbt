#!/usr/bin/env bash
set -euo pipefail

json_mode=0
if [[ "${1:-}" == "--json" ]]; then
  json_mode=1
  shift
fi
if [[ $# -ne 0 ]]; then
  echo "Usage: scripts/show_parity_preflight_status.sh [--json]"
  exit 2
fi

skip_wrapper="${SKIP_PARITY_WRAPPER_PREFLIGHT:-0}"
skip_docs="${SKIP_PARITY_DOCS_PREFLIGHT:-0}"
skip_docs_coverage="${SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT:-0}"
skip_env_helper="${SKIP_PARITY_ENV_HELPER_PREFLIGHT:-0}"
skip_preflight_status_helper="${SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT:-0}"

wrapper_status="enabled"
if [[ "$skip_wrapper" == "1" ]]; then
  wrapper_status="skipped"
fi

docs_status="enabled"
if [[ "$skip_docs" == "1" ]]; then
  docs_status="skipped"
fi

docs_coverage_status="enabled"
if [[ "$skip_docs" == "1" ]]; then
  docs_coverage_status="n/a (docs preflight skipped)"
elif [[ "$skip_docs_coverage" == "1" ]]; then
  docs_coverage_status="skipped"
fi

env_helper_status="enabled"
if [[ "$skip_env_helper" == "1" ]]; then
  env_helper_status="skipped"
fi

preflight_status_helper_status="enabled"
if [[ "$skip_preflight_status_helper" == "1" ]]; then
  preflight_status_helper_status="skipped"
fi

if [[ $json_mode -eq 1 ]]; then
  printf '{\n'
  printf '  "wrapper_preflight": "%s",\n' "$wrapper_status"
  printf '  "env_helper_preflight": "%s",\n' "$env_helper_status"
  printf '  "preflight_status_helper_preflight": "%s",\n' "$preflight_status_helper_status"
  printf '  "docs_preflight": "%s",\n' "$docs_status"
  printf '  "docs_wrapper_coverage_preflight": "%s",\n' "$docs_coverage_status"
  printf '  "env": {\n'
  printf '    "SKIP_PARITY_WRAPPER_PREFLIGHT": "%s",\n' "$skip_wrapper"
  printf '    "SKIP_PARITY_ENV_HELPER_PREFLIGHT": "%s",\n' "$skip_env_helper"
  printf '    "SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT": "%s",\n' "$skip_preflight_status_helper"
  printf '    "SKIP_PARITY_DOCS_PREFLIGHT": "%s",\n' "$skip_docs"
  printf '    "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT": "%s"\n' "$skip_docs_coverage"
  printf '  }\n'
  printf '}\n'
  exit 0
fi

echo "Parity aggregate preflight resolution:"
echo "- wrapper preflight: ${wrapper_status}"
echo "- env helper preflight: ${env_helper_status}"
echo "- preflight-status helper preflight: ${preflight_status_helper_status}"
echo "- docs preflight: ${docs_status}"
echo "- docs wrapper coverage preflight: ${docs_coverage_status}"

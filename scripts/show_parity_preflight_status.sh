#!/usr/bin/env bash
set -euo pipefail

json_mode=0
compact_mode=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      json_mode=1
      ;;
    --compact)
      compact_mode=1
      ;;
    *)
      echo "Usage: scripts/show_parity_preflight_status.sh [--json [--compact]]"
      exit 2
      ;;
  esac
  shift
done
if [[ $compact_mode -eq 1 && $json_mode -ne 1 ]]; then
  echo "Usage: scripts/show_parity_preflight_status.sh [--json [--compact]]"
  exit 2
fi

skip_wrapper="${SKIP_PARITY_WRAPPER_PREFLIGHT:-0}"
skip_docs="${SKIP_PARITY_DOCS_PREFLIGHT:-0}"
skip_docs_coverage="${SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT:-0}"
skip_env_helper="${SKIP_PARITY_ENV_HELPER_PREFLIGHT:-0}"
skip_preflight_status_helper="${SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT:-0}"
skip_gate_toggle="${SKIP_PARITY_GATE_TOGGLE_PREFLIGHT:-0}"
skip_gate_toggle_contract="${SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT:-0}"
skip_gate_show_toggle="${SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT:-0}"

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

gate_toggle_status="enabled"
if [[ "$skip_gate_toggle" == "1" ]]; then
  gate_toggle_status="skipped"
fi

gate_toggle_contract_status="enabled"
if [[ "$skip_gate_toggle_contract" == "1" ]]; then
  gate_toggle_contract_status="skipped"
fi

gate_show_toggle_status="enabled"
if [[ "$skip_gate_show_toggle" == "1" ]]; then
  gate_show_toggle_status="skipped"
fi

if [[ $json_mode -eq 1 ]]; then
  if [[ $compact_mode -eq 1 ]]; then
    printf '{"wrapper_preflight":"%s","env_helper_preflight":"%s","preflight_status_helper_preflight":"%s","gate_toggle_consistency_preflight":"%s","gate_toggle_contract_preflight":"%s","gate_show_toggle_contract_preflight":"%s","docs_preflight":"%s","docs_wrapper_coverage_preflight":"%s","env":{"SKIP_PARITY_WRAPPER_PREFLIGHT":"%s","SKIP_PARITY_ENV_HELPER_PREFLIGHT":"%s","SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT":"%s","SKIP_PARITY_GATE_TOGGLE_PREFLIGHT":"%s","SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT":"%s","SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT":"%s","SKIP_PARITY_DOCS_PREFLIGHT":"%s","SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT":"%s"}}\n' \
      "$wrapper_status" \
      "$env_helper_status" \
      "$preflight_status_helper_status" \
      "$gate_toggle_status" \
      "$gate_toggle_contract_status" \
      "$gate_show_toggle_status" \
      "$docs_status" \
      "$docs_coverage_status" \
      "$skip_wrapper" \
      "$skip_env_helper" \
      "$skip_preflight_status_helper" \
      "$skip_gate_toggle" \
      "$skip_gate_toggle_contract" \
      "$skip_gate_show_toggle" \
      "$skip_docs" \
      "$skip_docs_coverage"
    exit 0
  fi

  printf '{\n'
  printf '  "wrapper_preflight": "%s",\n' "$wrapper_status"
  printf '  "env_helper_preflight": "%s",\n' "$env_helper_status"
  printf '  "preflight_status_helper_preflight": "%s",\n' "$preflight_status_helper_status"
  printf '  "gate_toggle_consistency_preflight": "%s",\n' "$gate_toggle_status"
  printf '  "gate_toggle_contract_preflight": "%s",\n' "$gate_toggle_contract_status"
  printf '  "gate_show_toggle_contract_preflight": "%s",\n' "$gate_show_toggle_status"
  printf '  "docs_preflight": "%s",\n' "$docs_status"
  printf '  "docs_wrapper_coverage_preflight": "%s",\n' "$docs_coverage_status"
  printf '  "env": {\n'
  printf '    "SKIP_PARITY_WRAPPER_PREFLIGHT": "%s",\n' "$skip_wrapper"
  printf '    "SKIP_PARITY_ENV_HELPER_PREFLIGHT": "%s",\n' "$skip_env_helper"
  printf '    "SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT": "%s",\n' "$skip_preflight_status_helper"
  printf '    "SKIP_PARITY_GATE_TOGGLE_PREFLIGHT": "%s",\n' "$skip_gate_toggle"
  printf '    "SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT": "%s",\n' "$skip_gate_toggle_contract"
  printf '    "SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT": "%s",\n' "$skip_gate_show_toggle"
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
echo "- gate-toggle consistency preflight: ${gate_toggle_status}"
echo "- gate-toggle contract preflight: ${gate_toggle_contract_status}"
echo "- gate show-toggle contract preflight: ${gate_show_toggle_status}"
echo "- docs preflight: ${docs_status}"
echo "- docs wrapper coverage preflight: ${docs_coverage_status}"

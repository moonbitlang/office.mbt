#!/usr/bin/env bash
set -euo pipefail

json_mode=0
if [[ "${1:-}" == "--json" ]]; then
  json_mode=1
  shift
fi
if [[ $# -ne 0 ]]; then
  echo "Usage: scripts/show_parity_env.sh [--json]"
  exit 2
fi

if [[ $json_mode -eq 1 ]]; then
  python3 - <<'PY'
import json
import os

report_default = "_build/semantic_parity/report.json"

payload = {
    "PARITY_JSON_REPORT": {"value": os.getenv("PARITY_JSON_REPORT"), "default": report_default},
    "SEMANTIC_PARITY_REPORT": {"value": os.getenv("SEMANTIC_PARITY_REPORT"), "default": report_default},
    "SEMANTIC_PARITY_ARGS": {"value": os.getenv("SEMANTIC_PARITY_ARGS"), "default": "none"},
    "SEMANTIC_PARITY_SUMMARY_ARGS": {"value": os.getenv("SEMANTIC_PARITY_SUMMARY_ARGS"), "default": "none"},
    "SKIP_PARITY_WRAPPER_PREFLIGHT": {"value": os.getenv("SKIP_PARITY_WRAPPER_PREFLIGHT"), "default": "0"},
    "SKIP_PARITY_ENV_HELPER_PREFLIGHT": {"value": os.getenv("SKIP_PARITY_ENV_HELPER_PREFLIGHT"), "default": "0"},
    "SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT": {
        "value": os.getenv("SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT"),
        "default": "0",
    },
    "SKIP_PARITY_GATE_TOGGLE_PREFLIGHT": {
        "value": os.getenv("SKIP_PARITY_GATE_TOGGLE_PREFLIGHT"),
        "default": "0",
    },
    "SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT": {
        "value": os.getenv("SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT"),
        "default": "0",
    },
    "SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT": {
        "value": os.getenv("SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT"),
        "default": "0",
    },
    "SKIP_PARITY_DOCS_PREFLIGHT": {"value": os.getenv("SKIP_PARITY_DOCS_PREFLIGHT"), "default": "0"},
    "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT": {
        "value": os.getenv("SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT"),
        "default": "0",
    },
    "SHOW_PARITY_PREFLIGHT_STATUS": {
        "value": os.getenv("SHOW_PARITY_PREFLIGHT_STATUS"),
        "default": "0",
        "options": "0|1|json",
    },
    "SHOW_PARITY_PREFLIGHT_STATUS_COMPACT": {
        "value": os.getenv("SHOW_PARITY_PREFLIGHT_STATUS_COMPACT"),
        "default": "0",
        "options": "0|1",
    },
}

print(json.dumps(payload, indent=2, sort_keys=False))
PY
  exit 0
fi

echo "Parity environment overrides:"
echo "- PARITY_JSON_REPORT=${PARITY_JSON_REPORT:-<unset>} (default: _build/semantic_parity/report.json)"
echo "- SEMANTIC_PARITY_REPORT=${SEMANTIC_PARITY_REPORT:-<unset>} (default: _build/semantic_parity/report.json)"
echo "- SEMANTIC_PARITY_ARGS=${SEMANTIC_PARITY_ARGS:-<unset>} (default: none)"
echo "- SEMANTIC_PARITY_SUMMARY_ARGS=${SEMANTIC_PARITY_SUMMARY_ARGS:-<unset>} (default: none)"
echo "- SKIP_PARITY_WRAPPER_PREFLIGHT=${SKIP_PARITY_WRAPPER_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_ENV_HELPER_PREFLIGHT=${SKIP_PARITY_ENV_HELPER_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT=${SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_GATE_TOGGLE_PREFLIGHT=${SKIP_PARITY_GATE_TOGGLE_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT=${SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT=${SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_DOCS_PREFLIGHT=${SKIP_PARITY_DOCS_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT=${SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT:-<unset>} (default: 0)"
echo "- SHOW_PARITY_PREFLIGHT_STATUS=${SHOW_PARITY_PREFLIGHT_STATUS:-<unset>} (default: 0; options: 0|1|json)"
echo "- SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=${SHOW_PARITY_PREFLIGHT_STATUS_COMPACT:-<unset>} (default: 0; options: 0|1)"

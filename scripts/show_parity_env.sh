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

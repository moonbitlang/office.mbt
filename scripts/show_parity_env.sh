#!/usr/bin/env bash
set -euo pipefail

echo "Parity environment overrides:"
echo "- PARITY_JSON_REPORT=${PARITY_JSON_REPORT:-<unset>} (default: _build/semantic_parity/report.json)"
echo "- SEMANTIC_PARITY_REPORT=${SEMANTIC_PARITY_REPORT:-<unset>} (default: _build/semantic_parity/report.json)"
echo "- SEMANTIC_PARITY_ARGS=${SEMANTIC_PARITY_ARGS:-<unset>} (default: none)"
echo "- SEMANTIC_PARITY_SUMMARY_ARGS=${SEMANTIC_PARITY_SUMMARY_ARGS:-<unset>} (default: none)"
echo "- SKIP_PARITY_WRAPPER_PREFLIGHT=${SKIP_PARITY_WRAPPER_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_DOCS_PREFLIGHT=${SKIP_PARITY_DOCS_PREFLIGHT:-<unset>} (default: 0)"
echo "- SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT=${SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT:-<unset>} (default: 0)"
echo "- SHOW_PARITY_PREFLIGHT_STATUS=${SHOW_PARITY_PREFLIGHT_STATUS:-<unset>} (default: 0; options: 0|1|json)"

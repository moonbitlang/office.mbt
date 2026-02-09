#!/usr/bin/env bash
set -euo pipefail

skip_wrapper="${SKIP_PARITY_WRAPPER_PREFLIGHT:-0}"
skip_docs="${SKIP_PARITY_DOCS_PREFLIGHT:-0}"
skip_docs_coverage="${SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT:-0}"

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

echo "Parity aggregate preflight resolution:"
echo "- wrapper preflight: ${wrapper_status}"
echo "- docs preflight: ${docs_status}"
echo "- docs wrapper coverage preflight: ${docs_coverage_status}"

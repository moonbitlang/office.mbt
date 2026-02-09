#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required_patterns=(
  "SHOW_PARITY_PREFLIGHT_STATUS_COMPACT"
  "SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=1 requires SHOW_PARITY_PREFLIGHT_STATUS=json"
  "scripts/show_parity_preflight_status.sh --json --compact"
  "Invalid SHOW_PARITY_PREFLIGHT_STATUS_COMPACT="
)

for pattern in "${required_patterns[@]}"; do
  if rg -Fq "$pattern" scripts/test_parity_gates.sh; then
    echo "[OK] scripts/test_parity_gates.sh contains: $pattern"
  else
    echo "[MISSING] scripts/test_parity_gates.sh missing: $pattern"
    exit 1
  fi
done

set +e
invalid_combo_output="$(SHOW_PARITY_PREFLIGHT_STATUS=1 SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=1 scripts/test_parity_gates.sh 2>&1)"
invalid_combo_code=$?
set -e
if [[ $invalid_combo_code -ne 2 ]]; then
  echo "Expected exit code 2 for compact-without-json combo, got ${invalid_combo_code}"
  exit 1
fi
if ! rg -Fq "SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=1 requires SHOW_PARITY_PREFLIGHT_STATUS=json" <<<"$invalid_combo_output"; then
  echo "Missing compact-without-json guard message in test_parity_gates output."
  exit 1
fi

set +e
invalid_value_output="$(SHOW_PARITY_PREFLIGHT_STATUS=json SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=bad scripts/test_parity_gates.sh 2>&1)"
invalid_value_code=$?
set -e
if [[ $invalid_value_code -ne 2 ]]; then
  echo "Expected exit code 2 for invalid compact toggle value, got ${invalid_value_code}"
  exit 1
fi
if ! rg -Fq "Invalid SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=bad (expected 0 or 1)" <<<"$invalid_value_output"; then
  echo "Missing invalid compact toggle message in test_parity_gates output."
  exit 1
fi

echo "Parity gate show-toggle contract check passed."

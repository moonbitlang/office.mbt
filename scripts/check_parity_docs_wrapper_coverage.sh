#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docs=(
  "docs/excelize-parity.md"
  "docs/parity-commands.md"
)

wrappers=(
  "scripts/test_semantic_parity.sh"
  "scripts/test_semantic_parity_fast.sh"
  "scripts/test_semantic_parity_ultrafast.sh"
  "scripts/test_semantic_parity_ultrasmoke.sh"
  "scripts/test_semantic_parity_report.sh"
  "scripts/test_semantic_parity_report_compact.sh"
  "scripts/test_parity_gates.sh"
  "scripts/check_parity_env_helper.sh"
  "scripts/check_parity_preflight_status_helper.sh"
  "scripts/check_parity_gate_skip_toggles.sh"
  "scripts/check_parity_gate_skip_toggles_contract.sh"
  "scripts/check_parity_gate_show_toggles.sh"
  "scripts/check_parity_preflight_matrix_smoke.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_wrappers.sh"
  "scripts/check_parity_docs_refs.sh"
  "scripts/check_parity_docs_wrapper_coverage.sh"
  "scripts/show_parity_env.sh"
)

failed=0
for wrapper in "${wrappers[@]}"; do
  if rg -Fq "$wrapper" "${docs[@]}"; then
    echo "[COVERED] $wrapper"
  else
    echo "[MISSING DOC REF] $wrapper"
    failed=1
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "Parity docs wrapper coverage check failed."
  exit 1
fi

echo "Parity docs wrapper coverage check passed."

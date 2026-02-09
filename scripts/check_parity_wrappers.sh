#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

json_mode=0
if [[ "${1:-}" == "--json" ]]; then
  json_mode=1
  shift
fi
if [[ $# -ne 0 ]]; then
  echo "Usage: scripts/check_parity_wrappers.sh [--json]"
  exit 2
fi

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
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x25.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x26.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x27.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x28.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x29.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x30.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x31.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x32.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x33.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x34.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x35.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x36.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x37.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x38.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x39.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x40.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x41.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x42.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x43.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x44.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x45.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x46.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x47.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x48.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x49.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x50.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x51.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x52.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x53.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x54.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x55.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x56.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x57.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x58.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x59.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x60.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x61.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x62.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x63.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x64.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x65.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x66.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x67.sh"
  "scripts/check_parity_preflight_matrix_smoke_contract_x68.sh"
  "scripts/show_parity_env.sh"
)

missing=0
paths=()
statuses=()
for script in "${wrappers[@]}"; do
  status="ok"
  if [[ ! -f "$script" ]]; then
    status="missing"
    missing=1
  elif [[ ! -x "$script" ]]; then
    status="not_executable"
    missing=1
  fi
  paths+=("$script")
  statuses+=("$status")
  if [[ $json_mode -eq 0 ]]; then
    case "$status" in
      ok) echo "[OK] $script" ;;
      missing) echo "[MISSING] $script" ;;
      not_executable) echo "[NOT EXECUTABLE] $script" ;;
    esac
  fi
done

if [[ $json_mode -eq 1 ]]; then
  result="pass"
  if [[ $missing -ne 0 ]]; then
    result="fail"
  fi
  printf '{\n'
  printf '  "result": "%s",\n' "$result"
  printf '  "scripts": [\n'
  for i in "${!paths[@]}"; do
    comma=","
    if [[ $i -eq $((${#paths[@]} - 1)) ]]; then
      comma=""
    fi
    printf '    {"path": "%s", "status": "%s"}%s\n' "${paths[$i]}" "${statuses[$i]}" "$comma"
  done
  printf '  ]\n'
  printf '}\n'
fi

if [[ $missing -ne 0 ]]; then
  echo "Parity wrapper self-check failed."
  exit 1
fi

if [[ $json_mode -eq 0 ]]; then
  echo "Parity wrapper self-check passed."
fi

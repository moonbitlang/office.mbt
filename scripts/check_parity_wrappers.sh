#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

wrappers=(
  "scripts/test_semantic_parity.sh"
  "scripts/test_semantic_parity_fast.sh"
  "scripts/test_semantic_parity_ultrafast.sh"
  "scripts/test_semantic_parity_ultrasmoke.sh"
  "scripts/test_semantic_parity_report.sh"
  "scripts/test_semantic_parity_report_compact.sh"
  "scripts/test_parity_gates.sh"
  "scripts/show_parity_env.sh"
)

missing=0
for script in "${wrappers[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "[MISSING] $script"
    missing=1
    continue
  fi
  if [[ ! -x "$script" ]]; then
    echo "[NOT EXECUTABLE] $script"
    missing=1
    continue
  fi
  echo "[OK] $script"
done

if [[ $missing -ne 0 ]]; then
  echo "Parity wrapper self-check failed."
  exit 1
fi

echo "Parity wrapper self-check passed."

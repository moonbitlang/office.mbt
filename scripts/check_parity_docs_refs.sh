#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docs=(
  "docs/excelize-parity.md"
  "docs/parity-commands.md"
)

refs=()
while IFS= read -r ref; do
  refs+=("$ref")
done < <(rg -o --no-filename "scripts/[A-Za-z0-9._/-]+" "${docs[@]}" | sort -u)

if [[ ${#refs[@]} -eq 0 ]]; then
  echo "No script references found in parity docs."
  exit 1
fi

failed=0
for ref in "${refs[@]}"; do
  if [[ ! -f "$ref" ]]; then
    echo "[MISSING] $ref"
    failed=1
    continue
  fi
  if [[ "$ref" == *.sh && ! -x "$ref" ]]; then
    echo "[NOT EXECUTABLE] $ref"
    failed=1
    continue
  fi
  echo "[OK] $ref"
done

if [[ $failed -ne 0 ]]; then
  echo "Parity docs reference check failed."
  exit 1
fi

echo "Parity docs reference check passed."

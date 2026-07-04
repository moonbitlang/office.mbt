#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT/demos_out}"
VALIDATE_XLSX="$ROOT/scripts/validate_xlsx.sh"

if [[ ! -d "$OUT_DIR" ]]; then
  echo "error: output directory not found: $OUT_DIR" >&2
  exit 2
fi

plain_openxml_files=(
  "dashboard.xlsx"
  "invoice.xlsx"
  "pivot_slicer.xlsx"
  "sparklines.xlsx"
  "tracker_heatmap.xlsx"
  "interactive_controls.xlsx"
  "combo_chart.xlsx"
  "ooxml_showcase.xlsx"
  "stream_big_20000.xlsx"
)

encrypted_files=(
  "secure_password.xlsx"
)

status=0

for name in "${plain_openxml_files[@]}"; do
  path="$OUT_DIR/$name"
  if [[ ! -f "$path" ]]; then
    echo "MISSING $name" >&2
    status=1
    continue
  fi
  if "$VALIDATE_XLSX" "$path"; then
    echo "VALID $name"
  else
    echo "INVALID $name" >&2
    status=1
  fi
done

for name in "${encrypted_files[@]}"; do
  path="$OUT_DIR/$name"
  if [[ ! -f "$path" ]]; then
    echo "MISSING $name" >&2
    status=1
    continue
  fi

  if unzip -t "$path" >/dev/null 2>&1; then
    entries="$(unzip -Z1 "$path" 2>/dev/null || true)"
    if grep -Fxq "EncryptedPackage" <<<"$entries" \
      && grep -Fxq "EncryptionInfo" <<<"$entries"; then
      echo "SKIP(encrypted-zip-package) $name"
    else
      echo "INVALID(encryption-shape) $name" >&2
      status=1
    fi
    continue
  fi

  file_kind="$(file -b "$path" 2>/dev/null || true)"
  if grep -Eiq 'encrypted|composite document file' <<<"$file_kind"; then
    echo "SKIP(encrypted-container) $name"
  else
    echo "INVALID(non-zip-shape) $name" >&2
    status=1
  fi
done

exit "$status"

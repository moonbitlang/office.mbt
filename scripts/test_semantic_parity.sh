#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MBT_DIR="_build/semantic_parity/mbt"
EXCELIZE_DIR="_build/semantic_parity/excelize"

if [[ "${SHOW_PARITY_ENV:-0}" == "1" ]]; then
  scripts/show_parity_env.sh
fi

if [[ "${SKIP_PARITY_FINGERPRINT_CHECK:-0}" == "1" ]]; then
  echo "Skipping semantic parity fingerprint regression checks."
else
  echo "Running semantic parity fingerprint regression checks..."
  python3 scripts/semantic_parity_fingerprint_test.py
fi

echo "Cleaning semantic parity output directories..."
rm -rf "$MBT_DIR" "$EXCELIZE_DIR"

echo "Running semantic parity regression..."
python3 scripts/semantic_parity.py \
  --mbt-dir "$MBT_DIR" \
  --excelize-dir "$EXCELIZE_DIR" \
  --print-summary \
  --print-durations \
  "$@"

echo "Semantic parity regression suite passed."

#!/usr/bin/env bash
# Modified for office.mbt: generate the PPTX demo from the shared workspace.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT/demos_out_pptx}"
mkdir -p "$OUT_DIR"
moon -C "$ROOT" run --target native pptx/cmd/demos \
  | tail -1 \
  | xxd -r -p > "$OUT_DIR/sample.pptx"
echo "wrote $OUT_DIR/sample.pptx ($(wc -c < "$OUT_DIR/sample.pptx") bytes)"

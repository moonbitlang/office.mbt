#!/usr/bin/env sh
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fixtures="$root/markdown/fixtures"
cjk_font="${PDFLITE_PANDOC_CJK_FONT:-Arial Unicode MS}"

pandoc "$fixtures/pandoc_latin.md" \
  --pdf-engine=tectonic \
  -o "$fixtures/pandoc_latin.pdf"

pandoc "$fixtures/pandoc_cjk.md" \
  --pdf-engine=tectonic \
  -V "mainfont=$cjk_font" \
  -o "$fixtures/pandoc_cjk.pdf"

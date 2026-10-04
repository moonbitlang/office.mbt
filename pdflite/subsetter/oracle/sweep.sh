#!/usr/bin/env bash
# Compare pdflite/subsetter with the Rust crate on local fonts.
#
# Usage: pdflite/subsetter/oracle/sweep.sh [work dir]
#
# Builds a manifest of subsetting cases (glyph sets and variation
# coordinates) for the fonts of the Typst assets, the Typst dev assets (from
# the local cargo git checkouts) and some macOS system fonts
# (`gen_manifest.py`), subsets them with the `subsetter` crate (`sweep` in
# this directory) and checks that `pdflite/subsetter` produces the same bytes
# (`pdflite/subsetter/sweep`, a native-only test).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="${1:-$(mktemp -d)}"
mkdir -p "$work/rust_out"
python3 "$here/gen_manifest.py" "$work/manifest.tsv"
(cd "$here" && cargo build --release --offline --bin sweep)
"$here/target/release/sweep" "$work/manifest.tsv" --dump "$work/rust_out" > "$work/rust.txt"
cd "$here/../../.."
SUBSETTER_SWEEP="$work" moon test --target native --release -p pdflite/subsetter/sweep

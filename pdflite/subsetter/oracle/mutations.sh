#!/usr/bin/env bash
# Compare pdflite/subsetter with the Rust crate on single-byte variants of
# the synthetic fixtures (up to six replacement values per byte, see
# `src/bin/mutations.rs`; ~420k cases, a few minutes in release mode).
#
# Usage: pdflite/subsetter/oracle/mutations.sh [work dir] [font...]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="${1:-$(mktemp -d)}"
shift || true
(cd "$here" && cargo build --release --offline --bin mutations)
"$here/target/release/mutations" "$work" "$@"
cd "$here/../../.."
SUBSETTER_SWEEP="$work" moon test --target native --release -p pdflite/subsetter/sweep

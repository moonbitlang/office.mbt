#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/office-cli-registry-check.XXXXXX")"
MODULE="$SANDBOX/office-cli"
trap 'rm -rf "$SANDBOX"' EXIT
source "$ROOT/scripts/registry_release.sh"

stage_registry_module office-cli
stage_registry_docx_fixtures

cd "$MODULE"
prepare_registry_dependencies \
  moonbitlang/office-lib \
  moonbitlang/docx2html \
  moonbitlang/mbtexcel \
  moonbitlang/pagelayout
moon check --frozen --target native
moon check --frozen --target wasm
# Run the full module, including root tests and SDK-validity child packages.
moon test --frozen --target native
moon test --frozen --target wasm
moon build --frozen --target native
moon build --frozen --target wasm
help_output="$(moon run --frozen --target wasm . -- help all --json)"
grep -Fq '"schema": "office.capabilities/2"' <<<"$help_output"

check_registry_publish

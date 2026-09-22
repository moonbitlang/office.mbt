#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/office-registry-check.XXXXXX")"
MODULE="$SANDBOX/office-lib"
trap 'rm -rf "$SANDBOX"' EXIT
source "$ROOT/scripts/registry_release.sh"

stage_registry_module office-lib
stage_registry_validators
stage_registry_docx_fixtures

cd "$MODULE"
prepare_registry_dependencies \
  moonbitlang/mbtexcel \
  moonbitlang/docx2html
moon check --frozen --target native
moon check --frozen --target wasm
# Run the full module, including root tests and SDK-validity child packages.
moon test --frozen --target native
moon test --frozen --target wasm

check_registry_publish

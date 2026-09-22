#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/docx2html-registry-check.XXXXXX")"
MODULE="$SANDBOX/docx2html"
trap 'rm -rf "$SANDBOX"' EXIT
source "$ROOT/scripts/registry_release.sh"

stage_registry_module docx2html
stage_registry_validators

cd "$MODULE"
prepare_registry_dependencies
moon check --frozen --target native
moon check --frozen --target wasm
# Run the full module, including root tests and SDK-validity child packages.
moon test --frozen --target native
moon test --frozen --target wasm

check_registry_publish

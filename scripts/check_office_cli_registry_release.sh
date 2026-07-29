#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/office-cli-registry-check.XXXXXX")"
MODULE="$SANDBOX/office-cli"
trap 'rm -rf "$SANDBOX"' EXIT
source "$ROOT/scripts/release_tree_guard.sh"

mkdir -p "$MODULE"
cp -R "$ROOT/office-cli/." "$MODULE/"

grep -Fq 'name = "bobzhang/office"' "$MODULE/moon.mod"
grep -Fq '"bobzhang/office-lib@0.1.0"' "$MODULE/moon.mod"

cd "$MODULE"
moon update
dependency_tree="$(moon tree)"
printf '%s\n' "$dependency_tree"
assert_selected_dependency "$dependency_tree" "bobzhang/office-lib" "0.1.0"
moon check --frozen --target native
moon check --frozen --target wasm
moon build --frozen --target native
moon build --frozen --target wasm
help_output="$(moon run --frozen --target wasm . -- help all --json)"
grep -Fq '"schema": "office.capabilities/2"' <<<"$help_output"

set +e
publish_output="$(moon publish --frozen --dry-run 2>&1)"
publish_status=$?
set -e
printf '%s\n' "$publish_output"
if ! grep -Fq "Dry run completed successfully" <<<"$publish_output"; then
  if [[ "$publish_status" -ne 0 ]]; then
    exit "$publish_status"
  fi
  exit 1
fi

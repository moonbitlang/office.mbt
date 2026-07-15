#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/office-registry-check.XXXXXX")"
MODULE="$SANDBOX/office"
trap 'rm -rf "$SANDBOX"' EXIT
source "$ROOT/scripts/release_tree_guard.sh"

mkdir -p "$MODULE" "$SANDBOX/scripts" "$SANDBOX/tools/openxml-validator"
cp -R "$ROOT/office/." "$MODULE/"
cp "$ROOT/scripts/ensure_dotnet.sh" "$ROOT/scripts/validate_docx.sh" \
  "$ROOT/scripts/validate_xlsx.sh" "$SANDBOX/scripts/"
cp "$ROOT/tools/openxml-validator/OpenXmlValidator.csproj" \
  "$ROOT/tools/openxml-validator/Program.cs" \
  "$SANDBOX/tools/openxml-validator/"
chmod +x "$SANDBOX/scripts/ensure_dotnet.sh" \
  "$SANDBOX/scripts/validate_docx.sh" \
  "$SANDBOX/scripts/validate_xlsx.sh"

grep -Fq '"bobzhang/mbtexcel@0.1.9"' "$MODULE/moon.mod"
grep -Fq '"bobzhang/docx2html@0.1.45"' "$MODULE/moon.mod"
test -x "$SANDBOX/scripts/validate_docx.sh"
test -x "$SANDBOX/scripts/validate_xlsx.sh"
test -f "$SANDBOX/tools/openxml-validator/OpenXmlValidator.csproj"

cd "$MODULE"
moon update
dependency_tree="$(moon tree)"
printf '%s\n' "$dependency_tree"
assert_selected_dependency "$dependency_tree" "bobzhang/mbtexcel" "0.1.9"
assert_selected_dependency "$dependency_tree" "bobzhang/docx2html" "0.1.45"
moon check --frozen --target native
moon check --frozen --target wasm
moon test --frozen --target native transaction
moon test --frozen --target wasm transaction
moon test --frozen --target native transaction/sdk_validity
moon test --frozen --target native raw
moon test --frozen --target wasm raw
moon test --frozen --target native raw/sdk_validity
moon test --frozen --target native docx
moon test --frozen --target wasm docx
moon test --frozen --target native docx/sdk_validity

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

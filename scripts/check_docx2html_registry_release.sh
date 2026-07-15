#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/docx2html-registry-check.XXXXXX")"
MODULE="$SANDBOX/docx2html"
trap 'rm -rf "$SANDBOX"' EXIT
source "$ROOT/scripts/release_tree_guard.sh"

mkdir -p "$MODULE" "$SANDBOX/scripts" "$SANDBOX/tools/openxml-validator"
cp -R "$ROOT/docx2html/." "$MODULE/"
cp "$ROOT/scripts/ensure_dotnet.sh" "$ROOT/scripts/validate_docx.sh" \
  "$SANDBOX/scripts/"
cp "$ROOT/tools/openxml-validator/OpenXmlValidator.csproj" \
  "$ROOT/tools/openxml-validator/Program.cs" \
  "$SANDBOX/tools/openxml-validator/"
chmod +x "$SANDBOX/scripts/ensure_dotnet.sh" \
  "$SANDBOX/scripts/validate_docx.sh"

grep -Fq '"bobzhang/mbtexcel@0.1.9"' "$MODULE/moon.mod"
test -x "$SANDBOX/scripts/validate_docx.sh"
test -f "$SANDBOX/tools/openxml-validator/OpenXmlValidator.csproj"

cd "$MODULE"
moon update
dependency_tree="$(moon tree)"
printf '%s\n' "$dependency_tree"
assert_selected_dependency "$dependency_tree" "bobzhang/mbtexcel" "0.1.9"
moon check --frozen --target native
moon check --frozen --target wasm
moon test --frozen --target native
moon test --frozen --target wasm

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

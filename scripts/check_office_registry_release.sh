#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/office-registry-check.XXXXXX")"
MODULE="$SANDBOX/office"
trap 'rm -rf "$SANDBOX"' EXIT

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
moon check --target native
moon check --target wasm
moon test --target native transaction
moon test --target wasm transaction
moon test --target native raw
moon test --target wasm raw
moon test --target native docx
moon test --target wasm docx

set +e
publish_output="$(moon publish --dry-run 2>&1)"
publish_status=$?
set -e
printf '%s\n' "$publish_output"
if ! grep -Fq "Dry run completed successfully" <<<"$publish_output"; then
  if [[ "$publish_status" -ne 0 ]]; then
    exit "$publish_status"
  fi
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ISOLATED="$(mktemp -d "${TMPDIR:-/tmp}/office-registry-check.XXXXXX")"
trap 'rm -rf "$ISOLATED"' EXIT

cp -R "$ROOT/office/." "$ISOLATED/"

cd "$ISOLATED"
moon update
moon check --target native
moon check --target wasm
moon test --target native transaction
moon test --target wasm transaction

set +e
publish_output="$(moon publish --dry-run 2>&1)"
publish_status=$?
set -e
printf '%s\n' "$publish_output"
if [[ "$publish_status" -ne 0 ]] &&
  ! grep -Fq "Dry run completed successfully" <<<"$publish_output"; then
  exit "$publish_status"
fi

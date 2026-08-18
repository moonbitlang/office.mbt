#!/usr/bin/env bash
#
# The cheap half of CI, runnable locally in well under a minute.
#
# CI's `lint` job runs exactly these checks, in this order. They are also where
# CI fails most: of the ten most recent red runs on this repository, six died
# on `moon fmt` drift or `pkg.generated.mbti` drift — both fully reproducible
# here, both costing a ~15-minute CI round trip when they are discovered
# remotely instead.
#
# Unlike CI, this script leaves the fixes applied: `moon fmt` and `moon info`
# rewrite the tree in place, so a failure here is usually one `git add -u`
# away from green.
#
# Usage:
#   scripts/ci/local-gate.sh            # fmt + interface + check (native/wasm/js)
#   scripts/ci/local-gate.sh --fast     # fmt + interface + native check only
#
# Wire it into git so it runs automatically:
#   git config core.hooksPath .githooks
#
# Deliberately avoids bash arrays: macOS still ships bash 3.2, where expanding
# an empty array under `set -u` aborts the script.

set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

fast=0
case "${1:-}" in
  --fast) fast=1 ;;
  "") ;;
  *)
    printf 'usage: %s [--fast]\n' "$0" >&2
    exit 2
    ;;
esac

if ! command -v moon >/dev/null 2>&1; then
  printf 'local-gate: moon not found in PATH; skipping.\n' >&2
  exit 0
fi

if [ -t 1 ]; then
  bold=$(printf '\033[1m'); red=$(printf '\033[31m')
  green=$(printf '\033[32m'); reset=$(printf '\033[0m')
else
  bold=""; red=""; green=""; reset=""
fi

failed_count=0
failed_list=""

fail() {
  failed_count=$((failed_count + 1))
  failed_list="${failed_list}  - $1
"
}

run() {
  label="$1"
  shift
  printf '%s==> %s%s\n' "$bold" "$label" "$reset"
  if ! "$@"; then
    fail "$label"
  fi
}

# `moon fmt` and `moon info` rewrite files rather than reporting; the drift is
# only visible as a dirty tree afterwards. Snapshot first so a dirty tree is
# attributed to these two commands and not to edits the caller already had.
dirty_before=$(git status --porcelain=v1)

run "dispatch registry" python3 docx2html/tests/registry/check_dispatch_registry.py
run "dispatch escape suite" bash docx2html/tests/registry/escape_suite.sh
run "moon fmt" moon fmt
run "moon info" moon info

dirty_after=$(git status --porcelain=v1)
if [ "$dirty_before" != "$dirty_after" ]; then
  fail "formatting/interface drift"
  printf '\n%smoon fmt / moon info rewrote tracked files.%s\n' "$red" "$reset"
  printf 'CI rejects this in its "Format check" / "Interface check" steps.\n'
  printf 'The corrections are already applied here — review and stage them:\n\n'
  git --no-pager diff --stat
  printf '\n    git add -u\n\n'
fi

run "moon check" moon check
if [ "$fast" -eq 0 ]; then
  run "moon check --target wasm" moon check --target wasm
  run "moon check --target js" moon check --target js
fi

printf '\n'
if [ "$failed_count" -eq 0 ]; then
  printf '%slocal-gate: all checks passed.%s\n' "$green" "$reset"
  exit 0
fi

printf '%slocal-gate: %d check(s) failed:%s\n' "$red" "$failed_count" "$reset"
printf '%s' "$failed_list"
printf '\nThese are the same checks CI runs first. Fix them here rather than\n'
printf 'spending a CI round trip on them.\n'
exit 1

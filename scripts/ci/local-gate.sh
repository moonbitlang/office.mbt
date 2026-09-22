#!/usr/bin/env bash
#
# Run the CI lint checks and an additional corpus CLI smoke check locally.
# --fast omits the Wasm and JS type checks, not the corpus checks.
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

# Compare content, not status letters: an already-modified file can be
# rewritten again without changing its `git status` entry. Include untracked
# MoonBit source/interface files because git diff alone does not report them.
snapshot_dir=$(mktemp -d)
trap 'rm -rf "$snapshot_dir"' EXIT
snapshot_content() {
  git diff --binary --no-ext-diff --no-textconv HEAD -- || return 1
  while IFS= read -r -d '' path; do
    printf '%s\0' "$path"
    git hash-object -- "$path" || return 1
  done < <(git ls-files --others --exclude-standard -z -- \
    '*.mbt' '*.mbt.md' '*.mbti' 'moon.pkg*' 'moon.mod*' 'moon.work')
}
run "corpus projection manifest" python3 docx2html/tests/corpus/projection_check.py
# The CLI-level corpus smoke pins refusal CLASSES too -- a mutation-read
# message change slipped past the gate to CI once (#458 round 3).
run "corpus CLI smoke" bash docx2html/tests/corpus/run.sh

snapshot_content > "$snapshot_dir/before" || exit 1
run "moon fmt" moon fmt
run "moon info" moon info

snapshot_content > "$snapshot_dir/after" || exit 1
if ! cmp -s "$snapshot_dir/before" "$snapshot_dir/after"; then
  fail "formatting/interface drift"
  printf '\n%smoon fmt / moon info changed source or interface content.%s\n' "$red" "$reset"
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
printf '\nThese include the CI lint checks and corpus smoke. Fix them here rather than\n'
printf 'spending a CI round trip on them.\n'
exit 1

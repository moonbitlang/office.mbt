#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
runner="$root/office/tests/acceptance/fresh-agent/run.sh"
mkdir -p "$root/_build"
test_root="$(mktemp -d "$root/_build/fresh-agent-runner.XXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT

fail() {
  echo "FRESH-AGENT RUNNER TEST FAIL: $*" >&2
  exit 1
}

install_root="$test_root/install"
codex_bin_dir="$test_root/codex-bin"
runtime_bin_dir="$test_root/runtime-bin"
mkdir -p "$install_root/bin" "$codex_bin_dir" "$runtime_bin_dir"

for command_name in office-native office-wasm; do
  printf '#!/bin/sh\nexit 0\n' > "$install_root/bin/$command_name"
  chmod +x "$install_root/bin/$command_name"
done
printf 'test-candidate\n' > "$install_root/CANDIDATE"
printf '{}\n' > "$test_root/auth.json"

printf '%s\n' \
  '#!/bin/sh' \
  'exec "$(dirname "$0")/runtime-real" "$@"' \
  > "$runtime_bin_dir/fake_runtime"
printf '#!/bin/sh\nscript=$1\nshift\nexec /bin/sh "$script" "$@"\n' \
  > "$runtime_bin_dir/runtime-real"
printf '#!/bin/sh\nexit 99\n' > "$runtime_bin_dir/forbidden-sibling"
chmod +x \
  "$runtime_bin_dir/fake_runtime" \
  "$runtime_bin_dir/runtime-real" \
  "$runtime_bin_dir/forbidden-sibling"

printf '%s\n' \
  '#!/usr/bin/env fake_runtime' \
  'if command -v forbidden-sibling >/dev/null 2>&1; then exit 41; fi' \
  'printf "runtime-isolated PATH=%s\n" "$PATH"' \
  > "$codex_bin_dir/codex"
chmod +x "$codex_bin_dir/codex"

mkdir -p "$test_root/probe-runtime" "$test_root/evidence-runtime"
PATH="$codex_bin_dir:$runtime_bin_dir:/usr/bin:/bin" \
  bash "$runner" \
  "$install_root" \
  "$test_root/probe-runtime" \
  "$test_root/evidence-runtime" \
  "$test_root/auth.json" \
  >/dev/null
grep -q '^runtime-isolated PATH=/' \
  "$test_root/evidence-runtime/codex-transcript.log" ||
  fail "private runtime launch"
if grep -q "$runtime_bin_dir" \
  "$test_root/evidence-runtime/codex-transcript.log"; then
  fail "runtime directory leaked into PATH"
fi

printf '%s\n' \
  '#!/bin/sh' \
  'exec codex-helper "$@"' \
  > "$codex_bin_dir/codex"
printf '%s\n' \
  '#!/bin/sh' \
  'exec codex-real "$@"' \
  > "$codex_bin_dir/codex-helper"
printf '%s\n' \
  '#!/bin/sh' \
  'exec "$(dirname "$0")/codex-final" "$@"' \
  > "$codex_bin_dir/codex-real"
printf '%s\n' \
  '#!/bin/sh' \
  'if command -v forbidden-sibling >/dev/null 2>&1; then exit 42; fi' \
  'printf "wrapper-isolated\n"' \
  > "$codex_bin_dir/codex-final"
printf '#!/bin/sh\nexit 98\n' > "$codex_bin_dir/forbidden-sibling"
chmod +x \
  "$codex_bin_dir/codex" \
  "$codex_bin_dir/codex-helper" \
  "$codex_bin_dir/codex-real" \
  "$codex_bin_dir/codex-final" \
  "$codex_bin_dir/forbidden-sibling"

mkdir -p "$test_root/probe-wrapper" "$test_root/evidence-wrapper"
OFFICE_F1B_CODEX_LAUNCHER_HELPERS="codex-helper:codex-real" \
  PATH="$codex_bin_dir:/usr/bin:/bin" \
  bash "$runner" \
  "$install_root" \
  "$test_root/probe-wrapper" \
  "$test_root/evidence-wrapper" \
  "$test_root/auth.json" \
  >/dev/null
grep -q '^wrapper-isolated$' \
  "$test_root/evidence-wrapper/codex-transcript.log" ||
  fail "shell-wrapper helper launch"

mkdir -p \
  "$test_root/a/probe" \
  "$test_root/b/sub" \
  "$test_root/b/probe" \
  "$test_root/evidence-physical"
ln -s "$test_root/b/sub" "$test_root/a/link"
physical_probe="$(
  cd -P -- "$test_root/a/link/../probe" >/dev/null
  pwd -P
)"
physical_output="$(
  OFFICE_F1B_CODEX_LAUNCHER_HELPERS="codex-helper:codex-real" \
    PATH="$codex_bin_dir:/usr/bin:/bin" \
    bash "$runner" \
    "$install_root" \
    "$test_root/a/link/../probe" \
    "$test_root/evidence-physical" \
    "$test_root/auth.json"
)"
case "$physical_output" in
  *"probe_dir=$physical_probe"*) ;;
  *) fail "physical path canonicalization" ;;
esac

relative_root="${test_root#"$root/"}"
mkdir -p \
  "$test_root/probe-relative" \
  "$test_root/evidence-relative" \
  "$test_root/cdpath/$relative_root/install" \
  "$test_root/cdpath/$relative_root/probe-relative" \
  "$test_root/cdpath/$relative_root/evidence-relative"
(
  cd "$root"
  CDPATH="$test_root/cdpath" \
    OFFICE_F1B_CODEX_LAUNCHER_HELPERS="codex-helper:codex-real" \
    PATH="$codex_bin_dir:/usr/bin:/bin" \
    bash "$runner" \
    "$relative_root/install" \
    "$relative_root/probe-relative" \
    "$relative_root/evidence-relative" \
    "$relative_root/auth.json" \
    >/dev/null
)
grep -q '^wrapper-isolated$' \
  "$test_root/evidence-relative/codex-transcript.log" ||
  fail "relative paths with ambient CDPATH"

printf '%s\n' \
  '#!/bin/sh' \
  '# forbidden-sibling is not a launcher dependency' \
  'helper_name=forbidden' \
  'helper_name="${helper_name}-sibling"' \
  'if command -v "$helper_name" >/dev/null 2>&1; then exit 43; fi' \
  'printf "comment-isolated\n"' \
  > "$codex_bin_dir/codex"
chmod +x "$codex_bin_dir/codex"

mkdir -p "$test_root/probe-comment" "$test_root/evidence-comment"
PATH="$codex_bin_dir:/usr/bin:/bin" \
  bash "$runner" \
  "$install_root" \
  "$test_root/probe-comment" \
  "$test_root/evidence-comment" \
  "$test_root/auth.json" \
  >/dev/null
grep -q '^comment-isolated$' \
  "$test_root/evidence-comment/codex-transcript.log" ||
  fail "non-command launcher text leaked a sibling"

mkdir -p "$test_root/overlap"
if PATH="$codex_bin_dir:/usr/bin:/bin" \
  bash "$runner" \
  "$install_root" \
  "$test_root/overlap" \
  "$test_root/overlap" \
  "$test_root/auth.json" \
  >"$test_root/overlap.stdout" 2>"$test_root/overlap.stderr"; then
  fail "overlapping output directories were accepted"
fi
grep -q 'must not overlap' "$test_root/overlap.stderr" ||
  fail "overlap diagnostic"

echo "FRESH-AGENT RUNNER TEST PASS"

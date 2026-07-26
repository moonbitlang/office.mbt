#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(
  unset CDPATH
  cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null
  pwd -P
)"
root="$(
  unset CDPATH
  cd -P -- "$script_dir/../../../.." >/dev/null
  pwd -P
)"
head="$(git -C "$root" rev-parse --verify HEAD)"
git_common_dir="$(git -C "$root" rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$root/$git_common_dir" ;;
esac
git_common_dir="$(
  unset CDPATH
  cd -P -- "$git_common_dir" >/dev/null
  pwd -P
)"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-runner.XXXXXX")"
chmod 0700 "$test_root"

cleanup() {
  local status="$?"
  if [ "${OFFICE_F1B_KEEP_TEST_ROOT:-0}" = "1" ]; then
    echo "kept fresh-agent test root: $test_root" >&2
    exit "$status"
  fi
  chmod -R u+w -- "$test_root" 2>/dev/null || true
  rm -rf -- "$test_root"
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

fail() {
  echo "FRESH-AGENT RUNNER TEST FAIL: $*" >&2
  exit 1
}

jq -e '
  .properties.result_path.type == "string" and
  .properties.transcript_path.type == "string"
' "$script_dir/final.schema.json" >/dev/null ||
  fail "structured output schema requires explicit string types"

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

make_candidate() {
  local install_root="$1"
  local native_sha
  local wasm_wrapper_sha
  local moonrun_sha
  local wasm_sha
  local runner_sha
  local prompt_sha
  local schema_sha
  local canary_sha
  local private_sha

  mkdir -m 0700 \
    "$install_root" \
    "$install_root/bin" \
    "$install_root/libexec" \
    "$install_root/control"
  printf '#!/bin/sh\nexit 0\n' > "$install_root/bin/office-native"
  install -m 0500 "$script_dir/office-wasm" "$install_root/bin/office-wasm"
  printf '#!/bin/sh\nexit 0\n' > "$install_root/libexec/moonrun"
  printf 'fake wasm\n' > "$install_root/libexec/office.wasm"
  install -m 0500 "$script_dir/run.sh" "$install_root/control/run.sh"
  install -m 0400 "$script_dir/prompt.md" "$install_root/control/prompt.md"
  install -m 0400 \
    "$script_dir/final.schema.json" \
    "$install_root/control/final.schema.json"
  install -m 0500 \
    "$script_dir/permission-canary.sh" \
    "$install_root/control/permission-canary.sh"
  chmod 0500 \
    "$install_root/bin/office-native" \
    "$install_root/libexec/moonrun"
  chmod 0400 "$install_root/libexec/office.wasm"
  ln -s office-native "$install_root/bin/office"

  jq -n \
    --arg schema "office.fresh-agent.private/1" \
    --arg source_root "$root" \
    --arg git_common_dir "$git_common_dir" \
    '{
      schema: $schema,
      source_root: $source_root,
      git_common_dir: $git_common_dir
    }' > "$install_root/control/private.json"
  chmod 0400 "$install_root/control/private.json"

  native_sha="$(sha256_file "$install_root/bin/office-native")"
  wasm_wrapper_sha="$(sha256_file "$install_root/bin/office-wasm")"
  moonrun_sha="$(sha256_file "$install_root/libexec/moonrun")"
  wasm_sha="$(sha256_file "$install_root/libexec/office.wasm")"
  runner_sha="$(sha256_file "$install_root/control/run.sh")"
  prompt_sha="$(sha256_file "$install_root/control/prompt.md")"
  schema_sha="$(sha256_file "$install_root/control/final.schema.json")"
  canary_sha="$(sha256_file "$install_root/control/permission-canary.sh")"
  private_sha="$(sha256_file "$install_root/control/private.json")"

  jq -n \
    --arg schema "office.fresh-agent.candidate/1" \
    --arg candidate_head "$head" \
    --arg native_sha "$native_sha" \
    --arg wasm_wrapper_sha "$wasm_wrapper_sha" \
    --arg moonrun_sha "$moonrun_sha" \
    --arg wasm_sha "$wasm_sha" \
    --arg runner_sha "$runner_sha" \
    --arg prompt_sha "$prompt_sha" \
    --arg schema_sha "$schema_sha" \
    --arg canary_sha "$canary_sha" \
    --arg private_sha "$private_sha" \
    '{
      schema: $schema,
      candidate_head: $candidate_head,
      build: {
        moon_version: "fake-moon 1",
        moon_sha256: ("a" * 64),
        moonrun_version: "fake-moonrun 1",
        dependency_tree_sha256: ("b" * 64),
        capability_schema: "office.capabilities/test",
        capability_fingerprint: "test:fingerprint"
      },
      files: [
        {path: "bin/office-native", kind: "file", mode: "0500", sha256: $native_sha},
        {path: "bin/office-wasm", kind: "file", mode: "0500", sha256: $wasm_wrapper_sha},
        {path: "libexec/moonrun", kind: "file", mode: "0500", sha256: $moonrun_sha},
        {path: "libexec/office.wasm", kind: "file", mode: "0400", sha256: $wasm_sha},
        {path: "control/run.sh", kind: "file", mode: "0500", sha256: $runner_sha},
        {path: "control/prompt.md", kind: "file", mode: "0400", sha256: $prompt_sha},
        {path: "control/final.schema.json", kind: "file", mode: "0400", sha256: $schema_sha},
        {path: "control/permission-canary.sh", kind: "file", mode: "0500", sha256: $canary_sha},
        {path: "control/private.json", kind: "file", mode: "0400", sha256: $private_sha}
      ],
      symlinks: [
        {path: "bin/office", target: "office-native"}
      ]
    }' > "$install_root/CANDIDATE.json"
  chmod 0400 "$install_root/CANDIDATE.json"
  chmod 0500 \
    "$install_root/bin" \
    "$install_root/libexec" \
    "$install_root/control" \
    "$install_root"
}

case_root="$test_root/space = case"
mkdir -m 0700 "$case_root"
install_root="$case_root/install"
make_candidate "$install_root"
printf '{}\n' > "$case_root/auth.json"
chmod 0600 "$case_root/auth.json"

codex_bin_dir="$test_root/codex=bin"
runtime_bin_dir="$test_root/runtime=bin"
mkdir -m 0700 "$codex_bin_dir" "$runtime_bin_dir"
printf '%s\n' \
  '#!/bin/sh' \
  'if [ "${1:-}" = "--version" ]; then echo "fake-runtime 1.0"; exit 0; fi' \
  'script=$1' \
  'shift' \
  'exec /bin/sh "$script" "$@"' \
  > "$runtime_bin_dir/fake_runtime"
chmod 0500 "$runtime_bin_dir/fake_runtime"
printf 'pass\n' > "$codex_bin_dir/mode"
chmod 0600 "$codex_bin_dir/mode"

{
  printf '%s\n' \
    '#!/usr/bin/env fake_runtime' \
    'set -eu'
  printf 'forbidden_runtime_dir=%q\n' "$runtime_bin_dir"
  printf '%s\n' \
    'mode=$(cat "$(dirname "$0")/mode")' \
    'if [ "${1:-}" = "--version" ]; then echo "codex-cli 0.145.0"; exit 0; fi' \
    'config="$CODEX_HOME/config.toml"' \
    'test -f "$config"' \
    'grep -q '\''^default_permissions = "fresh_agent"$'\'' "$config"' \
    'grep -q '\''^web_search = "disabled"$'\'' "$config"' \
    'grep -q '\''^allow_login_shell = false$'\'' "$config"' \
    'grep -q '\''^project_doc_max_bytes = 0$'\'' "$config"' \
    'grep -q '\''^\[permissions.fresh_agent.filesystem\.":root"\]$'\'' "$config"' \
    'grep -q '\''^\[permissions.fresh_agent.network\]$'\'' "$config"' \
    'grep -q '\''^enabled = false$'\'' "$config"' \
    'if awk '\''/^\[shell_environment_policy.set\]/{inside=1;next} /^\[/{inside=0} inside{print}'\'' "$config" | grep -q CODEX_HOME; then exit 61; fi' \
    'case "$PATH" in *"$(dirname "$0")"*) exit 62 ;; esac' \
    'case "$PATH" in *"$forbidden_runtime_dir"*) exit 63 ;; esac' \
    'test -z "${OPENAI_API_KEY+x}"' \
    'test -z "${GITHUB_TOKEN+x}"' \
    'command="${1:-}"' \
    'shift || true' \
    'if [ "$command" = "sandbox" ]; then' \
    '  case " $* " in *" -P fresh_agent "*) ;; *) exit 64 ;; esac' \
    '  case " $* " in *" -C "*) ;; *) exit 65 ;; esac' \
    '  echo "FRESH-AGENT PERMISSION CANARY PASS"' \
    '  exit 0' \
    'fi' \
    'test "$command" = "exec"' \
    'case " $* " in *" --sandbox "*|*" --ignore-user-config "*) exit 66 ;; esac' \
    'ephemeral=0; strict=0; json=0; ignore_rules=0; skip_git=0' \
    'probe=""; output=""; schema=""; model=""; reasoning=""' \
    'while [ "$#" -gt 0 ]; do' \
    '  case "$1" in' \
    '    --ephemeral) ephemeral=1; shift ;;' \
    '    --strict-config) strict=1; shift ;;' \
    '    --json) json=1; shift ;;' \
    '    --ignore-rules) ignore_rules=1; shift ;;' \
    '    --skip-git-repo-check) skip_git=1; shift ;;' \
    '    -C) probe=$2; shift 2 ;;' \
    '    --output-last-message) output=$2; shift 2 ;;' \
    '    --output-schema) schema=$2; shift 2 ;;' \
    '    -m) model=$2; shift 2 ;;' \
    '    -c) reasoning=$2; shift 2 ;;' \
    '    -) shift; cat > "$probe/prompt-seen.txt"; break ;;' \
    '    *) exit 67 ;;' \
    '  esac' \
    'done' \
    'test "$ephemeral$strict$json$ignore_rules$skip_git" = "11111"' \
    'test "$model" = "gpt-5.6-sol"' \
    'test "$reasoning" = '\''model_reasoning_effort="max"'\''' \
    'test -d "$probe"' \
    'test -f "$schema"' \
    'test -n "$output"' \
    'grep -q "Use this severity rubric" "$probe/prompt-seen.txt"' \
    'install_root=$(CDPATH= cd -- "$(dirname "$schema")/.." && pwd)' \
    'evidence_root=$(dirname "$output")' \
    'grep -Fq "\"$install_root\" = \"read\"" "$config"' \
    'grep -Fq "\"$probe\" = \"write\"" "$config"' \
    'grep -Fq "\"$evidence_root\" = \"deny\"" "$config"' \
    'grep -Fq "[projects.\"$probe\"]" "$config"' \
    'case "$PATH" in "$install_root/bin:"*) ;; *) exit 68 ;; esac' \
    'if [ "$mode" = "exit19" ]; then exit 19; fi' \
    'verdict="BASELINE PASS"' \
    'if [ "$mode" = "fail" ]; then verdict="BASELINE FAIL"; fi' \
    'printf "# Probe result\n\n%s\n" "$verdict" > "$probe/probe-result.md"' \
    'printf "# Probe transcript\n\nfake command, exit 0\n" > "$probe/probe-transcript.md"' \
    'if [ "$mode" = "malformed" ]; then' \
    '  printf "{\n" > "$output"' \
    'else' \
    '  printf '\''{"verdict":"%s","result_path":"probe-result.md","transcript_path":"probe-transcript.md"}\n'\'' "$verdict" > "$output"' \
    'fi' \
    'printf '\''{"type":"fake-result"}\n'\'''
} > "$codex_bin_dir/codex"
chmod 0500 "$codex_bin_dir/codex"

runner="$install_root/control/run.sh"
probe="$case_root/probe"
evidence="$case_root/evidence"
PATH="$codex_bin_dir:$runtime_bin_dir:/usr/bin:/bin" \
  "$runner" "$head" "$probe" "$evidence" "$case_root/auth.json" \
  > "$case_root/success.stdout"

grep -Fq "verdict=BASELINE PASS" "$case_root/success.stdout" ||
  fail "successful structured verdict"
jq -e '
  .schema == "office.fresh-agent.run/1" and
  .verdict == "BASELINE PASS" and
  .codex_exit_status == 0 and
  (.integrity.candidate_manifest.before ==
    .integrity.candidate_manifest.after) and
  (.integrity.codex_launcher.before ==
    .integrity.codex_launcher.after) and
  (.integrity.codex_runtime.before ==
    .integrity.codex_runtime.after) and
  (.integrity.isolation_config.before ==
    .integrity.isolation_config.after)
' "$evidence/RUN.json" >/dev/null ||
  fail "final run manifest"
jq -e '
  .schema == "office.fresh-agent.run-preflight/1" and
  .candidate_head == $head and
  (.codex.launcher_version | startswith("codex-cli "))
' --arg head "$head" "$evidence/RUN-PREFLIGHT.json" >/dev/null ||
  fail "preflight manifest"
grep -q '^FRESH-AGENT PERMISSION CANARY PASS$' \
  "$evidence/permission-canary.log" ||
  fail "permission canary evidence"
if find "$case_root" -maxdepth 1 -type d -name '.office-f1b-isolation.*' |
  grep -q .; then
  fail "isolated credential state was not cleaned"
fi

expect_failure() {
  local label="$1"
  local expected_status="$2"
  local pattern="$3"
  shift 3
  local stdout="$test_root/$label.stdout"
  local stderr="$test_root/$label.stderr"
  local status
  set +e
  PATH="$codex_bin_dir:$runtime_bin_dir:/usr/bin:/bin" \
    "$@" >"$stdout" 2>"$stderr"
  status="$?"
  set -e
  [ "$status" -eq "$expected_status" ] ||
    fail "$label status: expected $expected_status, found $status"
  if [ -n "$pattern" ]; then
    grep -q "$pattern" "$stderr" ||
      fail "$label diagnostic"
  fi
}

mkdir -m 0700 "$case_root/preexisting-probe"
expect_failure \
  preexisting 1 'must not already exist' \
  "$runner" "$head" \
  "$case_root/preexisting-probe" \
  "$case_root/preexisting-evidence" \
  "$case_root/auth.json"

expect_failure \
  overlap 1 'must not overlap' \
  "$runner" "$head" \
  "$case_root/same-output" \
  "$case_root/same-output" \
  "$case_root/auth.json"

weak_parent="$test_root/weak-parent"
mkdir -m 0755 "$weak_parent"
expect_failure \
  weak-parent 1 'must not grant group or other access' \
  "$runner" "$head" \
  "$weak_parent/probe" \
  "$weak_parent/evidence" \
  "$case_root/auth.json"

expect_failure \
  wrong-head 1 'candidate manifest failed strict schema validation' \
  "$runner" "0000000000000000000000000000000000000000" \
  "$case_root/wrong-head-probe" \
  "$case_root/wrong-head-evidence" \
  "$case_root/auth.json"

ln -s "$case_root/auth.json" "$case_root/auth-link.json"
expect_failure \
  auth-symlink 1 'must not be a symlink' \
  "$runner" "$head" \
  "$case_root/auth-link-probe" \
  "$case_root/auth-link-evidence" \
  "$case_root/auth-link.json"

colon_parent="$test_root/colon:parent"
mkdir -m 0700 "$colon_parent"
colon_install="$colon_parent/install"
make_candidate "$colon_install"
expect_failure \
  colon-path 1 "must not contain ':'" \
  "$colon_install/control/run.sh" "$head" \
  "$colon_parent/probe" \
  "$colon_parent/evidence" \
  "$case_root/auth.json"

chmod 0700 "$codex_bin_dir"
chmod 0700 "$codex_bin_dir/codex"
cp "$codex_bin_dir/codex" "$codex_bin_dir/codex.simple"
printf '%s\n' \
  '#!/usr/bin/env -S fake_runtime --flag' \
  'exit 0' \
  > "$codex_bin_dir/codex"
chmod 0500 "$codex_bin_dir/codex"
expect_failure \
  env-shebang 1 'must name exactly one simple runtime' \
  "$runner" "$head" \
  "$case_root/env-shebang-probe" \
  "$case_root/env-shebang-evidence" \
  "$case_root/auth.json"
mv "$codex_bin_dir/codex.simple" "$codex_bin_dir/codex"
chmod 0500 "$codex_bin_dir/codex"
chmod 0700 "$codex_bin_dir"

printf 'exit19\n' > "$codex_bin_dir/mode"
expect_failure \
  codex-status 19 'Codex probe exited with status 19' \
  "$runner" "$head" \
  "$case_root/status-probe" \
  "$case_root/status-evidence" \
  "$case_root/auth.json"

printf 'malformed\n' > "$codex_bin_dir/mode"
expect_failure \
  malformed-final 1 'did not match the required structured result' \
  "$runner" "$head" \
  "$case_root/malformed-probe" \
  "$case_root/malformed-evidence" \
  "$case_root/auth.json"

printf 'fail\n' > "$codex_bin_dir/mode"
expect_failure \
  baseline-fail 3 '' \
  "$runner" "$head" \
  "$case_root/fail-probe" \
  "$case_root/fail-evidence" \
  "$case_root/auth.json"
jq -e '.verdict == "BASELINE FAIL"' \
  "$case_root/fail-evidence/RUN.json" >/dev/null ||
  fail "BASELINE FAIL run manifest"

echo "FRESH-AGENT RUNNER TEST PASS"

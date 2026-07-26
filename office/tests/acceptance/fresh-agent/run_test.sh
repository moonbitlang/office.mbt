#!/bin/bash -p
# This test intentionally emits fixture scripts from single-quoted literals.
# shellcheck disable=SC2016

case "$-" in
  *p*) ;;
  *)
    echo "error: execute run_test.sh directly so Bash privileged mode can ignore BASH_ENV" >&2
    exit 2
    ;;
esac

set -euo pipefail
umask 077

PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
unset BASH_ENV ENV CDPATH NODE_OPTIONS
unset DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH LD_PRELOAD LD_LIBRARY_PATH

script_dir="$(
  unset CDPATH
  cd -P -- "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")" >/dev/null
  pwd -P
)"
root="$(
  unset CDPATH
  cd -P -- "$script_dir/../../../.." >/dev/null
  pwd -P
)"
head="$(/usr/bin/git -C "$root" rev-parse --verify HEAD)"
git_common_dir="$(/usr/bin/git -C "$root" rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$root/$git_common_dir" ;;
esac
git_common_dir="$(
  unset CDPATH
  cd -P -- "$git_common_dir" >/dev/null
  pwd -P
)"

if [ "$(/usr/bin/uname -s)" = "Linux" ]; then
  test_tmp_root=/var/tmp
else
  test_tmp_root="${TMPDIR:-/tmp}"
fi
test_root="$(/usr/bin/mktemp -d "$test_tmp_root/office-f1b-runner.XXXXXX")"
chmod 0700 "$test_root"
linux_tmp_parent=""

cleanup() {
  local status="$1"
  trap - EXIT HUP INT TERM
  if [ "${OFFICE_F1B_KEEP_TEST_ROOT:-0}" = "1" ]; then
    echo "kept fresh-agent test root: $test_root" >&2
    exit "$status"
  fi
  chmod -R u+w -- "$test_root" 2>/dev/null || true
  /bin/rm -rf -- "$test_root"
  if [ -n "$linux_tmp_parent" ] && [ -d "$linux_tmp_parent" ]; then
    chmod -R u+w -- "$linux_tmp_parent" 2>/dev/null || true
    /bin/rm -rf -- "$linux_tmp_parent"
  fi
  exit "$status"
}
trap 'cleanup $?' EXIT
trap 'cleanup 129' HUP
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

fail() {
  echo "FRESH-AGENT RUNNER TEST FAIL: $*" >&2
  exit 1
}

sha256_file() {
  /usr/bin/shasum -a 256 "$1" |
    /usr/bin/awk '{print substr($1, length($1) - 63)}'
}

/usr/bin/jq -e '
  .properties.targets.type == "object" and
  .properties.gaps.type == "array" and
  .properties.result_path.type == "string" and
  (.properties | has("transcript_path") | not)
' "$script_dir/final.schema.json" >/dev/null ||
  fail "structured output schema has strict target and gap evidence"

make_candidate() {
  local install_root="$1"
  local source_root="${2:-$root}"
  local common_dir="${3:-$git_common_dir}"
  local native_sha
  local wasm_wrapper_sha
  local moonrun_sha
  local wasm_sha
  local runner_sha
  local prompt_sha
  local schema_sha
  local canary_sha
  local private_sha

  /bin/mkdir -m 0700 \
    "$install_root" \
    "$install_root/bin" \
    "$install_root/libexec" \
    "$install_root/control"
  printf '%s\n' \
    '#!/bin/sh' \
    'case "${TMPDIR:-}" in */.office-f1b-isolation.*/tmp) ;; *) exit 70 ;; esac' \
    'printf "fake-office %s\\n" "${1:-help}"' \
    > "$install_root/bin/office-native"
  /usr/bin/install -m 0500 "$script_dir/office-wasm" \
    "$install_root/bin/office-wasm"
  printf '%s\n' \
    '#!/bin/sh' \
    'shift' \
    'case "${TMPDIR:-}" in */.office-f1b-isolation.*/tmp) ;; *) exit 70 ;; esac' \
    'printf "fake-office %s\\n" "${1:-help}"' \
    > "$install_root/libexec/moonrun"
  printf 'fake wasm\n' > "$install_root/libexec/office.wasm"
  /usr/bin/install -m 0500 "$script_dir/run.sh" \
    "$install_root/control/run.sh"
  /usr/bin/install -m 0400 "$script_dir/prompt.md" \
    "$install_root/control/prompt.md"
  /usr/bin/install -m 0400 "$script_dir/final.schema.json" \
    "$install_root/control/final.schema.json"
  /usr/bin/install -m 0500 "$script_dir/permission-canary.sh" \
    "$install_root/control/permission-canary.sh"
  chmod 0500 \
    "$install_root/bin/office-native" \
    "$install_root/libexec/moonrun"
  chmod 0400 "$install_root/libexec/office.wasm"
  /bin/ln -s office-native "$install_root/bin/office"

  /usr/bin/jq -n \
    --arg schema "office.fresh-agent.private/1" \
    --arg source_root "$source_root" \
    --arg git_common_dir "$common_dir" \
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

  /usr/bin/jq -n \
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
        source_tree: ("c" * 40),
        moon_version: "fake-moon 1",
        moon_sha256: ("a" * 64),
        moonc_version: "fake-moonc 1",
        moonc_sha256: ("d" * 64),
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
/bin/mkdir -m 0700 "$case_root"
install_root="$case_root/install"
make_candidate "$install_root"
candidate_sha="$(sha256_file "$install_root/CANDIDATE.json")"
printf '{}\n' > "$case_root/auth.json"
chmod 0600 "$case_root/auth.json"

codex_bin_dir="$test_root/codex=bin"
/bin/mkdir -m 0700 "$codex_bin_dir"
printf 'pass\n' > "$codex_bin_dir/mode"
chmod 0600 "$codex_bin_dir/mode"

{
  printf '%s\n' '#!/bin/sh' 'set -eu'
  printf 'mode_file=%q\n' "$codex_bin_dir/mode"
  printf '%s\n' \
    'mode=$(/bin/cat "$mode_file")' \
    'if [ "${1:-}" = "--version" ]; then' \
    '  if [ "$mode" = "old-version" ]; then echo "codex-cli 0.144.9"; else echo "codex-cli 0.145.0"; fi' \
    '  exit 0' \
    'fi' \
    'config="$CODEX_HOME/config.toml"' \
    'test -f "$config"' \
    '/usr/bin/grep -q '\''^default_permissions = "fresh_agent"$'\'' "$config"' \
    '/usr/bin/grep -q '\''^web_search = "disabled"$'\'' "$config"' \
    'if /usr/bin/grep -q '\''^web_search = false$'\'' "$config"; then exit 66; fi' \
    '/usr/bin/grep -q '\''^hooks = {}$'\'' "$config"' \
    '/usr/bin/grep -q '\''^mcp_servers = {}$'\'' "$config"' \
    '/usr/bin/grep -q '\''^":minimal" = "read"$'\'' "$config"' \
    'if /usr/bin/grep -q '\''^":tmpdir" = '\'' "$config"; then exit 65; fi' \
    'codex_home_key=$(/usr/bin/jq -Rn --arg value "$CODEX_HOME" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "$codex_home_key = \"deny\"" "$config"' \
    'isolation_root=$(CDPATH= cd -- "$CODEX_HOME/.." && pwd)' \
    'policy_readonly="$isolation_root/policy-readonly"' \
    'test -d "$policy_readonly"' \
    'test -w "$policy_readonly"' \
    'policy_readonly_key=$(/usr/bin/jq -Rn --arg value "$policy_readonly" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "$policy_readonly_key = \"read\"" "$config"' \
    'child_tmp="$isolation_root/tmp"' \
    'test "$TMPDIR" = "$CODEX_HOME/runtime-tmp"' \
    'test "$TMPDIR" != "$child_tmp"' \
    'runtime_tmp_key=$(/usr/bin/jq -Rn --arg value "$TMPDIR" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "TMPDIR = $runtime_tmp_key" "$config"' \
    'child_tmp_key=$(/usr/bin/jq -Rn --arg value "$child_tmp" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "$child_tmp_key = \"write\"" "$config"' \
    'probe_path="$isolation_root/launcher-bin:$isolation_root/candidate/bin:/usr/bin:/bin:/usr/sbin:/sbin"' \
    'probe_path_key=$(/usr/bin/jq -Rn --arg value "$probe_path" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "PATH = $probe_path_key" "$config"' \
    'PATH=$probe_path; export PATH' \
    '/usr/bin/grep -q '\''candidate" = "read"$'\'' "$config"' \
    '/usr/bin/grep -q '\''candidate/CANDIDATE.json" = "deny"$'\'' "$config"' \
    '/usr/bin/grep -q '\''codex-bin" = "read"$'\'' "$config"' \
    '/usr/bin/grep -q '\''codex-resources" = "deny"$'\'' "$config"' \
    'if /usr/bin/grep -q '\''":root"'\'' "$config"; then exit 61; fi' \
    'if [ "$(/usr/bin/uname -s)" = "Linux" ]; then /usr/bin/grep -q '\''^"/etc" = "deny"$'\'' "$config"; fi' \
    'test -z "${OPENAI_API_KEY+x}"' \
    'test -z "${GITHUB_TOKEN+x}"' \
    'command="${1:-}"' \
    'shift || true' \
    'if [ "$command" = "sandbox" ]; then' \
    '  case " $* " in *" --include-managed-config "*) ;; *) exit 62 ;; esac' \
    '  case " $* " in *" -P fresh_agent "*) ;; *) exit 63 ;; esac' \
    '  if [ "$mode" = "sandbox-fail" ]; then echo "sandbox diagnostic" >&2; exit 41; fi' \
    '  /bin/mkdir -p "$TMPDIR/codex-bwrap-synthetic-mount-targets-fake"' \
    '  : > "$TMPDIR/codex-bwrap-synthetic-mount-targets-fake/lock"' \
    '  printf "FRESH-AGENT PERMISSION CANARY PASS\\n"' \
    '  exit 0' \
    'fi' \
    'test "$command" = "exec"' \
    'ephemeral=0; strict=0; json=0; ignore_rules=0; skip_git=0' \
    'probe=""; output=""; schema=""; model=""; reasoning=""; permission=""' \
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
    '    -c)' \
    '      case "$2" in model_reasoning_effort=*) reasoning=$2 ;; default_permissions=*) permission=$2 ;; esac' \
    '      shift 2' \
    '      ;;' \
    '    -) shift; /bin/cat > "$probe/prompt-seen.txt"; break ;;' \
    '    *) exit 64 ;;' \
    '  esac' \
    'done' \
    'test "$ephemeral$strict$json$ignore_rules$skip_git" = "11111"' \
    'test "$model" = "gpt-5.6-sol"' \
    'test "$reasoning" = '\''model_reasoning_effort="max"'\''' \
    'test "$permission" = '\''default_permissions="fresh_agent"'\''' \
    'test -d "$probe"' \
    'test -f "$schema"' \
    'test -n "$output"' \
    '/usr/bin/grep -q "office-permission-canary" "$probe/prompt-seen.txt"' \
    'candidate=$(CDPATH= cd -- "$(/usr/bin/dirname "$schema")/.." && pwd)' \
    'emit_started() {' \
    '  id=$1; cmd=$2' \
    '  /usr/bin/jq -cn --arg id "$id" --arg cmd "$cmd" '\''{type:"item.started",item:{id:$id,type:"command_execution",command:$cmd,aggregated_output:"",exit_code:null,status:"in_progress"}}'\''' \
    '}' \
    'emit_completed() {' \
    '  id=$1; cmd=$2; status=$3; body=$4' \
    '  /usr/bin/jq -cn --arg id "$id" --arg cmd "$cmd" --arg body "$body" --argjson status "$status" '\''{type:"item.completed",item:{id:$id,type:"command_execution",command:$cmd,aggregated_output:$body,exit_code:$status,status:(if $status == 0 then "completed" else "failed" end)}}'\''' \
    '}' \
    '/usr/bin/jq -cn '\''{type:"thread.started",thread_id:"fake-thread"}'\''' \
    '/usr/bin/jq -cn '\''{type:"turn.started"}'\''' \
    'if [ "$mode" = "pre-canary" ]; then' \
    '  emit_started pre-canary "true"' \
    '  emit_completed pre-canary "true" 0 ""' \
    'fi' \
    'emit_started canary "/bin/sh -c '\''office-permission-canary'\''"' \
    'canary_body=$(/usr/bin/printf "FRESH-AGENT PERMISSION CANARY PASS\\n_")' \
    'canary_body=${canary_body%_}' \
    'emit_completed canary "/bin/sh -c '\''office-permission-canary'\''" 0 "$canary_body"' \
    'emit_started expected-refusal "false"' \
    'emit_completed expected-refusal "false" 1 ""' \
    'if [ "$mode" != "no-office" ]; then' \
    '  index=0' \
    '  for runtime in native wasm; do' \
    '    index=$((index + 1))' \
    '    if [ "$mode" = "spoof-office" ]; then cmd="echo office-$runtime help all --json"; else cmd="office-$runtime help all --json"; fi' \
    '    emit_started "cmd-$index" "$cmd"' \
    '    if [ "$mode" = "spoof-office" ]; then body="spoof"; status=0; else body=$("office-$runtime" help all --json 2>&1); status=$?; fi' \
    '    emit_completed "cmd-$index" "$cmd" "$status" "$body"' \
    '    for format in xlsx docx; do' \
    '      if [ "$format" = "xlsx" ]; then verbs="create batch identify outline get text query validate issues preview template dump replay raw"; else verbs="batch identify outline get text query validate issues preview template dump replay raw annotate"; fi' \
    '      for verb in $verbs; do' \
    '        if [ "$mode" = "missing-create" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then continue; fi' \
    '      index=$((index + 1))' \
    '      if [ "$mode" = "spoof-office" ]; then cmd="echo office-$runtime $verb sample.$format --json"; else cmd="office-$runtime $verb sample.$format --json"; fi' \
    '      if [ "$mode" = "format-redirection-spoof" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then cmd="office-native create missing-target --json > proof.xlsx"; fi' \
    '      if [ "$mode" = "newline-mask" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then cmd=$(/usr/bin/printf "office-native create sample.xlsx --json\\ntrue"); fi' \
    '      emit_started "cmd-$index" "$cmd"' \
    '      if [ "$mode" = "spoof-office" ]; then body="spoof"; status=0; else' \
    '        set +e' \
    '        body=$("office-$runtime" "$verb" "sample.$format" --json 2>&1)' \
    '        status=$?' \
    '        set -e' \
    '      fi' \
    '      emit_completed "cmd-$index" "$cmd" "$status" "$body"' \
    '      done' \
    '    done' \
    '  done' \
    'fi' \
    'if [ "$mode" = "exit19" ]; then exit 19; fi' \
    'verdict="BASELINE PASS"; outcome="PASS"; gaps="[]"' \
    'if [ "$mode" = "fail" ]; then verdict="BASELINE FAIL"; outcome="FAIL"; gaps='\''[{"severity":"P1","summary":"fake failure"}]'\''; fi' \
    'header="Verdict: $verdict"' \
    'if [ "$mode" = "contradictory" ]; then header="Verdict: BASELINE FAIL"; fi' \
    'if [ "$mode" = "incomplete-report" ]; then' \
    '  printf "%s\\n\\n# Probe result\\n" "$header" > "$probe/probe-result.md"' \
    'else' \
    '  printf "%s\\nNative XLSX: %s\\nNative DOCX: %s\\nWasm XLSX: %s\\nWasm DOCX: %s\\nCapability schema: office.capabilities/test\\nCapability fingerprint: test:fingerprint\\nDiscoverability: %s\\nNative/Wasm comparison: %s\\n\\n# Probe result\\n" "$header" "$outcome" "$outcome" "$outcome" "$outcome" "$outcome" "$outcome" > "$probe/probe-result.md"' \
    'fi' \
    'if [ "$mode" = "malformed" ]; then' \
    '  printf "{\\n" > "$output"' \
    'else' \
    '  /usr/bin/jq -n --arg verdict "$verdict" --arg outcome "$outcome" --argjson gaps "$gaps" '\''{verdict:$verdict,result_path:"probe-result.md",targets:{native:{xlsx:$outcome,docx:$outcome},wasm:{xlsx:$outcome,docx:$outcome}},gaps:$gaps}'\'' > "$output"' \
    'fi' \
    '/usr/bin/jq -cn '\''{type:"turn.completed",usage:{input_tokens:1,output_tokens:1}}'\'''
} > "$codex_bin_dir/codex"
chmod 0500 "$codex_bin_dir/codex"
codex_sha="$(sha256_file "$codex_bin_dir/codex")"

runner="$install_root/control/run.sh"
probe="$case_root/probe"
evidence="$case_root/evidence"
"$runner" \
  "$head" \
  "$candidate_sha" \
  "$probe" \
  "$evidence" \
  "$case_root/auth.json" \
  "$codex_bin_dir/codex" \
  "$codex_sha" \
  > "$case_root/success.stdout"

/usr/bin/grep -Fq "verdict=BASELINE PASS" "$case_root/success.stdout" ||
  fail "successful structured verdict"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.run/2" and
  .verdict == "BASELINE PASS" and
  .codex_exit_status == 0 and
  .integrity.privately_staged_candidate == true and
  .integrity.privately_staged_codex == true and
  .integrity.bubblewrap == null and
  (.evidence.workflows_sha256 | test("^[0-9a-f]{64}$"))
' "$evidence/RUN.json" >/dev/null ||
  fail "final run manifest"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.run-preflight/2" and
  .candidate_head == $head and
  .codex.version == "codex-cli 0.145.0" and
  .codex.privately_staged == true and
  .codex.bubblewrap == null and
  .harness.policy_readonly_canary == {
    host_write_preflight: true,
    sandbox_write_denied: true,
    host_write_postflight: true
  }
' --arg head "$head" "$evidence/RUN-PREFLIGHT.json" >/dev/null ||
  fail "preflight manifest"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.evidence/1" and
  (.artifacts | length) == 13 and
  (.artifacts | map(.path) | index("codex-stderr.log")) != null and
  (.artifacts | map(.path) | index("COMMANDS.json")) != null and
  (.artifacts | map(.path) | index("WORKFLOWS.json")) != null
' "$evidence/EVIDENCE.json" >/dev/null ||
  fail "complete evidence manifest"
[ "$(/usr/bin/jq 'length' "$evidence/COMMANDS.json")" -eq 60 ] ||
  fail "host-derived command inventory"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.workflows/1" and
  .required_count == 58 and
  (.workflows | length) == 58 and
  (.workflows | all((.events | length) > 0))
' "$evidence/WORKFLOWS.json" >/dev/null ||
  fail "host-derived workflow matrix"
[ ! -e "$probe/probe-transcript.md" ] ||
  fail "agent unexpectedly authored the command transcript"
[ "$(/usr/bin/grep -c '^## Event ' "$evidence/probe-transcript.md")" -eq 60 ] ||
  fail "host transcript event count"
ledger_sha="$(sha256_file "$evidence/COMMANDS.json")"
raw_sha="$(sha256_file "$evidence/codex-transcript.jsonl")"
/usr/bin/grep -Fq "Command ledger SHA-256: \`$ledger_sha\`" \
  "$evidence/probe-transcript.md" ||
  fail "host transcript ledger anchor"
/usr/bin/grep -Fq "Raw transcript SHA-256: \`$raw_sha\`" \
  "$evidence/probe-transcript.md" ||
  fail "host transcript raw-event anchor"
/usr/bin/grep -qx 'FRESH-AGENT PERMISSION CANARY PASS' \
  "$evidence/permission-canary.log" ||
  fail "permission canary evidence"
[ "$(/usr/bin/head -n 1 "$evidence/probe-result.md")" = \
  "Verdict: BASELINE PASS" ] ||
  fail "exact result verdict header"
if /usr/bin/find "$case_root" -maxdepth 1 -type d \
  -name '.office-f1b-isolation.*' | /usr/bin/grep -q .; then
  fail "isolated credential state was not cleaned"
fi

special_parent="$test_root/special # [x] * back\\slash"
/bin/mkdir -m 0700 "$special_parent"
special_install="$special_parent/install"
nested_source="$test_root/nested-source"
/bin/mkdir -m 0700 "$nested_source" "$nested_source/.git"
nested_source="$(
  unset CDPATH
  cd -P -- "$nested_source" >/dev/null
  pwd -P
)"
make_candidate "$special_install" "$nested_source" "$nested_source/.git"
special_candidate_sha="$(sha256_file "$special_install/CANDIDATE.json")"
"$special_install/control/run.sh" --canary-only \
  "$head" "$special_candidate_sha" \
  "$special_parent/probe" "$special_parent/evidence" \
  "$codex_bin_dir/codex" "$codex_sha" \
  > "$special_parent/canary.stdout"
/usr/bin/grep -qx 'verdict=CANARY PASS' "$special_parent/canary.stdout" ||
  fail "special-character prefix canary"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.canary-evidence/1" and
  (.artifacts | length) == 5
' "$special_parent/evidence/EVIDENCE.json" >/dev/null ||
  fail "canary-only evidence"
source_key="$(/usr/bin/jq -Rn --arg value "$nested_source" '$value')"
git_key="$(/usr/bin/jq -Rn --arg value "$nested_source/.git" '$value')"
source_deny="$source_key = \"deny\""
git_deny="$git_key = \"deny\""
/usr/bin/grep -Fqx "$source_deny" "$special_parent/evidence/CONFIG.toml" ||
  fail "source checkout deny rule"
if /usr/bin/grep -Fqx "$git_deny" "$special_parent/evidence/CONFIG.toml"; then
  fail "redundant nested Git deny rule"
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
  "$@" >"$stdout" 2>"$stderr"
  status="$?"
  set -e
  [ "$status" -eq "$expected_status" ] ||
    fail "$label status: expected $expected_status, found $status"
  if [ -n "$pattern" ]; then
    /usr/bin/grep -q "$pattern" "$stderr" ||
      fail "$label diagnostic"
  fi
}

runner_args() {
  printf '%s\n' \
    "$head" \
    "$candidate_sha" \
    "$1" \
    "$2" \
    "$case_root/auth.json" \
    "$codex_bin_dir/codex" \
    "$codex_sha"
}

/bin/mkdir -m 0700 "$case_root/preexisting-probe"
expect_failure preexisting 1 'must not already exist' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/preexisting-probe" "$case_root/preexisting-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

expect_failure overlap 1 'must not overlap' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/same-output" "$case_root/same-output" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

weak_parent="$test_root/weak-parent"
/bin/mkdir -m 0755 "$weak_parent"
expect_failure weak-parent 1 'must not grant group or other access' \
  "$runner" "$head" "$candidate_sha" \
  "$weak_parent/probe" "$weak_parent/evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

expect_failure wrong-head 1 'candidate manifest failed strict schema validation' \
  "$runner" "0000000000000000000000000000000000000000" "$candidate_sha" \
  "$case_root/wrong-head-probe" "$case_root/wrong-head-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

expect_failure wrong-candidate-digest 1 'caller-supplied digest' \
  "$runner" "$head" "$(printf '0%.0s' {1..64})" \
  "$case_root/digest-probe" "$case_root/digest-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

expect_failure wrong-codex-digest 1 'caller-supplied digest' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/codex-digest-probe" "$case_root/codex-digest-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$(printf '0%.0s' {1..64})"

if [ "$(/usr/bin/uname -s)" = "Linux" ]; then
  linux_tmp_parent="$(/usr/bin/mktemp -d /tmp/office-f1b-rejected.XXXXXX)"
  chmod 0700 "$linux_tmp_parent"
  expect_failure linux-slash-tmp 1 'outside Linux /tmp' \
    "$runner" "$head" "$candidate_sha" \
    "$linux_tmp_parent/probe" "$linux_tmp_parent/evidence" \
    "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
  /bin/rmdir "$linux_tmp_parent"
  linux_tmp_parent=""

  native_codex="$case_root/native-codex"
  /usr/bin/install -m 0500 /bin/echo "$native_codex"
  native_codex_sha="$(sha256_file "$native_codex")"
  expect_failure linux-native-runtime-closure 1 \
    'requires an approved bubblewrap executable and digest' \
    "$runner" "$head" "$candidate_sha" \
    "$case_root/native-probe" "$case_root/native-evidence" \
    "$case_root/auth.json" "$native_codex" "$native_codex_sha"
  system_bwrap="$(command -v bwrap || true)"
  if [ -n "$system_bwrap" ]; then
    system_bwrap_sha="$(sha256_file "$system_bwrap")"
    expect_failure linux-system-bwrap-version 1 \
      'could not identify Codex CLI version' \
      "$runner" "$head" "$candidate_sha" \
      "$case_root/system-bwrap-probe" "$case_root/system-bwrap-evidence" \
      "$case_root/auth.json" "$native_codex" "$native_codex_sha" \
      "$system_bwrap" "$system_bwrap_sha"
  fi
fi

/bin/ln -s "$case_root/auth.json" "$case_root/auth-link.json"
expect_failure auth-symlink 1 'must be regular' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/auth-link-probe" "$case_root/auth-link-evidence" \
  "$case_root/auth-link.json" "$codex_bin_dir/codex" "$codex_sha"

hostile_hook="$test_root/hostile-bash-env"
hostile_marker="$test_root/hostile-marker"
printf 'printf pwned > %q\n' "$hostile_marker" > "$hostile_hook"
set +e
BASH_ENV="$hostile_hook" PATH="$test_root" "$runner" > /dev/null 2>&1
hostile_status="$?"
set -e
[ "$hostile_status" -eq 2 ] || fail "hostile BASH_ENV usage status"
[ ! -e "$hostile_marker" ] || fail "hostile BASH_ENV executed before runner"

set +e
BASH_ENV="$hostile_hook" PATH="$test_root" \
  "$script_dir/prepare.sh" > /dev/null 2>&1
hostile_prepare_status="$?"
set -e
[ "$hostile_prepare_status" -eq 2 ] || fail "hostile prepare BASH_ENV usage status"
[ ! -e "$hostile_marker" ] || fail "hostile BASH_ENV executed before prepare"

expect_failure indirect-bash 2 'execute run.sh directly' \
  /bin/bash "$runner"
expect_failure indirect-prepare-bash 2 'execute prepare.sh directly' \
  /bin/bash "$script_dir/prepare.sh"

printf 'sandbox-fail\n' > "$codex_bin_dir/mode"
expect_failure sandbox-fail 1 'sandbox diagnostic' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/sandbox-fail-probe" "$case_root/sandbox-fail-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'old-version\n' > "$codex_bin_dir/mode"
expect_failure old-version 1 '0.145.0 or newer is required' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/old-probe" "$case_root/old-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'exit19\n' > "$codex_bin_dir/mode"
expect_failure codex-status 19 'Codex probe exited with status 19' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/status-probe" "$case_root/status-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'malformed\n' > "$codex_bin_dir/mode"
expect_failure malformed-final 1 'required structured result' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/malformed-probe" "$case_root/malformed-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'contradictory\n' > "$codex_bin_dir/mode"
expect_failure contradictory 1 'exact structured verdict' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/contradict-probe" "$case_root/contradict-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'no-office\n' > "$codex_bin_dir/mode"
expect_failure no-office 1 'required workflow: native/all/help' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/no-office-probe" "$case_root/no-office-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'spoof-office\n' > "$codex_bin_dir/mode"
expect_failure spoof-office 1 'required workflow: native/all/help' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/spoof-office-probe" "$case_root/spoof-office-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'missing-create\n' > "$codex_bin_dir/mode"
expect_failure missing-create 1 'required workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/missing-create-probe" "$case_root/missing-create-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'format-redirection-spoof\n' > "$codex_bin_dir/mode"
expect_failure format-redirection-spoof 1 'required workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/format-spoof-probe" "$case_root/format-spoof-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'newline-mask\n' > "$codex_bin_dir/mode"
expect_failure newline-mask 1 'required workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/newline-mask-probe" "$case_root/newline-mask-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'incomplete-report\n' > "$codex_bin_dir/mode"
expect_failure incomplete-report 1 'structured outcome: Native XLSX' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/incomplete-report-probe" "$case_root/incomplete-report-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'pre-canary\n' > "$codex_bin_dir/mode"
expect_failure pre-canary 1 'first live command was not the exact permission canary' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/pre-canary-probe" "$case_root/pre-canary-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'fail\n' > "$codex_bin_dir/mode"
expect_failure baseline-fail 3 '' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/fail-probe" "$case_root/fail-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
/usr/bin/jq -e '.verdict == "BASELINE FAIL"' \
  "$case_root/fail-evidence/RUN.json" >/dev/null ||
  fail "BASELINE FAIL run manifest"

echo "FRESH-AGENT RUNNER TEST PASS"

#!/bin/bash -p

case "$-" in
  *p*) ;;
  *)
    echo "error: execute run.sh directly so Bash privileged mode can ignore BASH_ENV" >&2
    exit 2
    ;;
esac

set -euo pipefail
umask 077

PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
unset BASH_ENV ENV CDPATH GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_CONFIG GIT_CONFIG_GLOBAL
unset GIT_CONFIG_SYSTEM GIT_CEILING_DIRECTORIES NODE_OPTIONS
unset DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH LD_PRELOAD LD_LIBRARY_PATH
unset OPENAI_API_KEY GITHUB_TOKEN GH_TOKEN

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 EXPECTED_FULL_HEAD EXPECTED_CANDIDATE_SHA256 ABSENT_PROBE_DIR ABSENT_EVIDENCE_DIR CODEX_AUTH_JSON CODEX_BIN EXPECTED_CODEX_SHA256 [CODEX_BWRAP EXPECTED_BWRAP_SHA256]" >&2
  echo "       $0 --canary-only EXPECTED_FULL_HEAD EXPECTED_CANDIDATE_SHA256 ABSENT_PROBE_DIR ABSENT_EVIDENCE_DIR CODEX_BIN EXPECTED_CODEX_SHA256 [CODEX_BWRAP EXPECTED_BWRAP_SHA256]" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "required command is unavailable: $1"
}

sha256_file() {
  /usr/bin/shasum -a 256 "$1" |
    /usr/bin/awk '{print substr($1, length($1) - 63)}'
}

stat_owner_mode_nlink() {
  if /usr/bin/stat -f '%u %Lp %l' "$1" >/dev/null 2>&1; then
    /usr/bin/stat -f '%u %Lp %l' "$1"
  else
    /usr/bin/stat -c '%u %a %h' "$1"
  fi
}

stat_identity() {
  if /usr/bin/stat -f '%d:%i' "$1" >/dev/null 2>&1; then
    /usr/bin/stat -f '%d:%i' "$1"
  else
    /usr/bin/stat -c '%d:%i' "$1"
  fi
}

normalized_mode() {
  local mode="$1"
  printf '%04o\n' "$((8#$mode))"
}

assert_owned_directory_mode() {
  local path="$1"
  local expected_mode="$2"
  local label="$3"
  local owner
  local mode
  local nlink
  [ -d "$path" ] && [ ! -L "$path" ] ||
    die "$label must be a regular directory: $path"
  read -r owner mode nlink <<<"$(stat_owner_mode_nlink "$path")"
  [ "$owner" = "$(/usr/bin/id -u)" ] ||
    die "$label is not owned by the current user: $path"
  [ "$(normalized_mode "$mode")" = "$expected_mode" ] ||
    die "$label mode must be $expected_mode: $path (found $mode)"
}

assert_owned_private_directory() {
  local path="$1"
  local owner
  local mode
  local nlink
  [ -d "$path" ] && [ ! -L "$path" ] ||
    die "directory must be regular and not a symlink: $path"
  read -r owner mode nlink <<<"$(stat_owner_mode_nlink "$path")"
  [ "$owner" = "$(/usr/bin/id -u)" ] ||
    die "directory is not owned by the current user: $path"
  case "$mode" in
    "" | *[!0-7]*) die "could not read directory mode: $path" ;;
  esac
  if (( (8#$mode & 077) != 0 )); then
    die "directory must not grant group or other access: $path (mode $mode)"
  fi
}

assert_owned_file() {
  local path="$1"
  local expected_mode="$2"
  local expected_nlink="$3"
  local label="$4"
  local owner
  local mode
  local nlink
  [ -f "$path" ] && [ ! -L "$path" ] ||
    die "$label must be a regular non-symlink file: $path"
  read -r owner mode nlink <<<"$(stat_owner_mode_nlink "$path")"
  [ "$owner" = "$(/usr/bin/id -u)" ] ||
    die "$label is not owned by the current user: $path"
  [ "$(normalized_mode "$mode")" = "$expected_mode" ] ||
    die "$label mode must be $expected_mode: $path (found $mode)"
  [ "$nlink" = "$expected_nlink" ] ||
    die "$label must have exactly $expected_nlink link: $path (found $nlink)"
}

assert_owned_private_file() {
  local path="$1"
  local label="$2"
  local owner
  local mode
  local nlink
  [ -f "$path" ] && [ ! -L "$path" ] ||
    die "$label must be a regular non-symlink file: $path"
  read -r owner mode nlink <<<"$(stat_owner_mode_nlink "$path")"
  [ "$owner" = "$(/usr/bin/id -u)" ] ||
    die "$label is not owned by the current user: $path"
  if (( (8#$mode & 077) != 0 )); then
    die "$label must not grant group or other access: $path (mode $mode)"
  fi
  [ "$nlink" = "1" ] ||
    die "$label must have exactly one link: $path"
}

assert_root_owned_system_executable() {
  local path="$1"
  local label="$2"
  local owner
  local mode
  local nlink
  [ -f "$path" ] && [ ! -L "$path" ] ||
    die "$label must be a regular non-symlink file: $path"
  read -r owner mode nlink <<<"$(stat_owner_mode_nlink "$path")"
  [ "$owner" = "0" ] || die "$label must be owned by root: $path"
  case "$mode" in
    "" | *[!0-7]*) die "could not read $label mode: $path" ;;
  esac
  (( (8#$mode & 07000) == 0 )) ||
    die "$label must not carry setuid, setgid, or sticky bits: $path (mode $mode)"
  (( (8#$mode & 022) == 0 )) ||
    die "$label must not be group- or other-writable: $path (mode $mode)"
  (( (8#$mode & 0111) != 0 )) || die "$label must be executable: $path"
}

canonical_directory() {
  (
    unset CDPATH
    cd -P -- "$1" >/dev/null
    pwd -P
  )
}

canonical_regular_file() {
  local input="$1"
  local label="$2"
  local parent
  local path
  case "$input" in
    /*) ;;
    *) die "$label path must be absolute: $input" ;;
  esac
  reject_path_syntax "$input" "$label"
  parent="$(canonical_directory "$(/usr/bin/dirname -- "$input")")"
  path="$parent/$(/usr/bin/basename -- "$input")"
  [ -f "$path" ] && [ ! -L "$path" ] ||
    die "$label must be regular and must not be a symlink: $path"
  printf '%s\n' "$path"
}

reject_path_syntax() {
  local path="$1"
  local label="$2"
  case "$path" in
    *:*) die "$label must not contain ':' because it is used in PATH: $path" ;;
    *$'\n'* | *$'\r'*) die "$label must not contain a newline: $path" ;;
  esac
}

canonical_absent_directory() {
  local input="$1"
  local label="$2"
  local parent
  local name
  case "$input" in
    /*) ;;
    *) die "$label must be absolute: $input" ;;
  esac
  reject_path_syntax "$input" "$label"
  [ ! -e "$input" ] && [ ! -L "$input" ] ||
    die "$label must not already exist: $input"
  name="$(/usr/bin/basename -- "$input")"
  case "$name" in
    "" | "." | "..") die "invalid $label: $input" ;;
  esac
  parent="$(canonical_directory "$(/usr/bin/dirname -- "$input")")"
  assert_owned_private_directory "$parent"
  if [ "$parent" = "/" ]; then
    printf '/%s\n' "$name"
  else
    printf '%s/%s\n' "$parent" "$name"
  fi
}

paths_overlap() {
  local left="$1"
  local right="$2"
  case "$left/" in
    "$right/"*) return 0 ;;
  esac
  case "$right/" in
    "$left/"*) return 0 ;;
  esac
  return 1
}

path_is_within_or_equal() {
  local path="$1"
  local root="$2"
  [ "$root" = "/" ] && return 0
  [ "$path" = "$root" ] && return 0
  case "$path/" in
    "$root/"*) return 0 ;;
  esac
  return 1
}

reject_overlap() {
  local left="$1"
  local left_label="$2"
  local right="$3"
  local right_label="$4"
  if paths_overlap "$left" "$right"; then
    die "$left_label and $right_label must not overlap"
  fi
}

reject_protected_location() {
  local path="$1"
  local label="$2"
  local protected
  for protected in /Users /home /root /Volumes /mnt /media /workspace /workspaces; do
    [ -e "$protected" ] || continue
    case "$path/" in
      "$protected/"*)
        die "$label must be outside protected user/workspace storage: $path"
        ;;
    esac
  done
}

reject_macos_platform_default_location() {
  local path="$1"
  local label="$2"
  [ "$platform_name" = "Darwin" ] || return 0
  case "$path/" in
    /tmp/* | /private/tmp/* | /var/tmp/* | /private/var/tmp/* | \
    /etc/* | /private/etc/* | /var/db/* | /private/var/db/* | \
    /Library/Preferences/* | /Applications/* | /opt/homebrew/lib/* | \
    /usr/local/lib/*)
      die "$label must be outside macOS Codex :minimal platform-default storage: $path"
      ;;
  esac
}

reject_linux_slash_tmp_location() {
  local path="$1"
  local label="$2"
  local slash_tmp
  [ "$platform_name" = "Linux" ] || return 0
  slash_tmp="$(canonical_directory /tmp)"
  case "$path/" in
    "$slash_tmp/"*)
      die "$label must be outside Linux /tmp because the fresh-agent profile denies /tmp before layering scoped roots: $path"
      ;;
  esac
}

assert_sha256() {
  local value="$1"
  local label="$2"
  case "$value" in
    "" | *[!0-9a-f]*) die "$label must be a lowercase SHA-256 value" ;;
  esac
  [ "${#value}" -eq 64 ] ||
    die "$label must be a lowercase 64-character SHA-256 value"
}

toml_string() {
  /usr/bin/jq -Rn --arg value "$1" '$value'
}

verify_candidate() {
  local root="$1"
  local expected_manifest_sha256="$2"
  local manifest="$root/CANDIDATE.json"
  local relative
  local expected_mode
  local expected_hash
  local candidate_file
  local actual_files
  local expected_files
  local actual_directories
  local expected_directories

  assert_owned_directory_mode "$root" "0500" "candidate root"
  for relative in bin control libexec; do
    assert_owned_directory_mode \
      "$root/$relative" "0500" "candidate directory $relative"
  done
  assert_owned_file "$manifest" "0400" "1" "candidate manifest"
  [ "$(sha256_file "$manifest")" = "$expected_manifest_sha256" ] ||
    die "candidate manifest does not match the caller-supplied digest"

  /usr/bin/jq -e \
    --arg head "$expected_head" \
    '
      keys == ["build", "candidate_head", "files", "schema", "symlinks"] and
      .schema == "office.fresh-agent.candidate/1" and
      .candidate_head == $head and
      (.build | keys) == [
        "capability_fingerprint",
        "capability_schema",
        "dependency_tree_sha256",
        "moon_sha256",
        "moon_version",
        "moonrun_version"
      ] and
      (.build.dependency_tree_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.moon_sha256 | test("^[0-9a-f]{64}$")) and
      (.files | map(keys == ["kind", "mode", "path", "sha256"]) | all) and
      (.files | map(.path)) == [
        "bin/office-native",
        "bin/office-wasm",
        "libexec/moonrun",
        "libexec/office.wasm",
        "control/run.sh",
        "control/prompt.md",
        "control/final.schema.json",
        "control/permission-canary.sh",
        "control/private.json"
      ] and
      (.files | map(.kind == "file") | all) and
      (.files | map(.sha256 | test("^[0-9a-f]{64}$")) | all) and
      .symlinks == [{path: "bin/office", target: "office-native"}]
    ' "$manifest" >/dev/null ||
    die "candidate manifest failed strict schema validation"

  while IFS='|' read -r relative expected_mode; do
    [ -n "$relative" ] || continue
    candidate_file="$root/$relative"
    assert_owned_file "$candidate_file" "$expected_mode" "1" \
      "candidate file $relative"
    expected_hash="$(
      /usr/bin/jq -er --arg path "$relative" \
        '.files[] | select(.path == $path) | .sha256' "$manifest"
    )"
    [ "$(
      /usr/bin/jq -er --arg path "$relative" \
        '.files[] | select(.path == $path) | .mode' "$manifest"
    )" = "$expected_mode" ] ||
      die "candidate manifest has an unexpected mode for $relative"
    [ "$(sha256_file "$candidate_file")" = "$expected_hash" ] ||
      die "candidate hash mismatch: $relative"
  done <<'EOF'
bin/office-native|0500
bin/office-wasm|0500
libexec/moonrun|0500
libexec/office.wasm|0400
control/run.sh|0500
control/prompt.md|0400
control/final.schema.json|0400
control/permission-canary.sh|0500
control/private.json|0400
EOF

  [ -L "$root/bin/office" ] ||
    die "candidate office alias is not a symlink"
  [ "$(/usr/bin/readlink "$root/bin/office")" = "office-native" ] ||
    die "candidate office alias has an unexpected target"

  actual_files="$(
    cd "$root"
    /usr/bin/find . -mindepth 1 \( -type f -o -type l \) -print |
      while IFS= read -r relative; do
        printf '%s\n' "${relative#./}"
      done |
      LC_ALL=C /usr/bin/sort
  )"
  expected_files="$(
    printf '%s\n' \
      CANDIDATE.json \
      bin/office \
      bin/office-native \
      bin/office-wasm \
      control/final.schema.json \
      control/permission-canary.sh \
      control/private.json \
      control/prompt.md \
      control/run.sh \
      libexec/moonrun \
      libexec/office.wasm |
      LC_ALL=C /usr/bin/sort
  )"
  [ "$actual_files" = "$expected_files" ] ||
    die "candidate prefix contains an unexpected or missing file"

  actual_directories="$(
    cd "$root"
    /usr/bin/find . -mindepth 1 -type d -print |
      while IFS= read -r relative; do
        printf '%s\n' "${relative#./}"
      done |
      LC_ALL=C /usr/bin/sort
  )"
  expected_directories="$(printf '%s\n' bin control libexec | LC_ALL=C /usr/bin/sort)"
  [ "$actual_directories" = "$expected_directories" ] ||
    die "candidate prefix contains an unexpected or missing directory"
  if [ -n "$(
    /usr/bin/find "$root" -mindepth 1 \
      ! -type d ! -type f ! -type l -print -quit
  )" ]; then
    die "candidate prefix contains an unsupported filesystem entry"
  fi

  [ "$(sha256_file "$manifest")" = "$expected_manifest_sha256" ] ||
    die "candidate manifest changed while it was verified"
}

run_codex() {
  /usr/bin/env -i \
    HOME="$isolated_user_home" \
    CODEX_HOME="$isolated_codex_state" \
    ZDOTDIR="$isolated_user_home" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    TMPDIR="$isolated_codex_tmp" \
    LANG=C \
    LC_ALL=C \
    "${codex_argv[@]}" "$@"
}

verify_codex_runtime() {
  assert_owned_file "$codex_bin" "0500" "1" "staged Codex executable"
  [ "$(sha256_file "$codex_bin")" = "$expected_codex_sha256" ] ||
    die "staged Codex executable hash mismatch"
  if [ -n "$bwrap_bin" ]; then
    if [ "$bwrap_selection" = "system" ]; then
      assert_root_owned_system_executable "$bwrap_bin" "system bubblewrap"
    else
      assert_owned_file \
        "$bwrap_bin" "0500" "1" "staged Codex bubblewrap executable"
    fi
    [ "$(sha256_file "$bwrap_bin")" = "$expected_bwrap_sha256" ] ||
      die "approved Codex bubblewrap executable hash mismatch"
    [ "$(sha256_file "$bwrap_source")" = "$expected_bwrap_sha256" ] ||
      die "approved Codex bubblewrap executable changed during the run"
  fi
}

start_loopback_listener() {
  local attempt
  local port
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    port=$((41000 + ((RANDOM + $$ + attempt * 997) % 20000)))
    "$netcat_bin" -l -k 127.0.0.1 "$port" \
      </dev/null >"$isolation_root/network-listener.log" 2>&1 &
    network_listener_pid="$!"
    /bin/sleep 0.05
    if /bin/kill -0 "$network_listener_pid" 2>/dev/null &&
      /bin/bash -p -c 'exec 3<>/dev/tcp/127.0.0.1/$1' \
        office-listener "$port" >/dev/null 2>&1; then
      network_port="$port"
      return 0
    fi
    /bin/kill "$network_listener_pid" 2>/dev/null || true
    wait "$network_listener_pid" 2>/dev/null || true
    network_listener_pid=""
  done
  die "could not start the loopback denial canary listener"
}

write_live_canary_launcher() {
  local launcher="$isolated_launcher_bin/office-permission-canary"
  local canary_body="$isolated_launcher_bin/.office-permission-canary-body"
  /usr/bin/install -m 0500 \
    "$candidate_root/control/permission-canary.sh" "$canary_body"
  {
    printf '%s\n' '#!/bin/bash -p' 'set -euo pipefail'
    printf 'TMPDIR=%q\nexport TMPDIR\n' "$isolated_tmp"
    printf 'exec %q' "$canary_body"
    printf ' %q' \
      "$candidate_root" \
      "$install_root" \
      "$probe_root" \
      "$isolated_tmp" \
      "$evidence_root" \
      "$isolated_codex_state" \
      "$auth_json" \
      "$source_root" \
      "$git_common_dir" \
      "$ambient_write_path" \
      "$network_port" \
      "$platform_name"
    printf '\n'
  } > "$launcher"
  chmod 0500 "$launcher"
}

write_office_launcher() {
  local runtime="$1"
  local launcher="$isolated_launcher_bin/office-$runtime"
  local target="$candidate_root/bin/office-$runtime"
  {
    printf '%s\n' '#!/bin/bash -p' 'set -euo pipefail'
    printf 'TMPDIR=%q\nexport TMPDIR\n' "$isolated_tmp"
    printf 'exec %q "$@"\n' "$target"
  } > "$launcher"
  chmod 0500 "$launcher"
}

assert_recorded_office_command() {
  local runtime="$1"
  local verb="$2"
  /usr/bin/jq -e \
    --arg executable "office-$runtime" \
    --arg verb "$verb" \
    '
      def masks_status:
        test("[;]|&&|[|][|]|(^|[^|])[|]([^|]|$)|(^|[^>])&([^>]|$)");
      def standalone_command($executable; $verb):
        test(
          "^([[:space:]]*|/bin/(sh|bash|zsh) -l?c [^A-Za-z0-9_-]?)" +
          $executable + "[[:space:]]+" + $verb + "([[:space:]]|$)"
        ) and (masks_status | not);
      any(.[].item?;
        .type == "command_execution" and
        .status == "completed" and
        .exit_code == 0 and
        (.command | standalone_command($executable; $verb))
      )
    ' "$isolation_root/transcript-array.json" >/dev/null ||
    die "Codex transcript does not record office-$runtime $verb"
}

assert_recorded_office_format() {
  local runtime="$1"
  local extension="$2"
  /usr/bin/jq -e \
    --arg executable "office-$runtime" \
    --arg extension ".$extension" \
    '
      def masks_status:
        test("[;]|&&|[|][|]|(^|[^|])[|]([^|]|$)|(^|[^>])&([^>]|$)");
      def standalone_format($executable; $extension):
        test(
          "^([[:space:]]*|/bin/(sh|bash|zsh) -l?c [^A-Za-z0-9_-]?)" +
          $executable + "[[:space:]]+[A-Za-z0-9_-]+[[:space:]]"
        ) and contains($extension) and (masks_status | not);
      any(.[].item?;
        .type == "command_execution" and
        .status == "completed" and
        .exit_code == 0 and
        (.command | standalone_format($executable; $extension))
      )
    ' "$isolation_root/transcript-array.json" >/dev/null ||
    die "Codex transcript does not record a successful office-$runtime .$extension target"
}

write_evidence_manifest() {
  local entries="$isolation_root/evidence-entries.jsonl"
  local name
  : > "$entries"
  for name in \
    CANDIDATE.json \
    COMMANDS.json \
    CONFIG.toml \
    RUN-PREFLIGHT.json \
    RUN.json \
    codex-exit-status.txt \
    codex-stderr.log \
    codex-transcript.jsonl \
    final-message.json \
    permission-canary.log \
    probe-result.md \
    probe-transcript.md; do
    [ -f "$evidence_root/$name" ] ||
      die "retained evidence artifact is missing: $name"
    /usr/bin/jq -n \
      --arg path "$name" \
      --arg sha256 "$(sha256_file "$evidence_root/$name")" \
      --argjson bytes "$(/usr/bin/wc -c < "$evidence_root/$name" | /usr/bin/tr -d ' ')" \
      '{path: $path, sha256: $sha256, bytes: $bytes}' >> "$entries"
  done
  /usr/bin/jq -s \
    --arg schema "office.fresh-agent.evidence/1" \
    --arg candidate_head "$expected_head" \
    --arg candidate_manifest_sha256 "$expected_candidate_sha256" \
    '{
      schema: $schema,
      candidate_head: $candidate_head,
      candidate_manifest_sha256: $candidate_manifest_sha256,
      artifacts: .
    }' "$entries" > "$isolation_root/EVIDENCE.json"
  /usr/bin/install -m 0600 "$isolation_root/EVIDENCE.json" \
    "$evidence_root/EVIDENCE.json"
}

write_canary_evidence_manifest() {
  local entries="$isolation_root/canary-evidence-entries.jsonl"
  local name
  : > "$entries"
  for name in \
    CANDIDATE.json \
    CONFIG.toml \
    RUN-PREFLIGHT.json \
    RUN.json \
    permission-canary.log; do
    /usr/bin/jq -n \
      --arg path "$name" \
      --arg sha256 "$(sha256_file "$evidence_root/$name")" \
      --argjson bytes "$(/usr/bin/wc -c < "$evidence_root/$name" | /usr/bin/tr -d ' ')" \
      '{path: $path, sha256: $sha256, bytes: $bytes}' >> "$entries"
  done
  /usr/bin/jq -s \
    --arg schema "office.fresh-agent.canary-evidence/1" \
    --arg candidate_head "$expected_head" \
    --arg candidate_manifest_sha256 "$expected_candidate_sha256" \
    '{
      schema: $schema,
      candidate_head: $candidate_head,
      candidate_manifest_sha256: $candidate_manifest_sha256,
      artifacts: .
    }' "$entries" > "$isolation_root/EVIDENCE.json"
  /usr/bin/install -m 0600 "$isolation_root/EVIDENCE.json" \
    "$evidence_root/EVIDENCE.json"
}

canary_only=0
bwrap_input=""
expected_bwrap_sha256=""
if [ "${1:-}" = "--canary-only" ]; then
  case "$#" in 7 | 9) ;; *) usage ;; esac
  canary_only=1
  expected_head="$2"
  expected_candidate_sha256="$3"
  probe_input="$4"
  evidence_input="$5"
  auth_input=""
  codex_input="$6"
  expected_codex_sha256="$7"
  if [ "$#" -eq 9 ]; then
    bwrap_input="$8"
    expected_bwrap_sha256="$9"
  fi
else
  case "$#" in 7 | 9) ;; *) usage ;; esac
  expected_head="$1"
  expected_candidate_sha256="$2"
  probe_input="$3"
  evidence_input="$4"
  auth_input="$5"
  codex_input="$6"
  expected_codex_sha256="$7"
  if [ "$#" -eq 9 ]; then
    bwrap_input="$8"
    expected_bwrap_sha256="$9"
  fi
fi

case "$expected_head" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) die "EXPECTED_FULL_HEAD must be a lowercase 40-character commit id" ;;
esac
assert_sha256 "$expected_candidate_sha256" "EXPECTED_CANDIDATE_SHA256"
assert_sha256 "$expected_codex_sha256" "EXPECTED_CODEX_SHA256"
if [ -n "$bwrap_input" ] || [ -n "$expected_bwrap_sha256" ]; then
  [ -n "$bwrap_input" ] && [ -n "$expected_bwrap_sha256" ] ||
    die "CODEX_BWRAP and EXPECTED_BWRAP_SHA256 must be supplied together"
  assert_sha256 "$expected_bwrap_sha256" "EXPECTED_BWRAP_SHA256"
fi

for tool in jq shasum awk find sort stat id mktemp install wc tr readlink nc uname; do
  require_command "$tool"
done
netcat_bin="$(command -v nc)"
case "$netcat_bin" in
  /*) ;;
  *) die "netcat must resolve to an absolute path" ;;
esac
platform_name="$(/usr/bin/uname -s)"

control_dir="$(canonical_directory "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")")"
install_root="$(canonical_directory "$control_dir/..")"
[ "$control_dir" = "$install_root/control" ] ||
  die "runner must be invoked from a prepared candidate prefix"
reject_path_syntax "$install_root" "install prefix"
reject_linux_slash_tmp_location "$install_root" "install prefix"
assert_owned_private_directory "$(/usr/bin/dirname -- "$install_root")"
verify_candidate "$install_root" "$expected_candidate_sha256"
install_identity="$(stat_identity "$install_root")"

private_manifest="$install_root/control/private.json"
/usr/bin/jq -e '
  keys == ["git_common_dir", "schema", "source_root"] and
  .schema == "office.fresh-agent.private/1" and
  (.source_root | startswith("/")) and
  (.git_common_dir | startswith("/"))
' "$private_manifest" >/dev/null ||
  die "candidate private manifest failed strict validation"
source_root="$(canonical_directory "$(/usr/bin/jq -er '.source_root' "$private_manifest")")"
git_common_dir="$(
  canonical_directory "$(/usr/bin/jq -er '.git_common_dir' "$private_manifest")"
)"
reject_linux_slash_tmp_location "$source_root" "source checkout"
reject_linux_slash_tmp_location "$git_common_dir" "Git common directory"
reject_overlap "$install_root" "install prefix" "$source_root" "source checkout"
reject_overlap "$install_root" "install prefix" "$git_common_dir" "Git common directory"

auth_json=""
if [ "$canary_only" -eq 0 ]; then
  auth_json="$(canonical_regular_file "$auth_input" "Codex auth JSON")"
  assert_owned_private_file "$auth_json" "Codex auth JSON"
  reject_linux_slash_tmp_location "$auth_json" "Codex auth JSON"
fi
codex_source="$(canonical_regular_file "$codex_input" "Codex executable")"
[ -x "$codex_source" ] || die "Codex executable is not executable: $codex_source"
[ "$(sha256_file "$codex_source")" = "$expected_codex_sha256" ] ||
  die "Codex executable does not match the caller-supplied digest"
bwrap_source=""
if [ -n "$bwrap_input" ]; then
  bwrap_source="$(
    canonical_regular_file "$bwrap_input" "Codex bubblewrap executable"
  )"
  [ -x "$bwrap_source" ] ||
    die "Codex bubblewrap helper is not executable: $bwrap_source"
  [ "$(sha256_file "$bwrap_source")" = "$expected_bwrap_sha256" ] ||
    die "Codex bubblewrap executable does not match the caller-supplied digest"
fi

probe_root="$(canonical_absent_directory "$probe_input" "probe directory")"
evidence_root="$(
  canonical_absent_directory "$evidence_input" "evidence directory"
)"
reject_linux_slash_tmp_location "$probe_root" "probe directory"
reject_linux_slash_tmp_location "$evidence_root" "evidence directory"
reject_protected_location "$install_root" "install prefix"
reject_protected_location "$probe_root" "probe directory"
reject_protected_location "$evidence_root" "evidence directory"
reject_macos_platform_default_location "$install_root" "install prefix"
reject_macos_platform_default_location "$probe_root" "probe directory"
reject_macos_platform_default_location "$evidence_root" "evidence directory"
if [ -n "$auth_json" ]; then
  reject_macos_platform_default_location "$auth_json" "Codex auth JSON"
fi

reject_overlap "$probe_root" "probe directory" "$evidence_root" "evidence directory"
protected_inputs=("$install_root" "$source_root" "$git_common_dir" "$codex_source")
if [ -n "$bwrap_source" ]; then
  protected_inputs+=("$bwrap_source")
fi
for protected_path in "${protected_inputs[@]}"; do
  reject_overlap "$probe_root" "probe directory" "$protected_path" "protected input"
  reject_overlap "$evidence_root" "evidence directory" "$protected_path" "protected input"
done
if [ -n "$auth_json" ]; then
  reject_overlap "$probe_root" "probe directory" "$auth_json" "Codex auth JSON"
  reject_overlap "$evidence_root" "evidence directory" "$auth_json" "Codex auth JSON"
  reject_overlap "$install_root" "install prefix" "$auth_json" "Codex auth JSON"
fi
reject_overlap "$install_root" "install prefix" "$codex_source" "Codex executable"
if [ -n "$bwrap_source" ]; then
  reject_overlap \
    "$install_root" "install prefix" "$bwrap_source" "Codex bubblewrap executable"
fi

/bin/mkdir -m 0700 "$probe_root"
if ! /bin/mkdir -m 0700 "$evidence_root"; then
  /bin/rmdir "$probe_root" 2>/dev/null || true
  die "could not create evidence directory"
fi
assert_owned_private_directory "$probe_root"
assert_owned_private_directory "$evidence_root"
probe_identity="$(stat_identity "$probe_root")"
evidence_identity="$(stat_identity "$evidence_root")"

probe_parent="$(canonical_directory "$(/usr/bin/dirname -- "$probe_root")")"
isolation_root="$(/usr/bin/mktemp -d "$probe_parent/.office-f1b-isolation.XXXXXX")"
chmod 0700 "$isolation_root"
network_listener_pid=""
ambient_write_path=""

cleanup() {
  local status="$?"
  trap - EXIT HUP INT TERM
  if [ -n "${network_listener_pid:-}" ]; then
    /bin/kill "$network_listener_pid" 2>/dev/null || true
    wait "$network_listener_pid" 2>/dev/null || true
  fi
  if [ -n "${ambient_write_path:-}" ] && [ -d "$ambient_write_path" ]; then
    /bin/rmdir "$ambient_write_path" 2>/dev/null || true
  fi
  if [ -n "${isolation_root:-}" ] && [ -d "$isolation_root" ]; then
    chmod -R u+w -- "$isolation_root" 2>/dev/null || true
    /bin/rm -rf -- "$isolation_root"
  fi
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

assert_owned_private_directory "$isolation_root"
reject_path_syntax "$isolation_root" "isolation directory"
reject_overlap "$isolation_root" "isolation directory" "$install_root" "install prefix"
reject_overlap "$isolation_root" "isolation directory" "$evidence_root" "evidence directory"
if [ -n "$auth_json" ]; then
  reject_overlap "$isolation_root" "isolation directory" "$auth_json" "Codex auth JSON"
fi
if [ -n "$bwrap_source" ]; then
  reject_overlap \
    "$isolation_root" "isolation directory" "$bwrap_source" "Codex bubblewrap executable"
fi

isolated_user_home="$isolation_root/home"
isolated_codex_state="$isolation_root/codex"
isolated_codex_tmp="$isolated_codex_state/runtime-tmp"
isolated_tmp="$isolation_root/tmp"
isolated_launcher_bin="$isolation_root/launcher-bin"
candidate_root="$isolation_root/candidate"
isolated_codex_bin="$isolation_root/codex-bin"
isolated_codex_resources="$isolation_root/codex-resources"
/bin/mkdir -m 0700 \
  "$isolated_user_home" \
  "$isolated_codex_state" \
  "$isolated_codex_tmp" \
  "$isolated_tmp" \
  "$isolated_launcher_bin" \
  "$candidate_root" \
  "$isolated_codex_bin" \
  "$isolated_codex_resources"
printf '%s\n' 'non-secret permission sentinel' \
  > "$isolated_codex_state/credential-canary"
chmod 0600 "$isolated_codex_state/credential-canary"

/bin/cp -R "$install_root/." "$candidate_root/"
chmod 0500 "$candidate_root" "$candidate_root/bin" \
  "$candidate_root/control" "$candidate_root/libexec"
verify_candidate "$candidate_root" "$expected_candidate_sha256"
verify_candidate "$install_root" "$expected_candidate_sha256"
[ "$(stat_identity "$install_root")" = "$install_identity" ] ||
  die "install prefix identity changed while staging the candidate"

codex_bin="$isolated_codex_bin/codex"
/usr/bin/install -m 0500 "$codex_source" "$codex_bin"
assert_owned_file "$codex_bin" "0500" "1" "staged Codex executable"
[ "$(sha256_file "$codex_bin")" = "$expected_codex_sha256" ] ||
  die "staged Codex executable hash mismatch"
[ "$(sha256_file "$codex_source")" = "$expected_codex_sha256" ] ||
  die "approved Codex executable changed while it was staged"

codex_first_line=""
codex_is_native=0
IFS= read -r codex_first_line < "$codex_bin" || true
codex_first_line="${codex_first_line%$'\r'}"
case "$codex_first_line" in
  '#!/bin/sh') codex_argv=(/bin/sh "$codex_bin") ;;
  '#!/bin/bash') codex_argv=(/bin/bash -p "$codex_bin") ;;
  '#!'*) die "Codex script must use exactly #!/bin/sh or #!/bin/bash" ;;
  *)
    codex_is_native=1
    codex_argv=("$codex_bin")
    ;;
esac

bwrap_bin=""
bwrap_selection="none"
if [ "$platform_name" = "Linux" ] && [ "$codex_is_native" -eq 1 ]; then
  [ -n "$bwrap_source" ] ||
    die "native Linux Codex requires an approved bubblewrap executable and digest"
  system_bwrap="$(command -v bwrap || true)"
  if [ -n "$system_bwrap" ]; then
    system_bwrap="$(
      canonical_regular_file "$system_bwrap" "system bubblewrap executable"
    )"
    [ "$bwrap_source" = "$system_bwrap" ] ||
      die "the bubblewrap executable selected from sanitized PATH must be the caller-approved executable"
    bwrap_bin="$system_bwrap"
    bwrap_selection="system"
  else
    bwrap_bin="$isolated_codex_resources/bwrap"
    /usr/bin/install -m 0500 "$bwrap_source" "$bwrap_bin"
    bwrap_selection="private"
  fi
elif [ -n "$bwrap_source" ]; then
  die "a Codex bubblewrap executable is accepted only for native Linux Codex"
fi
verify_codex_runtime

codex_version="$(run_codex --version | /usr/bin/head -n 1)"
if [[ ! "$codex_version" =~ ^codex-cli[[:space:]]+([0-9]+)\.([0-9]+)\.([0-9]+)([-+][0-9A-Za-z.-]+)?$ ]]; then
  die "could not identify Codex CLI version: $codex_version"
fi
codex_major="${BASH_REMATCH[1]}"
codex_minor="${BASH_REMATCH[2]}"
if (( codex_major == 0 && codex_minor < 145 )); then
  die "Codex CLI 0.145.0 or newer is required: $codex_version"
fi

if [ "$platform_name" = "Darwin" ]; then
  ambient_write_path="$source_root/.office-f1b-deny-write.$$.$RANDOM"
else
  slash_tmp="$(canonical_directory /tmp)"
  ambient_write_path="$slash_tmp/.office-f1b-deny-write.$$.$RANDOM"
fi
[ ! -e "$ambient_write_path" ] && [ ! -L "$ambient_write_path" ] ||
  die "ambient permission-canary path unexpectedly exists"
start_loopback_listener
write_live_canary_launcher
write_office_launcher native
write_office_launcher wasm

probe_path="$isolated_launcher_bin:$candidate_root/bin:/usr/bin:/bin:/usr/sbin:/sbin"
for profile_name in .profile .bash_profile .zprofile .zlogin .zshenv; do
  printf 'PATH=%q\nexport PATH\nunset CDPATH CODEX_HOME\n' "$probe_path" \
    > "$isolated_user_home/$profile_name"
  chmod 0400 "$isolated_user_home/$profile_name"
done
chmod 0500 \
  "$isolated_user_home" \
  "$isolated_launcher_bin" \
  "$isolated_codex_bin" \
  "$isolated_codex_resources"

config_tmp="$isolated_codex_state/config.toml.tmp"
config_file="$isolated_codex_state/config.toml"
{
  printf '%s\n' \
    'default_permissions = "fresh_agent"' \
    'approval_policy = "never"' \
    'web_search = "disabled"' \
    'allow_login_shell = false' \
    'project_doc_max_bytes = 0' \
    'project_doc_fallback_filenames = []' \
    'check_for_update_on_startup = false' \
    'hooks = {}' \
    'mcp_servers = {}' \
    '' \
    '[features]' \
    'apps = false' \
    'browser_use = false' \
    'computer_use = false' \
    'in_app_browser = false' \
    'memories = false' \
    'multi_agent = false' \
    'plugins = false' \
    'skill_search = false' \
    '' \
    '[shell_environment_policy]' \
    'inherit = "none"' \
    'experimental_use_profile = false' \
    '' \
    '[shell_environment_policy.set]'
  printf 'HOME = %s\n' "$(toml_string "$isolated_user_home")"
  printf 'ZDOTDIR = %s\n' "$(toml_string "$isolated_user_home")"
  printf 'PATH = %s\n' "$(toml_string "$probe_path")"
  printf 'TMPDIR = %s\n' "$(toml_string "$isolated_codex_tmp")"
  printf '%s\n' \
    'LANG = "C"' \
    'LC_ALL = "C"' \
    '' \
    '[permissions.fresh_agent]' \
    'description = "Installed Office probe with explicit least-privilege roots."' \
    '' \
    '[permissions.fresh_agent.filesystem]' \
    '":slash_tmp" = "deny"' \
    '":minimal" = "read"'
  printf '%s = "deny"\n' "$(toml_string "$install_root")"
  if [ "$platform_name" = "Linux" ] && [ -d /etc ]; then
    printf '%s = "deny"\n' "$(toml_string /etc)"
  fi
  if [ -d /proc ]; then
    printf '%s = "deny"\n' "$(toml_string /proc)"
  fi
  printf '%s = "deny"\n' "$(toml_string "$source_root")"
  if ! path_is_within_or_equal "$git_common_dir" "$source_root"; then
    printf '%s = "deny"\n' "$(toml_string "$git_common_dir")"
  fi
  if [ -n "$auth_json" ]; then
    if ! path_is_within_or_equal "$auth_json" "$source_root" &&
      ! path_is_within_or_equal "$auth_json" "$git_common_dir"; then
      printf '%s = "deny"\n' "$(toml_string "$auth_json")"
    fi
  fi
  printf '%s = "deny"\n' "$(toml_string "$isolated_codex_state")"
  printf '%s = "deny"\n' "$(toml_string "$isolated_codex_resources")"
  printf '%s = "deny"\n' "$(toml_string "$evidence_root")"
  printf '%s = "deny"\n' "$(toml_string "$candidate_root/control")"
  printf '%s = "deny"\n' "$(toml_string "$candidate_root/CANDIDATE.json")"
  printf '%s = "read"\n' "$(toml_string "$candidate_root")"
  printf '%s = "read"\n' "$(toml_string "$isolated_user_home")"
  printf '%s = "read"\n' "$(toml_string "$isolated_launcher_bin")"
  # Linux bubblewrap re-enters this exact executable inside the namespace.
  printf '%s = "read"\n' "$(toml_string "$isolated_codex_bin")"
  printf '%s = "write"\n' "$(toml_string "$probe_root")"
  printf '%s = "write"\n' "$(toml_string "$isolated_tmp")"
  printf '%s\n' \
    '' \
    '[permissions.fresh_agent.network]' \
    'enabled = false'
  printf '\n[projects.%s]\n' "$(toml_string "$probe_root")"
  printf 'trust_level = "trusted"\n'
} > "$config_tmp"
chmod 0600 "$config_tmp"
/bin/mv "$config_tmp" "$config_file"
config_sha256_before="$(sha256_file "$config_file")"

set +e
run_codex sandbox \
  --include-managed-config \
  -P fresh_agent \
  -C "$probe_root" \
  -c 'default_permissions="fresh_agent"' \
  -c 'approval_policy="never"' \
  -c 'web_search="disabled"' \
  -c 'hooks={}' \
  -c 'mcp_servers={}' \
  /usr/bin/env -i \
  HOME="$isolated_user_home" \
  ZDOTDIR="$isolated_user_home" \
  PATH="$probe_path" \
  TMPDIR="$isolated_tmp" \
  LANG=C \
  LC_ALL=C \
  "$isolated_launcher_bin/office-permission-canary" \
  > "$evidence_root/permission-canary.log" 2>&1
canary_status="$?"
set -e
if [ "$canary_status" -ne 0 ]; then
  echo "error: Codex permission-profile canary log follows" >&2
  /bin/cat "$evidence_root/permission-canary.log" >&2
  die "Codex permission-profile canary failed; see $evidence_root/permission-canary.log"
fi
if [ "$(/usr/bin/wc -l < "$evidence_root/permission-canary.log" | /usr/bin/tr -d ' ')" != "1" ] ||
  ! /usr/bin/grep -qx 'FRESH-AGENT PERMISSION CANARY PASS' \
    "$evidence_root/permission-canary.log"; then
  die "Codex permission-profile canary did not report an exact PASS"
fi
[ ! -e "$ambient_write_path" ] && [ ! -L "$ambient_write_path" ] ||
  die "permission canary created its ambient write path"
[ "$(/usr/bin/find "$probe_root" -mindepth 1 -print -quit)" = "" ] ||
  die "permission canary left the probe directory non-empty"
[ "$(/usr/bin/find "$isolated_tmp" -mindepth 1 -print -quit)" = "" ] ||
  die "permission canary left the isolated scratch directory non-empty"
verify_codex_runtime

runner_sha256="$(sha256_file "$candidate_root/control/run.sh")"
prompt_sha256="$(sha256_file "$candidate_root/control/prompt.md")"
output_schema_sha256="$(sha256_file "$candidate_root/control/final.schema.json")"
canary_sha256="$(sha256_file "$evidence_root/permission-canary.log")"
bwrap_evidence_json="$(
  /usr/bin/jq -cn \
    --arg selection "$bwrap_selection" \
    --arg sha256 "$expected_bwrap_sha256" \
    'if $selection == "none" then null else {
      selection: $selection,
      sha256: $sha256,
      privately_staged: ($selection == "private")
    } end'
)"

/usr/bin/jq -n \
  --arg schema "office.fresh-agent.run-preflight/2" \
  --arg candidate_head "$expected_head" \
  --arg candidate_manifest_sha256 "$expected_candidate_sha256" \
  --arg runner_sha256 "$runner_sha256" \
  --arg prompt_sha256 "$prompt_sha256" \
  --arg output_schema_sha256 "$output_schema_sha256" \
  --arg codex_version "$codex_version" \
  --arg codex_sha256 "$expected_codex_sha256" \
  --argjson bubblewrap "$bwrap_evidence_json" \
  --arg config_sha256 "$config_sha256_before" \
  --arg permission_canary_sha256 "$canary_sha256" \
  '{
    schema: $schema,
    candidate_head: $candidate_head,
    candidate_manifest_sha256: $candidate_manifest_sha256,
    harness: {
      runner_sha256: $runner_sha256,
      prompt_sha256: $prompt_sha256,
      output_schema_sha256: $output_schema_sha256,
      config_sha256: $config_sha256,
      permission_canary_sha256: $permission_canary_sha256
    },
    codex: {
      version: $codex_version,
      sha256: $codex_sha256,
      privately_staged: true,
      bubblewrap: $bubblewrap
    }
  }' > "$isolation_root/RUN-PREFLIGHT.json"
/usr/bin/install -m 0600 "$isolation_root/RUN-PREFLIGHT.json" \
  "$evidence_root/RUN-PREFLIGHT.json"
/usr/bin/install -m 0600 "$config_file" "$evidence_root/CONFIG.toml"
/usr/bin/install -m 0600 "$candidate_root/CANDIDATE.json" \
  "$evidence_root/CANDIDATE.json"

if [ "$canary_only" -eq 1 ]; then
  verify_candidate "$install_root" "$expected_candidate_sha256"
  verify_candidate "$candidate_root" "$expected_candidate_sha256"
  verify_codex_runtime
  [ "$(sha256_file "$config_file")" = "$config_sha256_before" ] ||
    die "Codex isolation config changed during the canary"
  /usr/bin/jq -n \
    --arg schema "office.fresh-agent.canary-run/1" \
    --arg candidate_head "$expected_head" \
    --arg candidate_manifest_sha256 "$expected_candidate_sha256" \
    --arg codex_version "$codex_version" \
    --arg codex_sha256 "$expected_codex_sha256" \
    --argjson bubblewrap "$bwrap_evidence_json" \
    --arg config_sha256 "$config_sha256_before" \
    --arg permission_canary_sha256 "$canary_sha256" \
    '{
      schema: $schema,
      candidate_head: $candidate_head,
      candidate_manifest_sha256: $candidate_manifest_sha256,
      codex: {
        version: $codex_version,
        sha256: $codex_sha256,
        bubblewrap: $bubblewrap
      },
      isolation_config_sha256: $config_sha256,
      permission_canary_sha256: $permission_canary_sha256,
      verdict: "CANARY PASS"
    }' > "$isolation_root/RUN.json"
  /usr/bin/install -m 0600 "$isolation_root/RUN.json" "$evidence_root/RUN.json"
  write_canary_evidence_manifest
  printf 'probe_dir=%s\n' "$probe_root"
  printf 'evidence_dir=%s\n' "$evidence_root"
  printf 'verdict=CANARY PASS\n'
  exit 0
fi

verify_candidate "$install_root" "$expected_candidate_sha256"
verify_candidate "$candidate_root" "$expected_candidate_sha256"
[ "$(stat_identity "$install_root")" = "$install_identity" ] ||
  die "install prefix identity changed before the probe"
[ "$(stat_identity "$probe_root")" = "$probe_identity" ] ||
  die "probe directory identity changed before the probe"
[ "$(stat_identity "$evidence_root")" = "$evidence_identity" ] ||
  die "evidence directory identity changed before the probe"
verify_codex_runtime

# The real credential enters the isolation only after every unauthenticated
# preflight and sandbox check has succeeded. The cleanup trap has been armed
# since the isolation root was created.
/usr/bin/install -m 0600 "$auth_json" "$isolated_codex_state/auth.json"

set +e
run_codex exec \
  --ephemeral \
  --skip-git-repo-check \
  --ignore-rules \
  --strict-config \
  --json \
  -m gpt-5.6-sol \
  -c 'model_reasoning_effort="max"' \
  -c 'default_permissions="fresh_agent"' \
  -c 'approval_policy="never"' \
  -c 'web_search="disabled"' \
  -c 'hooks={}' \
  -c 'mcp_servers={}' \
  -C "$probe_root" \
  --output-schema "$candidate_root/control/final.schema.json" \
  --output-last-message "$evidence_root/final-message.json" \
  - < "$candidate_root/control/prompt.md" \
  > "$evidence_root/codex-transcript.jsonl" \
  2> "$evidence_root/codex-stderr.log"
codex_status="$?"
set -e

printf 'codex_exit_status=%s\n' "$codex_status" \
  > "$evidence_root/codex-exit-status.txt"
chmod u+w "$isolated_codex_state/auth.json" 2>/dev/null || true
/bin/rm -f -- "$isolated_codex_state/auth.json"

verify_candidate "$install_root" "$expected_candidate_sha256"
verify_candidate "$candidate_root" "$expected_candidate_sha256"
verify_codex_runtime
[ "$(sha256_file "$config_file")" = "$config_sha256_before" ] ||
  die "Codex isolation config changed during the probe"
[ "$(stat_identity "$install_root")" = "$install_identity" ] ||
  die "install prefix identity changed during the probe"
[ "$(stat_identity "$probe_root")" = "$probe_identity" ] ||
  die "probe directory identity changed during the probe"
[ "$(stat_identity "$evidence_root")" = "$evidence_identity" ] ||
  die "evidence directory identity changed during the probe"
[ "$(/usr/bin/find "$isolated_tmp" -mindepth 1 -print -quit)" = "" ] ||
  die "Office probe left the isolated child scratch directory non-empty"

[ "$codex_status" -eq 0 ] || {
  echo "error: Codex probe exited with status $codex_status" >&2
  exit "$codex_status"
}

assert_owned_private_file "$evidence_root/final-message.json" "Codex final message"
assert_owned_private_file "$evidence_root/codex-transcript.jsonl" "Codex transcript"
assert_owned_private_file "$evidence_root/codex-stderr.log" "Codex stderr"
[ -s "$evidence_root/codex-transcript.jsonl" ] ||
  die "Codex JSONL transcript is empty"

while IFS= read -r json_line || [ -n "$json_line" ]; do
  [ -n "$json_line" ] || die "Codex JSONL transcript contains a blank line"
  printf '%s\n' "$json_line" | /usr/bin/jq -e \
    'type == "object" and (.type | type == "string")' >/dev/null ||
    die "Codex transcript contains a malformed JSONL event"
done < "$evidence_root/codex-transcript.jsonl"
/usr/bin/jq -s '.' "$evidence_root/codex-transcript.jsonl" \
  > "$isolation_root/transcript-array.json"
/usr/bin/jq -e '
  def exact_canary_command:
    . == "office-permission-canary" or
    . == "/bin/sh -c office-permission-canary" or
    . == "/bin/sh -c '\''office-permission-canary'\''" or
    . == "/bin/bash -c office-permission-canary" or
    . == "/bin/bash -c '\''office-permission-canary'\''" or
    . == "/bin/zsh -c office-permission-canary" or
    . == "/bin/zsh -c '\''office-permission-canary'\''";
  ([.[] | select(.type == "item.started" and .item.type == "command_execution") | .item]) as $started |
  ([.[] | select(.type == "item.completed" and .item.type == "command_execution") | .item]) as $completed |
  ([.[] | select(.item?.type == "command_execution")][0]) as $first_event |
  ($started | length) > 0 and
  ($started | map(.id) | length) == ($started | map(.id) | unique | length) and
  ($completed | map(.id) | length) == ($completed | map(.id) | unique | length) and
  ($started | map({id, command}) | sort_by(.id)) ==
    ($completed | map({id, command}) | sort_by(.id)) and
  all($completed[];
    (.exit_code | type) == "number" and
    ((.status == "completed" and .exit_code == 0) or
     (.status == "failed" and .exit_code != 0))) and
  $first_event.type == "item.started" and
  ($first_event.item.command | exact_canary_command) and
  ([ $completed[] | select(.id == $first_event.item.id) ][0] |
    .exit_code == 0 and
    .aggregated_output == "FRESH-AGENT PERMISSION CANARY PASS\n" and
    (.command | exact_canary_command))
' "$isolation_root/transcript-array.json" >/dev/null ||
  die "Codex command events were incomplete or the first live command was not the exact permission canary"

/usr/bin/jq '[
  .[] |
  select(.type == "item.completed" and .item.type == "command_execution") |
  .item |
  {
    id,
    command,
    status,
    exit_code,
    output_bytes: (.aggregated_output | length)
  }
]' "$isolation_root/transcript-array.json" > "$isolation_root/COMMANDS.json"
/usr/bin/install -m 0600 "$isolation_root/COMMANDS.json" \
  "$evidence_root/COMMANDS.json"

for runtime in native wasm; do
  for verb in help batch identify outline get text query validate issues preview template dump replay raw annotate; do
    assert_recorded_office_command "$runtime" "$verb"
  done
  assert_recorded_office_format "$runtime" xlsx
  assert_recorded_office_format "$runtime" docx
done

/usr/bin/jq -e '
  keys == ["gaps", "result_path", "targets", "transcript_path", "verdict"] and
  (.verdict == "BASELINE PASS" or .verdict == "BASELINE FAIL") and
  .result_path == "probe-result.md" and
  .transcript_path == "probe-transcript.md" and
  (.targets | keys) == ["native", "wasm"] and
  ([.targets.native, .targets.wasm] |
    map(keys == ["docx", "xlsx"] and
      (.docx == "PASS" or .docx == "FAIL") and
      (.xlsx == "PASS" or .xlsx == "FAIL")) | all) and
  (.gaps | type) == "array" and
  (.gaps | map(
    keys == ["severity", "summary"] and
    (.severity == "P0" or .severity == "P1" or .severity == "P2" or .severity == "P3") and
    (.summary | type == "string" and length > 0)
  ) | all)
' "$evidence_root/final-message.json" >/dev/null ||
  die "Codex final message did not match the required structured result"

verdict="$(/usr/bin/jq -er '.verdict' "$evidence_root/final-message.json")"
if [ "$verdict" = "BASELINE PASS" ]; then
  /usr/bin/jq -e '
    ([.targets.native.xlsx, .targets.native.docx,
      .targets.wasm.xlsx, .targets.wasm.docx] | all(. == "PASS")) and
    (.gaps | all(.severity == "P3"))
  ' "$evidence_root/final-message.json" >/dev/null ||
    die "BASELINE PASS contradicts target outcomes or P0-P2 gaps"
else
  /usr/bin/jq -e '
    ([.targets.native.xlsx, .targets.native.docx,
      .targets.wasm.xlsx, .targets.wasm.docx] | any(. == "FAIL")) or
    (.gaps | any(.severity == "P0" or .severity == "P1" or .severity == "P2"))
  ' "$evidence_root/final-message.json" >/dev/null ||
    die "BASELINE FAIL has no failed target or P0-P2 gap"
fi

result_file="$probe_root/probe-result.md"
transcript_file="$probe_root/probe-transcript.md"
assert_owned_private_file "$result_file" "probe result"
assert_owned_private_file "$transcript_file" "probe transcript"
[ -s "$result_file" ] || die "probe result is empty"
[ -s "$transcript_file" ] || die "probe transcript is empty"
IFS= read -r result_header < "$result_file" || true
[ "$result_header" = "Verdict: $verdict" ] ||
  die "probe result does not begin with the exact structured verdict"

/usr/bin/install -m 0600 "$result_file" "$evidence_root/probe-result.md"
/usr/bin/install -m 0600 "$transcript_file" "$evidence_root/probe-transcript.md"

/usr/bin/jq -n \
  --arg schema "office.fresh-agent.run/2" \
  --arg candidate_head "$expected_head" \
  --arg candidate_manifest_sha256 "$expected_candidate_sha256" \
  --arg verdict "$verdict" \
  --argjson codex_exit_status "$codex_status" \
  --arg codex_sha256 "$expected_codex_sha256" \
  --argjson bubblewrap "$bwrap_evidence_json" \
  --arg config_sha256 "$config_sha256_before" \
  --arg result_sha256 "$(sha256_file "$result_file")" \
  --arg transcript_sha256 "$(sha256_file "$transcript_file")" \
  --arg raw_transcript_sha256 "$(sha256_file "$evidence_root/codex-transcript.jsonl")" \
  --arg stderr_sha256 "$(sha256_file "$evidence_root/codex-stderr.log")" \
  --arg commands_sha256 "$(sha256_file "$evidence_root/COMMANDS.json")" \
  --arg final_message_sha256 "$(sha256_file "$evidence_root/final-message.json")" \
  '{
    schema: $schema,
    candidate_head: $candidate_head,
    candidate_manifest_sha256: $candidate_manifest_sha256,
    verdict: $verdict,
    codex_exit_status: $codex_exit_status,
    integrity: {
      codex_sha256: $codex_sha256,
      bubblewrap: $bubblewrap,
      isolation_config_sha256: $config_sha256,
      privately_staged_candidate: true,
      privately_staged_codex: true
    },
    evidence: {
      result_sha256: $result_sha256,
      chronological_transcript_sha256: $transcript_sha256,
      raw_codex_transcript_sha256: $raw_transcript_sha256,
      codex_stderr_sha256: $stderr_sha256,
      commands_sha256: $commands_sha256,
      final_message_sha256: $final_message_sha256
    }
  }' > "$isolation_root/RUN.json"
/usr/bin/install -m 0600 "$isolation_root/RUN.json" "$evidence_root/RUN.json"
write_evidence_manifest

printf 'probe_dir=%s\n' "$probe_root"
printf 'evidence_dir=%s\n' "$evidence_root"
printf 'verdict=%s\n' "$verdict"

[ "$verdict" = "BASELINE PASS" ] || exit 3

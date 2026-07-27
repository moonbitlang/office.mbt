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
unset PERL5OPT PERL5LIB TAR_OPTIONS POSIXLY_CORRECT BLOCKSIZE

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

validate_timeout_seconds() {
  local value="$1"
  local maximum="$2"
  local label="$3"
  case "$value" in
    "" | *[!0-9]*) die "$label must be an integer number of seconds" ;;
  esac
  if (( value < 1 || value > maximum )); then
    die "$label must be between 1 and $maximum seconds"
  fi
}

sha256_file() {
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/shasum -a 256 "$1" |
    /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
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

stat_size() {
  if /usr/bin/stat -f '%z' "$1" >/dev/null 2>&1; then
    /usr/bin/stat -f '%z' "$1"
  else
    /usr/bin/stat -c '%s' "$1"
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

assert_empty_directory() {
  local path="$1"
  local label="$2"
  local first_entry
  if ! first_entry="$(/usr/bin/find "$path" -mindepth 1 -print -quit)"; then
    die "could not inspect $label for unexpected content"
  fi
  [ -z "$first_entry" ] || die "$label is not empty"
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
  local build_platform
  local toolchain_header
  local dependency_header
  local build_host_header
  local observed_native_plan_sha256

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
      .schema == "office.fresh-agent.candidate/5" and
      .candidate_head == $head and
      (.build | keys) == [
        "build_host_manifest_sha256",
        "build_host_sha256",
        "build_lock_sha256",
        "dependency_manifest_sha256",
        "moon_sha256",
        "moon_version",
        "moonc_sha256",
        "moonc_version",
        "moonrun_version",
        "platform",
        "source_tree",
        "toolchain_manifest_sha256"
      ] and
      (.build.build_lock_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.build_host_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.build_host_manifest_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.dependency_manifest_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.toolchain_manifest_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.moonc_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.moon_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.platform == "darwin-arm64" or
        .build.platform == "linux-x86_64") and
      (.build.source_tree | test("^[0-9a-f]{40}$")) and
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
        "control/attest.py",
        "control/command-policy.py",
        "control/private.json",
        "control/inventory.sh",
        "control/build-lock.json",
        "control/toolchain.manifest",
        "control/dependencies.manifest",
        "control/build-host.json",
        "control/build-host.manifest"
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
control/attest.py|0400
control/command-policy.py|0400
control/private.json|0400
control/inventory.sh|0500
control/build-lock.json|0400
control/toolchain.manifest|0400
control/dependencies.manifest|0400
control/build-host.json|0400
control/build-host.manifest|0400
EOF

  while IFS='|' read -r field relative; do
    [ "$(/usr/bin/jq -er --arg field "$field" '.build[$field]' "$manifest")" = \
      "$(/usr/bin/jq -er --arg path "$relative" \
        '.files[] | select(.path == $path) | .sha256' "$manifest")" ] ||
      die "candidate build provenance does not bind $relative"
  done <<'EOF'
build_lock_sha256|control/build-lock.json
toolchain_manifest_sha256|control/toolchain.manifest
dependency_manifest_sha256|control/dependencies.manifest
build_host_sha256|control/build-host.json
build_host_manifest_sha256|control/build-host.manifest
EOF
  build_platform="$(/usr/bin/jq -er '.build.platform' "$manifest")"
  /usr/bin/jq -e \
    --arg platform "$build_platform" \
    --arg toolchain_sha256 \
      "$(/usr/bin/jq -er '.build.toolchain_manifest_sha256' "$manifest")" \
    --arg dependency_sha256 \
      "$(/usr/bin/jq -er '.build.dependency_manifest_sha256' "$manifest")" \
    '
      .schema == "office.fresh-agent.build-lock/1" and
      .dependencies.manifest_sha256 == $dependency_sha256 and
      ([.toolchains[] | select(
        .platform == $platform and
        .manifest_sha256 == $toolchain_sha256
      )] | length) == 1
    ' "$root/control/build-lock.json" >/dev/null ||
    die "retained build lock contradicts the candidate provenance"
  IFS= read -r toolchain_header < "$root/control/toolchain.manifest" || true
  [ "$toolchain_header" = \
    "office.fresh-agent.tree-manifest/1"$'\t'"$build_platform" ] ||
    die "retained toolchain inventory has an unexpected header"
  IFS= read -r dependency_header < "$root/control/dependencies.manifest" || true
  [ "$dependency_header" = \
    "office.fresh-agent.tree-manifest/1"$'\t'"dependencies" ] ||
    die "retained dependency inventory has an unexpected header"
  IFS= read -r build_host_header < "$root/control/build-host.manifest" || true
  [ "$build_host_header" = \
    "office.fresh-agent.tree-manifest/1"$'\t'"build-host" ] ||
    die "retained build-host inventory has an unexpected header"
  /usr/bin/jq -e \
    --arg platform "$build_platform" \
    --arg manifest_sha256 "$(
      /usr/bin/jq -er '.build.build_host_manifest_sha256' "$manifest"
    )" '
      keys == ["archiver", "assembler", "compiler", "environment", "host",
        "inventory", "linker", "native_plan", "platform", "schema", "sdk"] and
      .schema == "office.fresh-agent.build-host/1" and
      .platform == $platform and
      (.environment | keys) == ["moon_ar", "moon_cc", "sdkroot"] and
      (.environment.moon_cc | startswith("/")) and
      (.environment.moon_ar | startswith("/")) and
      (.environment.sdkroot == null or
        (.environment.sdkroot | startswith("/"))) and
      (.compiler | keys) == ["resolved_path", "resource_dir", "selected_path",
        "sha256", "target", "version"] and
      .compiler.selected_path == .environment.moon_cc and
      .compiler.selected_path == .compiler.resolved_path and
      (.compiler.resolved_path | startswith("/")) and
      (.compiler.resource_dir | startswith("/")) and
      (.compiler.sha256 | test("^[0-9a-f]{64}$")) and
      (.compiler.target | type) == "string" and
      (.compiler.target | length) > 0 and
      (.compiler.version | type) == "string" and
      (.compiler.version | length) > 0 and
      (.archiver | keys) == ["resolved_path", "selected_path", "sha256"] and
      .archiver.selected_path == .environment.moon_ar and
      .archiver.selected_path == .archiver.resolved_path and
      (.archiver.resolved_path | startswith("/")) and
      (.archiver.sha256 | test("^[0-9a-f]{64}$")) and
      (.linker | keys) == ["resolved_path", "sha256", "version"] and
      (.linker.resolved_path | startswith("/")) and
      (.linker.sha256 | test("^[0-9a-f]{64}$")) and
      (.linker.version | type) == "string" and
      (.linker.version | length) > 0 and
      (.assembler | keys) == ["resolved_path", "sha256"] and
      (.assembler.resolved_path | startswith("/")) and
      (.assembler.sha256 | test("^[0-9a-f]{64}$")) and
      (.host | keys) == ["identity_path", "identity_sha256", "kernel"] and
      (.host.identity_path | startswith("/")) and
      (.host.identity_sha256 | test("^[0-9a-f]{64}$")) and
      (.host.kernel | type) == "string" and (.host.kernel | length) > 0 and
      (.sdk | keys) == ["kind", "path", "version"] and
      (.sdk.path | startswith("/")) and
      (.sdk.version | type) == "string" and (.sdk.version | length) > 0 and
      (if $platform == "darwin-arm64" then
        .sdk.kind == "macos-sdk" and .environment.sdkroot == .sdk.path
      else
        .sdk.kind == "linux-sysroot" and .environment.sdkroot == null
      end) and
      (.inventory | keys) == ["entries", "manifest_sha256", "root"] and
      .inventory.root == "/" and
      (.inventory.entries | type) == "array" and
      (.inventory.entries | length) > 0 and
      (.inventory.entries | all(type == "string" and length > 0)) and
      (.inventory.entries | unique | length) == (.inventory.entries | length) and
      .inventory.manifest_sha256 == $manifest_sha256 and
      (.native_plan | keys) == ["commands", "sha256"] and
      (.native_plan.sha256 | test("^[0-9a-f]{64}$")) and
      (.native_plan.commands | type) == "array" and
      (.native_plan.commands | length) > 0 and
      (.native_plan.commands | all(type == "string" and length > 0)) and
      (. as $host |
        any(.native_plan.commands[];
          startswith($host.environment.moon_cc + " ")) and
        any(.native_plan.commands[];
          startswith($host.environment.moon_ar + " ")))
    ' "$root/control/build-host.json" >/dev/null ||
    die "retained native build-host provenance failed strict validation"
  observed_native_plan_sha256="$(
    /usr/bin/jq -r '.native_plan.commands[]' \
      "$root/control/build-host.json" |
      /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
        /usr/bin/shasum -a 256 |
      /usr/bin/awk '{print substr($1, length($1) - 63)}'
  )"
  [ "$observed_native_plan_sha256" = "$(
    /usr/bin/jq -er '.native_plan.sha256' "$root/control/build-host.json"
  )" ] || die "retained native build plan hash is inconsistent"

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
      control/build-host.json \
      control/build-host.manifest \
      control/final.schema.json \
      control/attest.py \
      control/command-policy.py \
      control/build-lock.json \
      control/dependencies.manifest \
      control/inventory.sh \
      control/permission-canary.sh \
      control/private.json \
      control/prompt.md \
      control/run.sh \
      control/toolchain.manifest \
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
  local unsupported_entry
  if ! unsupported_entry="$(
    /usr/bin/find "$root" -mindepth 1 \
      ! -type d ! -type f ! -type l -print -quit
  )"; then
    die "could not inspect the candidate filesystem entry types"
  fi
  if [ -n "$unsupported_entry" ]; then
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

remove_isolated_auth() {
  local codex_state="${isolated_codex_state:-}"
  local observed_identity
  local staged_auth
  [ -n "$codex_state" ] || return 0
  staged_auth="$codex_state/auth.json"
  if [ -e "$staged_auth" ] || [ -L "$staged_auth" ]; then
    observed_identity="$(stat_identity "$codex_state" 2>/dev/null || true)"
    if [ -n "${isolated_codex_state_identity:-}" ] &&
      { [ ! -d "$codex_state" ] || [ -L "$codex_state" ] ||
        [ "$observed_identity" != "$isolated_codex_state_identity" ]; }; then
      return 1
    fi
    chmod u+rwx -- "$codex_state" 2>/dev/null || true
    chmod u+rw -- "$staged_auth" 2>/dev/null || true
    /bin/rm -f -- "$staged_auth" 2>/dev/null || true
  fi
  [ ! -e "$staged_auth" ] && [ ! -L "$staged_auth" ]
}

process_is_live() {
  local pid="$1"
  local state
  state="$(/bin/ps -o stat= -p "$pid" 2>/dev/null | /usr/bin/tr -d ' ')"
  case "$state" in
    "" | Z*) return 1 ;;
    *) return 0 ;;
  esac
}

process_group_has_live_processes() {
  local pgid="$1"
  /bin/ps -axo pgid=,stat= 2>/dev/null |
    /usr/bin/awk -v expected="$pgid" '
      $1 == expected && $2 !~ /^Z/ { found = 1 }
      END { exit(found ? 0 : 1) }
    '
}

terminate_supervised_codex() {
  local attempt
  local pid="${codex_pid:-}"
  local pgid="${codex_pgid:-}"
  local auth_removed=1
  local first_signal=TERM
  local survived=0
  if ! remove_isolated_auth; then
    auth_removed=0
    # Do not give a process a graceful-shutdown window while its staged
    # credential is still present. A direct KILL is the fail-closed fallback.
    first_signal=KILL
  fi
  if [ -n "$pgid" ] && [ -n "$pid" ] && [ "$pgid" = "$pid" ]; then
    if process_group_has_live_processes "$pgid"; then
      /bin/kill -"$first_signal" "-$pgid" 2>/dev/null || true
      for attempt in {1..20}; do
        process_group_has_live_processes "$pgid" || break
        /bin/sleep 0.1
      done
      if [ "$first_signal" = TERM ] &&
        process_group_has_live_processes "$pgid"; then
        /bin/kill -KILL "-$pgid" 2>/dev/null || true
        for attempt in {1..20}; do
          process_group_has_live_processes "$pgid" || break
          /bin/sleep 0.1
        done
      fi
      if process_group_has_live_processes "$pgid"; then
        survived=1
      fi
    fi
  elif [ -n "$pid" ] && process_is_live "$pid"; then
    /bin/kill -"$first_signal" "$pid" 2>/dev/null || true
    for attempt in {1..20}; do
      process_is_live "$pid" || break
      /bin/sleep 0.1
    done
    if [ "$first_signal" = TERM ] && process_is_live "$pid"; then
      /bin/kill -KILL "$pid" 2>/dev/null || true
      for attempt in {1..20}; do
        process_is_live "$pid" || break
        /bin/sleep 0.1
      done
    fi
    if process_is_live "$pid"; then
      survived=1
    fi
  fi
  if [ -n "$pid" ] && ! process_is_live "$pid"; then
    wait "$pid" 2>/dev/null || true
  fi
  remove_isolated_auth || survived=1
  [ "$auth_removed" -eq 1 ] || survived=1
  codex_pid=""
  codex_pgid=""
  [ "$survived" -eq 0 ]
}

arm_codex_supervision() {
  local pid="$1"
  local observed_pgid
  codex_pid="$pid"
  codex_pgid="$pid"
  if /bin/kill -0 "$pid" 2>/dev/null; then
    observed_pgid="$(
      /bin/ps -o pgid= -p "$pid" 2>/dev/null | /usr/bin/tr -d ' '
    )" || true
    if [ -n "$observed_pgid" ] && [ "$observed_pgid" != "$pid" ]; then
      # Never signal an unexpected process group: it may be the runner's own
      # group. Clear the group claim and use bounded direct termination.
      codex_pgid=""
      terminate_supervised_codex ||
        die "Codex child in an unexpected process group survived termination"
      die "Codex child did not enter its dedicated process group"
    fi
  fi
}

supervised_codex_leader_is_running() {
  local pid="${codex_pid:-}"
  [ -n "$pid" ] && process_is_live "$pid"
}

wait_for_supervised_codex() {
  local operation="$1"
  local timeout_seconds="$2"
  local deadline=$((SECONDS + timeout_seconds))
  local timed_out=0
  local leader_status

  while supervised_codex_leader_is_running; do
    if (( SECONDS >= deadline )); then
      timed_out=1
      break
    fi
    /bin/sleep 0.1
  done

  if [ "$timed_out" -eq 0 ]; then
    set +e
    wait "$codex_pid"
    leader_status="$?"
    set -e
  else
    leader_status=124
  fi

  # Keep the dedicated PGID until every descendant has been terminated. A
  # Codex launcher may exit after forking a child, so the leader alone is not a
  # sufficient lifecycle boundary.
  if ! terminate_supervised_codex; then
    die "Codex $operation left a process that survived TERM/KILL escalation"
  fi
  if [ "$timed_out" -eq 1 ]; then
    echo "error: Codex $operation exceeded its ${timeout_seconds}s deadline" >&2
    supervised_codex_status=124
  else
    supervised_codex_status="$leader_status"
  fi
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
    if /bin/kill -0 "$network_listener_pid" 2>/dev/null; then
      network_port="$port"
      if assert_loopback_listener_reachable; then
        return 0
      fi
    fi
    /bin/kill "$network_listener_pid" 2>/dev/null || true
    wait "$network_listener_pid" 2>/dev/null || true
    network_listener_pid=""
  done
  die "netcat does not support the required 'nc -l -k HOST PORT' listener form, or no loopback port could be bound"
}

assert_loopback_listener_reachable() {
  [ -n "${network_listener_pid:-}" ] &&
    /bin/kill -0 "$network_listener_pid" 2>/dev/null ||
    return 1
  /bin/bash -p -c 'exec 3<>/dev/tcp/127.0.0.1/$1; exec 3>&-; exec 3<&-' \
    office-listener "$network_port" >/dev/null 2>&1 || return 1
  /bin/kill -0 "$network_listener_pid" 2>/dev/null
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
      "$platform_name" \
      "$policy_readonly_root"
    printf '\n'
  } > "$launcher"
  chmod 0500 "$launcher"
}

write_office_launcher() {
  local runtime="$1"
  local launcher="$isolated_launcher_bin/office-$runtime"
  local target="$candidate_root/bin/office-$runtime"
  local attester="$candidate_root/control/attest.py"
  {
    printf '%s\n' '#!/bin/bash -p' 'set -euo pipefail'
    printf 'TMPDIR=%q\nexport TMPDIR\n' "$isolated_tmp"
    printf 'target=%q\n' "$target"
    printf 'attester=%q\n' "$attester"
    printf '%s\n' \
      'args=("$@")' \
      'count=${#args[@]}' \
      'if (( count >= 2 )); then' \
      '  marker_index=$((count - 2))' \
      '  result_index=$((count - 1))' \
      '  if [ "${args[$marker_index]}" = --attest-result ]; then' \
      '    result=${args[$result_index]}' \
      '    unset '\''args[$marker_index]'\'' '\''args[$result_index]'\''' \
      '    exec /usr/bin/python3 -I "$attester" "$target" "$result" "${args[@]}"' \
      '  fi' \
      'fi'
    printf '%s\n' 'exec "$target" "$@"'
  } > "$launcher"
  chmod 0500 "$launcher"
}

write_host_command_transcript() {
  local ledger="$isolation_root/COMMANDS.json"
  local transcript="$isolation_root/probe-transcript.md"
  {
    printf '%s\n\n' '# Host-attested command chronology'
    printf '%s\n\n' \
      'Generated mechanically from paired Codex command events in start order.'
    printf "Candidate HEAD: \`%s\`\n\n" "$expected_head"
    printf "Raw transcript SHA-256: \`%s\`\n\n" \
      "$(sha256_file "$evidence_root/codex-transcript.jsonl")"
    printf "Command ledger SHA-256: \`%s\`\n\n" "$(sha256_file "$ledger")"
    printf "Command events: \`%s\`\n\n" "$(/usr/bin/jq 'length' "$ledger")"
    /usr/bin/jq -r '
      to_entries[] |
      "## Event \(.key + 1)\n\n    \(.value | tojson)\n"
    ' "$ledger"
  } > "$transcript"
  /usr/bin/install -m 0600 "$transcript" \
    "$evidence_root/probe-transcript.md"
}

assert_safe_probe_relative_path() {
  local relative="$1"
  local label="$2"
  local relative_lower
  local expected_parent
  local physical_parent
  local relative_parent
  case "$relative" in
    "" | /* | . | .. | ./* | ../* | */./* | */. | */../* | */.. | \
      */ | *//* | \
      *$'\r'* | *$'\n'* | *$'\t'*)
      die "$label is not a canonical relative probe path: $relative"
      ;;
    *[!A-Za-z0-9._/-]*)
      die "$label contains a non-portable path character: $relative"
      ;;
  esac
  relative_lower="$(
    printf '%s' "$relative" | LC_ALL=C /usr/bin/tr '[:upper:]' '[:lower:]'
  )"
  [ "$relative" = "$relative_lower" ] ||
    die "$label must use lowercase to remain unique on case-insensitive filesystems: $relative"
  relative_parent="$(/usr/bin/dirname -- "$relative")"
  if [ "$relative_parent" = . ]; then
    expected_parent="$probe_root"
  else
    expected_parent="$probe_root/$relative_parent"
  fi
  [ -d "$expected_parent" ] || die "$label parent is missing: $relative"
  physical_parent="$(canonical_directory "$expected_parent")"
  [ "$physical_parent" = "$expected_parent" ] ||
    die "$label parent must not traverse a symlink or physical path alias: $relative"
}

assert_valid_opc_archive() {
  local package="$1"
  local format="$2"
  local label="$3"

  [ "$(stat_size "$package")" -le 134217728 ] ||
    die "$label exceeds the 128 MiB compressed package limit"
  if ! /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/python3 -I - "$package" "$format" <<'PY'
import os
import signal
import stat
import sys
import zipfile
import xml.etree.ElementTree as ET

MAX_ARCHIVE_BYTES = 128 * 1024 * 1024
MAX_ENTRY_BYTES = 64 * 1024 * 1024
MAX_EXPANDED_BYTES = 128 * 1024 * 1024
MAX_ENTRIES = 2048
MAX_XML_BYTES = 8 * 1024 * 1024
CHUNK_BYTES = 1024 * 1024

CONTENT_TYPES_NS = (
    "http://schemas.openxmlformats.org/package/2006/content-types"
)
RELATIONSHIPS_NS = (
    "http://schemas.openxmlformats.org/package/2006/relationships"
)
OFFICE_DOCUMENT_REL = (
    "http://schemas.openxmlformats.org/officeDocument/2006/"
    "relationships/officeDocument"
)


class ValidationError(Exception):
    pass


def reject_timeout(_signum, _frame):
    raise ValidationError("archive validation exceeded 30 seconds")


def qname(namespace, local_name):
    return "{%s}%s" % (namespace, local_name)


def parse_xml(payload, part_name):
    if not payload:
        raise ValidationError("empty required OPC part: %s" % part_name)
    upper = payload.upper()
    for token in ("<!DOCTYPE", "<!ENTITY"):
        for encoding in (
            "ascii",
            "utf-16le",
            "utf-16be",
            "utf-32le",
            "utf-32be",
        ):
            if token.encode(encoding) in upper:
                raise ValidationError(
                    "DTD or entity declaration in required OPC XML"
                )
    try:
        return ET.fromstring(payload)
    except (ET.ParseError, ValueError) as error:
        raise ValidationError("malformed required OPC XML: %s" % part_name) from error


def validate_entry_name(name, is_directory, folded_names):
    if (
        not name
        or name.startswith("/")
        or "\\" in name
        or ":" in name
        or "//" in name
        or any(ord(character) < 32 or ord(character) == 127 for character in name)
    ):
        raise ValidationError("unsafe ZIP entry name")
    components = name.split("/")
    if is_directory:
        if components[-1] != "":
            raise ValidationError("ambiguous ZIP directory entry")
        components = components[:-1]
    if not components or any(component in ("", ".", "..") for component in components):
        raise ValidationError("non-canonical ZIP entry name")
    folded = name.casefold()
    if folded in folded_names:
        raise ValidationError("case-colliding ZIP entry name")
    folded_names.add(folded)


def read_archive(package_path, required_parts):
    archive_size = os.lstat(package_path).st_size
    if archive_size > MAX_ARCHIVE_BYTES:
        raise ValidationError("compressed package exceeds 128 MiB")
    payloads = {}
    expanded_bytes = 0
    folded_names = set()
    try:
        with zipfile.ZipFile(package_path, "r") as archive:
            entries = archive.infolist()
            if not 1 <= len(entries) <= MAX_ENTRIES:
                raise ValidationError("ZIP entry count is outside 1..2048")
            for info in entries:
                is_directory = info.is_dir()
                validate_entry_name(info.filename, is_directory, folded_names)
                unix_mode = (info.external_attr >> 16) & 0xFFFF
                entry_kind = stat.S_IFMT(unix_mode)
                if entry_kind not in (0, stat.S_IFREG, stat.S_IFDIR):
                    raise ValidationError("ZIP contains a non-file entry")
                if is_directory:
                    if entry_kind not in (0, stat.S_IFDIR) or info.file_size != 0:
                        raise ValidationError("invalid ZIP directory entry")
                    continue
                if entry_kind == stat.S_IFDIR:
                    raise ValidationError("ambiguous ZIP file entry")
                if info.flag_bits & 1:
                    raise ValidationError("encrypted ZIP entries are not accepted")
                actual_size = 0
                retained = bytearray() if info.filename in required_parts else None
                with archive.open(info, "r") as source:
                    while True:
                        chunk = source.read(CHUNK_BYTES)
                        if not chunk:
                            break
                        actual_size += len(chunk)
                        expanded_bytes += len(chunk)
                        if actual_size > MAX_ENTRY_BYTES:
                            raise ValidationError("ZIP entry expands beyond 64 MiB")
                        if expanded_bytes > MAX_EXPANDED_BYTES:
                            raise ValidationError("ZIP expands beyond 128 MiB")
                        if retained is not None:
                            if actual_size > MAX_XML_BYTES:
                                raise ValidationError(
                                    "required OPC XML part exceeds 8 MiB"
                                )
                            retained.extend(chunk)
                if actual_size != info.file_size:
                    raise ValidationError("ZIP entry size disagrees with its payload")
                if retained is not None:
                    payloads[info.filename] = bytes(retained)
    except (OSError, RuntimeError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
        raise ValidationError("unreadable or corrupt ZIP package") from error
    if expanded_bytes < 1:
        raise ValidationError("ZIP package expands to no file content")
    missing = [part for part in required_parts if part not in payloads]
    if missing:
        raise ValidationError("missing required OPC part: %s" % missing[0])
    return payloads


def validate_opc(package_path, package_format):
    if package_format == "xlsx":
        main_part = "xl/workbook.xml"
        main_content_type = (
            "application/vnd.openxmlformats-officedocument.spreadsheetml."
            "sheet.main+xml"
        )
        main_qname = qname(
            "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
            "workbook",
        )
    elif package_format == "docx":
        main_part = "word/document.xml"
        main_content_type = (
            "application/vnd.openxmlformats-officedocument.wordprocessingml."
            "document.main+xml"
        )
        main_qname = qname(
            "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
            "document",
        )
    else:
        raise ValidationError("unsupported OPC format")

    required_parts = ("[Content_Types].xml", "_rels/.rels", main_part)
    payloads = read_archive(package_path, required_parts)
    types_root = parse_xml(payloads[required_parts[0]], required_parts[0])
    rels_root = parse_xml(payloads[required_parts[1]], required_parts[1])
    main_root = parse_xml(payloads[main_part], main_part)

    types_qname = qname(CONTENT_TYPES_NS, "Types")
    default_qname = qname(CONTENT_TYPES_NS, "Default")
    override_qname = qname(CONTENT_TYPES_NS, "Override")
    if types_root.tag != types_qname:
        raise ValidationError("unexpected OPC content-types root")
    overrides = []
    for child in list(types_root):
        if child.tag not in (default_qname, override_qname) or list(child):
            raise ValidationError("invalid OPC content-types child structure")
        if (
            child.tag == override_qname
            and child.attrib.get("PartName") == "/" + main_part
            and child.attrib.get("ContentType") == main_content_type
        ):
            overrides.append(child)
    if len(overrides) != 1:
        raise ValidationError("expected exactly one main-part content-type override")

    relationships_qname = qname(RELATIONSHIPS_NS, "Relationships")
    relationship_qname = qname(RELATIONSHIPS_NS, "Relationship")
    if rels_root.tag != relationships_qname:
        raise ValidationError("unexpected OPC relationships root")
    relationship_ids = set()
    office_relationships = []
    for child in list(rels_root):
        if child.tag != relationship_qname or list(child):
            raise ValidationError("invalid OPC relationship child structure")
        relationship_id = child.attrib.get("Id", "")
        if not relationship_id or relationship_id in relationship_ids:
            raise ValidationError("missing or duplicate OPC relationship Id")
        relationship_ids.add(relationship_id)
        if child.attrib.get("Type") == OFFICE_DOCUMENT_REL:
            office_relationships.append(child)
    if len(office_relationships) != 1:
        raise ValidationError("expected exactly one officeDocument relationship")
    office_relationship = office_relationships[0]
    target = office_relationship.attrib.get("Target", "")
    if target.startswith("/"):
        target = target[1:]
    if (
        target != main_part
        or office_relationship.attrib.get("TargetMode", "Internal") != "Internal"
    ):
        raise ValidationError("officeDocument relationship targets the wrong part")
    if main_root.tag != main_qname:
        raise ValidationError("unexpected OPC main-part root")


signal.signal(signal.SIGALRM, reject_timeout)
signal.alarm(30)
try:
    validate_opc(sys.argv[1], sys.argv[2])
except (ValidationError, IndexError) as error:
    print("OPC validation failed: %s" % error, file=sys.stderr)
    sys.exit(1)
finally:
    signal.alarm(0)
PY
  then
    die "$label is not a bounded, structurally valid $format OPC package"
  fi
}

assert_workflow_package() {
  local relative="$1"
  local format="$2"
  local label="$3"
  local relative_lower
  assert_safe_probe_relative_path "$relative" "$label"
  relative_lower="$(printf '%s' "$relative" | LC_ALL=C /usr/bin/tr '[:upper:]' '[:lower:]')"
  case "$relative_lower" in
    *."$format") ;;
    *) die "$label does not name a .$format package: $relative" ;;
  esac
  assert_owned_private_file "$probe_root/$relative" "$label"
  [ -s "$probe_root/$relative" ] || die "$label is empty: $relative"
  assert_valid_opc_archive "$probe_root/$relative" "$format" "$label"
}

assert_workflow_output() {
  local relative="$1"
  local suffix="$2"
  local label="$3"
  local relative_lower
  assert_safe_probe_relative_path "$relative" "$label"
  relative_lower="$(printf '%s' "$relative" | LC_ALL=C /usr/bin/tr '[:upper:]' '[:lower:]')"
  case "$relative_lower" in
    *."$suffix") ;;
    *) die "$label does not name a .$suffix file: $relative" ;;
  esac
  assert_owned_private_file "$probe_root/$relative" "$label"
  [ -s "$probe_root/$relative" ] || die "$label is empty: $relative"
}

expected_workflow_schema() {
  local format="$1"
  local verb="$2"
  case "$format/$verb" in
    xlsx/create) printf '%s\n' office.xlsx.create/1 ;;
    xlsx/batch) printf '%s\n' office.xlsx.batch/1 ;;
    docx/batch) printf '%s\n' office.docx.batch/1 ;;
    xlsx/identify | docx/identify) printf '%s\n' office.identify/1 ;;
    xlsx/outline) printf '%s\n' office.xlsx.outline/1 ;;
    docx/outline) printf '%s\n' office.docx.outline/1 ;;
    xlsx/get) printf '%s\n' office.xlsx.element/1 ;;
    docx/get) printf '%s\n' office.docx.element/1 ;;
    xlsx/text) printf '%s\n' office.xlsx.text/1 ;;
    docx/text) printf '%s\n' office.docx.text/1 ;;
    xlsx/query) printf '%s\n' office.xlsx.query/1 ;;
    docx/query) printf '%s\n' office.docx.query/1 ;;
    xlsx/validate | docx/validate) printf '%s\n' office.validate/1 ;;
    xlsx/issues | docx/issues) printf '%s\n' office.issues/1 ;;
    xlsx/preview | docx/preview) printf '%s\n' office.preview/1 ;;
    xlsx/template | docx/template) printf '%s\n' office.template/1 ;;
    xlsx/dump | docx/dump) printf '%s\n' office.dump/1 ;;
    xlsx/replay | docx/replay) printf '%s\n' office.replay/1 ;;
    xlsx/raw) printf '%s\n' office.raw.inventory/1 ;;
    docx/raw) printf '%s\n' office.raw.part/1 ;;
    docx/annotate) printf '%s\n' office.docx.annotation-batch/1 ;;
    *) die "no result schema is registered for workflow $format/$verb" ;;
  esac
}

is_expected_workflow_result() {
  local result_file="$1"
  local expected_schema="$2"
  [ -f "$result_file" ] && [ ! -L "$result_file" ] || return 1
  /usr/bin/jq -e --arg expected_schema "$expected_schema" '
    if $expected_schema == "office.dump/1" then
      .schema == $expected_schema
    else
      .schema == "office.output/1" and
      .success == true and
      .data.schema == $expected_schema
    end
  ' "$result_file" >/dev/null 2>&1
}

validate_workflow_event() {
  local runtime="$1"
  local format="$2"
  local verb="$3"
  local match="$4"
  local event_id
  local command
  local result_relative
  local result_file
  local result_schema
  local result_sha256
  local result_bytes
  local artifact_relative
  local artifact_json
  local produced_relative=""
  local produced_json=null

  event_id="$(/usr/bin/jq -er '.event_id' <<<"$match")"
  command="$(/usr/bin/jq -er '.command' <<<"$match")"
  result_relative="$(/usr/bin/jq -er '.attestation.result.path' <<<"$match")"
  assert_safe_probe_relative_path "$result_relative" \
    "workflow result for $runtime/$format/$verb"
  result_file="$probe_root/$result_relative"
  assert_owned_private_file "$result_file" \
    "workflow result for $runtime/$format/$verb"
  [ -s "$result_file" ] ||
    die "workflow result is empty for $runtime/$format/$verb"
  result_sha256="$(sha256_file "$result_file")"
  result_bytes="$(stat_size "$result_file")"
  /usr/bin/jq -e \
    --arg sha256 "$result_sha256" \
    --argjson bytes "$result_bytes" '
      .attestation.result.sha256 == $sha256 and
      .attestation.result.bytes == $bytes
    ' <<<"$match" >/dev/null ||
    die "workflow result changed after its command completed for $runtime/$format/$verb"
  result_schema="$(expected_workflow_schema "$format" "$verb")"

  /usr/bin/jq -e \
    --arg expected_schema "$result_schema" \
    --arg format "$format" \
    --arg verb "$verb" '
      def result_format:
        .data.format // .data.transaction.format;
      def successful_envelope:
        .schema == "office.output/1" and
        .success == true and
        .data.schema == $expected_schema and
        result_format == $format;
      if $verb == "dump" then
        .schema == $expected_schema and
        .format == $format and
        (.source.file | type) == "string" and
        (.ops | type) == "array" and (.ops | length) > 0
      elif $verb == "create" or $verb == "batch" then
        successful_envelope and
        .data.transaction.committed == true and
        .data.transaction.dry_run == false and
        .data.transaction.changed == true and
        (.data.transaction.output | type) == "string"
      elif $verb == "identify" then
        successful_envelope and (.data.file | type) == "string"
      elif $verb == "outline" then
        successful_envelope and (.data.file | type) == "string"
      elif $verb == "get" then
        successful_envelope and
        (.data.file | type) == "string" and
        (.data.path | type) == "string"
      elif $verb == "text" or $verb == "query" then
        successful_envelope and
        (.data.file | type) == "string" and
        (.data.returned | type) == "number" and .data.returned > 0
      elif $verb == "validate" or $verb == "issues" then
        successful_envelope and
        (.data.file | type) == "string" and
        .data.valid == true and .data.error_count == 0
      elif $verb == "preview" then
        successful_envelope and
        (.data.file | type) == "string" and
        (.data.output | type) == "string" and
        (.data.bytes_written | type) == "number" and .data.bytes_written > 0
      elif $verb == "template" then
        successful_envelope and
        (.data.output | type) == "string" and
        (.data.replaced | type) == "number" and .data.replaced > 0 and
        .data.transaction.committed == true
      elif $verb == "replay" then
        successful_envelope and
        (.data.output | type) == "string" and
        (.data.bytes_written | type) == "number" and .data.bytes_written > 0 and
        (.data.ops_applied | type) == "number" and .data.ops_applied > 0
      elif $verb == "raw" and $format == "xlsx" then
        successful_envelope and
        (.data.part_count | type) == "number" and .data.part_count > 0
      elif $verb == "raw" and $format == "docx" then
        successful_envelope and
        (.data.content | type) == "string" and (.data.content | length) > 0
      elif $verb == "annotate" then
        successful_envelope and
        (.data.output | type) == "string" and
        (.data.ops_applied | type) == "number" and .data.ops_applied > 0 and
        .data.transaction.committed == true
      else
        successful_envelope
      end
    ' "$result_file" >/dev/null ||
    die "workflow result violates the $result_schema contract for $runtime/$format/$verb"

  case "$verb" in
    create | batch)
      artifact_relative="$(/usr/bin/jq -er \
        '.data.transaction.output' "$result_file")"
      ;;
    identify | outline | get | text | query | validate | issues | preview)
      artifact_relative="$(/usr/bin/jq -er '.data.file' "$result_file")"
      ;;
    template | replay | annotate)
      artifact_relative="$(/usr/bin/jq -er '.data.output' "$result_file")"
      ;;
    dump)
      artifact_relative="$(/usr/bin/jq -er '.source.file' "$result_file")"
      ;;
    raw)
      artifact_relative="$(/usr/bin/jq -er '
        if (.format_paths | length) == 1 then .format_paths[0]
        else error("raw attestation must name exactly one package")
        end
      ' <<<"$match")"
      ;;
    *) die "no artifact rule is registered for $format/$verb" ;;
  esac
  /usr/bin/jq -e --arg path "$artifact_relative" \
    '.tokens | index($path) != null' <<<"$match" >/dev/null ||
    die "workflow result artifact is not an exact command argument for $runtime/$format/$verb"
  assert_workflow_package "$artifact_relative" "$format" \
    "workflow artifact for $runtime/$format/$verb"
  artifact_json="$(/usr/bin/jq -cer --arg path "$artifact_relative" '
    [.attestation.files[] | select(.path == $path)] |
    if length == 1 then .[0]
    else error("workflow artifact is absent from the completion attestation")
    end
  ' <<<"$match")" ||
    die "workflow artifact lacks completion-time evidence for $runtime/$format/$verb"
  /usr/bin/jq -e \
    --arg sha256 "$(sha256_file "$probe_root/$artifact_relative")" \
    --argjson bytes "$(stat_size "$probe_root/$artifact_relative")" '
      .sha256 == $sha256 and .bytes == $bytes
    ' <<<"$artifact_json" >/dev/null ||
    die "workflow artifact changed after its command completed for $runtime/$format/$verb"

  if [ "$verb" = "preview" ]; then
    produced_relative="$(/usr/bin/jq -er '.data.output' "$result_file")"
    /usr/bin/jq -e --arg path "$produced_relative" \
      '.tokens | index($path) != null' <<<"$match" >/dev/null ||
      die "preview output is not an exact command argument for $runtime/$format"
    assert_workflow_output "$produced_relative" html \
      "preview output for $runtime/$format"
    produced_json="$(/usr/bin/jq -cer --arg path "$produced_relative" '
      [.attestation.files[] | select(.path == $path)] |
      if length == 1 then .[0]
      else error("preview output is absent from the completion attestation")
      end
    ' <<<"$match")" ||
      die "preview output lacks completion-time evidence for $runtime/$format"
    /usr/bin/jq -e \
      --arg sha256 "$(sha256_file "$probe_root/$produced_relative")" \
      --argjson bytes "$(stat_size "$probe_root/$produced_relative")" '
        .sha256 == $sha256 and .bytes == $bytes
      ' <<<"$produced_json" >/dev/null ||
      die "preview output changed after its command completed for $runtime/$format"
  fi

  /usr/bin/jq -cn \
    --arg event_id "$event_id" \
    --arg command "$command" \
    --arg result_path "$result_relative" \
    --arg result_sha256 "$result_sha256" \
    --argjson result_bytes "$result_bytes" \
    --arg result_schema "$result_schema" \
    --argjson artifact "$artifact_json" \
    --argjson produced "$produced_json" '
      {
        event_id: $event_id,
        command: $command,
        result: {
          path: $result_path,
          sha256: $result_sha256,
          bytes: $result_bytes,
          schema: $result_schema
        },
        artifact: $artifact,
        produced: $produced
      }
    '
}

record_workflow_evidence() {
  local runtime="$1"
  local format="$2"
  local verb="$3"
  local matches
  local validated_entries
  local match
  local help_file

  if [ "$format" = "all" ] && [ "$verb" = "help" ]; then
    help_file="$isolation_root/$runtime-help.json"
    matches="$(/usr/bin/jq -c \
      --arg bare "office-$runtime help all --json" \
      --arg result_schema "$(/usr/bin/jq -er '.data.schema' "$help_file")" \
      --arg result_sha256 "$(sha256_file "$help_file")" \
      --argjson result_bytes "$(stat_size "$help_file")" '
        def exact_command($command):
          . == $command or
          . == ("/bin/sh -c '\''" + $command + "'\''") or
          . == ("/bin/bash -c '\''" + $command + "'\''") or
          . == ("/bin/zsh -c '\''" + $command + "'\''");
        [
          .[] |
          select(
            .status == "completed" and .exit_code == 0 and
            (.command | exact_command($bare))
          ) |
          {
            event_id: .id,
            command,
            result: {
              path: null,
              sha256: $result_sha256,
              bytes: $result_bytes,
              schema: $result_schema
            },
            artifact: null,
            produced: null
          }
        ]
      ' "$isolation_root/COMMANDS.json")"
    /usr/bin/jq -e 'length == 1' <<<"$matches" >/dev/null ||
      die "Codex transcript does not contain one canonical help workflow for $runtime"
  else
    matches="$(/usr/bin/jq -c \
      --arg executable "office-$runtime" \
      --arg format "$format" \
      --arg opposite "$(if [ "$format" = xlsx ]; then printf docx; else printf xlsx; fi)" \
      --arg verb "$verb" '
        def parsed_command($executable; $verb):
          select(.product_argv != null) |
          .product_argv as $tokens |
          select(
            ($tokens | length) >= 3 and
            $tokens[0] == $executable and
            $tokens[1] == $verb and
            $tokens[-1] == "--json"
          ) |
          select(all($tokens[];
            test("^(?:--help|-h|help|--version|-V)(?:=|$)") | not)) |
          ($tokens | map(select(test("\\." + $format + "$"; "i")))) as $format_paths |
          select(($format_paths | length) > 0) |
          select(all($tokens[]; test("\\." + $opposite + "$"; "i") | not)) |
          {
            result_path: .attestation.result.path,
            tokens: $tokens,
            format_paths: $format_paths,
            attestation: .attestation
          };
        [
          .[] |
          select(.status == "completed" and .exit_code == 0) |
          . as $event |
          ($event | parsed_command($executable; $verb)) |
          . + {event_id: $event.id, command: $event.command}
        ]
      ' "$isolation_root/COMMANDS.json")"
    /usr/bin/jq -e 'length == 1' <<<"$matches" >/dev/null ||
      die "Codex transcript must record exactly one canonical attested workflow: $runtime/$format/$verb"
    validated_entries="$isolation_root/workflow-$runtime-$format-$verb.jsonl"
    : > "$validated_entries"
    while IFS= read -r match; do
      validate_workflow_event "$runtime" "$format" "$verb" "$match" \
        >> "$validated_entries"
    done < <(/usr/bin/jq -c '.[]' <<<"$matches")
    matches="$(/usr/bin/jq -s '.' "$validated_entries")"
    /usr/bin/jq -e 'length == 1' <<<"$matches" >/dev/null ||
      die "Codex transcript does not record one validated workflow for $runtime/$format/$verb"
  fi

  /usr/bin/jq -cn \
    --arg runtime "$runtime" \
    --arg format "$format" \
    --arg operation "$verb" \
    --argjson events "$matches" \
    '{
      runtime: $runtime,
      format: $format,
      operation: $operation,
      events: $events
    }' >> "$workflow_entries"
}

extract_isolated_help() {
  local runtime="$1"
  local output="$2"
  local bare="office-$runtime help all --json"
  /usr/bin/jq -er \
    --arg bare "$bare" \
    '
      def exact_command($command):
        . == $command or
        . == ("/bin/sh -c '\''" + $command + "'\''") or
        . == ("/bin/bash -c '\''" + $command + "'\''") or
        . == ("/bin/zsh -c '\''" + $command + "'\''");
      [
        .[] |
        select(
          .type == "item.completed" and
          .item.type == "command_execution" and
          .item.status == "completed" and
          .item.exit_code == 0 and
          (.item.command | exact_command($bare))
        ) |
        .item.aggregated_output
      ] |
      if length == 1 then .[0]
      else error("expected exactly one canonical isolated help command")
      end
    ' "$isolation_root/transcript-array.json" > "$output" ||
    die "Codex transcript lacks one exact isolated help result for $runtime"
  /usr/bin/jq -e '
    (.data | type) == "object" and
    (.data.schema | type) == "string" and
    (.data.schema | length) > 0 and
    (.data.fingerprint | type) == "string" and
    (.data.fingerprint | length) > 0
  ' "$output" >/dev/null ||
    die "installed $runtime help did not produce a capability identity"
}

write_evidence_manifest() {
  local entries="$isolation_root/evidence-entries.jsonl"
  local name
  : > "$entries"
  for name in \
    CANDIDATE.json \
    COMMANDS.json \
    WORKFLOWS.json \
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

for tool in jq shasum awk find sort stat id mktemp install wc tr readlink nc python3 uname ps sleep perl grep; do
  require_command "$tool"
done
netcat_bin="$(command -v nc)"
case "$netcat_bin" in
  /*) ;;
  *) die "netcat must resolve to an absolute path" ;;
esac
platform_name="$(/usr/bin/uname -s)"
codex_version_timeout_seconds="${OFFICE_F1B_CODEX_VERSION_TIMEOUT_SECONDS:-30}"
codex_canary_timeout_seconds="${OFFICE_F1B_CODEX_CANARY_TIMEOUT_SECONDS:-180}"
codex_probe_timeout_seconds="${OFFICE_F1B_CODEX_PROBE_TIMEOUT_SECONDS:-1800}"
validate_timeout_seconds \
  "$codex_version_timeout_seconds" 30 \
  OFFICE_F1B_CODEX_VERSION_TIMEOUT_SECONDS
validate_timeout_seconds \
  "$codex_canary_timeout_seconds" 180 \
  OFFICE_F1B_CODEX_CANARY_TIMEOUT_SECONDS
validate_timeout_seconds \
  "$codex_probe_timeout_seconds" 1800 \
  OFFICE_F1B_CODEX_PROBE_TIMEOUT_SECONDS

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
codex_pid=""
codex_pgid=""
isolated_codex_state_identity=""

cleanup() {
  local status="$1"
  trap - EXIT HUP INT TERM
  if ! terminate_supervised_codex; then
    status=1
  fi
  if ! remove_isolated_auth; then
    status=1
  fi
  if [ -n "${network_listener_pid:-}" ]; then
    /bin/kill "$network_listener_pid" 2>/dev/null || true
    wait "$network_listener_pid" 2>/dev/null || true
  fi
  if [ -n "${ambient_write_path:-}" ] && [ -d "$ambient_write_path" ]; then
    /bin/rmdir "$ambient_write_path" 2>/dev/null || true
  fi
  if [ -n "${isolation_root:-}" ] && [ -d "$isolation_root" ]; then
    chmod u+rwx -- "$isolation_root" 2>/dev/null || true
    chmod -R u+rwx -- "$isolation_root" 2>/dev/null || true
    /bin/rm -rf -- "$isolation_root"
  fi
  exit "$status"
}
trap 'cleanup $?' EXIT
trap 'cleanup 129' HUP
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

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
policy_readonly_root="$isolation_root/policy-readonly"
/bin/mkdir -m 0700 \
  "$isolated_user_home" \
  "$isolated_codex_state" \
  "$isolated_codex_tmp" \
  "$isolated_tmp" \
  "$isolated_launcher_bin" \
  "$candidate_root" \
  "$isolated_codex_bin" \
  "$isolated_codex_resources" \
  "$policy_readonly_root"
isolated_codex_state_identity="$(stat_identity "$isolated_codex_state")"
printf '%s\n' 'non-secret permission sentinel' \
  > "$isolated_codex_state/credential-canary"
chmod 0600 "$isolated_codex_state/credential-canary"
policy_host_marker="$policy_readonly_root/.host-write-preflight"
printf '%s\n' 'host-writable policy sentinel' > "$policy_host_marker"
[ -f "$policy_host_marker" ] ||
  die "policy read-only canary is not writable before sandboxing"
/bin/rm -f -- "$policy_host_marker"
assert_empty_directory "$policy_readonly_root" \
  "policy read-only canary directory before sandboxing"

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

codex_version_stdout="$isolation_root/codex-version.stdout"
codex_version_stderr="$isolation_root/codex-version.stderr"
set -m
run_codex --version >"$codex_version_stdout" 2>"$codex_version_stderr" &
arm_codex_supervision "$!"
set +m
wait_for_supervised_codex \
  "version probe" "$codex_version_timeout_seconds"
codex_version_status="$supervised_codex_status"
if [ "$codex_version_status" -ne 0 ]; then
  /bin/cat "$codex_version_stderr" >&2
  if [ "$codex_version_status" -eq 124 ]; then
    exit 124
  fi
  die "Codex version probe failed with status $codex_version_status"
fi
codex_version="$(/usr/bin/sed -n '1p' "$codex_version_stdout")"
if [[ ! "$codex_version" =~ ^codex-cli[[:space:]]+([0-9]+)\.([0-9]+)\.([0-9]+)([-+][0-9A-Za-z.-]+)?$ ]]; then
  die "could not identify Codex CLI version: $codex_version"
fi
codex_major="${BASH_REMATCH[1]}"
codex_minor="${BASH_REMATCH[2]}"
codex_suffix="${BASH_REMATCH[4]:-}"
case "$codex_suffix" in
  -*) die "Codex CLI prerelease builds are not accepted: $codex_version" ;;
esac
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
  printf '%s = "read"\n' "$(toml_string "$policy_readonly_root")"
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

assert_loopback_listener_reachable ||
  die "loopback denial-canary listener is not live before the permission canary"
set -m
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
  > "$evidence_root/permission-canary.log" 2>&1 &
arm_codex_supervision "$!"
set +m
wait_for_supervised_codex \
  "permission canary" "$codex_canary_timeout_seconds"
canary_status="$supervised_codex_status"
assert_loopback_listener_reachable ||
  die "loopback denial-canary listener is not live after the permission canary"
if [ "$canary_status" -ne 0 ]; then
  echo "error: Codex permission-profile canary log follows" >&2
  /bin/cat "$evidence_root/permission-canary.log" >&2
  if [ "$canary_status" -eq 124 ]; then
    exit 124
  fi
  die "Codex permission-profile canary failed; see $evidence_root/permission-canary.log"
fi
if [ "$(/usr/bin/wc -l < "$evidence_root/permission-canary.log" | /usr/bin/tr -d ' ')" != "1" ] ||
  ! /usr/bin/grep -qx 'FRESH-AGENT PERMISSION CANARY PASS' \
    "$evidence_root/permission-canary.log"; then
  die "Codex permission-profile canary did not report an exact PASS"
fi
[ ! -e "$ambient_write_path" ] && [ ! -L "$ambient_write_path" ] ||
  die "permission canary created its ambient write path"
[ ! -e "$policy_readonly_root/.permission-canary" ] &&
  [ ! -L "$policy_readonly_root/.permission-canary" ] ||
  die "permission canary wrote into its policy read-only directory"
policy_host_marker="$policy_readonly_root/.host-write-postflight"
if ! printf '%s\n' 'host-writable policy sentinel' > "$policy_host_marker"; then
  die "policy read-only canary lost host write access after sandboxing"
fi
/bin/rm -f -- "$policy_host_marker"
assert_empty_directory "$policy_readonly_root" \
  "policy read-only canary directory after sandboxing"
assert_empty_directory "$probe_root" "probe directory after permission canary"
assert_empty_directory "$isolated_tmp" \
  "isolated scratch directory after permission canary"
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
      permission_canary_sha256: $permission_canary_sha256,
      policy_readonly_canary: {
        host_write_preflight: true,
        sandbox_write_denied: true,
        host_write_postflight: true
      }
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

assert_loopback_listener_reachable ||
  die "loopback denial-canary listener is not live before the installed-command probe"
set -m
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
  2> "$evidence_root/codex-stderr.log" &
arm_codex_supervision "$!"
set +m
wait_for_supervised_codex \
  "installed-command probe" "$codex_probe_timeout_seconds"
codex_status="$supervised_codex_status"
assert_loopback_listener_reachable ||
  die "loopback denial-canary listener is not live after the installed-command probe"

printf 'codex_exit_status=%s\n' "$codex_status" \
  > "$evidence_root/codex-exit-status.txt"
remove_isolated_auth ||
  die "could not remove the staged Codex credential after the probe"

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
assert_empty_directory "$isolated_tmp" \
  "isolated scratch directory after Office probe"

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
  (to_entries) as $events |
  ([$events[] | select(.value.type == "thread.started")]) as $thread_started |
  ([$events[] | select(.value.type == "turn.started")]) as $turn_started |
  ([$events[] | select(.value.type == "turn.completed")]) as $turn_completed |
  ([$events[] | select(.value.type == "turn.failed")]) as $turn_failed |
  ([$events[] |
    select(.value.type == "item.started" and
      .value.item.type == "command_execution") |
    {index: .key, item: .value.item}]) as $started |
  ([$events[] |
    select(.value.type == "item.completed" and
      .value.item.type == "command_execution") |
    {index: .key, item: .value.item}]) as $completed |
  ([$events[] | select(.value.item?.type == "command_execution")][0]) as $first_event |
  ($events | length) > 0 and
  ($thread_started | length) == 1 and
  $thread_started[0].key == 0 and
  ($turn_started | length) == 1 and
  ($turn_completed | length) == 1 and
  ($turn_failed | length) == 0 and
  $turn_started[0].key < $turn_completed[0].key and
  $turn_completed[0].key == (($events | length) - 1) and
  ($started | length) > 0 and
  ($started | map(.item.id) | length) ==
    ($started | map(.item.id) | unique | length) and
  ($completed | map(.item.id) | length) ==
    ($completed | map(.item.id) | unique | length) and
  ($started | map(.item | {id, command}) | sort_by(.id)) ==
    ($completed | map(.item | {id, command}) | sort_by(.id)) and
  all($started[];
    . as $start |
    ([$completed[] | select(.item.id == $start.item.id)]) as $terminals |
    ($terminals | length) == 1 and
    $start.index > $turn_started[0].key and
    $terminals[0].index > $start.index and
    $terminals[0].index < $turn_completed[0].key) and
  all($completed[];
    (.item.exit_code | type) == "number" and
    .item.exit_code == (.item.exit_code | floor) and
    .item.exit_code >= 0 and .item.exit_code <= 255 and
    (.item.aggregated_output | type) == "string" and
    ((.item.status == "completed" and .item.exit_code == 0) or
     (.item.status == "failed" and .item.exit_code >= 1))) and
  $first_event.value.type == "item.started" and
  ($first_event.value.item.command | exact_canary_command) and
  ([ $completed[] |
    select(.item.id == $first_event.value.item.id) ][0].item |
    .exit_code == 0 and
    .aggregated_output == "FRESH-AGENT PERMISSION CANARY PASS\n" and
    (.command | exact_canary_command))
' "$isolation_root/transcript-array.json" >/dev/null ||
  die "Codex transcript lifecycle, command pairing, exit domain, or first live canary was invalid"

/usr/bin/jq '
  ([to_entries[] |
    select(.value.type == "item.started" and
      .value.item.type == "command_execution") |
    {index: .key, item: .value.item}]) as $started |
  ([to_entries[] |
    select(.value.type == "item.completed" and
      .value.item.type == "command_execution") |
    {index: .key, item: .value.item}]) as $completed |
  [
    $started[] as $start |
    ($completed | map(select(.item.id == $start.item.id))[0].item) |
    {
      id: $start.item.id,
      command: $start.item.command,
      status,
      exit_code,
      aggregated_output
    }
  ]
' "$isolation_root/transcript-array.json" > "$isolation_root/raw-commands.json"
if ! /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$candidate_root/control/command-policy.py" \
  "$isolation_root/raw-commands.json" "$isolation_root/COMMANDS.json"; then
  die "Codex transcript contains a command outside the simple-command acceptance policy"
fi
/usr/bin/install -m 0600 "$isolation_root/COMMANDS.json" \
  "$evidence_root/COMMANDS.json"
write_host_command_transcript

extract_isolated_help native "$isolation_root/native-help.json"
extract_isolated_help wasm "$isolation_root/wasm-help.json"
/usr/bin/jq -S -c . "$isolation_root/native-help.json" \
  > "$isolation_root/native-help.canonical.json"
/usr/bin/jq -S -c . "$isolation_root/wasm-help.json" \
  > "$isolation_root/wasm-help.canonical.json"
/usr/bin/cmp \
  "$isolation_root/native-help.canonical.json" \
  "$isolation_root/wasm-help.canonical.json" ||
  die "installed native and Wasm capability help differ"
observed_capability_schema="$(
  /usr/bin/jq -er '.data.schema' "$isolation_root/native-help.json"
)"
observed_capability_fingerprint="$(
  /usr/bin/jq -er '.data.fingerprint' "$isolation_root/native-help.json"
)"

workflow_entries="$isolation_root/workflow-entries.jsonl"
: > "$workflow_entries"
for runtime in native wasm; do
  record_workflow_evidence "$runtime" all help
  for verb in create batch identify outline get text query validate issues preview template dump replay raw; do
    record_workflow_evidence "$runtime" xlsx "$verb"
  done
  for verb in batch identify outline get text query validate issues preview template dump replay raw annotate; do
    record_workflow_evidence "$runtime" docx "$verb"
  done
done
/usr/bin/jq -s \
  --arg schema "office.fresh-agent.workflows/3" \
  '{
    schema: $schema,
    required_count: length,
    workflows: .
  }' "$workflow_entries" > "$isolation_root/WORKFLOWS.json"
/usr/bin/jq -e '
  keys == ["required_count", "schema", "workflows"] and
  .schema == "office.fresh-agent.workflows/3" and
  .required_count == 58 and
  (.workflows | length) == 58 and
  (.workflows | unique_by([.runtime, .format, .operation]) | length) == 58 and
  ([.workflows[].events[].event_id] as $ids |
    ($ids | length) == ($ids | unique | length)) and
  ([.workflows[].events[].result.path | select(. != null)] as $paths |
    ($paths | length) == ($paths | unique | length)) and
  (.workflows | all(
    keys == ["events", "format", "operation", "runtime"] and
    (.runtime == "native" or .runtime == "wasm") and
    (.format == "all" or .format == "xlsx" or .format == "docx") and
    (.events | length) == 1 and
    (.events | all(
      keys == ["artifact", "command", "event_id", "produced", "result"] and
      (.command | type) == "string" and
      (.event_id | type) == "string" and (.event_id | length) > 0 and
      (.result | keys) == ["bytes", "path", "schema", "sha256"] and
      (.result.path == null or (.result.path | type) == "string") and
      (.result.bytes | type) == "number" and
      .result.bytes == (.result.bytes | floor) and .result.bytes > 0 and
      (.result.schema | type) == "string" and
      (.result.sha256 | test("^[0-9a-f]{64}$")) and
      (.artifact == null or (
        (.artifact | keys) == ["bytes", "path", "sha256"] and
        (.artifact.path | type) == "string" and
        (.artifact.bytes | type) == "number" and
        .artifact.bytes == (.artifact.bytes | floor) and .artifact.bytes > 0 and
        (.artifact.sha256 | test("^[0-9a-f]{64}$"))
      )) and
      (.produced == null or (
        (.produced | keys) == ["bytes", "path", "sha256"] and
        (.produced.path | type) == "string" and
        (.produced.bytes | type) == "number" and
        .produced.bytes == (.produced.bytes | floor) and .produced.bytes > 0 and
        (.produced.sha256 | test("^[0-9a-f]{64}$"))
      ))
    ))
  ))
' "$isolation_root/WORKFLOWS.json" >/dev/null ||
  die "host-generated workflow evidence failed strict validation"
/usr/bin/install -m 0600 "$isolation_root/WORKFLOWS.json" \
  "$evidence_root/WORKFLOWS.json"

/usr/bin/jq -e '
  keys == ["gaps", "result_path", "targets", "verdict"] and
  (.verdict == "BASELINE PASS" or .verdict == "BASELINE FAIL") and
  .result_path == "probe-result.md" and
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
assert_owned_private_file "$result_file" "probe result"
[ -s "$result_file" ] || die "probe result is empty"
IFS= read -r result_header < "$result_file" || true
[ "$result_header" = "Verdict: $verdict" ] ||
  die "probe result does not begin with the exact structured verdict"
summary_line=2
for runtime in native wasm; do
  case "$runtime" in
    native) runtime_label=Native ;;
    wasm) runtime_label=Wasm ;;
  esac
  for format in xlsx docx; do
    case "$format" in
      xlsx) format_label=XLSX ;;
      docx) format_label=DOCX ;;
    esac
    outcome="$(/usr/bin/jq -er \
      --arg runtime "$runtime" \
      --arg format "$format" \
      '.targets[$runtime][$format]' \
      "$evidence_root/final-message.json")"
    [ "$(/usr/bin/sed -n "${summary_line}p" "$result_file")" = \
      "$runtime_label $format_label: $outcome" ] ||
      die "probe result omits structured outcome: $runtime_label $format_label"
    summary_line=$((summary_line + 1))
  done
done
[ "$(/usr/bin/sed -n '6p' "$result_file")" = \
  "Capability schema: $observed_capability_schema" ] ||
  die "probe result omits the installed capability schema"
[ "$(/usr/bin/sed -n '7p' "$result_file")" = \
  "Capability fingerprint: $observed_capability_fingerprint" ] ||
  die "probe result omits the installed capability fingerprint"
if [ "$verdict" = "BASELINE PASS" ]; then
  [ "$(/usr/bin/sed -n '8p' "$result_file")" = 'Discoverability: PASS' ] ||
    die "passing probe result does not attest discoverability"
  [ "$(/usr/bin/sed -n '9p' "$result_file")" = 'Native/Wasm comparison: PASS' ] ||
    die "passing probe result does not attest native/Wasm parity"
else
  /usr/bin/sed -n '8p' "$result_file" |
    /usr/bin/grep -Eq '^Discoverability: (PASS|FAIL)$' ||
    die "failing probe result omits discoverability outcome"
  /usr/bin/sed -n '9p' "$result_file" |
    /usr/bin/grep -Eq '^Native/Wasm comparison: (PASS|FAIL)$' ||
    die "failing probe result omits native/Wasm comparison"
fi

/usr/bin/install -m 0600 "$result_file" "$evidence_root/probe-result.md"

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
  --arg transcript_sha256 "$(sha256_file "$evidence_root/probe-transcript.md")" \
  --arg raw_transcript_sha256 "$(sha256_file "$evidence_root/codex-transcript.jsonl")" \
  --arg stderr_sha256 "$(sha256_file "$evidence_root/codex-stderr.log")" \
  --arg commands_sha256 "$(sha256_file "$evidence_root/COMMANDS.json")" \
  --arg workflows_sha256 "$(sha256_file "$evidence_root/WORKFLOWS.json")" \
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
      workflows_sha256: $workflows_sha256,
      final_message_sha256: $final_message_sha256
    }
  }' > "$isolation_root/RUN.json"
/usr/bin/install -m 0600 "$isolation_root/RUN.json" "$evidence_root/RUN.json"
write_evidence_manifest

printf 'probe_dir=%s\n' "$probe_root"
printf 'evidence_dir=%s\n' "$evidence_root"
printf 'verdict=%s\n' "$verdict"

[ "$verdict" = "BASELINE PASS" ] || exit 3

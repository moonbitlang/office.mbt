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

validate_integer_range() {
  local value="$1"
  local minimum="$2"
  local maximum="$3"
  local label="$4"
  case "$value" in
    "" | *[!0-9]*) die "$label must be an integer" ;;
  esac
  if (( value < minimum || value > maximum )); then
    die "$label must be between $minimum and $maximum"
  fi
}

require_postprocess_budget() {
  local label="$1"
  local deadline="${postprocess_deadline:-0}"
  if (( deadline > 0 && SECONDS >= deadline )); then
    die "post-processing exceeded its ${postprocess_timeout_seconds}s global deadline before $label"
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

canonical_unopened_leaf() {
  local input="$1"
  local label="$2"
  local name
  local parent
  local path
  case "$input" in
    /*) ;;
    *) die "$label path must be absolute: $input" ;;
  esac
  reject_path_syntax "$input" "$label"
  name="$(/usr/bin/basename -- "$input")"
  case "$name" in
    "" | "." | "..") die "invalid $label path: $input" ;;
  esac
  parent="$(canonical_directory "$(/usr/bin/dirname -- "$input")")"
  if [ "$parent" = "/" ]; then
    path="/$name"
  else
    path="$parent/$name"
  fi
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
        "build_host_discovery_policy_sha256",
        "build_host_discovery_sha256",
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
      (.build.build_host_discovery_policy_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.build_host_discovery_sha256 | test("^[0-9a-f]{64}$")) and
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
        "control/argument-policy.py",
        "control/auth-guard.py",
        "control/command-policy.py",
        "control/opc-policy.py",
        "control/transcript-policy.py",
        "control/scenario-policy.py",
        "control/evidence-policy.py",
        "control/private.json",
        "control/inventory.sh",
        "control/build-lock.json",
        "control/toolchain.manifest",
        "control/dependencies.manifest",
        "control/build-host.json",
        "control/build-host.manifest",
        "control/build-host-discovery.py",
        "control/build-host-discovery.json"
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
control/argument-policy.py|0400
control/auth-guard.py|0400
control/command-policy.py|0400
control/opc-policy.py|0400
control/transcript-policy.py|0400
control/scenario-policy.py|0400
control/evidence-policy.py|0400
control/private.json|0400
control/inventory.sh|0500
control/build-lock.json|0400
control/toolchain.manifest|0400
control/dependencies.manifest|0400
control/build-host.json|0400
control/build-host.manifest|0400
control/build-host-discovery.py|0400
control/build-host-discovery.json|0400
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
build_host_discovery_policy_sha256|control/build-host-discovery.py
build_host_discovery_sha256|control/build-host-discovery.json
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
    )" \
    --arg discovery_sha256 "$(
      /usr/bin/jq -er '.build.build_host_discovery_sha256' "$manifest"
    )" \
    --slurpfile discovery "$root/control/build-host-discovery.json" '
      ($discovery[0]) as $d |
      keys == ["archiver", "assembler", "compiler", "discovery",
        "environment", "host", "inventory", "linker", "native_plan",
        "platform", "schema", "sdk"] and
      .schema == "office.fresh-agent.build-host/2" and
      .platform == $platform and
      .discovery == {
        schema: "office.fresh-agent.build-host-discovery/1",
        sha256: $discovery_sha256
      } and
      ($d | keys) == ["compiler_queries", "environment", "inventory_paths",
        "loader", "platform", "schema", "sdk", "tools"] and
      $d.schema == .discovery.schema and $d.platform == $platform and
      $d.environment == {
        lang: "C",
        lc_all: "C",
        path: "/usr/bin:/bin:/usr/sbin:/sbin",
        sdkroot: .environment.sdkroot
      } and
      ($d.tools | keys) == ["archiver", "assembler", "compiler", "linker"] and
      ($d.tools | all(
        (keys == ["bytes", "kind", "mode", "resolved_path", "selected_kind",
          "selected_path", "sha256", "version"]) and
        .kind == "file" and
        (.selected_kind == "file" or .selected_kind == "symlink") and
        (.selected_path | startswith("/")) and
        (.resolved_path | startswith("/")) and
        (.sha256 | test("^[0-9a-f]{64}$")) and
        (.bytes | type) == "number" and .bytes > 0 and
        (.version | type) == "array" and (.version | length) > 0
      )) and
      ($d.compiler_queries | keys) == ["reported_sysroot",
        "resource_directory", "runtime_files", "search_directories",
        "target"] and
      ($d.compiler_queries.runtime_files | type) == "array" and
      ($d.compiler_queries.runtime_files | length) > 0 and
      ($d.compiler_queries.search_directories | type) == "array" and
      ($d.inventory_paths | type) == "array" and
      ($d.inventory_paths | length) > 0 and
      ($d.inventory_paths | sort) == $d.inventory_paths and
      ($d.inventory_paths | unique | length) == ($d.inventory_paths | length) and
      (if $platform == "darwin-arm64" then
        $d.loader.strategy == "mach-o-and-dyld-images" and
        ($d.loader.declared_dependencies | length) > 0 and
        ($d.loader.loaded_images | length) > 0
      else
        $d.loader.strategy == "ldd" and
        ($d.loader.dependencies | length) > 0
      end) and
      (.environment | keys) == ["moon_ar", "moon_cc", "sdkroot"] and
      .environment.moon_cc == $d.tools.compiler.selected_path and
      .environment.moon_ar == $d.tools.archiver.selected_path and
      (.environment.sdkroot == null or
        (.environment.sdkroot | startswith("/"))) and
      (.compiler | keys) == ["resolved_path", "resource_dir", "selected_path",
        "sha256", "target", "version"] and
      .compiler.selected_path == .environment.moon_cc and
      .compiler.resolved_path == $d.tools.compiler.resolved_path and
      .compiler.sha256 == $d.tools.compiler.sha256 and
      .compiler.version == ($d.tools.compiler.version | join("\n")) and
      .compiler.target == $d.compiler_queries.target and
      .compiler.resource_dir == {
        selected_path: $d.compiler_queries.resource_directory.selected_path,
        resolved_path: $d.compiler_queries.resource_directory.resolved_path
      } and
      (.archiver | keys) == ["resolved_path", "selected_path", "sha256"] and
      .archiver.selected_path == .environment.moon_ar and
      .archiver.resolved_path == $d.tools.archiver.resolved_path and
      .archiver.sha256 == $d.tools.archiver.sha256 and
      (.linker | keys) == ["resolved_path", "selected_path", "sha256", "version"] and
      .linker.selected_path == $d.tools.linker.selected_path and
      .linker.resolved_path == $d.tools.linker.resolved_path and
      .linker.sha256 == $d.tools.linker.sha256 and
      .linker.version == ($d.tools.linker.version | join("\n")) and
      (.assembler | keys) == ["resolved_path", "selected_path", "sha256"] and
      .assembler.selected_path == $d.tools.assembler.selected_path and
      .assembler.resolved_path == $d.tools.assembler.resolved_path and
      .assembler.sha256 == $d.tools.assembler.sha256 and
      (.host | keys) == ["identity_path", "identity_sha256", "kernel"] and
      (.host.identity_path | startswith("/")) and
      (.host.identity_sha256 | test("^[0-9a-f]{64}$")) and
      (.host.kernel | type) == "string" and (.host.kernel | length) > 0 and
      (.sdk | keys) == ["kind", "resolved_path", "selected_path", "version"] and
      .sdk.selected_path == $d.sdk.selected_path and
      .sdk.resolved_path == $d.sdk.resolved_path and
      (.sdk.version | type) == "string" and (.sdk.version | length) > 0 and
      (if $platform == "darwin-arm64" then
        .sdk.kind == "macos-sdk" and
        .environment.sdkroot == .sdk.selected_path
      else
        .sdk.kind == "linux-sysroot" and .environment.sdkroot == null and
        .sdk.selected_path == "/" and .sdk.resolved_path == "/"
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
      control/build-host-discovery.py \
      control/build-host-discovery.json \
      control/final.schema.json \
      control/attest.py \
      control/argument-policy.py \
      control/auth-guard.py \
      control/command-policy.py \
      control/opc-policy.py \
      control/transcript-policy.py \
      control/scenario-policy.py \
      control/evidence-policy.py \
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

run_codex() (
  local current_processes
  local hard_limit
  local observed_limit
  local target_limit
  exec 7>&- 8>&-
  exec 9< "$job_sentinel" ||
    die "could not open the Codex job sentinel"
  ulimit -c 0
  hard_limit="$(ulimit -H -f)"
  target_limit=131072
  if [ "$hard_limit" != unlimited ] && (( hard_limit < target_limit )); then
    target_limit="$hard_limit"
  fi
  ulimit -S -f "$target_limit"
  if [ "$hard_limit" = unlimited ] || (( hard_limit > target_limit )); then
    ulimit -H -f "$target_limit"
  fi
  observed_limit="$(ulimit -S -f)"
  if [ "$observed_limit" = unlimited ]; then
    die "could not apply the 128 MiB Codex file-size limit"
  fi
  if (( observed_limit > 131072 )); then
    die "could not apply the 128 MiB Codex file-size limit"
  fi

  hard_limit="$(ulimit -H -n)"
  target_limit=256
  if [ "$hard_limit" != unlimited ] && (( hard_limit < target_limit )); then
    target_limit="$hard_limit"
  fi
  ulimit -S -n "$target_limit"
  if [ "$hard_limit" = unlimited ] || (( hard_limit > target_limit )); then
    ulimit -H -n "$target_limit"
  fi
  observed_limit="$(ulimit -S -n)"
  if [ "$observed_limit" = unlimited ]; then
    die "could not apply the Codex descriptor limit"
  fi
  (( observed_limit <= 256 )) ||
    die "could not apply the Codex descriptor limit"

  hard_limit="$(ulimit -H -t)"
  target_limit="$probe_max_cpu_seconds"
  if [ "$hard_limit" != unlimited ] && (( hard_limit < target_limit )); then
    target_limit="$hard_limit"
  fi
  ulimit -S -t "$target_limit"
  if [ "$hard_limit" = unlimited ] || (( hard_limit > target_limit )); then
    ulimit -H -t "$target_limit"
  fi
  observed_limit="$(ulimit -S -t)"
  if [ "$observed_limit" = unlimited ] ||
    (( observed_limit > probe_max_cpu_seconds )); then
    die "could not apply the Codex CPU-time limit"
  fi

  current_processes="$(
    /bin/ps -axo uid= 2>/dev/null |
      /usr/bin/awk -v expected="$(/usr/bin/id -u)" '$1 == expected { count++ } END { print count + 0 }'
  )"
  case "$current_processes" in
    '' | *[!0-9]*) die "could not count current user processes" ;;
  esac
  hard_limit="$(ulimit -H -u)"
  target_limit=$((current_processes + probe_max_processes))
  if [ "$hard_limit" != unlimited ] && (( hard_limit < target_limit )); then
    target_limit="$hard_limit"
  fi
  (( target_limit > current_processes )) ||
    die "the host process limit leaves no bounded Codex process budget"
  ulimit -S -u "$target_limit"
  if [ "$hard_limit" = unlimited ] || (( hard_limit > target_limit )); then
    ulimit -H -u "$target_limit"
  fi
  observed_limit="$(ulimit -S -u)"
  if [ "$observed_limit" = unlimited ] ||
    (( observed_limit > current_processes + probe_max_processes )); then
    die "could not apply the Codex user-process limit"
  fi

  if [ "$platform_name" = "Linux" ]; then
    hard_limit="$(ulimit -H -v)"
    target_limit=4194304
    if [ "$hard_limit" != unlimited ] && (( hard_limit < target_limit )); then
      target_limit="$hard_limit"
    fi
    ulimit -S -v "$target_limit"
    if [ "$hard_limit" = unlimited ] || (( hard_limit > target_limit )); then
      ulimit -H -v "$target_limit"
    fi
    observed_limit="$(ulimit -S -v)"
    if [ "$observed_limit" = unlimited ] ||
      (( observed_limit > 4194304 )); then
      die "could not apply the Codex virtual-memory limit"
    fi
  fi
  /usr/bin/env -i \
    HOME="$isolated_user_home" \
    CODEX_HOME="$isolated_codex_state" \
    ZDOTDIR="$isolated_user_home" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    TMPDIR="$isolated_codex_tmp" \
    LANG=C \
    LC_ALL=C \
    "${codex_argv[@]}" "$@"
)

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

close_auth_guard_fds() {
  exec 7>&- || true
  exec 8>&- || true
}

remove_auth_guard_root() {
  local observed_identity
  [ -n "${auth_guard_root:-}" ] || return 0
  if [ ! -e "$auth_guard_root" ] && [ ! -L "$auth_guard_root" ]; then
    return 0
  fi
  observed_identity="$(stat_identity "$auth_guard_root" 2>/dev/null || true)"
  if [ ! -d "$auth_guard_root" ] || [ -L "$auth_guard_root" ] ||
    [ -z "${auth_guard_root_identity:-}" ] ||
    [ "$observed_identity" != "$auth_guard_root_identity" ]; then
    return 1
  fi
  chmod u+rwx -- "$auth_guard_root" 2>/dev/null || true
  /bin/rm -f -- \
    "$auth_guard_request" "$auth_guard_response" "$auth_guard_log" \
    2>/dev/null || true
  /bin/rmdir "$auth_guard_root" 2>/dev/null || true
  [ ! -e "$auth_guard_root" ] && [ ! -L "$auth_guard_root" ]
}

stop_auth_guard() {
  local attempt
  local pid="${auth_guard_pid:-}"
  local survived=0
  close_auth_guard_fds
  if [ -n "$pid" ] && process_is_live "$pid"; then
    /bin/kill -TERM "$pid" 2>/dev/null || true
    for attempt in {1..10}; do
      process_is_live "$pid" || break
      /bin/sleep 0.1
    done
    if process_is_live "$pid"; then
      /bin/kill -KILL "$pid" 2>/dev/null || true
      for attempt in {1..10}; do
        process_is_live "$pid" || break
        /bin/sleep 0.1
      done
    fi
  fi
  if [ -n "$pid" ]; then
    process_is_live "$pid" && survived=1
    wait "$pid" 2>/dev/null || true
  fi
  auth_guard_pid=""
  remove_auth_guard_root || survived=1
  [ "$survived" -eq 0 ]
}

read_auth_guard_response() {
  local label="$1"
  if ! IFS= read -r -t 10 -u 8 auth_guard_response_json; then
    if [ -s "$auth_guard_log" ]; then
      /bin/cat "$auth_guard_log" >&2
    fi
    die "Codex credential guard timed out while waiting for $label"
  fi
  [ "${#auth_guard_response_json}" -le 4096 ] ||
    die "Codex credential guard returned an oversized response"
}

start_auth_guard() {
  local policy="$install_root/control/auth-guard.py"
  auth_guard_root="$isolation_root/auth-guard"
  auth_guard_request="$auth_guard_root/request.fifo"
  auth_guard_response="$auth_guard_root/response.fifo"
  auth_guard_log="$auth_guard_root/guard.log"
  /bin/mkdir -m 0700 "$auth_guard_root"
  auth_guard_root_identity="$(stat_identity "$auth_guard_root")"
  /usr/bin/mkfifo "$auth_guard_request" "$auth_guard_response"
  chmod 0600 "$auth_guard_request" "$auth_guard_response"
  : > "$auth_guard_log"
  chmod 0600 "$auth_guard_log"
  exec 7<> "$auth_guard_request"
  exec 8<> "$auth_guard_response"
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/python3 -I "$policy" serve \
      "$auth_json" "$auth_guard_request" "$auth_guard_response" \
      > /dev/null 2> "$auth_guard_log" 7>&- 8>&- &
  auth_guard_pid="$!"
  read_auth_guard_response "source validation"
  if ! /usr/bin/jq -e '
    keys == ["schema", "source", "status"] and
    .schema == "office.fresh-agent.auth-guard/1" and
    .status == "ready" and
    (.source | keys) == ["bytes", "sha256"] and
    (.source.bytes | type == "number" and . == floor and . > 0 and . <= 1048576) and
    (.source.sha256 | test("^[0-9a-f]{64}$"))
  ' <<< "$auth_guard_response_json" >/dev/null; then
    if [ -s "$auth_guard_log" ]; then
      /bin/cat "$auth_guard_log" >&2
    fi
    die "Codex credential guard rejected the source credential"
  fi
  auth_source_bytes="$(
    /usr/bin/jq -er '.source.bytes' <<< "$auth_guard_response_json"
  )"
  auth_source_sha256="$(
    /usr/bin/jq -er '.source.sha256' <<< "$auth_guard_response_json"
  )"
}

stage_isolated_auth() {
  local destination="$isolated_codex_state/auth.json"
  local guard_status
  /usr/bin/jq -nc --arg destination "$destination" \
    '{destination: $destination, op: "stage"}' >&7
  read_auth_guard_response "credential staging"
  if ! /usr/bin/jq -e \
    --arg sha256 "$auth_source_sha256" \
    --argjson bytes "$auth_source_bytes" '
      keys == ["destination", "schema", "status"] and
      .schema == "office.fresh-agent.auth-guard/1" and
      .status == "staged" and
      .destination == {bytes: $bytes, sha256: $sha256}
    ' <<< "$auth_guard_response_json" >/dev/null; then
    if [ -s "$auth_guard_log" ]; then
      /bin/cat "$auth_guard_log" >&2
    fi
    die "Codex credential guard failed to stage the source credential"
  fi
  set +e
  wait "$auth_guard_pid"
  guard_status="$?"
  set -e
  auth_guard_pid=""
  [ "$guard_status" -eq 0 ] ||
    die "Codex credential guard exited with status $guard_status"
  close_auth_guard_fds
  assert_owned_file "$destination" "0600" "1" "staged Codex credential"
  [ "$(stat_size "$destination")" = "$auth_source_bytes" ] ||
    die "staged Codex credential size mismatch"
  [ "$(sha256_file "$destination")" = "$auth_source_sha256" ] ||
    die "staged Codex credential hash mismatch"
  remove_auth_guard_root ||
    die "could not remove the Codex credential guard endpoints"
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

job_member_pids() {
  local pgid="${codex_pgid:-}"
  {
    if [ -n "$pgid" ]; then
      /bin/ps -axo pid=,pgid=,stat= 2>/dev/null |
        /usr/bin/awk -v expected="$pgid" '
          $2 == expected && $3 !~ /^Z/ { print $1 }
        '
    fi
    if [ -n "${job_sentinel:-}" ] &&
      { [ -e "$job_sentinel" ] || [ -L "$job_sentinel" ]; }; then
      {
        "$lsof_bin" -F p -- "$job_sentinel" 2>/dev/null || true
      } | /usr/bin/awk '/^p[0-9]+$/ { print substr($0, 2) }'
    fi
  } | /usr/bin/awk -v runner="$$" '
    /^[0-9]+$/ && $1 > 1 && $1 != runner && !seen[$1]++ { print $1 }
  '
}

pid_list_has_live_processes() {
  local pid
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    if process_is_live "$pid"; then
      return 0
    fi
  done
  return 1
}

signal_pid_list() {
  local pid
  local signal="$1"
  local pids="$2"
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    /bin/kill -"$signal" "$pid" 2>/dev/null || true
  done <<< "$pids"
}

terminate_supervised_codex() {
  local attempt
  local final_pids
  local initial_pids
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
  initial_pids="$(job_member_pids)"
  if [ -n "$pgid" ] && [ -n "$pid" ] && [ "$pgid" = "$pid" ]; then
    /bin/kill -"$first_signal" "-$pgid" 2>/dev/null || true
  fi
  signal_pid_list "$first_signal" "$initial_pids"
  for attempt in {1..5}; do
    pid_list_has_live_processes <<< "$initial_pids" || break
    /bin/sleep 0.1
  done
  final_pids="$(job_member_pids)"
  if [ "$first_signal" = TERM ] &&
    { [ -n "$final_pids" ] || pid_list_has_live_processes <<< "$initial_pids"; }; then
    if [ -n "$pgid" ] && [ -n "$pid" ] && [ "$pgid" = "$pid" ]; then
      /bin/kill -KILL "-$pgid" 2>/dev/null || true
    fi
    signal_pid_list KILL "$initial_pids"
    signal_pid_list KILL "$final_pids"
    for attempt in {1..5}; do
      if ! pid_list_has_live_processes <<< "$initial_pids" &&
        ! pid_list_has_live_processes <<< "$final_pids"; then
        break
      fi
      /bin/sleep 0.1
    done
  fi
  final_pids="$(job_member_pids)"
  if [ -n "$final_pids" ] ||
    pid_list_has_live_processes <<< "$initial_pids"; then
    survived=1
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
  local stderr_log="$3"
  local deadline=$((SECONDS + timeout_seconds))
  local timed_out=0
  local resource_exceeded=0
  local leader_status

  while supervised_codex_leader_is_running; do
    if [ -n "${probe_resource_violation_file:-}" ] &&
      [ -s "$probe_resource_violation_file" ]; then
      resource_exceeded=1
      break
    fi
    if (( SECONDS >= deadline )); then
      timed_out=1
      break
    fi
    /bin/sleep 0.1
  done

  if [ -n "${probe_resource_violation_file:-}" ] &&
    [ -s "$probe_resource_violation_file" ]; then
    resource_exceeded=1
  fi

  if [ "$timed_out" -eq 0 ] && [ "$resource_exceeded" -eq 0 ]; then
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
  elif [ "$resource_exceeded" -eq 1 ]; then
    echo "error: Codex probe exceeded its bounded resource policy" >&2
    /bin/cat "$probe_resource_violation_file" >&2
    supervised_codex_status=125
  elif [ "$leader_status" -ne 0 ] &&
    /usr/bin/grep -Fq 'fork: Resource temporarily unavailable' \
      "$stderr_log"; then
    # On platforms that enforce RLIMIT_NPROC before the sampling monitor can
    # observe an over-limit child, Bash reports the same bounded-process
    # refusal directly. Normalize that kernel-enforced outcome to the runner's
    # resource-policy status.
    echo "error: Codex probe exceeded its bounded resource policy" >&2
    printf 'Codex job reached the OS process ceiling (limit %s processes)\n' \
      "$probe_max_processes" >&2
    supervised_codex_status=125
  else
    supervised_codex_status="$leader_status"
  fi
}

start_probe_resource_monitor() {
  local monitored_pgid="$1"
  case "$monitored_pgid" in
    '' | *[!0-9]*) die "invalid Codex process group for resource monitor" ;;
  esac
  probe_resource_violation_file="$isolation_root/resource-violation.log"
  : > "$probe_resource_violation_file"
  (
    local inspection_failures=0
    trap 'exit 0' HUP INT TERM
    while :; do
      local cpu_seconds
      local entry_count
      local process_count
      local process_snapshot
      local rss_kib
      local usage_kib
      if ! usage_kib="$(
        /usr/bin/du -sk \
          "$probe_root" "$evidence_root" "$isolated_user_home" \
          "$isolated_tmp" "$isolated_codex_state" 2>/dev/null |
          /usr/bin/awk '{ total += $1 } END { print total + 0 }'
      )"; then
        inspection_failures=$((inspection_failures + 1))
        if (( inspection_failures >= 10 )); then
          printf '%s\n' 'probe storage remained uninspectable across 10 samples' \
            > "$probe_resource_violation_file"
          exit 0
        fi
        /bin/sleep 0.05
        continue
      fi
      if ! entry_count="$(
        /usr/bin/find \
          "$probe_root" "$evidence_root" "$isolated_user_home" \
          "$isolated_tmp" "$isolated_codex_state" \
          -mindepth 1 -print 2>/dev/null |
          /usr/bin/wc -l |
          /usr/bin/tr -d ' '
      )"; then
        inspection_failures=$((inspection_failures + 1))
        if (( inspection_failures >= 10 )); then
          printf '%s\n' 'probe entry count remained uninspectable across 10 samples' \
            > "$probe_resource_violation_file"
          exit 0
        fi
        /bin/sleep 0.05
        continue
      fi
      if ! process_snapshot="$(
        /bin/ps -axo pgid=,rss=,time=,stat= 2>/dev/null |
          /usr/bin/awk -v expected="$monitored_pgid" '
            function seconds(raw, count, fields, whole) {
              count = split(raw, fields, ":")
              sub(/[.][0-9]+$/, "", fields[count])
              if (count == 3) {
                return (fields[1] * 3600) + (fields[2] * 60) + fields[3]
              }
              if (count == 2) {
                return (fields[1] * 60) + fields[2]
              }
              return fields[1] + 0
            }
            $1 == expected && $4 !~ /^Z/ {
              processes++
              rss += $2
              cpu += seconds($3)
            }
            END { print processes + 0, rss + 0, cpu + 0 }
          '
      )"; then
        inspection_failures=$((inspection_failures + 1))
        if (( inspection_failures >= 10 )); then
          printf '%s\n' 'Codex process resources remained uninspectable across 10 samples' \
            > "$probe_resource_violation_file"
          exit 0
        fi
        /bin/sleep 0.05
        continue
      fi
      read -r process_count rss_kib cpu_seconds <<< "$process_snapshot"
      case "$process_count:$rss_kib:$cpu_seconds" in
        *[!0-9:]*)
          printf '%s\n' 'Codex process resource snapshot was malformed' \
            > "$probe_resource_violation_file"
          exit 0
          ;;
      esac
      inspection_failures=0
      if (( usage_kib > probe_max_kib )); then
        printf 'probe storage reached %s KiB (limit %s KiB)\n' \
          "$usage_kib" "$probe_max_kib" > "$probe_resource_violation_file"
        exit 0
      fi
      if (( entry_count > probe_max_entries )); then
        printf 'probe storage reached %s entries (limit %s)\n' \
          "$entry_count" "$probe_max_entries" > "$probe_resource_violation_file"
        exit 0
      fi
      if (( process_count > probe_max_processes )); then
        printf 'Codex job reached %s processes (limit %s)\n' \
          "$process_count" "$probe_max_processes" \
          > "$probe_resource_violation_file"
        exit 0
      fi
      if (( rss_kib > probe_max_rss_kib )); then
        printf 'Codex job reached %s KiB RSS (limit %s KiB)\n' \
          "$rss_kib" "$probe_max_rss_kib" \
          > "$probe_resource_violation_file"
        exit 0
      fi
      if (( cpu_seconds >= probe_max_cpu_seconds )); then
        printf 'Codex job reached %s CPU seconds (limit %s)\n' \
          "$cpu_seconds" "$probe_max_cpu_seconds" \
          > "$probe_resource_violation_file"
        exit 0
      fi
      /bin/sleep 0.1
    done
  ) &
  probe_resource_monitor_pid="$!"
  /bin/sleep 0.05
  if ! /bin/kill -0 "$probe_resource_monitor_pid" 2>/dev/null; then
    # A small limit can be exceeded by the first sample. In that case the
    # monitor has completed its job before this readiness check; the durable
    # violation record is the successful readiness signal.
    [ -s "$probe_resource_violation_file" ] ||
      die "probe resource monitor did not start"
  fi
}

stop_probe_resource_monitor() {
  local pid="${probe_resource_monitor_pid:-}"
  if [ -n "$pid" ]; then
    /bin/kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    probe_resource_monitor_pid=""
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

stage_attester() {
  staged_attester="$isolated_launcher_bin/.office-attest.py"
  staged_argument_policy="$isolated_launcher_bin/.office-argument-policy.py"
  expected_attester_sha256="$(
    sha256_file "$candidate_root/control/attest.py"
  )"
  expected_argument_policy_sha256="$(
    sha256_file "$candidate_root/control/argument-policy.py"
  )"
  /usr/bin/install -m 0500 \
    "$candidate_root/control/attest.py" "$staged_attester"
  /usr/bin/install -m 0400 \
    "$candidate_root/control/argument-policy.py" "$staged_argument_policy"
  verify_staged_attester
}

verify_staged_attester() {
  assert_owned_file "$staged_attester" "0500" "1" \
    "privately staged Office attester"
  [ "$(sha256_file "$staged_attester")" = "$expected_attester_sha256" ] ||
    die "privately staged Office attester hash mismatch"
  [ "$(sha256_file "$candidate_root/control/attest.py")" = \
    "$expected_attester_sha256" ] ||
    die "candidate Office attester changed after private staging"
  assert_owned_file "$staged_argument_policy" "0400" "1" \
    "privately staged Office argument policy"
  [ "$(sha256_file "$staged_argument_policy")" = \
    "$expected_argument_policy_sha256" ] ||
    die "privately staged Office argument policy hash mismatch"
  [ "$(sha256_file "$candidate_root/control/argument-policy.py")" = \
    "$expected_argument_policy_sha256" ] ||
    die "candidate Office argument policy changed after private staging"
}

write_office_launcher() {
  local runtime="$1"
  local launcher="$isolated_launcher_bin/office-$runtime"
  local target="$candidate_root/bin/office-$runtime"
  local attester="$staged_attester"
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

verify_command_input_snapshots() {
  local ledger="$1"
  local bytes
  local path
  local sha256
  local parent

  /usr/bin/jq -e '
    [.[] | select(.attestation != null) |
      .attestation.inputs[].snapshot.path] as $paths |
    ($paths | length) == ($paths | unique | length)
  ' "$ledger" >/dev/null ||
    die "command input snapshot paths are not globally unique"

  while IFS=$'\t' read -r path bytes sha256; do
    require_postprocess_budget "command input snapshot validation"
    [ -n "$path" ] || die "command input snapshot path is empty"
    assert_safe_probe_relative_path "$path" "command input snapshot"
    parent="$probe_root/$(/usr/bin/dirname -- "$path")"
    assert_owned_private_directory "$parent"
    assert_owned_file "$probe_root/$path" "0400" "1" "command input snapshot"
    [ "$(stat_size "$probe_root/$path")" = "$bytes" ] ||
      die "command input snapshot byte count changed after its Office event: $path"
    [ "$(sha256_file "$probe_root/$path")" = "$sha256" ] ||
      die "command input snapshot digest changed after its Office event: $path"
  done < <(
    /usr/bin/jq -r '
      .[] | select(.attestation != null) |
      .attestation.inputs[].snapshot |
      [.path, (.bytes | tostring), .sha256] | @tsv
    ' "$ledger"
  )
}

assert_valid_opc_archive() {
  local package="$1"
  local format="$2"
  local label="$3"
  local remaining_seconds

  require_postprocess_budget "$label OPC validation"
  remaining_seconds=$((postprocess_deadline - SECONDS))
  if (( remaining_seconds > 30 )); then
    remaining_seconds=30
  fi
  if ! /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/python3 -I "$candidate_root/control/opc-policy.py" \
    "$package" "$format" "$remaining_seconds"; then
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
    docx/edit) printf '%s\n' office.docx.edit/2 ;;
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
  local inputs_json
  local produced_relative=""
  local produced_json=null

  require_postprocess_budget "$runtime/$format/$verb workflow validation"

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
      elif $verb == "edit" then
        successful_envelope and
        (.data.output | type) == "string" and
        .data.ops_applied == 1 and
        (.data.replacements | type) == "number" and .data.replacements > 0 and
        (.data.results | type) == "array" and (.data.results | length) == 1 and
        (.data.results[0] |
          .op == "set_run_text" and
          (.at | type) == "string" and
          (.expect | type) == "string" and
          (.text | type) == "string" and
          .expect != .text and
          .find == null and
          .matched == 1 and
          .replacements == 1) and
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
    template | replay | annotate | edit)
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
  artifact_json="$(/usr/bin/jq -cer --arg path "$artifact_relative" '
    [.attestation.files[] | select(.path == $path)] |
    if length == 1 then .[0]
    else error("workflow artifact is absent from the completion attestation")
    end
  ' <<<"$match")" ||
    die "workflow artifact lacks completion-time evidence for $runtime/$format/$verb"
  /usr/bin/jq -e --arg verb "$verb" '
    if $verb == "batch" then
      (.role == "package-output" and .access == "output") or
      (.role == "package" and .access == "input-output")
    elif $verb == "create" or $verb == "template" or
         $verb == "replay" or $verb == "annotate" or $verb == "edit" then
      .role == "package-output" and .access == "output"
    else
      .role == "package" and .access == "input"
    end
  ' <<<"$artifact_json" >/dev/null ||
    die "workflow result follows the wrong command path role for $runtime/$format/$verb"
  /usr/bin/jq -e \
    --arg sha256 "$(sha256_file "$probe_root/$artifact_relative")" \
    --argjson bytes "$(stat_size "$probe_root/$artifact_relative")" '
      .sha256 == $sha256 and .bytes == $bytes
    ' <<<"$artifact_json" >/dev/null ||
    die "workflow artifact changed after its command completed for $runtime/$format/$verb"
  assert_workflow_package "$artifact_relative" "$format" \
    "workflow artifact for $runtime/$format/$verb"
  inputs_json="$(/usr/bin/jq -c '.attestation.inputs' <<<"$match")"

  if [ "$verb" = "preview" ]; then
    produced_relative="$(/usr/bin/jq -er '.data.output' "$result_file")"
    /usr/bin/jq -e --arg path "$produced_relative" \
      '.tokens | index($path) != null' <<<"$match" >/dev/null ||
      die "preview output is not an exact command argument for $runtime/$format"
    produced_json="$(/usr/bin/jq -cer --arg path "$produced_relative" '
      [.attestation.files[] | select(.path == $path)] |
      if length == 1 then .[0]
      else error("preview output is absent from the completion attestation")
      end
    ' <<<"$match")" ||
      die "preview output lacks completion-time evidence for $runtime/$format"
    /usr/bin/jq -e '
      .role == "preview-output" and .access == "output"
    ' <<<"$produced_json" >/dev/null ||
      die "preview result follows the wrong command output role for $runtime/$format"
    /usr/bin/jq -e \
      --arg sha256 "$(sha256_file "$probe_root/$produced_relative")" \
      --argjson bytes "$(stat_size "$probe_root/$produced_relative")" '
        .sha256 == $sha256 and .bytes == $bytes
      ' <<<"$produced_json" >/dev/null ||
      die "preview output changed after its command completed for $runtime/$format"
    assert_workflow_output "$produced_relative" html \
      "preview output for $runtime/$format"
  fi

  /usr/bin/jq -cn \
    --arg event_id "$event_id" \
    --arg command "$command" \
    --arg result_path "$result_relative" \
    --arg result_sha256 "$result_sha256" \
    --argjson result_bytes "$result_bytes" \
    --arg result_schema "$result_schema" \
    --argjson artifact "$artifact_json" \
    --argjson inputs "$inputs_json" \
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
        inputs: $inputs,
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

  require_postprocess_budget "$runtime/$format/$verb workflow selection"

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
            inputs: [],
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
      --arg result_path "matrix-$runtime-$format-$verb.json" \
      --arg verb "$verb" '
        def parsed_command($executable; $verb):
          select(.product_argv != null) |
          .product_argv as $tokens |
          select(
            ($tokens | length) >= 3 and
            $tokens[0] == $executable and
            $tokens[1] == $verb and
            $tokens[-1] == "--json" and
            .attestation.result.path == $result_path
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
    .data.fingerprint as $fingerprint |
    ([.data.records[] | select(.kind == "command") | .name] | sort) as $commands |
    keys == ["data", "schema", "success"] and
    .schema == "office.output/1" and .success == true and
    (.data | keys) == ["fingerprint", "records", "schema"] and
    .data.schema == "office.capabilities/2" and
    (.data.fingerprint | type) == "string" and (.data.fingerprint | length) > 0 and
    (.data.records | type) == "array" and (.data.records | length) >= 18 and
    ([.data.records[] | select(.kind == "format") | .name] | sort) == ["docx", "xlsx"] and
    (["annotate", "batch", "create", "dump", "edit", "get", "help",
      "identify", "issues", "outline", "preview", "query", "raw", "replay",
      "template", "text", "validate"] - $commands | length) == 0 and
    (.data.records | all(
      .schema == "office.capability/2" and
      .fingerprint == $fingerprint
    ))
  ' "$output" >/dev/null ||
    die "installed $runtime help did not produce the complete baseline capability inventory"
}

extract_isolated_contracts() {
  local runtime="$1"
  local output="$2"
  local bare="office-$runtime help schemas --json"
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
      else error("expected exactly one canonical isolated contract-inventory command")
      end
    ' "$isolation_root/transcript-array.json" > "$output" ||
    die "Codex transcript lacks one exact installed contract inventory for $runtime"
  /usr/bin/jq -e '
    keys == ["data", "schema", "success"] and
    .schema == "office.output/1" and .success == true and
    (.data | keys) == ["contracts", "fingerprint", "schema"] and
    .data.schema == "office.input-contracts/1" and
    (.data.fingerprint | test("^sha256:[0-9a-f]{64}$")) and
    (.data.contracts | type) == "array" and (.data.contracts | length) == 7 and
    ([.data.contracts[].id] | sort) == [
      "docx.annotation-batch/1",
      "docx.batch/2",
      "docx.edit/1",
      "docx.edit/2",
      "docx.paragraph/1",
      "office.template.data/1",
      "xlsx.batch/2"
    ] and
    (.data.contracts | all(
      keys == ["consumed_by", "fingerprint", "id", "summary"] and
      (.fingerprint | test("^sha256:[0-9a-f]{64}$")) and
      (.summary | type) == "string" and (.summary | length) > 0 and
      (.consumed_by | type) == "array" and (.consumed_by | length) > 0 and
      (.consumed_by | all(type == "string" and length > 0))
    ))
  ' "$output" >/dev/null ||
    die "installed $runtime help did not produce the complete consumed-contract inventory"
}


run_host_docx_refusal_probes() {
  local evidence_file="$1"
  local host_root="$probe_root/host-refusal"
  local records="$isolation_root/host-docx-refusal-records.jsonl"
  local payload='{"schema":"docx.batch/2","ops":[{"op":"f1b_invalid_operation","params":{}}]}'

  [ ! -e "$host_root" ] && [ ! -L "$host_root" ] ||
    die "host DOCX refusal root already exists"
  [ ! -e "$evidence_file" ] && [ ! -L "$evidence_file" ] ||
    die "host DOCX refusal evidence already exists"
  /bin/mkdir -m 0700 "$host_root"
  : > "$records"
  /bin/chmod 0600 "$records"

  local sequence=0
  for runtime in native wasm; do
    sequence=$((sequence + 1))
    local directory="$host_root/$runtime"
    local script_relative="host-refusal/$runtime/refusal.json"
    local output_relative="host-refusal/$runtime/host-refusal-output.docx"
    local diagnostic_relative="host-refusal/$runtime/diagnostic.json"
    local script="$probe_root/$script_relative"
    local output="$probe_root/$output_relative"
    local diagnostic="$probe_root/$diagnostic_relative"
    local stderr_file="$directory/stderr.log"
    local script_sha256_before
    local script_sha256_after
    local script_bytes
    local status

    /bin/mkdir -m 0700 "$directory"
    /usr/bin/printf '%s\n' "$payload" > "$script"
    /bin/chmod 0600 "$script"
    assert_owned_private_file "$script" "host DOCX refusal script"
    [ ! -e "$output" ] && [ ! -L "$output" ] ||
      die "host DOCX refusal output exists before execution: $runtime"
    if /usr/bin/find "$directory" -maxdepth 1 \
      \( -name '.office-tmp-*' -o -name '.office-output-tmp-*' \) \
      -print -quit | /usr/bin/grep -q .; then
      die "host DOCX refusal has staging before execution: $runtime"
    fi
    script_sha256_before="$(sha256_file "$script")"
    script_bytes="$(stat_size "$script")"

    set +e
    (
      cd -P -- "$probe_root"
      PATH=/usr/bin:/bin:/usr/sbin:/sbin
      TMPDIR="$isolated_tmp"
      LANG=C
      LC_ALL=C
      export PATH TMPDIR LANG LC_ALL
      "$candidate_root/bin/office-$runtime" batch --format docx \
        "$output_relative" "$script_relative" --json \
        > "$diagnostic" 2> "$stderr_file"
    )
    status="$?"
    set -e

    # These are deliberately the first observations after process exit. No
    # agent command can replace the script or erase transaction staging: the
    # agent has exited, and this host-owned probe root did not exist before.
    [ ! -e "$output" ] && [ ! -L "$output" ] ||
      die "host DOCX refusal published an output: $runtime"
    if /usr/bin/find "$directory" -maxdepth 1 \
      \( -name '.office-tmp-*' -o -name '.office-output-tmp-*' \) \
      -print -quit | /usr/bin/grep -q .; then
      die "host DOCX refusal left transaction staging: $runtime"
    fi
    script_sha256_after="$(sha256_file "$script")"
    [ "$script_sha256_after" = "$script_sha256_before" ] ||
      die "host DOCX refusal script changed during execution: $runtime"
    [ "$status" -gt 0 ] && [ "$status" -le 255 ] ||
      die "host DOCX refusal returned an invalid status: $runtime ($status)"
    assert_owned_private_file "$diagnostic" "host DOCX refusal diagnostic"
    assert_owned_private_file "$stderr_file" "host DOCX refusal stderr"
    [ "$(stat_size "$diagnostic")" -gt 0 ] ||
      die "host DOCX refusal diagnostic is empty: $runtime"
    if ! /usr/bin/jq -s -e '
      length == 1 and
      .[0].schema == "office.output/1" and
      .[0].success == false and
      .[0].error.code == "office.docx.batch_parse"
    ' "$diagnostic" >/dev/null; then
      die "host DOCX refusal returned the wrong typed diagnostic: $runtime"
    fi

    /usr/bin/jq -n \
      --arg runtime "$runtime" \
      --argjson sequence "$sequence" \
      --argjson exit_status "$status" \
      --arg script_path "$script_relative" \
      --arg script_sha256 "$script_sha256_before" \
      --argjson script_bytes "$script_bytes" \
      --arg diagnostic_path "$diagnostic_relative" \
      --arg diagnostic_sha256 "$(sha256_file "$diagnostic")" \
      --argjson diagnostic_bytes "$(stat_size "$diagnostic")" \
      --arg output "$output_relative" \
      '{
        runtime: $runtime,
        sequence: $sequence,
        command: [
          ("office-" + $runtime), "batch", "--format", "docx",
          $output, $script_path, "--json"
        ],
        script: {
          path: $script_path,
          sha256: $script_sha256,
          bytes: $script_bytes
        },
        diagnostic: {
          path: $diagnostic_path,
          sha256: $diagnostic_sha256,
          bytes: $diagnostic_bytes
        },
        exit_status: $exit_status,
        error_code: "office.docx.batch_parse",
        output: $output,
        output_absent_before: true,
        output_absent_after: true,
        staging_before: [],
        staging_after: [],
        postcondition: "immediate-after-process-exit"
      }' >> "$records"
  done

  /usr/bin/jq -s '{
    schema: "office.fresh-agent.docx-refusals/1",
    required_count: length,
    refusals: .
  }' "$records" > "$evidence_file"
  /bin/chmod 0600 "$evidence_file"
  assert_owned_private_file "$evidence_file" "host DOCX refusal evidence"
  /usr/bin/jq -e '
    keys == ["refusals", "required_count", "schema"] and
    .schema == "office.fresh-agent.docx-refusals/1" and
    .required_count == 2 and
    [.refusals[].runtime] == ["native", "wasm"] and
    (.refusals | all(
      .error_code == "office.docx.batch_parse" and
      .output_absent_before == true and .output_absent_after == true and
      .staging_before == [] and .staging_after == [] and
      .postcondition == "immediate-after-process-exit"
    ))
  ' "$evidence_file" >/dev/null ||
    die "host DOCX refusal evidence failed strict validation"
}


run_host_xlsx_refusal_probes() {
  local evidence_file="$1"
  local workflows_file="$2"
  local host_root="$probe_root/host-xlsx-refusal"
  local records="$isolation_root/host-xlsx-refusal-records.jsonl"
  local payload='{"schema":"xlsx.batch/2","ops":[{"op":"set","params":{"sheet":"Data","cell":"A9","value":"refusal"}}]}'

  [ ! -e "$host_root" ] && [ ! -L "$host_root" ] ||
    die "host XLSX refusal root already exists"
  [ ! -e "$evidence_file" ] && [ ! -L "$evidence_file" ] ||
    die "host XLSX refusal evidence already exists"
  /bin/mkdir -m 0700 "$host_root"
  : > "$records"
  /bin/chmod 0600 "$records"

  local sequence=0
  for runtime in native wasm; do
    sequence=$((sequence + 1))
    local directory="$host_root/$runtime"
    local source_relative
    local source
    local script_relative="host-xlsx-refusal/$runtime/refusal.json"
    local target_relative="host-xlsx-refusal/$runtime/refusal-target.xlsx"
    local before_relative="host-xlsx-refusal/$runtime/refusal-before.xlsx"
    local diagnostic_relative="host-xlsx-refusal/$runtime/diagnostic.json"
    local script="$probe_root/$script_relative"
    local target="$probe_root/$target_relative"
    local before="$probe_root/$before_relative"
    local diagnostic="$probe_root/$diagnostic_relative"
    local stderr_file="$directory/stderr.log"
    local source_sha256
    local source_bytes
    local script_sha256_before
    local script_sha256_after
    local script_bytes
    local before_sha256
    local before_bytes
    local target_sha256
    local target_bytes
    local status

    source_relative="$(
      /usr/bin/jq -er --arg runtime "$runtime" '
        [.workflows[] |
          select(
            .runtime == $runtime and .format == "xlsx" and
            .operation == "template"
          ) |
          .events[0].artifact.path] |
        if length == 1 then .[0]
        else error("missing canonical XLSX final artifact")
        end
      ' "$workflows_file"
    )" || die "host XLSX refusal cannot locate the final package: $runtime"
    source="$probe_root/$source_relative"
    assert_owned_private_file "$source" "host XLSX refusal source"
    source_sha256="$(sha256_file "$source")"
    source_bytes="$(stat_size "$source")"

    /bin/mkdir -m 0700 "$directory"
    /bin/cp -- "$source" "$target"
    /bin/cp -- "$target" "$before"
    /bin/chmod 0600 "$target" "$before"
    /usr/bin/printf '%s\n' "$payload" > "$script"
    /bin/chmod 0600 "$script"
    assert_owned_private_file "$target" "host XLSX refusal target"
    assert_owned_private_file "$before" "host XLSX refusal before-image"
    assert_owned_private_file "$script" "host XLSX refusal script"
    if /usr/bin/find "$directory" -maxdepth 1 \
      \( -name '.office-tmp-*' -o -name '.office-output-tmp-*' \) \
      -print -quit | /usr/bin/grep -q .; then
      die "host XLSX refusal has staging before execution: $runtime"
    fi
    script_sha256_before="$(sha256_file "$script")"
    script_bytes="$(stat_size "$script")"
    before_sha256="$(sha256_file "$before")"
    before_bytes="$(stat_size "$before")"

    set +e
    (
      cd -P -- "$probe_root"
      PATH=/usr/bin:/bin:/usr/sbin:/sbin
      TMPDIR="$isolated_tmp"
      LANG=C
      LC_ALL=C
      export PATH TMPDIR LANG LC_ALL
      "$candidate_root/bin/office-$runtime" batch \
        "$source_relative" "$script_relative" \
        --out "$target_relative" --json \
        > "$diagnostic" 2> "$stderr_file"
    )
    status="$?"
    set -e

    # These are the first observations after process exit. The Codex process
    # has already terminated and never had access to this host-owned root.
    target_sha256="$(sha256_file "$target")"
    target_bytes="$(stat_size "$target")"
    [ "$target_sha256" = "$before_sha256" ] &&
      [ "$target_bytes" = "$before_bytes" ] ||
      die "host XLSX refusal changed its existing target: $runtime"
    if /usr/bin/find "$directory" -maxdepth 1 \
      \( -name '.office-tmp-*' -o -name '.office-output-tmp-*' \) \
      -print -quit | /usr/bin/grep -q .; then
      die "host XLSX refusal left transaction staging: $runtime"
    fi
    script_sha256_after="$(sha256_file "$script")"
    [ "$script_sha256_after" = "$script_sha256_before" ] ||
      die "host XLSX refusal script changed during execution: $runtime"
    [ "$status" -gt 0 ] && [ "$status" -le 255 ] ||
      die "host XLSX refusal returned an invalid status: $runtime ($status)"
    assert_owned_private_file "$diagnostic" "host XLSX refusal diagnostic"
    assert_owned_private_file "$stderr_file" "host XLSX refusal stderr"
    [ "$(stat_size "$diagnostic")" -gt 0 ] ||
      die "host XLSX refusal diagnostic is empty: $runtime"
    if ! /usr/bin/jq -s -e '
      length == 1 and
      .[0].schema == "office.output/1" and
      .[0].success == false and
      (. [0].error | type) == "object" and
      .[0].error.code == "office.transaction.output_exists" and
      (. [0].error.message | type) == "string" and
      (. [0].error.message | length) > 0 and
      (. [0].error.details | type) == "object"
    ' "$diagnostic" >/dev/null; then
      die "host XLSX refusal returned the wrong typed diagnostic: $runtime"
    fi

    /usr/bin/jq -n \
      --arg runtime "$runtime" \
      --argjson sequence "$sequence" \
      --argjson exit_status "$status" \
      --arg source_path "$source_relative" \
      --arg source_sha256 "$source_sha256" \
      --argjson source_bytes "$source_bytes" \
      --arg script_path "$script_relative" \
      --arg script_sha256 "$script_sha256_before" \
      --argjson script_bytes "$script_bytes" \
      --arg diagnostic_path "$diagnostic_relative" \
      --arg diagnostic_sha256 "$(sha256_file "$diagnostic")" \
      --argjson diagnostic_bytes "$(stat_size "$diagnostic")" \
      --arg before_path "$before_relative" \
      --arg before_sha256 "$before_sha256" \
      --argjson before_bytes "$before_bytes" \
      --arg target_path "$target_relative" \
      --arg target_sha256 "$target_sha256" \
      --argjson target_bytes "$target_bytes" \
      '{
        runtime: $runtime,
        sequence: $sequence,
        command: [
          ("office-" + $runtime), "batch", $source_path, $script_path,
          "--out", $target_path, "--json"
        ],
        source: {
          path: $source_path,
          sha256: $source_sha256,
          bytes: $source_bytes
        },
        script: {
          path: $script_path,
          sha256: $script_sha256,
          bytes: $script_bytes
        },
        diagnostic: {
          path: $diagnostic_path,
          sha256: $diagnostic_sha256,
          bytes: $diagnostic_bytes
        },
        before: {
          path: $before_path,
          sha256: $before_sha256,
          bytes: $before_bytes
        },
        target: {
          path: $target_path,
          sha256: $target_sha256,
          bytes: $target_bytes
        },
        exit_status: $exit_status,
        error_code: "office.transaction.output_exists",
        target_exists_before: true,
        target_exists_after: true,
        staging_before: [],
        staging_after: [],
        postcondition: "immediate-after-process-exit"
      }' >> "$records"
  done

  /usr/bin/jq -s '{
    schema: "office.fresh-agent.xlsx-refusals/1",
    required_count: length,
    refusals: .
  }' "$records" > "$evidence_file"
  /bin/chmod 0600 "$evidence_file"
  assert_owned_private_file "$evidence_file" "host XLSX refusal evidence"
  /usr/bin/jq -e '
    keys == ["refusals", "required_count", "schema"] and
    .schema == "office.fresh-agent.xlsx-refusals/1" and
    .required_count == 2 and
    [.refusals[].runtime] == ["native", "wasm"] and
    (.refusals | all(
      .error_code == "office.transaction.output_exists" and
      .target_exists_before == true and .target_exists_after == true and
      .before.sha256 == .target.sha256 and
      .before.bytes == .target.bytes and
      .staging_before == [] and .staging_after == [] and
      .postcondition == "immediate-after-process-exit"
    ))
  ' "$evidence_file" >/dev/null ||
    die "host XLSX refusal evidence failed strict validation"
}


ensure_postprocess_deadline() {
  if (( ${postprocess_deadline:-0} == 0 )); then
    postprocess_deadline=$((SECONDS + postprocess_timeout_seconds))
  fi
}

remaining_postprocess_budget() {
  local label="$1"
  local remaining_seconds
  ensure_postprocess_deadline
  require_postprocess_budget "$label"
  remaining_seconds=$((postprocess_deadline - SECONDS))
  (( remaining_seconds >= 1 )) ||
    die "post-processing exceeded its ${postprocess_timeout_seconds}s global deadline before $label"
  printf '%s\n' "$remaining_seconds"
}

publish_evidence_closure() {
  local evidence_policy="$candidate_root/control/evidence-policy.py"
  local remaining_seconds
  local -a publish_args
  remaining_seconds="$(remaining_postprocess_budget "evidence closure publication")"
  publish_args=(
    publish
    --evidence-root "$evidence_root"
    --candidate-root "$candidate_root"
    --probe-root "$probe_root"
    --candidate-head "$expected_head"
    --candidate-sha256 "$expected_candidate_sha256"
    --codex-bin "$codex_bin"
    --codex-version "$codex_version"
    --codex-sha256 "$expected_codex_sha256"
    --bwrap-selection "$bwrap_selection"
    --timeout-seconds "$remaining_seconds"
  )
  if [ "$bwrap_selection" != "none" ]; then
    publish_args+=(
      --bwrap-bin "$bwrap_bin"
      --bwrap-sha256 "$expected_bwrap_sha256"
    )
  fi
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/python3 -I "$evidence_policy" "${publish_args[@]}" ||
    die "could not publish the bounded self-contained evidence closure"
  verify_candidate \
    "$evidence_root/closure/candidate" "$expected_candidate_sha256"
  [ "$(sha256_file "$evidence_root/closure/runtime/codex")" = \
    "$expected_codex_sha256" ] ||
    die "retained Codex runtime does not match its approved digest"
  if [ "$bwrap_selection" != "none" ]; then
    [ "$(sha256_file "$evidence_root/closure/runtime/bwrap")" = \
      "$expected_bwrap_sha256" ] ||
      die "retained bubblewrap runtime does not match its approved digest"
  fi
  verify_candidate "$candidate_root" "$expected_candidate_sha256"
  verify_candidate "$install_root" "$expected_candidate_sha256"
  verify_codex_runtime
}

write_evidence_manifest() {
  local mode="$1"
  local evidence_policy="$candidate_root/control/evidence-policy.py"
  local remaining_seconds
  publish_evidence_closure
  remaining_seconds="$(remaining_postprocess_budget "evidence manifest publication")"
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/python3 -I "$evidence_policy" manifest \
      --evidence-root "$evidence_root" \
      --mode "$mode" \
      --candidate-head "$expected_head" \
      --candidate-sha256 "$expected_candidate_sha256" \
      --output "$isolation_root/EVIDENCE.json" \
      --timeout-seconds "$remaining_seconds" ||
    die "could not create the recursive evidence manifest"
  /usr/bin/install -m 0600 "$isolation_root/EVIDENCE.json" \
    "$evidence_root/EVIDENCE.json"
  remaining_seconds="$(remaining_postprocess_budget "evidence manifest verification")"
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/python3 -I "$evidence_policy" verify \
      --evidence-root "$evidence_root" \
      --manifest "$evidence_root/EVIDENCE.json" \
      --timeout-seconds "$remaining_seconds" ||
    die "published evidence does not reproduce its recursive manifest"
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

for tool in jq shasum awk du find sort stat id mktemp mkfifo install wc tr readlink nc python3 uname ps sleep perl grep lsof; do
  require_command "$tool"
done
netcat_bin="$(command -v nc)"
case "$netcat_bin" in
  /*) ;;
  *) die "netcat must resolve to an absolute path" ;;
esac
lsof_bin="$(command -v lsof)"
case "$lsof_bin" in
  /*) ;;
  *) die "lsof must resolve to an absolute path" ;;
esac
platform_name="$(/usr/bin/uname -s)"
codex_version_timeout_seconds="${OFFICE_F1B_CODEX_VERSION_TIMEOUT_SECONDS:-30}"
codex_canary_timeout_seconds="${OFFICE_F1B_CODEX_CANARY_TIMEOUT_SECONDS:-180}"
codex_probe_timeout_seconds="${OFFICE_F1B_CODEX_PROBE_TIMEOUT_SECONDS:-1800}"
postprocess_timeout_seconds="${OFFICE_F1B_POSTPROCESS_TIMEOUT_SECONDS:-300}"
probe_max_kib="${OFFICE_F1B_PROBE_MAX_KIB:-524288}"
probe_max_entries="${OFFICE_F1B_PROBE_MAX_ENTRIES:-8192}"
probe_max_rss_kib="${OFFICE_F1B_PROBE_MAX_RSS_KIB:-4194304}"
probe_max_processes="${OFFICE_F1B_PROBE_MAX_PROCESSES:-128}"
probe_max_cpu_seconds="${OFFICE_F1B_PROBE_MAX_CPU_SECONDS:-1900}"
validate_timeout_seconds \
  "$codex_version_timeout_seconds" 30 \
  OFFICE_F1B_CODEX_VERSION_TIMEOUT_SECONDS
validate_timeout_seconds \
  "$codex_canary_timeout_seconds" 180 \
  OFFICE_F1B_CODEX_CANARY_TIMEOUT_SECONDS
validate_timeout_seconds \
  "$codex_probe_timeout_seconds" 1800 \
  OFFICE_F1B_CODEX_PROBE_TIMEOUT_SECONDS
validate_timeout_seconds \
  "$postprocess_timeout_seconds" 600 \
  OFFICE_F1B_POSTPROCESS_TIMEOUT_SECONDS
validate_integer_range \
  "$probe_max_kib" 1024 524288 OFFICE_F1B_PROBE_MAX_KIB
validate_integer_range \
  "$probe_max_entries" 128 8192 OFFICE_F1B_PROBE_MAX_ENTRIES
validate_integer_range \
  "$probe_max_rss_kib" 8192 4194304 OFFICE_F1B_PROBE_MAX_RSS_KIB
validate_integer_range \
  "$probe_max_processes" 4 128 OFFICE_F1B_PROBE_MAX_PROCESSES
validate_integer_range \
  "$probe_max_cpu_seconds" 1 1900 OFFICE_F1B_PROBE_MAX_CPU_SECONDS

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
  # Validate only the canonical path here. The credential guard performs the
  # authoritative symlink-free open and retains that exact file description.
  auth_json="$(canonical_unopened_leaf "$auth_input" "Codex auth JSON")"
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
probe_resource_monitor_pid=""
probe_resource_violation_file=""
isolated_codex_state_identity=""
job_sentinel=""
auth_guard_pid=""
auth_guard_root=""
auth_guard_root_identity=""
auth_guard_request=""
auth_guard_response=""
auth_guard_log=""
auth_guard_response_json=""
auth_source_bytes=""
auth_source_sha256=""

cleanup() {
  local status="$1"
  trap - EXIT
  trap '' HUP INT TERM
  if ! terminate_supervised_codex; then
    status=1
  fi
  stop_probe_resource_monitor
  if ! stop_auth_guard; then
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
  trap - HUP INT TERM
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
job_sentinel="$isolation_root/job-sentinel"
printf 'office-f1b-job %s %s\n' "$expected_head" "$$" > "$job_sentinel"
chmod 0400 "$job_sentinel"
assert_owned_file "$job_sentinel" "0400" "1" "Codex job sentinel"
isolated_codex_state_identity="$(stat_identity "$isolated_codex_state")"
if [ "$canary_only" -eq 0 ]; then
  start_auth_guard
fi
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
  "version probe" "$codex_version_timeout_seconds" "$codex_version_stderr"
codex_version_status="$supervised_codex_status"
if [ "$codex_version_status" -ne 0 ]; then
  /bin/cat "$codex_version_stderr" >&2
  if [ "$codex_version_status" -eq 124 ] ||
    [ "$codex_version_status" -eq 125 ]; then
    exit "$codex_version_status"
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
stage_attester
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
verify_staged_attester

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
  printf '%s = "deny"\n' "$(toml_string "$job_sentinel")"
  if [ -n "$auth_guard_root" ]; then
    printf '%s = "deny"\n' "$(toml_string "$auth_guard_root")"
  fi
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
  "permission canary" "$codex_canary_timeout_seconds" \
  "$evidence_root/permission-canary.log"
canary_status="$supervised_codex_status"
assert_loopback_listener_reachable ||
  die "loopback denial-canary listener is not live after the permission canary"
if [ "$canary_status" -ne 0 ]; then
  echo "error: Codex permission-profile canary log follows" >&2
  /bin/cat "$evidence_root/permission-canary.log" >&2
  if [ "$canary_status" -eq 124 ] || [ "$canary_status" -eq 125 ]; then
    exit "$canary_status"
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
verify_staged_attester

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
  --arg attester_sha256 "$expected_attester_sha256" \
  --arg argument_policy_sha256 "$expected_argument_policy_sha256" \
  --arg auth_guard_sha256 "$(sha256_file "$candidate_root/control/auth-guard.py")" \
  --arg job_sentinel_sha256 "$(sha256_file "$job_sentinel")" \
  --arg prompt_sha256 "$prompt_sha256" \
  --arg output_schema_sha256 "$output_schema_sha256" \
  --arg codex_version "$codex_version" \
  --arg codex_sha256 "$expected_codex_sha256" \
  --argjson bubblewrap "$bwrap_evidence_json" \
  --arg config_sha256 "$config_sha256_before" \
  --arg permission_canary_sha256 "$canary_sha256" \
  --argjson max_cpu_seconds "$probe_max_cpu_seconds" \
  --argjson max_entries "$probe_max_entries" \
  --argjson max_processes "$probe_max_processes" \
  --argjson max_rss_kib "$probe_max_rss_kib" \
  --argjson max_storage_kib "$probe_max_kib" \
  --arg platform_name "$platform_name" \
  '{
    schema: $schema,
    candidate_head: $candidate_head,
    candidate_manifest_sha256: $candidate_manifest_sha256,
    harness: {
      runner_sha256: $runner_sha256,
      attester_sha256: $attester_sha256,
      argument_policy_sha256: $argument_policy_sha256,
      credential_guard: {
        policy_sha256: $auth_guard_sha256,
        source_open: "component-wise O_NOFOLLOW retained FD",
        delayed_staging: true
      },
      prompt_sha256: $prompt_sha256,
      output_schema_sha256: $output_schema_sha256,
      config_sha256: $config_sha256,
      permission_canary_sha256: $permission_canary_sha256,
      job_identity: {
        inherited_fd: 9,
        sentinel_sha256: $job_sentinel_sha256,
        detached_member_discovery: "lsof"
      },
      resource_policy: {
        cpu_seconds: $max_cpu_seconds,
        file_size_bytes: 134217728,
        open_files: 256,
        process_count: $max_processes,
        rss_kib: $max_rss_kib,
        storage_kib: $max_storage_kib,
        storage_entries: $max_entries,
        virtual_memory_kib: (if $platform_name == "Linux" then 4194304 else null end),
        writable_roots: ["probe", "evidence", "home", "scratch", "codex_state"]
      },
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
  verify_staged_attester
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
  write_evidence_manifest canary
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
verify_staged_attester

# The real credential enters the isolation only after every unauthenticated
# preflight and sandbox check has succeeded. The guard copies the immutable
# snapshot from its retained, symlink-free source FD; this path is not reopened.
stage_isolated_auth

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
start_probe_resource_monitor "$codex_pgid"
wait_for_supervised_codex \
  "installed-command probe" "$codex_probe_timeout_seconds" \
  "$evidence_root/codex-stderr.log"
codex_status="$supervised_codex_status"
stop_probe_resource_monitor
if [ -s "$probe_resource_violation_file" ] && [ "$codex_status" -eq 0 ]; then
  echo "error: Codex probe exceeded its bounded resource policy" >&2
  /bin/cat "$probe_resource_violation_file" >&2
  codex_status=125
fi
assert_loopback_listener_reachable ||
  die "loopback denial-canary listener is not live after the installed-command probe"

printf 'codex_exit_status=%s\n' "$codex_status" \
  > "$evidence_root/codex-exit-status.txt"
remove_isolated_auth ||
  die "could not remove the staged Codex credential after the probe"

verify_candidate "$install_root" "$expected_candidate_sha256"
verify_candidate "$candidate_root" "$expected_candidate_sha256"
verify_codex_runtime
verify_staged_attester
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

postprocess_deadline=$((SECONDS + postprocess_timeout_seconds))

assert_owned_private_file "$evidence_root/final-message.json" "Codex final message"
assert_owned_private_file "$evidence_root/codex-transcript.jsonl" "Codex transcript"
assert_owned_private_file "$evidence_root/codex-stderr.log" "Codex stderr"
[ "$(stat_size "$evidence_root/final-message.json")" -le 1048576 ] ||
  die "Codex final message exceeds 1 MiB"
[ "$(stat_size "$evidence_root/codex-stderr.log")" -le 8388608 ] ||
  die "Codex stderr exceeds 8 MiB"
if ! /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$candidate_root/control/transcript-policy.py" \
  "$evidence_root/codex-transcript.jsonl" "$codex_status" \
  "$isolation_root/transcript-array.json"; then
  die "Codex transcript lifecycle or size policy was invalid"
fi
require_postprocess_budget "transcript validation"

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
require_postprocess_budget "command-policy validation"
verify_command_input_snapshots "$isolation_root/COMMANDS.json"
require_postprocess_budget "command input snapshot validation"
/usr/bin/install -m 0600 "$isolation_root/COMMANDS.json" \
  "$evidence_root/COMMANDS.json"
write_host_command_transcript
host_docx_refusals="$isolation_root/DOCX-REFUSALS.json"
run_host_docx_refusal_probes "$host_docx_refusals"
/usr/bin/install -m 0600 "$host_docx_refusals" \
  "$evidence_root/DOCX-REFUSALS.json"
require_postprocess_budget "host DOCX refusal probes"

extract_isolated_help native "$isolation_root/native-help.json"
extract_isolated_help wasm "$isolation_root/wasm-help.json"
extract_isolated_contracts native "$isolation_root/native-contracts.json"
extract_isolated_contracts wasm "$isolation_root/wasm-contracts.json"
/usr/bin/jq -S -c . "$isolation_root/native-help.json" \
  > "$isolation_root/native-help.canonical.json"
/usr/bin/jq -S -c . "$isolation_root/wasm-help.json" \
  > "$isolation_root/wasm-help.canonical.json"
/usr/bin/cmp \
  "$isolation_root/native-help.canonical.json" \
  "$isolation_root/wasm-help.canonical.json" ||
  die "installed native and Wasm capability help differ"
/usr/bin/jq -S -c . "$isolation_root/native-contracts.json" \
  > "$isolation_root/native-contracts.canonical.json"
/usr/bin/jq -S -c . "$isolation_root/wasm-contracts.json" \
  > "$isolation_root/wasm-contracts.canonical.json"
/usr/bin/cmp \
  "$isolation_root/native-contracts.canonical.json" \
  "$isolation_root/wasm-contracts.canonical.json" ||
  die "installed native and Wasm input-contract inventories differ"
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
  for verb in batch identify outline get text query validate issues preview template dump replay raw edit annotate; do
    record_workflow_evidence "$runtime" docx "$verb"
  done
done
/usr/bin/jq -s \
  --arg schema "office.fresh-agent.workflows/5" \
  '{
    schema: $schema,
    required_count: length,
    workflows: .
  }' "$workflow_entries" > "$isolation_root/WORKFLOWS.json"
/usr/bin/jq -e '
  keys == ["required_count", "schema", "workflows"] and
  .schema == "office.fresh-agent.workflows/5" and
  .required_count == 60 and
  (.workflows | length) == 60 and
  (.workflows | unique_by([.runtime, .format, .operation]) | length) == 60 and
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
      keys == ["artifact", "command", "event_id", "inputs", "produced", "result"] and
      (.command | type) == "string" and
      (.event_id | type) == "string" and (.event_id | length) > 0 and
      (.result | keys) == ["bytes", "path", "schema", "sha256"] and
      (.result.path == null or (.result.path | type) == "string") and
      (.result.bytes | type) == "number" and
      .result.bytes == (.result.bytes | floor) and .result.bytes > 0 and
      (.result.schema | type) == "string" and
      (.result.sha256 | test("^[0-9a-f]{64}$")) and
      (.artifact == null or (
        (.artifact | keys) == ["access", "argument_index", "bytes", "path", "role", "sha256"] and
        (.artifact.access == "input" or .artifact.access == "input-output" or .artifact.access == "output") and
        (.artifact.argument_index | type) == "number" and
        .artifact.argument_index == (.artifact.argument_index | floor) and
        .artifact.argument_index >= 0 and
        (.artifact.path | type) == "string" and
        (.artifact.role | type) == "string" and (.artifact.role | length) > 0 and
        (.artifact.bytes | type) == "number" and
        .artifact.bytes == (.artifact.bytes | floor) and .artifact.bytes > 0 and
        (.artifact.sha256 | test("^[0-9a-f]{64}$"))
      )) and
      (.inputs | type) == "array" and
      (.inputs | all(
        keys == ["access", "argument_index", "path", "role", "snapshot"] and
        (.access == "input" or .access == "input-output") and
        (.argument_index | type) == "number" and
        .argument_index == (.argument_index | floor) and .argument_index >= 0 and
        (.path | type) == "string" and (.path | length) > 0 and
        (.role | type) == "string" and (.role | length) > 0 and
        (.snapshot | keys) == ["bytes", "path", "sha256"] and
        (.snapshot.bytes | type) == "number" and
        .snapshot.bytes == (.snapshot.bytes | floor) and
        .snapshot.bytes > 0 and
        (.snapshot.path | test("^input-evidence/event-[0-9a-f]{32}/[0-9]{3}[.]")) and
        (.snapshot.sha256 | test("^[0-9a-f]{64}$"))
      )) and
      (.produced == null or (
        (.produced | keys) == ["access", "argument_index", "bytes", "path", "role", "sha256"] and
        .produced.access == "output" and
        (.produced.argument_index | type) == "number" and
        .produced.argument_index == (.produced.argument_index | floor) and
        .produced.argument_index >= 0 and
        (.produced.path | type) == "string" and
        .produced.role == "preview-output" and
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
require_postprocess_budget "workflow evidence aggregation"
host_xlsx_refusals="$isolation_root/XLSX-REFUSALS.json"
run_host_xlsx_refusal_probes \
  "$host_xlsx_refusals" "$isolation_root/WORKFLOWS.json"
/usr/bin/install -m 0600 "$host_xlsx_refusals" \
  "$evidence_root/XLSX-REFUSALS.json"
require_postprocess_budget "host XLSX refusal probes"
/usr/bin/install -m 0600 "$isolation_root/raw-commands.json" \
  "$evidence_root/RAW-COMMANDS.json"
if ! /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$candidate_root/control/scenario-policy.py" build \
  "$probe_root" \
  "$isolation_root/COMMANDS.json" \
  "$isolation_root/raw-commands.json" \
  "$isolation_root/WORKFLOWS.json" \
  "$host_xlsx_refusals" \
  "$host_docx_refusals" \
  "$isolation_root/SCENARIOS.json"; then
  die "host-derived scenario semantics failed validation"
fi
/usr/bin/install -m 0600 "$isolation_root/SCENARIOS.json" \
  "$evidence_root/SCENARIOS.json"
require_postprocess_budget "scenario evidence aggregation"

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
[ "$(stat_size "$result_file")" -le 1048576 ] ||
  die "probe result exceeds 1 MiB"
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
  --arg raw_commands_sha256 "$(sha256_file "$evidence_root/RAW-COMMANDS.json")" \
  --arg workflows_sha256 "$(sha256_file "$evidence_root/WORKFLOWS.json")" \
  --arg xlsx_refusals_sha256 "$(sha256_file "$evidence_root/XLSX-REFUSALS.json")" \
  --arg docx_refusals_sha256 "$(sha256_file "$evidence_root/DOCX-REFUSALS.json")" \
  --arg scenarios_sha256 "$(sha256_file "$evidence_root/SCENARIOS.json")" \
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
      raw_commands_sha256: $raw_commands_sha256,
      workflows_sha256: $workflows_sha256,
      xlsx_refusals_sha256: $xlsx_refusals_sha256,
      docx_refusals_sha256: $docx_refusals_sha256,
      scenarios_sha256: $scenarios_sha256,
      final_message_sha256: $final_message_sha256
    }
  }' > "$isolation_root/RUN.json"
/usr/bin/install -m 0600 "$isolation_root/RUN.json" "$evidence_root/RUN.json"
write_evidence_manifest baseline
require_postprocess_budget "successful evidence completion"

printf 'probe_dir=%s\n' "$probe_root"
printf 'evidence_dir=%s\n' "$evidence_root"
printf 'verdict=%s\n' "$verdict"

[ "$verdict" = "BASELINE PASS" ] || exit 3

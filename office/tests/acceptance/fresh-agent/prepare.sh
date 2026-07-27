#!/bin/bash -p

case "$-" in
  *p*) ;;
  *)
    echo "error: execute prepare.sh directly so Bash privileged mode can ignore BASH_ENV" >&2
    exit 2
    ;;
esac

set -euo pipefail
umask 077

PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
unset BASH_ENV ENV CDPATH GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_CONFIG GIT_CONFIG_GLOBAL
unset GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_CEILING_DIRECTORIES NODE_OPTIONS
unset GIT_EXEC_PATH GIT_TEMPLATE_DIR GIT_ATTR_NOSYSTEM GIT_NO_REPLACE_OBJECTS
unset DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH LD_PRELOAD LD_LIBRARY_PATH
unset PERL5OPT PERL5LIB TAR_OPTIONS POSIXLY_CORRECT BLOCKSIZE
TMPDIR=/tmp
export TMPDIR

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 EXPECTED_FULL_HEAD ABSENT_INSTALL_PREFIX MOON_BIN MOONC_BIN MOONRUN_BIN" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "required command is unavailable: $1"
}

sha256_file() {
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/shasum -a 256 "$1" |
    /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
      /usr/bin/awk '{print substr($1, length($1) - 63)}'
}

trusted_git() {
  /usr/bin/env -i \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LANG=C \
    LC_ALL=C \
    GIT_NO_REPLACE_OBJECTS=1 \
    GIT_CONFIG=/dev/null \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_SYSTEM=/dev/null \
    GIT_ATTR_NOSYSTEM=1 \
    /usr/bin/git --no-replace-objects \
      -c core.attributesFile=/dev/null \
      -c core.fsmonitor=false \
      -c core.untrackedCache=false \
      "$@"
}

stat_owner_mode() {
  if /usr/bin/stat -f '%u %Lp' "$1" >/dev/null 2>&1; then
    /usr/bin/stat -f '%u %Lp' "$1"
  else
    /usr/bin/stat -c '%u %a' "$1"
  fi
}

stat_identity() {
  if /usr/bin/stat -f '%d:%i' "$1" >/dev/null 2>&1; then
    /usr/bin/stat -f '%d:%i' "$1"
  else
    /usr/bin/stat -c '%d:%i' "$1"
  fi
}

assert_private_directory() {
  local path="$1"
  local owner
  local mode
  read -r owner mode <<<"$(stat_owner_mode "$path")"
  [ "$owner" = "$(/usr/bin/id -u)" ] ||
    die "directory is not owned by the current user: $path"
  case "$mode" in
    "" | *[!0-7]*) die "could not read directory mode: $path" ;;
  esac
  if (( (8#$mode & 077) != 0 )); then
    die "directory must not grant group or other access: $path (mode $mode)"
  fi
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
  local resolved
  case "$input" in
    /*) ;;
    *) die "$label must be an absolute path: $input" ;;
  esac
  reject_path_syntax "$input" "$label"
  parent="$(canonical_directory "$(/usr/bin/dirname -- "$input")")"
  resolved="$parent/$(/usr/bin/basename -- "$input")"
  [ -f "$resolved" ] && [ ! -L "$resolved" ] && [ -x "$resolved" ] ||
    die "$label must be an executable regular non-symlink file: $resolved"
  printf '%s\n' "$resolved"
}

reject_path_syntax() {
  local path="$1"
  local label="$2"
  case "$path" in
    *:*) die "$label must not contain ':' because it is used in PATH: $path" ;;
    *$'\n'* | *$'\r'*) die "$label must not contain a newline: $path" ;;
  esac
}

canonical_absent_path() {
  local input="$1"
  local parent
  local name
  case "$input" in
    /*) ;;
    *) die "install prefix must be absolute: $input" ;;
  esac
  [ ! -e "$input" ] && [ ! -L "$input" ] ||
    die "install prefix must not already exist: $input"
  name="$(/usr/bin/basename -- "$input")"
  case "$name" in
    "" | "." | "..") die "invalid install prefix: $input" ;;
  esac
  parent="$(canonical_directory "$(/usr/bin/dirname -- "$input")")"
  assert_private_directory "$parent"
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

reject_overlap() {
  local left="$1"
  local left_label="$2"
  local right="$3"
  local right_label="$4"
  if paths_overlap "$left" "$right"; then
    die "$left_label and $right_label must not overlap"
  fi
}

[ "$#" -eq 5 ] || usage
expected_head="$1"
install_input="$2"
moon_input="$3"
moonc_input="$4"
moonrun_input="$5"

case "$expected_head" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) die "EXPECTED_FULL_HEAD must be a lowercase 40-character commit id" ;;
esac

for tool in git jq shasum awk sed find sort tar cmp diff install mktemp stat id basename dirname mv ln env perl uname; do
  require_command "$tool"
done

moon_bin="$(canonical_regular_file "$moon_input" "Moon compiler")"
moonc_bin="$(canonical_regular_file "$moonc_input" "Moon code generator")"
moonrun_bin="$(canonical_regular_file "$moonrun_input" "Moon runtime")"

moon_bin_dir="$(canonical_directory "$(/usr/bin/dirname -- "$moon_bin")")"
[ "$(canonical_directory "$(/usr/bin/dirname -- "$moonc_bin")")" = "$moon_bin_dir" ] ||
  die "Moon compiler and code generator must belong to one toolchain"
[ "$(canonical_directory "$(/usr/bin/dirname -- "$moonrun_bin")")" = "$moon_bin_dir" ] ||
  die "Moon compiler and runtime must belong to one toolchain"
moon_toolchain_root="$(canonical_directory "$moon_bin_dir/..")"
[ "$moon_bin" = "$moon_toolchain_root/bin/moon" ] &&
  [ "$moonc_bin" = "$moon_toolchain_root/bin/moonc" ] &&
  [ "$moonrun_bin" = "$moon_toolchain_root/bin/moonrun" ] ||
  die "Moon tools must use the canonical bin/moon, bin/moonc, and bin/moonrun paths"

script_dir="$(canonical_directory "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")")"
source_root="$(canonical_directory "$script_dir/../../../..")"
git_root="$(canonical_directory "$(trusted_git -C "$source_root" rev-parse --show-toplevel)")"
[ "$git_root" = "$source_root" ] ||
  die "fresh-agent harness is not rooted in the expected checkout"

actual_head="$(trusted_git -C "$source_root" rev-parse --verify HEAD)"
[ "$actual_head" = "$expected_head" ] ||
  die "candidate HEAD mismatch: expected $expected_head, found $actual_head"
[ "$(trusted_git -C "$source_root" rev-parse --verify "$expected_head^{commit}")" = "$expected_head" ] ||
  die "EXPECTED_FULL_HEAD does not resolve to the requested commit"
expected_tree="$(trusted_git -C "$source_root" rev-parse --verify "$expected_head^{tree}")"
case "$expected_tree" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) die "candidate source tree must be a lowercase 40-character object id" ;;
esac

if [ -n "$(trusted_git -C "$source_root" status --porcelain=v1 --untracked-files=all)" ]; then
  die "candidate checkout has tracked or untracked changes"
fi

inventory_script="$script_dir/inventory.sh"
build_lock="$script_dir/build-lock.json"
[ -f "$inventory_script" ] && [ ! -L "$inventory_script" ] &&
  [ -x "$inventory_script" ] ||
  die "tracked inventory helper must be an executable regular file"
[ -f "$build_lock" ] && [ ! -L "$build_lock" ] ||
  die "tracked build lock must be a regular file"
/usr/bin/jq -e '
  keys == ["dependencies", "schema", "toolchains"] and
  .schema == "office.fresh-agent.build-lock/1" and
  (.dependencies | keys) == ["entries", "manifest_sha256"] and
  (.dependencies.entries | type) == "array" and
  (.dependencies.entries | length) > 0 and
  (.dependencies.entries | all(type == "string" and length > 0)) and
  (.dependencies.entries | unique | length) ==
    (.dependencies.entries | length) and
  (.dependencies.manifest_sha256 | test("^[0-9a-f]{64}$")) and
  (.toolchains | type) == "array" and
  (.toolchains | length) > 0 and
  (.toolchains | map(.platform) | unique | length) ==
    (.toolchains | length) and
  (.toolchains | all(
    keys == ["entries", "manifest_sha256", "moon_version",
      "moonc_version", "moonrun_version", "platform"] and
    (.platform | type) == "string" and
    (.entries | type) == "array" and
    (.entries | length) > 0 and
    (.entries | all(type == "string" and length > 0)) and
    (.entries | unique | length) == (.entries | length) and
    (.manifest_sha256 | test("^[0-9a-f]{64}$")) and
    (.moon_version | type) == "string" and
    (.moonc_version | type) == "string" and
    (.moonrun_version | type) == "string"
  ))
' "$build_lock" >/dev/null || die "tracked build lock failed strict validation"

case "$(/usr/bin/uname -s) $(/usr/bin/uname -m)" in
  "Darwin arm64") build_platform=darwin-arm64 ;;
  "Linux x86_64") build_platform=linux-x86_64 ;;
  *) die "fresh candidate preparation has no pinned toolchain for this platform" ;;
esac
[ "$(/usr/bin/jq --arg platform "$build_platform" \
  '[.toolchains[] | select(.platform == $platform)] | length' "$build_lock")" = "1" ] ||
  die "build lock does not contain exactly one toolchain for $build_platform"
expected_toolchain_manifest_sha256="$(/usr/bin/jq -er \
  --arg platform "$build_platform" \
  '.toolchains[] | select(.platform == $platform) | .manifest_sha256' \
  "$build_lock")"
expected_moon_version="$(/usr/bin/jq -er \
  --arg platform "$build_platform" \
  '.toolchains[] | select(.platform == $platform) | .moon_version' \
  "$build_lock")"
expected_moonc_version="$(/usr/bin/jq -er \
  --arg platform "$build_platform" \
  '.toolchains[] | select(.platform == $platform) | .moonc_version' \
  "$build_lock")"
expected_moonrun_version="$(/usr/bin/jq -er \
  --arg platform "$build_platform" \
  '.toolchains[] | select(.platform == $platform) | .moonrun_version' \
  "$build_lock")"
expected_dependency_manifest_sha256="$(
  /usr/bin/jq -er '.dependencies.manifest_sha256' "$build_lock"
)"
toolchain_entries=()
while IFS= read -r entry; do
  toolchain_entries+=("$entry")
done < <(/usr/bin/jq -er \
  --arg platform "$build_platform" \
  '.toolchains[] | select(.platform == $platform) | .entries[]' \
  "$build_lock")
dependency_entries=()
while IFS= read -r entry; do
  dependency_entries+=("$entry")
done < <(/usr/bin/jq -er '.dependencies.entries[]' "$build_lock")
build_lock_sha256="$(sha256_file "$build_lock")"

git_common_dir="$(trusted_git -C "$source_root" rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$source_root/$git_common_dir" ;;
esac
git_common_dir="$(canonical_directory "$git_common_dir")"
[ ! -s "$git_common_dir/info/attributes" ] ||
  die "Git common-directory attributes must be empty for an exact source export"

reject_path_syntax "$install_input" "install prefix"
install_root="$(canonical_absent_path "$install_input")"
reject_overlap "$install_root" "install prefix" "$source_root" "source checkout"
reject_overlap "$install_root" "install prefix" "$git_common_dir" "Git common directory"

install_parent="$(canonical_directory "$(/usr/bin/dirname -- "$install_root")")"
install_parent_identity="$(stat_identity "$install_parent")"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-prepare.XXXXXX")"
stage="$(mktemp -d "$install_parent/.office-f1b-stage.XXXXXX")"
chmod 0700 "$scratch" "$stage"
assert_private_directory "$scratch"
assert_private_directory "$stage"
stage_identity="$(stat_identity "$stage")"
install_identity=""
published=0

cleanup() {
  local status="$1"
  trap - EXIT HUP INT TERM
  if [ -n "${stage:-}" ] && [ -d "$stage" ]; then
    chmod -R u+w -- "$stage" 2>/dev/null || true
    rm -rf -- "$stage"
  fi
  if [ -d "${scratch:-}" ]; then
    chmod -R u+w -- "$scratch" 2>/dev/null || true
    rm -rf -- "$scratch"
  fi
  if [ "${published:-0}" != "1" ] &&
    [ -n "${install_identity:-}" ] &&
    [ -d "${install_root:-}" ] &&
    [ "$(stat_identity "$install_root" 2>/dev/null || true)" = "$install_identity" ]; then
    chmod -R u+w -- "$install_root" 2>/dev/null || true
    rm -rf -- "$install_root"
  fi
  exit "$status"
}
trap 'cleanup $?' EXIT
trap 'cleanup 129' HUP
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

if ! mkdir -m 0700 "$install_root"; then
  die "could not atomically reserve absent install prefix: $install_root"
fi
install_identity="$(stat_identity "$install_root")"
assert_private_directory "$install_root"

snapshot="$scratch/source"
mkdir -m 0700 "$snapshot"
source_archive="$scratch/source.tar"
trusted_git -C "$source_root" archive --format=tar "$expected_tree" \
  > "$source_archive"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/tar -xf "$source_archive" -C "$snapshot"

snapshot_inventory="$snapshot/office/tests/acceptance/fresh-agent/inventory.sh"
snapshot_build_lock="$snapshot/office/tests/acceptance/fresh-agent/build-lock.json"
[ "$(sha256_file "$snapshot_inventory")" = "$(sha256_file "$inventory_script")" ] ||
  die "exported inventory helper differs from the exact checkout"
[ "$(sha256_file "$snapshot_build_lock")" = "$build_lock_sha256" ] ||
  die "exported build lock differs from the exact checkout"

approved_toolchain_root="$moon_toolchain_root"
source_toolchain_manifest="$scratch/source-toolchain.manifest"
"$snapshot_inventory" \
  "$approved_toolchain_root" \
  "$source_toolchain_manifest" \
  "$build_platform" \
  "${toolchain_entries[@]}"
[ "$(sha256_file "$source_toolchain_manifest")" = \
  "$expected_toolchain_manifest_sha256" ] ||
  die "complete Moon toolchain inventory does not match the tracked build lock"

toolchain_archive="$scratch/toolchain.tar"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/tar -C "$approved_toolchain_root" -cf "$toolchain_archive" \
    "${toolchain_entries[@]}"
moon_toolchain_root="$scratch/toolchain"
mkdir -m 0700 "$moon_toolchain_root"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/tar -xpf "$toolchain_archive" -C "$moon_toolchain_root"
staged_toolchain_manifest="$scratch/staged-toolchain.manifest"
"$snapshot_inventory" \
  "$moon_toolchain_root" \
  "$staged_toolchain_manifest" \
  "$build_platform" \
  "${toolchain_entries[@]}"
/usr/bin/cmp "$source_toolchain_manifest" "$staged_toolchain_manifest" ||
  {
    echo "error: staged toolchain inventory diff follows" >&2
    /usr/bin/diff -u "$source_toolchain_manifest" \
      "$staged_toolchain_manifest" |
      /usr/bin/sed -n '1,200p' >&2 || true
    die "privately staged Moon toolchain differs from the pinned source closure"
  }

moon_bin="$moon_toolchain_root/bin/moon"
moonc_bin="$moon_toolchain_root/bin/moonc"
moonrun_bin="$moon_toolchain_root/bin/moonrun"
for tool_path in "$moon_bin" "$moonc_bin" "$moonrun_bin"; do
  [ -f "$tool_path" ] && [ ! -L "$tool_path" ] && [ -x "$tool_path" ] ||
    die "staged Moon tool is not an executable regular file: $tool_path"
done

build_home="$scratch/home"
build_moon_home="$scratch/moon-home"
build_tmp="$scratch/tmp"
mkdir -m 0700 "$build_home" "$build_moon_home" "$build_tmp"

run_moon() {
  /usr/bin/env -i \
    HOME="$build_home" \
    MOON_HOME="$build_moon_home" \
    MOON_TOOLCHAIN_ROOT="$moon_toolchain_root" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    TMPDIR="$build_tmp" \
    LANG=C \
    LC_ALL=C \
    "$moon_bin" "$@"
}

toolchain_versions="$scratch/toolchain-versions.txt"
run_moon version --all > "$toolchain_versions"
[ "$(/usr/bin/awk 'NR == 1 { print $NF }' "$toolchain_versions")" = "$moon_bin" ] ||
  die "Moon driver resolved outside the approved toolchain closure"
[ "$(/usr/bin/awk 'NR == 2 { print $NF }' "$toolchain_versions")" = "$moonc_bin" ] ||
  die "Moon driver resolved an unapproved code generator"
[ "$(/usr/bin/awk 'NR == 3 { print $NF }' "$toolchain_versions")" = "$moonrun_bin" ] ||
  die "Moon driver resolved an unapproved runtime"
moon_version="$(/usr/bin/sed -n '1p' "$toolchain_versions")"
moonc_version="$(/usr/bin/sed -n '2p' "$toolchain_versions")"
moonrun_version="$(/usr/bin/sed -n '3p' "$toolchain_versions")"
[ "$(printf '%s\n' "$moon_version" | /usr/bin/awk \
  '{$NF=""; sub(/[[:space:]]+$/, ""); print}')" = "$expected_moon_version" ] ||
  die "Moon driver version does not match the tracked build lock"
[ "$(printf '%s\n' "$moonc_version" | /usr/bin/awk \
  '{$NF=""; sub(/[[:space:]]+$/, ""); print}')" = "$expected_moonc_version" ] ||
  die "Moon code-generator version does not match the tracked build lock"
[ "$(printf '%s\n' "$moonrun_version" | /usr/bin/awk \
  '{$NF=""; sub(/[[:space:]]+$/, ""); print}')" = "$expected_moonrun_version" ] ||
  die "Moon runtime version does not match the tracked build lock"
moon_version="$expected_moon_version"
moonc_version="$expected_moonc_version"
moonrun_version="$expected_moonrun_version"

resolve_log="$scratch/resolve.log"
if ! (
  cd "$snapshot"
  run_moon update
  run_moon install
) >"$resolve_log" 2>&1; then
  echo "error: pinned dependency resolution failed; complete log follows" >&2
  cat "$resolve_log" >&2
  exit 1
fi

dependency_manifest="$scratch/dependencies.manifest"
"$snapshot_inventory" \
  "$snapshot/.mooncakes" \
  "$dependency_manifest" \
  dependencies \
  "${dependency_entries[@]}"
[ "$(sha256_file "$dependency_manifest")" = \
  "$expected_dependency_manifest_sha256" ] ||
  die "resolved dependency inventory does not match the tracked build lock"

build_log="$scratch/build.log"
if ! (
  cd "$snapshot"
  run_moon build --frozen --release --target native office/cmd/office
  run_moon build --frozen --release --target wasm office/cmd/office
) >"$build_log" 2>&1; then
  echo "error: fresh release build failed; complete build log follows" >&2
  cat "$build_log" >&2
  exit 1
fi

native_artifact="$snapshot/_build/native/release/build/bobzhang/office/cmd/office/office.exe"
wasm_artifact="$snapshot/_build/wasm/release/build/bobzhang/office/cmd/office/office.wasm"
[ -x "$native_artifact" ] ||
  die "native release artifact was not built"
[ -f "$wasm_artifact" ] ||
  die "Wasm release artifact was not built"

postbuild_dependency_manifest="$scratch/postbuild-dependencies.manifest"
"$snapshot_inventory" \
  "$snapshot/.mooncakes" \
  "$postbuild_dependency_manifest" \
  dependencies \
  "${dependency_entries[@]}"
/usr/bin/cmp "$dependency_manifest" "$postbuild_dependency_manifest" ||
  die "dependency closure changed during frozen release builds"
postbuild_toolchain_manifest="$scratch/postbuild-toolchain.manifest"
"$snapshot_inventory" \
  "$moon_toolchain_root" \
  "$postbuild_toolchain_manifest" \
  "$build_platform" \
  "${toolchain_entries[@]}"
/usr/bin/cmp "$staged_toolchain_manifest" "$postbuild_toolchain_manifest" ||
  die "pinned Moon toolchain changed during frozen release builds"
mkdir -m 0700 "$stage/bin" "$stage/libexec" "$stage/control"
install -m 0500 "$native_artifact" "$stage/bin/office-native"
install -m 0500 \
  "$snapshot/office/tests/acceptance/fresh-agent/office-wasm" \
  "$stage/bin/office-wasm"
install -m 0500 "$moonrun_bin" "$stage/libexec/moonrun"
install -m 0400 "$wasm_artifact" "$stage/libexec/office.wasm"
install -m 0500 \
  "$snapshot/office/tests/acceptance/fresh-agent/run.sh" \
  "$stage/control/run.sh"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/prompt.md" \
  "$stage/control/prompt.md"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/final.schema.json" \
  "$stage/control/final.schema.json"
install -m 0500 \
  "$snapshot/office/tests/acceptance/fresh-agent/permission-canary.sh" \
  "$stage/control/permission-canary.sh"
install -m 0500 "$snapshot_inventory" "$stage/control/inventory.sh"
install -m 0400 "$snapshot_build_lock" "$stage/control/build-lock.json"
install -m 0400 "$source_toolchain_manifest" \
  "$stage/control/toolchain.manifest"
install -m 0400 "$dependency_manifest" \
  "$stage/control/dependencies.manifest"
ln -s office-native "$stage/bin/office"

jq -n \
  --arg schema "office.fresh-agent.private/1" \
  --arg source_root "$source_root" \
  --arg git_common_dir "$git_common_dir" \
  '{
    schema: $schema,
    source_root: $source_root,
    git_common_dir: $git_common_dir
  }' > "$scratch/private.json"
install -m 0400 "$scratch/private.json" "$stage/control/private.json"

native_sha256="$(sha256_file "$stage/bin/office-native")"
wasm_wrapper_sha256="$(sha256_file "$stage/bin/office-wasm")"
moonrun_sha256="$(sha256_file "$stage/libexec/moonrun")"
wasm_sha256="$(sha256_file "$stage/libexec/office.wasm")"
runner_sha256="$(sha256_file "$stage/control/run.sh")"
prompt_sha256="$(sha256_file "$stage/control/prompt.md")"
schema_sha256="$(sha256_file "$stage/control/final.schema.json")"
canary_sha256="$(sha256_file "$stage/control/permission-canary.sh")"
private_sha256="$(sha256_file "$stage/control/private.json")"
inventory_sha256="$(sha256_file "$stage/control/inventory.sh")"
installed_build_lock_sha256="$(sha256_file "$stage/control/build-lock.json")"
toolchain_manifest_sha256="$(sha256_file "$stage/control/toolchain.manifest")"
dependency_manifest_sha256="$(sha256_file "$stage/control/dependencies.manifest")"
moon_sha256="$(sha256_file "$moon_bin")"
moonc_sha256="$(sha256_file "$moonc_bin")"

jq -n \
  --arg schema "office.fresh-agent.candidate/3" \
  --arg candidate_head "$expected_head" \
  --arg source_tree "$expected_tree" \
  --arg build_platform "$build_platform" \
  --arg build_lock_sha256 "$installed_build_lock_sha256" \
  --arg toolchain_manifest_sha256 "$toolchain_manifest_sha256" \
  --arg dependency_manifest_sha256 "$dependency_manifest_sha256" \
  --arg moon_version "$moon_version" \
  --arg moon_sha256 "$moon_sha256" \
  --arg moonc_version "$moonc_version" \
  --arg moonc_sha256 "$moonc_sha256" \
  --arg moonrun_version "$moonrun_version" \
  --arg native_sha256 "$native_sha256" \
  --arg wasm_wrapper_sha256 "$wasm_wrapper_sha256" \
  --arg moonrun_sha256 "$moonrun_sha256" \
  --arg wasm_sha256 "$wasm_sha256" \
  --arg runner_sha256 "$runner_sha256" \
  --arg prompt_sha256 "$prompt_sha256" \
  --arg schema_sha256 "$schema_sha256" \
  --arg canary_sha256 "$canary_sha256" \
  --arg private_sha256 "$private_sha256" \
  --arg inventory_sha256 "$inventory_sha256" \
  '{
    schema: $schema,
    candidate_head: $candidate_head,
    build: {
      source_tree: $source_tree,
      platform: $build_platform,
      build_lock_sha256: $build_lock_sha256,
      toolchain_manifest_sha256: $toolchain_manifest_sha256,
      dependency_manifest_sha256: $dependency_manifest_sha256,
      moon_version: $moon_version,
      moon_sha256: $moon_sha256,
      moonc_version: $moonc_version,
      moonc_sha256: $moonc_sha256,
      moonrun_version: $moonrun_version
    },
    files: [
      {path: "bin/office-native", kind: "file", mode: "0500", sha256: $native_sha256},
      {path: "bin/office-wasm", kind: "file", mode: "0500", sha256: $wasm_wrapper_sha256},
      {path: "libexec/moonrun", kind: "file", mode: "0500", sha256: $moonrun_sha256},
      {path: "libexec/office.wasm", kind: "file", mode: "0400", sha256: $wasm_sha256},
      {path: "control/run.sh", kind: "file", mode: "0500", sha256: $runner_sha256},
      {path: "control/prompt.md", kind: "file", mode: "0400", sha256: $prompt_sha256},
      {path: "control/final.schema.json", kind: "file", mode: "0400", sha256: $schema_sha256},
      {path: "control/permission-canary.sh", kind: "file", mode: "0500", sha256: $canary_sha256},
      {path: "control/private.json", kind: "file", mode: "0400", sha256: $private_sha256},
      {path: "control/inventory.sh", kind: "file", mode: "0500", sha256: $inventory_sha256},
      {path: "control/build-lock.json", kind: "file", mode: "0400", sha256: $build_lock_sha256},
      {path: "control/toolchain.manifest", kind: "file", mode: "0400", sha256: $toolchain_manifest_sha256},
      {path: "control/dependencies.manifest", kind: "file", mode: "0400", sha256: $dependency_manifest_sha256}
    ],
    symlinks: [
      {path: "bin/office", target: "office-native"}
    ]
  }' > "$scratch/CANDIDATE.json"
install -m 0400 "$scratch/CANDIDATE.json" "$stage/CANDIDATE.json"

[ "$(trusted_git -C "$source_root" rev-parse --verify HEAD)" = "$expected_head" ] ||
  die "candidate HEAD changed during preparation"
[ "$(trusted_git -C "$source_root" rev-parse --verify "$expected_head^{tree}")" = "$expected_tree" ] ||
  die "candidate source tree changed during preparation"
if [ -n "$(trusted_git -C "$source_root" status --porcelain=v1 --untracked-files=all)" ]; then
  die "candidate checkout changed during preparation"
fi

final_source_toolchain_manifest="$scratch/final-source-toolchain.manifest"
"$snapshot_inventory" \
  "$approved_toolchain_root" \
  "$final_source_toolchain_manifest" \
  "$build_platform" \
  "${toolchain_entries[@]}"
/usr/bin/cmp "$source_toolchain_manifest" "$final_source_toolchain_manifest" ||
  die "approved Moon toolchain source changed during candidate preparation"
[ "$(stat_identity "$install_parent")" = "$install_parent_identity" ] ||
  die "install parent identity changed during candidate preparation"
[ "$(stat_identity "$install_root")" = "$install_identity" ] ||
  die "reserved install prefix identity changed during candidate preparation"
[ "$(stat_identity "$stage")" = "$stage_identity" ] ||
  die "candidate staging identity changed during preparation"

# The destination is reserved before the build. Publish each fixed subtree with
# no-clobber moves, lock directory modes, then publish CANDIDATE.json last as
# the atomic commit marker. A runner treats a prefix without that marker as
# incomplete.
for subtree in bin libexec control; do
  [ ! -e "$install_root/$subtree" ] && [ ! -L "$install_root/$subtree" ] ||
    die "reserved install prefix was populated concurrently: $subtree"
  mv -n -- "$stage/$subtree" "$install_root/$subtree"
  [ ! -e "$stage/$subtree" ] && [ -d "$install_root/$subtree" ] ||
    die "could not publish candidate subtree without clobbering: $subtree"
  # macOS requires owner-write access on a directory while its parent entry is
  # renamed. Lock each directory immediately after the no-clobber move.
  chmod 0500 "$install_root/$subtree"
done
[ ! -e "$install_root/CANDIDATE.json" ] &&
  [ ! -L "$install_root/CANDIDATE.json" ] ||
  die "candidate commit marker already exists"
ln "$stage/CANDIDATE.json" "$install_root/CANDIDATE.json" ||
  die "could not atomically publish candidate commit marker"
rm -f -- "$stage/CANDIDATE.json"
chmod 0500 "$install_root"
[ "$(stat_identity "$install_root")" = "$install_identity" ] ||
  die "reserved install prefix identity changed during publication"
[ "$(sha256_file "$install_root/CANDIDATE.json")" = "$(sha256_file "$scratch/CANDIDATE.json")" ] ||
  die "published candidate commit marker hash mismatch"
published=1
trap - EXIT HUP INT TERM
chmod -R u+w -- "$stage" 2>/dev/null || true
rm -rf -- "$stage"
stage=""
chmod -R u+w -- "$scratch" 2>/dev/null || true
rm -rf -- "$scratch"
scratch=""

printf 'installed_prefix=%s\n' "$install_root"
cat "$install_root/CANDIDATE.json"

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
unset AR AS CC CFLAGS CPPFLAGS CXX CXXFLAGS LD LDFLAGS
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH
unset COMPILER_PATH GCC_EXEC_PREFIX LIBRARY_PATH
unset DEVELOPER_DIR MACOSX_DEPLOYMENT_TARGET SDKROOT TOOLCHAINS
unset TMPDIR

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

canonical_existing_path() {
  local input="$1"
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    /usr/bin/perl -MCwd=realpath -e '
      use strict;
      use warnings;
      my $resolved = realpath($ARGV[0]);
      defined $resolved or exit 1;
      $resolved !~ /[\t\r\n]/ or exit 1;
      print "$resolved\n";
    ' "$input" || die "could not resolve build-host path: $input"
}

add_host_inventory_path() {
  local input="$1"
  local resolved
  local selected
  local relative
  local existing
  local -a retained=()
  case "$input" in
    /*) ;;
    *) die "build-host inventory path must be absolute: $input" ;;
  esac
  case "$input" in
    / | */ | *//* | */./* | */. | */../* | */.. | *$'\t'* | *$'\r'* | *$'\n'*)
      die "build-host inventory path is not canonical: $input"
      ;;
  esac
  [ -e "$input" ] || [ -L "$input" ] ||
    die "build-host inventory path does not exist: $input"
  selected="$input"
  resolved="$(canonical_existing_path "$input")"
  if [ "$host_inventory_root" = / ]; then
    case "$resolved" in
      /*) relative="${selected#/}" ;;
      *) die "build-host inventory path escapes its root: $resolved" ;;
    esac
  else
    case "$resolved/" in
      "$host_inventory_root/"*) ;;
      *) die "build-host inventory path escapes its root: $resolved" ;;
    esac
    case "$selected/" in
      "$host_inventory_root/"*) relative="${selected#"$host_inventory_root/"}" ;;
      *) relative="${resolved#"$host_inventory_root/"}" ;;
    esac
  fi
  [ -n "$relative" ] ||
    die "build-host inventory must select a strict descendant"
  if (( ${#host_inventory_entries[@]} > 0 )); then
    for existing in "${host_inventory_entries[@]}"; do
      if [ "$relative" = "$existing" ]; then
        return 0
      fi
      case "$relative/" in
        "$existing/"*) return 0 ;;
      esac
      case "$existing/" in
        "$relative/"*) continue ;;
      esac
      retained+=("$existing")
    done
  fi
  retained+=("$relative")
  host_inventory_entries=("${retained[@]}")
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

require_clean_checkout() {
  local status_output
  if ! status_output="$(
    trusted_git -C "$source_root" status --porcelain=v1 --untracked-files=all
  )"; then
    die "could not inspect candidate checkout status"
  fi
  [ -z "$status_output" ] ||
    die "candidate checkout has tracked or untracked changes"
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

for tool in git jq shasum awk sed find sort tar cmp diff install mktemp stat id basename dirname mv ln env perl python3 uname; do
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

require_clean_checkout

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
  (.dependencies | keys) == ["entries"] and
  (.dependencies.entries | type) == "array" and
  (.dependencies.entries | length) > 0 and
  (.dependencies.entries | all(type == "string" and length > 0)) and
  (.dependencies.entries | unique | length) ==
    (.dependencies.entries | length) and
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
scratch="$(mktemp -d "$install_parent/.office-f1b-prepare.XXXXXX")"
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
actual_toolchain_manifest_sha256="$(sha256_file "$source_toolchain_manifest")"
[ "$actual_toolchain_manifest_sha256" = \
  "$expected_toolchain_manifest_sha256" ] ||
  die "complete Moon toolchain inventory does not match the tracked build lock: expected $expected_toolchain_manifest_sha256, found $actual_toolchain_manifest_sha256"

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
  --root-alias "$approved_toolchain_root" \
  "${toolchain_entries[@]}"
/usr/bin/cmp "$source_toolchain_manifest" "$staged_toolchain_manifest" ||
  {
    echo "error: staged toolchain inventory diff follows" >&2
    /usr/bin/diff -u "$source_toolchain_manifest" \
      "$staged_toolchain_manifest" |
      /usr/bin/sed -n '1,200p' >&2 || true
    die "privately staged Moon toolchain differs from the pinned source closure"
  }

for target in js llvm native wasm-gc wasm; do
  generated_bundle_db="$moon_toolchain_root/lib/core/_build/$target/release/bundle/bundle.moon_db"
  [ -f "$generated_bundle_db" ] && [ ! -L "$generated_bundle_db" ] ||
    die "expected generated Moon bundle database is unavailable: $target"
  /bin/rm -f -- "$generated_bundle_db"
  [ ! -e "$generated_bundle_db" ] && [ ! -L "$generated_bundle_db" ] ||
    die "could not reset generated Moon bundle database: $target"
done

moon_bin="$moon_toolchain_root/bin/moon"
moonc_bin="$moon_toolchain_root/bin/moonc"
moonrun_bin="$moon_toolchain_root/bin/moonrun"
for tool_path in "$moon_bin" "$moonc_bin" "$moonrun_bin"; do
  [ -f "$tool_path" ] && [ ! -L "$tool_path" ] && [ -x "$tool_path" ] ||
    die "staged Moon tool is not an executable regular file: $tool_path"
done

build_sdkroot=""
build_sdkroot_argument=-
case "$build_platform" in
  darwin-arm64)
    for tool in xcrun xcode-select sw_vers; do
      require_command "$tool"
    done
    build_cc="$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=C LC_ALL=C \
      /usr/bin/xcrun --sdk macosx --find clang)"
    build_ar="$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=C LC_ALL=C \
      /usr/bin/xcrun --sdk macosx --find ar)"
    build_sdkroot="$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=C LC_ALL=C \
      /usr/bin/xcrun --sdk macosx --show-sdk-path)"
    build_sdkroot_argument="$build_sdkroot"
    build_sdk_kind="macos-sdk"
    build_sdk_version="$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=C LC_ALL=C \
      /usr/bin/xcrun --sdk macosx --show-sdk-version)"
    host_inventory_root=/
    host_identity_path="$(canonical_existing_path \
      /System/Library/CoreServices/SystemVersion.plist)"
    ;;
  linux-x86_64)
    build_cc=/usr/bin/cc
    build_ar=/usr/bin/ar
    build_sdk_kind="linux-sysroot"
    host_inventory_root=/
    host_identity_path="$(canonical_existing_path /etc/os-release)"
    ;;
  *) die "no native build-host policy is registered for $build_platform" ;;
esac

build_host_discovery_policy="$snapshot/office/tests/acceptance/fresh-agent/build_host_discovery.py"
[ -f "$build_host_discovery_policy" ] && [ ! -L "$build_host_discovery_policy" ] ||
  die "build-host discovery policy is unavailable from the exported snapshot"
build_host_discovery_json="$scratch/build-host-discovery.json"
build_host_discovery_paths="$scratch/build-host-discovery.paths"
if ! /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$build_host_discovery_policy" \
  "$build_platform" "$build_cc" "$build_ar" "$build_sdkroot_argument" \
  "$build_host_discovery_json" "$build_host_discovery_paths"; then
  die "could not discover the native build-host closure"
fi
/usr/bin/jq -e --arg platform "$build_platform" '
  keys == ["compiler_queries", "environment", "inventory_paths", "loader",
    "platform", "schema", "sdk", "tools"] and
  .schema == "office.fresh-agent.build-host-discovery/1" and
  .platform == $platform and
  (.tools | keys) == ["archiver", "assembler", "compiler", "linker"] and
  (.inventory_paths | type) == "array" and
  (.inventory_paths | length) > 0 and
  (.inventory_paths | all(type == "string" and startswith("/"))) and
  (.inventory_paths | unique | length) == (.inventory_paths | length)
' "$build_host_discovery_json" >/dev/null ||
  die "native build-host discovery failed strict validation"
build_host_discovery_sha256="$(sha256_file "$build_host_discovery_json")"
build_cc="$(/usr/bin/jq -er '.tools.compiler.selected_path' "$build_host_discovery_json")"
build_cc_resolved="$(/usr/bin/jq -er '.tools.compiler.resolved_path' "$build_host_discovery_json")"
build_cc_sha256="$(/usr/bin/jq -er '.tools.compiler.sha256' "$build_host_discovery_json")"
build_cc_version="$(/usr/bin/jq -r '.tools.compiler.version[]' "$build_host_discovery_json")"
build_cc_target="$(/usr/bin/jq -er '.compiler_queries.target' "$build_host_discovery_json")"
build_cc_resource_dir="$(/usr/bin/jq -er '.compiler_queries.resource_directory.selected_path' "$build_host_discovery_json")"
build_cc_resource_dir_resolved="$(/usr/bin/jq -er '.compiler_queries.resource_directory.resolved_path' "$build_host_discovery_json")"
build_ar="$(/usr/bin/jq -er '.tools.archiver.selected_path' "$build_host_discovery_json")"
build_ar_resolved="$(/usr/bin/jq -er '.tools.archiver.resolved_path' "$build_host_discovery_json")"
build_ar_sha256="$(/usr/bin/jq -er '.tools.archiver.sha256' "$build_host_discovery_json")"
build_linker="$(/usr/bin/jq -er '.tools.linker.selected_path' "$build_host_discovery_json")"
build_linker_resolved="$(/usr/bin/jq -er '.tools.linker.resolved_path' "$build_host_discovery_json")"
build_linker_sha256="$(/usr/bin/jq -er '.tools.linker.sha256' "$build_host_discovery_json")"
build_linker_version="$(/usr/bin/jq -r '.tools.linker.version[]' "$build_host_discovery_json")"
build_assembler="$(/usr/bin/jq -er '.tools.assembler.selected_path' "$build_host_discovery_json")"
build_assembler_resolved="$(/usr/bin/jq -er '.tools.assembler.resolved_path' "$build_host_discovery_json")"
build_assembler_sha256="$(/usr/bin/jq -er '.tools.assembler.sha256' "$build_host_discovery_json")"
build_sdkroot="$(/usr/bin/jq -er '.sdk.selected_path' "$build_host_discovery_json")"
build_sdkroot_resolved="$(/usr/bin/jq -er '.sdk.resolved_path' "$build_host_discovery_json")"
if [ "$build_platform" = linux-x86_64 ]; then
  build_sdk_version="$build_cc_target"
fi
host_identity_sha256="$(sha256_file "$host_identity_path")"
host_kernel="$(/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/uname -a)"

host_inventory_entries=()
add_host_inventory_path "$host_identity_path"
while IFS= read -r discovered_host_path; do
  [ -n "$discovered_host_path" ] || continue
  [ "$discovered_host_path" = / ] || add_host_inventory_path "$discovered_host_path"
done < "$build_host_discovery_paths"
if [ "$build_platform" = linux-x86_64 ]; then
  add_host_inventory_path /usr/include
  [ ! -d /usr/local/include ] || add_host_inventory_path /usr/local/include
  [ ! -d "/usr/include/$build_cc_target" ] ||
    add_host_inventory_path "/usr/include/$build_cc_target"
fi

sorted_host_inventory_entries=()
while IFS= read -r host_inventory_entry; do
  sorted_host_inventory_entries+=("$host_inventory_entry")
done < <(
  printf '%s\n' "${host_inventory_entries[@]}" | LC_ALL=C /usr/bin/sort
)
host_inventory_entries=("${sorted_host_inventory_entries[@]}")
build_host_manifest="$scratch/build-host.manifest"
"$snapshot_inventory" \
  "$host_inventory_root" \
  "$build_host_manifest" \
  build-host \
  "${host_inventory_entries[@]}"
build_host_manifest_sha256="$(sha256_file "$build_host_manifest")"

build_home="$scratch/home"
build_moon_home="$scratch/moon-home"
build_tmp="$scratch/tmp"
mkdir -m 0700 "$build_home" "$build_moon_home" "$build_tmp"

run_moon() {
  local -a build_environment=(
    HOME="$build_home"
    MOON_HOME="$build_moon_home"
    MOON_TOOLCHAIN_ROOT="$moon_toolchain_root"
    MOON_CC="$build_cc"
    MOON_AR="$build_ar"
    PATH=/usr/bin:/bin:/usr/sbin:/sbin
    TMPDIR="$build_tmp"
    LANG=C
    LC_ALL=C
  )
  if [ -n "$build_sdkroot" ] && [ "$build_platform" = "darwin-arm64" ]; then
    build_environment+=(SDKROOT="$build_sdkroot")
  fi
  /usr/bin/env -i \
    "${build_environment[@]}" \
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

bundle_log="$scratch/bundle.log"
if ! (
  run_moon -C "$moon_toolchain_root/lib/core" \
    bundle --warn-list -a --all
  run_moon -C "$moon_toolchain_root/lib/core" \
    bundle --warn-list -a --target llvm
  run_moon -C "$moon_toolchain_root/lib/core" \
    bundle --warn-list -a --target wasm-gc --quiet
) >"$bundle_log" 2>&1; then
  echo "error: trusted core bundle regeneration failed; complete log follows" >&2
  cat "$bundle_log" >&2
  exit 1
fi
for target in js llvm native wasm-gc wasm; do
  generated_bundle_db="$moon_toolchain_root/lib/core/_build/$target/release/bundle/bundle.moon_db"
  [ -f "$generated_bundle_db" ] && [ ! -L "$generated_bundle_db" ] ||
    die "trusted core bundle regeneration omitted a database: $target"
  chmod 0644 "$generated_bundle_db"
done
regenerated_toolchain_manifest="$scratch/regenerated-toolchain.manifest"
"$snapshot_inventory" \
  "$moon_toolchain_root" \
  "$regenerated_toolchain_manifest" \
  "$build_platform" \
  --root-alias "$approved_toolchain_root" \
  "${toolchain_entries[@]}"
/usr/bin/cmp "$staged_toolchain_manifest" "$regenerated_toolchain_manifest" ||
  {
    echo "error: regenerated toolchain inventory diff follows" >&2
    /usr/bin/diff -u "$staged_toolchain_manifest" \
      "$regenerated_toolchain_manifest" |
      /usr/bin/sed -n '1,200p' >&2 || true
    die "trusted core bundle regeneration changed the pinned toolchain closure"
  }

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

native_plan_raw="$scratch/native-build-plan.raw"
native_plan="$scratch/native-build-plan.txt"
if ! (
  cd "$snapshot"
  run_moon build --frozen --release --target native --dry-run -v \
    office-cli
) >"$native_plan_raw" 2>&1; then
  echo "error: native build planning failed; complete log follows" >&2
  cat "$native_plan_raw" >&2
  exit 1
fi
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/perl - "$native_plan_raw" "$native_plan" \
    "$snapshot" "$moon_toolchain_root" "$build_home" "$build_moon_home" \
    "$build_tmp" "$scratch" <<'PERL'
use strict;
use warnings;

my ($input, $output, @roots) = @ARGV;
my @markers = (
  '${SOURCE_ROOT}',
  '${MOON_TOOLCHAIN_ROOT}',
  '${BUILD_HOME}',
  '${BUILD_MOON_HOME}',
  '${BUILD_TMP}',
  '${PREPARE_ROOT}',
);
open my $input_handle, '<', $input or die "could not read native plan\n";
local $/;
my $plan = <$input_handle>;
close $input_handle or die "could not close native plan input\n";
for my $index (sort { length($roots[$b]) <=> length($roots[$a]) } 0 .. $#roots) {
  $plan =~ s/\Q$roots[$index]\E/$markers[$index]/g;
}
$plan = join("\n", grep { length $_ } split /\n/, $plan) . "\n";
open my $output_handle, '>', $output or die "could not write native plan\n";
print {$output_handle} $plan;
close $output_handle or die "could not close native plan output\n";
PERL
[ -s "$native_plan" ] || die "normalized native build plan is empty"
/usr/bin/grep -F -- "$build_cc " "$native_plan" >/dev/null ||
  die "native build plan does not use the explicitly selected C compiler"
/usr/bin/grep -F -- "$build_ar " "$native_plan" >/dev/null ||
  die "native build plan does not use the explicitly selected archive tool"
native_plan_sha256="$(sha256_file "$native_plan")"
host_inventory_entries_json="$(
  printf '%s\n' "${host_inventory_entries[@]}" |
    /usr/bin/jq -Rsc 'split("\n") | map(select(length > 0))'
)"
build_sdkroot_environment=""
if [ "$build_platform" = darwin-arm64 ]; then
  build_sdkroot_environment="$build_sdkroot"
fi
build_host_json="$scratch/build-host.json"
/usr/bin/jq -n \
  --arg schema "office.fresh-agent.build-host/2" \
  --arg platform "$build_platform" \
  --arg discovery_sha256 "$build_host_discovery_sha256" \
  --arg moon_cc "$build_cc" \
  --arg moon_ar "$build_ar" \
  --arg sdkroot "$build_sdkroot_environment" \
  --arg kernel "$host_kernel" \
  --arg identity_path "$host_identity_path" \
  --arg identity_sha256 "$host_identity_sha256" \
  --arg cc_resolved "$build_cc_resolved" \
  --arg cc_sha256 "$build_cc_sha256" \
  --arg cc_version "$build_cc_version" \
  --arg cc_target "$build_cc_target" \
  --arg cc_resource_dir "$build_cc_resource_dir" \
  --arg cc_resource_dir_resolved "$build_cc_resource_dir_resolved" \
  --arg ar_resolved "$build_ar_resolved" \
  --arg ar_sha256 "$build_ar_sha256" \
  --arg linker_selected "$build_linker" \
  --arg linker_resolved "$build_linker_resolved" \
  --arg linker_sha256 "$build_linker_sha256" \
  --arg linker_version "$build_linker_version" \
  --arg assembler_selected "$build_assembler" \
  --arg assembler_resolved "$build_assembler_resolved" \
  --arg assembler_sha256 "$build_assembler_sha256" \
  --arg sdk_kind "$build_sdk_kind" \
  --arg sdk_path "$build_sdkroot" \
  --arg sdk_resolved "$build_sdkroot_resolved" \
  --arg sdk_version "$build_sdk_version" \
  --arg inventory_root "$host_inventory_root" \
  --arg inventory_sha256 "$build_host_manifest_sha256" \
  --arg native_plan_sha256 "$native_plan_sha256" \
  --argjson inventory_entries "$host_inventory_entries_json" \
  --rawfile native_plan "$native_plan" \
  '{
    schema: $schema,
    platform: $platform,
    discovery: {
      schema: "office.fresh-agent.build-host-discovery/1",
      sha256: $discovery_sha256
    },
    environment: {
      moon_cc: $moon_cc,
      moon_ar: $moon_ar,
      sdkroot: (if $sdkroot == "" then null else $sdkroot end)
    },
    host: {
      kernel: $kernel,
      identity_path: $identity_path,
      identity_sha256: $identity_sha256
    },
    compiler: {
      selected_path: $moon_cc,
      resolved_path: $cc_resolved,
      sha256: $cc_sha256,
      version: $cc_version,
      target: $cc_target,
      resource_dir: {
        selected_path: $cc_resource_dir,
        resolved_path: $cc_resource_dir_resolved
      }
    },
    archiver: {
      selected_path: $moon_ar,
      resolved_path: $ar_resolved,
      sha256: $ar_sha256
    },
    linker: {
      selected_path: $linker_selected,
      resolved_path: $linker_resolved,
      sha256: $linker_sha256,
      version: $linker_version
    },
    assembler: {
      selected_path: $assembler_selected,
      resolved_path: $assembler_resolved,
      sha256: $assembler_sha256
    },
    sdk: {
      kind: $sdk_kind,
      selected_path: $sdk_path,
      resolved_path: $sdk_resolved,
      version: $sdk_version
    },
    inventory: {
      root: $inventory_root,
      entries: $inventory_entries,
      manifest_sha256: $inventory_sha256
    },
    native_plan: {
      sha256: $native_plan_sha256,
      commands: ($native_plan | split("\n") | map(select(length > 0)))
    }
  }' > "$build_host_json"

build_log="$scratch/build.log"
if ! (
  cd "$snapshot"
  run_moon build --frozen --release --target native office-cli
  run_moon build --frozen --release --target wasm office-cli
) >"$build_log" 2>&1; then
  echo "error: fresh release build failed; complete build log follows" >&2
  cat "$build_log" >&2
  exit 1
fi

native_artifact="$snapshot/_build/native/release/build/bobzhang/office/office.exe"
wasm_artifact="$snapshot/_build/wasm/release/build/bobzhang/office/office.wasm"
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
  --root-alias "$approved_toolchain_root" \
  "${toolchain_entries[@]}"
/usr/bin/cmp "$staged_toolchain_manifest" "$postbuild_toolchain_manifest" ||
  {
    echo "error: post-build toolchain inventory diff follows" >&2
    /usr/bin/diff -u "$staged_toolchain_manifest" \
      "$postbuild_toolchain_manifest" |
      /usr/bin/sed -n '1,200p' >&2 || true
    die "pinned Moon toolchain changed during frozen release builds"
  }
postbuild_host_manifest="$scratch/postbuild-host.manifest"
"$snapshot_inventory" \
  "$host_inventory_root" \
  "$postbuild_host_manifest" \
  build-host \
  "${host_inventory_entries[@]}"
/usr/bin/cmp "$build_host_manifest" "$postbuild_host_manifest" ||
  die "native build-host closure changed during frozen release builds"
postbuild_discovery_cc="$build_cc"
postbuild_discovery_ar="$build_ar"
postbuild_discovery_sdk_argument=-
postbuild_sdk_version="$build_sdk_version"
if [ "$build_platform" = darwin-arm64 ]; then
  postbuild_discovery_cc="$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=C LC_ALL=C \
    /usr/bin/xcrun --sdk macosx --find clang)"
  postbuild_discovery_ar="$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=C LC_ALL=C \
    /usr/bin/xcrun --sdk macosx --find ar)"
  postbuild_discovery_sdk_argument="$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=C LC_ALL=C \
    /usr/bin/xcrun --sdk macosx --show-sdk-path)"
  postbuild_sdk_version="$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=C LC_ALL=C \
    /usr/bin/xcrun --sdk macosx --show-sdk-version)"
fi
[ "$postbuild_discovery_cc" = "$build_cc" ] &&
  [ "$postbuild_discovery_ar" = "$build_ar" ] &&
  { [ "$build_platform" = linux-x86_64 ] ||
    [ "$postbuild_discovery_sdk_argument" = "$build_sdkroot" ]; } &&
  [ "$postbuild_sdk_version" = "$build_sdk_version" ] ||
  die "native build-host selector changed during the build"
postbuild_discovery_json="$scratch/postbuild-host-discovery.json"
postbuild_discovery_paths="$scratch/postbuild-host-discovery.paths"
if ! /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$build_host_discovery_policy" \
  "$build_platform" "$postbuild_discovery_cc" "$postbuild_discovery_ar" \
  "$postbuild_discovery_sdk_argument" \
  "$postbuild_discovery_json" "$postbuild_discovery_paths"; then
  die "could not rediscover the native build-host closure after the build"
fi
/usr/bin/cmp "$build_host_discovery_json" "$postbuild_discovery_json" ||
  die "native build-host selections or loaded dependencies changed during the build"
/usr/bin/cmp "$build_host_discovery_paths" "$postbuild_discovery_paths" ||
  die "native build-host inventory roots changed during the build"
[ "$(/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/uname -a)" = \
  "$host_kernel" ] &&
  [ "$(sha256_file "$host_identity_path")" = "$host_identity_sha256" ] ||
  die "native build-host OS identity changed during the build"
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
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/attest.py" \
  "$stage/control/attest.py"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/argument_policy.py" \
  "$stage/control/argument-policy.py"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/auth_guard.py" \
  "$stage/control/auth-guard.py"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/command_policy.py" \
  "$stage/control/command-policy.py"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/opc_policy.py" \
  "$stage/control/opc-policy.py"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/transcript_policy.py" \
  "$stage/control/transcript-policy.py"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/scenario_policy.py" \
  "$stage/control/scenario-policy.py"
install -m 0400 \
  "$snapshot/office/tests/acceptance/fresh-agent/evidence_policy.py" \
  "$stage/control/evidence-policy.py"
install -m 0500 "$snapshot_inventory" "$stage/control/inventory.sh"
install -m 0400 "$snapshot_build_lock" "$stage/control/build-lock.json"
install -m 0400 "$source_toolchain_manifest" \
  "$stage/control/toolchain.manifest"
install -m 0400 "$dependency_manifest" \
  "$stage/control/dependencies.manifest"
install -m 0400 "$build_host_json" "$stage/control/build-host.json"
install -m 0400 "$build_host_manifest" \
  "$stage/control/build-host.manifest"
install -m 0400 "$build_host_discovery_policy" \
  "$stage/control/build-host-discovery.py"
install -m 0400 "$build_host_discovery_json" \
  "$stage/control/build-host-discovery.json"
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
attest_sha256="$(sha256_file "$stage/control/attest.py")"
argument_policy_sha256="$(sha256_file "$stage/control/argument-policy.py")"
auth_guard_sha256="$(sha256_file "$stage/control/auth-guard.py")"
command_policy_sha256="$(sha256_file "$stage/control/command-policy.py")"
opc_policy_sha256="$(sha256_file "$stage/control/opc-policy.py")"
transcript_policy_sha256="$(sha256_file "$stage/control/transcript-policy.py")"
scenario_policy_sha256="$(sha256_file "$stage/control/scenario-policy.py")"
evidence_policy_sha256="$(sha256_file "$stage/control/evidence-policy.py")"
private_sha256="$(sha256_file "$stage/control/private.json")"
inventory_sha256="$(sha256_file "$stage/control/inventory.sh")"
installed_build_lock_sha256="$(sha256_file "$stage/control/build-lock.json")"
toolchain_manifest_sha256="$(sha256_file "$stage/control/toolchain.manifest")"
dependency_manifest_sha256="$(sha256_file "$stage/control/dependencies.manifest")"
installed_build_host_sha256="$(sha256_file "$stage/control/build-host.json")"
installed_build_host_manifest_sha256="$(
  sha256_file "$stage/control/build-host.manifest"
)"
build_host_discovery_policy_sha256="$(
  sha256_file "$stage/control/build-host-discovery.py"
)"
installed_build_host_discovery_sha256="$(
  sha256_file "$stage/control/build-host-discovery.json"
)"
moon_sha256="$(sha256_file "$moon_bin")"
moonc_sha256="$(sha256_file "$moonc_bin")"

jq -n \
  --arg schema "office.fresh-agent.candidate/5" \
  --arg candidate_head "$expected_head" \
  --arg source_tree "$expected_tree" \
  --arg build_platform "$build_platform" \
  --arg build_lock_sha256 "$installed_build_lock_sha256" \
  --arg toolchain_manifest_sha256 "$toolchain_manifest_sha256" \
  --arg dependency_manifest_sha256 "$dependency_manifest_sha256" \
  --arg build_host_sha256 "$installed_build_host_sha256" \
  --arg build_host_manifest_sha256 "$installed_build_host_manifest_sha256" \
  --arg build_host_discovery_policy_sha256 "$build_host_discovery_policy_sha256" \
  --arg build_host_discovery_sha256 "$installed_build_host_discovery_sha256" \
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
  --arg attest_sha256 "$attest_sha256" \
  --arg argument_policy_sha256 "$argument_policy_sha256" \
  --arg auth_guard_sha256 "$auth_guard_sha256" \
  --arg command_policy_sha256 "$command_policy_sha256" \
  --arg opc_policy_sha256 "$opc_policy_sha256" \
  --arg transcript_policy_sha256 "$transcript_policy_sha256" \
  --arg scenario_policy_sha256 "$scenario_policy_sha256" \
  --arg evidence_policy_sha256 "$evidence_policy_sha256" \
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
      build_host_sha256: $build_host_sha256,
      build_host_manifest_sha256: $build_host_manifest_sha256,
      build_host_discovery_policy_sha256: $build_host_discovery_policy_sha256,
      build_host_discovery_sha256: $build_host_discovery_sha256,
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
      {path: "control/attest.py", kind: "file", mode: "0400", sha256: $attest_sha256},
      {path: "control/argument-policy.py", kind: "file", mode: "0400", sha256: $argument_policy_sha256},
      {path: "control/auth-guard.py", kind: "file", mode: "0400", sha256: $auth_guard_sha256},
      {path: "control/command-policy.py", kind: "file", mode: "0400", sha256: $command_policy_sha256},
      {path: "control/opc-policy.py", kind: "file", mode: "0400", sha256: $opc_policy_sha256},
      {path: "control/transcript-policy.py", kind: "file", mode: "0400", sha256: $transcript_policy_sha256},
      {path: "control/scenario-policy.py", kind: "file", mode: "0400", sha256: $scenario_policy_sha256},
      {path: "control/evidence-policy.py", kind: "file", mode: "0400", sha256: $evidence_policy_sha256},
      {path: "control/private.json", kind: "file", mode: "0400", sha256: $private_sha256},
      {path: "control/inventory.sh", kind: "file", mode: "0500", sha256: $inventory_sha256},
      {path: "control/build-lock.json", kind: "file", mode: "0400", sha256: $build_lock_sha256},
      {path: "control/toolchain.manifest", kind: "file", mode: "0400", sha256: $toolchain_manifest_sha256},
      {path: "control/dependencies.manifest", kind: "file", mode: "0400", sha256: $dependency_manifest_sha256},
      {path: "control/build-host.json", kind: "file", mode: "0400", sha256: $build_host_sha256},
      {path: "control/build-host.manifest", kind: "file", mode: "0400", sha256: $build_host_manifest_sha256},
      {path: "control/build-host-discovery.py", kind: "file", mode: "0400", sha256: $build_host_discovery_policy_sha256},
      {path: "control/build-host-discovery.json", kind: "file", mode: "0400", sha256: $build_host_discovery_sha256}
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
require_clean_checkout

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

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
unset GIT_CONFIG_SYSTEM GIT_CEILING_DIRECTORIES NODE_OPTIONS
unset DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH LD_PRELOAD LD_LIBRARY_PATH
TMPDIR=/tmp
export TMPDIR

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 EXPECTED_FULL_HEAD ABSENT_INSTALL_PREFIX MOON_BIN MOON_SHA256 MOONRUN_BIN MOONRUN_SHA256" >&2
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

[ "$#" -eq 6 ] || usage
expected_head="$1"
install_input="$2"
moon_input="$3"
expected_moon_sha256="$4"
moonrun_input="$5"
expected_moonrun_sha256="$6"

case "$expected_head" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) die "EXPECTED_FULL_HEAD must be a lowercase 40-character commit id" ;;
esac

for tool in git jq shasum awk find sort tar cmp install mktemp stat id basename dirname mv ln; do
  require_command "$tool"
done

case "$expected_moon_sha256:$expected_moonrun_sha256" in
  *[!0-9a-f:]* | *:*:* | :* | *:) die "Moon tool hashes must be lowercase SHA-256 values" ;;
esac
[ "${#expected_moon_sha256}" -eq 64 ] &&
  [ "${#expected_moonrun_sha256}" -eq 64 ] ||
  die "Moon tool hashes must be lowercase 64-character SHA-256 values"

moon_bin="$(canonical_regular_file "$moon_input" "Moon compiler")"
moonrun_bin="$(canonical_regular_file "$moonrun_input" "Moon runtime")"
[ "$(sha256_file "$moon_bin")" = "$expected_moon_sha256" ] ||
  die "Moon compiler hash does not match the caller-supplied digest"
[ "$(sha256_file "$moonrun_bin")" = "$expected_moonrun_sha256" ] ||
  die "Moon runtime hash does not match the caller-supplied digest"

script_dir="$(canonical_directory "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")")"
source_root="$(canonical_directory "$script_dir/../../../..")"
git_root="$(canonical_directory "$(git -C "$source_root" rev-parse --show-toplevel)")"
[ "$git_root" = "$source_root" ] ||
  die "fresh-agent harness is not rooted in the expected checkout"

actual_head="$(git -C "$source_root" rev-parse --verify HEAD)"
[ "$actual_head" = "$expected_head" ] ||
  die "candidate HEAD mismatch: expected $expected_head, found $actual_head"
[ "$(git -C "$source_root" rev-parse --verify "$expected_head^{commit}")" = "$expected_head" ] ||
  die "EXPECTED_FULL_HEAD does not resolve to the requested commit"

if [ -n "$(git -C "$source_root" status --porcelain=v1 --untracked-files=all)" ]; then
  die "candidate checkout has tracked or untracked changes"
fi

git_common_dir="$(git -C "$source_root" rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$source_root/$git_common_dir" ;;
esac
git_common_dir="$(canonical_directory "$git_common_dir")"

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
  local status="$?"
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
trap cleanup EXIT HUP INT TERM

if ! mkdir -m 0700 "$install_root"; then
  die "could not atomically reserve absent install prefix: $install_root"
fi
install_identity="$(stat_identity "$install_root")"
assert_private_directory "$install_root"

snapshot="$scratch/source"
mkdir -m 0700 "$snapshot"
git -C "$source_root" archive --format=tar "$expected_head" |
  tar -xf - -C "$snapshot"

moon_version="$("$moon_bin" --version | /usr/bin/head -n 1)"
moonrun_version="$("$moonrun_bin" --version | /usr/bin/head -n 1)"

build_log="$scratch/build.log"
if ! (
  cd "$snapshot"
  "$moon_bin" build --release --target native office/cmd/office
  "$moon_bin" build --frozen --release --target native office/cmd/office
  "$moon_bin" build --frozen --release --target wasm office/cmd/office
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

"$native_artifact" help all --json > "$scratch/native-help.json"
"$moonrun_bin" "$wasm_artifact" help all --json > "$scratch/wasm-help.json"
cmp "$scratch/native-help.json" "$scratch/wasm-help.json"

dependency_hashes="$scratch/dependency-files.sha256"
(
  cd "$snapshot"
  find .mooncakes -type f ! -name .moon-lock -print |
    LC_ALL=C sort |
    while IFS= read -r dependency_file; do
      printf '%s  %s\n' \
        "$(sha256_file "$snapshot/$dependency_file")" \
        "$dependency_file"
    done
) > "$dependency_hashes"
[ -s "$dependency_hashes" ] ||
  die "fresh build did not materialize a dependency tree"
dependency_tree_sha256="$(sha256_file "$dependency_hashes")"

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

"$stage/bin/office-native" help all --json \
  > "$scratch/installed-native-help.json"
"$stage/bin/office-wasm" help all --json \
  > "$scratch/installed-wasm-help.json"
cmp "$scratch/installed-native-help.json" "$scratch/installed-wasm-help.json"
cmp "$scratch/native-help.json" "$scratch/installed-native-help.json"

capability_schema="$(jq -er '.data.schema' "$scratch/installed-native-help.json")"
capability_fingerprint="$(
  jq -er '.data.fingerprint' "$scratch/installed-native-help.json"
)"

native_sha256="$(sha256_file "$stage/bin/office-native")"
wasm_wrapper_sha256="$(sha256_file "$stage/bin/office-wasm")"
moonrun_sha256="$(sha256_file "$stage/libexec/moonrun")"
wasm_sha256="$(sha256_file "$stage/libexec/office.wasm")"
runner_sha256="$(sha256_file "$stage/control/run.sh")"
prompt_sha256="$(sha256_file "$stage/control/prompt.md")"
schema_sha256="$(sha256_file "$stage/control/final.schema.json")"
canary_sha256="$(sha256_file "$stage/control/permission-canary.sh")"
private_sha256="$(sha256_file "$stage/control/private.json")"
moon_sha256="$(sha256_file "$moon_bin")"

jq -n \
  --arg schema "office.fresh-agent.candidate/1" \
  --arg candidate_head "$expected_head" \
  --arg moon_version "$moon_version" \
  --arg moon_sha256 "$moon_sha256" \
  --arg moonrun_version "$moonrun_version" \
  --arg dependency_tree_sha256 "$dependency_tree_sha256" \
  --arg capability_schema "$capability_schema" \
  --arg capability_fingerprint "$capability_fingerprint" \
  --arg native_sha256 "$native_sha256" \
  --arg wasm_wrapper_sha256 "$wasm_wrapper_sha256" \
  --arg moonrun_sha256 "$moonrun_sha256" \
  --arg wasm_sha256 "$wasm_sha256" \
  --arg runner_sha256 "$runner_sha256" \
  --arg prompt_sha256 "$prompt_sha256" \
  --arg schema_sha256 "$schema_sha256" \
  --arg canary_sha256 "$canary_sha256" \
  --arg private_sha256 "$private_sha256" \
  '{
    schema: $schema,
    candidate_head: $candidate_head,
    build: {
      moon_version: $moon_version,
      moon_sha256: $moon_sha256,
      moonrun_version: $moonrun_version,
      dependency_tree_sha256: $dependency_tree_sha256,
      capability_schema: $capability_schema,
      capability_fingerprint: $capability_fingerprint
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
      {path: "control/private.json", kind: "file", mode: "0400", sha256: $private_sha256}
    ],
    symlinks: [
      {path: "bin/office", target: "office-native"}
    ]
  }' > "$scratch/CANDIDATE.json"
install -m 0400 "$scratch/CANDIDATE.json" "$stage/CANDIDATE.json"

chmod 0500 "$stage/bin" "$stage/libexec" "$stage/control" "$stage"

[ "$(git -C "$source_root" rev-parse --verify HEAD)" = "$expected_head" ] ||
  die "candidate HEAD changed during preparation"
if [ -n "$(git -C "$source_root" status --porcelain=v1 --untracked-files=all)" ]; then
  die "candidate checkout changed during preparation"
fi

[ "$(sha256_file "$moon_bin")" = "$expected_moon_sha256" ] ||
  die "Moon compiler changed during candidate preparation"
[ "$(sha256_file "$moonrun_bin")" = "$expected_moonrun_sha256" ] ||
  die "Moon runtime changed during candidate preparation"
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
done
chmod 0500 \
  "$install_root/bin" \
  "$install_root/libexec" \
  "$install_root/control" \
  "$install_root"
[ ! -e "$install_root/CANDIDATE.json" ] &&
  [ ! -L "$install_root/CANDIDATE.json" ] ||
  die "candidate commit marker already exists"
ln "$stage/CANDIDATE.json" "$install_root/CANDIDATE.json" ||
  die "could not atomically publish candidate commit marker"
rm -f -- "$stage/CANDIDATE.json"
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

#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 EXPECTED_FULL_HEAD ABSENT_INSTALL_PREFIX" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "required command is unavailable: $1"
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

stat_owner_mode() {
  if stat -f '%u %Lp' "$1" >/dev/null 2>&1; then
    stat -f '%u %Lp' "$1"
  else
    stat -c '%u %a' "$1"
  fi
}

assert_private_directory() {
  local path="$1"
  local owner
  local mode
  read -r owner mode <<<"$(stat_owner_mode "$path")"
  [ "$owner" = "$(id -u)" ] ||
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
  name="$(basename -- "$input")"
  case "$name" in
    "" | "." | "..") die "invalid install prefix: $input" ;;
  esac
  parent="$(canonical_directory "$(dirname -- "$input")")"
  assert_private_directory "$parent"
  if [ "$parent" = "/" ]; then
    printf '/%s\n' "$name"
  else
    printf '%s/%s\n' "$parent" "$name"
  fi
}

[ "$#" -eq 2 ] || usage
expected_head="$1"
install_input="$2"

case "$expected_head" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) die "EXPECTED_FULL_HEAD must be a lowercase 40-character commit id" ;;
esac

for tool in git moon moonrun jq shasum awk find sort tar cmp install mktemp stat; do
  require_command "$tool"
done

script_dir="$(canonical_directory "$(dirname -- "${BASH_SOURCE[0]}")")"
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

install_root="$(canonical_absent_path "$install_input")"
reject_path_syntax "$install_root" "install prefix"
case "$install_root/" in
  "$source_root/"*)
    die "install prefix must be outside the candidate checkout: $install_root"
    ;;
esac

install_parent="$(canonical_directory "$(dirname -- "$install_root")")"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-prepare.XXXXXX")"
stage="$(mktemp -d "$install_parent/.office-f1b-stage.XXXXXX")"
chmod 0700 "$scratch" "$stage"
assert_private_directory "$scratch"
assert_private_directory "$stage"

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
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

snapshot="$scratch/source"
mkdir -m 0700 "$snapshot"
git -C "$source_root" archive --format=tar "$expected_head" |
  tar -xf - -C "$snapshot"

moon_bin="$(command -v moon)"
moonrun_bin="$(command -v moonrun)"
moon_version="$("$moon_bin" --version | head -n 1)"
moonrun_version="$("$moonrun_bin" --version | head -n 1)"

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
install -m 0500 "$script_dir/office-wasm" "$stage/bin/office-wasm"
install -m 0500 "$moonrun_bin" "$stage/libexec/moonrun"
install -m 0400 "$wasm_artifact" "$stage/libexec/office.wasm"
install -m 0500 "$script_dir/run.sh" "$stage/control/run.sh"
install -m 0400 "$script_dir/prompt.md" "$stage/control/prompt.md"
install -m 0400 "$script_dir/final.schema.json" \
  "$stage/control/final.schema.json"
install -m 0500 "$script_dir/permission-canary.sh" \
  "$stage/control/permission-canary.sh"
ln -s office-native "$stage/bin/office"

git_common_dir="$(git -C "$source_root" rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$source_root/$git_common_dir" ;;
esac
git_common_dir="$(canonical_directory "$git_common_dir")"
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

PATH="$stage/bin:$PATH" office-native help all --json \
  > "$scratch/installed-native-help.json"
PATH="$stage/bin:$PATH" office-wasm help all --json \
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

mv -- "$stage" "$install_root"
stage=""
trap - EXIT HUP INT TERM
chmod -R u+w -- "$scratch" 2>/dev/null || true
rm -rf -- "$scratch"
scratch=""

printf 'installed_prefix=%s\n' "$install_root"
cat "$install_root/CANDIDATE.json"

#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: $0 INSTALL_PREFIX" >&2
  exit 2
fi

root="$(git rev-parse --show-toplevel)"
install_root="$1"

if [ -n "$(git -C "$root" status --porcelain --untracked-files=all)" ]; then
  echo "error: candidate checkout has tracked or untracked changes" >&2
  exit 1
fi

if [ -e "$install_root" ] && [ -n "$(find "$install_root" -mindepth 1 -print -quit)" ]; then
  echo "error: install prefix must be absent or empty: $install_root" >&2
  exit 1
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-prepare.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

head="$(git -C "$root" rev-parse HEAD)"
moon_bin="$(command -v moon)"
moonrun_bin="$(command -v moonrun)"

cd "$root"
"$moon_bin" run --frozen --release --target native office/cmd/office -- \
  help all --json > "$scratch/native-help.json"
"$moon_bin" run --frozen --release --target wasm office/cmd/office -- \
  help all --json > "$scratch/wasm-help.json"
cmp "$scratch/native-help.json" "$scratch/wasm-help.json"

if [ -n "$(git -C "$root" status --porcelain --untracked-files=all)" ]; then
  echo "error: candidate build changed the checkout" >&2
  exit 1
fi

native_artifact="$root/_build/native/release/build/bobzhang/office/cmd/office/office.exe"
wasm_artifact="$root/_build/wasm/release/build/bobzhang/office/cmd/office/office.wasm"
test -x "$native_artifact"
test -f "$wasm_artifact"

mkdir -p "$install_root/bin" "$install_root/libexec"
install -m 0755 "$native_artifact" "$install_root/bin/office-native"
install -m 0755 "$root/office/tests/acceptance/fresh-agent/office-wasm" \
  "$install_root/bin/office-wasm"
install -m 0755 "$moonrun_bin" "$install_root/libexec/moonrun"
install -m 0644 "$wasm_artifact" "$install_root/libexec/office.wasm"
ln -s office-native "$install_root/bin/office"

PATH="$install_root/bin:$PATH" office-native help all --json \
  > "$scratch/installed-native-help.json"
PATH="$install_root/bin:$PATH" office-wasm help all --json \
  > "$scratch/installed-wasm-help.json"
cmp "$scratch/installed-native-help.json" "$scratch/installed-wasm-help.json"
cmp "$scratch/native-help.json" "$scratch/installed-native-help.json"

{
  printf 'candidate_head=%s\n' "$head"
  printf 'moon=%s\n' "$("$moon_bin" --version | head -n 1)"
  printf 'moonrun=%s\n' "$("$moonrun_bin" --version)"
  printf 'capability_schema=%s\n' \
    "$(jq -r '.data.schema' "$scratch/installed-native-help.json")"
  printf 'capability_fingerprint=%s\n' \
    "$(jq -r '.data.fingerprint' "$scratch/installed-native-help.json")"
  shasum -a 256 "$install_root/bin/office-native" \
    "$install_root/libexec/office.wasm" "$install_root/libexec/moonrun"
} > "$install_root/CANDIDATE"

printf 'installed_prefix=%s\n' "$install_root"
cat "$install_root/CANDIDATE"

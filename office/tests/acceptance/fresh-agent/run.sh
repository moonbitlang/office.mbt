#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 INSTALL_PREFIX PROBE_DIR EVIDENCE_DIR CODEX_AUTH_JSON" >&2
  exit 2
fi

install_root="$1"
probe_root="$2"
evidence_root="$3"
auth_json="$4"

if [ ! -x "$install_root/bin/office-native" ] ||
  [ ! -x "$install_root/bin/office-wasm" ] ||
  [ ! -f "$install_root/CANDIDATE" ]; then
  echo "error: install prefix is not a prepared F1b candidate: $install_root" >&2
  exit 1
fi

if [ ! -f "$auth_json" ]; then
  echo "error: Codex auth JSON does not exist: $auth_json" >&2
  exit 1
fi

for output_root in "$probe_root" "$evidence_root"; do
  if [ -e "$output_root" ] &&
    [ -n "$(find "$output_root" -mindepth 1 -print -quit)" ]; then
    echo "error: output directory must be absent or empty: $output_root" >&2
    exit 1
  fi
  mkdir -p "$output_root"
done

root="$(git rev-parse --show-toplevel)"
prompt="$root/office/tests/acceptance/fresh-agent/prompt.md"
codex_bin="$(command -v codex)"
codex_bin_dir="$(dirname "$codex_bin")"

isolation_root="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-codex.XXXXXX")"
trap 'rm -rf -- "$isolation_root"' EXIT

isolated_user_home="$isolation_root/home"
isolated_codex_state="$isolation_root/codex"
isolated_tmp="$isolation_root/tmp"
mkdir -p "$isolated_user_home" "$isolated_codex_state" "$isolated_tmp"
install -m 0600 "$auth_json" "$isolated_codex_state/auth.json"

probe_path="$install_root/bin:$codex_bin_dir:/usr/bin:/bin:/usr/sbin:/sbin"

set +e
env -i \
  HOME="$isolated_user_home" \
  CODEX_HOME="$isolated_codex_state" \
  PATH="$probe_path" \
  TMPDIR="$isolated_tmp" \
  LANG=C \
  LC_ALL=C \
  "$codex_bin" exec \
  --ephemeral \
  --skip-git-repo-check \
  --ignore-user-config \
  --ignore-rules \
  --sandbox workspace-write \
  -m gpt-5.6-sol \
  -c 'model_reasoning_effort="max"' \
  -C "$probe_root" \
  --output-last-message "$evidence_root/final-message.md" \
  - < "$prompt" \
  > "$evidence_root/codex-transcript.log" 2>&1
codex_status="$?"
set -e

printf 'codex_exit_status=%s\n' "$codex_status" \
  > "$evidence_root/codex-exit-status.txt"
printf 'probe_dir=%s\n' "$probe_root"
printf 'evidence_dir=%s\n' "$evidence_root"
exit "$codex_status"

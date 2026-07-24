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

if [ ! -d "$install_root" ]; then
  echo "error: install prefix does not exist: $install_root" >&2
  exit 1
fi
install_root="$(cd "$install_root" && pwd -P)"

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

auth_dir="$(cd "$(dirname "$auth_json")" && pwd -P)"
auth_json="$auth_dir/$(basename "$auth_json")"

for output_root in "$probe_root" "$evidence_root"; do
  if [ -e "$output_root" ] && [ ! -d "$output_root" ]; then
    echo "error: output path is not a directory: $output_root" >&2
    exit 1
  fi
  mkdir -p "$output_root"
done

probe_root="$(cd "$probe_root" && pwd -P)"
evidence_root="$(cd "$evidence_root" && pwd -P)"
case "$probe_root/" in
  "$evidence_root/"*)
    echo "error: probe and evidence directories must not overlap" >&2
    exit 1
    ;;
esac
case "$evidence_root/" in
  "$probe_root/"*)
    echo "error: probe and evidence directories must not overlap" >&2
    exit 1
    ;;
esac

for output_root in "$probe_root" "$evidence_root"; do
  if [ -n "$(find "$output_root" -mindepth 1 -print -quit)" ]; then
    echo "error: output directory must be empty: $output_root" >&2
    exit 1
  fi
done

root="$(git rev-parse --show-toplevel)"
prompt="$root/office/tests/acceptance/fresh-agent/prompt.md"
codex_bin="$(command -v codex)"
if [ ! -x "$codex_bin" ]; then
  echo "error: Codex CLI is not executable: $codex_bin" >&2
  exit 1
fi
codex_bin="$(cd "$(dirname "$codex_bin")" && pwd -P)/$(basename "$codex_bin")"

codex_runtime_dir=""
codex_shebang=""
IFS= read -r codex_shebang < "$codex_bin" || true
codex_shebang="${codex_shebang%$'\r'}"
case "$codex_shebang" in
  "#!/usr/bin/env "*)
    env_spec="${codex_shebang#\#!/usr/bin/env }"
    read -r -a env_parts <<< "$env_spec"
    runtime_name=""
    for env_part in "${env_parts[@]}"; do
      case "$env_part" in
        -* | *=*) ;;
        *)
          runtime_name="$env_part"
          break
          ;;
      esac
    done
    if [ -z "$runtime_name" ]; then
      echo "error: could not resolve Codex launcher runtime: $codex_shebang" >&2
      exit 1
    fi
    runtime_bin="$(command -v "$runtime_name" || true)"
    if [ -z "$runtime_bin" ] || [ ! -x "$runtime_bin" ]; then
      echo "error: Codex launcher runtime is unavailable: $runtime_name" >&2
      exit 1
    fi
    codex_runtime_dir="$(cd "$(dirname "$runtime_bin")" && pwd -P)"
    ;;
esac

isolation_root="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-codex.XXXXXX")"
trap 'rm -rf -- "$isolation_root"' EXIT

isolated_user_home="$isolation_root/home"
isolated_codex_state="$isolation_root/codex"
isolated_tmp="$isolation_root/tmp"
mkdir -p "$isolated_user_home" "$isolated_codex_state" "$isolated_tmp"
install -m 0600 "$auth_json" "$isolated_codex_state/auth.json"

probe_path="$install_root/bin"
if [ -n "$codex_runtime_dir" ]; then
  probe_path="$probe_path:$codex_runtime_dir"
fi
probe_path="$probe_path:/usr/bin:/bin:/usr/sbin:/sbin"

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

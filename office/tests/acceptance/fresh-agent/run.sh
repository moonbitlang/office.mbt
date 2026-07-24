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
invocation_root="$(pwd -P)"

canonical_directory() {
  local candidate="$1"
  case "$candidate" in
    /*) ;;
    *) candidate="$invocation_root/$candidate" ;;
  esac
  (
    unset CDPATH
    cd -P -- "$candidate" >/dev/null && pwd -P
  )
}

if [ ! -d "$install_root" ]; then
  echo "error: install prefix does not exist: $install_root" >&2
  exit 1
fi
install_root="$(canonical_directory "$install_root")"

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

auth_dir="$(canonical_directory "$(dirname "$auth_json")")"
auth_json="$auth_dir/$(basename "$auth_json")"

for output_root in "$probe_root" "$evidence_root"; do
  if [ -e "$output_root" ] && [ ! -d "$output_root" ]; then
    echo "error: output path is not a directory: $output_root" >&2
    exit 1
  fi
  mkdir -p "$output_root"
done

probe_root="$(canonical_directory "$probe_root")"
evidence_root="$(canonical_directory "$evidence_root")"
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
codex_bin="$(command -v codex || true)"
if [ ! -x "$codex_bin" ]; then
  echo "error: Codex CLI is not executable: $codex_bin" >&2
  exit 1
fi
codex_bin_dir="$(canonical_directory "$(dirname "$codex_bin")")"
codex_bin="$codex_bin_dir/$(basename "$codex_bin")"
codex_name="$(basename "$codex_bin")"

codex_runtime_name=""
codex_runtime_bin=""
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
    case "$runtime_name" in
      /*)
        if [ ! -x "$runtime_name" ]; then
          echo "error: Codex launcher runtime is unavailable: $runtime_name" >&2
          exit 1
        fi
        ;;
      */* | *[!A-Za-z0-9._+-]*)
        echo "error: unsupported Codex launcher runtime name: $runtime_name" >&2
        exit 1
        ;;
      *)
        runtime_bin="$(command -v "$runtime_name" || true)"
        if [ -z "$runtime_bin" ] || [ ! -x "$runtime_bin" ]; then
          echo "error: Codex launcher runtime is unavailable: $runtime_name" >&2
          exit 1
        fi
        runtime_dir="$(canonical_directory "$(dirname "$runtime_bin")")"
        codex_runtime_name="$runtime_name"
        codex_runtime_bin="$runtime_dir/$(basename "$runtime_bin")"
        ;;
    esac
    ;;
esac

isolation_root="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-codex.XXXXXX")"
trap 'rm -rf -- "$isolation_root"' EXIT

isolated_user_home="$isolation_root/home"
isolated_codex_state="$isolation_root/codex"
isolated_tmp="$isolation_root/tmp"
isolated_launcher_bin="$isolation_root/launcher-bin"
mkdir -p \
  "$isolated_user_home" \
  "$isolated_codex_state" \
  "$isolated_tmp" \
  "$isolated_launcher_bin"
install -m 0600 "$auth_json" "$isolated_codex_state/auth.json"

write_launcher_forwarder() {
  local target_path="$1"
  local forwarder_path="$2"
  local quoted_target
  printf -v quoted_target '%q' "$target_path"
  printf '#!/bin/bash\nexec %s "$@"\n' "$quoted_target" > "$forwarder_path"
  chmod 0700 "$forwarder_path"
}

if [ -n "$codex_runtime_name" ]; then
  write_launcher_forwarder \
    "$codex_runtime_bin" \
    "$isolated_launcher_bin/$codex_runtime_name"
fi

launcher_helper_spec="${OFFICE_F1B_CODEX_LAUNCHER_HELPERS:-}"
if [ -n "$launcher_helper_spec" ]; then
  IFS=: read -r -a launcher_helper_names <<< "$launcher_helper_spec"
  launcher_seen_names=":$codex_name:"
  for helper_name in "${launcher_helper_names[@]}"; do
    case "$helper_name" in
      "" | -* | *[!A-Za-z0-9._+-]*)
        echo "error: invalid Codex launcher helper name: $helper_name" >&2
        exit 1
        ;;
    esac
    case "$launcher_seen_names" in
      *":$helper_name:"*) continue ;;
    esac
    helper_path="$codex_bin_dir/$helper_name"
    if [ ! -f "$helper_path" ] || [ ! -x "$helper_path" ]; then
      echo "error: Codex launcher helper is unavailable: $helper_path" >&2
      exit 1
    fi
    if [ -e "$isolated_launcher_bin/$helper_name" ]; then
      echo "error: Codex launcher helper conflicts with runtime: $helper_name" >&2
      exit 1
    fi

    launcher_seen_names="${launcher_seen_names}${helper_name}:"
    write_launcher_forwarder \
      "$helper_path" \
      "$isolated_launcher_bin/$helper_name"
  done
fi

probe_path="$install_root/bin:$isolated_launcher_bin:/usr/bin:/bin:/usr/sbin:/sbin"

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

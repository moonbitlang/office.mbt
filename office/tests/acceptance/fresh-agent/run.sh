#!/usr/bin/env bash
set -euo pipefail
umask 077

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 EXPECTED_FULL_HEAD ABSENT_PROBE_DIR ABSENT_EVIDENCE_DIR CODEX_AUTH_JSON" >&2
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

stat_identity() {
  if stat -f '%d:%i' "$1" >/dev/null 2>&1; then
    stat -f '%d:%i' "$1"
  else
    stat -c '%d:%i' "$1"
  fi
}

normalized_mode() {
  local mode="$1"
  printf '%04o\n' "$((8#$mode))"
}

assert_owned_private_directory() {
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

assert_owned_private_file() {
  local path="$1"
  local label="$2"
  local owner
  local mode
  [ -f "$path" ] && [ ! -L "$path" ] ||
    die "$label must be a regular non-symlink file: $path"
  read -r owner mode <<<"$(stat_owner_mode "$path")"
  [ "$owner" = "$(id -u)" ] ||
    die "$label is not owned by the current user: $path"
  if (( (8#$mode & 077) != 0 )); then
    die "$label must not grant group or other access: $path (mode $mode)"
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
  local parent
  local path
  case "$input" in
    /*) ;;
    *) die "file path must be absolute: $input" ;;
  esac
  parent="$(canonical_directory "$(dirname -- "$input")")"
  path="$parent/$(basename -- "$input")"
  [ -f "$path" ] && [ ! -L "$path" ] ||
    die "file must be regular and must not be a symlink: $path"
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
  name="$(basename -- "$input")"
  case "$name" in
    "" | "." | "..") die "invalid $label: $input" ;;
  esac
  parent="$(canonical_directory "$(dirname -- "$input")")"
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

reject_overlap() {
  local left="$1"
  local left_label="$2"
  local right="$3"
  local right_label="$4"
  if paths_overlap "$left" "$right"; then
    die "$left_label and $right_label must not overlap"
  fi
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

toml_string() {
  jq -Rn --arg value "$1" '$value'
}

verify_candidate() {
  local manifest="$install_root/CANDIDATE.json"
  local relative
  local expected_mode
  local expected_hash
  local actual_hash
  local owner
  local mode
  local candidate_file
  local actual_files
  local expected_files
  local actual_directories
  local expected_directories

  [ -f "$manifest" ] && [ ! -L "$manifest" ] ||
    die "candidate manifest is missing or is not a regular file"
  jq -e \
    --arg head "$expected_head" \
    '
      keys == ["build", "candidate_head", "files", "schema", "symlinks"] and
      .schema == "office.fresh-agent.candidate/1" and
      .candidate_head == $head and
      (.build | keys) == [
        "capability_fingerprint",
        "capability_schema",
        "dependency_tree_sha256",
        "moon_sha256",
        "moon_version",
        "moonrun_version"
      ] and
      (.build.dependency_tree_sha256 | test("^[0-9a-f]{64}$")) and
      (.build.moon_sha256 | test("^[0-9a-f]{64}$")) and
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
        "control/private.json"
      ] and
      (.files | map(.kind == "file") | all) and
      (.files | map(.sha256 | test("^[0-9a-f]{64}$")) | all) and
      .symlinks == [{path: "bin/office", target: "office-native"}]
    ' "$manifest" >/dev/null ||
    die "candidate manifest failed strict schema validation"

  while IFS='|' read -r relative expected_mode; do
    [ -n "$relative" ] || continue
    candidate_file="$install_root/$relative"
    [ -f "$candidate_file" ] && [ ! -L "$candidate_file" ] ||
      die "candidate file is missing or is not regular: $relative"
    expected_hash="$(
      jq -er --arg path "$relative" \
        '.files[] | select(.path == $path) | .sha256' "$manifest"
    )"
    [ "$(
      jq -er --arg path "$relative" \
        '.files[] | select(.path == $path) | .mode' "$manifest"
    )" = "$expected_mode" ] ||
      die "candidate manifest has an unexpected mode for $relative"
    actual_hash="$(sha256_file "$candidate_file")"
    [ "$actual_hash" = "$expected_hash" ] ||
      die "candidate hash mismatch: $relative"
    read -r owner mode <<<"$(stat_owner_mode "$candidate_file")"
    [ "$owner" = "$(id -u)" ] ||
      die "candidate file is not owned by the current user: $relative"
    [ "$(normalized_mode "$mode")" = "$expected_mode" ] ||
      die "candidate file mode mismatch: $relative"
  done <<'EOF'
bin/office-native|0500
bin/office-wasm|0500
libexec/moonrun|0500
libexec/office.wasm|0400
control/run.sh|0500
control/prompt.md|0400
control/final.schema.json|0400
control/permission-canary.sh|0500
control/private.json|0400
EOF

  [ -L "$install_root/bin/office" ] ||
    die "candidate office alias is not a symlink"
  [ "$(readlink "$install_root/bin/office")" = "office-native" ] ||
    die "candidate office alias has an unexpected target"

  actual_files="$(
    find "$install_root" -mindepth 1 \( -type f -o -type l \) -print |
      sed "s#^$install_root/##" |
      LC_ALL=C sort
  )"
  expected_files="$(
    printf '%s\n' \
      CANDIDATE.json \
      bin/office \
      bin/office-native \
      bin/office-wasm \
      control/final.schema.json \
      control/permission-canary.sh \
      control/private.json \
      control/prompt.md \
      control/run.sh \
      libexec/moonrun \
      libexec/office.wasm |
      LC_ALL=C sort
  )"
  [ "$actual_files" = "$expected_files" ] ||
    die "candidate prefix contains an unexpected or missing file"

  actual_directories="$(
    find "$install_root" -mindepth 1 -type d -print |
      sed "s#^$install_root/##" |
      LC_ALL=C sort
  )"
  expected_directories="$(printf '%s\n' bin control libexec | LC_ALL=C sort)"
  [ "$actual_directories" = "$expected_directories" ] ||
    die "candidate prefix contains an unexpected or missing directory"
  if [ -n "$(
    find "$install_root" -mindepth 1 \
      ! -type d ! -type f ! -type l -print -quit
  )" ]; then
    die "candidate prefix contains an unsupported filesystem entry"
  fi

  read -r owner mode <<<"$(stat_owner_mode "$manifest")"
  [ "$owner" = "$(id -u)" ] ||
    die "candidate manifest is not owned by the current user"
  [ "$(normalized_mode "$mode")" = "0400" ] ||
    die "candidate manifest mode mismatch"
}

[ "$#" -eq 4 ] || usage
expected_head="$1"
probe_input="$2"
evidence_input="$3"
auth_input="$4"

case "$expected_head" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) die "EXPECTED_FULL_HEAD must be a lowercase 40-character commit id" ;;
esac

for tool in jq shasum awk find sort sed stat id mktemp install perl; do
  require_command "$tool"
done

control_dir="$(canonical_directory "$(dirname -- "${BASH_SOURCE[0]}")")"
install_root="$(canonical_directory "$control_dir/..")"
[ "$control_dir" = "$install_root/control" ] ||
  die "runner must be invoked from a prepared candidate prefix"
reject_path_syntax "$install_root" "install prefix"
assert_owned_private_directory "$install_root"
assert_owned_private_directory "$(dirname -- "$install_root")"
verify_candidate
candidate_manifest_sha256="$(sha256_file "$install_root/CANDIDATE.json")"
install_identity="$(stat_identity "$install_root")"

private_manifest="$install_root/control/private.json"
jq -e '
  keys == ["git_common_dir", "schema", "source_root"] and
  .schema == "office.fresh-agent.private/1" and
  (.source_root | startswith("/")) and
  (.git_common_dir | startswith("/"))
' "$private_manifest" >/dev/null ||
  die "candidate private manifest failed strict validation"
source_root="$(canonical_directory "$(jq -er '.source_root' "$private_manifest")")"
git_common_dir="$(
  canonical_directory "$(jq -er '.git_common_dir' "$private_manifest")"
)"
reject_overlap "$install_root" "install prefix" "$source_root" "source checkout"
reject_overlap "$install_root" "install prefix" "$git_common_dir" "Git common directory"

auth_json="$(canonical_regular_file "$auth_input")"
assert_owned_private_file "$auth_json" "Codex auth JSON"

probe_root="$(canonical_absent_directory "$probe_input" "probe directory")"
evidence_root="$(
  canonical_absent_directory "$evidence_input" "evidence directory"
)"
reject_protected_location "$install_root" "install prefix"
reject_protected_location "$probe_root" "probe directory"
reject_protected_location "$evidence_root" "evidence directory"

reject_overlap "$probe_root" "probe directory" "$evidence_root" "evidence directory"
reject_overlap "$probe_root" "probe directory" "$install_root" "install prefix"
reject_overlap "$evidence_root" "evidence directory" "$install_root" "install prefix"
reject_overlap "$probe_root" "probe directory" "$source_root" "source checkout"
reject_overlap "$evidence_root" "evidence directory" "$source_root" "source checkout"
reject_overlap "$probe_root" "probe directory" "$git_common_dir" "Git common directory"
reject_overlap "$evidence_root" "evidence directory" "$git_common_dir" "Git common directory"
reject_overlap "$probe_root" "probe directory" "$auth_json" "Codex auth JSON"
reject_overlap "$evidence_root" "evidence directory" "$auth_json" "Codex auth JSON"
reject_overlap "$install_root" "install prefix" "$auth_json" "Codex auth JSON"

mkdir -m 0700 "$probe_root"
if ! mkdir -m 0700 "$evidence_root"; then
  rmdir "$probe_root" 2>/dev/null || true
  die "could not create evidence directory"
fi
assert_owned_private_directory "$probe_root"
assert_owned_private_directory "$evidence_root"
probe_identity="$(stat_identity "$probe_root")"
evidence_identity="$(stat_identity "$evidence_root")"

probe_parent="$(canonical_directory "$(dirname -- "$probe_root")")"
isolation_root="$(mktemp -d "$probe_parent/.office-f1b-isolation.XXXXXX")"
chmod 0700 "$isolation_root"
assert_owned_private_directory "$isolation_root"
reject_path_syntax "$isolation_root" "isolation directory"
reject_overlap "$isolation_root" "isolation directory" "$install_root" "install prefix"
reject_overlap "$isolation_root" "isolation directory" "$evidence_root" "evidence directory"
reject_overlap "$isolation_root" "isolation directory" "$auth_json" "Codex auth JSON"

isolated_user_home="$isolation_root/home"
isolated_codex_state="$isolation_root/codex"
isolated_tmp="$isolation_root/tmp"
isolated_launcher_bin="$isolation_root/launcher-bin"
mkdir -m 0700 \
  "$isolated_user_home" \
  "$isolated_codex_state" \
  "$isolated_tmp" \
  "$isolated_launcher_bin"
install -m 0600 "$auth_json" "$isolated_codex_state/auth.json"

slash_tmp="$(canonical_directory /tmp)"
ambient_write_path="$slash_tmp/.office-f1b-deny-write.$$.$RANDOM"
[ ! -e "$ambient_write_path" ] && [ ! -L "$ambient_write_path" ] ||
  die "ambient permission-canary path unexpectedly exists"

cleanup() {
  local status="$?"
  if [ -d "$ambient_write_path" ]; then
    rmdir "$ambient_write_path" 2>/dev/null || true
  fi
  if [ -n "${isolation_root:-}" ] && [ -d "$isolation_root" ]; then
    chmod -R u+w -- "$isolation_root" 2>/dev/null || true
    rm -rf -- "$isolation_root"
  fi
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

codex_command="$(command -v codex || true)"
[ -n "$codex_command" ] ||
  die "Codex CLI is unavailable"
case "$codex_command" in
  /*) ;;
  *) die "Codex CLI must resolve to an absolute path: $codex_command" ;;
esac
codex_bin_dir="$(canonical_directory "$(dirname -- "$codex_command")")"
codex_bin="$codex_bin_dir/$(basename -- "$codex_command")"
[ -f "$codex_bin" ] && [ -x "$codex_bin" ] ||
  die "Codex CLI is not an executable regular file: $codex_bin"

exec_trampoline="/usr/bin/perl"
exec_trampoline_program='my $target = shift @ARGV; exec {$target} $target, @ARGV; die "exec $target: $!\n";'
[ -x "$exec_trampoline" ] ||
  die "fresh-agent exec trampoline is unavailable: $exec_trampoline"

codex_runtime_name=""
codex_runtime_bin=""
codex_shebang=""
IFS= read -r codex_shebang < "$codex_bin" || true
codex_shebang="${codex_shebang%$'\r'}"
case "$codex_shebang" in
  "#!/usr/bin/env "*)
    runtime_name="${codex_shebang#\#!/usr/bin/env }"
    case "$runtime_name" in
      "" | -* | *" "* | *$'\t'* | */* | *[!A-Za-z0-9._+-]*)
        die "Codex env shebang must name exactly one simple runtime: $codex_shebang"
        ;;
    esac
    runtime_command="$(command -v "$runtime_name" || true)"
    [ -n "$runtime_command" ] && [ -x "$runtime_command" ] ||
      die "Codex launcher runtime is unavailable: $runtime_name"
    runtime_dir="$(canonical_directory "$(dirname -- "$runtime_command")")"
    codex_runtime_name="$runtime_name"
    codex_runtime_bin="$runtime_dir/$(basename -- "$runtime_command")"
    ;;
  "#!"/*)
    interpreter="${codex_shebang#\#!}"
    case "$interpreter" in
      *" "* | *$'\t'*) die "Codex absolute shebang arguments are unsupported" ;;
    esac
    [ -x "$interpreter" ] ||
      die "Codex launcher interpreter is unavailable: $interpreter"
    ;;
  "#!"*)
    die "Codex launcher has an unsupported shebang: $codex_shebang"
    ;;
  *)
    ;;
esac

write_launcher_forwarder() {
  local target_path="$1"
  local forwarder_path="$2"
  local quoted_program
  local quoted_target
  printf -v quoted_program '%q' "$exec_trampoline_program"
  printf -v quoted_target '%q' "$target_path"
  printf \
    '#!/bin/bash\nexec /usr/bin/env -u PWD -u SHLVL -u _ /usr/bin/perl -e %s %s "$@"\n' \
    "$quoted_program" "$quoted_target" > "$forwarder_path"
  chmod 0500 "$forwarder_path"
}

if [ -n "$codex_runtime_name" ]; then
  write_launcher_forwarder \
    "$codex_runtime_bin" \
    "$isolated_launcher_bin/$codex_runtime_name"
fi

launcher_helper_spec="${OFFICE_F1B_CODEX_LAUNCHER_HELPERS:-}"
if [ -n "$launcher_helper_spec" ]; then
  IFS=: read -r -a launcher_helper_names <<<"$launcher_helper_spec"
  launcher_seen_names=":$(basename "$codex_bin"):$codex_runtime_name:"
  for helper_name in "${launcher_helper_names[@]}"; do
    case "$helper_name" in
      "" | -* | *[!A-Za-z0-9._+-]*)
        die "invalid Codex launcher helper name: $helper_name"
        ;;
    esac
    case "$launcher_seen_names" in
      *":$helper_name:"*) continue ;;
    esac
    helper_path="$codex_bin_dir/$helper_name"
    [ -f "$helper_path" ] && [ -x "$helper_path" ] ||
      die "Codex launcher helper is unavailable: $helper_path"
    [ ! -e "$isolated_launcher_bin/$helper_name" ] ||
      die "Codex launcher helper conflicts with a runtime: $helper_name"
    launcher_seen_names="$launcher_seen_names$helper_name:"
    write_launcher_forwarder \
      "$helper_path" \
      "$isolated_launcher_bin/$helper_name"
  done
fi

probe_path="$install_root/bin:$isolated_launcher_bin:/usr/bin:/bin:/usr/sbin:/sbin"

write_shell_path_guard() {
  local profile="$1"
  local quoted_path
  printf -v quoted_path '%q' "$probe_path"
  printf 'PATH=%s\nexport PATH\nunset CDPATH CODEX_HOME\n' "$quoted_path" > "$profile"
  chmod 0400 "$profile"
}

for profile_name in .profile .bash_profile .zprofile .zlogin .zshenv; do
  write_shell_path_guard "$isolated_user_home/$profile_name"
done
chmod 0500 "$isolated_user_home"

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
  printf 'TMPDIR = %s\n' "$(toml_string "$isolated_tmp")"
  printf '%s\n' \
    'LANG = "C"' \
    'LC_ALL = "C"' \
    '' \
    '[permissions.fresh_agent]' \
    'description = "Installed Office probe with split read/write boundaries."' \
    '' \
    '[permissions.fresh_agent.filesystem]'
  for protected_root in /Users /home /root /Volumes /mnt /media /workspace /workspaces; do
    if [ -e "$protected_root" ]; then
      printf '%s = "deny"\n' "$(toml_string "$protected_root")"
    fi
  done
  printf '%s = "deny"\n' "$(toml_string "$source_root")"
  printf '%s = "deny"\n' "$(toml_string "$git_common_dir")"
  printf '%s = "deny"\n' "$(toml_string "$auth_json")"
  printf '%s = "deny"\n' "$(toml_string "$isolated_codex_state")"
  printf '%s = "deny"\n' "$(toml_string "$evidence_root")"
  printf '%s = "read"\n' "$(toml_string "$install_root")"
  printf '%s = "read"\n' "$(toml_string "$isolated_user_home")"
  printf '%s = "write"\n' "$(toml_string "$probe_root")"
  printf '%s = "write"\n' "$(toml_string "$isolated_tmp")"
  printf '%s\n' \
    '' \
    '[permissions.fresh_agent.filesystem.":root"]' \
    '"." = "read"' \
    '' \
    '[permissions.fresh_agent.network]' \
    'enabled = false'
  printf '\n[projects.%s]\n' "$(toml_string "$probe_root")"
  printf 'trust_level = "trusted"\n'
} > "$config_tmp"
chmod 0600 "$config_tmp"
mv "$config_tmp" "$config_file"

candidate_manifest_sha256_before="$(sha256_file "$install_root/CANDIDATE.json")"
codex_sha256_before="$(sha256_file "$codex_bin")"
if [ -n "$codex_runtime_bin" ]; then
  codex_runtime_sha256_before="$(sha256_file "$codex_runtime_bin")"
else
  codex_runtime_sha256_before=""
fi
config_sha256_before="$(sha256_file "$config_file")"

codex_version="$(
  /usr/bin/env -i \
    HOME="$isolated_user_home" \
    CODEX_HOME="$isolated_codex_state" \
    ZDOTDIR="$isolated_user_home" \
    PATH="$probe_path" \
    TMPDIR="$isolated_tmp" \
    LANG=C \
    LC_ALL=C \
    "$exec_trampoline" -e "$exec_trampoline_program" \
    "$codex_bin" --version |
    head -n 1
)"
case "$codex_version" in
  "codex-cli "*) ;;
  *) die "could not identify Codex CLI version: $codex_version" ;;
esac

runtime_version=""
if [ -n "$codex_runtime_bin" ]; then
  runtime_version="$("$codex_runtime_bin" --version 2>&1 | head -n 1)"
fi

set +e
/usr/bin/env -i \
  HOME="$isolated_user_home" \
  CODEX_HOME="$isolated_codex_state" \
  ZDOTDIR="$isolated_user_home" \
  PATH="$probe_path" \
  TMPDIR="$isolated_tmp" \
  LANG=C \
  LC_ALL=C \
  "$exec_trampoline" -e "$exec_trampoline_program" \
  "$codex_bin" sandbox \
  -P fresh_agent \
  -C "$probe_root" \
  /usr/bin/env -i \
  HOME="$isolated_user_home" \
  ZDOTDIR="$isolated_user_home" \
  PATH="$probe_path" \
  TMPDIR="$isolated_tmp" \
  LANG=C \
  LC_ALL=C \
  "$install_root/control/permission-canary.sh" \
  "$install_root" \
  "$probe_root" \
  "$isolated_tmp" \
  "$evidence_root" \
  "$isolated_codex_state" \
  "$auth_json" \
  "$source_root" \
  "$ambient_write_path" \
  > "$evidence_root/permission-canary.log" 2>&1
canary_status="$?"
set -e
[ "$canary_status" -eq 0 ] ||
  die "Codex permission-profile canary failed; see $evidence_root/permission-canary.log"
grep -q '^FRESH-AGENT PERMISSION CANARY PASS$' \
  "$evidence_root/permission-canary.log" ||
  die "Codex permission-profile canary did not report PASS"
[ ! -e "$ambient_write_path" ] && [ ! -L "$ambient_write_path" ] ||
  die "permission canary created its ambient write path"
[ "$(find "$probe_root" -mindepth 1 -print -quit)" = "" ] ||
  die "permission canary left the probe directory non-empty"
[ "$(find "$isolated_tmp" -mindepth 1 -print -quit)" = "" ] ||
  die "permission canary left the isolated scratch directory non-empty"

canary_sha256="$(sha256_file "$evidence_root/permission-canary.log")"
runner_sha256="$(sha256_file "$install_root/control/run.sh")"
prompt_sha256="$(sha256_file "$install_root/control/prompt.md")"
output_schema_sha256="$(
  sha256_file "$install_root/control/final.schema.json"
)"

jq -n \
  --arg schema "office.fresh-agent.run-preflight/1" \
  --arg candidate_head "$expected_head" \
  --arg candidate_manifest_sha256 "$candidate_manifest_sha256_before" \
  --arg runner_sha256 "$runner_sha256" \
  --arg prompt_sha256 "$prompt_sha256" \
  --arg output_schema_sha256 "$output_schema_sha256" \
  --arg codex_path "$codex_bin" \
  --arg codex_version "$codex_version" \
  --arg codex_sha256 "$codex_sha256_before" \
  --arg runtime_path "$codex_runtime_bin" \
  --arg runtime_version "$runtime_version" \
  --arg runtime_sha256 "$codex_runtime_sha256_before" \
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
      permission_canary_sha256: $permission_canary_sha256
    },
    codex: {
      launcher_path: $codex_path,
      launcher_version: $codex_version,
      launcher_sha256: $codex_sha256,
      runtime_path: $runtime_path,
      runtime_version: $runtime_version,
      runtime_sha256: $runtime_sha256
    }
  }' > "$isolation_root/RUN-PREFLIGHT.json"
install -m 0600 \
  "$isolation_root/RUN-PREFLIGHT.json" \
  "$evidence_root/RUN-PREFLIGHT.json"

verify_candidate
[ "$(stat_identity "$install_root")" = "$install_identity" ] ||
  die "install prefix identity changed before the probe"
[ "$(stat_identity "$probe_root")" = "$probe_identity" ] ||
  die "probe directory identity changed before the probe"
[ "$(stat_identity "$evidence_root")" = "$evidence_identity" ] ||
  die "evidence directory identity changed before the probe"

set +e
/usr/bin/env -i \
  HOME="$isolated_user_home" \
  CODEX_HOME="$isolated_codex_state" \
  ZDOTDIR="$isolated_user_home" \
  PATH="$probe_path" \
  TMPDIR="$isolated_tmp" \
  LANG=C \
  LC_ALL=C \
  "$exec_trampoline" -e "$exec_trampoline_program" \
  "$codex_bin" exec \
  --ephemeral \
  --skip-git-repo-check \
  --ignore-rules \
  --strict-config \
  --json \
  -m gpt-5.6-sol \
  -c 'model_reasoning_effort="max"' \
  -C "$probe_root" \
  --output-schema "$install_root/control/final.schema.json" \
  --output-last-message "$evidence_root/final-message.json" \
  - < "$install_root/control/prompt.md" \
  > "$evidence_root/codex-transcript.jsonl" 2>&1
codex_status="$?"
set -e

printf 'codex_exit_status=%s\n' "$codex_status" \
  > "$evidence_root/codex-exit-status.txt"
chmod u+w "$isolated_codex_state/auth.json" 2>/dev/null || true
rm -f -- "$isolated_codex_state/auth.json"

verify_candidate
[ "$(sha256_file "$install_root/CANDIDATE.json")" = "$candidate_manifest_sha256_before" ] ||
  die "candidate manifest changed during the probe"
[ "$(sha256_file "$codex_bin")" = "$codex_sha256_before" ] ||
  die "Codex launcher changed during the probe"
if [ -n "$codex_runtime_bin" ]; then
  [ "$(sha256_file "$codex_runtime_bin")" = "$codex_runtime_sha256_before" ] ||
    die "Codex launcher runtime changed during the probe"
fi
[ "$(sha256_file "$config_file")" = "$config_sha256_before" ] ||
  die "Codex isolation config changed during the probe"
[ "$(stat_identity "$install_root")" = "$install_identity" ] ||
  die "install prefix identity changed during the probe"
[ "$(stat_identity "$probe_root")" = "$probe_identity" ] ||
  die "probe directory identity changed during the probe"
[ "$(stat_identity "$evidence_root")" = "$evidence_identity" ] ||
  die "evidence directory identity changed during the probe"

[ "$codex_status" -eq 0 ] || {
  echo "error: Codex probe exited with status $codex_status" >&2
  exit "$codex_status"
}

assert_owned_private_file \
  "$evidence_root/final-message.json" \
  "Codex final message"
assert_owned_private_file \
  "$evidence_root/codex-transcript.jsonl" \
  "Codex transcript"
jq -e '
  keys == ["result_path", "transcript_path", "verdict"] and
  (.verdict == "BASELINE PASS" or .verdict == "BASELINE FAIL") and
  .result_path == "probe-result.md" and
  .transcript_path == "probe-transcript.md"
' "$evidence_root/final-message.json" >/dev/null ||
  die "Codex final message did not match the required structured result"

result_file="$probe_root/probe-result.md"
transcript_file="$probe_root/probe-transcript.md"
assert_owned_private_file "$result_file" "probe result"
assert_owned_private_file "$transcript_file" "probe transcript"
[ -s "$result_file" ] || die "probe result is empty"
[ -s "$transcript_file" ] || die "probe transcript is empty"
verdict="$(jq -er '.verdict' "$evidence_root/final-message.json")"
grep -Fq "$verdict" "$result_file" ||
  die "probe result does not contain the structured verdict"

candidate_manifest_sha256_after="$(
  sha256_file "$install_root/CANDIDATE.json"
)"
codex_sha256_after="$(sha256_file "$codex_bin")"
if [ -n "$codex_runtime_bin" ]; then
  codex_runtime_sha256_after="$(sha256_file "$codex_runtime_bin")"
else
  codex_runtime_sha256_after=""
fi

jq -n \
  --arg schema "office.fresh-agent.run/1" \
  --arg candidate_head "$expected_head" \
  --arg verdict "$verdict" \
  --argjson codex_exit_status "$codex_status" \
  --arg candidate_before "$candidate_manifest_sha256_before" \
  --arg candidate_after "$candidate_manifest_sha256_after" \
  --arg codex_before "$codex_sha256_before" \
  --arg codex_after "$codex_sha256_after" \
  --arg runtime_before "$codex_runtime_sha256_before" \
  --arg runtime_after "$codex_runtime_sha256_after" \
  --arg config_before "$config_sha256_before" \
  --arg config_after "$(sha256_file "$config_file")" \
  --arg result_sha256 "$(sha256_file "$result_file")" \
  --arg transcript_sha256 "$(sha256_file "$transcript_file")" \
  --arg raw_transcript_sha256 "$(
    sha256_file "$evidence_root/codex-transcript.jsonl"
  )" \
  --arg final_message_sha256 "$(
    sha256_file "$evidence_root/final-message.json"
  )" \
  '{
    schema: $schema,
    candidate_head: $candidate_head,
    verdict: $verdict,
    codex_exit_status: $codex_exit_status,
    integrity: {
      candidate_manifest: {before: $candidate_before, after: $candidate_after},
      codex_launcher: {before: $codex_before, after: $codex_after},
      codex_runtime: {before: $runtime_before, after: $runtime_after},
      isolation_config: {before: $config_before, after: $config_after}
    },
    evidence: {
      result_sha256: $result_sha256,
      chronological_transcript_sha256: $transcript_sha256,
      raw_codex_transcript_sha256: $raw_transcript_sha256,
      final_message_sha256: $final_message_sha256
    }
  }' > "$isolation_root/RUN.json"
install -m 0600 "$isolation_root/RUN.json" "$evidence_root/RUN.json"

printf 'probe_dir=%s\n' "$probe_root"
printf 'evidence_dir=%s\n' "$evidence_root"
printf 'verdict=%s\n' "$verdict"

[ "$verdict" = "BASELINE PASS" ] || exit 3

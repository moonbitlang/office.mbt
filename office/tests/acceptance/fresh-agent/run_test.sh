#!/bin/bash -p
# This test intentionally emits fixture scripts from single-quoted literals.
# shellcheck disable=SC2016

case "$-" in
  *p*) ;;
  *)
    echo "error: execute run_test.sh directly so Bash privileged mode can ignore BASH_ENV" >&2
    exit 2
    ;;
esac

set -euo pipefail
umask 077

PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
unset BASH_ENV ENV CDPATH NODE_OPTIONS
unset DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH LD_PRELOAD LD_LIBRARY_PATH
unset PERL5OPT PERL5LIB TAR_OPTIONS POSIXLY_CORRECT BLOCKSIZE

script_dir="$(
  unset CDPATH
  cd -P -- "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")" >/dev/null
  pwd -P
)"
root="$(
  unset CDPATH
  cd -P -- "$script_dir/../../../.." >/dev/null
  pwd -P
)"
head="$(/usr/bin/git -C "$root" rev-parse --verify HEAD)"
git_common_dir="$(/usr/bin/git -C "$root" rev-parse --git-common-dir)"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$root/$git_common_dir" ;;
esac
git_common_dir="$(
  unset CDPATH
  cd -P -- "$git_common_dir" >/dev/null
  pwd -P
)"

if [ "$(/usr/bin/uname -s)" = "Linux" ]; then
  test_tmp_root=/var/tmp
else
  test_tmp_root="${TMPDIR:-/tmp}"
fi
test_root="$(/usr/bin/mktemp -d "$test_tmp_root/office-f1b-runner.XXXXXX")"
chmod 0700 "$test_root"
linux_tmp_parent=""

cleanup() {
  local status="$1"
  trap - EXIT HUP INT TERM
  if [ "${OFFICE_F1B_KEEP_TEST_ROOT:-0}" = "1" ]; then
    echo "kept fresh-agent test root: $test_root" >&2
    exit "$status"
  fi
  chmod -R u+w -- "$test_root" 2>/dev/null || true
  /bin/rm -rf -- "$test_root"
  if [ -n "$linux_tmp_parent" ] && [ -d "$linux_tmp_parent" ]; then
    chmod -R u+w -- "$linux_tmp_parent" 2>/dev/null || true
    /bin/rm -rf -- "$linux_tmp_parent"
  fi
  exit "$status"
}
trap 'cleanup $?' EXIT
trap 'cleanup 129' HUP
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

fail() {
  echo "FRESH-AGENT RUNNER TEST FAIL: $*" >&2
  exit 1
}

sha256_file() {
  /usr/bin/shasum -a 256 "$1" |
    /usr/bin/awk '{print substr($1, length($1) - 63)}'
}

/usr/bin/jq -e '
  .properties.targets.type == "object" and
  .properties.gaps.type == "array" and
  .properties.result_path.type == "string" and
  (.properties | has("transcript_path") | not)
' "$script_dir/final.schema.json" >/dev/null ||
  fail "structured output schema has strict target and gap evidence"

inventory_root_a="$test_root/inventory-a"
inventory_root_b="$test_root/inventory-relocated-longer"
/bin/mkdir -m 0700 \
  "$inventory_root_a" \
  "$inventory_root_b" \
  "$inventory_root_a/lib" \
  "$inventory_root_b/lib"
/bin/mkdir -p -m 0700 \
  "$inventory_root_a/lib/core/_build/native/release/bundle" \
  "$inventory_root_b/lib/core/_build/native/release/bundle"
inventory_root_a="$(
  unset CDPATH
  cd -P -- "$inventory_root_a" >/dev/null
  pwd -P
)"
inventory_root_b="$(
  unset CDPATH
  cd -P -- "$inventory_root_b" >/dev/null
  pwd -P
)"
printf '{"root":"%s"}\n' "$inventory_root_a" \
  > "$inventory_root_a/lib/core/_build/packages.json"
printf '{"root":"%s"}\n' "$inventory_root_a" \
  > "$inventory_root_b/lib/core/_build/packages.json"
printf 'generated database A\n' \
  > "$inventory_root_a/lib/core/_build/native/release/bundle/bundle.moon_db"
printf 'different generated database B\n' \
  > "$inventory_root_b/lib/core/_build/native/release/bundle/bundle.moon_db"
printf 'stable payload\n' > "$inventory_root_a/payload.txt"
printf 'stable payload\n' > "$inventory_root_b/payload.txt"
"$script_dir/inventory.sh" \
  "$inventory_root_a" "$test_root/inventory-a.manifest" relocation \
  lib payload.txt
"$script_dir/inventory.sh" \
  "$inventory_root_b" "$test_root/inventory-b.manifest" relocation \
  --root-alias "$inventory_root_a" lib payload.txt
/usr/bin/cmp "$test_root/inventory-a.manifest" \
  "$test_root/inventory-b.manifest" >/dev/null ||
  fail "inventory manifest is not relocatable"
printf 'changed payload\n' > "$inventory_root_b/payload.txt"
"$script_dir/inventory.sh" \
  "$inventory_root_b" "$test_root/inventory-changed.manifest" relocation \
  --root-alias "$inventory_root_a" lib payload.txt
if /usr/bin/cmp -s "$test_root/inventory-a.manifest" \
  "$test_root/inventory-changed.manifest"; then
  fail "inventory normalization concealed a non-root content change"
fi
/bin/ln -s ../inventory-relocated-longer/payload.txt \
  "$inventory_root_a/external-link"
set +e
"$script_dir/inventory.sh" \
  "$inventory_root_a" "$test_root/inventory-external-rejected.manifest" \
  build-host external-link \
  >"$test_root/inventory-external.stdout" \
  2>"$test_root/inventory-external.stderr"
external_inventory_status="$?"
set -e
[ "$external_inventory_status" -eq 1 ] ||
  fail "external inventory symlink default policy"
/usr/bin/grep -q 'referent escaped its root' \
  "$test_root/inventory-external.stderr" ||
  fail "external inventory symlink rejection diagnostic"
"$script_dir/inventory.sh" \
  "$test_root" "$test_root/inventory-symlink-closure.manifest" \
  build-host inventory-a/external-link
/usr/bin/grep -Fq \
  $'L\t-\t-\t../inventory-relocated-longer/payload.txt\tinventory-a/external-link' \
  "$test_root/inventory-symlink-closure.manifest" ||
  fail "build-host symlink inventory"
/usr/bin/grep -Eq \
  $'^F\t[0-7]{4}\t[0-9]+\t[0-9a-f]{64}\tinventory-relocated-longer/payload.txt$' \
  "$test_root/inventory-symlink-closure.manifest" ||
  fail "build-host symlink referent inventory"
printf 'referent changed after inventory\n' > "$inventory_root_b/payload.txt"
"$script_dir/inventory.sh" \
  "$test_root" "$test_root/inventory-symlink-closure-changed.manifest" \
  build-host inventory-a/external-link
if /usr/bin/cmp -s \
  "$test_root/inventory-symlink-closure.manifest" \
  "$test_root/inventory-symlink-closure-changed.manifest"; then
  fail "build-host inventory did not bind a symlink referent"
fi

make_candidate() {
  local install_root="$1"
  local source_root="${2:-$root}"
  local common_dir="${3:-$git_common_dir}"
  local native_sha
  local wasm_wrapper_sha
  local moonrun_sha
  local wasm_sha
  local runner_sha
  local prompt_sha
  local schema_sha
  local canary_sha
  local private_sha
  local inventory_sha
  local build_lock_sha
  local toolchain_manifest_sha
  local dependency_manifest_sha
  local build_host_sha
  local build_host_manifest_sha
  local native_plan_sha
  local build_platform

  /bin/mkdir -m 0700 \
    "$install_root" \
    "$install_root/bin" \
    "$install_root/libexec" \
    "$install_root/control"
  printf '%s\n' \
    '#!/bin/sh' \
    'set -eu' \
    'case "${TMPDIR:-}" in */.office-f1b-isolation.*/tmp) ;; *) exit 70 ;; esac' \
    'case "${1:-}" in *.wasm) shift ;; esac' \
    'verb=${1:-help}' \
    'shift || true' \
    'raw_action=${1:-}' \
    'if [ "$verb" = help ]; then' \
    '  printf '\''{"data":{"schema":"office.capabilities/test","fingerprint":"test:fingerprint"}}\n'\''' \
    '  exit 0' \
    'fi' \
    'format=""; source_file=""; output_file=""; pending=""' \
    'for arg in "$@"; do' \
    '  case "$pending" in' \
    '    format) format=$arg; pending=""; continue ;;' \
    '    output) output_file=$arg; case "$arg" in *.xlsx) format=xlsx ;; *.docx) format=docx ;; esac; pending=""; continue ;;' \
    '  esac' \
    '  case "$arg" in' \
    '    --format) pending=format ;;' \
    '    --out|--output) pending=output ;;' \
    '    xlsx|docx) [ -n "$format" ] || format=$arg ;;' \
    '    *.xlsx) [ -n "$format" ] || format=xlsx; [ -n "$source_file" ] || source_file=$arg ;;' \
    '    *.docx) [ -n "$format" ] || format=docx; [ -n "$source_file" ] || source_file=$arg ;;' \
    '  esac' \
    'done' \
    '[ -n "$format" ] || exit 71' \
    'make_package() {' \
    '  package=$1' \
    '  case "$package" in /*) package_path=$package ;; *) package_path=$PWD/$package ;; esac' \
    '  /bin/mkdir -p "$(/usr/bin/dirname -- "$package_path")"' \
    '  package_tmp="$TMPDIR/fake-office-package-$$"' \
    '  /bin/rm -rf -- "$package_tmp"' \
    '  /bin/mkdir -m 0700 "$package_tmp" "$package_tmp/_rels"' \
    '  if [ "$format" = xlsx ]; then' \
    '    main_part=xl/workbook.xml' \
    '    main_content_type=application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml' \
    '    main_xml="<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"/>"' \
    '  else' \
    '    main_part=word/document.xml' \
    '    main_content_type=application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml' \
    '    main_xml="<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body/></w:document>"' \
    '  fi' \
    '  /bin/mkdir -p "$package_tmp/$(/usr/bin/dirname -- "$main_part")"' \
    '  printf "%s\n" "<?xml version=\"1.0\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Override PartName=\"/$main_part\" ContentType=\"$main_content_type\"/></Types>" > "$package_tmp/[Content_Types].xml"' \
    '  printf "%s\n" "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"$main_part\"/></Relationships>" > "$package_tmp/_rels/.rels"' \
    '  printf "%s\n" "$main_xml" > "$package_tmp/$main_part"' \
    '  (cd "$package_tmp" && /usr/bin/zip -q "$package_path" "[Content_Types].xml" "_rels/.rels" "$main_part")' \
    '  /bin/rm -rf -- "$package_tmp"' \
    '}' \
    '[ -n "$source_file" ] || source_file="fixture.$format"' \
    '[ -f "$source_file" ] || make_package "$source_file"' \
    'artifact=$source_file' \
    'case "$verb" in' \
    '  template|replay|annotate)' \
    '    [ -n "$output_file" ] || output_file="produced-$verb.$format"' \
    '    make_package "$output_file"' \
    '    artifact=$output_file' \
    '    ;;' \
    '  preview)' \
    '    [ -n "$output_file" ] || output_file=preview.html' \
    '    printf '\''<!doctype html><title>fake preview</title>\n'\'' > "$output_file"' \
    '    ;;' \
    'esac' \
    'case "$verb/$format" in' \
    '  create/xlsx) result_schema=office.xlsx.create/1 ;;' \
    '  batch/xlsx) result_schema=office.xlsx.batch/1 ;;' \
    '  batch/docx) result_schema=office.docx.batch/1 ;;' \
    '  identify/*) result_schema=office.identify/1 ;;' \
    '  outline/xlsx) result_schema=office.xlsx.outline/1 ;;' \
    '  outline/docx) result_schema=office.docx.outline/1 ;;' \
    '  get/xlsx) result_schema=office.xlsx.element/1 ;;' \
    '  get/docx) result_schema=office.docx.element/1 ;;' \
    '  text/xlsx) result_schema=office.xlsx.text/1 ;;' \
    '  text/docx) result_schema=office.docx.text/1 ;;' \
    '  query/xlsx) result_schema=office.xlsx.query/1 ;;' \
    '  query/docx) result_schema=office.docx.query/1 ;;' \
    '  validate/*) result_schema=office.validate/1 ;;' \
    '  issues/*) result_schema=office.issues/1 ;;' \
    '  preview/*) result_schema=office.preview/1 ;;' \
    '  template/*) result_schema=office.template/1 ;;' \
    '  dump/*) result_schema=office.dump/1 ;;' \
    '  replay/*) result_schema=office.replay/1 ;;' \
    '  raw/xlsx) result_schema=office.raw.inventory/1 ;;' \
    '  raw/docx) if [ "$raw_action" = list ]; then result_schema=office.raw.inventory/1; else result_schema=office.raw.part/1; fi ;;' \
    '  annotate/docx) result_schema=office.docx.annotation-batch/1 ;;' \
    '  *) exit 72 ;;' \
    'esac' \
    '/usr/bin/jq -cn --arg verb "$verb" --arg format "$format" --arg schema "$result_schema" --arg source "$source_file" --arg output "$artifact" --arg produced "$output_file" '\''if $verb == "dump" then {schema:$schema,format:$format,source:{file:$source},ops:[{}]} else {schema:"office.output/1",success:true,data:({schema:$schema,format:$format} + if $verb == "create" or $verb == "batch" then {transaction:{format:$format,output:$output,committed:true,dry_run:false,changed:true}} elif $verb == "identify" then {file:$source} elif $verb == "outline" or $verb == "get" then {file:$source,path:"/"} elif $verb == "text" or $verb == "query" then {file:$source,returned:1} elif $verb == "validate" or $verb == "issues" then {file:$source,valid:true,error_count:0} elif $verb == "preview" then {file:$source,output:$produced,bytes_written:1} elif $verb == "template" then {output:$output,replaced:1,transaction:{committed:true}} elif $verb == "replay" then {output:$output,bytes_written:1,ops_applied:1} elif $verb == "raw" and $schema == "office.raw.inventory/1" then {part_count:1} elif $verb == "raw" and $format == "docx" then {content:"<document/>"} elif $verb == "annotate" then {output:$output,ops_applied:1,transaction:{committed:true}} else {} end)} end'\''' \
    > "$install_root/bin/office-native"
  /usr/bin/install -m 0500 "$script_dir/office-wasm" \
    "$install_root/bin/office-wasm"
  /bin/cp "$install_root/bin/office-native" "$install_root/libexec/moonrun"
  printf 'fake wasm\n' > "$install_root/libexec/office.wasm"
  /usr/bin/install -m 0500 "$script_dir/run.sh" \
    "$install_root/control/run.sh"
  /usr/bin/install -m 0400 "$script_dir/prompt.md" \
    "$install_root/control/prompt.md"
  /usr/bin/install -m 0400 "$script_dir/final.schema.json" \
    "$install_root/control/final.schema.json"
  /usr/bin/install -m 0500 "$script_dir/permission-canary.sh" \
    "$install_root/control/permission-canary.sh"
  /usr/bin/install -m 0500 "$script_dir/inventory.sh" \
    "$install_root/control/inventory.sh"
  chmod 0500 \
    "$install_root/bin/office-native" \
    "$install_root/libexec/moonrun"
  chmod 0400 "$install_root/libexec/office.wasm"
  /bin/ln -s office-native "$install_root/bin/office"

  /usr/bin/jq -n \
    --arg schema "office.fresh-agent.private/1" \
    --arg source_root "$source_root" \
    --arg git_common_dir "$common_dir" \
    '{
      schema: $schema,
      source_root: $source_root,
      git_common_dir: $git_common_dir
    }' > "$install_root/control/private.json"
  chmod 0400 "$install_root/control/private.json"

  case "$(/usr/bin/uname -s) $(/usr/bin/uname -m)" in
    "Darwin arm64") build_platform=darwin-arm64 ;;
    "Linux x86_64") build_platform=linux-x86_64 ;;
    *) fail "unsupported runner-test platform" ;;
  esac
  printf 'office.fresh-agent.tree-manifest/1\t%s\n' "$build_platform" \
    > "$install_root/control/toolchain.manifest"
  printf 'office.fresh-agent.tree-manifest/1\tdependencies\n' \
    > "$install_root/control/dependencies.manifest"
  chmod 0400 \
    "$install_root/control/toolchain.manifest" \
    "$install_root/control/dependencies.manifest"
  toolchain_manifest_sha="$(
    sha256_file "$install_root/control/toolchain.manifest"
  )"
  dependency_manifest_sha="$(
    sha256_file "$install_root/control/dependencies.manifest"
  )"
  /usr/bin/jq -n \
    --arg schema "office.fresh-agent.build-lock/1" \
    --arg platform "$build_platform" \
    --arg toolchain_sha "$toolchain_manifest_sha" \
    --arg dependency_sha "$dependency_manifest_sha" \
    '{
      schema: $schema,
      dependencies: {entries: ["fixture"], manifest_sha256: $dependency_sha},
      toolchains: [{
        platform: $platform,
        entries: ["fixture"],
        manifest_sha256: $toolchain_sha,
        moon_version: "fake-moon 1",
        moonc_version: "fake-moonc 1",
        moonrun_version: "fake-moonrun 1"
      }]
    }' > "$install_root/control/build-lock.json"
  chmod 0400 "$install_root/control/build-lock.json"

  printf '%s\n' \
    "office.fresh-agent.tree-manifest/1"$'\t'"build-host" \
    'F	0444	7	eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee	sdk/header.h' \
    > "$install_root/control/build-host.manifest"
  chmod 0400 "$install_root/control/build-host.manifest"
  build_host_manifest_sha="$(
    sha256_file "$install_root/control/build-host.manifest"
  )"
  native_plan_sha="$(
    printf '%s\n' \
      '/usr/bin/cc -c fixture.c -o fixture.o' \
      '/usr/bin/ar -r -c -s libfixture.a fixture.o' |
      /usr/bin/shasum -a 256 |
      /usr/bin/awk '{print substr($1, length($1) - 63)}'
  )"
  /usr/bin/jq -n \
    --arg schema "office.fresh-agent.build-host/1" \
    --arg platform "$build_platform" \
    --arg manifest_sha "$build_host_manifest_sha" \
    --arg plan_sha "$native_plan_sha" \
    '{
      schema: $schema,
      platform: $platform,
      environment: {
        moon_cc: "/usr/bin/cc",
        moon_ar: "/usr/bin/ar",
        sdkroot: (if $platform == "darwin-arm64" then "/fixture/sdk" else null end)
      },
      host: {
        kernel: "fixture-kernel",
        identity_path: "/fixture/os-release",
        identity_sha256: ("1" * 64)
      },
      compiler: {
        selected_path: "/usr/bin/cc",
        resolved_path: "/usr/bin/cc",
        sha256: ("2" * 64),
        version: "fixture cc 1",
        target: (if $platform == "darwin-arm64"
          then "arm64-apple-darwin" else "x86_64-linux-gnu" end),
        resource_dir: "/fixture/compiler/include"
      },
      archiver: {
        selected_path: "/usr/bin/ar",
        resolved_path: "/usr/bin/ar",
        sha256: ("3" * 64)
      },
      linker: {
        resolved_path: "/usr/bin/ld",
        sha256: ("4" * 64),
        version: "fixture ld 1"
      },
      assembler: {
        resolved_path: "/usr/bin/as",
        sha256: ("5" * 64)
      },
      sdk: {
        kind: (if $platform == "darwin-arm64"
          then "macos-sdk" else "linux-sysroot" end),
        path: (if $platform == "darwin-arm64" then "/fixture/sdk" else "/" end),
        version: "fixture-sdk-1"
      },
      inventory: {
        root: "/",
        entries: ["fixture/sdk"],
        manifest_sha256: $manifest_sha
      },
      native_plan: {
        sha256: $plan_sha,
        commands: [
          "/usr/bin/cc -c fixture.c -o fixture.o",
          "/usr/bin/ar -r -c -s libfixture.a fixture.o"
        ]
      }
    }' > "$install_root/control/build-host.json"
  chmod 0400 "$install_root/control/build-host.json"
  build_host_sha="$(sha256_file "$install_root/control/build-host.json")"

  native_sha="$(sha256_file "$install_root/bin/office-native")"
  wasm_wrapper_sha="$(sha256_file "$install_root/bin/office-wasm")"
  moonrun_sha="$(sha256_file "$install_root/libexec/moonrun")"
  wasm_sha="$(sha256_file "$install_root/libexec/office.wasm")"
  runner_sha="$(sha256_file "$install_root/control/run.sh")"
  prompt_sha="$(sha256_file "$install_root/control/prompt.md")"
  schema_sha="$(sha256_file "$install_root/control/final.schema.json")"
  canary_sha="$(sha256_file "$install_root/control/permission-canary.sh")"
  private_sha="$(sha256_file "$install_root/control/private.json")"
  inventory_sha="$(sha256_file "$install_root/control/inventory.sh")"
  build_lock_sha="$(sha256_file "$install_root/control/build-lock.json")"

  /usr/bin/jq -n \
    --arg schema "office.fresh-agent.candidate/4" \
    --arg candidate_head "$head" \
    --arg build_platform "$build_platform" \
    --arg build_lock_sha "$build_lock_sha" \
    --arg toolchain_manifest_sha "$toolchain_manifest_sha" \
    --arg dependency_manifest_sha "$dependency_manifest_sha" \
    --arg build_host_sha "$build_host_sha" \
    --arg build_host_manifest_sha "$build_host_manifest_sha" \
    --arg native_sha "$native_sha" \
    --arg wasm_wrapper_sha "$wasm_wrapper_sha" \
    --arg moonrun_sha "$moonrun_sha" \
    --arg wasm_sha "$wasm_sha" \
    --arg runner_sha "$runner_sha" \
    --arg prompt_sha "$prompt_sha" \
    --arg schema_sha "$schema_sha" \
    --arg canary_sha "$canary_sha" \
    --arg private_sha "$private_sha" \
    --arg inventory_sha "$inventory_sha" \
    '{
      schema: $schema,
      candidate_head: $candidate_head,
      build: {
        source_tree: ("c" * 40),
        platform: $build_platform,
        build_lock_sha256: $build_lock_sha,
        toolchain_manifest_sha256: $toolchain_manifest_sha,
        dependency_manifest_sha256: $dependency_manifest_sha,
        build_host_sha256: $build_host_sha,
        build_host_manifest_sha256: $build_host_manifest_sha,
        moon_version: "fake-moon 1",
        moon_sha256: ("a" * 64),
        moonc_version: "fake-moonc 1",
        moonc_sha256: ("d" * 64),
        moonrun_version: "fake-moonrun 1"
      },
      files: [
        {path: "bin/office-native", kind: "file", mode: "0500", sha256: $native_sha},
        {path: "bin/office-wasm", kind: "file", mode: "0500", sha256: $wasm_wrapper_sha},
        {path: "libexec/moonrun", kind: "file", mode: "0500", sha256: $moonrun_sha},
        {path: "libexec/office.wasm", kind: "file", mode: "0400", sha256: $wasm_sha},
        {path: "control/run.sh", kind: "file", mode: "0500", sha256: $runner_sha},
        {path: "control/prompt.md", kind: "file", mode: "0400", sha256: $prompt_sha},
        {path: "control/final.schema.json", kind: "file", mode: "0400", sha256: $schema_sha},
        {path: "control/permission-canary.sh", kind: "file", mode: "0500", sha256: $canary_sha},
        {path: "control/private.json", kind: "file", mode: "0400", sha256: $private_sha},
        {path: "control/inventory.sh", kind: "file", mode: "0500", sha256: $inventory_sha},
        {path: "control/build-lock.json", kind: "file", mode: "0400", sha256: $build_lock_sha},
        {path: "control/toolchain.manifest", kind: "file", mode: "0400", sha256: $toolchain_manifest_sha},
        {path: "control/dependencies.manifest", kind: "file", mode: "0400", sha256: $dependency_manifest_sha},
        {path: "control/build-host.json", kind: "file", mode: "0400", sha256: $build_host_sha},
        {path: "control/build-host.manifest", kind: "file", mode: "0400", sha256: $build_host_manifest_sha}
      ],
      symlinks: [
        {path: "bin/office", target: "office-native"}
      ]
    }' > "$install_root/CANDIDATE.json"
  chmod 0400 "$install_root/CANDIDATE.json"
  chmod 0500 \
    "$install_root/bin" \
    "$install_root/libexec" \
    "$install_root/control" \
    "$install_root"
}

case_root="$test_root/space = case"
/bin/mkdir -m 0700 "$case_root"
install_root="$case_root/install"
make_candidate "$install_root"
candidate_sha="$(sha256_file "$install_root/CANDIDATE.json")"
printf '{}\n' > "$case_root/auth.json"
chmod 0600 "$case_root/auth.json"

codex_bin_dir="$test_root/codex=bin"
/bin/mkdir -m 0700 "$codex_bin_dir"
printf 'pass\n' > "$codex_bin_dir/mode"
chmod 0600 "$codex_bin_dir/mode"

{
  printf '%s\n' '#!/bin/sh' 'set -eu'
  printf 'mode_file=%q\n' "$codex_bin_dir/mode"
  printf '%s\n' \
    'mode=$(/bin/cat "$mode_file")' \
    'if [ "${1:-}" = "--version" ]; then' \
    '  if [ "$mode" = "version-hang" ]; then trap "" HUP INT TERM; while :; do /bin/sleep 1; done; fi' \
    '  if [ "$mode" = "old-version" ]; then echo "codex-cli 0.144.9"; elif [ "$mode" = "prerelease-version" ]; then echo "codex-cli 0.145.0-rc.1"; else echo "codex-cli 0.145.0"; fi' \
    '  exit 0' \
    'fi' \
    'config="$CODEX_HOME/config.toml"' \
    'test -f "$config"' \
    '/usr/bin/grep -q '\''^default_permissions = "fresh_agent"$'\'' "$config"' \
    '/usr/bin/grep -q '\''^web_search = "disabled"$'\'' "$config"' \
    'if /usr/bin/grep -q '\''^web_search = false$'\'' "$config"; then exit 66; fi' \
    '/usr/bin/grep -q '\''^hooks = {}$'\'' "$config"' \
    '/usr/bin/grep -q '\''^mcp_servers = {}$'\'' "$config"' \
    '/usr/bin/grep -q '\''^":minimal" = "read"$'\'' "$config"' \
    'if /usr/bin/grep -q '\''^":tmpdir" = '\'' "$config"; then exit 65; fi' \
    'codex_home_key=$(/usr/bin/jq -Rn --arg value "$CODEX_HOME" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "$codex_home_key = \"deny\"" "$config"' \
    'isolation_root=$(CDPATH= cd -- "$CODEX_HOME/.." && pwd)' \
    'policy_readonly="$isolation_root/policy-readonly"' \
    'test -d "$policy_readonly"' \
    'test -w "$policy_readonly"' \
    'policy_readonly_key=$(/usr/bin/jq -Rn --arg value "$policy_readonly" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "$policy_readonly_key = \"read\"" "$config"' \
    'child_tmp="$isolation_root/tmp"' \
    'test "$TMPDIR" = "$CODEX_HOME/runtime-tmp"' \
    'test "$TMPDIR" != "$child_tmp"' \
    'runtime_tmp_key=$(/usr/bin/jq -Rn --arg value "$TMPDIR" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "TMPDIR = $runtime_tmp_key" "$config"' \
    'child_tmp_key=$(/usr/bin/jq -Rn --arg value "$child_tmp" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "$child_tmp_key = \"write\"" "$config"' \
    'probe_path="$isolation_root/launcher-bin:$isolation_root/candidate/bin:/usr/bin:/bin:/usr/sbin:/sbin"' \
    'probe_path_key=$(/usr/bin/jq -Rn --arg value "$probe_path" '\''$value'\'')' \
    '/usr/bin/grep -Fqx "PATH = $probe_path_key" "$config"' \
    'PATH=$probe_path; export PATH' \
    '/usr/bin/grep -q '\''candidate" = "read"$'\'' "$config"' \
    '/usr/bin/grep -q '\''candidate/CANDIDATE.json" = "deny"$'\'' "$config"' \
    '/usr/bin/grep -q '\''codex-bin" = "read"$'\'' "$config"' \
    '/usr/bin/grep -q '\''codex-resources" = "deny"$'\'' "$config"' \
    'if /usr/bin/grep -q '\''":root"'\'' "$config"; then exit 61; fi' \
    'if [ "$(/usr/bin/uname -s)" = "Linux" ]; then /usr/bin/grep -q '\''^"/etc" = "deny"$'\'' "$config"; fi' \
    'test -z "${OPENAI_API_KEY+x}"' \
    'test -z "${GITHUB_TOKEN+x}"' \
    'command="${1:-}"' \
    'shift || true' \
    'if [ "$command" = "sandbox" ]; then' \
    '  case " $* " in *" --include-managed-config "*) ;; *) exit 62 ;; esac' \
    '  case " $* " in *" -P fresh_agent "*) ;; *) exit 63 ;; esac' \
    '  if [ "$mode" = "canary-hang" ]; then trap "" HUP INT TERM; while :; do /bin/sleep 1; done; fi' \
    '  if [ "$mode" = "sandbox-fail" ]; then echo "sandbox diagnostic" >&2; exit 41; fi' \
    '  if [ "$mode" = "unreadable-policy" ]; then chmod 0300 "$policy_readonly"; fi' \
    '  if [ "$mode" = "dead-listener" ]; then' \
    '    ancestor=$PPID; listener_pid=' \
    '    for ancestor_hop in 1 2 3; do' \
    '      listener_pid=$(/bin/ps -axo pid=,ppid=,args= | /usr/bin/awk -v parent="$ancestor" '\''$2 == parent && / -l -k 127[.]0[.]0[.]1 / { print $1; exit }'\'')' \
    '      test -z "$listener_pid" || break' \
    '      ancestor=$(/bin/ps -o ppid= -p "$ancestor" | /usr/bin/tr -d " ")' \
    '      test -n "$ancestor" || break' \
    '    done' \
    '    test -n "$listener_pid"' \
    '    /bin/kill "$listener_pid"' \
    '  fi' \
    '  /bin/mkdir -p "$TMPDIR/codex-bwrap-synthetic-mount-targets-fake"' \
    '  : > "$TMPDIR/codex-bwrap-synthetic-mount-targets-fake/lock"' \
    '  printf "FRESH-AGENT PERMISSION CANARY PASS\\n"' \
    '  exit 0' \
    'fi' \
    'test "$command" = "exec"' \
    'if [ "$mode" = "orphan-child" ]; then' \
    '  (trap "" HUP INT TERM; while :; do /bin/sleep 1; done) &' \
    '  printf "%s\n" "$!" > "$mode_file.child-pid"' \
    '  exit 0' \
    'fi' \
    'if [ "$mode" = "probe-hang" ]; then' \
    '  trap "" HUP INT TERM' \
    '  while :; do /bin/sleep 1; done' \
    'fi' \
    'if [ "$mode" = "ignore-term" ]; then' \
    '  printf "%s\n" "$$" > "$mode_file.child-pid"' \
    '  chmod 0500 "$CODEX_HOME"' \
    '  trap "" HUP INT TERM' \
    '  while :; do /bin/sleep 1; done' \
    'fi' \
    'ephemeral=0; strict=0; json=0; ignore_rules=0; skip_git=0' \
    'probe=""; output=""; schema=""; model=""; reasoning=""; permission=""' \
    'while [ "$#" -gt 0 ]; do' \
    '  case "$1" in' \
    '    --ephemeral) ephemeral=1; shift ;;' \
    '    --strict-config) strict=1; shift ;;' \
    '    --json) json=1; shift ;;' \
    '    --ignore-rules) ignore_rules=1; shift ;;' \
    '    --skip-git-repo-check) skip_git=1; shift ;;' \
    '    -C) probe=$2; shift 2 ;;' \
    '    --output-last-message) output=$2; shift 2 ;;' \
    '    --output-schema) schema=$2; shift 2 ;;' \
    '    -m) model=$2; shift 2 ;;' \
    '    -c)' \
    '      case "$2" in model_reasoning_effort=*) reasoning=$2 ;; default_permissions=*) permission=$2 ;; esac' \
    '      shift 2' \
    '      ;;' \
    '    -) shift; /bin/cat > "$probe/prompt-seen.txt"; break ;;' \
    '    *) exit 64 ;;' \
    '  esac' \
    'done' \
    'test "$ephemeral$strict$json$ignore_rules$skip_git" = "11111"' \
    'test "$model" = "gpt-5.6-sol"' \
    'test "$reasoning" = '\''model_reasoning_effort="max"'\''' \
    'test "$permission" = '\''default_permissions="fresh_agent"'\''' \
    'test -d "$probe"' \
    'test -f "$schema"' \
    'test -n "$output"' \
    '/usr/bin/grep -q "office-permission-canary" "$probe/prompt-seen.txt"' \
    'candidate=$(CDPATH= cd -- "$(/usr/bin/dirname "$schema")/.." && pwd)' \
    'cd "$probe"' \
    'emit_started() {' \
    '  id=$1; cmd=$2' \
    '  /usr/bin/jq -cn --arg id "$id" --arg cmd "$cmd" '\''{type:"item.started",item:{id:$id,type:"command_execution",command:$cmd,aggregated_output:"",exit_code:null,status:"in_progress"}}'\''' \
    '}' \
    'emit_completed() {' \
    '  id=$1; cmd=$2; status=$3; body=$4' \
    '  /usr/bin/jq -cn --arg id "$id" --arg cmd "$cmd" --arg body "$body" --argjson status "$status" '\''{type:"item.completed",item:{id:$id,type:"command_execution",command:$cmd,aggregated_output:$body,exit_code:$status,status:(if $status == 0 then "completed" else "failed" end)}}'\''' \
    '}' \
    '/usr/bin/jq -cn '\''{type:"thread.started",thread_id:"fake-thread"}'\''' \
    '/usr/bin/jq -cn '\''{type:"turn.started"}'\''' \
    'if [ "$mode" = "pre-canary" ]; then' \
    '  emit_started pre-canary "true"' \
    '  emit_completed pre-canary "true" 0 ""' \
    'fi' \
    'emit_started canary "/bin/sh -c '\''office-permission-canary'\''"' \
    'canary_body=$(/usr/bin/printf "FRESH-AGENT PERMISSION CANARY PASS\\n_")' \
    'canary_body=${canary_body%_}' \
    'emit_completed canary "/bin/sh -c '\''office-permission-canary'\''" 0 "$canary_body"' \
    'if [ "$mode" = "completion-before-start" ]; then' \
    '  emit_completed lifecycle-order "true" 0 ""' \
    '  emit_started lifecycle-order "true"' \
    'fi' \
    'if [ "$mode" = "fractional-exit" ]; then' \
    '  emit_started fractional-exit "true"' \
    '  /usr/bin/jq -cn '\''{type:"item.completed",item:{id:"fractional-exit",type:"command_execution",command:"true",aggregated_output:"",exit_code:0.5,status:"completed"}}'\''' \
    'fi' \
    'if [ "$mode" = "out-of-domain-exit" ]; then' \
    '  emit_started out-of-domain-exit "false"' \
    '  emit_completed out-of-domain-exit "false" 256 ""' \
    'fi' \
    'emit_started expected-refusal "false"' \
    'emit_completed expected-refusal "false" 1 ""' \
    'if [ "$mode" = "detaching-command" ]; then' \
    '  emit_started detached "setsid /bin/sleep 60"' \
    '  emit_completed detached "setsid /bin/sleep 60" 0 ""' \
    'fi' \
    'stop_after=' \
    'case "$mode" in' \
    '  spoof-office|missing-create|pre-canary|completion-before-start|fractional-exit|out-of-domain-exit|missing-turn-completed|turn-failed|detaching-command) stop_after=all/help ;;' \
    '  format-redirection-spoof|newline-mask|help-only|comment-spoof|uppercase-result-path|wrong-result-schema|invalid-artifact|generic-zip-artifact|decoy-opc-root|nested-content-types|nested-relationships|oversized-zip-entry|zip-symlink-artifact) stop_after=native/xlsx/create ;;' \
    '  duplicate-result-path|aliased-result-parent|reused-event-id) stop_after=native/xlsx/batch ;;' \
    '  input-redirection|cross-format) stop_after=native/xlsx/validate ;;' \
    'esac' \
    'if [ "$mode" != "no-office" ]; then' \
    '  index=0' \
    '  for runtime in native wasm; do' \
    '    index=$((index + 1))' \
    '    if [ "$mode" = "spoof-office" ]; then cmd="echo office-$runtime help all --json"; else cmd="office-$runtime help all --json"; fi' \
    '    emit_started "cmd-$index" "$cmd"' \
    '    if [ "$mode" = "spoof-office" ]; then body="spoof"; status=0; else body=$("office-$runtime" help all --json 2>&1); status=$?; fi' \
    '    emit_completed "cmd-$index" "$cmd" "$status" "$body"' \
    '  done' \
    '  if [ "$stop_after" != all/help ]; then' \
    '    for runtime in native wasm; do' \
    '    for format in xlsx docx; do' \
    '      if [ "$format" = "xlsx" ]; then verbs="create batch identify outline get text query validate issues preview template dump replay raw"; else verbs="batch identify outline get text query validate issues preview template dump replay raw annotate"; fi' \
    '      for verb in $verbs; do' \
    '        if [ "$mode" = "missing-create" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then continue; fi' \
    '        index=$((index + 1))' \
    '        package="$runtime-$format-base.$format"' \
    '        produced="$runtime-$format-$verb.$format"' \
    '        preview="$runtime-$format-preview.html"' \
    '        case "$verb/$format" in' \
    '          create/xlsx) run_args="xlsx $package" ;;' \
    '          batch/docx) run_args="--format docx $package fixture.json" ;;' \
    '          batch/xlsx) run_args="$package fixture.json" ;;' \
    '          preview/*) run_args="$package --output $preview" ;;' \
    '          template/*|annotate/*) run_args="$package fixture.json --out $produced" ;;' \
    '          replay/*) run_args="fixture.json --output $produced" ;;' \
    '          raw/xlsx) run_args="list $package" ;;' \
    '          raw/docx) run_args="read $package part:/document" ;;' \
    '          *) run_args="$package" ;;' \
    '        esac' \
    '        result="$runtime-$format-$verb-$index.json"' \
    '        if [ "$mode" = "aliased-result-parent" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then /bin/mkdir -m 0700 results; /bin/ln -s results aliases; result=results/create.json; fi' \
    '        if [ "$mode" = "aliased-result-parent" ] && [ "$runtime/$format/$verb" = "native/xlsx/batch" ]; then result=aliases/batch.json; fi' \
    '        if [ "$mode" = "duplicate-result-path" ] && { [ "$runtime/$format/$verb" = "native/xlsx/create" ] || [ "$runtime/$format/$verb" = "native/xlsx/batch" ]; }; then result=duplicate-result.json; fi' \
    '        if [ "$mode" = "uppercase-result-path" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then result=Uppercase-result.json; fi' \
    '        if [ "$mode" = "spoof-office" ]; then cmd="echo office-$runtime $verb $run_args --json > $result"; else cmd="office-$runtime $verb $run_args --json > $result"; fi' \
    '        if [ "$mode" = "format-redirection-spoof" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then cmd="office-native create missing-target --json > proof.xlsx"; fi' \
    '        if [ "$mode" = "newline-mask" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then cmd=$(/usr/bin/printf "office-native create xlsx sample.xlsx --json > result.json\\ntrue"); fi' \
    '        if [ "$mode" = "help-only" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then cmd="office-native create --help proof.xlsx --json > $result"; fi' \
    '        if [ "$mode" = "input-redirection" ] && [ "$runtime/$format/$verb" = "native/xlsx/validate" ]; then cmd="office-native validate real.docx --json < claimed.xlsx > $result"; fi' \
    '        if [ "$mode" = "comment-spoof" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then cmd="office-native create xlsx proof.xlsx # attested --json > $result"; fi' \
    '        if [ "$mode" = "cross-format" ] && [ "$runtime/$format/$verb" = "native/xlsx/validate" ]; then cmd="office-native validate real.docx claimed.xlsx --json > $result"; fi' \
    '        event_id="cmd-$index"' \
    '        if [ "$mode" = "reused-event-id" ] && { [ "$runtime/$format/$verb" = "native/xlsx/create" ] || [ "$runtime/$format/$verb" = "native/xlsx/batch" ]; }; then event_id=reused-workflow; fi' \
    '        emit_started "$event_id" "$cmd"' \
    '        if [ "$mode" = "spoof-office" ]; then body="spoof"; status=0; else' \
    '          set +e' \
    '          "office-$runtime" "$verb" $run_args --json > "$result" 2> "$result.stderr"' \
    '          status=$?' \
    '          set -e' \
    '          body=$(/bin/cat "$result.stderr")' \
    '          /bin/rm -f "$result.stderr"' \
    '        fi' \
    '        emit_completed "$event_id" "$cmd" "$status" "$body"' \
    '        if [ "$stop_after" = "$runtime/$format/$verb" ]; then break 3; fi' \
    '        if [ "$mode" != "spoof-office" ] && [ "$runtime/$format/$verb" = "native/docx/raw" ]; then' \
    '          index=$((index + 1))' \
    '          extra_result=native-docx-raw-inventory-extra.json' \
    '          extra_cmd="office-native raw list $package --json > $extra_result"' \
    '          emit_started "cmd-$index" "$extra_cmd"' \
    '          set +e' \
    '          office-native raw list "$package" --json > "$extra_result" 2> "$extra_result.stderr"' \
    '          extra_status=$?' \
    '          set -e' \
    '          extra_body=$(/bin/cat "$extra_result.stderr")' \
    '          /bin/rm -f "$extra_result.stderr"' \
    '          emit_completed "cmd-$index" "$extra_cmd" "$extra_status" "$extra_body"' \
    '        fi' \
    '      done' \
    '    done' \
    '  done' \
    '  fi' \
    'fi' \
    'if [ "$mode" = "wrong-result-schema" ]; then printf '\''{"schema":"office.output/1","success":true,"data":{"schema":"office.identify/1","format":"xlsx","file":"native-xlsx-base.xlsx"}}\n'\'' > native-xlsx-create-3.json; fi' \
    'if [ "$mode" = "invalid-artifact" ]; then printf '\''not an Office package\n'\'' > native-xlsx-base.xlsx; fi' \
    'if [ "$mode" = "generic-zip-artifact" ]; then /bin/rm -f native-xlsx-base.xlsx; printf '\''payload\n'\'' > generic-payload.txt; /usr/bin/zip -q native-xlsx-base.xlsx generic-payload.txt; fi' \
    'if [ "$mode" = "decoy-opc-root" ] || [ "$mode" = "nested-content-types" ] || [ "$mode" = "nested-relationships" ]; then' \
    '  package_path=$PWD/native-xlsx-base.xlsx' \
    '  opc_tmp=$TMPDIR/adversarial-opc-$$' \
    '  /bin/rm -rf -- "$opc_tmp"' \
    '  /bin/mkdir -m 0700 "$opc_tmp"' \
    '  /usr/bin/unzip -q "$package_path" -d "$opc_tmp"' \
    '  if [ "$mode" = "decoy-opc-root" ]; then printf "%s\n" '\''<decoy><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"/></decoy>'\'' > "$opc_tmp/xl/workbook.xml"; fi' \
    '  if [ "$mode" = "nested-content-types" ]; then printf "%s\n" '\''<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Wrapper><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Wrapper></Types>'\'' > "$opc_tmp/[Content_Types].xml"; fi' \
    '  if [ "$mode" = "nested-relationships" ]; then printf "%s\n" '\''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Wrapper><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Wrapper></Relationships>'\'' > "$opc_tmp/_rels/.rels"; fi' \
    '  /bin/rm -f -- "$package_path"' \
    '  (cd "$opc_tmp" && /usr/bin/zip -q "$package_path" "[Content_Types].xml" "_rels/.rels" "xl/workbook.xml")' \
    '  /bin/rm -rf -- "$opc_tmp"' \
    'fi' \
    'if [ "$mode" = "oversized-zip-entry" ]; then' \
    '  /bin/dd if=/dev/zero of=oversized.bin bs=1048576 count=65 2>/dev/null' \
    '  /usr/bin/zip -q native-xlsx-base.xlsx oversized.bin' \
    '  /bin/rm -f oversized.bin' \
    'fi' \
    'if [ "$mode" = "zip-symlink-artifact" ]; then' \
    '  : > symlink-target' \
    '  /bin/ln -s symlink-target package-link' \
    '  /usr/bin/zip -q -y native-xlsx-base.xlsx package-link' \
    '  /bin/rm -f package-link symlink-target' \
    'fi' \
    'if [ "$mode" = "exit19" ]; then exit 19; fi' \
    'verdict="BASELINE PASS"; outcome="PASS"; gaps="[]"' \
    'if [ "$mode" = "fail" ]; then verdict="BASELINE FAIL"; outcome="FAIL"; gaps='\''[{"severity":"P1","summary":"fake failure"}]'\''; fi' \
    'header="Verdict: $verdict"' \
    'if [ "$mode" = "contradictory" ]; then header="Verdict: BASELINE FAIL"; fi' \
    'if [ "$mode" = "incomplete-report" ]; then' \
    '  printf "%s\\n\\n# Probe result\\n" "$header" > "$probe/probe-result.md"' \
    'else' \
    '  printf "%s\\nNative XLSX: %s\\nNative DOCX: %s\\nWasm XLSX: %s\\nWasm DOCX: %s\\nCapability schema: office.capabilities/test\\nCapability fingerprint: test:fingerprint\\nDiscoverability: %s\\nNative/Wasm comparison: %s\\n\\n# Probe result\\n" "$header" "$outcome" "$outcome" "$outcome" "$outcome" "$outcome" "$outcome" > "$probe/probe-result.md"' \
    'fi' \
    'if [ "$mode" = "malformed" ]; then' \
    '  printf "{\\n" > "$output"' \
    'else' \
    '  /usr/bin/jq -n --arg verdict "$verdict" --arg outcome "$outcome" --argjson gaps "$gaps" '\''{verdict:$verdict,result_path:"probe-result.md",targets:{native:{xlsx:$outcome,docx:$outcome},wasm:{xlsx:$outcome,docx:$outcome}},gaps:$gaps}'\'' > "$output"' \
    'fi' \
    'if [ "$mode" = "turn-failed" ]; then' \
    '  /usr/bin/jq -cn '\''{type:"turn.failed",error:{message:"fixture"}}'\''' \
    'elif [ "$mode" != "missing-turn-completed" ]; then' \
    '  /usr/bin/jq -cn '\''{type:"turn.completed",usage:{input_tokens:1,output_tokens:1}}'\''' \
    'fi'
} > "$codex_bin_dir/codex"
chmod 0500 "$codex_bin_dir/codex"
codex_sha="$(sha256_file "$codex_bin_dir/codex")"

runner="$install_root/control/run.sh"
probe="$case_root/probe"
evidence="$case_root/evidence"
"$runner" \
  "$head" \
  "$candidate_sha" \
  "$probe" \
  "$evidence" \
  "$case_root/auth.json" \
  "$codex_bin_dir/codex" \
  "$codex_sha" \
  > "$case_root/success.stdout"

/usr/bin/grep -Fq "verdict=BASELINE PASS" "$case_root/success.stdout" ||
  fail "successful structured verdict"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.run/2" and
  .verdict == "BASELINE PASS" and
  .codex_exit_status == 0 and
  .integrity.privately_staged_candidate == true and
  .integrity.privately_staged_codex == true and
  .integrity.bubblewrap == null and
  (.evidence.workflows_sha256 | test("^[0-9a-f]{64}$"))
' "$evidence/RUN.json" >/dev/null ||
  fail "final run manifest"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.run-preflight/2" and
  .candidate_head == $head and
  .codex.version == "codex-cli 0.145.0" and
  .codex.privately_staged == true and
  .codex.bubblewrap == null and
  .harness.policy_readonly_canary == {
    host_write_preflight: true,
    sandbox_write_denied: true,
    host_write_postflight: true
  }
' --arg head "$head" "$evidence/RUN-PREFLIGHT.json" >/dev/null ||
  fail "preflight manifest"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.evidence/1" and
  (.artifacts | length) == 13 and
  (.artifacts | map(.path) | index("codex-stderr.log")) != null and
  (.artifacts | map(.path) | index("COMMANDS.json")) != null and
  (.artifacts | map(.path) | index("WORKFLOWS.json")) != null
' "$evidence/EVIDENCE.json" >/dev/null ||
  fail "complete evidence manifest"
[ "$(/usr/bin/jq 'length' "$evidence/COMMANDS.json")" -eq 61 ] ||
  fail "host-derived command inventory"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.workflows/2" and
  .required_count == 58 and
  (.workflows | length) == 58 and
  (.workflows | all((.events | length) > 0)) and
  ([.workflows[].events[].event_id] as $ids |
    ($ids | length) == 58 and ($ids | unique | length) == 58) and
  ([.workflows[].events[].result.path | select(. != null)] as $paths |
    ($paths | length) == 56 and ($paths | unique | length) == 56) and
  (.workflows | all(
    if .format == "all" then
      (.events | all(.artifact == null and .result.path == null))
    else
      (.events | all(
        (.artifact.sha256 | test("^[0-9a-f]{64}$")) and
        (.result.path | type) == "string"
      ))
    end
  ))
' "$evidence/WORKFLOWS.json" >/dev/null ||
  fail "host-derived workflow matrix"
[ ! -e "$probe/probe-transcript.md" ] ||
  fail "agent unexpectedly authored the command transcript"
[ "$(/usr/bin/grep -c '^## Event ' "$evidence/probe-transcript.md")" -eq 61 ] ||
  fail "host transcript event count"
ledger_sha="$(sha256_file "$evidence/COMMANDS.json")"
raw_sha="$(sha256_file "$evidence/codex-transcript.jsonl")"
/usr/bin/grep -Fq "Command ledger SHA-256: \`$ledger_sha\`" \
  "$evidence/probe-transcript.md" ||
  fail "host transcript ledger anchor"
/usr/bin/grep -Fq "Raw transcript SHA-256: \`$raw_sha\`" \
  "$evidence/probe-transcript.md" ||
  fail "host transcript raw-event anchor"
/usr/bin/grep -qx 'FRESH-AGENT PERMISSION CANARY PASS' \
  "$evidence/permission-canary.log" ||
  fail "permission canary evidence"
[ "$(/usr/bin/head -n 1 "$evidence/probe-result.md")" = \
  "Verdict: BASELINE PASS" ] ||
  fail "exact result verdict header"
if /usr/bin/find "$case_root" -maxdepth 1 -type d \
  -name '.office-f1b-isolation.*' | /usr/bin/grep -q .; then
  fail "isolated credential state was not cleaned"
fi

special_parent="$test_root/special # [x] * back\\slash"
/bin/mkdir -m 0700 "$special_parent"
special_install="$special_parent/install"
nested_source="$test_root/nested-source"
/bin/mkdir -m 0700 "$nested_source" "$nested_source/.git"
nested_source="$(
  unset CDPATH
  cd -P -- "$nested_source" >/dev/null
  pwd -P
)"
make_candidate "$special_install" "$nested_source" "$nested_source/.git"
special_candidate_sha="$(sha256_file "$special_install/CANDIDATE.json")"
"$special_install/control/run.sh" --canary-only \
  "$head" "$special_candidate_sha" \
  "$special_parent/probe" "$special_parent/evidence" \
  "$codex_bin_dir/codex" "$codex_sha" \
  > "$special_parent/canary.stdout"
/usr/bin/grep -qx 'verdict=CANARY PASS' "$special_parent/canary.stdout" ||
  fail "special-character prefix canary"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.canary-evidence/1" and
  (.artifacts | length) == 5
' "$special_parent/evidence/EVIDENCE.json" >/dev/null ||
  fail "canary-only evidence"
source_key="$(/usr/bin/jq -Rn --arg value "$nested_source" '$value')"
git_key="$(/usr/bin/jq -Rn --arg value "$nested_source/.git" '$value')"
source_deny="$source_key = \"deny\""
git_deny="$git_key = \"deny\""
/usr/bin/grep -Fqx "$source_deny" "$special_parent/evidence/CONFIG.toml" ||
  fail "source checkout deny rule"
if /usr/bin/grep -Fqx "$git_deny" "$special_parent/evidence/CONFIG.toml"; then
  fail "redundant nested Git deny rule"
fi

expect_failure() {
  local label="$1"
  local expected_status="$2"
  local pattern="$3"
  shift 3
  local stdout="$test_root/$label.stdout"
  local stderr="$test_root/$label.stderr"
  local status
  set +e
  "$@" >"$stdout" 2>"$stderr"
  status="$?"
  set -e
  [ "$status" -eq "$expected_status" ] ||
    fail "$label status: expected $expected_status, found $status"
  if [ -n "$pattern" ]; then
    /usr/bin/grep -q "$pattern" "$stderr" ||
      fail "$label diagnostic"
  fi
}

runner_args() {
  printf '%s\n' \
    "$head" \
    "$candidate_sha" \
    "$1" \
    "$2" \
    "$case_root/auth.json" \
    "$codex_bin_dir/codex" \
    "$codex_sha"
}

/bin/mkdir -m 0700 "$case_root/preexisting-probe"
expect_failure preexisting 1 'must not already exist' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/preexisting-probe" "$case_root/preexisting-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

expect_failure overlap 1 'must not overlap' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/same-output" "$case_root/same-output" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

weak_parent="$test_root/weak-parent"
/bin/mkdir -m 0755 "$weak_parent"
expect_failure weak-parent 1 'must not grant group or other access' \
  "$runner" "$head" "$candidate_sha" \
  "$weak_parent/probe" "$weak_parent/evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

expect_failure wrong-head 1 'candidate manifest failed strict schema validation' \
  "$runner" "0000000000000000000000000000000000000000" "$candidate_sha" \
  "$case_root/wrong-head-probe" "$case_root/wrong-head-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

expect_failure wrong-candidate-digest 1 'caller-supplied digest' \
  "$runner" "$head" "$(printf '0%.0s' {1..64})" \
  "$case_root/digest-probe" "$case_root/digest-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

expect_failure wrong-codex-digest 1 'caller-supplied digest' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/codex-digest-probe" "$case_root/codex-digest-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$(printf '0%.0s' {1..64})"

if [ "$(/usr/bin/uname -s)" = "Linux" ]; then
  linux_tmp_parent="$(/usr/bin/mktemp -d /tmp/office-f1b-rejected.XXXXXX)"
  chmod 0700 "$linux_tmp_parent"
  expect_failure linux-slash-tmp 1 'outside Linux /tmp' \
    "$runner" "$head" "$candidate_sha" \
    "$linux_tmp_parent/probe" "$linux_tmp_parent/evidence" \
    "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
  /bin/rmdir "$linux_tmp_parent"
  linux_tmp_parent=""

  native_codex="$case_root/native-codex"
  /usr/bin/install -m 0500 /bin/echo "$native_codex"
  native_codex_sha="$(sha256_file "$native_codex")"
  expect_failure linux-native-runtime-closure 1 \
    'requires an approved bubblewrap executable and digest' \
    "$runner" "$head" "$candidate_sha" \
    "$case_root/native-probe" "$case_root/native-evidence" \
    "$case_root/auth.json" "$native_codex" "$native_codex_sha"
  system_bwrap="$(command -v bwrap || true)"
  if [ -n "$system_bwrap" ]; then
    system_bwrap_sha="$(sha256_file "$system_bwrap")"
    expect_failure linux-system-bwrap-version 1 \
      'could not identify Codex CLI version' \
      "$runner" "$head" "$candidate_sha" \
      "$case_root/system-bwrap-probe" "$case_root/system-bwrap-evidence" \
      "$case_root/auth.json" "$native_codex" "$native_codex_sha" \
      "$system_bwrap" "$system_bwrap_sha"
  fi
fi

/bin/ln -s "$case_root/auth.json" "$case_root/auth-link.json"
expect_failure auth-symlink 1 'must be regular' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/auth-link-probe" "$case_root/auth-link-evidence" \
  "$case_root/auth-link.json" "$codex_bin_dir/codex" "$codex_sha"

hostile_hook="$test_root/hostile-bash-env"
hostile_marker="$test_root/hostile-marker"
printf 'printf pwned > %q\n' "$hostile_marker" > "$hostile_hook"
set +e
BASH_ENV="$hostile_hook" PATH="$test_root" "$runner" > /dev/null 2>&1
hostile_status="$?"
set -e
[ "$hostile_status" -eq 2 ] || fail "hostile BASH_ENV usage status"
[ ! -e "$hostile_marker" ] || fail "hostile BASH_ENV executed before runner"

set +e
BASH_ENV="$hostile_hook" PATH="$test_root" \
  "$script_dir/prepare.sh" > /dev/null 2>&1
hostile_prepare_status="$?"
set -e
[ "$hostile_prepare_status" -eq 2 ] || fail "hostile prepare BASH_ENV usage status"
[ ! -e "$hostile_marker" ] || fail "hostile BASH_ENV executed before prepare"

hostile_perl_lib="$test_root/hostile-perl"
hostile_perl_marker="$test_root/hostile-perl-marker"
/bin/mkdir -m 0700 "$hostile_perl_lib"
printf '%s\n' \
  'BEGIN { my $path = $ENV{OFFICE_F1B_HOSTILE_MARKER}; open my $fh, ">", $path or die $!; print {$fh} "pwned"; close $fh; } 1;' \
  > "$hostile_perl_lib/OfficeF1BHostile.pm"
set +e
PERL5OPT=-MOfficeF1BHostile PERL5LIB="$hostile_perl_lib" \
  OFFICE_F1B_HOSTILE_MARKER="$hostile_perl_marker" \
  "$runner" "0000000000000000000000000000000000000000" "$candidate_sha" \
  "$case_root/hostile-perl-probe" "$case_root/hostile-perl-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha" \
  >"$test_root/hostile-perl.stdout" 2>"$test_root/hostile-perl.stderr"
hostile_perl_status="$?"
set -e
[ "$hostile_perl_status" -eq 1 ] || fail "hostile Perl environment status"
[ ! -e "$hostile_perl_marker" ] || fail "ambient Perl startup hook executed"

failed_git_root="$test_root/failed-git-root"
failed_git_toolchain="$test_root/failed-git-toolchain"
/bin/mkdir -p -m 0700 \
  "$failed_git_root/office/tests/acceptance/fresh-agent" \
  "$failed_git_root/install-parent" \
  "$failed_git_toolchain/bin"
for fake_tool in moon moonc moonrun; do
  /usr/bin/install -m 0500 /usr/bin/true \
    "$failed_git_toolchain/bin/$fake_tool"
done
/usr/bin/install -m 0500 "$script_dir/prepare.sh" \
  "$failed_git_root/office/tests/acceptance/fresh-agent/prepare.sh"
/usr/bin/install -m 0500 "$script_dir/inventory.sh" \
  "$failed_git_root/office/tests/acceptance/fresh-agent/inventory.sh"
/usr/bin/install -m 0400 "$script_dir/build-lock.json" \
  "$failed_git_root/office/tests/acceptance/fresh-agent/build-lock.json"
/usr/bin/git -C "$failed_git_root" init -q
/usr/bin/git -C "$failed_git_root" add .
/usr/bin/git -C "$failed_git_root" \
  -c user.name=fixture -c user.email=fixture@example.invalid \
  commit -qm fixture
failed_git_head="$(/usr/bin/git -C "$failed_git_root" rev-parse HEAD)"
chmod 0000 "$failed_git_root/.git/index"
expect_failure failed-git-status 1 'could not inspect candidate checkout status' \
  "$failed_git_root/office/tests/acceptance/fresh-agent/prepare.sh" \
  "$failed_git_head" "$failed_git_root/install-parent/candidate" \
  "$failed_git_toolchain/bin/moon" \
  "$failed_git_toolchain/bin/moonc" \
  "$failed_git_toolchain/bin/moonrun"

expect_failure indirect-bash 2 'execute run.sh directly' \
  /bin/bash "$runner"
expect_failure indirect-prepare-bash 2 'execute prepare.sh directly' \
  /bin/bash "$script_dir/prepare.sh"

printf 'sandbox-fail\n' > "$codex_bin_dir/mode"
expect_failure sandbox-fail 1 'sandbox diagnostic' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/sandbox-fail-probe" "$case_root/sandbox-fail-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'canary-hang\n' > "$codex_bin_dir/mode"
OFFICE_F1B_CODEX_CANARY_TIMEOUT_SECONDS=1 \
expect_failure canary-timeout 124 'permission canary exceeded its 1s deadline' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/canary-timeout-probe" "$case_root/canary-timeout-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'unreadable-policy\n' > "$codex_bin_dir/mode"
expect_failure unreadable-policy 1 'could not inspect policy read-only canary' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/unreadable-policy-probe" \
  "$case_root/unreadable-policy-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'old-version\n' > "$codex_bin_dir/mode"
expect_failure old-version 1 '0.145.0 or newer is required' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/old-probe" "$case_root/old-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'prerelease-version\n' > "$codex_bin_dir/mode"
expect_failure prerelease-version 1 'prerelease builds are not accepted' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/prerelease-probe" "$case_root/prerelease-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'dead-listener\n' > "$codex_bin_dir/mode"
expect_failure dead-listener 1 \
  'listener is not live after the permission canary' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/dead-listener-probe" "$case_root/dead-listener-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'version-hang\n' > "$codex_bin_dir/mode"
OFFICE_F1B_CODEX_VERSION_TIMEOUT_SECONDS=1 \
expect_failure version-timeout 124 'version probe exceeded its 1s deadline' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/version-timeout-probe" "$case_root/version-timeout-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'exit19\n' > "$codex_bin_dir/mode"
expect_failure codex-status 19 'Codex probe exited with status 19' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/status-probe" "$case_root/status-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'probe-hang\n' > "$codex_bin_dir/mode"
OFFICE_F1B_CODEX_PROBE_TIMEOUT_SECONDS=1 \
expect_failure probe-timeout 124 'installed-command probe exceeded its 1s deadline' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/probe-timeout-probe" "$case_root/probe-timeout-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'orphan-child\n' > "$codex_bin_dir/mode"
/bin/rm -f -- "$codex_bin_dir/mode.child-pid"
expect_failure orphan-child 1 'Codex final message' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/orphan-probe" "$case_root/orphan-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
orphan_child_pid="$(/bin/cat "$codex_bin_dir/mode.child-pid")"
for _ in {1..20}; do
  orphan_child_state="$(
    /bin/ps -o stat= -p "$orphan_child_pid" 2>/dev/null |
      /usr/bin/tr -d ' ' || true
  )"
  case "$orphan_child_state" in
    "" | Z*) break ;;
  esac
  /bin/sleep 0.1
done
case "$orphan_child_state" in
  "" | Z*) ;;
  *) fail "Codex descendant survived after its leader exited" ;;
esac

printf 'ignore-term\n' > "$codex_bin_dir/mode"
signal_probe="$case_root/signal-probe"
signal_evidence="$case_root/signal-evidence"
signal_stdout="$test_root/signal.stdout"
signal_stderr="$test_root/signal.stderr"
"$runner" "$head" "$candidate_sha" \
  "$signal_probe" "$signal_evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha" \
  >"$signal_stdout" 2>"$signal_stderr" &
signal_runner_pid="$!"
signal_child_pid=""
staged_auth=""
for _ in {1..100}; do
  if [ -s "$codex_bin_dir/mode.child-pid" ]; then
    signal_child_pid="$(/bin/cat "$codex_bin_dir/mode.child-pid")"
    staged_auth="$(/usr/bin/find "$case_root" -path \
      '*/.office-f1b-isolation.*/codex/auth.json' -print -quit)"
    [ -n "$staged_auth" ] && break
  fi
  /bin/sleep 0.1
done
[ -n "$signal_child_pid" ] || fail "signal test did not start the fake Codex child"
[ -n "$staged_auth" ] && [ -f "$staged_auth" ] ||
  fail "signal test did not stage the isolated credential"
signal_started_at="$SECONDS"
/bin/kill -TERM "$signal_runner_pid"
set +e
wait "$signal_runner_pid"
signal_status="$?"
set -e
[ "$signal_status" -eq 143 ] ||
  fail "signal cleanup status: expected 143, found $signal_status"
[ $((SECONDS - signal_started_at)) -le 5 ] ||
  fail "signal cleanup exceeded its bounded escalation window"
if /bin/kill -0 "$signal_child_pid" 2>/dev/null; then
  fail "TERM-ignoring fake Codex child survived runner cleanup"
fi
[ -f "$case_root/auth.json" ] || fail "signal cleanup removed the source credential"
[ ! -e "$staged_auth" ] && [ ! -L "$staged_auth" ] ||
  fail "signal cleanup retained the staged credential"
if /usr/bin/find "$case_root" -maxdepth 1 -type d \
  -name '.office-f1b-isolation.*' | /usr/bin/grep -q .; then
  fail "signal cleanup retained the isolation root"
fi

printf 'malformed\n' > "$codex_bin_dir/mode"
expect_failure malformed-final 1 'required structured result' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/malformed-probe" "$case_root/malformed-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'contradictory\n' > "$codex_bin_dir/mode"
expect_failure contradictory 1 'exact structured verdict' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/contradict-probe" "$case_root/contradict-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'no-office\n' > "$codex_bin_dir/mode"
expect_failure no-office 1 'exact isolated help result for native' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/no-office-probe" "$case_root/no-office-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'spoof-office\n' > "$codex_bin_dir/mode"
expect_failure spoof-office 1 'exact isolated help result for native' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/spoof-office-probe" "$case_root/spoof-office-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'missing-create\n' > "$codex_bin_dir/mode"
expect_failure missing-create 1 'canonical result-bearing workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/missing-create-probe" "$case_root/missing-create-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'format-redirection-spoof\n' > "$codex_bin_dir/mode"
expect_failure format-redirection-spoof 1 'canonical result-bearing workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/format-spoof-probe" "$case_root/format-spoof-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'newline-mask\n' > "$codex_bin_dir/mode"
expect_failure newline-mask 1 'non-detaching acceptance policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/newline-mask-probe" "$case_root/newline-mask-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

for spoof_mode in help-only comment-spoof; do
  printf '%s\n' "$spoof_mode" > "$codex_bin_dir/mode"
  expect_failure "$spoof_mode" 1 \
    'canonical result-bearing workflow: native/xlsx/create' \
    "$runner" "$head" "$candidate_sha" \
    "$case_root/$spoof_mode-probe" "$case_root/$spoof_mode-evidence" \
    "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
done

for spoof_mode in input-redirection cross-format; do
  printf '%s\n' "$spoof_mode" > "$codex_bin_dir/mode"
  expect_failure "$spoof_mode" 1 \
    'canonical result-bearing workflow: native/xlsx/validate' \
    "$runner" "$head" "$candidate_sha" \
    "$case_root/$spoof_mode-probe" "$case_root/$spoof_mode-evidence" \
    "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
done

printf 'duplicate-result-path\n' > "$codex_bin_dir/mode"
expect_failure duplicate-result-path 1 'required office.xlsx.create/1 result' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/duplicate-result-probe" \
  "$case_root/duplicate-result-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'aliased-result-parent\n' > "$codex_bin_dir/mode"
expect_failure aliased-result-parent 1 \
  'must not traverse a symlink or physical path alias' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/aliased-result-probe" \
  "$case_root/aliased-result-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'uppercase-result-path\n' > "$codex_bin_dir/mode"
expect_failure uppercase-result-path 1 'must use lowercase' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/uppercase-result-probe" \
  "$case_root/uppercase-result-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'wrong-result-schema\n' > "$codex_bin_dir/mode"
expect_failure wrong-result-schema 1 'required office.xlsx.create/1 result' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/wrong-schema-probe" "$case_root/wrong-schema-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'invalid-artifact\n' > "$codex_bin_dir/mode"
expect_failure invalid-artifact 1 'unreadable or corrupt ZIP package' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/invalid-artifact-probe" \
  "$case_root/invalid-artifact-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'generic-zip-artifact\n' > "$codex_bin_dir/mode"
expect_failure generic-zip-artifact 1 'missing required OPC part' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/generic-zip-probe" \
  "$case_root/generic-zip-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'decoy-opc-root\n' > "$codex_bin_dir/mode"
expect_failure decoy-opc-root 1 'unexpected OPC main-part root' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/decoy-opc-probe" "$case_root/decoy-opc-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'nested-content-types\n' > "$codex_bin_dir/mode"
expect_failure nested-content-types 1 \
  'invalid OPC content-types child structure' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/nested-types-probe" "$case_root/nested-types-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'nested-relationships\n' > "$codex_bin_dir/mode"
expect_failure nested-relationships 1 \
  'invalid OPC relationship child structure' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/nested-rels-probe" "$case_root/nested-rels-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'oversized-zip-entry\n' > "$codex_bin_dir/mode"
expect_failure oversized-zip-entry 1 'ZIP entry expands beyond 64 MiB' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/oversized-zip-probe" "$case_root/oversized-zip-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'zip-symlink-artifact\n' > "$codex_bin_dir/mode"
expect_failure zip-symlink-artifact 1 'ZIP contains a non-file entry' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/zip-symlink-probe" "$case_root/zip-symlink-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'reused-event-id\n' > "$codex_bin_dir/mode"
expect_failure reused-event-id 1 'transcript lifecycle' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/reused-event-probe" "$case_root/reused-event-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'incomplete-report\n' > "$codex_bin_dir/mode"
expect_failure incomplete-report 1 'structured outcome: Native XLSX' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/incomplete-report-probe" "$case_root/incomplete-report-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'pre-canary\n' > "$codex_bin_dir/mode"
expect_failure pre-canary 1 'transcript lifecycle' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/pre-canary-probe" "$case_root/pre-canary-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'detaching-command\n' > "$codex_bin_dir/mode"
expect_failure detaching-command 1 'non-detaching acceptance policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/detaching-command-probe" \
  "$case_root/detaching-command-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

for lifecycle_mode in \
  completion-before-start \
  fractional-exit \
  out-of-domain-exit \
  missing-turn-completed \
  turn-failed; do
  printf '%s\n' "$lifecycle_mode" > "$codex_bin_dir/mode"
  expect_failure "$lifecycle_mode" 1 'transcript lifecycle' \
    "$runner" "$head" "$candidate_sha" \
    "$case_root/$lifecycle_mode-probe" \
    "$case_root/$lifecycle_mode-evidence" \
    "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
done

printf 'fail\n' > "$codex_bin_dir/mode"
expect_failure baseline-fail 3 '' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/fail-probe" "$case_root/fail-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
/usr/bin/jq -e '.verdict == "BASELINE FAIL"' \
  "$case_root/fail-evidence/RUN.json" >/dev/null ||
  fail "BASELINE FAIL run manifest"

echo "FRESH-AGENT RUNNER TEST PASS"

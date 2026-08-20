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

/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/command_policy_test.py" \
  "$script_dir/command_policy.py" ||
  fail "adversarial command-policy unit tests"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/build_host_discovery_test.py" \
  "$script_dir/build_host_discovery.py" ||
  fail "native build-host discovery unit tests"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/attest_test.py" \
  "$script_dir/attest.py" ||
  fail "atomic completion-attestation unit tests"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/argument_policy_test.py" \
  "$script_dir/argument_policy.py" ||
  fail "Office filesystem-argument policy unit tests"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/auth_guard_test.py" \
  "$script_dir/auth_guard.py" ||
  fail "held-FD credential guard unit tests"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/opc_policy_test.py" \
  "$script_dir/opc_policy.py" ||
  fail "bounded OPC-policy unit tests"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/transcript_policy_test.py" \
  "$script_dir/transcript_policy.py" ||
  fail "bounded transcript-policy unit tests"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/scenario_policy_test.py" \
  "$script_dir/scenario_policy.py" ||
  fail "host-derived scenario-policy unit tests"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I "$script_dir/evidence_policy_test.py" \
  "$script_dir/evidence_policy.py" ||
  fail "self-contained evidence-policy unit tests"

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
  local attest_sha
  local argument_policy_sha
  local auth_guard_sha
  local command_policy_sha
  local opc_policy_sha
  local transcript_policy_sha
  local scenario_policy_sha
  local private_sha
  local inventory_sha
  local build_lock_sha
  local toolchain_manifest_sha
  local dependency_manifest_sha
  local build_host_sha
  local build_host_manifest_sha
  local build_host_discovery_policy_sha
  local build_host_discovery_sha
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
    'runtime=native' \
    'case "${1:-}" in *.wasm) runtime=wasm; shift ;; esac' \
    'verb=${1:-help}' \
    'shift || true' \
    'raw_action=${1:-}' \
    'if [ "$verb" = help ]; then' \
    '  if [ "$raw_action" = schemas ]; then' \
    '    printf '\''{"schema":"office.output/1","success":true,"data":{"schema":"office.input-contracts/1","fingerprint":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","contracts":[{"id":"xlsx.batch/2","fingerprint":"sha256:1111111111111111111111111111111111111111111111111111111111111111","summary":"xlsx batch","consumed_by":["office batch"]},{"id":"docx.batch/2","fingerprint":"sha256:2222222222222222222222222222222222222222222222222222222222222222","summary":"docx batch","consumed_by":["office batch"]},{"id":"office.template.data/1","fingerprint":"sha256:3333333333333333333333333333333333333333333333333333333333333333","summary":"template data","consumed_by":["office template"]},{"id":"docx.edit/1","fingerprint":"sha256:5555555555555555555555555555555555555555555555555555555555555555","summary":"literal edit","consumed_by":["office edit"]},{"id":"docx.edit/2","fingerprint":"sha256:6666666666666666666666666666666666666666666666666666666666666666","summary":"addressed run edit","consumed_by":["office edit"]},{"id":"docx.annotation-batch/1","fingerprint":"sha256:4444444444444444444444444444444444444444444444444444444444444444","summary":"annotations","consumed_by":["office annotate"]}]}}\n'\''' \
    '  else' \
    '    printf '\''{"schema":"office.output/1","success":true,"data":{"schema":"office.capabilities/2","fingerprint":"test:fingerprint","records":[{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"format","name":"docx"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"format","name":"xlsx"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"help"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"identify"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"outline"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"get"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"text"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"query"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"validate"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"dump"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"replay"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"issues"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"preview"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"create"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"template"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"annotate"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"edit"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"batch"},{"schema":"office.capability/2","fingerprint":"test:fingerprint","kind":"command","name":"raw"}]}}\n'\''' \
    '  fi' \
    '  exit 0' \
    'fi' \
    'format=""; source_file=""; output_file=""; script_file=""; pending=""' \
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
    '    *.json) [ -n "$script_file" ] || script_file=$arg ;;' \
    '  esac' \
    'done' \
    '[ -n "$format" ] || exit 71' \
    'make_package() {' \
    '  package=$1' \
    '  case "$package" in /*) package_path=$package ;; *) package_path=$PWD/$package ;; esac' \
    '  /bin/mkdir -p "$(/usr/bin/dirname -- "$package_path")"' \
    '  case "${package_path##*/}" in batched.xlsx|authored.docx) stage_text="{{agent_name}}" ;; *.xlsx) stage_text=F1B-XLSX-TEMPLATE-V1 ;; *) stage_text=F1B-DOCX-TEMPLATE-V1 ;; esac' \
    '  content_marker=F1B-XLSX-REPRESENTATIVE-V1' \
    '  if [ "${OFFICE_F1B_EMPTY_SEMANTICS:-}" = 1 ]; then content_marker=EMPTY; stage_text=EMPTY; fi' \
    '  package_tmp="$TMPDIR/fake-office-package-$$"' \
    '  /bin/rm -rf -- "$package_tmp"' \
    '  /bin/mkdir -m 0700 "$package_tmp" "$package_tmp/_rels"' \
    '  if [ "$format" = xlsx ]; then' \
    '    /bin/mkdir -p "$package_tmp/xl/_rels" "$package_tmp/xl/worksheets/_rels" "$package_tmp/xl/drawings/_rels" "$package_tmp/xl/charts"' \
    '    printf "%s\n" "<?xml version=\"1.0\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/><Override PartName=\"/xl/drawings/drawing1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawing+xml\"/><Override PartName=\"/xl/charts/chart1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.chart+xml\"/></Types>" > "$package_tmp/[Content_Types].xml"' \
    '    printf "%s\n" '\''<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'\'' > "$package_tmp/_rels/.rels"' \
    '    printf "%s\n" '\''<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Data" sheetId="1" r:id="rId1"/></sheets></workbook>'\'' > "$package_tmp/xl/workbook.xml"' \
    '    printf "%s\n" '\''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/></Relationships>'\'' > "$package_tmp/xl/_rels/workbook.xml.rels"' \
    '    printf "%s\n" "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"2\" uniqueCount=\"2\"><si><t>$content_marker</t></si><si><t>$stage_text</t></si></sst>" > "$package_tmp/xl/sharedStrings.xml"' \
    '    if [ "${OFFICE_F1B_INCONSISTENT_SEMANTICS:-}" = 1 ]; then' \
    '      printf "%s\n" '\''<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1"><v>30</v></c><c r="C1"><f>SUM(B1:B1)</f><v>30</v></c><c r="D1" t="s"><v>1</v></c></row></sheetData><drawing r:id="rId1"/></worksheet>'\'' > "$package_tmp/xl/worksheets/sheet1.xml"' \
    '    else' \
    '      printf "%s\n" '\''<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c></row><row r="2"><c r="B2"><v>30</v></c></row><row r="3"><c r="B3"><v>70</v></c></row><row r="4"><c r="B4"><f>SUM(B2:B3)</f></c></row><row r="5"><c r="A5" t="s"><v>1</v></c></row></sheetData><drawing r:id="rId1"/></worksheet>'\'' > "$package_tmp/xl/worksheets/sheet1.xml"' \
    '    fi' \
    '    printf "%s\n" '\''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/></Relationships>'\'' > "$package_tmp/xl/worksheets/_rels/sheet1.xml.rels"' \
    '    printf "%s\n" '\''<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><xdr:twoCellAnchor><xdr:from><xdr:col>3</xdr:col><xdr:row>1</xdr:row></xdr:from><xdr:graphicFrame><c:chart r:id="rId1"/></xdr:graphicFrame></xdr:twoCellAnchor></xdr:wsDr>'\'' > "$package_tmp/xl/drawings/drawing1.xml"' \
    '    printf "%s\n" '\''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart" Target="../charts/chart1.xml"/></Relationships>'\'' > "$package_tmp/xl/drawings/_rels/drawing1.xml.rels"' \
    '    printf "%s\n" '\''<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><c:chart><c:title><c:tx><c:rich><a:p><a:r><a:t>Representative</a:t></a:r></a:p></c:rich></c:tx></c:title><c:plotArea><c:barChart><c:barDir val="col"/><c:ser><c:tx><c:v>F1B</c:v></c:tx><c:cat><c:strRef><c:f>Data!A2:A3</c:f></c:strRef></c:cat><c:val><c:numRef><c:f>Data!B2:B3</c:f></c:numRef></c:val></c:ser></c:barChart></c:plotArea></c:chart></c:chartSpace>'\'' > "$package_tmp/xl/charts/chart1.xml"' \
    '    (cd "$package_tmp" && /usr/bin/zip -q "$package_path" "[Content_Types].xml" "_rels/.rels" "xl/workbook.xml" "xl/_rels/workbook.xml.rels" "xl/sharedStrings.xml" "xl/worksheets/sheet1.xml" "xl/worksheets/_rels/sheet1.xml.rels" "xl/drawings/drawing1.xml" "xl/drawings/_rels/drawing1.xml.rels" "xl/charts/chart1.xml")' \
    '  else' \
    '    /bin/mkdir -p "$package_tmp/word/_rels"' \
    '    printf "%s\n" '\''<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/comments.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/><Override PartName="/word/commentsExtended.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml"/></Types>'\'' > "$package_tmp/[Content_Types].xml"' \
    '    printf "%s\n" '\''<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'\'' > "$package_tmp/_rels/.rels"' \
    '    anchor_start="<w:commentRangeStart w:id=\"0\"/>"' \
    '    anchor_end="<w:commentRangeEnd w:id=\"0\"/><w:r><w:commentReference w:id=\"0\"/></w:r>"' \
    '    heading_anchor_start=; heading_anchor_end=; template_anchor_start=$anchor_start; template_anchor_end=$anchor_end' \
    '    if [ "${OFFICE_F1B_WRONG_ANNOTATION_ANCHOR:-}" = 1 ]; then heading_anchor_start=$anchor_start; heading_anchor_end=$anchor_end; template_anchor_start=; template_anchor_end=; fi' \
    '    printf "%s\n" "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:body><w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr>$heading_anchor_start<w:r><w:t>F1B-DOCX-HEADING-V1</w:t></w:r>$heading_anchor_end</w:p><w:p>$template_anchor_start<w:r><w:t>$stage_text</w:t></w:r>$template_anchor_end</w:p><w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/></w:numPr></w:pPr><w:r><w:t>F1B-DOCX-LIST-V1</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>F1B-DOCX-TABLE-V1</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p><w:hyperlink r:id=\"rIdLink\"><w:r><w:t>F1B link</w:t></w:r></w:hyperlink></w:p></w:body></w:document>" > "$package_tmp/word/document.xml"' \
    '    printf "%s\n" '\''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdLink" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.invalid/f1b" TargetMode="External"/><Relationship Id="rIdComments" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="comments.xml"/><Relationship Id="rIdCommentsEx" Type="http://schemas.microsoft.com/office/2011/relationships/commentsExtended" Target="commentsExtended.xml"/></Relationships>'\'' > "$package_tmp/word/_rels/document.xml.rels"' \
    '    printf "%s\n" '\''<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:comment w:id="0"><w:p w14:paraId="00000001"><w:r><w:t>F1B-DOCX-COMMENT-V1</w:t></w:r></w:p></w:comment><w:comment w:id="1"><w:p w14:paraId="00000002"><w:r><w:t>F1B-DOCX-REPLY-V1</w:t></w:r></w:p></w:comment></w:comments>'\'' > "$package_tmp/word/comments.xml"' \
    '    printf "%s\n" '\''<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml"><w15:commentEx w15:paraId="00000001" w15:done="1"/><w15:commentEx w15:paraId="00000002" w15:paraIdParent="00000001" w15:done="0"/></w15:commentsEx>'\'' > "$package_tmp/word/commentsExtended.xml"' \
    '    (cd "$package_tmp" && /usr/bin/zip -q "$package_path" "[Content_Types].xml" "_rels/.rels" "word/document.xml" "word/_rels/document.xml.rels" "word/comments.xml" "word/commentsExtended.xml")' \
    '  fi' \
    '  /bin/rm -rf -- "$package_tmp"' \
    '}' \
    'if [ "$verb/$format" = batch/docx ] && { [ "${source_file##*/}" = refusal-output.docx ] || [ "${source_file##*/}" = host-refusal-output.docx ]; } && /usr/bin/jq -e '\''(.schema == "docx.batch/2") and (.ops == [{"op":"f1b_invalid_operation","params":{}}])'\'' "$script_file" >/dev/null; then' \
    '  if [ -e "$PWD/force-host-script-rewrite" ]; then /usr/bin/printf "%s\n" '\''{"schema":"docx.batch/2","ops":[]}'\'' > "$script_file"; fi' \
    '  if [ -e "$PWD/force-host-staging" ]; then : > "$(/usr/bin/dirname -- "$source_file")/.office-tmp-fixture"; fi' \
    '  /usr/bin/jq -cn '\''{schema:"office.output/1",success:false,error:{code:"office.docx.batch_parse",message:"unknown op"}}'\''' \
    '  exit 2' \
    'fi' \
    'if [ "$verb/$format" = batch/xlsx ] && [ -n "$output_file" ] && [ -e "$output_file" ]; then' \
    '  if [ -e "$PWD/force-host-xlsx-corruption" ] && [ "${output_file##*/}" = refusal-target.xlsx ]; then /usr/bin/printf corrupt > "$output_file"; fi' \
    '  if [ -e "$PWD/force-host-xlsx-divergent" ] && [ "$runtime" = wasm ]; then' \
    '    /usr/bin/jq -cn --arg output "$output_file" '\''{schema:"office.output/1",success:false,error:{code:"office.transaction.output_exists",message:"output exists",details:{output:$output}},warnings:[{code:"office.fixture.divergent_refusal",message:"Wasm-only refusal divergence"}]}'\''' \
    '  else' \
    '    /usr/bin/jq -cn --arg output "$output_file" '\''{schema:"office.output/1",success:false,error:{code:"office.transaction.output_exists",message:"output exists",details:{output:$output}}}'\''' \
    '  fi' \
    '  exit 2' \
    'fi' \
    '[ -n "$source_file" ] || source_file="fixture.$format"' \
    '[ -f "$source_file" ] || make_package "$source_file"' \
    'artifact=$source_file' \
    'case "$verb" in' \
    '  batch)' \
    '    if [ -n "$output_file" ]; then make_package "$output_file"; artifact=$output_file; fi' \
    '    if [ "${OFFICE_F1B_WRONG_OUTPUT_ROLE:-}" = 1 ]; then artifact=$source_file; fi' \
    '    ;;' \
    '  template|replay|annotate|edit)' \
    '    [ -n "$output_file" ] || output_file="produced-$verb.$format"' \
    '    make_package "$output_file"' \
    '    artifact=$output_file' \
    '    ;;' \
    '  preview)' \
    '    [ -n "$output_file" ] || output_file=preview.html' \
    '    if [ "${OFFICE_F1B_CANNED_PREVIEW:-}" = 1 ]; then' \
    '      printf '\''<!doctype html><title>fake preview</title>\n'\'' > "$output_file"' \
    '    elif [ "$format" = xlsx ]; then' \
    '      printf '\''<!doctype html><p>F1B-XLSX-REPRESENTATIVE-V1</p><p>F1B-XLSX-TEMPLATE-V1</p><figure class="chart">Representative</figure>\n'\'' > "$output_file"' \
    '    else' \
    '      printf '\''<!doctype html><h1>F1B-DOCX-HEADING-V1</h1><p>F1B-DOCX-TEMPLATE-V1</p><ol><li>F1B-DOCX-LIST-V1</li></ol><table><tr><td>F1B-DOCX-TABLE-V1</td></tr></table><a href="https://example.invalid/f1b">F1B link</a>\n'\'' > "$output_file"' \
    '    fi' \
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
    '  edit/docx) result_schema=office.docx.edit/2 ;;' \
    '  annotate/docx) result_schema=office.docx.annotation-batch/1 ;;' \
    '  *) exit 72 ;;' \
    'esac' \
    'if [ "$verb/$format" = dump/xlsx ]; then' \
    '  /usr/bin/jq -cn --arg source "$source_file" --arg canned "${OFFICE_F1B_CANNED_DUMP:-0}" '\''([{op:"set",params:{sheet:"Data",cell:"A1",value:"F1B-XLSX-REPRESENTATIVE-V1"}},{op:"set",params:{sheet:"Data",cell:"B2",value:(if $canned == "1" then 31 else 30 end)}},{op:"set",params:{sheet:"Data",cell:"B3",value:70}},{op:"formula",params:{sheet:"Data",cell:"B4",formula:"SUM(B2:B3)"}},{op:"set",params:{sheet:"Data",cell:"A5",value:"F1B-XLSX-TEMPLATE-V1"}},{op:"chart",params:{sheet:"Data",anchor:"D2",type:"col",categories:"A2:A3",values:"B2:B3",name:"F1B",title:"Representative"}}]) as $ops | {schema:"office.dump/1",format:"xlsx",source:{file:$source,bytes:1,sha256:("a"*64)},replay:{batch_schema:"xlsx.batch/2",create:{},limits:{}},ops:$ops,assets:{},residual:[],warnings:[],stats:{ops:6,assets:0,residual:0,warnings:0}}'\''' \
    '  exit 0' \
    'fi' \
    'if [ "$verb/$format" = get/xlsx ]; then' \
    '  /usr/bin/jq -cn --arg source "$source_file" --arg canned "${OFFICE_F1B_CANNED_GET:-0}" --arg unknown_warning "${OFFICE_F1B_UNKNOWN_WARNING:-0}" '\''({schema:"office.output/1",success:true,data:{schema:"office.xlsx.element/1",file:$source,format:"xlsx",path:"/xlsx/sheet[name=\"Data\"]/range[A1:B5]",kind:"range",stability:"snapshot-relative",parent:"/xlsx/sheet[name=\"Data\"]",reference:"A1:B5",cells:[{path:"/xlsx/sheet[name=\"Data\"]/cell[A1]",reference:"A1",row:1,column:1,value:"F1B-XLSX-REPRESENTATIVE-V1",raw:{type:"string",value:"F1B-XLSX-REPRESENTATIVE-V1"}},{path:"/xlsx/sheet[name=\"Data\"]/cell[B2]",reference:"B2",row:2,column:2,value:(if $canned == "1" then "31" else "30" end),raw:{type:"number",value:(if $canned == "1" then 31 else 30 end)}},{path:"/xlsx/sheet[name=\"Data\"]/cell[B3]",reference:"B3",row:3,column:2,value:"70",raw:{type:"number",value:70}},{path:"/xlsx/sheet[name=\"Data\"]/cell[B4]",reference:"B4",row:4,column:2,formula:"SUM(B2:B3)"},{path:"/xlsx/sheet[name=\"Data\"]/cell[A5]",reference:"A5",row:5,column:1,value:"F1B-XLSX-TEMPLATE-V1",raw:{type:"string",value:"F1B-XLSX-TEMPLATE-V1"}}],styles:{},scanned_cells:10,returned:5}}) + (if $unknown_warning == "1" then {warnings:[{code:"office.fixture.unclassified_target_warning",message:"unclassified target warning"}]} else {} end)'\''' \
    '  exit 0' \
    'fi' \
    '/usr/bin/jq -cn --arg verb "$verb" --arg format "$format" --arg schema "$result_schema" --arg source "$source_file" --arg output "$artifact" --arg produced "$output_file" --arg runtime "$runtime" --arg canned_get "${OFFICE_F1B_CANNED_GET:-0}" --arg canned_raw "${OFFICE_F1B_CANNED_RAW:-0}" --arg canned_dump "${OFFICE_F1B_CANNED_DUMP:-0}" --arg unknown_warning "${OFFICE_F1B_UNKNOWN_WARNING:-0}" '\''def commit_warnings: [{code:"office.transaction.path_based_commit_semantics",message:"publication uses moonbitlang/async path APIs; atomic rename is guaranteed, but hostile concurrent directory-entry replacement is outside the portable contract"}] + (if $runtime == "wasm" then [{code:"office.transaction.wasm_commit_semantics",message:"Wasm uses normalized paths and a same-directory rename, but host-independent realpath, symlink identity, and parent-directory durability are unavailable"}] else [] end); def envelope($data): {schema:"office.output/1",success:true,data:$data} + (if $unknown_warning == "1" then {warnings:[{code:"office.fixture.unclassified_target_warning",message:"unclassified target warning"}]} elif $verb == "create" or $verb == "batch" or $verb == "template" or $verb == "replay" or $verb == "annotate" or $verb == "edit" then {warnings:commit_warnings} else {} end); if $verb == "dump" then (if $canned_dump == "1" then [{op:"fixture",params:{format:$format}}] elif $format == "xlsx" then [{op:"set",params:{sheet:"Data",cell:"A1",value:"F1B-XLSX-REPRESENTATIVE-V1"}},{op:"set",params:{sheet:"Data",cell:"A5",value:"F1B-XLSX-TEMPLATE-V1"}},{op:"set",params:{sheet:"Data",cell:"B2",value:30}},{op:"formula",params:{sheet:"Data",cell:"B4",formula:"SUM(B2:B3)"}},{op:"chart",params:{sheet:"Data",anchor:"D2",categories:"A2:A3",values:"B2:B3"}}] else [{op:"paragraph",params:{text:"F1B-DOCX-HEADING-V1",style:"Heading1"}},{op:"paragraph",params:{text:"F1B-DOCX-TEMPLATE-V1"}},{op:"paragraph",params:{text:"F1B-DOCX-LIST-V1",list:{ordered:true}}},{op:"table",params:{rows:[["F1B-DOCX-TABLE-V1"]]}},{op:"paragraph",params:{runs:[{link:{href:"https://example.invalid/f1b",text:"F1B link"}}]}},{op:"comment",params:{body:"F1B-DOCX-COMMENT-V1"}},{op:"comment",params:{body:"F1B-DOCX-REPLY-V1",reply_to:5}}] end) as $ops | {schema:$schema,format:$format,source:{file:$source,bytes:1,sha256:("a"*64)},replay:{batch_schema:(if $format == "xlsx" then "xlsx.batch/2" else "docx.batch/2" end),create:{},limits:{}},ops:$ops,assets:{},residual:[],warnings:[],stats:{ops:($ops|length),assets:0,residual:0,warnings:0}} else envelope({schema:$schema,format:$format} + if $verb == "create" or $verb == "batch" then {transaction:{format:$format,output:$output,committed:true,dry_run:false,changed:true}} elif $verb == "identify" then {file:$source} elif $verb == "outline" and $format == "docx" then {file:$source,path:"/",counts:{comments:2}} elif $verb == "outline" then {file:$source,path:"/"} elif $verb == "get" and $canned_get == "1" then {file:$source,path:"/"} elif $verb == "get" and $format == "xlsx" then {file:$source,path:"/xlsx/sheet[name=Data]/range[A1:A5]",cells:[{raw:{value:"F1B-XLSX-REPRESENTATIVE-V1"}},{raw:{value:"F1B-XLSX-TEMPLATE-V1"}}]} elif $verb == "get" then {file:$source,path:"/docx/body/p[1]",text:"F1B-DOCX-HEADING-V1"} elif $verb == "text" then {file:$source,returned:1,entries:[{text:(if $format == "xlsx" then "F1B-XLSX-TEMPLATE-V1" else "F1B-DOCX-TEMPLATE-V1" end)}]} elif $verb == "query" then {file:$source,returned:1,matches:[{preview:(if $format == "xlsx" then "F1B-XLSX-TEMPLATE-V1" else "F1B-DOCX-TEMPLATE-V1" end)}]} elif $verb == "validate" or $verb == "issues" then {file:$source,valid:true,error_count:0} elif $verb == "preview" then {file:$source,output:$produced,bytes_written:50,charts_rendered:(if $format == "xlsx" then 1 else 0 end),charts_placeholder:0,images_embedded:0,truncation:{max_rows:1000,max_cols:256,truncated_sheets:[],images_omitted:0}} elif $verb == "template" then {output:$output,replaced:1,transaction:{committed:true}} elif $verb == "edit" then {output:$output,ops_applied:1,replacements:1,results:[{op:"set_run_text",at:"p[2]/r[1]",expect:"F1B-DOCX-TEMPLATE-V1",text:"F1B-DOCX-EDITED-V1",find:null,matched:1,replacements:1}],transaction:{committed:true}} elif $verb == "replay" then {output:$output,bytes_written:1,ops_applied:1} elif $verb == "raw" and $schema == "office.raw.inventory/1" and $canned_raw == "1" then {part_count:1,parts:[]} elif $verb == "raw" and $schema == "office.raw.inventory/1" then {part_count:3,parts:[{name:"xl/workbook.xml"},{name:"xl/worksheets/sheet1.xml"},{name:"xl/charts/chart1.xml"}]} elif $verb == "raw" and $format == "docx" and $canned_raw == "1" then {content:"<document/>"} elif $verb == "raw" and $format == "docx" then {content:"<document>F1B-DOCX-HEADING-V1 F1B-DOCX-TEMPLATE-V1 F1B-DOCX-LIST-V1 F1B-DOCX-TABLE-V1</document>"} elif $verb == "annotate" then {output:$output,ops_applied:3,results:[{op:"comment_add",comment_id:"0",done:null,anchor:"/docx/body/p[2]"},{op:"comment_reply",comment_id:"1",done:null,target:"0"},{op:"comment_resolve",comment_id:"0",done:true,target:"0"}],labels:[{label:"root",comment_id:"0"},{label:"answer",comment_id:"1"}],transaction:{committed:true}} else {} end) end'\''' \
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
  /usr/bin/install -m 0400 "$script_dir/attest.py" \
    "$install_root/control/attest.py"
  /usr/bin/install -m 0400 "$script_dir/argument_policy.py" \
    "$install_root/control/argument-policy.py"
  /usr/bin/install -m 0400 "$script_dir/auth_guard.py" \
    "$install_root/control/auth-guard.py"
  /usr/bin/install -m 0400 "$script_dir/command_policy.py" \
    "$install_root/control/command-policy.py"
  /usr/bin/install -m 0400 "$script_dir/opc_policy.py" \
    "$install_root/control/opc-policy.py"
  /usr/bin/install -m 0400 "$script_dir/transcript_policy.py" \
    "$install_root/control/transcript-policy.py"
  /usr/bin/install -m 0400 "$script_dir/scenario_policy.py" \
    "$install_root/control/scenario-policy.py"
  /usr/bin/install -m 0400 "$script_dir/evidence_policy.py" \
    "$install_root/control/evidence-policy.py"
  /usr/bin/install -m 0400 "$script_dir/build_host_discovery.py" \
    "$install_root/control/build-host-discovery.py"
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
    --arg platform "$build_platform" '
    def tool($selected; $resolved; $sha; $version): {
      bytes: 1,
      kind: "file",
      mode: "0755",
      resolved_path: $resolved,
      selected_kind: "file",
      selected_path: $selected,
      sha256: $sha,
      version: [$version]
    };
    {
      schema: "office.fresh-agent.build-host-discovery/1",
      platform: $platform,
      environment: {
        lang: "C",
        lc_all: "C",
        path: "/usr/bin:/bin:/usr/sbin:/sbin",
        sdkroot: (if $platform == "darwin-arm64" then "/fixture/sdk" else null end)
      },
      tools: {
        compiler: tool("/usr/bin/cc"; "/usr/bin/cc"; ("2" * 64); "fixture cc 1"),
        archiver: tool("/usr/bin/ar"; "/usr/bin/ar"; ("3" * 64); "fixture ar 1"),
        linker: tool("/usr/bin/ld"; "/usr/bin/ld"; ("4" * 64); "fixture ld 1"),
        assembler: tool("/usr/bin/as"; "/usr/bin/as"; ("5" * 64); "fixture as 1")
      },
      sdk: {
        kind: "directory",
        mode: "0755",
        resolved_path: (if $platform == "darwin-arm64" then "/fixture/sdk" else "/" end),
        selected_kind: "directory",
        selected_path: (if $platform == "darwin-arm64" then "/fixture/sdk" else "/" end)
      },
      compiler_queries: {
        reported_sysroot: (if $platform == "darwin-arm64" then "/fixture/sdk" else "/" end),
        resource_directory: {
          kind: "directory",
          mode: "0755",
          resolved_path: "/fixture/compiler/include",
          selected_kind: "directory",
          selected_path: "/fixture/compiler/include"
        },
        runtime_files: [{name: "fixture-runtime", reported: "fixture-runtime", path: null}],
        search_directories: ["programs: =/usr/bin"],
        target: (if $platform == "darwin-arm64"
          then "arm64-apple-darwin" else "x86_64-linux-gnu" end)
      },
      inventory_paths: [
        "/fixture/compiler/include", "/usr/bin/ar", "/usr/bin/as",
        "/usr/bin/cc", "/usr/bin/ld"
      ],
      loader: (if $platform == "darwin-arm64" then {
        strategy: "mach-o-and-dyld-images",
        declared_dependencies: [{declared: "/usr/lib/libSystem.B.dylib"}],
        loaded_images: [{path: "/usr/lib/libSystem.B.dylib"}]
      } else {
        strategy: "ldd",
        dependencies: [{library: "libc.so.6", tool: "compiler", path: null}]
      } end)
    }' > "$install_root/control/build-host-discovery.json"
  chmod 0400 "$install_root/control/build-host-discovery.json"
  build_host_discovery_sha="$(
    sha256_file "$install_root/control/build-host-discovery.json"
  )"
  /usr/bin/jq -n \
    --arg schema "office.fresh-agent.build-host/2" \
    --arg platform "$build_platform" \
    --arg manifest_sha "$build_host_manifest_sha" \
    --arg discovery_sha "$build_host_discovery_sha" \
    --arg plan_sha "$native_plan_sha" \
    '{
      schema: $schema,
      platform: $platform,
      discovery: {
        schema: "office.fresh-agent.build-host-discovery/1",
        sha256: $discovery_sha
      },
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
        resource_dir: {
          selected_path: "/fixture/compiler/include",
          resolved_path: "/fixture/compiler/include"
        }
      },
      archiver: {
        selected_path: "/usr/bin/ar",
        resolved_path: "/usr/bin/ar",
        sha256: ("3" * 64)
      },
      linker: {
        selected_path: "/usr/bin/ld",
        resolved_path: "/usr/bin/ld",
        sha256: ("4" * 64),
        version: "fixture ld 1"
      },
      assembler: {
        selected_path: "/usr/bin/as",
        resolved_path: "/usr/bin/as",
        sha256: ("5" * 64)
      },
      sdk: {
        kind: (if $platform == "darwin-arm64"
          then "macos-sdk" else "linux-sysroot" end),
        selected_path: (if $platform == "darwin-arm64" then "/fixture/sdk" else "/" end),
        resolved_path: (if $platform == "darwin-arm64" then "/fixture/sdk" else "/" end),
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
  attest_sha="$(sha256_file "$install_root/control/attest.py")"
  argument_policy_sha="$(sha256_file "$install_root/control/argument-policy.py")"
  auth_guard_sha="$(sha256_file "$install_root/control/auth-guard.py")"
  command_policy_sha="$(sha256_file "$install_root/control/command-policy.py")"
  opc_policy_sha="$(sha256_file "$install_root/control/opc-policy.py")"
  transcript_policy_sha="$(sha256_file "$install_root/control/transcript-policy.py")"
  scenario_policy_sha="$(sha256_file "$install_root/control/scenario-policy.py")"
  evidence_policy_sha="$(sha256_file "$install_root/control/evidence-policy.py")"
  build_host_discovery_policy_sha="$(
    sha256_file "$install_root/control/build-host-discovery.py"
  )"
  private_sha="$(sha256_file "$install_root/control/private.json")"
  inventory_sha="$(sha256_file "$install_root/control/inventory.sh")"
  build_lock_sha="$(sha256_file "$install_root/control/build-lock.json")"

  /usr/bin/jq -n \
    --arg schema "office.fresh-agent.candidate/5" \
    --arg candidate_head "$head" \
    --arg build_platform "$build_platform" \
    --arg build_lock_sha "$build_lock_sha" \
    --arg toolchain_manifest_sha "$toolchain_manifest_sha" \
    --arg dependency_manifest_sha "$dependency_manifest_sha" \
    --arg build_host_sha "$build_host_sha" \
    --arg build_host_manifest_sha "$build_host_manifest_sha" \
    --arg build_host_discovery_policy_sha "$build_host_discovery_policy_sha" \
    --arg build_host_discovery_sha "$build_host_discovery_sha" \
    --arg native_sha "$native_sha" \
    --arg wasm_wrapper_sha "$wasm_wrapper_sha" \
    --arg moonrun_sha "$moonrun_sha" \
    --arg wasm_sha "$wasm_sha" \
    --arg runner_sha "$runner_sha" \
    --arg prompt_sha "$prompt_sha" \
    --arg schema_sha "$schema_sha" \
    --arg canary_sha "$canary_sha" \
    --arg attest_sha "$attest_sha" \
    --arg argument_policy_sha "$argument_policy_sha" \
    --arg auth_guard_sha "$auth_guard_sha" \
    --arg command_policy_sha "$command_policy_sha" \
    --arg opc_policy_sha "$opc_policy_sha" \
    --arg transcript_policy_sha "$transcript_policy_sha" \
    --arg scenario_policy_sha "$scenario_policy_sha" \
    --arg evidence_policy_sha "$evidence_policy_sha" \
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
        build_host_discovery_policy_sha256: $build_host_discovery_policy_sha,
        build_host_discovery_sha256: $build_host_discovery_sha,
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
        {path: "control/attest.py", kind: "file", mode: "0400", sha256: $attest_sha},
        {path: "control/argument-policy.py", kind: "file", mode: "0400", sha256: $argument_policy_sha},
        {path: "control/auth-guard.py", kind: "file", mode: "0400", sha256: $auth_guard_sha},
        {path: "control/command-policy.py", kind: "file", mode: "0400", sha256: $command_policy_sha},
        {path: "control/opc-policy.py", kind: "file", mode: "0400", sha256: $opc_policy_sha},
        {path: "control/transcript-policy.py", kind: "file", mode: "0400", sha256: $transcript_policy_sha},
        {path: "control/scenario-policy.py", kind: "file", mode: "0400", sha256: $scenario_policy_sha},
        {path: "control/evidence-policy.py", kind: "file", mode: "0400", sha256: $evidence_policy_sha},
        {path: "control/private.json", kind: "file", mode: "0400", sha256: $private_sha},
        {path: "control/inventory.sh", kind: "file", mode: "0500", sha256: $inventory_sha},
        {path: "control/build-lock.json", kind: "file", mode: "0400", sha256: $build_lock_sha},
        {path: "control/toolchain.manifest", kind: "file", mode: "0400", sha256: $toolchain_manifest_sha},
        {path: "control/dependencies.manifest", kind: "file", mode: "0400", sha256: $dependency_manifest_sha},
        {path: "control/build-host.json", kind: "file", mode: "0400", sha256: $build_host_sha},
        {path: "control/build-host.manifest", kind: "file", mode: "0400", sha256: $build_host_manifest_sha},
        {path: "control/build-host-discovery.py", kind: "file", mode: "0400", sha256: $build_host_discovery_policy_sha},
        {path: "control/build-host-discovery.json", kind: "file", mode: "0400", sha256: $build_host_discovery_sha}
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
  printf 'auth_source=%q\n' "$case_root/auth.json"
  printf '%s\n' \
    'mode=$(/bin/cat "$mode_file")' \
    ': <&9' \
    'file_limit=$(ulimit -f)' \
    'test "$file_limit" != unlimited' \
    'test "$file_limit" -le 131072' \
    'descriptor_limit=$(ulimit -n)' \
    'test "$descriptor_limit" -le 256' \
    'cpu_limit=$(ulimit -t)' \
    'test "$cpu_limit" != unlimited' \
    'test "$cpu_limit" -le 1900' \
    'process_limit=$(ulimit -u)' \
    'test "$process_limit" != unlimited' \
    'if [ "$(/usr/bin/uname -s)" = "Linux" ]; then address_limit=$(ulimit -v); test "$address_limit" != unlimited; test "$address_limit" -le 4194304; fi' \
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
    '/usr/bin/grep -q '\''job-sentinel" = "deny"$'\'' "$config"' \
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
    '  if [ -d "$isolation_root/auth-guard" ]; then' \
    '    /bin/mv "$auth_source" "$auth_source.held.$$"' \
    '    /usr/bin/printf "{}\\n" > "$auth_source"' \
    '    chmod 0600 "$auth_source"' \
    '  fi' \
    '  /bin/mkdir -p "$TMPDIR/codex-bwrap-synthetic-mount-targets-fake"' \
    '  : > "$TMPDIR/codex-bwrap-synthetic-mount-targets-fake/lock"' \
    '  printf "FRESH-AGENT PERMISSION CANARY PASS\\n"' \
    '  exit 0' \
    'fi' \
    'test "$command" = "exec"' \
    'test -f "$CODEX_HOME/auth.json"' \
    '/usr/bin/jq -e '\''type == "object" and keys == []'\'' "$CODEX_HOME/auth.json" >/dev/null' \
    'test ! -e "$isolation_root/auth-guard"' \
    'if [ "$mode" = "orphan-child" ]; then' \
    '  (trap "" HUP INT TERM; while :; do /bin/sleep 1; done) &' \
    '  printf "%s\n" "$!" > "$mode_file.child-pid"' \
    '  exit 0' \
    'fi' \
    'if [ "$mode" = "detached-child" ]; then' \
    '  /usr/bin/perl -MPOSIX -e '\''POSIX::setsid(); $SIG{HUP}=$SIG{INT}=$SIG{TERM}="IGNORE"; open my $out, ">", $ARGV[0] or die $!; print {$out} "$$\\n"; close $out; sleep 60'\'' "$mode_file.child-pid" &' \
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
    'if [ "$mode" = "resource-exhaustion" ] || [ "$mode" = "resource-state-exhaustion" ] || [ "$mode" = "resource-evidence-exhaustion" ]; then' \
    '  resource_path=resource.bin' \
    '  if [ "$mode" = "resource-state-exhaustion" ]; then resource_path="$CODEX_HOME/runtime-tmp/resource.bin"; fi' \
    '  if [ "$mode" = "resource-evidence-exhaustion" ]; then resource_path="$output.resource.bin"; fi' \
    '  /bin/dd if=/dev/zero of="$resource_path" bs=1048576 count=4 2>/dev/null' \
    '  trap "" HUP INT TERM' \
    '  while :; do /bin/sleep 1; done' \
    'fi' \
    'if [ "$mode" = "resource-process-exhaustion" ]; then' \
    '  child=0' \
    '  while [ "$child" -lt 8 ]; do /bin/sleep 60 & child=$((child + 1)); done' \
    '  wait' \
    'fi' \
    'if [ "$mode" = "resource-rss-exhaustion" ]; then' \
    '  /usr/bin/perl -e '\''$data = "x" x (32 * 1024 * 1024); sleep 60'\''' \
    'fi' \
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
    'if [ "$mode" = "oversized-transcript" ]; then' \
    '  emit_started oversized-transcript "true"' \
    '  /usr/bin/printf '\''{"type":"item.completed","item":{"id":"oversized-transcript","type":"command_execution","command":"true","aggregated_output":"'\''' \
    '  /bin/dd if=/dev/zero bs=1048576 count=2 2>/dev/null | /usr/bin/tr "\\000" x' \
    '  /usr/bin/printf '\''","exit_code":0,"status":"completed"}}\\n'\''' \
    'fi' \
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
    '  spoof-office|missing-create|pre-canary|completion-before-start|fractional-exit|out-of-domain-exit|missing-turn-completed|turn-failed|detaching-command|oversized-transcript) stop_after=all/help ;;' \
    '  format-redirection-spoof|newline-mask|help-only|comment-spoof|uppercase-result-path|wrong-result-schema|invalid-artifact|generic-zip-artifact|decoy-opc-root|nested-content-types|nested-relationships|oversized-zip-entry|zip-symlink-artifact) stop_after=native/xlsx/create ;;' \
    '  duplicate-result-path|aliased-result-parent|reused-event-id|wrong-output-role) stop_after=native/xlsx/batch ;;' \
    '  input-redirection|cross-format) stop_after=native/xlsx/validate ;;' \
    'esac' \
    'for runtime in native wasm; do' \
    '  /bin/mkdir -p "$runtime/xlsx" "$runtime/docx"' \
    '  chmod 0700 "$runtime" "$runtime/xlsx" "$runtime/docx"' \
    '  /usr/bin/printf "%s\\n" '\''{"schema":"xlsx.batch/2","ops":[{"op":"set","params":{"sheet":"Data","cell":"A1","value":"F1B-XLSX-REPRESENTATIVE-V1"}},{"op":"set","params":{"sheet":"Data","cell":"B2","value":30}},{"op":"set","params":{"sheet":"Data","cell":"B3","value":70}},{"op":"formula","params":{"sheet":"Data","cell":"B4","formula":"=SUM(B2:B3)"}},{"op":"set","params":{"sheet":"Data","cell":"A5","value":"{{agent_name}}"}},{"op":"chart","params":{"sheet":"Data","anchor":"D2","type":"col","categories":"A2:A3","values":"B2:B3","name":"F1B","title":"Representative"}}]}'\'' > "$runtime/xlsx/batch.json"' \
    '  /usr/bin/printf "%s\\n" '\''{"schema":"office.template.data/1","values":{"agent_name":"F1B-XLSX-TEMPLATE-V1"}}'\'' > "$runtime/xlsx/template.json"' \
    '  /usr/bin/printf "%s\\n" '\''{"schema":"docx.batch/2","ops":[{"op":"paragraph","params":{"text":"F1B-DOCX-HEADING-V1","style":"Heading1"}},{"op":"paragraph","params":{"text":"{{agent_name}}"}},{"op":"paragraph","params":{"text":"F1B-DOCX-LIST-V1","list":{"ordered":true}}},{"op":"table","params":{"header_rows":1,"rows":[[{"text":"kind"},{"text":"value"}],[{"text":"marker"},{"text":"F1B-DOCX-TABLE-V1"}]]}},{"op":"paragraph","params":{"runs":[{"link":{"href":"https://example.invalid/f1b","text":"F1B link"}}]}}]}'\'' > "$runtime/docx/batch.json"' \
    '  /usr/bin/printf "%s\\n" '\''{"schema":"office.template.data/1","values":{"agent_name":"F1B-DOCX-TEMPLATE-V1"}}'\'' > "$runtime/docx/template.json"' \
    '  /usr/bin/printf "%s\\n" '\''{"schema":"docx.annotation-batch/1","ops":[{"op":"comment_add","anchor":{"at":"/docx/body/p[2]"},"author":"Reviewer","body":["F1B-DOCX-COMMENT-V1"],"label":"root"},{"op":"comment_reply","parent":{"label":"root"},"author":"Author","body":["F1B-DOCX-REPLY-V1"],"label":"answer"},{"op":"comment_resolve","target":{"label":"root"}}]}'\'' > "$runtime/docx/annotation.json"' \
    '  /usr/bin/printf "%s\\n" '\''{"schema":"docx.edit/2","ops":[{"op":"set_run_text","params":{"at":"p[2]/r[1]","expect":"F1B-DOCX-TEMPLATE-V1","text":"F1B-DOCX-EDITED-V1"}}]}'\'' > "$runtime/docx/edit.json"' \
    '  if [ "$mode" = "wrong-annotation-target" ] && [ "$runtime" = native ]; then' \
    '    /usr/bin/jq '\''.ops[2].target.label = "answer"'\'' "$runtime/docx/annotation.json" > "$runtime/docx/annotation.json.tmp"' \
    '    /bin/mv "$runtime/docx/annotation.json.tmp" "$runtime/docx/annotation.json"' \
    '  fi' \
    '  if [ "$mode" = "wrong-edit-op" ] && [ "$runtime" = native ]; then' \
    '    /usr/bin/jq '\''.ops[0] = {op:"replace_text",params:{find:"F1B-DOCX-TEMPLATE-V1",replace:"F1B-DOCX-EDITED-V1"}}'\'' "$runtime/docx/edit.json" > "$runtime/docx/edit.json.tmp"' \
    '    /bin/mv "$runtime/docx/edit.json.tmp" "$runtime/docx/edit.json"' \
    '  fi' \
    '  chmod 0600 "$runtime/xlsx/batch.json" "$runtime/xlsx/template.json" "$runtime/docx/batch.json" "$runtime/docx/template.json" "$runtime/docx/annotation.json" "$runtime/docx/edit.json"' \
    'done' \
    'if [ "$mode" != "no-office" ]; then' \
    '  index=0' \
    '  for runtime in native wasm; do' \
    '    index=$((index + 1))' \
    '    if [ "$mode" = "spoof-office" ]; then cmd="echo office-$runtime help all --json"; else cmd="office-$runtime help all --json"; fi' \
    '    emit_started "cmd-$index" "$cmd"' \
    '    if [ "$mode" = "spoof-office" ]; then body="spoof"; status=0; elif [ "$mode" = "incomplete-help" ] && [ "$runtime" = native ]; then body='\''{"schema":"office.output/1","success":true,"data":{"schema":"office.capabilities/2","fingerprint":"test:fingerprint","records":[]}}'\''; status=0; else body=$("office-$runtime" help all --json 2>&1); status=$?; fi' \
    '    emit_completed "cmd-$index" "$cmd" "$status" "$body"' \
    '    index=$((index + 1))' \
    '    if [ "$mode" = "spoof-office" ]; then cmd="echo office-$runtime help schemas --json"; else cmd="office-$runtime help schemas --json"; fi' \
    '    emit_started "cmd-$index" "$cmd"' \
    '    if [ "$mode" = "spoof-office" ]; then body="spoof"; status=0; else body=$("office-$runtime" help schemas --json 2>&1); status=$?; fi' \
    '    emit_completed "cmd-$index" "$cmd" "$status" "$body"' \
    '  done' \
    '  if [ "$stop_after" != all/help ]; then' \
    '    for runtime in native wasm; do' \
    '    for format in xlsx docx; do' \
    '      directory="$runtime/$format"' \
    '      if [ "$format" = "xlsx" ]; then' \
    '        created="$directory/created.xlsx"' \
    '        batched="$directory/batched.xlsx"' \
    '        final="$directory/templated.xlsx"' \
    '        replayed="$directory/replayed.xlsx"' \
    '        verbs="create batch template identify outline get text query validate issues preview dump replay raw"' \
    '      else' \
    '        authored="$directory/authored.docx"' \
    '        templated="$directory/templated.docx"' \
    '        final="$directory/annotated.docx"' \
    '        replayed="$directory/replayed.docx"' \
    '        verbs="batch template annotate identify outline get text query validate issues preview dump replay raw edit"' \
    '      fi' \
    '      for verb in $verbs; do' \
    '        if [ "$mode" = "missing-create" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then continue; fi' \
    '        index=$((index + 1))' \
    '        package="$final"' \
    '        case "$verb/$format" in' \
    '          create/xlsx) package="$created"; run_args="xlsx $created" ;;' \
    '          batch/xlsx) package="$batched"; run_args="$created $directory/batch.json --out $batched" ;;' \
    '          template/xlsx) package="$final"; run_args="$batched $directory/template.json --out $final" ;;' \
    '          batch/docx) package="$authored"; run_args="--format docx $authored $directory/batch.json" ;;' \
    '          template/docx) package="$templated"; run_args="$authored $directory/template.json --out $templated" ;;' \
    '          annotate/docx) package="$final"; run_args="$templated $directory/annotation.json --out $final" ;;' \
    '          edit/docx) package="$directory/edited.docx"; run_args="$final $directory/edit.json --out $directory/edited.docx" ;;' \
    '          get/xlsx) run_args="$final '\''/xlsx/sheet[name=\"Data\"]/range[A1:B5]'\''" ;;' \
    '          get/docx) run_args="$final '\''/docx/body/p[1]'\''" ;;' \
    '          preview/*) run_args="$final --output $directory/preview-1.html" ;;' \
    '          replay/*) package="$replayed"; run_args="matrix-$runtime-$format-dump.json --output $replayed" ;;' \
    '          raw/xlsx) run_args="list $final" ;;' \
    '          raw/docx) run_args="read $final part:/document" ;;' \
    '          *) run_args="$final" ;;' \
    '        esac' \
    '        result="matrix-$runtime-$format-$verb.json"' \
    '        if [ "$mode" = "aliased-result-parent" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then /bin/mkdir -m 0700 results; /bin/ln -s results aliases; result=results/create.json; fi' \
    '        if [ "$mode" = "aliased-result-parent" ] && [ "$runtime/$format/$verb" = "native/xlsx/batch" ]; then result=aliases/batch.json; fi' \
    '        if [ "$mode" = "duplicate-result-path" ] && { [ "$runtime/$format/$verb" = "native/xlsx/create" ] || [ "$runtime/$format/$verb" = "native/xlsx/batch" ]; }; then result=duplicate-result.json; fi' \
    '        if [ "$mode" = "uppercase-result-path" ] && [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then result=Uppercase-result.json; fi' \
    '        if [ "$mode" = "spoof-office" ]; then cmd="echo office-$runtime $verb $run_args --json --attest-result $result"; else cmd="office-$runtime $verb $run_args --json --attest-result $result"; fi' \
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
    '          if [ "$runtime/$format/$verb" = "native/xlsx/create" ]; then' \
    '            if [ "$mode" = "invalid-artifact" ]; then printf '\''not an Office package\n'\'' > "$package"; fi' \
    '            if [ "$mode" = "generic-zip-artifact" ]; then printf '\''payload\n'\'' > generic-payload.txt; /usr/bin/zip -q "$package" generic-payload.txt; /bin/rm -f generic-payload.txt; fi' \
    '            if [ "$mode" = "decoy-opc-root" ] || [ "$mode" = "nested-content-types" ] || [ "$mode" = "nested-relationships" ]; then' \
    '              office-native create xlsx "$package" --json >/dev/null' \
    '              package_path=$PWD/$package' \
    '              opc_tmp=$TMPDIR/adversarial-opc-$$' \
    '              /bin/rm -rf -- "$opc_tmp"' \
    '              /bin/mkdir -m 0700 "$opc_tmp"' \
    '              /usr/bin/unzip -q "$package_path" -d "$opc_tmp"' \
    '              if [ "$mode" = "decoy-opc-root" ]; then printf "%s\n" '\''<decoy><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"/></decoy>'\'' > "$opc_tmp/xl/workbook.xml"; fi' \
    '              if [ "$mode" = "nested-content-types" ]; then printf "%s\n" '\''<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Wrapper><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Wrapper></Types>'\'' > "$opc_tmp/[Content_Types].xml"; fi' \
    '              if [ "$mode" = "nested-relationships" ]; then printf "%s\n" '\''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Wrapper><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Wrapper></Relationships>'\'' > "$opc_tmp/_rels/.rels"; fi' \
    '              /bin/rm -f -- "$package_path"' \
    '              (cd "$opc_tmp" && /usr/bin/find "[Content_Types].xml" _rels xl -type f -print | LC_ALL=C /usr/bin/sort | /usr/bin/zip -q "$package_path" -@)' \
    '              /bin/rm -rf -- "$opc_tmp"' \
    '            fi' \
    '            if [ "$mode" = "oversized-zip-entry" ]; then /bin/dd if=/dev/zero of=oversized.bin bs=1048576 count=65 2>/dev/null; /usr/bin/zip -q "$package" oversized.bin; /bin/rm -f oversized.bin; fi' \
    '            if [ "$mode" = "zip-symlink-artifact" ]; then : > symlink-target; /bin/ln -s symlink-target package-link; /usr/bin/zip -q -y "$package" package-link; /bin/rm -f package-link symlink-target; fi' \
    '          fi' \
    '          set +e' \
    '          if [ "$mode" = "wrong-output-role" ] && [ "$runtime/$format/$verb" = "native/xlsx/batch" ]; then' \
    '            OFFICE_F1B_WRONG_OUTPUT_ROLE=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "empty-semantic-package" ] && [ "$runtime/$format/$verb" = "native/xlsx/batch" ]; then' \
    '            OFFICE_F1B_EMPTY_SEMANTICS=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "empty-replay-package" ] && [ "$runtime/$format/$verb" = "native/xlsx/replay" ]; then' \
    '            OFFICE_F1B_EMPTY_SEMANTICS=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "inconsistent-replay-package" ] && [ "$runtime/$format/$verb" = "native/xlsx/replay" ]; then' \
    '            OFFICE_F1B_INCONSISTENT_SEMANTICS=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "wrong-annotation-anchor" ] && [ "$runtime/$format/$verb" = "native/docx/annotate" ]; then' \
    '            OFFICE_F1B_WRONG_ANNOTATION_ANCHOR=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "canned-get" ] && [ "$runtime/$format/$verb" = "native/xlsx/get" ]; then' \
    '            OFFICE_F1B_CANNED_GET=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "canned-raw" ] && [ "$runtime/$format/$verb" = "native/xlsx/raw" ]; then' \
    '            OFFICE_F1B_CANNED_RAW=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "canned-docx-raw" ] && [ "$runtime/$format/$verb" = "native/docx/raw" ]; then' \
    '            OFFICE_F1B_CANNED_RAW=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "canned-preview" ] && [ "$runtime/$format/$verb" = "native/xlsx/preview" ]; then' \
    '            OFFICE_F1B_CANNED_PREVIEW=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "canned-dump" ] && [ "$runtime/$format/$verb" = "native/xlsx/dump" ]; then' \
    '            OFFICE_F1B_CANNED_DUMP=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          elif [ "$mode" = "unknown-runtime-warning" ] && [ "$runtime/$format/$verb" = "wasm/xlsx/get" ]; then' \
    '            OFFICE_F1B_UNKNOWN_WARNING=1 "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          else' \
    '            "office-$runtime" "$verb" $run_args --json --attest-result "$result" > "$result.attestation" 2> "$result.stderr"' \
    '          fi' \
    '          status=$?' \
    '          set -e' \
    '          body=$(/bin/cat "$result.attestation"; /bin/cat "$result.stderr"; /usr/bin/printf _)' \
    '          body=${body%_}' \
    '          /bin/rm -f "$result.attestation" "$result.stderr"' \
    '        fi' \
    '        emit_completed "$event_id" "$cmd" "$status" "$body"' \
    '        if [ "$stop_after" = "$runtime/$format/$verb" ]; then break 3; fi' \
    '        supplemental_verb=""' \
    '        if [ -z "$stop_after" ] && [ "$mode" != "shallow-scenario" ]; then' \
    '          case "$verb" in' \
    '            preview) supplemental_verb=preview; supplemental_args="$final --output $directory/preview-2.html"; supplemental_result="scenario-$runtime-$format-preview-2.json" ;;' \
    '            replay) supplemental_verb=dump; supplemental_args="$replayed"; supplemental_result="scenario-$runtime-$format-dump-2.json" ;;' \
    '          esac' \
    '        fi' \
    '        if [ -n "$supplemental_verb" ]; then' \
    '          index=$((index + 1))' \
    '          supplemental_cmd="office-$runtime $supplemental_verb $supplemental_args --json --attest-result $supplemental_result"' \
    '          emit_started "cmd-$index" "$supplemental_cmd"' \
    '          set +e' \
    '          "office-$runtime" "$supplemental_verb" $supplemental_args --json --attest-result "$supplemental_result" > "$supplemental_result.attestation" 2> "$supplemental_result.stderr"' \
    '          supplemental_status=$?' \
    '          set -e' \
    '          supplemental_body=$(/bin/cat "$supplemental_result.attestation"; /bin/cat "$supplemental_result.stderr"; /usr/bin/printf _)' \
    '          supplemental_body=${supplemental_body%_}' \
    '          /bin/rm -f "$supplemental_result.attestation" "$supplemental_result.stderr"' \
    '          emit_completed "cmd-$index" "$supplemental_cmd" "$supplemental_status" "$supplemental_body"' \
    '        fi' \
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
    'if [ "$mode" = "host-script-rewrite" ]; then : > force-host-script-rewrite; chmod 0600 force-host-script-rewrite; fi' \
    'if [ "$mode" = "host-staging" ]; then : > force-host-staging; chmod 0600 force-host-staging; fi' \
    'if [ "$mode" = "host-xlsx-corruption" ]; then : > force-host-xlsx-corruption; chmod 0600 force-host-xlsx-corruption; fi' \
    'if [ "$mode" = "host-xlsx-divergent" ]; then : > force-host-xlsx-divergent; chmod 0600 force-host-xlsx-divergent; fi' \
    'if [ "$mode" = "agent-xlsx-corrupt-restore" ]; then /bin/cp native/xlsx/templated.xlsx native/xlsx/legacy-refusal.xlsx; /usr/bin/printf corrupt > native/xlsx/legacy-refusal.xlsx; /bin/cp native/xlsx/templated.xlsx native/xlsx/legacy-refusal.xlsx; fi' \
    'if [ "$mode" = "wrong-result-schema" ]; then printf '\''{"schema":"office.output/1","success":true,"data":{"schema":"office.identify/1","format":"xlsx","file":"native/xlsx/created.xlsx"}}\n'\'' > matrix-native-xlsx-create.json; fi' \
    'if [ "$mode" = "exit19" ]; then exit 19; fi' \
    'verdict="BASELINE PASS"; outcome="PASS"; gaps="[]"' \
    'if [ "$mode" = "fail" ]; then verdict="BASELINE FAIL"; outcome="FAIL"; gaps='\''[{"severity":"P1","summary":"fake failure"}]'\''; fi' \
    'header="Verdict: $verdict"' \
    'if [ "$mode" = "contradictory" ]; then header="Verdict: BASELINE FAIL"; fi' \
    'if [ "$mode" = "incomplete-report" ]; then' \
    '  printf "%s\\n\\n# Probe result\\n" "$header" > "$probe/probe-result.md"' \
    'else' \
    '  printf "%s\\nNative XLSX: %s\\nNative DOCX: %s\\nWasm XLSX: %s\\nWasm DOCX: %s\\nCapability schema: office.capabilities/2\\nCapability fingerprint: test:fingerprint\\nDiscoverability: %s\\nNative/Wasm comparison: %s\\n\\n# Probe result\\n" "$header" "$outcome" "$outcome" "$outcome" "$outcome" "$outcome" "$outcome" > "$probe/probe-result.md"' \
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
  (.evidence.raw_commands_sha256 | test("^[0-9a-f]{64}$")) and
  (.evidence.workflows_sha256 | test("^[0-9a-f]{64}$")) and
  (.evidence.xlsx_refusals_sha256 | test("^[0-9a-f]{64}$")) and
  (.evidence.docx_refusals_sha256 | test("^[0-9a-f]{64}$")) and
  (.evidence.scenarios_sha256 | test("^[0-9a-f]{64}$"))
' "$evidence/RUN.json" >/dev/null ||
  fail "final run manifest"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.run-preflight/2" and
  .candidate_head == $head and
  .codex.version == "codex-cli 0.145.0" and
  .codex.privately_staged == true and
  .codex.bubblewrap == null and
  .harness.credential_guard.delayed_staging == true and
  .harness.credential_guard.source_open == "component-wise O_NOFOLLOW retained FD" and
  (.harness.credential_guard.policy_sha256 | test("^[0-9a-f]{64}$")) and
  (.harness.argument_policy_sha256 | test("^[0-9a-f]{64}$")) and
  .harness.job_identity.inherited_fd == 9 and
  .harness.job_identity.detached_member_discovery == "lsof" and
  (.harness.job_identity.sentinel_sha256 | test("^[0-9a-f]{64}$")) and
  .harness.resource_policy == {
    cpu_seconds: 1900,
    file_size_bytes: 134217728,
    open_files: 256,
    process_count: 128,
    rss_kib: 4194304,
    storage_kib: 524288,
    storage_entries: 8192,
    virtual_memory_kib: (if $platform == "Linux" then 4194304 else null end),
    writable_roots: ["probe", "evidence", "home", "scratch", "codex_state"]
  } and
  .harness.policy_readonly_canary == {
    host_write_preflight: true,
    sandbox_write_denied: true,
    host_write_postflight: true
  }
' --arg head "$head" --arg platform "$(/usr/bin/uname -s)" \
  "$evidence/RUN-PREFLIGHT.json" >/dev/null ||
  fail "preflight manifest"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.evidence/2" and
  .artifact_count == (.artifacts | length) and
  .file_count > 20 and
  .total_bytes > 0 and
  (.artifacts | map(.path) | index("codex-stderr.log")) != null and
  (.artifacts | map(.path) | index("COMMANDS.json")) != null and
  (.artifacts | map(.path) | index("RAW-COMMANDS.json")) != null and
  (.artifacts | map(.path) | index("WORKFLOWS.json")) != null and
  (.artifacts | map(.path) | index("XLSX-REFUSALS.json")) != null and
  (.artifacts | map(.path) | index("DOCX-REFUSALS.json")) != null and
  (.artifacts | map(.path) | index("SCENARIOS.json")) != null and
  (.artifacts | map(.path) | index("closure/candidate/control/build-host.json")) != null and
  (.artifacts | map(.path) | index("closure/probe/probe-result.md")) != null and
  (.artifacts | map(.path) |
    any(startswith("closure/probe/input-evidence/event-"))) and
  (.artifacts | map(.path) | index("closure/runtime/RUNTIME.json")) != null and
  (.artifacts | map(.path) | index("closure/runtime/codex")) != null and
  (.artifacts[] | select(.path == "closure/candidate/bin/office")) == {
    kind: "symlink",
    path: "closure/candidate/bin/office",
    target: "office-native"
  }
' "$evidence/EVIDENCE.json" >/dev/null ||
  fail "complete evidence manifest"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C \
  /usr/bin/python3 -I \
    "$evidence/closure/candidate/control/evidence-policy.py" verify \
    --evidence-root "$evidence" \
    --manifest "$evidence/EVIDENCE.json" \
    --timeout-seconds 30 ||
  fail "independent evidence manifest verification"
[ "$(/usr/bin/jq 'length' "$evidence/COMMANDS.json")" -eq 73 ] ||
  fail "host-derived command inventory"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.workflows/5" and
  .required_count == 60 and
  (.workflows | length) == 60 and
  (.workflows | all((.events | length) == 1)) and
  ([.workflows[].events[].event_id] as $ids |
    ($ids | length) == 60 and ($ids | unique | length) == 60) and
  ([.workflows[].events[].result.path | select(. != null)] as $paths |
    ($paths | length) == 58 and ($paths | unique | length) == 58) and
  (.workflows | all(
    if .format == "all" then
      (.events | all(.artifact == null and .inputs == [] and .result.path == null))
    else
      (.events | all(
        (.artifact.sha256 | test("^[0-9a-f]{64}$")) and
        (.artifact.bytes | type) == "number" and .artifact.bytes > 0 and
        (.inputs | type) == "array" and
        (.inputs | all(
          (.snapshot.path | startswith("input-evidence/event-")) and
          (.snapshot.sha256 | test("^[0-9a-f]{64}$"))
        )) and
        (.result.bytes | type) == "number" and .result.bytes > 0 and
        (.result.path | type) == "string"
      ))
    end
  ))
' "$evidence/WORKFLOWS.json" >/dev/null ||
  fail "host-derived workflow matrix"
/usr/bin/jq -e '
  keys == ["refusals", "required_count", "schema"] and
  .schema == "office.fresh-agent.xlsx-refusals/1" and
  .required_count == 2 and
  [.refusals[].runtime] == ["native", "wasm"] and
  [.refusals[].sequence] == [1, 2] and
  (.refusals | all(
    .error_code == "office.transaction.output_exists" and
    (.exit_status | type) == "number" and .exit_status > 0 and
    .target_exists_before == true and .target_exists_after == true and
    .before.sha256 == .target.sha256 and .before.bytes == .target.bytes and
    .staging_before == [] and .staging_after == [] and
    .postcondition == "immediate-after-process-exit" and
    (.source.sha256 | test("^[0-9a-f]{64}$")) and
    (.script.sha256 | test("^[0-9a-f]{64}$")) and
    (.diagnostic.sha256 | test("^[0-9a-f]{64}$"))
  ))
' "$evidence/XLSX-REFUSALS.json" >/dev/null ||
  fail "host-controlled XLSX refusal evidence"
/usr/bin/jq -e '
  keys == ["refusals", "required_count", "schema"] and
  .schema == "office.fresh-agent.docx-refusals/1" and
  .required_count == 2 and
  [.refusals[].runtime] == ["native", "wasm"] and
  [.refusals[].sequence] == [1, 2] and
  (.refusals | all(
    .error_code == "office.docx.batch_parse" and
    (.exit_status | type) == "number" and .exit_status > 0 and
    .output_absent_before == true and .output_absent_after == true and
    .staging_before == [] and .staging_after == [] and
    .postcondition == "immediate-after-process-exit" and
    (.script.sha256 | test("^[0-9a-f]{64}$")) and
    (.diagnostic.sha256 | test("^[0-9a-f]{64}$"))
  ))
' "$evidence/DOCX-REFUSALS.json" >/dev/null ||
  fail "host-controlled DOCX refusal evidence"
/usr/bin/jq -e '
  .schema == "office.fresh-agent.scenarios/1" and
  .required_count == 4 and
  (.scenarios | length) == 4 and
  (.cross_runtime | keys) == ["docx", "xlsx"] and
  (.scenarios | all(
    (.runtime == "native" or .runtime == "wasm") and
    (.format == "xlsx" or .format == "docx") and
    (.final_artifact.sha256 | test("^[0-9a-f]{64}$")) and
    (.lineage | length) == (if .format == "docx" then 16 else 15 end) and
    (.preview.sha256 | test("^[0-9a-f]{64}$")) and
    (.preview.semantic_sha256 | test("^[0-9a-f]{64}$")) and
    (.dump_fixpoint_sha256 | test("^[0-9a-f]{64}$")) and
    (if .format == "docx" then (.edit_script_sha256 | test("^[0-9a-f]{64}$"))
     else .edit_script_sha256 == null end) and
    (.diagnostic_inventory | type) == "array" and
    .package_semantics.authored.template_state == "placeholder" and
    .package_semantics.final.template_state == "merged" and
    .package_semantics.replayed == .package_semantics.final and
    (if .format == "xlsx" then
       .package_semantics.final.formula == true and
       .package_semantics.final.numeric == true and
       .package_semantics.final.chart_series > 0
     else
       .package_semantics.final.annotations == "add-reply-resolve" and
       .package_semantics.final.external_hyperlink == true
     end) and
    .refusal.error_code ==
      (if .format == "xlsx" then
         "office.transaction.output_exists"
       else
         "office.docx.batch_parse"
       end) and
    .refusal.execution == "host-controlled-immediate" and
    (.refusal.script_semantic_sha256 | test("^[0-9a-f]{64}$")) and
    (.refusal.diagnostic_semantic_sha256 | test("^[0-9a-f]{64}$")) and
    (.refusal.diagnostic_core.error.message | type) == "string" and
    (if .format == "xlsx" then
       .raw_semantics == {chart_part:true, workbook_part:true, worksheet_part:true}
     else
       .raw_semantics.main_document_content == true
     end)
  )) and
  (.cross_runtime | all(
    (.diagnostics.shared_sha256 | test("^[0-9a-f]{64}$")) and
    (.diagnostics.target_limitations | length) > 0 and
    (.diagnostics.target_limitations | all(
      .field == "warnings" and
      .value.code == "office.transaction.wasm_commit_semantics"
    ))
  )) and
  ([.scenarios[] | .runtime + "/" + .format] | unique) ==
    ["native/docx", "native/xlsx", "wasm/docx", "wasm/xlsx"]
' "$evidence/SCENARIOS.json" >/dev/null ||
  fail "host-derived semantic scenarios"
[ ! -e "$probe/probe-transcript.md" ] ||
  fail "agent unexpectedly authored the command transcript"
[ "$(/usr/bin/grep -c '^## Event ' "$evidence/probe-transcript.md")" -eq 73 ] ||
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

printf 'agent-xlsx-corrupt-restore\n' > "$codex_bin_dir/mode"
"$runner" \
  "$head" \
  "$candidate_sha" \
  "$case_root/agent-xlsx-corrupt-restore-probe" \
  "$case_root/agent-xlsx-corrupt-restore-evidence" \
  "$case_root/auth.json" \
  "$codex_bin_dir/codex" \
  "$codex_sha" \
  > "$case_root/agent-xlsx-corrupt-restore.stdout"
/usr/bin/grep -Fq "verdict=BASELINE PASS" \
  "$case_root/agent-xlsx-corrupt-restore.stdout" ||
  fail "agent-side XLSX corrupt/restore cannot replace host refusal evidence"
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
  .schema == "office.fresh-agent.canary-evidence/2" and
  .artifact_count == (.artifacts | length) and
  (.artifacts | map(.path) | index("closure/candidate/CANDIDATE.json")) != null and
  (.artifacts | map(.path) | index("closure/probe")) != null and
  (.artifacts | map(.path) | index("closure/runtime/codex")) != null and
  (.artifacts | map(.path) | index("closure/runtime/bwrap")) == null
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
  if [ "$status" -ne "$expected_status" ]; then
    /bin/cat "$stderr" >&2
    fail "$label status: expected $expected_status, found $status"
  fi
  if [ -n "$pattern" ]; then
    if ! /usr/bin/grep -q "$pattern" "$stderr"; then
      /bin/cat "$stderr" >&2
      fail "$label diagnostic"
    fi
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

printf 'pass\n' > "$codex_bin_dir/mode"
OFFICE_F1B_POSTPROCESS_TIMEOUT_SECONDS=1 \
expect_failure postprocess-timeout 1 'post-processing exceeded its 1s global deadline' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/postprocess-timeout-probe" \
  "$case_root/postprocess-timeout-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

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
expect_failure auth-symlink 1 'PATH_SYMLINK' \
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

printf 'resource-exhaustion\n' > "$codex_bin_dir/mode"
OFFICE_F1B_PROBE_MAX_KIB=1024 \
expect_failure resource-exhaustion 125 'bounded resource policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/resource-probe" "$case_root/resource-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'resource-state-exhaustion\n' > "$codex_bin_dir/mode"
OFFICE_F1B_PROBE_MAX_KIB=1024 \
expect_failure resource-state-exhaustion 125 'bounded resource policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/resource-state-probe" "$case_root/resource-state-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'resource-evidence-exhaustion\n' > "$codex_bin_dir/mode"
OFFICE_F1B_PROBE_MAX_KIB=1024 \
expect_failure resource-evidence-exhaustion 125 'bounded resource policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/resource-evidence-probe" \
  "$case_root/resource-evidence-output" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'resource-process-exhaustion\n' > "$codex_bin_dir/mode"
OFFICE_F1B_PROBE_MAX_PROCESSES=4 \
expect_failure resource-process-exhaustion 125 'reached .* processes' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/resource-process-probe" \
  "$case_root/resource-process-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'resource-rss-exhaustion\n' > "$codex_bin_dir/mode"
OFFICE_F1B_PROBE_MAX_RSS_KIB=8192 \
expect_failure resource-rss-exhaustion 125 'reached .* KiB RSS' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/resource-rss-probe" "$case_root/resource-rss-evidence" \
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

printf 'detached-child\n' > "$codex_bin_dir/mode"
/bin/rm -f -- "$codex_bin_dir/mode.child-pid"
expect_failure detached-child 1 'Codex final message' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/detached-probe" "$case_root/detached-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"
detached_child_pid="$(/bin/cat "$codex_bin_dir/mode.child-pid")"
for _ in {1..20}; do
  detached_child_state="$(
    /bin/ps -o stat= -p "$detached_child_pid" 2>/dev/null |
      /usr/bin/tr -d ' ' || true
  )"
  case "$detached_child_state" in
    "" | Z*) break ;;
  esac
  /bin/sleep 0.1
done
case "$detached_child_state" in
  "" | Z*) ;;
  *) fail "session-detached Codex descendant survived runner cleanup" ;;
esac

printf 'ignore-term\n' > "$codex_bin_dir/mode"
/bin/rm -f -- "$codex_bin_dir/mode.child-pid"
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
for _ in {1..300}; do
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
for _ in {1..100}; do
  [ ! -e "$staged_auth" ] && [ ! -L "$staged_auth" ] && break
  /bin/sleep 0.01
done
if /bin/kill -0 "$signal_runner_pid" 2>/dev/null; then
  /bin/kill -HUP "$signal_runner_pid"
  /bin/kill -INT "$signal_runner_pid"
fi
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

printf 'incomplete-help\n' > "$codex_bin_dir/mode"
expect_failure incomplete-help 1 'complete baseline capability inventory' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/incomplete-help-probe" "$case_root/incomplete-help-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'shallow-scenario\n' > "$codex_bin_dir/mode"
expect_failure shallow-scenario 1 \
  'host-derived scenario semantics failed validation' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/shallow-scenario-probe" \
  "$case_root/shallow-scenario-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'wrong-annotation-target\n' > "$codex_bin_dir/mode"
expect_failure wrong-annotation-target 1 \
  'DOCX annotation resolve must target the marker-bearing root label' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/wrong-annotation-target-probe" \
  "$case_root/wrong-annotation-target-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'wrong-annotation-anchor\n' > "$codex_bin_dir/mode"
expect_failure wrong-annotation-anchor 1 \
  'root comment anchor differs from the annotation result' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/wrong-annotation-anchor-probe" \
  "$case_root/wrong-annotation-anchor-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'wrong-edit-op\n' > "$codex_bin_dir/mode"
expect_failure wrong-edit-op 1 \
  'DOCX edit script must contain exactly one set_run_text operation' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/wrong-edit-op-probe" \
  "$case_root/wrong-edit-op-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'empty-semantic-package\n' > "$codex_bin_dir/mode"
expect_failure empty-semantic-package 1 \
  'has the wrong XLSX template state' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/empty-semantic-package-probe" \
  "$case_root/empty-semantic-package-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'unknown-runtime-warning\n' > "$codex_bin_dir/mode"
expect_failure unknown-runtime-warning 1 \
  'unclassified Wasm-only diagnostic differs for xlsx' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/unknown-runtime-warning-probe" \
  "$case_root/unknown-runtime-warning-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'canned-get\n' > "$codex_bin_dir/mode"
expect_failure canned-get 1 \
  'XLSX get returns the wrong value at B2' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/canned-get-probe" "$case_root/canned-get-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'canned-raw\n' > "$codex_bin_dir/mode"
expect_failure canned-raw 1 \
  'XLSX raw inventory omits workbook, worksheet, or chart parts' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/canned-raw-probe" "$case_root/canned-raw-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'canned-docx-raw\n' > "$codex_bin_dir/mode"
expect_failure canned-docx-raw 1 \
  'DOCX raw main document omits representative content' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/canned-docx-raw-probe" \
  "$case_root/canned-docx-raw-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'canned-preview\n' > "$codex_bin_dir/mode"
expect_failure canned-preview 1 \
  'xlsx preview omits representative content' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/canned-preview-probe" "$case_root/canned-preview-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'canned-dump\n' > "$codex_bin_dir/mode"
expect_failure canned-dump 1 \
  'XLSX dump does not match the retained batch semantics' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/canned-dump-probe" "$case_root/canned-dump-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'empty-replay-package\n' > "$codex_bin_dir/mode"
expect_failure empty-replay-package 1 \
  'replayed package has the wrong XLSX template state' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/empty-replay-package-probe" \
  "$case_root/empty-replay-package-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'inconsistent-replay-package\n' > "$codex_bin_dir/mode"
expect_failure inconsistent-replay-package 1 \
  'replayed package has unexpected representative worksheet cell B1' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/inconsistent-replay-package-probe" \
  "$case_root/inconsistent-replay-package-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'host-script-rewrite\n' > "$codex_bin_dir/mode"
expect_failure host-script-rewrite 1 \
  'host DOCX refusal script changed during execution: native' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/host-script-rewrite-probe" \
  "$case_root/host-script-rewrite-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'host-staging\n' > "$codex_bin_dir/mode"
expect_failure host-staging 1 \
  'host DOCX refusal left transaction staging: native' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/host-staging-probe" \
  "$case_root/host-staging-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'host-xlsx-corruption\n' > "$codex_bin_dir/mode"
expect_failure host-xlsx-corruption 1 \
  'host XLSX refusal changed its existing target: native' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/host-xlsx-corruption-probe" \
  "$case_root/host-xlsx-corruption-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'host-xlsx-divergent\n' > "$codex_bin_dir/mode"
expect_failure host-xlsx-divergent 1 \
  'unclassified Wasm-only diagnostic differs for xlsx' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/host-xlsx-divergent-probe" \
  "$case_root/host-xlsx-divergent-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'missing-create\n' > "$codex_bin_dir/mode"
expect_failure missing-create 1 'exactly one canonical attested workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/missing-create-probe" "$case_root/missing-create-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'format-redirection-spoof\n' > "$codex_bin_dir/mode"
expect_failure format-redirection-spoof 1 'exactly one canonical attested workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/format-spoof-probe" "$case_root/format-spoof-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'newline-mask\n' > "$codex_bin_dir/mode"
expect_failure newline-mask 1 'simple-command acceptance policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/newline-mask-probe" "$case_root/newline-mask-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'help-only\n' > "$codex_bin_dir/mode"
expect_failure help-only 1 \
  'exactly one canonical attested workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/help-only-probe" "$case_root/help-only-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'comment-spoof\n' > "$codex_bin_dir/mode"
expect_failure comment-spoof 1 'simple-command acceptance policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/comment-spoof-probe" "$case_root/comment-spoof-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'input-redirection\n' > "$codex_bin_dir/mode"
expect_failure input-redirection 1 'simple-command acceptance policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/input-redirection-probe" "$case_root/input-redirection-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'cross-format\n' > "$codex_bin_dir/mode"
expect_failure cross-format 1 \
  'exactly one canonical attested workflow: native/xlsx/validate' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/cross-format-probe" "$case_root/cross-format-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'duplicate-result-path\n' > "$codex_bin_dir/mode"
expect_failure duplicate-result-path 1 \
  'exactly one canonical attested workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/duplicate-result-probe" \
  "$case_root/duplicate-result-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'wrong-output-role\n' > "$codex_bin_dir/mode"
expect_failure wrong-output-role 1 'wrong command path role' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/wrong-output-role-probe" \
  "$case_root/wrong-output-role-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'aliased-result-parent\n' > "$codex_bin_dir/mode"
expect_failure aliased-result-parent 1 \
  'exactly one canonical attested workflow: native/xlsx/create' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/aliased-result-probe" \
  "$case_root/aliased-result-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'uppercase-result-path\n' > "$codex_bin_dir/mode"
expect_failure uppercase-result-path 1 'simple-command acceptance policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/uppercase-result-probe" \
  "$case_root/uppercase-result-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'wrong-result-schema\n' > "$codex_bin_dir/mode"
expect_failure wrong-result-schema 1 \
  'workflow result changed after its command completed' \
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
expect_failure detaching-command 1 'simple-command acceptance policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/detaching-command-probe" \
  "$case_root/detaching-command-evidence" \
  "$case_root/auth.json" "$codex_bin_dir/codex" "$codex_sha"

printf 'oversized-transcript\n' > "$codex_bin_dir/mode"
expect_failure oversized-transcript 1 'transcript lifecycle or size policy' \
  "$runner" "$head" "$candidate_sha" \
  "$case_root/oversized-transcript-probe" \
  "$case_root/oversized-transcript-evidence" \
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

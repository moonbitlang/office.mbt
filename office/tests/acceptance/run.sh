#!/usr/bin/env bash
set -euo pipefail

target="${1:-wasm}"
installed_command="${2:-}"
case "$target" in
  native|wasm) ;;
  *)
    echo "usage: $0 [native|wasm] [INSTALLED-OFFICE-COMMAND]" >&2
    exit 2
    ;;
esac
if [ "$#" -gt 2 ]; then
  echo "usage: $0 [native|wasm] [INSTALLED-OFFICE-COMMAND]" >&2
  exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/office-acceptance-${target}.XXXXXX")"
trap 'rm -rf "$work"' EXIT

fail() {
  echo "OFFICE ACCEPTANCE FAIL [$target]: $*" >&2
  exit 1
}

if [ -n "$installed_command" ]; then
  [ -f "$installed_command" ] && [ -x "$installed_command" ] ||
    fail "installed Office command is not executable: $installed_command"
else
  if ! moon build --target "$target" office-cli >"$work/build.log" 2>&1; then
    cat "$work/build.log" >&2
    fail "office build"
  fi
fi

office() {
  if [ -n "$installed_command" ]; then
    "$installed_command" "$@"
  else
    moon run --target "$target" office-cli -- "$@"
  fi
}

json() {
  local expected_data_schema="$1"
  shift
  local output
  local expected_envelope_schema="office.output/1"
  if [ "$expected_data_schema" = "office.dump/1" ]; then
    expected_envelope_schema="office.dump/1"
  fi
  if ! output="$(office "$@" 2>"$work/stderr.log")"; then
    cat "$work/stderr.log" >&2
    fail "command failed: office $* -> $output"
  fi
  if ! jq -s -e \
    --arg envelope "$expected_envelope_schema" \
    --arg data "$expected_data_schema" '
    length == 1 and
    .[0].schema == $envelope and
    (if $envelope == "office.output/1" then
       .[0].success == true and .[0].data.schema == $data
     else
       true
     end)
  ' >/dev/null 2>&1 <<<"$output"; then
    cat "$work/stderr.log" >&2
    fail "command did not emit exactly one $expected_envelope_schema/$expected_data_schema result: office $* -> $output"
  fi
  printf '%s\n' "$output"
}

expect_failure() {
  local output_file="$1"
  shift
  if office "$@" >"$output_file" 2>"$work/stderr.log"; then
    fail "command unexpectedly succeeded: office $*"
  fi
  jq -s -e '
    length == 1 and
    .[0].schema == "office.output/1" and
    .[0].success == false
  ' "$output_file" >/dev/null || {
    cat "$output_file" >&2
    cat "$work/stderr.log" >&2
    fail "failure was not a typed JSON error: office $*"
  }
}

cp "$here/xlsx.batch.json" "$work/xlsx.batch.json"
cp "$here/docx.batch.json" "$work/docx.batch.json"
cp "$here/template-data.json" "$work/template-data.json"
cp "$here/annotation.json" "$work/annotation.json"
cp "$here/edit.json" "$work/edit.json"

# Discovery is schema-driven and advertises the complete supported command set.
capabilities="$(json office.capabilities/2 help all --json)"
jq -e '
  .success == true and
  .data.schema == "office.capabilities/2" and
  (.data.fingerprint | test("^crc32:[0-9a-f]{8}$")) and
  ([.data.records[].name] == [
    "docx", "xlsx", "help", "identify", "outline", "get", "text",
    "query", "validate", "dump", "replay", "issues", "preview",
    "render", "create", "template", "edit", "annotate", "batch", "raw"
  ])
' >/dev/null <<<"$capabilities" || fail "capability registry"

# XLSX: create, author/mutate, inspect, template, validate, preview, dump/replay.
xlsx_create="$(json office.xlsx.create/1 create xlsx "$work/xlsx-blank.xlsx" --sheet Data --json)"
jq -e '.success == true and .data.transaction.committed == true' >/dev/null <<<"$xlsx_create" || fail "xlsx create"

xlsx_batch="$(json office.xlsx.batch/1 batch "$work/xlsx-blank.xlsx" "$work/xlsx.batch.json" --out "$work/xlsx-template.xlsx" --json)"
jq -e '.success == true and .data.stats.operation_count == 9 and .data.transaction.committed == true' >/dev/null <<<"$xlsx_batch" || fail "xlsx batch"

[ "$(json office.identify/1 identify "$work/xlsx-template.xlsx" --json | jq -r '.data.format')" = "xlsx" ] || fail "xlsx identify"
jq -e '.data.sheets[0].name == "Data" and .data.sheets[0].counts.charts == 1' >/dev/null <<<"$(json office.xlsx.outline/1 outline "$work/xlsx-template.xlsx" --json)" || fail "xlsx outline"
jq -e '.data.cells[0].raw.value == "Customer: {{customer}}"' >/dev/null <<<"$(json office.xlsx.element/1 get "$work/xlsx-template.xlsx" '/xlsx/sheet[name="Data"]/range[A1:C3]' --json)" || fail "xlsx get"
jq -e '.data.matched_total >= 6' >/dev/null <<<"$(json office.xlsx.text/1 text "$work/xlsx-template.xlsx" --under '/xlsx/sheet[name="Data"]' --json)" || fail "xlsx text"
jq -e '.data.matched_total == 1 and .data.matches[0].reference == "C2"' >/dev/null <<<"$(json office.xlsx.query/1 query "$work/xlsx-template.xlsx" 'cell[type=formula]' --json)" || fail "xlsx query"

xlsx_template="$(json office.template/1 template "$work/xlsx-template.xlsx" "$work/template-data.json" --out "$work/xlsx-filled.xlsx" --json)"
jq -e '.success == true and .data.replaced == 2 and (.data.missing | length) == 0' >/dev/null <<<"$xlsx_template" || fail "xlsx template"
jq -e '.data.cells[0].raw.value == "Customer: Ada Lovelace" and .data.cells[1].raw.value == 100' >/dev/null <<<"$(json office.xlsx.element/1 get "$work/xlsx-filled.xlsx" '/xlsx/sheet[name="Data"]/range[A1:B1]' --json)" || fail "xlsx template readback"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json office.validate/1 validate "$work/xlsx-filled.xlsx" --json)" || fail "xlsx validate"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json office.issues/1 issues "$work/xlsx-filled.xlsx" --json)" || fail "xlsx issues"
jq -e '.data.format == "xlsx" and .data.charts_rendered == 1' >/dev/null <<<"$(json office.preview/1 preview "$work/xlsx-filled.xlsx" --output "$work/xlsx.html" --json)" || fail "xlsx preview"
jq -e '.data.format == "xlsx" and .data.charts_rendered == 1' >/dev/null <<<"$(json office.preview/1 preview "$work/xlsx-filled.xlsx" --output "$work/xlsx-2.html" --json)" || fail "xlsx second preview"
grep -q '<figure class="chart"' "$work/xlsx.html" || fail "xlsx preview chart"
cmp -s "$work/xlsx.html" "$work/xlsx-2.html" || fail "xlsx preview is not deterministic"

json office.dump/1 dump "$work/xlsx-filled.xlsx" --json >"$work/xlsx.dump.json"
jq -e '
  .format == "xlsx" and
  (.ops | length) > 0 and
  ([.ops[] | select(.op == "chart")] | length) == 1 and
  ([.residual[].code] | index("xlsx.charts_not_dumped")) == null
' "$work/xlsx.dump.json" >/dev/null || fail "xlsx dump chart preservation"
jq -e '.success == true and .data.format == "xlsx"' >/dev/null <<<"$(json office.replay/1 replay "$work/xlsx.dump.json" --output "$work/xlsx-replayed.xlsx" --json)" || fail "xlsx replay"
jq -e '.data.sheets[0].counts.charts == 1' >/dev/null <<<"$(json office.xlsx.outline/1 outline "$work/xlsx-replayed.xlsx" --json)" || fail "xlsx replay chart"
json office.dump/1 dump "$work/xlsx-replayed.xlsx" --json >"$work/xlsx.replayed.dump.json"
# Prove that the complete projected envelope reaches a fixpoint; only
# source-path/byte provenance is contractually ignored.
jq -e '.success == true and .data.format == "xlsx"' >/dev/null <<<"$(json office.replay/1 replay "$work/xlsx.replayed.dump.json" --output "$work/xlsx-replayed-2.xlsx" --json)" || fail "xlsx second replay"
json office.dump/1 dump "$work/xlsx-replayed-2.xlsx" --json >"$work/xlsx.replayed-2.dump.json"
jq -S 'del(.source)' "$work/xlsx.replayed.dump.json" >"$work/xlsx.fixpoint-1.json"
jq -S 'del(.source)' "$work/xlsx.replayed-2.dump.json" >"$work/xlsx.fixpoint-2.json"
cmp -s "$work/xlsx.fixpoint-1.json" "$work/xlsx.fixpoint-2.json" || fail "xlsx complete dump/replay fixpoint"
jq -e '.data.format == "xlsx" and (.data.parts | length) > 0' >/dev/null <<<"$(json office.raw.inventory/1 raw list "$work/xlsx-filled.xlsx" --json)" || fail "xlsx raw list"

# A refused publication must be typed and leave the existing output untouched.
cp "$work/xlsx.html" "$work/xlsx.before.html"
expect_failure "$work/preview-exists.json" preview "$work/xlsx-filled.xlsx" --output "$work/xlsx.html" --json
jq -e '.error.code == "office.transaction.output_exists"' "$work/preview-exists.json" >/dev/null || fail "preview refusal code"
cmp -s "$work/xlsx.html" "$work/xlsx.before.html" || fail "preview refusal mutated output"

# A malformed replay targeting a new path must leave neither output nor a
# staging artifact behind.
jq '.stats.ops += 1' "$work/xlsx.dump.json" >"$work/xlsx.invalid.dump.json"
expect_failure "$work/replay-invalid.json" replay "$work/xlsx.invalid.dump.json" --output "$work/never.xlsx" --json
jq -e '.error.code == "office.replay.invalid_dump"' "$work/replay-invalid.json" >/dev/null || fail "invalid replay code"
[ ! -e "$work/never.xlsx" ] || fail "invalid replay wrote a new output"
[ -z "$(find "$work" -maxdepth 1 -name '.office-output-tmp-*' -print -quit)" ] || fail "invalid replay left a staging artifact"

# DOCX: blank create, fresh authoring, inspect, template, annotate, and replay.
docx_create="$(json office.docx.create/1 create docx "$work/docx-blank.docx" --json)"
jq -e '.success == true and .data.transaction.committed == true' >/dev/null <<<"$docx_create" || fail "docx create"

# The exact malformed-script contract is exercised through this same command
# path in both source-tree and installed native/Wasm acceptance modes.
printf '%s\n' \
  '{"schema":"docx.batch/2","ops":[{"op":"f1b_invalid_operation","params":{}}]}' \
  >"$work/docx-refusal.json"
expect_failure "$work/docx-refusal-result.json" batch --format docx \
  "$work/docx-refusal-output.docx" "$work/docx-refusal.json" --json
jq -e '.error.code == "office.docx.batch_parse"' \
  "$work/docx-refusal-result.json" >/dev/null || fail "docx refusal code"
[ ! -e "$work/docx-refusal-output.docx" ] || fail "docx refusal wrote output"
[ -z "$(find "$work" -maxdepth 1 \( -name '.office-tmp-*' -o -name '.office-output-tmp-*' \) -print -quit)" ] ||
  fail "docx refusal left a staging artifact"

docx_batch="$(json office.docx.batch/1 batch --format docx "$work/docx-template.docx" "$work/docx.batch.json" --json)"
jq -e '.success == true and .data.ops == 3 and .data.transaction.committed == true' >/dev/null <<<"$docx_batch" || fail "docx batch"
[ "$(json office.identify/1 identify "$work/docx-template.docx" --json | jq -r '.data.format')" = "docx" ] || fail "docx identify"
jq -e '.data.counts.paragraphs >= 8 and .data.counts.hyperlinks == 1 and .data.counts.tables == 1' >/dev/null <<<"$(json office.docx.outline/1 outline "$work/docx-template.docx" --json)" || fail "docx outline"
jq -e '.data.text == "Quarterly report for {{customer}}"' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-template.docx" '/docx/body/p[1]' --json)" || fail "docx get"
jq -e '.data.matched_total >= 8' >/dev/null <<<"$(json office.docx.text/1 text "$work/docx-template.docx" --json)" || fail "docx text"
jq -e '.data.matched_total == 1 and .data.matches[0].kind == "hyperlink"' >/dev/null <<<"$(json office.docx.query/1 query "$work/docx-template.docx" --kind link --json)" || fail "docx query"

# Header/footer authoring (#95): every variant becomes its own part, the
# section references them, the reader surfaces each at its own story path, and
# the footer's page number is a LIVE field rather than static text a reader
# would have to correct by hand.
cp "$here/docx.stories.json" "$work/docx.stories.json"
docx_stories="$(json office.docx.batch/1 batch --format docx "$work/docx-stories.docx" "$work/docx.stories.json" --json)"
jq -e '.success == true and .data.headers == 2 and .data.footers == 1 and .data.transaction.committed == true' >/dev/null <<<"$docx_stories" || fail "docx header/footer batch"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json office.validate/1 validate "$work/docx-stories.docx" --json)" || fail "docx header/footer validate"
jq -e '
  .data.counts.headers == 2 and
  .data.counts.footers == 1 and
  ([.data.stories[].path] | index("/docx/header[1]")) != null and
  ([.data.stories[].path] | index("/docx/footer[1]")) != null and
  (.data.sections[0].headers == [{"variant":"default","part":1},{"variant":"first","part":2}]) and
  (.data.sections[0].footers == [{"variant":"default","part":1}])
' >/dev/null <<<"$(json office.docx.outline/1 outline "$work/docx-stories.docx" --json)" || fail "docx header/footer outline"
jq -e '.data.text == "ACME quarterly"' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-stories.docx" '/docx/header[1]/p[1]' --json)" || fail "docx header get"
jq -e '.data.text == "Cover page"' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-stories.docx" '/docx/header[2]/p[1]' --json)" || fail "docx first-page header get"
jq -e '
  ([.data.entries[].path] | index("/docx/header[1]/p[1]")) != null and
  ([.data.entries[].path] | index("/docx/footer[1]/p[1]")) != null
' >/dev/null <<<"$(json office.docx.text/1 text "$work/docx-stories.docx" --json)" || fail "docx header/footer text"
office raw read "$work/docx-stories.docx" /word/footer1.xml >"$work/docx-footer1.xml" 2>"$work/stderr.log" ||
  { cat "$work/stderr.log" >&2; fail "docx footer raw read"; }
grep -q 'w:fldChar w:fldCharType="begin"' "$work/docx-footer1.xml" || fail "docx footer page number is not a live field"
grep -q '<w:instrText xml:space="preserve"> PAGE </w:instrText>' "$work/docx-footer1.xml" || fail "docx footer PAGE instruction"
office raw read "$work/docx-stories.docx" /word/document.xml >"$work/docx-stories-document.xml" 2>"$work/stderr.log" ||
  { cat "$work/stderr.log" >&2; fail "docx stories document raw read"; }
grep -q '<w:titlePg/>' "$work/docx-stories-document.xml" || fail "docx first-page header without titlePg"

docx_template="$(json office.template/1 template "$work/docx-template.docx" "$work/template-data.json" --out "$work/docx-filled.docx" --json)"
jq -e '.success == true and .data.replaced == 2 and .data.transaction.preservation.changed == ["word/document.xml"]' >/dev/null <<<"$docx_template" || fail "docx template"
jq -e '.data.text == "Quarterly report for Ada Lovelace"' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-filled.docx" '/docx/body/p[1]' --json)" || fail "docx template readback"

# Literal find & replace on an existing document: preservation-safe byte-span
# run rewrites, a typed refusal when a needle is absent, and a typed refusal
# when a match would have to cross a hyperlink boundary.
docx_edit="$(json office.docx.edit/1 edit "$work/docx-filled.docx" "$work/edit.json" --out "$work/docx-edited.docx" --json)"
jq -e '.success == true and .data.replacements == 2 and .data.transaction.preservation.changed == ["word/document.xml"]' >/dev/null <<<"$docx_edit" || fail "docx edit"
jq -e '.data.text == "Annual report for Ada Lovelace"' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-edited.docx" '/docx/body/p[1]' --json)" || fail "docx edit readback"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json office.validate/1 validate "$work/docx-edited.docx" --json)" || fail "docx edit validate"

printf '%s\n' \
  '{"schema":"docx.edit/1","ops":[{"op":"replace_text","params":{"find":"nowhere at all","replace":"x"}}]}' \
  >"$work/docx-edit-miss.json"
expect_failure "$work/docx-edit-miss-result.json" edit "$work/docx-filled.docx" \
  "$work/docx-edit-miss.json" --out "$work/docx-edit-never.docx" --json
jq -e '.error.code == "office.edit.unmatched_find"' "$work/docx-edit-miss-result.json" >/dev/null || fail "docx edit unmatched code"
[ ! -e "$work/docx-edit-never.docx" ] || fail "docx edit refusal wrote output"

printf '%s\n' \
  '{"schema":"docx.edit/1","ops":[{"op":"replace_text","params":{"find":"the published","replace":"the archived"}}]}' \
  >"$work/docx-edit-link.json"
expect_failure "$work/docx-edit-link-result.json" edit "$work/docx-filled.docx" \
  "$work/docx-edit-link.json" --out "$work/docx-edit-link.docx" --json
jq -e '.error.code == "office.edit.unsupported_context" and (.error.details.unsupported[0].detail | test("hyperlink"))' "$work/docx-edit-link-result.json" >/dev/null || fail "docx edit hyperlink refusal"
[ ! -e "$work/docx-edit-link.docx" ] || fail "docx edit hyperlink refusal wrote output"

# Addressed whole-run replacement (docx.edit/2): the canonical query path
# normalizes, the /2 result shape carries at/expect/text on every entry, a
# stale expectation refuses without publishing, and a self-replacement
# publishes the exact source bytes.
json office.raw.result/1 raw edit "$work/docx-filled.docx" /document \
  --path '/w:document/w:body/w:p[1]' --action replace \
  --xml '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:r><w:t>alpha</w:t></w:r><w:r><w:t>beta</w:t></w:r></w:p>' \
  --out "$work/docx-setrun-base.docx" --json >/dev/null
printf '%s\n' \
  '{"schema":"docx.edit/2","ops":[{"op":"set_run_text","params":{"at":"/docx/body/p[1]/r[2]","expect":"beta","text":"BETA"}}]}' \
  >"$work/docx-setrun.json"
docx_setrun="$(json office.docx.edit/2 edit "$work/docx-setrun-base.docx" "$work/docx-setrun.json" --out "$work/docx-setrun-out.docx" --json)"
jq -e '.success == true and .data.replacements == 1 and (.data.results[0] | .op == "set_run_text" and .at == "p[1]/r[2]" and .expect == "beta" and .text == "BETA" and .find == null and .selector == null) and .data.transaction.preservation.changed == ["word/document.xml"]' >/dev/null <<<"$docx_setrun" || fail "docx set_run_text"
jq -e '.data.text == "alphaBETA"' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-setrun-out.docx" '/docx/body/p[1]' --json)" || fail "docx set_run_text readback"

printf '%s\n' \
  '{"schema":"docx.edit/2","ops":[{"op":"replace_text","params":{"find":"BETA","replace":"beta"}}]}' \
  >"$work/docx-setrun-mixed.json"
docx_v2_replace="$(json office.docx.edit/2 edit "$work/docx-setrun-out.docx" "$work/docx-setrun-mixed.json" --out "$work/docx-setrun-back.docx" --json)"
jq -e '.data.results[0] | .op == "replace_text" and .at == null and .expect == null and .text == null and .find == "BETA"' >/dev/null <<<"$docx_v2_replace" || fail "docx /2 replace entry shape"

printf '%s\n' \
  '{"schema":"docx.edit/2","ops":[{"op":"set_run_text","params":{"at":"p[1]/r[2]","expect":"stale","text":"X"}}]}' \
  >"$work/docx-setrun-stale.json"
expect_failure "$work/docx-setrun-stale-result.json" edit "$work/docx-setrun-base.docx" \
  "$work/docx-setrun-stale.json" --out "$work/docx-setrun-never.docx" --json
jq -e '.error.code == "office.docx.invalid_plan"' "$work/docx-setrun-stale-result.json" >/dev/null || fail "docx set_run_text stale code"
[ ! -e "$work/docx-setrun-never.docx" ] || fail "docx set_run_text stale wrote output"

printf '%s\n' \
  '{"schema":"docx.edit/2","ops":[{"op":"set_run_text","params":{"at":"p[1]/r[2]","expect":"beta","text":"beta"}}]}' \
  >"$work/docx-setrun-noop.json"
json office.docx.edit/2 edit "$work/docx-setrun-base.docx" "$work/docx-setrun-noop.json" --out "$work/docx-setrun-noop.docx" --json >/dev/null
cmp -s "$work/docx-setrun-base.docx" "$work/docx-setrun-noop.docx" || fail "docx set_run_text no-op bytes"

# Tracked-change resolution on the same command: accepting everything keeps the
# insertion and drops the deletion, rejecting everything does the reverse (which
# means restoring w:delText as w:t), and outline reports nothing pending after
# either. A selection reaching an out-of-scope construct refuses.
json office.raw.result/1 raw edit "$work/docx-filled.docx" /document \
  --path '/w:document/w:body/w:p[1]' --action replace \
  --xml '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:r><w:t xml:space="preserve">The revenue was </w:t></w:r><w:del w:id="1" w:author="Reviewer" w:date="2026-01-01T00:00:00Z"><w:r><w:delText xml:space="preserve">flat</w:delText></w:r></w:del><w:ins w:id="2" w:author="Reviewer" w:date="2026-01-01T00:00:00Z"><w:r><w:t xml:space="preserve">up 18%</w:t></w:r></w:ins><w:r><w:t xml:space="preserve"> this quarter.</w:t></w:r></w:p>' \
  --out "$work/docx-tracked.docx" --json >/dev/null
jq -e '.data.counts.insertions == 1 and .data.counts.deletions == 1 and ([.data.revisions[].id] == ["1","2"])' >/dev/null <<<"$(json office.docx.outline/1 outline "$work/docx-tracked.docx" --json)" || fail "docx tracked outline"

printf '%s\n' '{"schema":"docx.edit/1","ops":[{"op":"accept_revision","params":{"all":true}}]}' >"$work/docx-accept.json"
docx_accept="$(json office.docx.edit/1 edit "$work/docx-tracked.docx" "$work/docx-accept.json" --out "$work/docx-accepted.docx" --json)"
jq -e '.success == true and .data.revisions_resolved == 2 and .data.transaction.preservation.changed == ["word/document.xml"]' >/dev/null <<<"$docx_accept" || fail "docx accept_revision"
jq -e '.data.text == "The revenue was up 18% this quarter."' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-accepted.docx" '/docx/body/p[1]' --json)" || fail "docx accept readback"
jq -e '.data.counts.insertions == 0 and .data.counts.deletions == 0 and (.data.revisions | length) == 0' >/dev/null <<<"$(json office.docx.outline/1 outline "$work/docx-accepted.docx" --json)" || fail "docx accept outline"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json office.validate/1 validate "$work/docx-accepted.docx" --json)" || fail "docx accept validate"

printf '%s\n' '{"schema":"docx.edit/1","ops":[{"op":"reject_revision","params":{"author":"Reviewer"}}]}' >"$work/docx-reject.json"
docx_reject="$(json office.docx.edit/1 edit "$work/docx-tracked.docx" "$work/docx-reject.json" --out "$work/docx-rejected.docx" --json)"
jq -e '.success == true and .data.revisions_resolved == 2' >/dev/null <<<"$docx_reject" || fail "docx reject_revision"
jq -e '.data.text == "The revenue was flat this quarter."' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-rejected.docx" '/docx/body/p[1]' --json)" || fail "docx reject readback"
jq -e '.data.counts.insertions == 0 and .data.counts.deletions == 0' >/dev/null <<<"$(json office.docx.outline/1 outline "$work/docx-rejected.docx" --json)" || fail "docx reject outline"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json office.validate/1 validate "$work/docx-rejected.docx" --json)" || fail "docx reject validate"

printf '%s\n' '{"schema":"docx.edit/1","ops":[{"op":"accept_revision","params":{"id":"404"}}]}' >"$work/docx-revision-miss.json"
expect_failure "$work/docx-revision-miss-result.json" edit "$work/docx-tracked.docx" \
  "$work/docx-revision-miss.json" --out "$work/docx-revision-never.docx" --json
jq -e '.error.code == "office.edit.unmatched_revision"' "$work/docx-revision-miss-result.json" >/dev/null || fail "docx revision unmatched code"
[ ! -e "$work/docx-revision-never.docx" ] || fail "docx revision refusal wrote output"

json office.raw.result/1 raw edit "$work/docx-filled.docx" /document \
  --path '/w:document/w:body/w:p[1]' --action replace \
  --xml '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:rPr><w:ins w:id="4" w:author="Reviewer"/></w:rPr></w:pPr><w:r><w:t>body</w:t></w:r></w:p>' \
  --out "$work/docx-paramark.docx" --json >/dev/null
expect_failure "$work/docx-paramark-result.json" edit "$work/docx-paramark.docx" \
  "$work/docx-accept.json" --out "$work/docx-paramark-out.docx" --json
jq -e '.error.code == "office.edit.unsupported_revision" and (.error.details.unsupported[0].detail | test("property"))' "$work/docx-paramark-result.json" >/dev/null || fail "docx property revision refusal"
[ ! -e "$work/docx-paramark-out.docx" ] || fail "docx property revision refusal wrote output"

docx_annotate="$(json office.docx.annotation-batch/1 annotate "$work/docx-filled.docx" "$work/annotation.json" --out "$work/docx-reviewed.docx" --json)"
jq -e '.success == true and .data.ops_applied == 3 and (.data.labels | length) == 2 and (.data.changed_parts | index("word/document.xml")) != null' >/dev/null <<<"$docx_annotate" || fail "docx annotate"
jq -e '.data.metadata.done == true and .data.metadata.author == "Reviewer"' >/dev/null <<<"$(json office.docx.element/1 get "$work/docx-reviewed.docx" '/docx/comments/comment[id="0"]' --json)" || fail "docx annotation readback"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json office.validate/1 validate "$work/docx-reviewed.docx" --json)" || fail "docx validate"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json office.issues/1 issues "$work/docx-reviewed.docx" --json)" || fail "docx issues"
jq -e '.data.format == "docx" and .data.images_embedded == 0' >/dev/null <<<"$(json office.preview/1 preview "$work/docx-reviewed.docx" --output "$work/docx.html" --json)" || fail "docx preview"
jq -e '.data.format == "docx" and .data.images_embedded == 0' >/dev/null <<<"$(json office.preview/1 preview "$work/docx-reviewed.docx" --output "$work/docx-2.html" --json)" || fail "docx second preview"
grep -q 'Ada Lovelace' "$work/docx.html" || fail "docx preview content"
cmp -s "$work/docx.html" "$work/docx-2.html" || fail "docx preview is not deterministic"

# render: the paginated artifacts, which preview deliberately cannot produce.
# The SVG assertion is the interesting one -- it is uncompressed, so it is the
# backend whose bytes are identical on every runtime, and a real glyph
# coordinate is visible in it.
jq -e '.data.backend == "pdf" and .data.pages_rendered >= 1 and .data.byte_determinism == "per-runtime"' >/dev/null <<<"$(json office.render/1 render "$work/docx-reviewed.docx" --output "$work/docx.pdf" --json)" || fail "docx render pdf"
head -c 8 "$work/docx.pdf" | grep -q '^%PDF-1' || fail "docx render pdf header"
json office.render/1 render "$work/docx-reviewed.docx" --output "$work/docx-2.pdf" --json >/dev/null
cmp -s "$work/docx.pdf" "$work/docx-2.pdf" || fail "docx render is not deterministic"
jq -e '.data.backend == "svg" and .data.byte_determinism == "cross-runtime"' >/dev/null <<<"$(json office.render/1 render "$work/docx-reviewed.docx" --output "$work/docx.svg" --json)" || fail "docx render svg"
grep -q '<svg' "$work/docx.svg" || fail "docx render svg content"
# a destination that names no backend is refused before any work happens
office render "$work/docx-reviewed.docx" --output "$work/docx.txt" --json >/dev/null 2>&1 &&
  fail "docx render accepted an unknown output extension"

json office.dump/1 dump "$work/docx-reviewed.docx" --json >"$work/docx.dump.json"
jq -e '.schema == "office.dump/1" and .format == "docx" and (.ops | length) > 0' "$work/docx.dump.json" >/dev/null || fail "docx dump"
jq -e '.success == true and .data.format == "docx"' >/dev/null <<<"$(json office.replay/1 replay "$work/docx.dump.json" --output "$work/docx-replayed.docx" --json)" || fail "docx replay"
json office.dump/1 dump "$work/docx-replayed.docx" --json >"$work/docx.replayed.dump.json"
# As above, compare the whole post-projection envelope rather than merely ops.
jq -e '.success == true and .data.format == "docx"' >/dev/null <<<"$(json office.replay/1 replay "$work/docx.replayed.dump.json" --output "$work/docx-replayed-2.docx" --json)" || fail "docx second replay"
json office.dump/1 dump "$work/docx-replayed-2.docx" --json >"$work/docx.replayed-2.dump.json"
jq -S 'del(.source)' "$work/docx.replayed.dump.json" >"$work/docx.fixpoint-1.json"
jq -S 'del(.source)' "$work/docx.replayed-2.dump.json" >"$work/docx.fixpoint-2.json"
cmp -s "$work/docx.fixpoint-1.json" "$work/docx.fixpoint-2.json" || fail "docx complete dump/replay fixpoint"
jq -e '.data.format == "docx" and (.data.content | contains("Quarterly report"))' >/dev/null <<<"$(json office.raw.part/1 raw read "$work/docx-reviewed.docx" /document --json)" || fail "docx raw read"

echo "OFFICE ACCEPTANCE PASS [$target]: unified XLSX and DOCX workflows"

#!/usr/bin/env bash
set -euo pipefail

target="${1:-wasm}"
case "$target" in
  native|wasm) ;;
  *)
    echo "usage: $0 [native|wasm]" >&2
    exit 2
    ;;
esac

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/office-acceptance-${target}.XXXXXX")"
trap 'rm -rf "$work"' EXIT

fail() {
  echo "OFFICE ACCEPTANCE FAIL [$target]: $*" >&2
  exit 1
}

if ! moon build --target "$target" office/cmd/office >"$work/build.log" 2>&1; then
  cat "$work/build.log" >&2
  fail "office build"
fi

office() {
  moon run --target "$target" office/cmd/office -- "$@"
}

json() {
  local output
  local expected_schema="office.output/1"
  if [ "${1:-}" = "dump" ]; then
    expected_schema="office.dump/1"
  fi
  if ! output="$(office "$@" 2>"$work/stderr.log")"; then
    cat "$work/stderr.log" >&2
    fail "command failed: office $* -> $output"
  fi
  if ! jq -s -e --arg schema "$expected_schema" '
    length == 1 and
    .[0].schema == $schema
  ' >/dev/null 2>&1 <<<"$output"; then
    cat "$work/stderr.log" >&2
    fail "command did not emit exactly one $expected_schema document: office $* -> $output"
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

# Discovery is schema-driven and advertises the complete supported command set.
capabilities="$(json help all --json)"
jq -e '
  .success == true and
  .data.schema == "office.capabilities/2" and
  (.data.fingerprint | test("^crc32:[0-9a-f]{8}$")) and
  ([.data.records[].name] == [
    "docx", "xlsx", "help", "identify", "outline", "get", "text",
    "query", "validate", "dump", "replay", "issues", "preview",
    "create", "template", "annotate", "batch", "raw"
  ])
' >/dev/null <<<"$capabilities" || fail "capability registry"

# XLSX: create, author/mutate, inspect, template, validate, preview, dump/replay.
xlsx_create="$(json create xlsx "$work/xlsx-blank.xlsx" --sheet Data --json)"
jq -e '.success == true and .data.transaction.committed == true' >/dev/null <<<"$xlsx_create" || fail "xlsx create"

xlsx_batch="$(json batch "$work/xlsx-blank.xlsx" "$work/xlsx.batch.json" --out "$work/xlsx-template.xlsx" --json)"
jq -e '.success == true and .data.stats.operation_count == 9 and .data.transaction.committed == true' >/dev/null <<<"$xlsx_batch" || fail "xlsx batch"

[ "$(json identify "$work/xlsx-template.xlsx" --json | jq -r '.data.format')" = "xlsx" ] || fail "xlsx identify"
jq -e '.data.sheets[0].name == "Data" and .data.sheets[0].counts.charts == 1' >/dev/null <<<"$(json outline "$work/xlsx-template.xlsx" --json)" || fail "xlsx outline"
jq -e '.data.cells[0].raw.value == "Customer: {{customer}}"' >/dev/null <<<"$(json get "$work/xlsx-template.xlsx" '/xlsx/sheet[name="Data"]/range[A1:C3]' --json)" || fail "xlsx get"
jq -e '.data.matched_total >= 6' >/dev/null <<<"$(json text "$work/xlsx-template.xlsx" --under '/xlsx/sheet[name="Data"]' --json)" || fail "xlsx text"
jq -e '.data.matched_total == 1 and .data.matches[0].reference == "C2"' >/dev/null <<<"$(json query "$work/xlsx-template.xlsx" 'cell[type=formula]' --json)" || fail "xlsx query"

xlsx_template="$(json template "$work/xlsx-template.xlsx" "$work/template-data.json" --out "$work/xlsx-filled.xlsx" --json)"
jq -e '.success == true and .data.replaced == 2 and (.data.missing | length) == 0' >/dev/null <<<"$xlsx_template" || fail "xlsx template"
jq -e '.data.cells[0].raw.value == "Customer: Ada Lovelace" and .data.cells[1].raw.value == 100' >/dev/null <<<"$(json get "$work/xlsx-filled.xlsx" '/xlsx/sheet[name="Data"]/range[A1:B1]' --json)" || fail "xlsx template readback"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json validate "$work/xlsx-filled.xlsx" --json)" || fail "xlsx validate"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json issues "$work/xlsx-filled.xlsx" --json)" || fail "xlsx issues"
jq -e '.data.format == "xlsx" and .data.charts_rendered == 1' >/dev/null <<<"$(json preview "$work/xlsx-filled.xlsx" --output "$work/xlsx.html" --json)" || fail "xlsx preview"
jq -e '.data.format == "xlsx" and .data.charts_rendered == 1' >/dev/null <<<"$(json preview "$work/xlsx-filled.xlsx" --output "$work/xlsx-2.html" --json)" || fail "xlsx second preview"
grep -q '<figure class="chart"' "$work/xlsx.html" || fail "xlsx preview chart"
cmp -s "$work/xlsx.html" "$work/xlsx-2.html" || fail "xlsx preview is not deterministic"

json dump "$work/xlsx-filled.xlsx" --json >"$work/xlsx.dump.json"
jq -e '.schema == "office.dump/1" and .format == "xlsx" and (.ops | length) > 0' "$work/xlsx.dump.json" >/dev/null || fail "xlsx dump"
jq -e '.success == true and .data.format == "xlsx"' >/dev/null <<<"$(json replay "$work/xlsx.dump.json" --output "$work/xlsx-replayed.xlsx" --json)" || fail "xlsx replay"
json dump "$work/xlsx-replayed.xlsx" --json >"$work/xlsx.replayed.dump.json"
# The first projection may intentionally drop features disclosed by residuals
# (the chart in this fixture). Prove that the complete projected envelope then
# reaches a fixpoint; only source-path/byte provenance is contractually ignored.
jq -e '.success == true and .data.format == "xlsx"' >/dev/null <<<"$(json replay "$work/xlsx.replayed.dump.json" --output "$work/xlsx-replayed-2.xlsx" --json)" || fail "xlsx second replay"
json dump "$work/xlsx-replayed-2.xlsx" --json >"$work/xlsx.replayed-2.dump.json"
jq -S 'del(.source)' "$work/xlsx.replayed.dump.json" >"$work/xlsx.fixpoint-1.json"
jq -S 'del(.source)' "$work/xlsx.replayed-2.dump.json" >"$work/xlsx.fixpoint-2.json"
cmp -s "$work/xlsx.fixpoint-1.json" "$work/xlsx.fixpoint-2.json" || fail "xlsx complete dump/replay fixpoint"
jq -e '.data.format == "xlsx" and (.data.parts | length) > 0' >/dev/null <<<"$(json raw list "$work/xlsx-filled.xlsx" --json)" || fail "xlsx raw list"

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
[ -z "$(find "$work" -maxdepth 1 -name 'never.xlsx.tmp-*' -print -quit)" ] || fail "invalid replay left a staging artifact"

# DOCX: blank create, fresh authoring, inspect, template, annotate, and replay.
docx_create="$(json create docx "$work/docx-blank.docx" --json)"
jq -e '.success == true and .data.transaction.committed == true' >/dev/null <<<"$docx_create" || fail "docx create"

docx_batch="$(json batch --format docx "$work/docx-template.docx" "$work/docx.batch.json" --json)"
jq -e '.success == true and .data.ops == 3 and .data.transaction.committed == true' >/dev/null <<<"$docx_batch" || fail "docx batch"
[ "$(json identify "$work/docx-template.docx" --json | jq -r '.data.format')" = "docx" ] || fail "docx identify"
jq -e '.data.counts.paragraphs >= 8 and .data.counts.hyperlinks == 1 and .data.counts.tables == 1' >/dev/null <<<"$(json outline "$work/docx-template.docx" --json)" || fail "docx outline"
jq -e '.data.text == "Quarterly report for {{customer}}"' >/dev/null <<<"$(json get "$work/docx-template.docx" '/docx/body/p[1]' --json)" || fail "docx get"
jq -e '.data.matched_total >= 8' >/dev/null <<<"$(json text "$work/docx-template.docx" --json)" || fail "docx text"
jq -e '.data.matched_total == 1 and .data.matches[0].kind == "hyperlink"' >/dev/null <<<"$(json query "$work/docx-template.docx" --kind link --json)" || fail "docx query"

docx_template="$(json template "$work/docx-template.docx" "$work/template-data.json" --out "$work/docx-filled.docx" --json)"
jq -e '.success == true and .data.replaced == 2 and .data.transaction.preservation.changed == ["word/document.xml"]' >/dev/null <<<"$docx_template" || fail "docx template"
jq -e '.data.text == "Quarterly report for Ada Lovelace"' >/dev/null <<<"$(json get "$work/docx-filled.docx" '/docx/body/p[1]' --json)" || fail "docx template readback"

docx_annotate="$(json annotate "$work/docx-filled.docx" "$work/annotation.json" --out "$work/docx-reviewed.docx" --json)"
jq -e '.success == true and .data.ops_applied == 3 and (.data.labels | length) == 2 and (.data.changed_parts | index("word/document.xml")) != null' >/dev/null <<<"$docx_annotate" || fail "docx annotate"
jq -e '.data.metadata.done == true and .data.metadata.author == "Reviewer"' >/dev/null <<<"$(json get "$work/docx-reviewed.docx" '/docx/comments/comment[id="0"]' --json)" || fail "docx annotation readback"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json validate "$work/docx-reviewed.docx" --json)" || fail "docx validate"
jq -e '.data.valid == true and .data.error_count == 0' >/dev/null <<<"$(json issues "$work/docx-reviewed.docx" --json)" || fail "docx issues"
jq -e '.data.format == "docx" and .data.images_embedded == 0' >/dev/null <<<"$(json preview "$work/docx-reviewed.docx" --output "$work/docx.html" --json)" || fail "docx preview"
jq -e '.data.format == "docx" and .data.images_embedded == 0' >/dev/null <<<"$(json preview "$work/docx-reviewed.docx" --output "$work/docx-2.html" --json)" || fail "docx second preview"
grep -q 'Ada Lovelace' "$work/docx.html" || fail "docx preview content"
cmp -s "$work/docx.html" "$work/docx-2.html" || fail "docx preview is not deterministic"

json dump "$work/docx-reviewed.docx" --json >"$work/docx.dump.json"
jq -e '.schema == "office.dump/1" and .format == "docx" and (.ops | length) > 0' "$work/docx.dump.json" >/dev/null || fail "docx dump"
jq -e '.success == true and .data.format == "docx"' >/dev/null <<<"$(json replay "$work/docx.dump.json" --output "$work/docx-replayed.docx" --json)" || fail "docx replay"
json dump "$work/docx-replayed.docx" --json >"$work/docx.replayed.dump.json"
# As above, compare the whole post-projection envelope rather than merely ops.
jq -e '.success == true and .data.format == "docx"' >/dev/null <<<"$(json replay "$work/docx.replayed.dump.json" --output "$work/docx-replayed-2.docx" --json)" || fail "docx second replay"
json dump "$work/docx-replayed-2.docx" --json >"$work/docx.replayed-2.dump.json"
jq -S 'del(.source)' "$work/docx.replayed.dump.json" >"$work/docx.fixpoint-1.json"
jq -S 'del(.source)' "$work/docx.replayed-2.dump.json" >"$work/docx.fixpoint-2.json"
cmp -s "$work/docx.fixpoint-1.json" "$work/docx.fixpoint-2.json" || fail "docx complete dump/replay fixpoint"
jq -e '.data.format == "docx" and (.data.content | contains("Quarterly report"))' >/dev/null <<<"$(json raw read "$work/docx-reviewed.docx" /document --json)" || fail "docx raw read"

echo "OFFICE ACCEPTANCE PASS [$target]: unified XLSX and DOCX workflows"

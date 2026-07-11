#!/usr/bin/env bash
# Mechanical harness for the docx authoring acceptance scenario (see
# README.md). Runs the checked-in probe script through the real CLI and
# asserts every structural claim of the scenario. Run from the repo root:
#
#   bash docx2html/tests/acceptance/run.sh
#
# Exits non-zero on the first divergence, printing the diverging output.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
docx() { moon run --target wasm docx2html/cmd/docx -- "$@"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/docx-acceptance.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cp "$here/minutes.json" "$work/minutes.json"

fail() { echo "ACCEPTANCE FAIL: $*" >&2; exit 1; }

# Capture a command's stdout; on failure, surface the diagnostic (wasm has
# no stderr — failures land on stdout) instead of letting set -e eat it.
must() {
  local __out
  if ! __out="$("$@" 2>&1)"; then
    fail "command failed: $* -> $__out"
  fi
  printf '%s' "$__out"
}

# 1. Author the document from the probe's script.
out="$(must docx batch "$work/minutes.docx" "$work/minutes.json")"
[ "$out" = "created $work/minutes.docx (8 op(s))" ] || fail "batch output: $out"

# 2. Structural validity.
[ "$(must docx validate "$work/minutes.docx")" = "valid" ] || fail "validate"

# 3. Content round-trips with the paths the scenario requires. 15 lines: the
# 7 body paragraphs plus one per table-cell paragraph (3 + 2 + 3 cells).
text="$(must docx text "$work/minutes.docx")"
echo "$text" | grep -qx '\[/body/p\[1\]\] Meeting Minutes' || fail "title text"
echo "$text" | grep -q '\[/body/tbl\[1\]/tr\[1\]/tc\[3\]/p\[1\]\] Status' || fail "table header cell"
[ "$(echo "$text" | wc -l)" -eq 15 ] || fail "paragraph count: $(echo "$text" | wc -l)"

# Heading1 title, with the reader's enriched style name.
p1="$(must docx get "$work/minutes.docx" '/body/p[1]' --json)"
echo "$p1" | grep -q '"style_id": "Heading1"' || fail "p1 style_id"
echo "$p1" | grep -q '"style_name": "heading 1"' || fail "p1 enriched style_name"

# The bold run inside the narrative paragraph (run 2 of p[2]).
bold_run="$(must docx get "$work/minutes.docx" '/body/p[2]/r[2]' --json)"
echo "$bold_run" | grep -q '"bold": true' || fail "bold run"
echo "$bold_run" | grep -q '"quarterly budget"' || fail "bold run text"

# The hyperlink and its target.
link="$(must docx get "$work/minutes.docx" '/body/p[2]/hyperlink[1]' --json)"
echo "$link" | grep -q '"href": "https://example.org/agenda"' || fail "hyperlink href"

# All three bulleted items and both ordered items.
for i in 3 4 5; do
  bullet="$(must docx get "$work/minutes.docx" "/body/p[$i]" --json)"
  echo "$bullet" | grep -q '"ordered": false' || fail "p[$i] bullet numbering"
done
for i in 6 7; do
  ordered="$(must docx get "$work/minutes.docx" "/body/p[$i]" --json)"
  echo "$ordered" | grep -q '"ordered": true' || fail "p[$i] ordered numbering"
done

# Header row is marked, and the spanning cell reads back col_span 2.
row1="$(must docx get "$work/minutes.docx" '/body/tbl[1]/tr[1]' --json)"
echo "$row1" | grep -q '"header": true' || fail "header row flag"
cell="$(must docx get "$work/minutes.docx" '/body/tbl[1]/tr[2]/tc[1]' --json)"
echo "$cell" | grep -q '"col_span": 2' || fail "col_span read-back"

# 4. Error probe: unknown op names its index and the known ops, exactly.
printf '{"schema": "docx.batch/1", "ops": [{"op": "pagebreak", "params": {}}]}' > "$work/bad.json"
if err="$(docx batch "$work/never.docx" "$work/bad.json" 2>&1)"; then
  fail "unknown op accepted"
fi
echo "$err" | grep -qx "error: ops\[0\].op 'pagebreak' is unknown (known ops: paragraph, table, comment)" || fail "unknown-op message: $err"
[ ! -e "$work/never.docx" ] || fail "unknown op wrote a file"

# 5. Error probe: fresh-document-only refusal, exact message, and no
# filesystem side effects (file untouched, no temp droppings).
cp "$work/minutes.docx" "$work/minutes.before"
if err="$(docx batch "$work/minutes.docx" "$work/minutes.json" 2>&1)"; then
  fail "existing output overwritten"
fi
echo "$err" | grep -qx "docx: refusing to write '$work/minutes.docx': it already exists (batch creates NEW documents only; it cannot preserve parts of an existing file)" || fail "refusal message: $err"
cmp -s "$work/minutes.docx" "$work/minutes.before" || fail "existing file mutated"
leftovers="$(find "$work" -name '*.tmp-*' | wc -l)"
[ "$leftovers" -eq 0 ] || fail "temp droppings left behind"

# 6. Phase 2 — the review workflow on the authored document: comment,
# reply, resolve, each byte-preserving, each read back structurally.
out="$(must docx annotate add "$work/minutes.docx" "$work/reviewed.docx" --at /body/p[2] --text 'Cite the decision owner.' --author 'Reviewer' --initials RV)"
[ "$out" = "annotated $work/reviewed.docx (comment 0 on /body/p[2])" ] || fail "annotate add output: $out"
[ "$(must docx validate "$work/reviewed.docx")" = "valid" ] || fail "reviewed validate"
inventory="$(must docx outline "$work/reviewed.docx")"
echo "$inventory" | grep -q '"author": "Reviewer"' || fail "comment author in outline"
echo "$inventory" | grep -q '"anchored_to": "/body/p\[2\]"' || fail "comment anchor in outline"

out="$(must docx annotate reply "$work/reviewed.docx" "$work/replied.docx" --comment 0 --text 'Owner named in section 2.' --author 'Author')"
[ "$out" = "annotated $work/replied.docx (comment 1 replying to 0)" ] || fail "reply output: $out"
threaded="$(must docx get "$work/replied.docx" '/comments/comment[@id=1]' --json)"
echo "$threaded" | grep -q '"parent_id": "0"' || fail "reply threading"
echo "$threaded" | grep -q '"anchors": \[\]' || fail "reply anchorlessness"

out="$(must docx annotate resolve "$work/replied.docx" "$work/resolved.docx" --comment 0)"
[ "$out" = "annotated $work/resolved.docx (comment 0 done=true)" ] || fail "resolve output: $out"
resolved="$(must docx get "$work/resolved.docx" '/comments/comment[@id=0]' --json)"
echo "$resolved" | grep -q '"done": true' || fail "resolved done flag"

# Byte preservation, PROVEN per generation over EVERY zip entry:
# assert_preserved demands (a) no entry disappears, (b) every NEW entry
# is on the expected list, (c) every entry NOT on the expected list is
# byte-identical to the previous generation. On top of that, add's
# document.xml (which IS expected to change) must hold each of the
# three marker fragments EXACTLY ONCE (stripping is optional per
# pattern — presence must be proven separately), and minus those
# fragments must equal the original — the change is exactly the
# markers. And mutation never edited any input in place.
cmp -s "$work/minutes.docx" "$work/minutes.before" || fail "original mutated by annotate"
# unzip pattern-matches member names ([Content_Types].xml would be a
# character class) — escape the glob metacharacters to extract literally.
part() { unzip -p "$1" "$(printf '%s' "$2" | sed 's/[][*?]/\\&/g')"; }
expected_change() {
  needle="$1"
  shift
  for e in "$@"; do [ "$e" = "$needle" ] && return 0; done
  return 1
}
assert_preserved() {
  prev="$1"
  next="$2"
  shift 2
  unzip -Z1 "$prev" | LC_ALL=C sort > "$work/prev.entries"
  unzip -Z1 "$next" | LC_ALL=C sort > "$work/next.entries"
  dropped="$(comm -23 "$work/prev.entries" "$work/next.entries")"
  [ -z "$dropped" ] || fail "$(basename "$next") dropped entries: $dropped"
  while IFS= read -r entry; do
    expected_change "$entry" "$@" || fail "$(basename "$next") grew unexpected entry '$entry'"
  done < <(comm -13 "$work/prev.entries" "$work/next.entries")
  while IFS= read -r entry; do
    expected_change "$entry" "$@" && continue
    part "$prev" "$entry" > "$work/prev.part"
    part "$next" "$entry" > "$work/next.part"
    cmp -s "$work/prev.part" "$work/next.part" \
      || fail "$(basename "$next") mutated unrelated entry '$entry'"
  done < <(comm -12 "$work/prev.entries" "$work/next.entries")
}
assert_preserved "$work/minutes.docx" "$work/reviewed.docx" \
  word/document.xml word/comments.xml word/_rels/document.xml.rels '[Content_Types].xml'
assert_preserved "$work/reviewed.docx" "$work/replied.docx" \
  word/comments.xml word/commentsExtended.xml word/_rels/document.xml.rels '[Content_Types].xml'
assert_preserved "$work/replied.docx" "$work/resolved.docx" word/commentsExtended.xml
for marker in '<w:commentRangeStart[^>]*/>' '<w:commentRangeEnd[^>]*/>' '<w:r xmlns:w=[^>]*><w:commentReference[^>]*/></w:r>'; do
  n="$(part "$work/reviewed.docx" word/document.xml | { grep -oE "$marker" || true; } | wc -l | tr -d ' ')"
  [ "$n" -eq 1 ] || fail "add: expected exactly one marker matching \"$marker\" in document.xml, found $n"
done
part "$work/reviewed.docx" word/document.xml \
  | sed -E 's|<w:commentRangeStart[^>]*/>||; s|<w:commentRangeEnd[^>]*/>||; s|<w:r xmlns:w=[^>]*><w:commentReference[^>]*/></w:r>||' \
  > "$work/reviewed.body.stripped"
part "$work/minutes.docx" word/document.xml > "$work/minutes.body"
cmp -s "$work/reviewed.body.stripped" "$work/minutes.body" || fail "add mutated bytes beyond the marker fragments"
[ "$(must docx text "$work/resolved.docx" | grep -c '^\[/body/')" -eq 15 ] || fail "body text count after review loop"

echo "ACCEPTANCE PASS: authored, validated, every structural claim round-tripped, both error probes exact, review loop (comment/reply/resolve) byte-preserving"

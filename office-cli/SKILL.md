---
name: office
description: >-
  Work with non-PowerPoint Office/OOXML documents through the published unified
  office CLI: identify, inspect, query, validate, diagnose, preview, create,
  template, comment, batch-edit, dump/replay, or safely inspect raw parts in
  .docx and .xlsx files, including addressed run-level text edits that refuse
  rather than silently lose content. Use this for Word and Excel tasks instead of
  python-docx, openpyxl, ExcelJS, pandoc, or LibreOffice. Use the legacy
  format-specific CLIs only for the few workflows the umbrella command does not
  provide: direct CSV import/export, formula calculation, fine-grained XLSX
  formula linting and live batch-capability discovery, fine-grained XLSX
  rendering controls, and DOCX Markdown/style-map/image-extraction conversion.
---

# Office documents through one CLI

Use the unified `office` command for every DOCX/XLSX workflow unless the
legacy-only table below names the exact missing capability.

Nothing to install beyond `moonx`. Run from any directory:

```
moonx bobzhang/office help all --json
moonx bobzhang/office <command> <args...>
```

Arguments after `bobzhang/office` are passed directly to the command; do not
insert a `--` separator.

The WebAssembly target is the default and is the right choice for untrusted
documents. It cannot spawn programs or open network connections, and the CLI
also applies bounded package, XML, scan, output, and mutation limits. It can
still read or write the paths supplied to it and consume CPU within those
limits. For trusted files, `moonx --target native bobzhang/office ...` is a
faster drop-in.

Pin a version when reproducibility matters: `moonx bobzhang/office@0.4.0 ...`.
`@latest` refreshes the registry index before resolving.

## The CLI describes itself — prefer that over prose

This file will drift; the binary will not. Three introspection commands are
normative:

```
moonx bobzhang/office help all --json        # every format, command, field, limit
moonx bobzhang/office help schemas --json    # every consumed JSON contract
moonx bobzhang/office help schema ID --json  # one contract, e.g. xlsx.batch/2
```

`help all` carries a `crc32:` fingerprint over the capability registry. When
this document and the fingerprinted registry disagree, the registry wins.

## Default workflow

1. Discover the surface with `help all --json`, and `help schema ID` before
   authoring any JSON input document.
2. Run `identify`, then `outline --json`, before choosing paths or edits.
3. Inspect only what you need with `get`, `text`, or `query`. Reuse the
   canonical paths the CLI returns; do not invent selectors.
4. For mutations, prefer a separate `--out`, run `--dry-run` where supported,
   and read the transaction preservation report.
5. Read the result back, then run `validate` and `issues`. For any XLSX
   containing formulas, also run the legacy `xlsx lint` fallback below and
   require `finding_count == 0`: newly authored formulas have no cached
   result, so `issues` and `preview` cannot evaluate them. Lint evaluates
   formula masters but not shared/array slave formulas — treat those slaves as
   an unresolved residual rather than claiming formula correctness.
6. Run the delivery gate in "Verify before you deliver" below before handing
   anything over. `preview` publishes the HTML, but nothing in this toolchain
   renders it to an image — see the ceiling statement in that section.

Every documented failure exits non-zero, but a successful diagnostic command
can still report warnings or formula findings with exit code zero. Inspect the
structured counts and records, not just the exit code.

Ordinary `--json` commands emit one `office.output/1` success/failure envelope.
`dump --json` is the deliberate exception: it emits the replayable
`office.dump/1` document directly.

## Command map

Replace the `office` token below with the `moonx bobzhang/office` launcher.

| Goal | Command |
| --- | --- |
| Discover formats, commands, fields, limits | `office help [all\|FORMAT\|COMMAND\|FORMAT COMMAND] [--json\|--jsonl]` |
| Discover consumed JSON contracts | `office help schemas [--json\|--jsonl]`; `office help schema ID [--json\|--jsonl]` |
| Verify and identify a package | `office identify FILE [--json]` |
| Map document/workbook structure | `office outline FILE [--max-elements N] [--max-output-chars N] [--json]` |
| Resolve one canonical selector | `office get FILE SELECTOR [limits] [--json]` |
| Extract path-tagged paragraphs/cells | `office text FILE [--under SELECTOR] [--offset N] [--limit N] [limits] [--json]` |
| Search bounded literal predicates | `office query FILE [CELL_SELECTOR] [--under SELECTOR] [DOCX predicates] [pagination/limits] [--json]` |
| Run the exact mutation validation gate | `office validate FILE [--json\|--jsonl]` |
| Report validation plus bounded actionable warnings | `office issues FILE [--json\|--jsonl]` |
| Publish deterministic offline HTML | `office preview FILE --output OUT.html [--overwrite] [--json\|--jsonl]` |
| Create a blank validated file | `office create xlsx OUT.xlsx [--sheet NAME] [--dry-run] [--overwrite] [--json]` or `office create docx OUT.docx [--dry-run] [--overwrite] [--json]` |
| Merge strict placeholders/row regions | `office template FILE DATA.json --out OUT [--dry-run] [--overwrite] [--allow-missing] [--json\|--jsonl]` |
| Replace literal text, set one addressed run's text, or accept/reject tracked changes, in an existing DOCX | `office edit FILE SCRIPT.json --out OUT.docx [--dry-run] [--overwrite] [--allow-unmatched] [--json\|--jsonl]` |
| Add/reply/resolve DOCX comments | `office annotate FILE SCRIPT.json --out OUT.docx [--dry-run] [--overwrite] [--json\|--jsonl]` |
| Mutate an XLSX transactionally | `office batch BOOK.xlsx SCRIPT.json [--out OUT.xlsx] [--dry-run] [--overwrite] [--json]` |
| Author a fresh DOCX from ops | `office batch --format docx OUT.docx SCRIPT.json [--dry-run] [--overwrite] [--json]` |
| Produce a replayable semantic dump | `office dump FILE --json` or streaming `--jsonl` |
| Reconstruct replayable dump content | `office replay DUMP.json --output OUT [--overwrite] [--json\|--jsonl]` |
| Inventory/read OOXML parts | `office raw list FILE [--json]`; `office raw read FILE PART [--json] [--base64\|--output FILE]` |
| Replace one XML part | `office raw replace FILE PART (--xml XML \| --xml-file FILE) [--out FILE] [--dry-run] [--overwrite] [--json]` |
| Edit inside one XML part | `office raw edit FILE PART --path PATH --action ACTION [action arguments] [--namespace PREFIX=URI]... [--all] [--out FILE] [--dry-run] [--overwrite] [--json]` |

`[limits]` abbreviates `--max-elements N --max-output-chars N`. DOCX query
predicates are `--kind`, `--text`, `--id`, repeatable `--property NAME=VALUE`,
and `--ignore-case`. XLSX query uses a quoted cell selector such as
`'cell[type=number][value>0]'`.

## Canonical selectors

Selectors are format-rooted:

```
/docx/body/p[1]
/docx/body/tbl[1]/tr[1]/tc[2]/p[1]
/docx/comments/comment[id="7"]
/xlsx/workbook
/xlsx/sheet[name="Data"]
/xlsx/sheet[name="Data"]/cell[A1]
/xlsx/sheet[name="Data"]/range[A1:C12]
```

Ordinal paths are snapshot-relative. Re-run `outline` or `text` after a
mutation before reusing them.

The XLSX payload shape follows the selector: a `cell[A1]` selector returns a
single `data.cell` **object**, while a `range[A1:C12]` selector returns a
`data.cells` **array**. Do not assume `data.cells` is always present.

## Mutation contracts

- `create` is create-new by default; `--overwrite` explicitly replaces an
  existing destination. `--dry-run` validates without publishing.
- XLSX `batch` consumes `xlsx.batch/2`; the historical `xlsx.batch/1` remains
  accepted with its exact v1 registry subset. With no `--out` it rewrites the
  input after all operations pass; prefer `--out` when preserving the source
  matters.
- DOCX `batch --format docx` consumes `docx.batch/2` (and accepts
  `docx.batch/1`) and only authors a fresh destination. It does not edit an
  existing DOCX and does not accept `--out`.
- `template` never modifies its template. It substitutes non-executable
  `{{key}}` placeholders from flat scalar data and optional marked-row regions
  into a separate output.
- `edit` is the literal find & replace surface for an existing DOCX. It
  consumes `docx.edit/1` (`{"op": "replace_text", "params": {"find", "replace",
  "occurrence"}}`) and publishes a separate output; the input is never touched.
  `find` is **literal**, never a regular expression, and matches across run
  boundaries. Omitting `occurrence` replaces every occurrence in document
  order; `occurrence: N` replaces only the Nth. Every op is matched against the
  original snapshot, so two ops whose matches overlap refuse
  (`office.edit.overlapping_matches`). A match the byte-span rewriter cannot
  own — mixed run content, a hyperlink boundary, or a footnote/endnote/comment
  story — refuses with `office.edit.unsupported_context` rather than being
  silently skipped, and an op that finds nothing refuses with
  `office.edit.unmatched_find` unless `--allow-unmatched` is passed.
- `edit` also RESOLVES tracked changes, through the same `docx.edit/1` script:
  `accept_revision` and `reject_revision` with `{"id"}`, `{"author"}`,
  `{"type": "ins"|"del"}`, or `{"all": true}`. Spelled selector fields are
  conjunctive; `id` is the stable `w:id` handle `outline` reports, and ordinal
  position is never a selector. Accepting an insertion (or rejecting a
  deletion) unwraps the element and keeps its runs; rejecting an insertion (or
  accepting a deletion) removes the element and its content. One script is
  entirely `replace_text` or entirely revision ops — mixing them is rejected.
- `edit` also has an ADDRESSED text surface, `set_run_text`, under
  `"schema": "docx.edit/2"`. Use it when you know *which* run to change rather
  than which text to find: `{"op": "set_run_text", "params": {"at", "expect",
  "text"}}`. `at` names ONE run — the `office query` path
  (`/docx/body/p[3]/r[2]`) or its body-relative form (`p[3]/r[2]`). `expect`
  must equal that run's **entire** current text, not a substring; a stale
  expectation refuses rather than editing the wrong run, because addresses are
  snapshot-relative and a document you read earlier may have moved. `text`
  replaces the run's whole text. Setting a run to its own text validates and
  changes nothing. A script is entirely `set_run_text` or entirely another
  family — never mixed. Prefer this over `replace_text` when the same literal
  occurs more than once, or when the text you want to change is short and
  ambiguous.
- **Addressed edits refuse on content whose edit would not survive.** This is
  the surface's main safety property and the most common surprise. A refusal
  here is not a defect to retry around — it means the write would have been
  lost, misattributed, or contradicted, and nothing downstream could have told
  you. `set_run_text` refuses a run that:
  - holds a **field's cached result** (a `PAGE`, `DATE`, `TOC`, `REF` or
    `MERGEFIELD` answer). Word recomputes it and discards your text. Edit what
    the field *asks*, or flatten the field, rather than its answer.
  - sits in a **tracked insertion** (`w:ins`). Writing there makes the document
    record that the insertion's named author wrote your words. Resolve the
    revision first with `accept_revision`, then edit the resulting plain text.
  - sits in a **content control** (`w:sdt`). A data-bound one is repopulated
    from its XML part on open. Change the bound data instead. Plain-text
    controls refuse too — the reader cannot yet tell them apart, and refusing
    the safe case is the deliberate side to err on.
  - sits in **textbox content** or a **markup-compatibility fallback**, where
    the same text is commonly stored twice and editing one copy leaves the
    other disagreeing.
  - **owns suppressed content** the reader could not model — a picture, an
    unmappable symbol, an unrecognised element — because replacing the run
    would leave content beside your text that you never saw.
  - sits in a **logical paragraph joined from several physical ones** (a
    deleted paragraph mark joins them), where one address does not name one
    place in the file.
  - **spans a hyperlink boundary**, where the rewrite would silently grow or
    shrink what is linked.
  Each refusal names the construct it found. Read the message: it tells you
  which of the above you hit, and therefore what to do instead.
- `annotate` is the preservation-safe existing-DOCX mutation surface. It
  consumes `docx.annotation-batch/1` with `comment_add`, `comment_reply`,
  `comment_resolve`, and `comment_unresolve` ops and publishes a separate
  output. **Its ops carry their fields directly, not under a `params` object**
  — unlike `xlsx.batch` and `docx.batch`. `comment_add` takes
  `anchor: {"at": "/docx/body/p[1]"}`, `author`, and `body` as an *array* of
  strings, plus an optional `label` that later ops reference via
  `{"label": ...}`. Passing `params` fails with
  `office.annotate.invalid_script`. Run `office help schema
  docx.annotation-batch/1 --json` and read its `examples` before authoring.
- `raw replace` and `raw edit` are expert fallbacks. Use `--dry-run` and a
  separate `--out`; semantic commands are safer whenever they can express the
  task.
- A preservation report is authoritative. Do not infer preservation from the
  requested operations.
- `dump --json` is the form accepted by `replay`. `dump --jsonl` is a
  streaming inspection form with a terminal digest, not replay input.
- `preview --overwrite` and `replay --overwrite` remove the old destination
  before staging the replacement; a later write failure can leave it absent.
  Use a fresh destination, or make and verify a backup before explicit
  replacement. They do not share the atomic-overwrite guarantee of the
  transaction-backed mutation commands.

Run `office help schema ID --json` before authoring any consumed JSON
document. It is normative for `xlsx.batch/2`, `docx.batch/2`,
`docx.edit/1`, `docx.edit/2`, `office.template.data/1`, and
`docx.annotation-batch/1`.

## Shapes that are easy to get wrong

These four cost a failed run each if you guess. All are visible in
`help schema`, but guessing is the natural failure.

**1. A table cell is an object, not a string.** `rows` is an array of arrays
of *cell objects*:

```json
{"op": "table", "params": {"header_rows": 1, "rows": [
  [{"text": "Area"}, {"text": "Owner"}],
  [{"text": "Cache"}, {"text": "Dana"}],
  [{"text": "Payments", "col_span": 2}]
]}}
```

A cell also takes `paragraphs` (for multi-paragraph cells) and `row_span`.
Passing `[["Area","Owner"]]` fails.

**2. Annotation ops have no `params`.** See the `annotate` bullet above —
fields sit directly on the op.

**3. `query` returns matched content in `preview`, not `text`.** A match is
`{path, kind, role, stability, preview, preview_truncated, properties}`.
Reading `.text` yields nothing and makes the command look broken.

**4. `outline` summarises comment threads but does not carry their text.**
Bodies come from `text --under '/docx/comments'`. See below.

## Reviewing a DOCX

`outline` returns the thread structure in one call — who commented, whether
it is resolved, what replies what, and which paragraph each comment covers:

```
office outline FILE --json     # .data.comments[]
```

```json
{"path": "/docx/comments/comment[id=\"0\"]", "id": "0",
 "author": "Reviewer", "done": true, "anchor": "/docx/body/p[5]"}
{"path": "/docx/comments/comment[id=\"1\"]", "id": "1",
 "author": "Ravi", "done": false, "parent_id": "0"}
```

`done` and `parent_id` appear **only when the document records them** — an
unresolved top-level comment has neither key. Treat a missing `done` as
unresolved and a missing `parent_id` as top-level rather than indexing them.

The comment *text* is not in the outline. For bodies, and for the full anchor
records when one summary path is not enough:

```
# the comment bodies, path-tagged
office text FILE --under '/docx/comments' --json

# one comment in full: every anchor, initials, date, body paragraph count
office get FILE '/docx/comments/comment[id="0"]' --json
```

`get` on a comment returns the full record under `metadata` — `author`,
`initials`, `date`, `body_paragraphs`, every `anchor`, plus `done` and
`parent_id`:

```json
{"id": "0", "ordinal": 1, "author": "Reviewer", "done": true,
 "anchors": [{"start": "/docx/body/p[5]", "end": "/docx/body/p[5]"}]}
```

Reach for `get` when the outline summary is not enough; for enumerating a
thread, the outline alone is usually sufficient.

**`text` shows the accepted view of a tracked document.** Insertions read as
ordinary text and deletions are gone, so a paragraph that says "revenue was up
18%" may be an unaccepted edit that replaced "flat". Nothing in `text` or `get`
says so. `outline` does:

```
office outline FILE --json     # .data.counts.insertions / .deletions, .data.revisions[]
```

```json
{"type": "del", "path": "/docx/body/p[1]", "id": "1",
 "author": "Reviewer", "date": "2026-01-01T00:00:00Z"}
{"type": "ins", "path": "/docx/body/p[1]", "id": "2", "author": "Reviewer"}
```

Check `counts.insertions` and `counts.deletions` before reporting anything from
a document as settled. `author`, `date`, and `id` appear **only when the
document records them** — the insertion above spells no `w:date`. Insertions
and deletions are counted apart because they distort the accepted view in
opposite directions: an insertion shows words nobody has agreed to, a deletion
hides words that are still in the file.

`text` deliberately keeps returning the accepted view whatever you do. To
change what the document actually says, resolve the revisions with `office
edit`:

```json
{"schema": "docx.edit/1", "ops": [
  {"op": "accept_revision", "params": {"author": "Reviewer"}}
]}
```

Select by `id` (the stable `w:id` above), `author`, `type` (`ins`/`del`), or
`all: true`; spelled fields are conjunctive. On the fixture above, accepting
everything yields "The revenue was up 18% this quarter." and rejecting
everything yields "The revenue was flat this quarter." `revisions_resolved`
reports the count, and `outline` on the output reports nothing pending.

Paragraph-mark and table-row revisions (`w:rPr/w:ins`, `w:trPr/w:del`), moves
(`w:moveFrom`/`w:moveTo`), and every `*PrChange` are out of scope: they are not
listed by `outline`, and a selection that REACHES one refuses with
`office.edit.unsupported_revision` instead of resolving the rest — so a partial
review can never masquerade as a finished one. A revision nested inside another
refuses too (`office.edit.conflicting_revisions`); resolve the inner one first.

**Anchors are whole body paragraphs.** `anchor.at` (and `to`) must be
`/docx/body/p[K]`. You cannot anchor a comment to a phrase, a run, a table
cell, or a header — `/docx/body/p[2]/r[1]` is rejected with
`anchor.at must be a single body paragraph`. Use `{"at": ..., "to": ...}` to
span several paragraphs. If you need phrase-level review, quote the phrase in
the comment body and anchor the paragraph that contains it.

## Verify before you deliver

**Assume your first output is wrong, and go looking for how.** Verification
here is a bug hunt, not a confirmation step. Exit code zero tells you the
command succeeded; it says nothing about whether the document is correct. If
your first inspection finds nothing, the usual explanation is that you did not
inspect hard enough — read the document back from disk and look again.

The defects this catches are dull and common, not exotic. A `{{client_name}}`
placeholder shipped as finished prose. A `\$` or `\t` left behind by a shell
quoting layer, rendering as literal backslash-dollar in the delivered file. A
reviewer's question still open in a comment thread. A sentence that reads as
settled fact but is an unaccepted insertion nobody has agreed to.

### Minimum cycle before "done"

Re-open the file from disk. Do not verify against the mutation report you just
received — it describes what the command intended, not what a reader will see.

1. `office validate FILE --json` — the schema gate. `.data.error_count` must
   be `0`.
2. `office issues FILE --json` — bounded actionable findings. This command
   exits `0` while reporting them, so read `.data.findings`, never `$?`.
3. `office text FILE --json` — the words a reader actually gets: typos, leaked
   `{{placeholders}}`, `\$`/`\t`/`\n` escape artefacts. One call covers body
   paragraphs, table cells, and comment bodies.
4. `office outline FILE --json` — the structure `text` cannot show you. On a
   DOCX: `.data.headings[].level` for hierarchy, `.data.comments[]` for open
   threads, `.data.counts.insertions`/`.deletions` for pending redline.

The outline payload is format-shaped. A DOCX outline carries `counts`,
`headings`, `comments`, and `revisions`; an XLSX outline carries `sheets` and
`sheet_count` and **none** of those keys. Index them on the wrong format and
jq yields `null` or aborts, which is why the gate below branches on the format
`identify` reports rather than probing blind.

Unlike `text`, `outline` refuses rather than truncating: exceeding
`--max-elements` returns `office.docx.resource_limit` with `success: false`,
so a partial outline can never be mistaken for a whole one.

Heading hierarchy is worth a look on every DOCX, because a skipped level is
invisible in `text`:

```
office outline FILE.docx --json |
  jq '[.data.headings[].level] as $l
      | [range(1; $l|length) | select($l[.] - $l[.-1] > 1)] | length'
```

Non-zero means at least one H1→H3-style jump. It is deliberately *not* in the
gate below: a skip is sometimes an intentional design choice, and every gate
entry must have an unambiguous REJECT.

When something fails, fix it and rerun the **whole** cycle. One fix routinely
uncovers the next, and ordinal selectors shift under you after every mutation.

### Delivery gate

Copy this verbatim, set `FILE`, and do not hand the document over until it
prints `GATE PASS`. Every REJECT is a defect in your output, not a false alarm
to argue with.

```bash
# Two shims so the gate runs as written.
office()    { moonx bobzhang/office "$@"; }
xlsx_lint() { moonx bobzhang/mbtexcel/cmd/xlsx lint "$@"; }

FILE="report.docx"          # the file you are about to hand over

fail=0
reject() { fail=$((fail + 1)); printf 'REJECT  %s\n' "$*"; }

FMT=$(office identify "$FILE" --json | jq -r 'select(.success).data.format // empty')
[ -n "$FMT" ] || reject "0 identify: not a readable DOCX/XLSX package"

# Gate 1 - schema. Test `.success` first: a package that fails this early
# carries an `error` object and no `.data` at all, so `.data.error_count`
# would be null, and `null` is not `0`-and-not-an-error to a naive test.
if office validate "$FILE" --json | jq -e '.success and .data.error_count == 0' >/dev/null; then
  echo "OK      1 schema"
else
  reject "1 schema"
  office validate "$FILE" --json | jq -c '.error // .data.findings[]'
fi

# Gate 2 - actionable findings. `issues` exits 0 while reporting them, so the
# finding count is the gate and `$?` is not.
if office issues "$FILE" --json | jq -e '.success and (.data.findings | length) == 0' >/dev/null; then
  echo "OK      2 issues"
else
  reject "2 issues"
  office issues "$FILE" --json | jq -c '.error // .data.findings[]'
fi

# Gate 3 - one complete text scan, captured once. Gate 4 means nothing unless
# this succeeded AND covered the whole document: a truncated or failed scan
# yields an empty stream, and an empty stream matches no leak pattern.
TEXT=$(office text "$FILE" --limit 10000 --json)
if printf '%s' "$TEXT" | jq -e '.success and .data.truncated == false' >/dev/null; then
  echo "OK      3 text scan complete"

  # Gate 4 - leaked template tokens and shell-escape artefacts. `grep -c`
  # prints a count on every path, including the empty stream, so it cannot
  # false-PASS the way `grep -q` silently does.
  LEAK_RE='\{\{[^}]*\}\}|\\[nt]|\\\$|<TODO>|TODO|TBD|FIXME|[Ll]orem ipsum'
  LEAK=$(printf '%s' "$TEXT" | jq -r '.data.entries[].text' | grep -cE "$LEAK_RE" || true)
  if [ "${LEAK:-1}" -eq 0 ]; then
    echo "OK      4 no leaked tokens"
  else
    reject "4 leaked token/escape artefact on $LEAK line(s)"
    printf '%s' "$TEXT" | jq -r '.data.entries[] | "\(.path)\t\(.text)"' | grep -E "$LEAK_RE"
  fi
else
  reject "3 text scan incomplete - page with --offset, or scope with --under"
  reject "4 not evaluated: gate 3 produced no trustworthy text"
  printf '%s' "$TEXT" | jq -c '.error // (.data | {truncated, returned, matched_total})'
fi

if [ "$FMT" = docx ]; then
  # Gate 5 - unresolved comment threads. An unresolved comment spells no
  # `done` key at all, so the test is `!= true` and never `== false`.
  if office outline "$FILE" --json | jq -e '.success and ([.data.comments[] | select(.done != true)] | length) == 0' >/dev/null; then
    echo "OK      5 comment threads resolved"
  else
    reject "5 unresolved comment thread(s)"
    office outline "$FILE" --json | jq -c '.error // (.data.comments[] | select(.done != true))'
  fi

  # Gate 6 - pending tracked changes. `text` renders the accepted view, so
  # redline is invisible to every other check in this gate.
  if office outline "$FILE" --json | jq -e '.success and .data.counts.insertions == 0 and .data.counts.deletions == 0' >/dev/null; then
    echo "OK      6 no pending revisions"
  else
    reject "6 unaccepted tracked changes"
    office outline "$FILE" --json | jq -c '.error // (.data.counts | {insertions, deletions})'
  fi
fi

if [ "$FMT" = xlsx ]; then
  # Gate 7 - formulas, run unconditionally. A formula-free workbook reports
  # finding_count 0 anyway, and no `=` heuristic over `text` is reliable: a
  # formula carrying a cached value surfaces as that value, not its source.
  if xlsx_lint "$FILE" | jq -e '.finding_count == 0' >/dev/null 2>&1; then
    echo "OK      7 formulas evaluate clean"
  else
    reject "7 formula error(s)"
    xlsx_lint "$FILE" 2>&1 | jq -c '.findings[]' 2>/dev/null || xlsx_lint "$FILE" 2>&1
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "GATE PASS - structurally verified. NOT visually verified."
else
  echo "GATE FAIL - $fail check(s) rejected. Do not deliver."
fi
# Last command on purpose: it sets the exit status without `exit`, so
# `bash gate.sh && deliver` cannot deliver a rejected document, and pasting
# the block into an interactive shell does not close it.
[ "$fail" -eq 0 ]
```

The gate never calls `exit`, on purpose: pasting it into your working shell
must not kill that shell, and one run should report every defect rather than
stopping at the first.

Three failure modes it is built to avoid, all of which false-PASS if you
rewrite it casually:

- **`.data` can be absent entirely.** A package that fails to open returns
  `{"success": false, "error": {...}}` with no `.data`. `jq -e '.success and
  ...'` rejects that; `jq '.data.error_count'` alone yields `null`.
- **An empty stream matches nothing.** If `text` fails, piping its output into
  `grep -q` finds no tokens and looks like a pass. Gate 4 therefore runs only
  inside gate 3's success branch, and counts with `grep -c`.
- **Exit codes are not findings.** `issues` and `xlsx lint` both exit `0`
  while reporting problems. Only the counts decide.

### What this gate does not cover

It verifies **structure, not appearance**. A document that prints `GATE PASS`
is structurally verified; it is not "looks right", and you should not describe
it that way when you hand it over.

`preview` writes HTML and nothing in this toolchain rasterises it, so there is
no step at which you can *look* at the document. Everything that only exists
once something renders is outside the gate:

- pagination — page count, page breaks, orphaned headings, blank pages
- layout and fit — column widths, truncated cells, overflowing tables, margins
- typography as seen — font substitution, actual rendered sizes, spacing rhythm
- anything a viewer computes at open time, including field results such as
  `PAGE` or a table-of-contents page column

Reading the `preview` HTML is still worth doing, and it is strictly better than
nothing — but it is reading a DOM, not seeing a page. State that limitation
when you deliver rather than letting a green gate imply more than it checked.

XLSX formula coverage has its own edge, already noted above: `xlsx lint`
evaluates formula masters, not shared/array slave formulas. Gate 7 passing
means no master evaluated to an error, not that every formula is correct.

## Legacy-only fallbacks

Do not start with these. Use them only when the named capability is required.
Each is a separately published module, reachable the same way:

| Missing from `office` | Legacy command |
| --- | --- |
| Direct CSV import to a new workbook | `moonx bobzhang/mbtexcel/cmd/xlsx csv INPUT.csv OUT.xlsx --sheet Data` |
| Evaluate one formula locally | `moonx bobzhang/mbtexcel/cmd/xlsx calc BOOK.xlsx Sheet1 B4` |
| Recompute and lint formula masters, including formulas with no cached result; shared/array slave formulas are not evaluated | `moonx bobzhang/mbtexcel/cmd/xlsx lint BOOK.xlsx [--sheet Sheet1]` |
| Discover the exact XLSX batch operations, parameters, allowed values, and limits accepted by this build | `moonx bobzhang/mbtexcel/cmd/xlsx capabilities` |
| Export one sheet as generic CSV (LF-delimited records) | `moonx bobzhang/mbtexcel/cmd/xlsx rows BOOK.xlsx --sheet Sheet1` |
| Render a selected or bounded XLSX view, suppress images, or calculate uncached formulas | `moonx bobzhang/mbtexcel/cmd/xlsx html BOOK.xlsx --out OUT.html [--sheet Sheet1] [--max-rows N] [--max-cols N] [--no-images] [--calc]` |
| DOCX to Markdown, custom Mammoth style maps, or extracted-image directories | `moonx bobzhang/docx2html/cmd/docx2html ...` |

The legacy writers do not share the unified transaction contract. CSV import
truncates an existing output, and XLSX HTML rendering replaces its output. Use
verified-new destination paths unless replacement is explicitly intended. DOCX
conversion truncates output files and writes extracted images
non-transactionally, so use a fresh output directory and publish it only after
the command completes successfully.

The umbrella already covers general HTML preview, read/query, validation,
creation, batch authoring, templating, comments, and raw OOXML access. Do not
route those tasks through the legacy CLIs.

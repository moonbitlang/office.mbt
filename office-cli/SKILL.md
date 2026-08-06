---
name: office
description: >-
  Work with non-PowerPoint Office/OOXML documents through the published unified
  office CLI: identify, inspect, query, validate, diagnose, preview, create,
  template, comment, batch-edit, dump/replay, or safely inspect raw parts in
  .docx and .xlsx files. Use this for Word and Excel tasks instead of
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

Pin a version when reproducibility matters: `moonx bobzhang/office@0.3.0 ...`.
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
6. Generate a `preview` and visually inspect the HTML before delivery.

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
| Replace literal text in an existing DOCX | `office edit FILE SCRIPT.json --out OUT.docx [--dry-run] [--overwrite] [--allow-unmatched] [--json\|--jsonl]` |
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
`office.template.data/1`, and `docx.annotation-batch/1`.

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

`revisions` is read-only. The CLI cannot accept or reject a tracked change, and
`text` deliberately keeps returning the accepted view. Paragraph-mark and
table-row revisions (`w:rPr/w:ins`, `w:trPr/w:del`) are property revisions and
are not listed.

**Anchors are whole body paragraphs.** `anchor.at` (and `to`) must be
`/docx/body/p[K]`. You cannot anchor a comment to a phrase, a run, a table
cell, or a header — `/docx/body/p[2]/r[1]` is rejected with
`anchor.at must be a single body paragraph`. Use `{"at": ..., "to": ...}` to
span several paragraphs. If you need phrase-level review, quote the phrase in
the comment body and anchor the paragraph that contains it.

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

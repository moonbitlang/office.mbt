---
name: office-cli
description: >-
  Inspect, create, edit, validate, and preview DOCX and XLSX files through the
  unified Office CLI, including comments, tracked changes, transactional edits,
  and DOCX rendering to PDF or SVG. Use when working with this CLI or when a
  portable command-line workflow fits the document task. Does not edit existing
  PDFs or PowerPoint files.
---

# Office documents through the CLI

Prefer the unified `office` command for its supported DOCX/XLSX operations.
Honor an explicit user choice of another tool. Use the format-specific fallbacks
below when the task needs a capability absent from `office`.

## Launch and discover

Run through `moonx` from any directory; arguments follow the package coordinate
without an extra `--` separator:

```sh
moonx moonbitlang/office help all --json
moonx moonbitlang/office help schemas --json
moonx moonbitlang/office help schema xlsx.batch/2 --json
```

Below, `office` abbreviates `moonx moonbitlang/office`. Use `help COMMAND --json`
for flags and limits, and `help schema ID --json` for the operations, constraints,
and examples of a consumed JSON contract. Discover these from the same version
that will execute the task. `help all` includes a `crc32:` capability fingerprint.
The running version's help takes precedence over examples in this file.

For reproducibility, pin a verified published version by appending `@VERSION`
to the package coordinate (replace `VERSION` with the selected version).
`@latest` refreshes the registry index; an unpinned coordinate uses the latest
version known to the local index.

`moonx` defaults to Wasm. Wasm alone does not guarantee denial of filesystem,
network, or process access: permissions depend on the host and runtime policy.
The CLI also enforces package, XML, scan, output, and mutation limits. Consult
`moonx --help` for the installed runtime's policy options; its native target is
currently deprecated, so do not assume a native launcher is always available.

## Choose an operation

| Task | Commands and distinctions |
| --- | --- |
| Identify and map structure | `identify FILE --json`; `outline FILE --json` |
| Read selected content | `get FILE SELECTOR --json`; `text FILE --under SELECTOR --json` |
| Search | `query` for bounded structural predicates; `find` for literal DOCX text and editability |
| Edit DOCX text or formatting | `replace`, `format`, `insert-paragraph`, `delete-paragraph`; `edit` for scripted replacements, addressed run edits, or revision resolution |
| Comments | `annotate` adds, replies to, resolves, or reopens DOCX comments |
| Create or author | `create xlsx OUT.xlsx`; `create docx OUT.docx`; `batch --format docx OUT.docx SCRIPT.json` |
| Edit XLSX | `batch BOOK.xlsx SCRIPT.json --out OUT.xlsx` |
| Fill templates | `template FILE DATA.json --out OUT` |
| Check package and findings | `validate FILE --json`; `issues FILE --json` |
| HTML preview | `preview FILE --output OUT.html --json` for DOCX or XLSX |
| Paginated DOCX rendering | `render FILE.docx --output OUT.pdf --json` or `--output OUT.svg`; optional `--pages RANGE` |
| Semantic export/import | `dump FILE --json`; `replay DUMP.json --output OUT` |
| OOXML fallback | `raw list`, `raw read`, `raw replace`, `raw edit` |

For XLSX batch capability discovery, use `office help schema xlsx.batch/2 --json`.
It carries the underlying batch operation registry and limits; a separate
`xlsx capabilities` invocation is unnecessary and may resolve a different version.

## Reading and selectors

Use `identify` when the format is unknown, then inspect the relevant structure
with `outline`, `text`, or `query`. Reuse returned canonical selectors:

```text
/docx/body/p[1]
/docx/body/tbl[1]/tr[1]/tc[2]/p[1]
/docx/comments/comment[id="7"]
/xlsx/sheet[name="Data"]/cell[A1]
/xlsx/sheet[name="Data"]/range[A1:C12]
```

Ordinal selectors are snapshot-relative; rediscover affected paths after edits.
A supported stable paragraph selector such as `p[id="1A2B3C4D"]` resolves by
identity, but still requires checking the targeted content.

Response details that affect callers:

- Ordinary JSON commands return an `office.output/1` envelope. Check `success`
  before reading `data`; failures may have only `error`.
- `dump --json` instead returns the replayable `office.dump/1` document directly.
  `dump --jsonl` is a streaming inspection form, not replay input.
- XLSX `get` returns `data.cell` as an object for a cell selector and `data.cells`
  as an array for a range selector.
- DOCX query matches carry `preview` and `preview_truncated`, not a `text` field.
- Text/query scans are bounded. Inspect `truncated`, `returned`, and
  `matched_total`; paginate with `--offset`/`--limit` as needed. A failed or
  partial scan does not establish that content is absent.
- DOCX outline carries `counts`, `headings`, `comments`, and `revisions`; XLSX
  outline carries `sheets` and `sheet_count`. Do not assume identical shapes.
  Outline refuses when its resource limits are exceeded instead of returning
  a partial successful outline.

## Mutation contracts

Inspect the relevant input schema before composing a script. Prefer a separate
output for edits and `--dry-run` where supported. Output syntax varies: `replace`
uses a positional output, `edit` uses `--out`, and `preview` uses `--output`.
Read the preservation report rather than inferring preservation from op names.

| Surface | Contract and publication behavior |
| --- | --- |
| XLSX `batch` | `xlsx.batch/2`; historical `/1` accepts its original subset. Without `--out`, rewrites the input after operations pass. |
| DOCX `batch --format docx` | `docx.batch/2`, also accepts `/1`. Authors a fresh destination; does not edit an existing DOCX or accept `--out`. |
| `template` | `office.template.data/1`; flat scalar data and optional marked-row regions. Substitutes non-executable `{{key}}` placeholders into a separate output. |
| DOCX `edit` | `docx.edit/1` or `/2`; publishes a separate output. Each script uses one operation family, described below. |
| DOCX `annotate` | `docx.annotation-batch/1`; separate output. Op fields are direct members, **not wrapped in `params`**. |

`create` refuses an existing destination unless `--overwrite` is supplied.
`preview`, `replay`, and `render` overwrite by removing the old destination
before staging its replacement; a later failure can leave it absent. Prefer a
fresh destination when retaining the old artifact matters. Multi-page SVG
rendering publishes separate files and is not atomic across the set; inspect
`office.render.partial_publication` if publication fails.

Use semantic operations before raw XML edits when they express the task.
For `raw replace`/`raw edit`, prefer a separate `--out` and inspect a dry run.

### Editing existing DOCX text

`docx.edit/1` supports these separate families; `/2` additionally supports
`set_run_text`. Do not mix families in one script:

- `replace_text`: `params` contains `find`, `replace`, and optional `occurrence`.
  Matching is literal, can cross runs, and uses the original snapshot for every
  op. Omitted occurrence means all matches; `N` selects the Nth. Overlapping
  matches refuse. Unmatched ops refuse unless `--allow-unmatched` is supplied;
  unsupported rewrite contexts also refuse rather than silently skipping text.
- `accept_revision` / `reject_revision`: select by `id`, `author`, `type`
  (`ins`/`del`), or `all: true`. Specified fields are conjunctive. Only resolve
  revisions when that is part of the requested task.
- `set_run_text` (`docx.edit/2`): `params` contains `at`, `expect`, and `text`.
  `at` addresses one run, for example `/docx/body/p[3]/r[2]` or
  `p[id="1A2B3C4D"]/r[2]`. `expect` must equal its entire current text; `text`
  replaces the entire run text. Use this when selecting a specific run is more
  precise than matching a repeated literal.

Addressed edits refuse field results, tracked insertions, content controls,
textbox/compatibility-fallback content, suppressed content, joined physical
paragraphs, and hyperlink-boundary cases that cannot be safely rewritten.
Read the reported construct and choose an appropriate operation; do not bypass
these refusals with a blind raw replacement. Resolving revisions or changing
bound data is a separate document change and must fit the user's task.

### Authoring tables and comments

DOCX table `rows` contain cell **objects**, not strings:

```json
{"op": "table", "params": {"header_rows": 1, "rows": [
  [{"text": "Area"}, {"text": "Owner"}],
  [{"text": "Cache"}, {"text": "Dana"}]
]}}
```

Cells can also have `paragraphs`, `col_span`, and `row_span`; consult the schema
for constraints.

Annotation operations are `comment_add`, `comment_reply`, `comment_resolve`,
and `comment_unresolve`. `comment_add` takes `anchor`, `author`, and `body`
(an array of strings), plus an optional `label` for subsequent references:

```json
{"schema": "docx.annotation-batch/1", "ops": [
  {"op": "comment_add", "anchor": {"at": "/docx/body/p[1]"},
   "author": "Reviewer", "body": ["Please confirm this amount."]}
]}
```

Anchors name whole body paragraphs, not phrases, runs, table cells, or headers.
Use `anchor: {"at": ..., "to": ...}` to span paragraphs. For phrase-level
feedback, quote the phrase in the comment and anchor its containing paragraph.

## Reviewing DOCX comments and revisions

`outline --json` reports comment summaries and reply relationships, not comment
bodies. Read bodies with `text FILE --under '/docx/comments' --json`; use
`get FILE '/docx/comments/comment[id="0"]' --json` for full comment metadata and
anchors. Missing `done` means unresolved; missing `parent_id` means top-level.
Optional author/date/id fields may also be absent.

`text` shows the accepted view: inserted text is present and deleted text is
omitted, even before revisions are resolved. Inspect outline's
`counts.insertions`, `counts.deletions`, and `revisions` when review status matters.
These describe supported text insertions/deletions, not every revision type.
Paragraph-mark/table-row revisions, moves, and property changes are outside
that inventory; zero counts do not prove the document has no tracked changes.
A revision-resolution selection reaching unsupported constructs refuses, as do
conflicting nested revisions.

## Verification matched to the task

For changed documents, read back the published file and check the requested
result. Select checks appropriate to the content and delivery requirements:

- **Package integrity:** `validate --json` runs the shared mutation package gate.
  Require a successful response with `data.error_count == 0`; this is not a
  complete OOXML Schema or Microsoft OpenXML SDK validation.
- **Diagnostics:** inspect `issues --json` findings and their scope. Exit zero
  can still carry warnings. Determine whether each finding affects the task;
  an empty bounded report is not proof of complete correctness.
- **Content:** use `text`, `get`, or `query` to verify changed content. Complete
  the relevant pagination before asserting absence of unexpected placeholders
  or omissions. Template markers, code escapes, and TODO text can be intentional.
- **Review state:** preserve comments and tracked changes for review deliverables.
  Require resolution only when the requested output is a finalized clean copy;
  account for the revision types the CLI cannot inventory.
- **Formulas:** when formula results need verification, use the `xlsx lint`
  fallback below and inspect `finding_count`/`findings`. `issues` only inspects
  cached errors, and preview does not evaluate uncached formulas. Lint evaluates
  formula masters, not shared/array slaves; no findings does not prove every
  formula correct.
- **Appearance:** open the generated HTML preview in an available viewer, or
  render DOCX to PDF/SVG and inspect it. Check `pages_total`, `images_dropped`,
  and `unsupported` notices; notices are not exhaustive. Rendering is not a
  guarantee of Word-identical pagination or viewer-computed field results.
  Report whether the result was actually viewed, rather than equating generated
  HTML/PDF with visual verification.

After a correction, rerun the checks affected by it and refresh stale selectors.
Once those checks pass, report any remaining coverage limits relevant to the
user's task; do not repeat the full cycle without a new reason.

## Format-specific fallbacks

These are executable packages within the mbtexcel and docx2html modules. Use
compatible pinned versions when reproducibility across tools matters.

| Capability absent from `office` | Command |
| --- | --- |
| CSV import into a new workbook | `moonx moonbitlang/mbtexcel/cmd/xlsx csv INPUT.csv OUT.xlsx --sheet Data` |
| Evaluate one formula | `moonx moonbitlang/mbtexcel/cmd/xlsx calc BOOK.xlsx Sheet1 B4` |
| Recompute/lint formula masters | `moonx moonbitlang/mbtexcel/cmd/xlsx lint BOOK.xlsx [--sheet Sheet1]` |
| Export a sheet as CSV | `moonx moonbitlang/mbtexcel/cmd/xlsx rows BOOK.xlsx --sheet Sheet1` |
| XLSX HTML with sheet/bounds, image suppression, or formula calculation | `moonx moonbitlang/mbtexcel/cmd/xlsx html BOOK.xlsx --out OUT.html [--sheet Sheet1] [--max-rows N] [--max-cols N] [--no-images] [--calc]` |
| DOCX Markdown, style maps, or extracted images | `moonx moonbitlang/docx2html/cmd/docx2html ...` (inspect its help for options) |

These writers do not share the unified transaction contract. CSV import and
XLSX HTML output replace existing files; DOCX conversion truncates output and
writes extracted images non-transactionally. Use fresh outputs unless replacement
is intended, and verify completion before delivering them.

# Agent JSON Schemas (xlsx and docx CLIs)

This is the normative specification of the versioned JSON payloads the
`cmd/xlsx` and `docx2html/cmd/docx` CLIs exchange with agents. The executable
examples live in `cmd/xlsx/cram/agent.t` and
`docx2html/tests/cram/docx-agent.md`; the snapshot tests in
`inspect/*_test.mbt` and `docx2html/inspect/*_test.mbt` pin the exact
serialized shapes. If this document and those tests disagree, the tests are
the source of truth and this document has a bug.

## Conventions (all schemas)

- Every payload's first key is `"schema"`, holding an identifier of the form
  `<domain>.<kind>/<major>` (e.g. `xlsx.outline/1`). Identifiers are declared
  once per module: xlsx identifiers in `inspect/schema.mbt`, docx identifiers
  in `docx2html/inspect/schema.mbt`.
- **Evolution is additive-only**: new optional keys may appear under an
  existing identifier; keys are never renamed, removed, or retyped. A
  breaking change mints a new identifier with a bumped major. Consumers of
  **emitted** payloads (`outline`, `get --json`) must ignore keys they do
  not recognize. Schemas the tool **consumes** (`xlsx.batch/1`) are the
  opposite: validated strictly, unknown keys are errors — a typo must fail
  loudly, not silently no-op.
- **`null` is never emitted.** An absent key means "unset / not present".
  Top-level inventory lists (`sheets`, `merges`, `tables`, `charts`,
  `images`, `pivot_tables`, `defined_names`, `cells`) are always present
  (possibly `[]`); optional sub-object fields — including list-valued ones
  like `fill.colors` or a style's `border` — may be omitted entirely.
- **Index bases**: sheet `index` is 0-based tab order. Rows and columns are
  never sent as bare numbers; cell and range references are A1-style strings.
- Output is pretty-printed (2-space indent) UTF-8 with a trailing newline,
  deterministic for a given workbook.

## `xlsx.outline/1` — workbook structure map (`xlsx outline <file>`)

Top-level keys:

| key | type | notes |
|---|---|---|
| `schema` | string | `"xlsx.outline/1"` |
| `file` | string | the path argument, echoed verbatim |
| `sheet_count` | number | worksheets + chart sheets |
| `active_sheet` | object? | `{name, index}`; `index` spans both sheet kinds in tab order |
| `defined_names` | array | `{name, refers_to, scope?, comment?}`; `scope`/`comment` omitted when empty. Includes engine-managed names such as `_xlnm._FilterDatabase` |
| `sheets` | array | one entry per tab, in tab order |

Sheet entries carry a `kind` discriminator:

**`"kind": "worksheet"`**

| key | type | notes |
|---|---|---|
| `name`, `index`, `state` | string, number, string | `state` ∈ `visible` \| `hidden` \| `very_hidden` |
| `declared_dimension` | string? | the retained OOXML `<dimension>`; **may be stale** after mutations — trust `used_range` |
| `max_row`, `max_col` | number | live extents (0 for an empty sheet) |
| `used_range` | string? | `A1:<max>`, omitted when the sheet is empty |
| `frozen` | object? | `{x_split, y_split, top_left_cell?}`, present only when panes are frozen |
| `auto_filter` | string? | the filter range |
| `merges` | array | range strings |
| `tables` | array | `{name, range, columns[]}` |
| `charts` | array | `{anchor, width_emu, height_emu, kinds[], series[]}`; `kinds` are DrawingML plot-kind names (e.g. `barChart`), `series` entries are `{name?, categories?, values?}` range refs scanned from the retained chart XML (XML entities decoded). The scanner matches the conventional `c:` namespace prefix — a chart bound to a different prefix yields empty `kinds`/`series`, never an error |
| `images` | array | `{anchor, extension, content_type, width_emu, height_emu}` |
| `pivot_tables` | array | `{name}` |
| `counts` | object | `{data_validations, conditional_format_ranges, comments, hyperlinks, slicers}`; conditional-format ranges count space-separated `sqref` entries, not rule blocks |

**`"kind": "chart_sheet"`**: `{kind, name, index, state, charts[]}` where the
single `charts` entry is `{kinds[], series[]}`.

**`"kind": "unknown"`** is reserved for tab entries the reader cannot
classify (should not occur) and keeps `index` aligned with tab order.

## `xlsx.cells/1` — structured range read (`xlsx get <file> <sheet> <range> --json`)

The `<range>` argument accepts a single cell (`B2`) or a range (`A1:C3`,
corner order irrelevant), with optional `$` anchors and lowercase letters.
Parsing is strict: a reference must be 1–3 column letters plus row digits
inside the xlsx grid (`XFD1048576`), so malformed input (`A$B1`,
over-long column names) is rejected rather than silently aliased to some
valid cell. Ranges are capped at **100,000 cells**; larger ranges fail with
a clean error and no output.

| key | type | notes |
|---|---|---|
| `schema` | string | `"xlsx.cells/1"` |
| `file`, `sheet` | string | echoed |
| `range` | string | **normalized** ref (top-left first; single cell stays a single name) |
| `cells` | array | row-major; one entry per non-absent cell |
| `styles` | object | style id (decimal string) → style object; only non-zero ids referenced by `cells`, in first-reference order |

A cell appears in `cells` when it has a stored non-empty value, a formula,
or a **non-zero effective style** (cell → row → column precedence, matching
the write-side `prepareCellStyle` rule — so a blank cell inside a styled row
or column is reported); fully-absent cells are omitted (absence ⇒ blank and
unstyled). An **empty-string cell is treated as a synthetic blank** —
styling a bare cell and setting an uncached formula both store one — so such
a cell carries no `value`/`raw`: a styled blank appears as
`{ref, style_id}`, an uncached formula as `{ref, formula, style_id?}`.
Entry keys:

| key | type | notes |
|---|---|---|
| `ref` | string | A1-style |
| `value` | string? | the **formatted display string**; present iff the cell stores a non-empty value. The number format applied is the cell's **own** style's (excelize `GetCellValue` parity) — a row/column-inherited format is reported via `style_id` but not applied to `value` |
| `raw` | object? | `{type, value}` with `type` ∈ `string` \| `number` \| `bool` \| `error`; `value` is the matching JSON type (`error` carries the code as a string) |
| `formula` | string? | stored formula text, without a leading `=` |
| `style_id` | number? | the **effective** style id (cell → row → column precedence), present only when non-zero; key into `styles` |

Style objects (all keys optional; absent ⇒ property unset):

- `num_fmt_id` (number, builtin format id) / `number_format` (string, custom
  format code)
- `font`: `{bold?, italic?, strike?, underline?, size?, color?,
  color_theme?, color_indexed?, color_tint?, family?}`
- `fill`: `{type?, pattern?, colors?[], fg_theme?, fg_indexed?, fg_tint?,
  bg_theme?, bg_indexed?, bg_tint?}` (theme/indexed color slots are how most
  real files carry color — a themed fill has no literal `colors` entry)
- `border`: array of `{side, style?, color?}` (`side` ∈ `left`/`right`/`top`/
  `bottom`/`diagonal…`)
- `alignment`: `{horizontal?, vertical?, wrap_text?, text_rotation?, indent?,
  shrink_to_fit?}`
- `protection`: `{hidden?, locked?}`

Literal color fields (`font.color`, `fill.colors[]`, `border[].color`) are
the workbook's stored hex strings (typically `RRGGBB` or `AARRGGBB`),
passed through unvalidated — consumers rendering them must validate. The
theme/indexed/tint fields are numeric theme-palette references, not hex.

## `xlsx.batch/1` — mutation script (`xlsx batch <file> <script.json>`)

Envelope:

```json
{
  "schema": "xlsx.batch/1",
  "ops": [
    {"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": "Hello"}}
  ]
}
```

- Op names mirror the CLI subcommands; params are snake_case versions of
  the CLI arguments. Normative per-op params (`?` = optional):

| op | params |
| --- | --- |
| `set` | `sheet` (string), `cell` (string), `value` (string \| number \| bool \| null) |
| `formula` | `sheet`, `cell`, `formula` (strings; leading `=` optional) |
| `style` | `sheet`, `range` (strings); `bold?`, `italic?` (bool); `number_format?`, `fill?`, `font_color?`, `align?` (strings) |
| `merge` | `sheet`, `range` (strings) |
| `width` | `sheet`, `column` (strings; `A` or `A:C`), `width` (number) |
| `freeze` | `sheet`, `cell` (strings) |
| `filter` | `sheet`, `range` (strings) |
| `add-sheet` | `name` (string) |
| `chart` | `sheet`, `anchor`, `categories`, `values` (strings, required); `type?` (default `col`), `name?`, `title?` (strings) |
- `set.value` accepts string, number, bool, or null. JSON types are honored:
  a number becomes a numeric cell, a string a text cell (no
  reclassification), a bool a boolean cell, and null clears the cell.
- Validation is strict, and the file is never touched on failure.
  Envelope errors (missing/unsupported `schema`, malformed `ops`) carry no
  index; op-level errors (unknown op, unknown param key, wrong param type)
  name the 0-based op index, e.g. `op 1 (style): unknown param 'colour'`.
- Numbers follow standard JSON semantics: a literal parses to the nearest
  IEEE-754 double (about 15–17 significant digits; `9007199254740993`
  stores `9007199254740992`, spelling-independent). Literals whose value
  is not finite — `1e309` overflows to infinity — are rejected rather
  than corrupting the sheet.
- Application is all-or-nothing: ops apply to the in-memory workbook and the
  file is written (temp file + rename) only after every op succeeds.
- Every cell/range/column reference is validated at parse time against
  the strict in-grid grammar: `cell` params must be a single cell (no
  range spelling); `merge`/`filter` `range` params must be an `A1:B2`
  colon range; `style.range` accepts a cell or range (each range capped
  at 100,000 cells); `column` is a letters-only column or ascending
  column range; chart `categories`/`values` are a range with an optional
  non-empty `Sheet!` qualification.
- Zero ops is a valid no-op and writes nothing. Scripts are capped at
  10,000 ops, style ranges at 1,000,000 expanded cells per script in
  aggregate, and numeric literals at 40 characters (pathologically long
  literals can round incorrectly upstream).
- `--dry-run` parses and applies in memory but never writes.
- The save resolves a symlinked workbook to its target first (native),
  writes a uniquely-named temp through its exclusive handle, and renames
  it over the target, syncing the bytes to stable storage first. On
  POSIX the saved file is created owner-only (0600) — never wider than
  the original (Windows follows directory ACLs); chmod afterwards for
  group access.

## `docx.outline/1` — document structure map (`docx outline <file>`)

A metadata-priced orientation payload: no document text is emitted beyond
heading lines. Counts and headings cover the **main body story only** —
footnote/endnote/comment bodies are counted as units, not folded into
`paragraphs` — while nested body content (paragraphs inside table cells) is
included. All top-level keys are always present (possibly `[]`).

| key | type | notes |
|---|---|---|
| `schema` | string | `"docx.outline/1"` |
| `file` | string | the path argument, echoed verbatim |
| `counts` | object | `{paragraphs, tables, images, hyperlinks, bookmarks, footnotes, endnotes, comments, headers, footers, sections}`, all numbers. `headers`/`footers` count distinct parts, `sections` counts logical sections (a document always has at least one — the final section exists even without an explicit body-final `sectPr`). `bookmarks` counts bookmark starts (Word's transient `_GoBack` is dropped by the reader); `footnotes`/`endnotes` count note definitions. `hyperlinks` counts link spans in the parsed document: a multi-run field hyperlink (e.g. a Word TOC entry) contributes one span per run, so this can exceed the rendered `<a>` count |
| `headings` | array | in document order: `{level, text, style_id?, style_name?}`. Heading detection follows the Mammoth default style-map convention with its rule order and matching semantics — style ids compare exactly, style names case-insensitively: id `Heading1`..`Heading6`; else name equal (ignoring case) to `heading 1`..`heading 6`; else bare id `Heading` / bare name `heading` (level 1). Headings whose text is empty are omitted. `text` is the paragraph's raw text without the trailing paragraph separator |
| `styles_in_use` | array | unique `{kind, id?, name?}` in first-use order; `kind` ∈ `paragraph` \| `run` \| `table`. Only styles the reader resolved on body elements (unstyled elements contribute nothing) |
| `images` | array | `{content_type, bytes}` per embedded image, in document order; `bytes` is the image part's byte length — no image data is emitted |
| `sections` | array | in document order: `{ends_after_paragraph?, headers, footers}`. `ends_after_paragraph` is the 1-based index of the section's last direct body paragraph (absent = the body-final section); `headers`/`footers` are the section's **effective** references — OOXML inheritance applied: a section without an explicit reference for a variant uses the previous section's, and an explicit-but-unreadable reference blocks inheritance for that variant. Ordering is deterministic: explicit references in XML order, then inherited entries in the previous section's effective order. Entries are `{variant, part}` with `variant` ∈ `default` \| `first` \| `even` and `part` the 1-based index into the `/header[n]` / `/footer[n]` path space |
| `messages` | array | reader diagnostics: `{severity, text}` with `severity` ∈ `warning` \| `error` (e.g. ignored unrecognised elements) |

## docx element paths (shared by `docx text`, `docx get`, and future mutations)

Paths are **logical, snapshot-relative projection paths** over the parsed
document — not literal source-XML paths, and not stable anchors:

- Grammar: a root — `/body`, `/header[n]`, or `/footer[n]` — followed by `kind[index]` segments, 1-based:
  `/body/p[3]`, `/body/tbl[1]/tr[2]/tc[1]/p[1]`.
- Kind table (part of the `docx.element/1` contract; extended only
  additively): `p` paragraph, `r` run, `tbl` table, `tr` table row, `tc`
  table cell, `hyperlink`, `image`. Leaves and structural nodes without a
  kind (text, tabs, breaks, references, bookmarks) are not directly
  addressable — read them through their parent.
- Indices count same-kind DIRECT siblings within the parent (a hyperlink
  between two paragraphs does not consume a `p` index). Nested content
  always gets its full path — a table-cell paragraph is never `/body/p[N]`.
- A path is valid for one document snapshot; positional paths shift after
  any edit. Because the reader flattens some OOXML nodes (content controls,
  revisions), kinds are the parsed document's semantic kinds with OOXML-like
  spellings.
- Roots: `/body` (the main story) and `/header[n]` / `/footer[n]` (1-based
  index into the outline's part space; a too-large index is an ordinary
  not-found naming the part count). Reserved roots for the upcoming
  notes/comments surface — `/footnotes/note[id]`, `/endnotes/note[id]`,
  `/comments/comment[id]` — fail with a dedicated "reserved but not yet
  addressable" error rather than `not found`.
- Future batch mutations will resolve each path against the document state
  produced by the preceding ops in the same script.

Resolution errors are agent-correctable: they name the failing segment and
how many same-kind children exist (`'/body' has 2 'p' children (wanted
index 9)`).

## `docx.element/1` — one element by path (`docx get <file> <path> --json`)

Without `--json`, `get` prints the element's raw text only. The JSON payload:

| key | type | notes |
|---|---|---|
| `schema` | string | `"docx.element/1"` |
| `file` | string | echoed |
| `path` | string | **normalized** (`p[02]` → `p[2]`); `/body` for the body itself |
| `kind` | string | `body` \| `header` \| `footer` (path roots) \| `p` \| `r` \| `tbl` \| `tr` \| `tc` \| `hyperlink` \| `image` |
| `children` | array | `{kind, path}` per addressable direct child, in document order |

Kind-specific keys (all optional — absent means unset; boolean flags appear
only when true; `null` is never emitted):

- `p`: `text` (raw text without the trailing paragraph separator),
  `style_id`, `style_name`, `numbering` (`{ordered, level}`), `alignment`
- `r`: `text`, `style_id`, `style_name`, `bold`, `italic`, `underline`,
  `strikethrough`, `all_caps`, `small_caps`, `vertical_alignment`
  (`superscript`/`subscript`), `font`, `font_size` (**points** — the reader
  halves OOXML's `w:sz` half-points, truncating odd values), `highlight`
- `tbl`: `style_id`, `style_name`
- `tr`: `header` (true for header rows)
- `tc`: `col_span`, `row_span` (present only when ≠ 1)
- `hyperlink`: `text`, `href`, `anchor`, `target_frame`
- `image`: `content_type`, `bytes` (image part byte length), `alt_text`

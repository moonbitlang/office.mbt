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
  once per package: xlsx identifiers (including the consumed
  `xlsx.batch/1`) in `inspect/schema.mbt`, docx read-side identifiers in
  `docx2html/inspect/schema.mbt`, and the consumed `docx.batch/1` /
  `docx.batch/2` identifiers in `docx2html/batch` (`SCHEMA_BATCH`,
  `SCHEMA_BATCH_V2`), next to their parser.
- **Produced payloads** (everything the CLIs print — outline, element,
  `get --json`) evolve additively-only: new optional keys may appear under
  an existing identifier; keys are never renamed, removed, or retyped. A
  breaking change mints a new identifier with a bumped major. Consumers
  must ignore keys they do not recognize.
- **Consumed scripts** (`xlsx.batch/1`, `docx.batch/1`, `docx.batch/2`)
  are the opposite:
  validation is STRICT. Unknown keys, unknown enum values, and wrong value
  types are rejected with an error naming the op — a typo must fail
  loudly, not silently no-op or drop content.
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

## `xlsx.query/1` — content-selector cell search (`xlsx query <file> <sheet> <selector>`)

Finds the cells on `sheet` matching a **content selector**, returned in the
same per-cell shape as `xlsx.cells/1` (`ref`/`value`/`raw`/`formula`/`style_id`,
plus the shared deduplicated `styles` map) — so an agent can filter ("every
formula", "every value over 100") instead of reading a whole range and
scanning it itself. Scans the sheet's used range by default, or the
`--range A1:D100` you pass (both bounded at 100,000 cells).

```json
{
  "schema": "xlsx.query/1",
  "file": "book.xlsx",
  "sheet": "Data",
  "range": "A1:B4",
  "selector": "cell[type=formula]",
  "match_count": 1,
  "matches": [ { "ref": "B4", "formula": "SUM(B1:B3)" } ],
  "styles": {}
}
```

- A **selector** is the literal `cell` followed by zero or more `[predicate]`
  groups, ANDed together. `cell` alone matches every populated cell. `range`
  echoes the scanned rectangle (the empty string for an empty sheet), and
  `match_count` is `matches.length()`.
- Predicates:
  - `type=formula|number|string|bool|error` — by raw value kind (`formula` =
    has a formula; a formula with no cached value is *not* `number`).
  - `value>N` / `value>=N` / `value<N` / `value<=N` / `value=N` / `value!=N` —
    numeric comparison against a cell's raw number (non-numeric cells never
    match).
  - `formula` — has a formula; `formula~=TEXT` — the formula contains `TEXT`.
  - `text=TEXT` — the string cell equals `TEXT`; `text~=TEXT` — contains it.
    A blank cell (an empty stored string) never matches a `text`/`string`
    predicate.
- A predicate argument (the `TEXT` after `=`/`~=`, the `N` after an operator)
  is trimmed of surrounding whitespace and cannot contain `]` (which closes
  the predicate). `text=`/`text~=`/`formula~=` require a non-empty value, and a
  `value` bound must be a finite number (`NaN`/`Infinity` are rejected).
- `query` is read-only. A malformed selector, an oversized scan, or a missing
  sheet fails with a non-zero exit and a one-line `error:` message; nothing is
  written.

## `xlsx.calc/1` — a cell's typed computed value (`xlsx calc <file> <sheet> <cell> --json`)

Evaluates a cell's formula and returns its **computed** value, typed — the
gap `xlsx.cells/1` leaves for a formula with no cached value (`get --json`
reports the formula text but no value until it is recalculated). Without
`--json`, `calc` prints the value as a string as before.

```json
{
  "schema": "xlsx.calc/1",
  "file": "book.xlsx",
  "sheet": "Data",
  "ref": "B2",
  "result": { "type": "number", "value": 200 }
}
```

- `ref` echoes the requested cell. `result` is `{type, value}` — the **same
  shape** as an `xlsx.cells/1` cell's `raw` field (`type` ∈
  `number`/`string`/`bool`/`error`; an `error` carries its code as the value).
- `result` is **omitted** when the formula computes to an empty result
  (absence means blank, matching the other read payloads). A genuine formula
  error is a *present* result with `type: "error"` (e.g. `"#DIV/0!"`); only a
  missing sheet or malformed reference fails with a non-zero exit.
- The value is recomputed on demand and reflects the engine's evaluation; it
  is not read from any stored cache.

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
| `table` | `sheet`, `range` (strings; `range` is an `A1:B2` colon range); `name?`, `style?` (strings); `header_row?`, `row_stripes?`, `first_column?`, `last_column?`, `column_stripes?` (bool) |
| `validate` | `sheet`, `range` (strings; `range` is the cell/range the rule covers), `type` (required: `list`/`whole`/`decimal`/`date`/`time`/`textLength`/`custom`); `operator?`, `formula1?`, `formula2?`, `source?` (strings); `values?` (string array); `allow_blank?` (bool); `input_title?`, `input_message?`, `error_title?`, `error_message?`, `error_style?` (strings) |
| `cf` | `sheet`, `range` (strings; `range` is the cell/range the rule covers), `type` (required: `cell`/`formula`/`2_color_scale`/`3_color_scale`/`data_bar`/`icon_set`); `criteria?`, `value?`, `min_value?`, `max_value?`, `formula?` (strings); `fill?`, `font_color?` (strings), `bold?`, `italic?` (bool); `min_type?`, `mid_type?`, `max_type?`, `mid_value?`, `min_color?`, `mid_color?`, `max_color?`, `bar_color?` (strings); `bar_solid?` (bool), `bar_direction?`, `bar_border_color?` (strings, x14 data bar); `icon_style?` (string); `reverse_icons?`, `stop_if_true?` (bool) |
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
  at 100,000 cells); `table.range` must be an `A1:B2` colon range but is
  not cell-capped; `validate.range` and `cf.range` are a cell or `A1:B2`
  range, also not cell-capped; `column` is a letters-only column or ascending
  column range; chart `categories`/`values` are a range with an optional
  non-empty `Sheet!` qualification.
- `table` takes its column names from the header row of `range` (set those
  cells first, in an earlier op); the engine auto-names any blank or
  duplicate header `Column<n>`. `range` must be an `A1:B2` colon range and,
  unlike `style.range`, is not subject to the 100,000-cell cap (a table
  reads only the header row, never the whole range). A single-row range is
  expanded downward by one row to make room for a data row, so a single-row
  range on the last grid row is rejected at parse time. An omitted `name`
  lets the engine assign `Table<n>`; an omitted `style` keeps the default
  (`TableStyleMedium9`). `header_row` and `row_stripes` are tri-state —
  omitting them keeps the engine defaults (both `true`), distinct from
  passing `false`. Adding a table whose range intersects an existing one, or
  reusing a table name, fails at apply time.
- `validate` attaches one data validation to `range` (a single cell or an
  `A1:B2` range; not cell-capped, since a whole-column rule is common). Pick
  a `type`:
  - `list` — a dropdown; give inline `values` (a string array; the engine
    comma-joins and quotes them, so an individual value must not contain a
    comma or start with `=` — use `source` for those) *or* a `source` cell
    range (e.g. `Lists!$A$1:$A$5`). `values` win if both are given.
  - `whole`/`decimal`/`date`/`time`/`textLength` — a comparison needing an
    `operator` (`between`/`notBetween`/`equal`/`notEqual`/`greaterThan`/
    `greaterThanOrEqual`/`lessThan`/`lessThanOrEqual`) and `formula1`;
    `between`/`notBetween` also need `formula2` (the others must not carry
    one). `formula1`/`formula2` are written verbatim (a number, a cell
    reference, or a formula).
  - `custom` — a boolean `formula1` (e.g. `=ISNUMBER(A1)`).

  `allow_blank` defaults to `true` (omit to allow empty cells; pass `false`
  to forbid them). Supply `input_title`/`input_message` for a hover prompt
  and `error_title`/`error_message` (+ `error_style` `stop`/`warning`/
  `information`, default `stop`) for the rejection alert. The `type`,
  `operator`, and `error_style` values are checked at apply time, and a
  param the chosen `type` does not use (e.g. `operator` on a `list`, or
  `values` on a `whole` rule) is rejected rather than silently ignored.
- `cf` adds one conditional-formatting rule to `range` (repeat the op to
  stack rules; the engine assigns increasing priorities). Every color
  (`fill`, `font_color`, `min_color`/`mid_color`/`max_color`, `bar_color`) is
  a 6-digit hex RGB (an optional leading `#`). Pick a `type`:
  - `cell` — a value comparison; `criteria` is an operator (`>`, `>=`, `<`,
    `<=`, `=`, `!=`, `between`, `not between`) plus a `value` (or, for
    `between`/`not between`, `min_value` and `max_value`), and a highlight
    (`fill`, `font_color`, `bold`, `italic` — at least one).
  - `formula` — a boolean `formula` (e.g. `=$A1>0`) plus a highlight.
  - `2_color_scale` / `3_color_scale` — `min_color`/`max_color` (+ `mid_color`
    for 3), optionally the matching `*_type`/`*_value` cfvo stops. A `*_type`
    is one of `num`/`min`/`max`/`percent`/`percentile`/`formula`.
  - `data_bar` — `bar_color` (defaults to a blue) and optional
    `min_type`/`min_value`/`max_type`/`max_value` (same stop types). The
    **x14 extended** bar is opted into with any of `bar_solid` (solid fill
    instead of gradient), `bar_direction` (`leftToRight`/`rightToLeft`), or
    `bar_border_color` (a 6-hex RGB); those emit the `x14:` extension block.
  - `icon_set` — a classic `icon_style` (e.g. `3TrafficLights1`, `4Arrows`,
    `5Rating`; the x14-only `3Stars`/`3Triangles`/`5Boxes` are not supported
    by this op); `reverse_icons` flips the order.

  `stop_if_true` (on `cell`/`formula` rules) stops evaluating lower-priority
  rules when this one matches. As with `validate`, the `type` is checked at
  apply time and a param the chosen type does not use is rejected rather than
  silently ignored.
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

### Forward-compatibility & `xlsx.capabilities/1` (`xlsx capabilities`)

The `xlsx.batch/1` *script* contract is backward-compatible: a script that
was valid stays valid on newer builds. It is **not** forward-compatible —
a stricter older CLI rejects an op or param it doesn't know. So an agent
targeting an unknown build should first query what that build supports:

```json
{
  "schema": "xlsx.capabilities/1",
  "batch_schema": "xlsx.batch/1",
  "limits": { "max_ops": 10000, "max_style_cells": 1000000 },
  "ops": [
    { "op": "set", "params": [
        { "name": "sheet", "type": "string", "required": true },
        { "name": "cell",  "type": "cell",   "required": true },
        { "name": "value", "type": "value",  "required": true } ] }
    // … one entry per op this build accepts
  ]
}
```

`ops[].params[].type` names the validator applied at parse time — `cell`
(single in-grid cell), `range` / `colon_range` (each capped at 100,000
cells, since the op enumerates them), `table_range` (an `A1:B2` colon range
that is *not* cell-capped — a table reads only the header row), `sqref` (a
cell or `A1:B2` range a validation covers, also not cell-capped), `column`,
`series_range` (optional `Sheet!` prefix), `value` (string/number/bool/null),
`string`, `string_array`, `number`, `bool`. New ops appear in `ops` on newer builds; the catalog is
the single source of truth an agent should read rather than hard-coding the
op list. (Parsed ops are opaque in the library API too, so growing the op
set is a source-compatible change.)

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
| `comments` | array | the annotation inventory: `{id, author?, done?, parent_id?, anchored_to?}` per comment (always present, possibly `[]`); full semantics under "Annotations in the read surface" |
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
- Roots: `/body` (the main story), `/header[n]` / `/footer[n]` (1-based
  index into the outline's part space; a too-large index is an ordinary
  not-found naming the part count), and the annotation stories
  `/footnotes`, `/endnotes`, `/comments` (live since Phase 2 — see the
  Annotations section for their container selectors).
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

## Annotations in the read surface (Phase 2: `/comments`, `/footnotes`, `/endnotes`)

Additive extensions to the existing identifiers (consumers ignoring
unknown keys are unaffected):

- **Path grammar**: the annotation roots are live. Their first segment is
  `comment[...]` / `note[...]`, selected by ORDINAL (`comment[2]`,
  snapshot-relative like all ordinals) or by DOCUMENT ID
  (`comment[@id=3]` — ids are document-lifetime stable, the preferred
  agent handle). The id token matches the literal id string and may not
  be empty or contain `]`/`=`; an id shared by multiple containers is
  AMBIGUOUS (the error names the ordinal alternatives). Deeper segments
  are the ordinary body grammar (`/comments/comment[@id=0]/p[1]`).
  Emitted paths use the id form when the id is unique, else the ordinal.
- **`docx.outline/1`** gains a top-level `comments` inventory (always
  present, possibly `[]`): `{id, author?, done?, parent_id?,
  anchored_to?}` per comment, in comments.xml order — metadata only, no
  bodies. Ids that appear only in markers (no definition) are listed
  after the definitions with whatever metadata exists; they are not
  path-addressable.
- **`docx.element/1`** gains kinds `comment`, `footnote`, `endnote` for
  the annotation containers: `id`, `author?`, `initials?`, `date?`
  (lexical, never converted), `done?` and `parent_id?` (w15 threading,
  keyed by the comment's LAST body paragraph per CT_CommentEx),
  `anchors` (array of `{story, start?, start_boundary?, end?,
  end_boundary?, references}` — boundaries are `before`/`inside_start`/
  `inside_end`/`after`), `anchored_to?` (the first anchor's
  start-else-first-reference path), and `children` (the body, ordinarily
  addressable). Notes carry `references` (every referencing body
  position; multi-reference notes preserved). BODY elements covered by a
  comment's anchors gain `comment_ids` (intersection semantics; point
  anchors cover their reference's paragraph).
- **`docx text`** emits the annotation stories after headers/footers in
  story-rank order (`/footnotes`, `/endnotes`, `/comments`).
- Positions never lie: every anchor path is verified against the parsed
  document or degraded to its nearest resolvable ancestor with a
  diagnostic in `messages`. All index diagnostics (orphan definitions,
  dangling markers/references, duplicate ids, degradations, and ids that
  cannot take the `[@id=...]` form and therefore emit ordinal paths)
  surface as `messages` warnings.

## `docx.batch/1` — authoring script (`docx batch <output> <script.json>`)

The consumed (input) schema: **strict** validation — an unknown schema, op,
key, or enum value, a duplicate key within one object, or a wrong value
type fails naming the 0-based op index and the offending key; nothing is
repaired. Numbers must be plain decimal integers — no fraction or
exponent (`2.9` and `1e2` are errors, never coerced; every numeric field
in this schema is an integer). Strings destined for the document reject
characters XML cannot carry: C0 controls (text additionally rejects raw
`\n`/`\r` — paragraphs are the line-break unit), unpaired surrogates,
and U+FFFE/U+FFFF. **Fresh-document-only**: the output path must not exist
(the reader is lossy, so mutating existing files would silently drop
unmodeled parts — batch refuses rather than corrupts). The build is
all-or-nothing with an atomic write (unique temp + no-replace rename);
`--dry-run` parses, builds, and validates without writing. Scripts are
capped at 10,000 ops; an empty `ops` array yields a blank document.

```json
{
  "schema": "docx.batch/1",
  "ops": [
    {"op": "paragraph", "params": {"text": "Title", "style": "Heading1"}},
    {"op": "paragraph", "params": {"align": "center", "runs": [
      {"text": "bold", "bold": true, "size": 14},
      {"link": {"href": "https://example.com", "text": "site"}},
      {"image": {"path": "logo.png", "alt": "logo"}}
    ]}},
    {"op": "paragraph", "params": {"text": "item", "list": {"ordered": true, "level": 2}}},
    {"op": "table", "params": {"header_rows": 1, "rows": [
      [{"text": "A"}, {"text": "B"}, {"paragraphs": [{"text": "C"}]}],
      [{"text": "spans A+B", "col_span": 2}, {"text": "c"}],
      [{"text": "tall", "row_span": 2}, {"text": "b"}, {"text": "c"}],
      [{"text": "b"}, {"text": "c"}]
    ]}}
  ]
}
```

- `paragraph.params`: exactly one of `text` (one plain run; `""` makes a
  blank paragraph) or `runs[]` (non-empty); `style` (`Normal`,
  `Heading1`..`Heading6`); `align` (`left`, `center`, `right`, `both`,
  `start`, `end`, `distribute`); `list` (`{ordered, level?=1}`, levels
  1–9). `ordered` is required: `true` numbers the items, `false` bullets
  them.
- run spec: `text` plus `bold/italic/underline/strike/all_caps/small_caps`
  (booleans), `vertical` (`superscript`/`subscript`), `font` (non-empty),
  `size` (points, 1–1638 — Word's cap), `highlight` (an ST_HighlightColor
  name: `yellow`, `green`, `cyan`, `magenta`, `blue`, `red`, `darkBlue`,
  `darkCyan`, `darkGreen`, `darkMagenta`, `darkRed`, `darkYellow`,
  `darkGray`, `lightGray`, `black`, `white`; omit the key for no
  highlight — `"none"` is rejected because the reader normalizes it to
  absent, so it cannot round-trip) — the exact writer surface, so anything the writer fails closed on fails the batch too,
  with the op's address. Two read-back keys are named differently:
  `docx.element/1` reports `strike` as `strikethrough` and `vertical` as
  `vertical_alignment`.
- `link`: exactly one of `href` or `anchor` (non-empty), optional
  `target_frame` (non-empty), and exactly one of `text` or `runs[]`
  (non-empty; links cannot nest).
- `image`: `path` (read relative to the CLI's working directory),
  `content_type` (`image/png`, `image/jpeg`, `image/gif`; inferred from
  the extension when omitted), `alt` (non-blank when present).
- `table.params`: `rows[][]` (non-empty, each row non-empty) of cells
  (exactly one of `text` or non-empty `paragraphs[]`; `col_span` 1–63 —
  Word's column limit; `row_span` from 1 up to the table's remaining rows
  at that cell; default 1 for both);
  `header_rows` (0 to the row count, default 0) marks the first N rows. A
  cell with `col_span` N occupies N grid columns of its row, and a cell
  under a still-open `row_span` is not written at all — as in the example,
  each spanned row lists FEWER cells, and rows must tile the same total
  width, at most 63 columns (ragged or wider tables fail).
## `docx.batch/2` — authoring with comments (`docx batch <output> <script.json>`)

`docx.batch/2` WIDENS `/1`: every `/1` script parses unchanged under
either declaration, and everything above (strict validation, integer
lexemes, character rules, fresh-document-only, atomicity, the op cap)
applies verbatim. The one addition is the `comment` op — declaring
`/2` is required to use it and changes nothing else.

```json
{
  "schema": "docx.batch/2",
  "ops": [
    {"op": "paragraph", "params": {"text": "Findings", "style": "Heading1"}},
    {"op": "comment", "params": {"on": 0, "author": "Reviewer", "initials": "R",
     "date": "2026-07-11T09:30:00Z", "text": "Sharpen this title."}},
    {"op": "paragraph", "params": {"text": "Revenue grew 12%."}},
    {"op": "paragraph", "params": {"text": "Costs fell 3%."}},
    {"op": "comment", "params": {"on": {"from": 2, "to": 3}, "author": "Auditor",
     "paragraphs": [{"text": "Verify both figures,"}, {"text": "then resolve."}]}},
    {"op": "comment", "params": {"reply_to": 4, "author": "Reviewer", "done": true,
     "text": "Both verified; resolving."}}
  ]
}
```

- **`on`** (required unless `reply_to` is given): what the comment
  anchors to, by OP index — a
  single integer or an inclusive, ordered `{"from": i, "to": j}` range.
  Every endpoint must be an EARLIER `paragraph` op: tables cannot carry
  the intra-paragraph anchor markers, comments produce no anchorable
  content of their own, and self/forward references name content that
  does not exist yet — all rejected with the exact `ops[i]` address. A
  range may pass OVER intervening tables (the endpoints bracket them).
- **Body** (required): exactly one of `text` (one plain paragraph) or
  `paragraphs[]` (non-empty; each entry is a `paragraph.params` object).
  Bodies are PLAIN CONTENT: hyperlinks and images are rejected (the
  comments part gets no relationships); run formatting, `style`,
  `align`, and `list` all work.
- **`author`** (required, non-empty), **`initials`** (optional,
  non-empty): attribute-safe strings (no C0 controls).
- **`date`** (optional): a lexical xsd:dateTime —
  `YYYY-MM-DDThh:mm:ss`, optional fractional seconds, optional `Z` or
  `±hh:mm` zone (4-digit year, real calendar day, hours 00–23, zone
  within ±14:00). The value is emitted VERBATIM, never normalized;
  invalid dates fail with the op's address.
- **Ids are dense, in op order**: the first comment op is `w:id` 0, the
  second 1, … — the same ids `docx outline` reports and
  `/comments/comment[@id=N]` addresses after the write. Anchors are
  emitted in the canonical shape (range start after `pPr` in the
  opening paragraph; range end followed by that comment's reference
  run at the close of the ending paragraph), so everything the writer
  anchors reads back exactly through the annotation index — the
  round-trip the SDK gate pins.
- **`reply_to`** (XOR with `on`): the OP index of an EARLIER `comment`
  op this one answers. A reply is ANCHORLESS — its parent's anchor is
  logically its own, so it emits no range or reference markers; the
  linkage lives in `word/commentsExtended.xml` (`w15:paraIdParent`,
  keyed by each comment's LAST body paragraph `w14:paraId`). Chains
  are allowed (a reply may answer a reply). Anchoring `on` a comment
  op is an error that points at `reply_to`.
- **`done`** (optional, boolean, any comment op): the resolution flag
  (`w15:done`). Absent means no resolution record for that comment —
  but note the PART granularity: if ANY comment in the script threads
  or resolves, every comment gets a commentsExtended entry (absent
  `done` then reads back as `done: false`); if none do, the output has
  no commentsExtended part at all and `done` is absent on read-back.
- **Notes** (`/2`, K3): a RUN entry may instead be
  `{"footnote": {...}}` or `{"endnote": {...}}` (exclusive within its
  run object), whose body is `text` | `paragraphs` under the same
  plain-content rules. The run becomes that note's single reference —
  notes may sit in body paragraphs and table cells, but not inside
  hyperlink runs, comment bodies, or other notes. Emitted note ids are
  dense per kind starting at 1 (`/footnotes/note[@id=1]`, …), with the
  separator/continuationSeparator plumbing and the in-note mark run
  handled by the writer.

## `docx.annotate/1` — one comment for an existing document (`docx annotate add`)

The consumed envelope behind `docx annotate add <in> <out> --at <path>
[--to <path>] --json <file>`. Same STRICT discipline as the batch
scripts (duplicate keys and fractional lexemes rejected at the raw
text; unknown keys/types rejected with addressed errors):

```json
{
  "schema": "docx.annotate/1",
  "comment": {
    "author": "Reviewer",
    "initials": "R",
    "date": "2026-07-11T21:00:00Z",
    "paragraphs": [{"text": "First,"}, {"runs": [{"text": "bold.", "bold": true}]}]
  }
}
```

- `paragraphs` uses the SAME plain-content grammar as `docx.batch/2`
  comment bodies — run formatting yes; hyperlinks, images, and notes
  no. Additionally, annotate bodies reject `style` and `list`
  (they would reference style/numbering definitions the EXISTING
  document may not have).
- **Metadata ownership is branch-exclusive**: with `--json`, the
  envelope owns author/initials/date and the `--author`/`--initials`/
  `--date` flags are REJECTED; with `--text`, the flags own them
  (`--author` required) and no envelope exists. No precedence, no
  merging.
- Anchors are CLI flags, never envelope keys: `--at` (required) and
  `--to` (optional, same story, not before `--at`) take BODY-story
  paragraph paths (`/body/p[2]`, `/body/tbl[1]/tr[2]/tc[1]/p[1]`),
  ordinal selectors only.
- The mutation is byte-preserving surgery (the L0 contract): markers
  splice at scanner offsets, the definition into the comments part
  (created + wired only when absent), untouched bytes stay identical;
  ids allocate densely above every id in the document; failures of any
  kind leave ZERO output. Files carrying Word's
  commentsIds/people/commentsExtensible sidecars are refused (this
  tool cannot keep them consistent).
- **Reply** (`docx annotate reply <in> <out> --comment <id> …`) uses
  the SAME two branch-exclusive forms and the same envelope. Replies
  are ANCHORLESS (the parent's anchor is logically theirs) and thread
  via `word/commentsExtended.xml`, keyed by last-body-paragraph
  `w14:paraId` values; documents predating w14 are RETROFITTED (a
  fresh paraId spliced onto the parent's last paragraph, the part
  created and wired). `--comment` takes the comment id `outline`
  shows.
- **Resolve / unresolve** (`docx annotate resolve|unresolve <in> <out>
  --comment <id>`) flip `w15:done`, creating the part and the paraId
  key when absent. After any thread or resolution exists, every
  comment reads back with an explicit `done` value (absent `done`
  means the document has no commentsExtended part at all).
- **Comment ids are JSON STRINGS** everywhere they are read
  (`"id": "0"`, `"parent_id": "0"`): they are XML attribute values,
  spelled as the document spells them. `--comment` takes that spelled
  value (`--comment 0` matches id `"0"`).
- **stdout contract**: success lines are
  `created <path> (N op(s)[, N comment(s)][, N footnote(s)][, N endnote(s)])`
  for `batch` (`ok (dry run): ... , nothing written` under
  `--dry-run`) and `annotated <path> (...)` for the annotate verbs.
  Failures are ONE diagnostic line with exit 1 and NO OUTPUT FILE
  created: `error: ...` for problems with the request or with the
  document's annotation state (scripts, flags, anchors, envelopes,
  sidecar and other refusing-to-annotate gates), `docx: ...` for
  environment refusals and internal errors (existing output paths,
  unreadable inputs, post-splice verification).
  Anchor misses include a corrective detail — the sibling count
  (`'/body/p[9]' does not name a body paragraph (the body has 3
  top-level paragraph(s))`) or the first missing ancestor
  (`'/body/tbl[9]' does not exist`).

## Recipe: the review workflow (read → comment → reply → resolve)

The complete annotation lifecycle on a document you did NOT author,
using only this CLI. Every mutation writes a NEW file (never in
place), fails with zero output, and preserves every byte it does not
explicitly change.

```sh
# 1. ORIENT: what is in the document, and what discussion exists?
docx outline report.docx            # counts + comments inventory (id/author/done/parent_id/anchored_to)
docx text report.docx               # every paragraph with its path

# (Paths are SNAPSHOT-RELATIVE projection paths — re-read them after
# any mutation; they are not stable anchors. Quote them in shells.)
# 2. READ a thread end to end.
docx get report.docx '/comments/comment[@id=0]' --json   # metadata + anchors + children
docx get report.docx '/comments/comment[@id=0]/p[1]'     # a comment body paragraph, as text
docx get report.docx '/body/p[2]' --json                 # .comment_ids lists comments covering a paragraph

# 3. COMMENT on a paragraph (or a --to range) of the existing file.
docx annotate add report.docx r1.docx --at '/body/p[2]' \
  --text 'Cite the source for this figure.' --author 'Reviewer' --initials RV

# 4. REPLY in the thread (anchorless; threads under the parent).
docx annotate reply r1.docx r2.docx --comment 0 \
  --text 'Source added in the appendix.' --author 'Author'

# 5. RESOLVE (or unresolve) the thread.
docx annotate resolve r2.docx r3.docx --comment 0
docx outline r3.docx | jq '[.comments[] | {id, done, parent_id}]'
```

Multi-paragraph or formatted comment bodies use the `--json` envelope
(`docx.annotate/1` above) instead of `--text`; the envelope then owns
ALL metadata. New documents with built-in discussions are authored in
one shot via `docx batch` with `docx.batch/2` `comment` ops
(`reply_to`/`done` included) — see that section.

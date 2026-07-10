# Agent JSON Schemas (xlsx CLI)

This is the normative specification of the versioned JSON payloads the
`cmd/xlsx` CLI exchanges with agents. The executable examples live in
`cmd/xlsx/cram/agent.t`; the snapshot tests in `inspect/*_test.mbt` pin the
exact serialized shapes. If this document and those tests disagree, the tests
are the source of truth and this document has a bug.

## Conventions (all schemas)

- Every payload's first key is `"schema"`, holding an identifier of the form
  `<domain>.<kind>/<major>` (e.g. `xlsx.outline/1`). Identifiers are declared
  once, in `inspect/schema.mbt`.
- **Evolution is additive-only**: new optional keys may appear under an
  existing identifier; keys are never renamed, removed, or retyped. A
  breaking change mints a new identifier with a bumped major. Consumers must
  ignore keys they do not recognize.
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

*Reserved in P0; implemented by the `batch` subcommand (P1).* Envelope:

```json
{
  "schema": "xlsx.batch/1",
  "ops": [
    {"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": "Hello"}}
  ]
}
```

- Op names mirror the CLI subcommands (`set`, `formula`, `style`, `merge`,
  `width`, `freeze`, `filter`, `add-sheet`, `chart`); params are snake_case
  versions of the CLI arguments.
- `set.value` accepts string, number, bool, or null. JSON types are honored:
  a number becomes a numeric cell, a string a text cell (no
  reclassification), a bool a boolean cell, and null clears the cell.
- Validation is strict: a missing/unknown `schema`, an unknown `op`, an
  unknown param key, or a wrong param type fails with an error naming the
  0-based op index, and the file is not touched.
- Application is all-or-nothing: ops apply to the in-memory workbook and the
  file is written (temp file + rename) only after every op succeeds.
- Zero ops is a valid no-op. Scripts are capped at 10,000 ops.
- `--dry-run` parses and applies in memory but never writes.

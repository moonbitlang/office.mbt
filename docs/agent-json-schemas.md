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
  List-valued keys are always present (possibly `[]`).
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
| `charts` | array | `{anchor, width_emu, height_emu, kinds[], series[]}`; `kinds` are DrawingML plot-kind names (e.g. `barChart`), `series` entries are `{name?, categories?, values?}` range refs scanned from the retained chart XML |
| `images` | array | `{anchor, extension, content_type, width_emu, height_emu}` |
| `pivot_tables` | array | `{name}` |
| `counts` | object | `{data_validations, conditional_format_ranges, comments, hyperlinks, slicers}`; conditional-format ranges count space-separated `sqref` entries, not rule blocks |

**`"kind": "chart_sheet"`**: `{kind, name, index, state, charts[]}` where the
single `charts` entry is `{kinds[], series[]}`.

**`"kind": "unknown"`** is reserved for tab entries the reader cannot
classify (should not occur) and keeps `index` aligned with tab order.

## `xlsx.cells/1` — structured range read (`xlsx get <file> <sheet> <range> --json`)

The `<range>` argument accepts a single cell (`B2`) or a range (`A1:C3`,
corner order irrelevant). Ranges are capped at **100,000 cells**; larger
ranges fail with a clean error and no output.

| key | type | notes |
|---|---|---|
| `schema` | string | `"xlsx.cells/1"` |
| `file`, `sheet` | string | echoed |
| `range` | string | **normalized** ref (top-left first; single cell stays a single name) |
| `cells` | array | row-major; one entry per non-absent cell |
| `styles` | object | style id (decimal string) → style object; only ids referenced by `cells` |

A cell appears in `cells` when it has a stored value, a formula, or a style;
fully-absent cells are omitted (absence ⇒ blank and unstyled). Entry keys:

| key | type | notes |
|---|---|---|
| `ref` | string | A1-style |
| `value` | string? | the **formatted display string** (number format applied); present iff the cell stores a value. A formula cell whose result is not cached shows `""` |
| `raw` | object? | `{type, value}` with `type` ∈ `string` \| `number` \| `bool` \| `error`; `value` is the matching JSON type (`error` carries the code as a string) |
| `formula` | string? | stored formula text, without a leading `=` |
| `style_id` | number? | key into `styles` |

Style objects (all keys optional; absent ⇒ property unset):

- `num_fmt_id` (number, builtin format id) / `number_format` (string, custom
  format code)
- `font`: `{bold?, italic?, strike?, underline?, size?, color?, family?}`
- `fill`: `{type?, pattern?, colors?[]}`
- `border`: array of `{side, style?, color?}` (`side` ∈ `left`/`right`/`top`/
  `bottom`/`diagonal…`)
- `alignment`: `{horizontal?, vertical?, wrap_text?, text_rotation?, indent?,
  shrink_to_fit?}`
- `protection`: `{hidden?, locked?}`

Colors are the workbook's stored hex strings (typically `RRGGBB` or
`AARRGGBB`), passed through unvalidated — consumers rendering them must
validate.

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

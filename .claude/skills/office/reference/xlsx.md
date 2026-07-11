# Reference: `cmd/xlsx`

Invoke every command as:

```
moon run --target wasm cmd/xlsx -- <command> [args...]
```

from the repository root (`--target native` is a faster drop-in for trusted
files; a prebuilt `.wasm` also runs standalone via `moonrun` — see SKILL.md).
When unsure of a command's exact arguments, ask the tool itself:
`moon run --target wasm cmd/xlsx -- <command> --help`.

## Conventions (apply to every command)

- **`<file>` is modified in place.** `set`, `formula`, `style`, `merge`,
  `width`, `freeze`, `filter`, `add-sheet`, `chart` open `<file>`, change it,
  and overwrite it. `create` and `csv` instead take an `<output>` path and
  write a new file. Read-only commands (`get`, `outline`, `html`, `calc`,
  `sheets`, `rows`, `view`, `validate`) never modify the file.
- **`<cell>`** is an A1-style reference: a column letter(s) then a row number,
  e.g. `A1`, `B2`, `AA10`. Columns and rows are 1-based.
- **`<range>`** is `<cell>:<cell>`, e.g. `A1:C10`.
- **`<sheet>`** is a sheet name, matched **case-insensitively** (`data` finds
  `Data`); the original case is preserved for display. `--sheet` defaults to
  `Sheet1` for `create`/`csv` and to the first sheet for readers.
- **On success, mutating commands** (`create`, `csv`, `set`, `formula`,
  `style`, `merge`, `width`, `freeze`, `filter`, `add-sheet`, `chart`) print
  one confirmation line and exit `0` — the exact line is in the command table
  below; match it, don't assume. **Read commands** (`get`, `outline`, `html`,
  `calc`, `sheets`, `rows`, `view`, `validate`) print their data/result
  instead, which may be multiple lines.
- **Failure** prints one diagnostic line and exits **non-zero**. `cmd/xlsx`
  diagnostics start with `error:`. Because the wasm backend has no stderr, the
  diagnostic arrives on stdout — so **check the exit code**, not just output.
- Values passed on the shell command line: quote anything with spaces or shell
  metacharacters. In particular a `$`-containing number format must be
  **single-quoted** (`'$#,##0.00'`) or the shell expands `$#`.

## Commands

| Command | Purpose | Success output |
| --- | --- | --- |
| `create <output> [--sheet NAME]` | New empty workbook | `created <output> (sheet <NAME>)` |
| `csv <input> <output> [--sheet NAME]` | Import a CSV into a new workbook | `imported <N> row(s) into <output> (sheet <NAME>)` |
| `set <file> <sheet> <cell> <value>` | Set one cell's value | `set <sheet>!<cell> = <value>` |
| `formula <file> <sheet> <cell> <expr>` | Set a cell's formula | `set <sheet>!<cell> = =<expr>` |
| `calc <file> <sheet> <cell> [--raw]` | Evaluate a cell's formula | the computed value |
| `style <file> <sheet> <cell-or-range> [flags]` | Apply a cell style | `styled <N> cell(s) in <sheet>!<target>` |
| `merge <file> <sheet> <range>` | Merge a cell range | `merged <sheet>!<range>` |
| `width <file> <sheet> <col-or-range> <width>` | Set column width | `set width of <sheet>!<target> to <width>` |
| `freeze <file> <sheet> <cell>` | Freeze panes above/left of a cell | `froze panes above and left of <sheet>!<cell>` |
| `filter <file> <sheet> <range>` | Add an auto-filter | `added auto-filter to <sheet>!<range>` |
| `add-sheet <file> <name>` | Add a sheet to an existing workbook | `added sheet <name>` |
| `chart <file> <sheet> <anchor> [--type … --categories … --values … --title … --name …]` | Add a chart from a data range | `added <type> chart to <sheet>!<anchor>` |
| `batch <file> <script.json> [--dry-run]` | Apply a JSON op script in one save | `applied <N> op(s) to <file>` |
| `get <file> <sheet> <cell>` | Print a cell's stored value | the value, or its formula text |
| `get <file> <sheet> <cell-or-range> --json` | Structured read of a cell/range | an `xlsx.cells/1` JSON payload |
| `outline <file>` | Workbook structure map | an `xlsx.outline/1` JSON payload |
| `html <file> [--sheet --out --max-rows --max-cols --no-images --calc]` | Render sheets as HTML | a self-contained document (or `wrote <out>`) |
| `sheets <file>` | List sheet names | one name per line |
| `rows <file> [--sheet NAME]` | Dump a sheet as CSV | RFC 4180 CSV |
| `view <file> [--sheet NAME]` | Render a sheet as a table | an ASCII table |
| `validate <file>` | Check OOXML structure | `valid`, or one problem per line |

## Command details

### Writing cells

- **`set`** stores a *plain, canonical* number (`42`, `-3.5`, `9.99`) as a real
  numeric cell — so formulas over it evaluate and number formats render.
  Anything else stays **text**: leading zeros (`007`), a leading `+`, exponent
  forms (`1e3`), thousands separators (`1,000`), non-numbers. No date inference.
- **`formula`** stores the expression; a leading `=` is optional. The result is
  **not cached** in the file — Excel computes it on open, and `get`/`rows`/`view`
  show a formula cell as its formula text / blank. Use **`calc`** to compute it
  here.

### Reading formula results — `get` vs `calc`

- **`get`** returns the cell's *stored* content: a value cell → its value; a
  formula cell → the formula text (`=SUM(A1:A2)`); an empty cell → empty.
- **`calc`** *evaluates* a formula and prints the computed result (a value cell
  just returns its value). Supports arithmetic, cell/range references, and
  functions such as `SUM`, `AVERAGE`, `IF`. **Formatting:** by default `calc`
  applies the cell's number format; a cell with **no** format (General) prints
  the full-precision value — identical to `--raw` — so a decimal sum can show
  floating-point noise (`9.99+19.99` → `29.979999999999997`). Give the formula
  cell a number format (`style … --number-format "0.00"`) for a clean rounded
  result (`29.98`); `--raw` always prints the unformatted value.

### Formatting and layout

- **`style <cell-or-range>`** builds a style from flags and applies it to every
  cell in the target. Flags: `--number-format "CODE"` (an Excel format code,
  stored verbatim — `"#,##0.00"`, `"0%"`; single-quote a `$` code:
  `'$#,##0.00'`), `--bold`, `--italic`, `--fill HEXRGB` (solid fill, e.g.
  `FFFF00`), `--font-color HEXRGB` (text color, e.g. `FFFFFF` for white — pair
  with a dark `--fill` for a header band), `--align left|center|right`. Number
  formats render only on numeric cells. Each call sets the target's **complete**
  style (it *replaces*, not merges) — put all of a cell's formatting in one
  command and don't overlap styled ranges. A range over 100000 cells is
  rejected.
- **`merge <range>`** merges the range into one cell; the top-left cell's value
  is kept.
- **`width <col-or-range> <width>`** sets a column width in character units. The
  column is a letter (`C`) or a letter range (`A:C`). `<width>` is a number.
- **`freeze <cell>`** freezes every row above and every column left of `<cell>`;
  `<cell>` becomes the first scrollable cell. So `freeze f Sheet1 A2` freezes
  the header row; `B2` freezes row 1 and column A.

### Sheets

- **`add-sheet <name>`** appends a new empty sheet to an existing workbook
  (`create`/`csv` only make new files, each with one sheet).
- **`sheets`** lists names; use a name (case-insensitive) as the `<sheet>`
  argument to other commands.

### Charts

- **`chart <anchor>`** adds a chart whose top-left corner sits at `<anchor>`
  (e.g. `E2`). Options:
  - `--type` — `col` (vertical bars, the default), `bar` (horizontal), `line`,
    `pie`, `area`, `scatter`, `doughnut`, `radar`. An unknown type is a clean
    `error:`.
  - `--categories <range>` — the axis labels. A column (`A2:A6`) or a single
    row (`C1:F1`) both work — a horizontal range is handy for a radar over
    stat-name headers. Required.
  - `--values <range>` — the series data (`B2:B6`, or a row `C6:F6`). Required.
  - `--name <text>` — the series' legend label. A plain string is used
    literally (`--name Revenue`); to pull the label from a cell, pass a
    sheet-qualified reference (`--name Sheet1!B1`) — a bare `B1` is treated as
    literal text, not a cell.
  - `--title <text>` — chart title.
  Ranges are single-sheet: pass a plain `A2:A6` and it's read from `<sheet>`;
  to point at another sheet, qualify it yourself (`Other!A2:A6`). One `chart`
  call adds **one series**; run it again to add more charts. The data cells must
  already exist — add the chart after the data.

  **Size and placement.** Each chart is a fixed footprint of ~7 columns wide ×
  14 rows tall from its anchor (there is no size flag). To stack several charts
  on one sheet without silent overlap, space their anchors by ≥15 rows (e.g.
  `H2`, `H18`, `H34`) or ≥8 columns. `outline` reads a chart's kind and series
  ranges back; confirm the file with `validate`.

### Batch edits (`batch`)

`batch <file> <script.json>` applies many edits in **one open → apply →
save cycle** — the way to build or restyle a sheet without N separate
open/write round-trips. The script is versioned JSON
(`"schema": "xlsx.batch/1"`); ops mirror the subcommands, with snake_case
params:

| op | params |
| --- | --- |
| `set` | `sheet`, `cell`, `value` (string/number/bool/null — JSON types are honored: a number becomes a numeric cell, a string stays text, null clears) |
| `formula` | `sheet`, `cell`, `formula` (leading `=` optional) |
| `style` | `sheet`, `range`, `bold?`, `italic?`, `number_format?`, `fill?`, `font_color?`, `align?` |
| `merge` | `sheet`, `range` |
| `width` | `sheet`, `column` (`A` or `A:C`), `width` (number) |
| `freeze` | `sheet`, `cell` |
| `filter` | `sheet`, `range` |
| `add-sheet` | `name` |
| `chart` | `sheet`, `anchor`, `categories`, `values`, `type?`, `name?`, `title?` |

Application is **all-or-nothing**: a parse error or a failing op leaves the
file untouched (a failing op reports `error: op <i> (<name>): …; <file> not
modified` with a 0-based index and exit 1), and the final save writes a
uniquely-named temp file through an exclusive handle, then renames it over
the (symlink-resolved) target — on POSIX the saved file is created
owner-only (0600; Windows follows directory ACLs); chmod afterwards if
others need to read it. `--dry-run` parses and
applies in memory, writes nothing, and prints
`dry-run ok: <N> op(s); <file> not modified`. Zero ops is a valid no-op and
writes nothing. Every reference is validated strictly at parse time (`cell`
params take a single in-grid cell, `range` params a range; malformed or
out-of-grid references fail up front — the `style` subcommand, by contrast,
passes a bare cell name through untouched). Numbers follow standard
JSON/IEEE-double semantics; non-finite values (`1e309`) and numeric
literals over 40 characters are rejected. Scripts are capped at 10,000
ops and 1,000,000 aggregate style-expanded cells. Full grammar:
`docs/agent-json-schemas.md`; runnable examples: `cmd/xlsx/cram/agent.t`.

### Visual rendering (`html`)

`html <file>` renders sheets to one self-contained HTML document — the
"look" half of a render → look → fix loop. Open it in a browser or read it
directly. What renders: formatted cell values, fonts/fills/alignments/
borders as CSS classes (one per style id), merged cells as row/col spans,
column widths and row heights, embedded images as `data:` URIs, chart
placeholders (kind + series ranges — no chart drawing), and a frozen-pane
note. Fidelity limits: theme/indexed colors and gradient fills are omitted
(never guessed); only literal hex colors render.

- Each sheet is bounded to `--max-rows` (1000) × `--max-cols` (256) plus a
  hard per-sheet cell ceiling; a visible marker reports truncation.
- A formula with no cached result renders as its text, styled as pending;
  `--calc` evaluates such formulas instead.
- `--sheet NAME` (case-insensitive) renders one sheet; `--out FILE` writes
  the document instead of stdout; `--no-images` skips image embedding.
- Untrusted-file safe: all workbook text is HTML-escaped and colors are
  strictly validated before entering the stylesheet.
- `--out` is written atomically (temp + rename) and never truncates the
  input; a symlink/hard-link at the `--out` leaf replaces that entry, not
  its target. One residual: an adversary who swaps an *intermediate*
  directory component of `--out` mid-write could redirect it — closing
  that needs handle-relative `openat`/`renameat`, which the async fs
  library does not expose. It grants no capability the adversary's
  directory write access doesn't already give, so it is out of scope.

### Structured JSON reads (`outline`, `get --json`)

These two commands are the machine-readable inspection surface; prefer them
when a program (or an agent) consumes the output. Payloads are versioned —
`"schema": "xlsx.outline/1"` / `"xlsx.cells/1"` — and evolve additively only;
the normative field-by-field spec is `docs/agent-json-schemas.md`, and
`cmd/xlsx/cram/agent.t` shows complete real outputs.

- **`outline <file>`** maps the workbook before you edit it: every sheet (in
  tab order, with `kind` `worksheet`/`chart_sheet` and `state`
  `visible`/`hidden`/`very_hidden`), live extents (`used_range`, `max_row`,
  `max_col` — trust these over `declared_dimension`, which is the file's
  retained value and may be stale), merges, tables, charts (kinds + series
  ranges), images, pivot tables, defined names, and per-sheet counts of
  validations/conditional formats/comments/hyperlinks/slicers.
- **`get <file> <sheet> <cell-or-range> --json`** reads a cell or range
  structurally: per cell a formatted display `value`, typed `raw` value
  (`string`/`number`/`bool`/`error`), `formula` text, and `style_id` into a
  deduplicated `styles` map (`style_id` is the effective style: cell, else
  row, else column). A styled blank appears as `{ref, style_id}` and an
  uncached formula as `{ref, formula, …}` — no fake empty `value` (font/fill/border/alignment/
  number format). Blank unstyled cells are omitted. Ranges accept either
  corner order and are capped at 100,000 cells.

### Reading whole sheets

- **`rows`** dumps a sheet as CSV; **`view`** renders it as an ASCII table with
  the first row as the header. Both show a cell as Excel would *display* it: a
  `--number-format`'d value shows its formatted text; a formula cell shows blank
  when unformatted, but shows the **format code literally** (e.g. `$#,##0`) if it
  carries a number format — because a formula has no cached value to format. So
  to read a total, use `calc`, not `rows`/`view`. `csv` → `rows` round-trips
  text/empty/quoted structure exactly, but a numeric field round-trips by
  *value* not spelling (`1.0` → `1`, `0.50` → `0.5`) — read a raw value with
  `get`.
- **`validate`** checks the file's own bytes (not a re-serialized copy); prints
  exactly `valid`, or one structural problem per line.

## Choosing a command

- Turn a table/CSV into a spreadsheet → `csv`. Build one from scratch → `create`
  then `set`/`formula`.
- Read a cell's stored value or formula text → `get`. Read a formula's *computed
  result* → `calc`.
- See what's in an unfamiliar workbook before editing → `outline`. Read
  values + styles + formulas programmatically → `get … --json`.
- Read a whole sheet as data → `rows` (CSV). Eyeball a sheet in the
  terminal → `view`; see it with real formatting → `html`.
- Make a data dump look like a real report → `style` (bold header, number
  formats), `width`, `freeze` (header row), `filter` — or all of it in one
  `batch` script.
- Visualize data → `chart` (a `col`/`bar`/`line`/`pie`/`radar` over a
  categories range + a values range).

## Worked example: a formatted report

```
moon run --target wasm cmd/xlsx -- csv sales.csv sales.xlsx --sheet Q1
moon run --target wasm cmd/xlsx -- formula sales.xlsx Q1 B5 "=SUM(B2:B4)"
moon run --target wasm cmd/xlsx -- style sales.xlsx Q1 A1:C1 --bold --fill DDDDDD
moon run --target wasm cmd/xlsx -- style sales.xlsx Q1 B2:B5 --number-format '$#,##0.00'
moon run --target wasm cmd/xlsx -- width sales.xlsx Q1 A:C 16
moon run --target wasm cmd/xlsx -- freeze sales.xlsx Q1 A2
moon run --target wasm cmd/xlsx -- filter sales.xlsx Q1 A1:C4
moon run --target wasm cmd/xlsx -- calc sales.xlsx Q1 B5        # the computed total
moon run --target wasm cmd/xlsx -- validate sales.xlsx          # -> valid
```

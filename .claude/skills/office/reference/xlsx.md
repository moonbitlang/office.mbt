# Reference: `cmd/xlsx`

Run as `moon run --target wasm cmd/xlsx -- <command> [args]` from the repo root.
Confirm anything here with `moon run --target wasm cmd/xlsx -- <command> --help`.

| Command | Purpose |
| --- | --- |
| `create <output.xlsx> [--sheet NAME]` | Create a new empty workbook (default sheet `Sheet1`) |
| `csv <input.csv> <output.xlsx> [--sheet NAME]` | Import a CSV file into a new workbook |
| `set <file> <sheet> <cell> <value>` | Set one cell and save the file in place |
| `formula <file> <sheet> <cell> <expr>` | Set a cell formula (leading `=` optional) |
| `style <file> <sheet> <cell-or-range> [flags]` | Apply a style to a cell or range |
| `merge <file> <sheet> <range>` | Merge a cell range (e.g. `A1:B2`) |
| `get <file> <sheet> <cell>` | Print a cell's value (or its formula, if unevaluated) |
| `calc <file> <sheet> <cell> [--raw]` | Evaluate a cell's formula and print the computed result |
| `sheets <file>` | List sheet names, one per line |
| `rows <file> [--sheet NAME]` | Dump a sheet as RFC 4180 CSV |
| `view <file> [--sheet NAME]` | Render a sheet as an ASCII table (first row = header) |
| `validate <file>` | Report OOXML structure problems; prints `valid` if clean |

## Behavior and quirks

- **Cell references** are A1-style (`A1`, `B2`, …).
- **Sheet names** are matched case-insensitively; their original case is kept
  for display. `--sheet` defaults to the first sheet for readers, `Sheet1` for
  `create`/`csv`.
- **Numbers are stored as numbers.** `set` and `csv` write a *plain, canonical*
  number (`42`, `-3.5`, `9.99`) as a real numeric cell, so formulas over it
  evaluate and number formats render in Excel. Anything ambiguous stays text:
  leading zeros (`007`), a leading `+`, exponent forms (`1e3`), thousands
  separators (`1,000`), and non-numbers. There is no date/formula inference —
  use `formula` for formulas.
- **`csv` → `rows` preserves structure and values, but not every spelling.**
  `csv` parses RFC 4180 (quoted fields, `""` escapes, embedded commas/newlines,
  `LF`/`CRLF`, a leading BOM) and writes every field including empty ones, so the
  round trip preserves comma-bearing quoted fields, empty cells, and text
  exactly. `rows` quotes any field containing a comma, quote, CR, or LF. Two
  things that do *not* round-trip verbatim: (1) a numeric field round-trips by
  *value*, not spelling — since it's stored as a number, `1.0` comes back as `1`,
  `0.50` as `0.5`, `-0` as `0` (use a leading-zero/`+`/etc. form to keep an exact
  string as text); (2) `rows`/`view` show a cell as Excel would *display* it, so a
  cell with a `--number-format` shows its formatted text (e.g. `$9.99`) — read the
  raw value with `get`, and avoid number-formatting data you intend to
  re-export.
- **`formula`** stores the expression (leading `=` optional). It is not
  *cached* in the file — Excel recomputes on open, and `rows`/`view` show a
  formula cell as blank — but `calc` evaluates it on demand (see below). `get`
  on a formula cell falls back to printing the formula text (`=SUM(...)`).
- **`calc`** evaluates a cell's formula with the built-in engine and prints the
  computed result (a plain cell just returns its value). Supports arithmetic,
  cell/range references, and functions like `SUM`, `AVERAGE`, `IF`. By default
  it applies the cell's number format — but a cell with **no** format (General)
  prints the full-precision value, identical to `--raw`, so a sum of decimals
  can show floating-point noise (e.g. `29.979999999999997` for `9.99+19.99`).
  For a clean rounded display, give the formula cell a number format first
  (`style … C4 --number-format "0.00"` → `calc` prints `29.98`). `--raw` always
  prints the unformatted value.
- **`style`** builds a style from flags and applies it to every cell in the
  target cell or `A1:B2` range: `--number-format "CODE"` (an Excel format code,
  stored verbatim — e.g. `"#,##0.00"`, `"0%"`; for a `$` currency code use
  single quotes so the shell doesn't expand it: `--number-format '$#,##0.00'`),
  `--bold`,
  `--italic`, `--fill HEXRGB` (solid fill, e.g. `FFFF00`),
  `--align left|center|right`. Number formats only render on numeric cells (see
  above). A range wider than 100000 cells is rejected.
  Each `style` call sets the target's **complete** style — it *replaces* any
  prior style on those cells rather than merging — so put all the formatting a
  cell needs into one command, and avoid overlapping styled ranges.
- **`merge`** merges a range (`A1:B2`); the top-left cell's value is kept.
- **`validate` checks the file's own bytes**, not a re-serialized copy, so it
  reports defects even in a package this reader would otherwise tolerate. A
  clean file prints exactly `valid`; otherwise one problem per line.
- **Errors** print a single `error: …` line and exit non-zero.

## Examples

```
# data -> spreadsheet, then confirm
moon run --target wasm cmd/xlsx -- csv report.csv report.xlsx --sheet Data
moon run --target wasm cmd/xlsx -- view report.xlsx
moon run --target wasm cmd/xlsx -- validate report.xlsx

# build a workbook cell by cell
moon run --target wasm cmd/xlsx -- create book.xlsx --sheet Summary
moon run --target wasm cmd/xlsx -- set book.xlsx Summary A1 Total
moon run --target wasm cmd/xlsx -- set book.xlsx Summary B1 42
moon run --target wasm cmd/xlsx -- get book.xlsx Summary B1        # -> 42

# inspect an existing (possibly untrusted) workbook
moon run --target wasm cmd/xlsx -- sheets incoming.xlsx
moon run --target wasm cmd/xlsx -- rows incoming.xlsx > incoming.csv
```

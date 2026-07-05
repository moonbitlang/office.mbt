# Reference: `cmd/xlsx`

Run as `moon run --target wasm cmd/xlsx -- <command> [args]` from the repo root.
Confirm anything here with `moon run --target wasm cmd/xlsx -- <command> --help`.

| Command | Purpose |
| --- | --- |
| `create <output.xlsx> [--sheet NAME]` | Create a new empty workbook (default sheet `Sheet1`) |
| `csv <input.csv> <output.xlsx> [--sheet NAME]` | Import a CSV file into a new workbook |
| `set <file> <sheet> <cell> <value>` | Set one cell and save the file in place |
| `get <file> <sheet> <cell>` | Print a single cell's value |
| `sheets <file>` | List sheet names, one per line |
| `rows <file> [--sheet NAME]` | Dump a sheet as RFC 4180 CSV |
| `view <file> [--sheet NAME]` | Render a sheet as an ASCII table (first row = header) |
| `validate <file>` | Report OOXML structure problems; prints `valid` if clean |

## Behavior and quirks

- **Cell references** are A1-style (`A1`, `B2`, …).
- **Sheet names** are matched case-insensitively; their original case is kept
  for display. `--sheet` defaults to the first sheet for readers, `Sheet1` for
  `create`/`csv`.
- **Values are stored as text.** `set` and `csv` do not infer numbers, dates,
  or formulas — a cell set to `42` is the string "42". Downstream numeric use
  may need explicit typing (not currently exposed by the CLI).
- **`csv` and `rows` are inverses.** `csv` parses RFC 4180 (quoted fields, `""`
  escapes, embedded commas/newlines, `LF`/`CRLF`, a leading BOM) and writes
  every field including empty ones, so a `csv` → `rows` round-trip preserves
  both comma-bearing quoted fields and empty cells. `rows` quotes any field
  containing a comma, quote, CR, or LF.
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

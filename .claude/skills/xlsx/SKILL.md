---
name: xlsx
description: >-
  Create, read, inspect, validate, and CSV-import Excel .xlsx spreadsheets by
  running the in-repo mbtexcel CLI on the WebAssembly backend — a memory-safe,
  dependency-free sandbox. Use this whenever the user wants to generate a
  spreadsheet, turn CSV/table data into an .xlsx, read or dump cells from an
  existing workbook, or check that an .xlsx is structurally valid, without a
  native Excel library (openpyxl, ExcelJS, LibreOffice, etc.).
---

# xlsx — spreadsheets via the WebAssembly sandbox

This skill drives the `cmd/xlsx` CLI compiled to **WebAssembly** and executed by
MoonBit's own wasm runtime. The document parsing and generation happen inside
the wasm sandbox: the module is memory-safe and cannot execute other programs
or open network connections — its only effects are reading/writing files and
printing to stdout. That contains the main risks of parsing a **malformed or
hostile** `.xlsx` (no memory-corruption, no native code execution, no
exfiltration). Normal precautions still apply: a crafted file can still consume
CPU or memory, and the tool reads/writes whatever paths you pass it, so run it
on files you can afford it to touch.

## How to run

From the repository root:

```
moon run --target wasm cmd/xlsx -- <command> [args]
```

Everything after `--` is passed to the CLI. File paths are relative to the
current directory. The first run builds the wasm module (a few seconds);
later runs are fast. For trusted files where speed matters, `--target native`
is a drop-in faster alternative.

## Commands

| Command | Purpose |
| --- | --- |
| `create <output.xlsx> [--sheet NAME]` | Create a new empty workbook |
| `csv <input.csv> <output.xlsx> [--sheet NAME]` | Import a CSV file into a new workbook |
| `set <file> <sheet> <cell> <value>` | Set one cell and save in place |
| `get <file> <sheet> <cell>` | Print a single cell's value |
| `sheets <file>` | List sheet names |
| `rows <file> [--sheet NAME]` | Dump a sheet as CSV (RFC 4180) |
| `view <file> [--sheet NAME]` | Render a sheet as an ASCII table |
| `validate <file>` | Report OOXML structure problems (prints `valid` if clean) |

`csv` and `rows` are inverses: `rows` exports RFC 4180 CSV (quoting fields that
contain commas, quotes, or CR/LF), and `csv` parses the same format back
(quoted fields, `""` escapes, embedded commas/newlines, `LF`/`CRLF`, optional
BOM).

## Examples

Turn a CSV of data into a spreadsheet, then confirm it:

```
moon run --target wasm cmd/xlsx -- csv report.csv report.xlsx --sheet Data
moon run --target wasm cmd/xlsx -- view report.xlsx
moon run --target wasm cmd/xlsx -- validate report.xlsx
```

Build a workbook cell by cell:

```
moon run --target wasm cmd/xlsx -- create book.xlsx --sheet Summary
moon run --target wasm cmd/xlsx -- set book.xlsx Summary A1 Total
moon run --target wasm cmd/xlsx -- set book.xlsx Summary B1 42
moon run --target wasm cmd/xlsx -- get book.xlsx Summary B1     # -> 42
```

Inspect an existing (possibly untrusted) workbook:

```
moon run --target wasm cmd/xlsx -- sheets incoming.xlsx
moon run --target wasm cmd/xlsx -- rows incoming.xlsx --sheet Sheet1 > out.csv
```

## Notes

- Cell references are A1-style (`A1`, `B2`, …). Sheet names are matched
  case-insensitively, though their original case is preserved for display.
- `set` and `csv` store every value as text — the tool does not infer numbers,
  dates, or formulas. Downstream numeric use may need explicit typing.
- A non-zero exit and an `error: …` line on stdout signal failure (the wasm
  backend has no stderr). `validate` prints one problem per line, or `valid`.
- To generate a spreadsheet from data you already have in the conversation,
  write it to a `.csv` first, then use `csv`.

The agent-oriented read surface: `outline` prints a workbook structure map
and `get --json` prints a structured range read. Both payloads are versioned
JSON (see docs/agent-json-schemas.md); this file is their executable
documentation and runs in a fresh temporary directory.

Build a small workbook with a styled header, a formula, and a chart:

  $ xlsx.exe create book.xlsx --sheet Data
  created book.xlsx (sheet Data)
  $ xlsx.exe set book.xlsx Data A1 Region
  set Data!A1 = Region
  $ xlsx.exe set book.xlsx Data B1 100
  set Data!B1 = 100
  $ xlsx.exe formula book.xlsx Data B2 "=B1*2"
  set Data!B2 = =B1*2
  $ xlsx.exe style book.xlsx Data A1 --bold --fill 4472C4 --font-color FFFFFF
  styled 1 cell(s) in Data!A1
  $ xlsx.exe chart book.xlsx Data D2 --categories A1:A1 --values B1:B1 --name Sales
  added col chart to Data!D2

`outline` maps the workbook: sheets in tab order with live extents
(`used_range` is authoritative; `declared_dimension` is the file's retained
value and may be stale), plus per-sheet inventories of merges, tables,
charts, images, and object counts:

  $ xlsx.exe outline book.xlsx
  {
    "schema": "xlsx.outline/1",
    "file": "book.xlsx",
    "sheet_count": 1,
    "active_sheet": {
      "name": "Data",
      "index": 0
    },
    "defined_names": [],
    "sheets": [
      {
        "kind": "worksheet",
        "name": "Data",
        "index": 0,
        "state": "visible",
        "declared_dimension": "A1:A1",
        "max_row": 2,
        "max_col": 2,
        "used_range": "A1:B2",
        "merges": [],
        "tables": [],
        "charts": [
          {
            "anchor": "D2",
            "width_emu": 4572000,
            "height_emu": 2476500,
            "kinds": [
              "barChart"
            ],
            "series": [
              {
                "categories": "'Data'!A1:A1",
                "values": "'Data'!B1:B1"
              }
            ]
          }
        ],
        "images": [],
        "pivot_tables": [],
        "counts": {
          "data_validations": 0,
          "conditional_format_ranges": 0,
          "comments": 0,
          "hyperlinks": 0,
          "slicers": 0
        }
      }
    ]
  }

`get --json` reads a cell or range structurally: formatted display value,
typed raw value, formula text, and a deduplicated style map. Blank unstyled
cells (A2 here) are omitted — absence means blank — a plain cell carries no
style_id, and a formula with no cached result carries only its formula
text, no fake empty value:

  $ xlsx.exe get book.xlsx Data A1:B2 --json
  {
    "schema": "xlsx.cells/1",
    "file": "book.xlsx",
    "sheet": "Data",
    "range": "A1:B2",
    "cells": [
      {
        "ref": "A1",
        "value": "Region",
        "raw": {
          "type": "string",
          "value": "Region"
        },
        "style_id": 1
      },
      {
        "ref": "B1",
        "value": "100",
        "raw": {
          "type": "number",
          "value": 100
        }
      },
      {
        "ref": "B2",
        "formula": "B1*2"
      }
    ],
    "styles": {
      "1": {
        "font": {
          "bold": true,
          "size": 11,
          "color": "FFFFFF",
          "family": "Calibri"
        },
        "fill": {
          "type": "pattern",
          "pattern": 1,
          "colors": [
            "4472C4"
          ]
        }
      }
    }
  }

Corner order is normalized, and a single cell echoes a single-cell range:

  $ xlsx.exe get book.xlsx Data B1 --json | head -5
  {
    "schema": "xlsx.cells/1",
    "file": "book.xlsx",
    "sheet": "Data",
    "range": "B1",

Without `--json`, `get` behaves exactly as before:

  $ xlsx.exe get book.xlsx Data A1
  Region

Errors are strict and leave no partial output — an oversized range (the cap
is 100,000 cells), a missing sheet, and a missing file all fail with exit 1:

  $ xlsx.exe get book.xlsx Data A1:K9091 --json
  error: range A1:K9091 covers 100001 cells; max is 100000
  [1]
  $ xlsx.exe get book.xlsx Missing A1 --json
  error: * (glob)
  [1]
  $ xlsx.exe outline missing.xlsx
  error: * (glob)
  [1]

The workbook the agent commands read stays a valid OOXML package:

  $ xlsx.exe validate book.xlsx
  valid

`batch` applies an xlsx.batch/1 op script in one open -> apply -> save
cycle (ops mirror the subcommands; JSON value types are honored). It is
all-or-nothing: `--dry-run` writes nothing, a failing op names its 0-based
index and leaves the file untouched, and the final save goes through a
temp file + rename:

  $ cat > report.json <<'JSON'
  > {
  >   "schema": "xlsx.batch/1",
  >   "ops": [
  >     {"op": "set", "params": {"sheet": "Data", "cell": "D1", "value": "Qty"}},
  >     {"op": "set", "params": {"sheet": "Data", "cell": "D2", "value": 7.5}},
  >     {"op": "formula", "params": {"sheet": "Data", "cell": "D3", "formula": "=D2*2"}},
  >     {"op": "style", "params": {"sheet": "Data", "range": "D1", "bold": true, "align": "center"}},
  >     {"op": "merge", "params": {"sheet": "Data", "range": "A5:B5"}},
  >     {"op": "width", "params": {"sheet": "Data", "column": "D", "width": 12}},
  >     {"op": "add-sheet", "params": {"name": "Notes"}}
  >   ]
  > }
  > JSON
  $ xlsx.exe batch book.xlsx report.json --dry-run
  dry-run ok: 7 op(s); book.xlsx not modified
  $ xlsx.exe batch book.xlsx report.json
  applied 7 op(s) to book.xlsx
  $ xlsx.exe get book.xlsx Data D2
  7.5
  $ xlsx.exe calc book.xlsx Data D3
  15
  $ xlsx.exe sheets book.xlsx
  Data
  Notes
  $ xlsx.exe validate book.xlsx
  valid

A failing op reports its index and op name, and the file is not written —
E9 stays empty even though the first op set it:

  $ cat > bad.json <<'JSON'
  > {"schema": "xlsx.batch/1", "ops": [
  >   {"op": "set", "params": {"sheet": "Data", "cell": "E9", "value": "x"}},
  >   {"op": "merge", "params": {"sheet": "Missing", "range": "A1:B1"}}
  > ]}
  > JSON
  $ xlsx.exe batch book.xlsx bad.json
  error: op 1 (merge): * (glob)
  [1]
  $ test "$(xlsx.exe get book.xlsx Data E9)" = ""

Validation is strict — unknown params fail with the op's index, and a
wrong schema string is rejected up front:

  $ cat > typo.json <<'JSON'
  > {"schema": "xlsx.batch/1", "ops": [
  >   {"op": "style", "params": {"sheet": "Data", "range": "A1", "colour": "FF0000"}}
  > ]}
  > JSON
  $ xlsx.exe batch book.xlsx typo.json
  error: op 0 (style): unknown param 'colour'
  [1]
  $ cat > wrong.json <<'JSON'
  > {"schema": "xlsx.batch/9", "ops": []}
  > JSON
  $ xlsx.exe batch book.xlsx wrong.json
  error: unsupported schema 'xlsx.batch/9' (expected xlsx.batch/1)
  [1]


`html` renders sheets to one self-contained document — the "look" half of
the agent's render -> look -> fix loop. Structure checks (the document is
large, so grep, not full literals):

  $ xlsx.exe html book.xlsx --out book.html
  wrote book.html
  $ head -2 book.html
  <!DOCTYPE html>
  <html>
  $ grep -c '<section data-sheet=' book.html
  2
  $ grep -c 'class="s[0-9]' book.html | head -1
  1
  $ xlsx.exe html book.xlsx --sheet Data | grep -c 'data-sheet="Data"'
  1

A formula with no cached result is visibly pending by default and
evaluates under --calc:

  $ xlsx.exe html book.xlsx --sheet Data | grep -o 'class="formula-pending">=D2\*2</td>'
  class="formula-pending">=D2*2</td>
  $ xlsx.exe html book.xlsx --sheet Data --calc | grep -o '<td>15</td>'
  <td>15</td>

Errors are the CLI's usual one-liners:

  $ xlsx.exe html book.xlsx --sheet Missing
  error: sheet 'Missing' not found
  [1]
  $ xlsx.exe html book.xlsx --max-rows zero
  error: invalid --max-rows 'zero' (expected a number)
  [1]

`html` is read-only — writing the document over the input workbook is
refused:

  $ xlsx.exe html book.xlsx --out book.xlsx
  error: --out must not be the input workbook
  [1]
  $ xlsx.exe html book.xlsx --out ./book.xlsx
  error: --out must not be the input workbook
  [1]

A hard link the guard cannot detect is still safe: the rename replaces
the --out entry, and the workbook keeps its bytes.

  $ ln book.xlsx alias.xlsx
  $ xlsx.exe validate book.xlsx
  valid
  $ xlsx.exe html book.xlsx --out alias.xlsx
  wrote alias.xlsx
  $ xlsx.exe validate book.xlsx
  valid

--out replaces the named entry itself: a symlink target is not followed,
so an unrelated file the link points at is left untouched.

  $ xlsx.exe create other.xlsx --sheet Keep >/dev/null
  $ ln -s other.xlsx link.xlsx
  $ xlsx.exe html book.xlsx --out link.xlsx
  wrote link.xlsx
  $ head -1 link.xlsx
  <!DOCTYPE html>
  $ xlsx.exe validate other.xlsx
  valid

`capabilities` prints the batch op catalog this build supports, so an agent
can confirm its needed ops exist before generating a script (the JSON
script contract is backward-compatible, but a stricter older CLI rejects
ops it doesn't know):

  $ xlsx.exe capabilities | head -2
  {
    "schema": "xlsx.capabilities/1",
  $ xlsx.exe capabilities | grep -c '"op":'
  9
  $ xlsx.exe capabilities | grep -o '"batch_schema": "[^"]*"'
  "batch_schema": "xlsx.batch/1"

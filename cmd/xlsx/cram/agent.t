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
cells (A2 here) are omitted — absence means blank — and a formula with no
cached result carries only its formula text, no fake empty value:

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
        },
        "style_id": 0
      },
      {
        "ref": "B2",
        "formula": "B1*2",
        "style_id": 0
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
      },
      "0": {}
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

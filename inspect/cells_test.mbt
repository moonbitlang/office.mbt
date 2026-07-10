// Snapshot tests for the `xlsx.cells/1` payload and the bounded range
// parser. The stringified JSON is the contract (docs/agent-json-schemas.md).

///|
test "cells over a mixed range" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "Label")
  workbook.set_cell_int("Data", "A2", 42)
  workbook.set_cell_float("Data", "B1", 1234.5)
  workbook.set_cell_bool("Data", "B2", true)
  // A formula with no cached value must still appear (formula key only).
  workbook.set_cell_formula("Data", "A3", "SUM(A2:B2)")
  // A styled blank is a real stored cell: entry with style_id only.
  let bold = workbook.new_style(
    @xlsx.Style::number_format("#,##0.00").with_font(
      @xlsx.Font::with_values(bold=true),
    ),
  )
  workbook.set_cell_style("Data", "B3", bold)
  workbook.set_cell_style("Data", "B1", bold)
  // C1:C3 stay fully absent and must be omitted from `cells`.
  inspect(
    @inspect.cells(workbook, file="book.xlsx", "Data", "A1:C3").stringify(
      indent=2,
    ),
    content=(
      #|{
      #|  "schema": "xlsx.cells/1",
      #|  "file": "book.xlsx",
      #|  "sheet": "Data",
      #|  "range": "A1:C3",
      #|  "cells": [
      #|    {
      #|      "ref": "A1",
      #|      "value": "Label",
      #|      "raw": {
      #|        "type": "string",
      #|        "value": "Label"
      #|      }
      #|    },
      #|    {
      #|      "ref": "B1",
      #|      "value": "1,234.50",
      #|      "raw": {
      #|        "type": "number",
      #|        "value": 1234.5
      #|      },
      #|      "style_id": 1
      #|    },
      #|    {
      #|      "ref": "A2",
      #|      "value": "42",
      #|      "raw": {
      #|        "type": "number",
      #|        "value": 42
      #|      }
      #|    },
      #|    {
      #|      "ref": "B2",
      #|      "value": "TRUE",
      #|      "raw": {
      #|        "type": "bool",
      #|        "value": true
      #|      }
      #|    },
      #|    {
      #|      "ref": "A3",
      #|      "formula": "SUM(A2:B2)"
      #|    },
      #|    {
      #|      "ref": "B3",
      #|      "style_id": 1
      #|    }
      #|  ],
      #|  "styles": {
      #|    "1": {
      #|      "number_format": "#,##0.00",
      #|      "font": {
      #|        "bold": true
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "cells of a single cell normalizes the range ref" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell_int("Data", "B2", 7)
  inspect(
    @inspect.cells(workbook, file="one.xlsx", "Data", "B2").stringify(indent=2),
    content=(
      #|{
      #|  "schema": "xlsx.cells/1",
      #|  "file": "one.xlsx",
      #|  "sheet": "Data",
      #|  "range": "B2",
      #|  "cells": [
      #|    {
      #|      "ref": "B2",
      #|      "value": "7",
      #|      "raw": {
      #|        "type": "number",
      #|        "value": 7
      #|      }
      #|    }
      #|  ],
      #|  "styles": {}
      #|}
    ),
  )
}

///|
test "cells on a missing sheet raises" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  try @inspect.cells(workbook, file="x.xlsx", "Nope", "A1") catch {
    err =>
      inspect(
        err,
        content=(
          #|bobzhang/mbtexcel/xlsx.XlsxError.SheetNotFound
        ),
      )
  } noraise {
    _ => fail("expected a missing-sheet error")
  }
}

///|
test "cells serializes alignment style fields" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "centered")
  let centered = workbook.new_style(
    @xlsx.Style::new().with_alignment(
      @xlsx.Alignment::with_values(
        horizontal="center",
        vertical="top",
        wrap_text=true,
        text_rotation=45,
      ),
    ),
  )
  workbook.set_cell_style("Data", "A1", centered)
  inspect(
    @inspect.cells(workbook, file="a.xlsx", "Data", "A1").stringify(indent=2),
    content=(
      #|{
      #|  "schema": "xlsx.cells/1",
      #|  "file": "a.xlsx",
      #|  "sheet": "Data",
      #|  "range": "A1",
      #|  "cells": [
      #|    {
      #|      "ref": "A1",
      #|      "value": "centered",
      #|      "raw": {
      #|        "type": "string",
      #|        "value": "centered"
      #|      },
      #|      "style_id": 1
      #|    }
      #|  ],
      #|  "styles": {
      #|    "1": {
      #|      "alignment": {
      #|        "horizontal": "center",
      #|        "vertical": "top",
      #|        "wrap_text": true,
      #|        "text_rotation": 45
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "cells reports effective row and column styles" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let banded = workbook.new_style(
    @xlsx.Style::new().with_fill(@xlsx.Fill::solid("EEEEEE")),
  )
  let priced = workbook.new_style(@xlsx.Style::number_format("#,##0.00"))
  workbook.set_row_style("Data", 2, banded)
  workbook.set_col_style("Data", 3, priced)
  // A2: blank in a styled row -> {ref, style_id}. B2: value in the styled
  // row inherits its style id (the display value keeps the cell's own
  // format, excelize-parity). C1: blank in a styled column. B1: plain cell,
  // no style_id key at all.
  workbook.set_cell_int("Data", "B2", 5)
  workbook.set_cell("Data", "B1", "plain")
  inspect(
    @inspect.cells(workbook, file="rowcol.xlsx", "Data", "A1:C2").stringify(
      indent=2,
    ),
    content=(
      #|{
      #|  "schema": "xlsx.cells/1",
      #|  "file": "rowcol.xlsx",
      #|  "sheet": "Data",
      #|  "range": "A1:C2",
      #|  "cells": [
      #|    {
      #|      "ref": "B1",
      #|      "value": "plain",
      #|      "raw": {
      #|        "type": "string",
      #|        "value": "plain"
      #|      }
      #|    },
      #|    {
      #|      "ref": "C1",
      #|      "style_id": 2
      #|    },
      #|    {
      #|      "ref": "A2",
      #|      "style_id": 1
      #|    },
      #|    {
      #|      "ref": "B2",
      #|      "value": "5",
      #|      "raw": {
      #|        "type": "number",
      #|        "value": 5
      #|      },
      #|      "style_id": 1
      #|    },
      #|    {
      #|      "ref": "C2",
      #|      "style_id": 1
      #|    }
      #|  ],
      #|  "styles": {
      #|    "2": {
      #|      "number_format": "#,##0.00"
      #|    },
      #|    "1": {
      #|      "fill": {
      #|        "type": "pattern",
      #|        "pattern": 1,
      #|        "colors": [
      #|          "EEEEEE"
      #|        ]
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "cells serializes theme and indexed colors" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "themed")
  let themed = workbook.new_style(
    @xlsx.Style::new().with_font(
      @xlsx.Font::with_values(color_theme=1, color_tint=-0.25),
    ),
  )
  workbook.set_cell_style("Data", "A1", themed)
  inspect(
    @inspect.cells(workbook, file="theme.xlsx", "Data", "A1").stringify(
      indent=2,
    ),
    content=(
      #|{
      #|  "schema": "xlsx.cells/1",
      #|  "file": "theme.xlsx",
      #|  "sheet": "Data",
      #|  "range": "A1",
      #|  "cells": [
      #|    {
      #|      "ref": "A1",
      #|      "value": "themed",
      #|      "raw": {
      #|        "type": "string",
      #|        "value": "themed"
      #|      },
      #|      "style_id": 1
      #|    }
      #|  ],
      #|  "styles": {
      #|    "1": {
      #|      "font": {
      #|        "color_theme": 1,
      #|        "color_tint": -0.25
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

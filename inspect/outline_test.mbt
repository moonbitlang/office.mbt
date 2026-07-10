// Snapshot tests for the `xlsx.outline/1` payload. Fixtures are built
// through the public @xlsx API only; the stringified JSON is the contract,
// so a diff here is a schema change and must follow the additive-only
// evolution policy (docs/agent-json-schemas.md).

///|
/// A 1x1 transparent PNG, the smallest well-formed image fixture.
let tiny_png : Bytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
  0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00,
  0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78,
  0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]

///|
/// A workbook exercising every outline feature at once: values, a formula,
/// a styled+merged header, frozen panes, an auto-filter, a table, a chart,
/// an image, a data validation, a hyperlink, a comment, a defined name, and
/// hidden/very-hidden sheets.
fn rich_workbook() -> @xlsx.Workbook raise @xlsx.XlsxError {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell("Data", "B1", "Sales")
  workbook.set_cell("Data", "A2", "East")
  workbook.set_cell_int("Data", "B2", 120)
  workbook.set_cell("Data", "A3", "West")
  workbook.set_cell_int("Data", "B3", 80)
  workbook.set_cell_formula("Data", "B4", "SUM(B2:B3)")
  let header_style = workbook.new_style(
    @xlsx.Style::new()
    .with_font(@xlsx.Font::with_values(bold=true, color="FFFFFF"))
    .with_fill(@xlsx.Fill::solid("4472C4")),
  )
  workbook.set_cell_style("Data", "A1", header_style)
  workbook.set_cell_style("Data", "B1", header_style)
  workbook.merge_cells("Data", "D1:E1")
  workbook.set_panes(
    "Data",
    @xlsx.Panes::with_values(freeze=true, y_split=1, top_left_cell="A2"),
  )
  workbook.set_auto_filter("Data", "A1:B3", [])
  workbook.set_cell("Data", "G1", "Item")
  workbook.set_cell("Data", "H1", "Qty")
  workbook.set_cell("Data", "G2", "Ann")
  workbook.set_cell_int("Data", "H2", 3)
  ignore(
    workbook.add_table_with_columns("Data", "G1:H2", "Table1", ["Item", "Qty"]),
  )
  let chart = @xlsx.ChartOptions::new(Col)
  chart.series.push(
    @xlsx.ChartSeries::new("Data!$A$2:$A$3", "Data!$B$2:$B$3", name="Sales"),
  )
  workbook.add_chart_with_options("Data", "E5", chart)
  workbook.add_image("Data", "D4", tiny_png, "png", "image/png")
  workbook.add_data_validation_list("Data", "C2", ["yes", "no"])
  workbook.set_cell_hyperlink("Data", "A3", "https://example.com", External)
  workbook.add_comment("Data", {
    cell: "B2",
    author: "tester",
    author_id: None,
    text: "check me",
    paragraph: [],
    width: None,
    height: None,
  })
  workbook.set_defined_name(
    @xlsx.DefinedName::new("SalesRange", "Data!$B$2:$B$3"),
  )
  ignore(workbook.add_sheet("Hidden"))
  workbook.set_sheet_visible("Hidden", false)
  ignore(workbook.add_sheet("Ghost"))
  workbook.set_sheet_visible("Ghost", false, very_hidden=true)
  workbook
}

///|
test "outline of a rich workbook" {
  let workbook = rich_workbook()
  inspect(
    @inspect.outline(workbook, file="book.xlsx").stringify(indent=2),
    content=(
      #|{
      #|  "schema": "xlsx.outline/1",
      #|  "file": "book.xlsx",
      #|  "sheet_count": 3,
      #|  "active_sheet": {
      #|    "name": "Data",
      #|    "index": 0
      #|  },
      #|  "defined_names": [
      #|    {
      #|      "name": "_xlnm._FilterDatabase",
      #|      "refers_to": "'Data'!$A$1:$B$3",
      #|      "scope": "Data"
      #|    },
      #|    {
      #|      "name": "SalesRange",
      #|      "refers_to": "Data!$B$2:$B$3",
      #|      "scope": "Workbook"
      #|    }
      #|  ],
      #|  "sheets": [
      #|    {
      #|      "kind": "worksheet",
      #|      "name": "Data",
      #|      "index": 0,
      #|      "state": "visible",
      #|      "declared_dimension": "A1:H4",
      #|      "max_row": 4,
      #|      "max_col": 8,
      #|      "used_range": "A1:H4",
      #|      "frozen": {
      #|        "x_split": 0,
      #|        "y_split": 1,
      #|        "top_left_cell": "A2"
      #|      },
      #|      "auto_filter": "A1:B3",
      #|      "merges": [
      #|        "D1:E1"
      #|      ],
      #|      "tables": [
      #|        {
      #|          "name": "Table1",
      #|          "range": "G1:H2",
      #|          "columns": [
      #|            "Item",
      #|            "Qty"
      #|          ]
      #|        }
      #|      ],
      #|      "charts": [
      #|        {
      #|          "anchor": "E5",
      #|          "width_emu": 4572000,
      #|          "height_emu": 2476500,
      #|          "kinds": [
      #|            "barChart"
      #|          ],
      #|          "series": [
      #|            {
      #|              "categories": "Data!$A$2:$A$3",
      #|              "values": "Data!$B$2:$B$3"
      #|            }
      #|          ]
      #|        }
      #|      ],
      #|      "images": [
      #|        {
      #|          "anchor": "D4",
      #|          "extension": "png",
      #|          "content_type": "image/png",
      #|          "width_emu": 9525,
      #|          "height_emu": 9525
      #|        }
      #|      ],
      #|      "pivot_tables": [],
      #|      "counts": {
      #|        "data_validations": 1,
      #|        "conditional_format_ranges": 0,
      #|        "comments": 1,
      #|        "hyperlinks": 1,
      #|        "slicers": 0
      #|      }
      #|    },
      #|    {
      #|      "kind": "worksheet",
      #|      "name": "Hidden",
      #|      "index": 1,
      #|      "state": "hidden",
      #|      "max_row": 0,
      #|      "max_col": 0,
      #|      "merges": [],
      #|      "tables": [],
      #|      "charts": [],
      #|      "images": [],
      #|      "pivot_tables": [],
      #|      "counts": {
      #|        "data_validations": 0,
      #|        "conditional_format_ranges": 0,
      #|        "comments": 0,
      #|        "hyperlinks": 0,
      #|        "slicers": 0
      #|      }
      #|    },
      #|    {
      #|      "kind": "worksheet",
      #|      "name": "Ghost",
      #|      "index": 2,
      #|      "state": "very_hidden",
      #|      "max_row": 0,
      #|      "max_col": 0,
      #|      "merges": [],
      #|      "tables": [],
      #|      "charts": [],
      #|      "images": [],
      #|      "pivot_tables": [],
      #|      "counts": {
      #|        "data_validations": 0,
      #|        "conditional_format_ranges": 0,
      #|        "comments": 0,
      #|        "hyperlinks": 0,
      #|        "slicers": 0
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "outline of an empty workbook" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  inspect(
    @inspect.outline(workbook, file="empty.xlsx").stringify(indent=2),
    content=(
      #|{
      #|  "schema": "xlsx.outline/1",
      #|  "file": "empty.xlsx",
      #|  "sheet_count": 1,
      #|  "active_sheet": {
      #|    "name": "Sheet1",
      #|    "index": 0
      #|  },
      #|  "defined_names": [],
      #|  "sheets": [
      #|    {
      #|      "kind": "worksheet",
      #|      "name": "Sheet1",
      #|      "index": 0,
      #|      "state": "visible",
      #|      "max_row": 0,
      #|      "max_col": 0,
      #|      "merges": [],
      #|      "tables": [],
      #|      "charts": [],
      #|      "images": [],
      #|      "pivot_tables": [],
      #|      "counts": {
      #|        "data_validations": 0,
      #|        "conditional_format_ranges": 0,
      #|        "comments": 0,
      #|        "hyperlinks": 0,
      #|        "slicers": 0
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "outline with an interleaved, active chart sheet" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "Month")
  workbook.set_cell_int("Data", "B1", 10)
  let chart = @xlsx.ChartOptions::new(Line)
  chart.series.push(@xlsx.ChartSeries::new("Data!$A$1:$A$1", "Data!$B$1:$B$1"))
  ignore(workbook.add_chart_sheet_with_options("Trend", chart))
  ignore(workbook.add_sheet("Notes"))
  // The active index spans worksheets AND chart sheets in tab order.
  workbook.set_active_sheet(workbook.get_sheet_index("Trend"))
  inspect(
    @inspect.outline(workbook, file="charted.xlsx").stringify(indent=2),
    content=(
      #|{
      #|  "schema": "xlsx.outline/1",
      #|  "file": "charted.xlsx",
      #|  "sheet_count": 3,
      #|  "active_sheet": {
      #|    "name": "Trend",
      #|    "index": 1
      #|  },
      #|  "defined_names": [],
      #|  "sheets": [
      #|    {
      #|      "kind": "worksheet",
      #|      "name": "Data",
      #|      "index": 0,
      #|      "state": "visible",
      #|      "declared_dimension": "A1:B1",
      #|      "max_row": 1,
      #|      "max_col": 2,
      #|      "used_range": "A1:B1",
      #|      "merges": [],
      #|      "tables": [],
      #|      "charts": [],
      #|      "images": [],
      #|      "pivot_tables": [],
      #|      "counts": {
      #|        "data_validations": 0,
      #|        "conditional_format_ranges": 0,
      #|        "comments": 0,
      #|        "hyperlinks": 0,
      #|        "slicers": 0
      #|      }
      #|    },
      #|    {
      #|      "kind": "chart_sheet",
      #|      "name": "Trend",
      #|      "index": 1,
      #|      "state": "visible",
      #|      "charts": [
      #|        {
      #|          "kinds": [
      #|            "lineChart"
      #|          ],
      #|          "series": [
      #|            {
      #|              "categories": "Data!$A$1:$A$1",
      #|              "values": "Data!$B$1:$B$1"
      #|            }
      #|          ]
      #|        }
      #|      ]
      #|    },
      #|    {
      #|      "kind": "worksheet",
      #|      "name": "Notes",
      #|      "index": 2,
      #|      "state": "visible",
      #|      "max_row": 0,
      #|      "max_col": 0,
      #|      "merges": [],
      #|      "tables": [],
      #|      "charts": [],
      #|      "images": [],
      #|      "pivot_tables": [],
      #|      "counts": {
      #|        "data_validations": 0,
      #|        "conditional_format_ranges": 0,
      #|        "comments": 0,
      #|        "hyperlinks": 0,
      #|        "slicers": 0
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "outline reports live extents when the declared dimension is stale" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  workbook.set_cell("Data", "B3", "y")
  // Round-trip through bytes so the sheet carries a declared <dimension>.
  let reread = @xlsx.read(@xlsx.write(workbook)[:])
  // Mutating past the declared range must not fool the outline: the
  // retained dimension is reported as declared, live extents win.
  reread.set_cell("Data", "C9", "later")
  inspect(
    @inspect.outline(reread, file="stale.xlsx").stringify(indent=2),
    content=(
      #|{
      #|  "schema": "xlsx.outline/1",
      #|  "file": "stale.xlsx",
      #|  "sheet_count": 1,
      #|  "active_sheet": {
      #|    "name": "Data",
      #|    "index": 0
      #|  },
      #|  "defined_names": [],
      #|  "sheets": [
      #|    {
      #|      "kind": "worksheet",
      #|      "name": "Data",
      #|      "index": 0,
      #|      "state": "visible",
      #|      "declared_dimension": "A1:B3",
      #|      "max_row": 9,
      #|      "max_col": 3,
      #|      "used_range": "A1:C9",
      #|      "merges": [],
      #|      "tables": [],
      #|      "charts": [],
      #|      "images": [],
      #|      "pivot_tables": [],
      #|      "counts": {
      #|        "data_validations": 0,
      #|        "conditional_format_ranges": 0,
      #|        "comments": 0,
      #|        "hyperlinks": 0,
      #|        "slicers": 0
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
}

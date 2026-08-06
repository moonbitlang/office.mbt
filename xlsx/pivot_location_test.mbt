///|
/// Regression coverage for defect 1 of
/// https://github.com/moonbitlang/office.mbt/issues/264: `<location>` was
/// emitted with fixed `firstHeaderRow="1" firstDataRow="2" firstDataCol="1"`
/// and never carried `rowPageCount` / `colPageCount`, so a pivot with page
/// (filter) fields declared a layout Excel could not place (`#SPILL!`, no
/// pivot appears).
fn issue264_source_workbook() -> @xlsx.Workbook raise {
  let wb = @xlsx.Workbook::new()
  wb.new_sheet("Data") |> ignore
  wb.new_sheet("Summary") |> ignore
  let headers : ReadOnlyArray[String] = [
    "Region", "Quarter", "Channel", "Revenue",
  ]
  let cols : ReadOnlyArray[String] = ["A", "B", "C", "D"]
  for i, name in headers {
    wb.set_cell_value("Data", "\{cols[i]}1", String(name))
  }
  wb.set_cell_value("Data", "A2", String("APAC"))
  wb.set_cell_value("Data", "B2", String("Q3"))
  wb.set_cell_value("Data", "C2", String("Direct"))
  wb.set_cell_value("Data", "D2", Numeric(1.0))
  wb.set_cell_value("Data", "A3", String("EMEA"))
  wb.set_cell_value("Data", "B3", String("Q4"))
  wb.set_cell_value("Data", "C3", String("Partner"))
  wb.set_cell_value("Data", "D3", Numeric(2.0))
  wb
}

///|
/// Extracts the single `<location .../>` element from a pivot table part.
fn issue264_location(table_xml : String) -> String raise {
  let start = match table_xml.find("<location ") {
    Some(pos) => pos
    None => fail("no <location> element")
  }
  let rest = table_xml[start:]
  let stop = match rest.find("/>") {
    Some(pos) => pos + 2
    None => fail("unterminated <location> element")
  }
  rest[:stop].to_owned()
}

///|
/// Builds one pivot on `Summary` over `Data`, from field names per axis.
fn issue264_pivot_location(
  rows : ReadOnlyArray[String],
  columns : ReadOnlyArray[String],
  filters : ReadOnlyArray[String],
  data : ReadOnlyArray[String],
  page_over_then_down? : Bool = false,
) -> String raise {
  let wb = issue264_source_workbook()
  let options = @xlsx.PivotTableOptions::new("Data!A1:D3", "Summary!A3:F30")
  options.page_over_then_down = page_over_then_down
  for name in rows {
    options.rows.push(@xlsx.PivotTableField::new(name))
  }
  for name in columns {
    options.columns.push(@xlsx.PivotTableField::new(name))
  }
  for name in filters {
    options.filter.push(@xlsx.PivotTableField::new(name))
  }
  for name in data {
    options.data.push(@xlsx.PivotTableField::new(name, subtotal="Sum"))
  }
  issue264_location(wb.add_pivot_table(options).table_xml)
}

///|
/// No page fields: `rowPageCount` / `colPageCount` stay at their schema
/// default of 0 and are omitted. `firstDataRow` follows the column axis and
/// `firstDataCol` follows the row axis.
test "issue 264 location without page fields" {
  // rows + values: no column axis, so no caption row above the single header
  // row of data-field captions.
  inspect(
    issue264_pivot_location(["Region"], [], [], ["Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="0" firstDataRow="1" firstDataCol="1"/>
    ),
  )
  // rows + columns + values: caption row, then one column-field label row.
  inspect(
    issue264_pivot_location(["Region"], ["Quarter"], [], ["Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="1" firstDataRow="2" firstDataCol="1"/>
    ),
  )
  // columns + values, no row fields: the corner column still holds the
  // grand-total label, so firstDataCol stays 1.
  inspect(
    issue264_pivot_location([], ["Quarter"], [], ["Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="1" firstDataRow="2" firstDataCol="1"/>
    ),
  )
  // two row fields: outline/tabular form gives each row field its own column.
  inspect(
    issue264_pivot_location(["Region", "Quarter"], [], [], ["Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="0" firstDataRow="1" firstDataCol="2"/>
    ),
  )
  // two column fields: two label rows below the caption row.
  inspect(
    issue264_pivot_location(["Region"], ["Quarter", "Channel"], [], ["Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="1" firstDataRow="3" firstDataCol="1"/>
    ),
  )
  // two data fields put an implicit "Values" field on the column axis, which
  // adds a label row (and a caption row when it is the only column level).
  inspect(
    issue264_pivot_location(["Region"], [], [], ["Revenue", "Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="1" firstDataRow="2" firstDataCol="1"/>
    ),
  )
  inspect(
    issue264_pivot_location(["Region"], ["Quarter"], [], ["Revenue", "Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="1" firstDataRow="3" firstDataCol="1"/>
    ),
  )
}

///|
/// With page fields the filter area is described by `rowPageCount` /
/// `colPageCount`. Per [MS-OI29500] Part 1 18.10.1.49, Office reads `@ref` as
/// the pivot range *excluding* the page fields, so the row offsets are the
/// same as for the equivalent pivot without filters.
test "issue 264 location with page fields" {
  // The reporter's case: rows + values + one filter.
  inspect(
    issue264_pivot_location(["Region"], [], ["Channel"], ["Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="0" firstDataRow="1" firstDataCol="1" rowPageCount="1" colPageCount="1"/>
    ),
  )
  // rows + columns + values + one filter.
  inspect(
    issue264_pivot_location(["Region"], ["Quarter"], ["Channel"], ["Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="1" firstDataRow="2" firstDataCol="1" rowPageCount="1" colPageCount="1"/>
    ),
  )
  // Two filters stack down a single column by default.
  inspect(
    issue264_pivot_location(["Region"], [], ["Quarter", "Channel"], ["Revenue"]),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="0" firstDataRow="1" firstDataCol="1" rowPageCount="2" colPageCount="1"/>
    ),
  )
  // pageOverThenDown lays the same filters out across instead of down.
  inspect(
    issue264_pivot_location(
      ["Region"],
      [],
      ["Quarter", "Channel"],
      ["Revenue"],
      page_over_then_down=true,
    ),
    content=(
      #|<location ref="A3:F30" firstHeaderRow="0" firstDataRow="1" firstDataCol="1" rowPageCount="1" colPageCount="2"/>
    ),
  )
}

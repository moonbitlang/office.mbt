///|
test "add_table options auto name and columns" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = TableOptions::new("B26:A21")
  let table = workbook.add_table("Sheet1", opts)
  inspect(table.name, content="Table1")
  inspect(table.range_ref, content="A21:B26")
  debug_inspect(table.columns, content="[\"Column1\", \"Column2\"]")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A21"),
    content="Some(\"Column1\")",
  )
  debug_inspect(
    workbook.get_cell_value("Sheet1", "B21"),
    content="Some(\"Column2\")",
  )
}

///|
test "add_table options style and header row hidden" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_cell("Sheet2", "A2", "Date")
  workbook.set_cell("Sheet2", "B2", "Values")
  let opts = TableOptions::new("A2:B5")
  opts.set_name("table")
  opts.set_style_name("TableStyleMedium2")
  opts.set_show_column_stripes(true)
  opts.set_show_first_column(true)
  opts.set_show_last_column(true)
  opts.set_show_row_stripes(Some(true))
  let t1 = workbook.add_table("Sheet2", opts)
  inspect(t1.name, content="table")
  inspect(t1.style_name, content="TableStyleMedium2")
  debug_inspect(t1.columns, content="[\"Date\", \"Values\"]")
  let opts2 = TableOptions::new("D1:D11")
  opts2.set_show_header_row(Some(false))
  let t2 = workbook.add_table("Sheet2", opts2)
  inspect(t2.show_header_row, content="false")
  inspect(t2.range_ref, content="D2:D11")
  debug_inspect(workbook.get_cell_value("Sheet2", "D2"), content="None")
}

///|
test "add_table options single cell range expands" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = TableOptions::new("F1:F1")
  let table = workbook.add_table("Sheet1", opts)
  inspect(table.range_ref, content="F1:F2")
  debug_inspect(table.columns, content="[\"Column1\"]")
}

///|
test "add_table options duplicate name and overlap errors" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts1 = TableOptions::new("A1:B2")
  opts1.set_name("Dup")
  ignore(workbook.add_table("Sheet1", opts1))
  let opts2 = TableOptions::new("C1:D2")
  opts2.set_name("Dup")
  let dup : Result[Table, Error] = try? workbook.add_table("Sheet1", opts2)
  inspect(dup is Err(@xlsx.InvalidTable(_)), content="true")
  let opts3 = TableOptions::new("B2:C3")
  let overlap : Result[Table, Error] = try? workbook.add_table("Sheet1", opts3)
  inspect(overlap is Err(@xlsx.InvalidTable(_)), content="true")
}

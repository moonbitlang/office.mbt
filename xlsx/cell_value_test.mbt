///|
test "typed cell values roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", CellValue::Numeric(1.5))
  workbook.set_cell_value("Sheet1", "B1", CellValue::Bool(true))
  workbook.set_cell_value("Sheet1", "C1", CellValue::Error("#DIV/0!"))
  let bytes = write(workbook)
  let parsed = read(bytes)
  inspect(
    parsed.get_cell_value_raw("Sheet1", "A1"),
    content="Some(Numeric(1.5))",
  )
  inspect(parsed.get_cell_value_raw("Sheet1", "B1"), content="Some(Bool(true))")
  inspect(
    parsed.get_cell_value_raw("Sheet1", "C1"),
    content="Some(Error(\"#DIV/0!\"))",
  )
  inspect(parsed.get_cell("Sheet1", "B1"), content="Some(\"1\")")
}

///|
test "formatted cell value" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", CellValue::Numeric(1.234))
  let style_id = workbook.add_style(Style::number_format("0.00"))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  inspect(workbook.get_cell_value("Sheet1", "A1"), content="Some(\"1.23\")")
  inspect(
    workbook.get_cell_value("Sheet1", "A1", raw=true),
    content="Some(\"1.234\")",
  )
}

///|
test "formatted cell value roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", CellValue::Numeric(1234.5))
  let style_id = workbook.add_style(Style::number_format("#,##0.0"))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  let parsed = read(write(workbook))
  inspect(parsed.get_cell_value("Sheet1", "A1"), content="Some(\"1,234.5\")")
  inspect(
    parsed.get_cell_value("Sheet1", "A1", raw=true),
    content="Some(\"1234.5\")",
  )
}

///|
test "formatted percent and date" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", CellValue::Numeric(0.256))
  let pct_style = workbook.add_style(Style::number_format("0%"))
  workbook.set_cell_style("Sheet1", "A1", pct_style)
  workbook.set_cell_value("Sheet1", "B1", CellValue::Numeric(2.0))
  let date_style = workbook.add_style(Style::builtin_number_format(14))
  workbook.set_cell_style("Sheet1", "B1", date_style)
  workbook.set_cell_value("Sheet1", "C1", CellValue::Bool(true))
  inspect(workbook.get_cell_value("Sheet1", "A1"), content="Some(\"26%\")")
  inspect(workbook.get_cell_value("Sheet1", "B1"), content="Some(\"1/2/00\")")
  inspect(workbook.get_cell_value("Sheet1", "C1"), content="Some(\"TRUE\")")
}

///|
test "typed cell values roundtrip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", Numeric(1.5))
  workbook.set_cell_value("Sheet1", "B1", Bool(true))
  workbook.set_cell_value("Sheet1", "C1", Error("#DIV/0!"))
  let bytes = @xlsx.write(workbook)
  let parsed = @xlsx.read(bytes)
  debug_inspect(
    parsed.get_cell_value_raw("Sheet1", "A1"),
    content="Some(Numeric(1.5))",
  )
  debug_inspect(
    parsed.get_cell_value_raw("Sheet1", "B1"),
    content="Some(Bool(true))",
  )
  debug_inspect(
    parsed.get_cell_value_raw("Sheet1", "C1"),
    content="Some(Error(\"#DIV/0!\"))",
  )
  debug_inspect(parsed.get_cell("Sheet1", "B1"), content="Some(\"1\")")
}

///|
test "formatted cell value" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", Numeric(1.234))
  let style_id = workbook.add_style(@xlsx.Style::number_format("0.00"))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1"),
    content="Some(\"1.23\")",
  )
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1", raw=true),
    content="Some(\"1.234\")",
  )
}

///|
test "formatted cell value roundtrip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", Numeric(1234.5))
  let style_id = workbook.add_style(@xlsx.Style::number_format("#,##0.0"))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  debug_inspect(
    parsed.get_cell_value("Sheet1", "A1"),
    content="Some(\"1,234.5\")",
  )
  debug_inspect(
    parsed.get_cell_value("Sheet1", "A1", raw=true),
    content="Some(\"1234.5\")",
  )
}

///|
test "formatted percent and date" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", Numeric(0.256))
  let pct_style = workbook.add_style(@xlsx.Style::number_format("0%"))
  workbook.set_cell_style("Sheet1", "A1", pct_style)
  workbook.set_cell_value("Sheet1", "B1", Numeric(2.0))
  let date_style = workbook.add_style(@xlsx.Style::builtin_number_format(14))
  workbook.set_cell_style("Sheet1", "B1", date_style)
  workbook.set_cell_value("Sheet1", "C1", Bool(true))
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1"),
    content="Some(\"26%\")",
  )
  debug_inspect(
    workbook.get_cell_value("Sheet1", "B1"),
    content="Some(\"01-02-00\")",
  )
  debug_inspect(
    workbook.get_cell_value("Sheet1", "C1"),
    content="Some(\"TRUE\")",
  )
}

///|
test "typed setters and cell type" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let value_uint : UInt = 7
  workbook.set_cell_bool("Sheet1", "A1", true)
  workbook.set_cell_int("Sheet1", "B1", -12)
  workbook.set_cell_uint("Sheet1", "C1", value_uint)
  workbook.set_cell_float("Sheet1", "D1", 1.234, precision=2)
  workbook.set_cell_str("Sheet1", "E1", "text")
  workbook.set_cell_default("Sheet1", "F1", "raw")
  debug_inspect(workbook.get_cell_type("Sheet1", "A1"), content="Some(Bool)")
  debug_inspect(workbook.get_cell_type("Sheet1", "B1"), content="Some(Number)")
  debug_inspect(workbook.get_cell_type("Sheet1", "E1"), content="Some(String)")
  debug_inspect(workbook.get_cell_type("Sheet1", "Z9"), content="None")
  debug_inspect(
    workbook.get_cell_value_raw("Sheet1", "D1"),
    content="Some(Numeric(1.23))",
  )
  debug_inspect(workbook.get_cell("Sheet1", "F1"), content="Some(\"raw\")")
}

///|
test "non-finite numeric cell values are written as strings" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let nan : Double = @double.not_a_number
  let pos_inf : Double = @double.infinity
  let neg_inf : Double = @double.neg_infinity
  sheet.set_cell_value("A1", Numeric(nan))
  sheet.set_cell_value("A2", Numeric(pos_inf))
  sheet.set_cell_value("A3", Numeric(neg_inf))
  debug_inspect(
    sheet.get_cell("A1"),
    content=(
      #|Some("NaN")
    ),
  )
  debug_inspect(
    sheet.get_cell("A2"),
    content=(
      #|Some("+Inf")
    ),
  )
  debug_inspect(
    sheet.get_cell("A3"),
    content=(
      #|Some("-Inf")
    ),
  )
  // roundtrip stays a string cell, not an invalid numeric <v>
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(
    parsed_sheet.get_cell_value_raw("A1"),
    content=(
      #|Some(String("NaN"))
    ),
  )
  debug_inspect(
    parsed_sheet.get_cell_value_raw("A2"),
    content=(
      #|Some(String("+Inf"))
    ),
  )
  debug_inspect(
    parsed_sheet.get_cell_value_raw("A3"),
    content=(
      #|Some(String("-Inf"))
    ),
  )
}

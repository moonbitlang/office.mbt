///|
test "compat sheet aliases and row or col setters" {
  let workbook = Workbook::new()
  let sheet = workbook.new_sheet("Sheet1")
  workbook.set_sheet_row("Sheet1", "B2", ["x", "y"])
  workbook.set_sheet_col("Sheet1", "A1", ["1", "2"])
  inspect(sheet.get_cell("B2"), content="Some(\"x\")")
  inspect(sheet.get_cell("C2"), content="Some(\"y\")")
  inspect(sheet.get_cell("A1"), content="Some(\"1\")")
  inspect(sheet.get_cell("A2"), content="Some(\"2\")")
  inspect(workbook.get_sheet_index("Sheet1"), content="0")
  inspect(workbook.get_sheet_name(0), content="Some(\"Sheet1\")")
  inspect(workbook.get_active_sheet_index(), content="0")
  inspect(workbook.get_sheet_visible("Sheet1"), content="true")
  workbook.set_defined_name(DefinedName::new("Total", "Sheet1!$A$1"))
  inspect(workbook.get_defined_name().length(), content="1")
}

///|
test "compat get_sheet_index missing returns -1" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  inspect(workbook.get_sheet_index("SheetN"), content="-1")
  let invalid : Result[Int, Error] = try? workbook.get_sheet_index("Sheet:1")
  inspect(invalid is Err(XlsxError::InvalidSheetName(_)), content="true")
}

///|
test "compat auto filter and background bytes" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  workbook.auto_filter("Sheet1", "A1:B2", [])
  inspect(sheet.auto_filter() is Some(_), content="true")
  let data = Bytes::from_array([0x89, 0x50, 0x4e, 0x47])
  workbook.set_sheet_background_from_bytes("Sheet1", ".png", data)
  let background = match sheet.sheet_background() {
    Some(value) => value
    None => fail("missing background")
  }
  inspect(background.extension, content="png")
}

///|
test "search sheet exact and regex" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "100")
  sheet.set_cell("B2", "abc")
  sheet.set_cell("C3", "500")
  inspect(workbook.search_sheet("Sheet1", "100"), content="[\"A1\"]")
  inspect(
    workbook.search_sheet("Sheet1", "[0-9]", reg=true),
    content="[\"A1\", \"C3\"]",
  )
}

///|
test "update linked value clears formula cache" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  workbook.set_cell_formula("Sheet1", "A1", "SUM(1,2)", value="3")
  workbook.set_calc_props(
    Some(CalcPropsOptions::with_values(calc_mode="manual")),
  )
  workbook.update_linked_value()
  inspect(sheet.get_cell("A1"), content="Some(\"\")")
  let props = workbook.get_calc_props()
  inspect(props.calc_mode, content="None")
}

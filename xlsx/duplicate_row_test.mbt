///|
test "duplicate row basic" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A1", "B1"])
  sheet.set_row(2, ["A2", "B2"])
  workbook.duplicate_row("Sheet1", 1)
  debug_inspect(sheet.get_row(1), content="[\"A1\", \"B1\"]")
  debug_inspect(sheet.get_row(2), content="[\"A1\", \"B1\"]")
  debug_inspect(sheet.get_row(3), content="[\"A2\", \"B2\"]")
}

///|
test "duplicate row to target position" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A1"])
  sheet.set_row(2, ["A2"])
  sheet.set_row(3, ["A3"])
  workbook.duplicate_row_to("Sheet1", 1, 3)
  debug_inspect(sheet.get_row(1), content="[\"A1\"]")
  debug_inspect(sheet.get_row(2), content="[\"A2\"]")
  debug_inspect(sheet.get_row(3), content="[\"A1\"]")
  debug_inspect(sheet.get_row(4), content="[\"A3\"]")
}

///|
test "duplicate row copies validations and merges" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A", "B"])
  sheet.set_row_height(1, 20.0)
  sheet.merge_cells("A1:B1")
  sheet.add_data_validation_list("A1", ["Yes", "No"])
  sheet.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\"><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  workbook.duplicate_row("Sheet1", 1)
  debug_inspect(sheet.get_row_height(2), content="Some(20)")
  inspect(sheet.merged_cells().contains("A2:B2"), content="true")
  let mut has_validation = false
  for xml in sheet.data_validations() {
    if xml.contains("sqref=\"A2:A2\"") {
      has_validation = true
    }
  }
  inspect(has_validation, content="true")
  let mut has_condition = false
  for xml in sheet.conditional_formats() {
    if xml.contains("sqref=\"A2:A2\"") {
      has_condition = true
    }
  }
  inspect(has_condition, content="true")
}

///|
test "duplicate row invalid index" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = Ok(workbook.duplicate_row("Sheet1", 0)) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidCellRef(_)), content="true")
}

///|
test "set_sheet_name supports case-only rename" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_sheet_name("Sheet1", "sheet1")
  debug_inspect(workbook.sheet_name(0), content="Some(\"sheet1\")")
  inspect(workbook.sheet_index("SHEET1"), content="0")
}

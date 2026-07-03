///|
test "delete_sheet is no-op when missing" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = try? workbook.delete_sheet("SheetN")
  inspect(result is Ok(_), content="true")
  debug_inspect(workbook.sheet_name(0), content="Some(\"Sheet1\")")
  inspect(workbook.active_sheet_index(), content="0")
}

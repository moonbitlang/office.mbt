///|
test "delete_sheet is no-op when missing" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = Ok(workbook.delete_sheet("SheetN")) catch {
    e => Err(e)
  }
  inspect(result is Ok(_), content="true")
  debug_inspect(workbook.sheet_name(0), content="Some(\"Sheet1\")")
  inspect(workbook.active_sheet_index(), content="0")
}

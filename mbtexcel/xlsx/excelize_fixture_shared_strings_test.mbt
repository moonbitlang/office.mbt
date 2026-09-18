///|
#cfg(target="native")
async test "excelize fixture SharedStrings.xlsx search_sheet parity" {
  let workbook = @xlsx.open_file("fixtures/excelize/test/SharedStrings.xlsx")
  debug_inspect(workbook.search_sheet("Sheet1", "X"), content="[]")
  debug_inspect(workbook.search_sheet("Sheet1", "A"), content="[\"A1\"]")
  debug_inspect(
    workbook.search_sheet("Sheet1", "[0-9]", reg=true),
    content="[]",
  )
  let invalid_result : Result[Array[String], Error] = Ok(
    workbook.search_sheet("Sheet:1", ""),
  ) catch {
    e => Err(e)
  }
  inspect(
    invalid_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let missing_result : Result[Array[String], Error] = Ok(
    workbook.search_sheet("Sheet4", ""),
  ) catch {
    e => Err(e)
  }
  inspect(
    missing_result is Err(@xlsx.XlsxError::SheetNotFound(_)),
    content="true",
  )
}

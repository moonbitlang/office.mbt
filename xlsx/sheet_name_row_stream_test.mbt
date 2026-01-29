///|
test "row_stream validates sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let row_stream_result : Result[RowStream, Error] = try? workbook.row_stream(
    "Sheet:1",
  )
  inspect(
    row_stream_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}

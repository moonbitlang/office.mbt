///|
test "row_stream validates sheet name" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let row_stream_result : Result[@xlsx.RowStream, Error] = Ok(
    workbook.row_stream("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    row_stream_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
}

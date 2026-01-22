///|
test "ignored errors write and roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_ignored_errors("A1", IgnoredErrorType::EvalError)
  sheet.add_ignored_errors("A1", IgnoredErrorType::EvalError)
  sheet.add_ignored_errors("B2:C3", IgnoredErrorType::NumberStoredAsText)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet xml")
  }
  inspect(sheet_xml.contains("<ignoredErrors>"), content="true")
  inspect(sheet_xml.contains("evalError=\"1\""), content="true")
  inspect(sheet_xml.contains("numberStoredAsText=\"1\""), content="true")
  let parsed = read(bytes)
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing parsed sheet")
  }
  inspect(parsed_sheet.ignored_errors().length(), content="2")
  inspect(parsed_sheet.ignored_errors()[0].sqref, content="A1")
}

///|
test "ignored errors invalid range" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let result : Result[Unit, Error] = try? sheet.add_ignored_errors(
    "",
    IgnoredErrorType::EvalError,
  )
  match result {
    Err(XlsxError::InvalidSheetOperation(msg~)) =>
      inspect(msg, content="ignored errors range empty")
    _ => fail("expected ignored errors range error")
  }
}

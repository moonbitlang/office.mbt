///|
test "ignored errors write and roundtrip" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_ignored_errors("A1", EvalError)
  sheet.add_ignored_errors("A1", EvalError)
  sheet.add_ignored_errors("B2:C3", NumberStoredAsText)
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet xml")
  }
  inspect(sheet_xml.contains("<ignoredErrors>"), content="true")
  inspect(sheet_xml.contains("evalError=\"1\""), content="true")
  inspect(sheet_xml.contains("numberStoredAsText=\"1\""), content="true")
  let parsed = @xlsx.read(bytes)
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing parsed sheet")
  }
  inspect(parsed_sheet.ignored_errors().length(), content="2")
  inspect(parsed_sheet.ignored_errors()[0].sqref, content="A1")
}

///|
test "ignored errors invalid range" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let result : Result[Unit, Error] = Ok(sheet.add_ignored_errors("", EvalError)) catch {
    e => Err(e)
  }
  match result {
    Err(@xlsx.XlsxError::InvalidSheetOperation(msg~)) =>
      inspect(msg, content="ignored errors range empty")
    _ => fail("expected ignored errors range error")
  }
}

///|
test "ignored errors workbook parity (all types + errors)" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let types : Array[@xlsx.IgnoredErrorType] = [
    EvalError,
    TwoDigitTextYear,
    NumberStoredAsText,
    Formula,
    FormulaRange,
    UnlockedFormula,
    EmptyCellReference,
    ListDataValidation,
    CalculatedColumn,
  ]
  for t in types {
    workbook.add_ignored_errors("Sheet1", "A1", t)
  }
  workbook.add_ignored_errors("Sheet1", "A1", EvalError)
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet xml")
  }
  inspect(sheet_xml.contains("evalError=\"1\""), content="true")
  inspect(sheet_xml.contains("twoDigitTextYear=\"1\""), content="true")
  inspect(sheet_xml.contains("numberStoredAsText=\"1\""), content="true")
  inspect(sheet_xml.contains("formula=\"1\""), content="true")
  inspect(sheet_xml.contains("formulaRange=\"1\""), content="true")
  inspect(sheet_xml.contains("unlockedFormula=\"1\""), content="true")
  inspect(sheet_xml.contains("emptyCellReference=\"1\""), content="true")
  inspect(sheet_xml.contains("listDataValidation=\"1\""), content="true")
  inspect(sheet_xml.contains("calculatedColumn=\"1\""), content="true")
  let parsed = @xlsx.read(bytes)
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing parsed sheet")
  }
  inspect(sheet.ignored_errors().length(), content="9")
  let missing_sheet : Result[Unit, Error] = Ok(
    parsed.add_ignored_errors("SheetN", "A1", EvalError),
  ) catch {
    e => Err(e)
  }
  inspect(
    missing_sheet is Err(@xlsx.XlsxError::SheetNotFound(_)),
    content="true",
  )
  let blank_range : Result[Unit, Error] = Ok(
    parsed.add_ignored_errors("Sheet1", "", EvalError),
  ) catch {
    e => Err(e)
  }
  inspect(
    blank_range is Err(@xlsx.XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
}

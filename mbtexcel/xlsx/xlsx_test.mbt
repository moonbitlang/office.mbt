///|
test "xlsx roundtrip strings" {
  let workbook = @xlsx.Workbook::new()
  let sheet1 = workbook.add_sheet("Sheet1")
  sheet1.set_cell("A1", "hello")
  sheet1.set_cell("B2", "world")
  let sheet2 = workbook.add_sheet("Data")
  sheet2.set_cell("A1", "hello")
  let bytes = @xlsx.write(workbook)
  let parsed = @xlsx.read(bytes)
  inspect(parsed.sheets().length(), content="2")
  let parsed_sheet1 = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(parsed_sheet1.get_cell("A1"), content="Some(\"hello\")")
  debug_inspect(parsed_sheet1.get_cell("B2"), content="Some(\"world\")")
  let parsed_sheet2 = match parsed.sheet("Data") {
    Some(value) => value
    None => fail("missing Data")
  }
  debug_inspect(parsed_sheet2.get_cell("A1"), content="Some(\"hello\")")
}

///|
test "xlsx shared strings unique count" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "dup")
  sheet.set_cell("A2", "dup")
  sheet.set_cell("A3", "uniq")
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let xml = match archive.get("xl/sharedStrings.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sharedStrings.xml")
  }
  inspect(xml.contains("uniqueCount=\"2\""), content="true")
  inspect(xml.contains("count=\"3\""), content="true")
}

///|
test "xlsx invalid cell ref" {
  let sheet = @xlsx.Worksheet::new("Sheet1")
  @test.assert_raise(() => sheet.set_cell("1A", "bad"))
}

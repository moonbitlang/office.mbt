///|
test "unicode shared strings roundtrip" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data & Stats")
  let value = "Hi 😀 & <tag> \"quote\""
  sheet.set_cell("A1", value)
  sheet.set_cell("B1", "Plain")
  let bytes = @xlsx.write(workbook)
  let parsed = @xlsx.read(bytes)
  @test.assert_eq(parsed.get_cell("Data & Stats", "A1"), Some(value))
  @test.assert_eq(parsed.get_cell("Data & Stats", "B1"), Some("Plain"))
}

///|
test "sheet name xml escaping" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("R&D"))
  let bytes = @xlsx.write(workbook)
  let parsed = @xlsx.read(bytes)
  guard parsed.sheet("R&D") is Some(_) else { fail("missing sheet") }
}

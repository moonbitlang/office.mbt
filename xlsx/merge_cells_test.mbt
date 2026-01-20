///|
test "merge cells write and dimension" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.merge_cells("B2:A1")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("<mergeCells count=\"1\">"), content="true")
  inspect(sheet_xml.contains("ref=\"A1:B2\""), content="true")
  inspect(sheet_xml.contains("<dimension ref=\"A1:B2\"/>"), content="true")
}

///|
test "merge cells roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("C3", "x")
  sheet.merge_cells("C3:D4")
  let parsed = read(write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(parsed_sheet.merged_cells(), content="[\"C3:D4\"]")
  parsed_sheet.unmerge_cells("D4:C3")
  inspect(parsed_sheet.merged_cells(), content="[]")
}

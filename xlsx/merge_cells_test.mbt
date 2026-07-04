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
  debug_inspect(parsed_sheet.merged_cells().to_owned(), content="[\"C3:D4\"]")
  parsed_sheet.unmerge_cells("D4:C3")
  debug_inspect(parsed_sheet.merged_cells().to_owned(), content="[]")
}

///|
test "workbook merge cell wrappers" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.merge_cell("Sheet1", "B2", "A1")
  debug_inspect(workbook.get_merge_cells("Sheet1"), content="[\"A1:B2\"]")
  workbook.unmerge_cell("Sheet1", "A1", "B2")
  debug_inspect(workbook.get_merge_cells("Sheet1"), content="[]")
}

///|
test "merge cells info includes value" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "hello")
  workbook.merge_cells("Sheet1", "A1:B2")
  let merges = workbook.get_merge_cells_info("Sheet1")
  guard merges is [cell] && cell.range_ref == "A1:B2" && cell.value == "hello" else {
    fail("unexpected merge cell info")
  }
}

///|
test "merge cells info without values" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "hello")
  workbook.merge_cells("Sheet1", "A1:B2")
  let merges = workbook.get_merge_cells_info("Sheet1", without_values=true)
  guard merges is [cell] && cell.range_ref == "A1:B2" && cell.value == "" else {
    fail("unexpected merge cell info")
  }
}

///|
test "merge cells info merges overlap" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.merge_cells("Sheet1", "A1:B2")
  workbook.merge_cells("Sheet1", "B2:C3")
  let merges = workbook.get_merge_cells_info("Sheet1", without_values=true)
  guard merges.length() == 1 && merges[0].range_ref == "A1:C3" else {
    fail("unexpected merged range")
  }
}

///|
test "merge cells invalid range reference" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let result : Result[Unit, Error] = try? sheet.merge_cells("A1:B2:C3")
  inspect(result is Err(XlsxError::InvalidCellRef(_)), content="true")
}

///|
test "merge cells duplicate is no-op" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.merge_cells("A1:B2")
  sheet.merge_cells("B2:A1")
  debug_inspect(sheet.merged_cells().to_owned(), content="[\"A1:B2\"]")
}

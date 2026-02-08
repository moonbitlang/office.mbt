///|
fn find_index_or_fail(xml : String, needle : String) -> Int raise Error {
  match xml.find(needle) {
    Some(value) => value
    None => fail("missing needle: \{needle}")
  }
}

///|
test "worksheet xml order: conditional formatting is written before table parts and pivots stay in rels" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "Name")
  sheet.set_cell("B1", "Value")
  sheet.set_cell("A2", "A")
  sheet.set_cell("B2", "1")
  ignore(sheet.add_table("A1:B2", "Table1", ["Name", "Value"]))
  ignore(
    sheet.add_pivot_table_xml(
      "<pivotTableDefinition name=\"Pivot1\"/>", "<pivotCacheDefinition/>",
    ),
  )
  let opt = ConditionalFormatOptions::new("cell")
  opt.set_criteria(">")
  opt.set_value("0")
  sheet.set_conditional_format("B2:B2", [opt])
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
  let conditional_idx = find_index_or_fail(sheet_xml, "<conditionalFormatting")
  let table_parts_idx = find_index_or_fail(sheet_xml, "<tableParts")
  inspect(conditional_idx < table_parts_idx, content="true")
  inspect(sheet_xml.contains("<pivotTableParts"), content="false")
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml.rels utf8 decode failed")
      }
    None => fail("missing sheet1.xml.rels")
  }
  inspect(rels_xml.contains("relationships/pivotTable"), content="true")
}

///|
test "worksheet xml order: hyperlinks are written before ignoredErrors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "123")
  sheet.set_cell_hyperlink("A1", "https://example.com", External)
  sheet.add_ignored_errors("A1", NumberStoredAsText)
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
  let hyperlinks_idx = find_index_or_fail(sheet_xml, "<hyperlinks>")
  let ignored_idx = find_index_or_fail(sheet_xml, "<ignoredErrors>")
  inspect(hyperlinks_idx < ignored_idx, content="true")
}

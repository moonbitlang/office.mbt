///|
test "table write and relationships" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(sheet.add_table("A1:B2", "Table1", ["Name", "Value"]))
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
  inspect(sheet_xml.contains("<tableParts count=\"1\">"), content="true")
  inspect(sheet_xml.contains("r:id=\"rId1\""), content="true")
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml.rels utf8 decode failed")
      }
    None => fail("missing sheet1.xml.rels")
  }
  inspect(rels_xml.contains("relationships/table"), content="true")
  inspect(rels_xml.contains("../tables/table1.xml"), content="true")
  let table_xml = match archive.get("xl/tables/table1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("table1.xml utf8 decode failed")
      }
    None => fail("missing table1.xml")
  }
  inspect(table_xml.contains("name=\"Table1\""), content="true")
  inspect(table_xml.contains("ref=\"A1:B2\""), content="true")
  inspect(
    table_xml.contains("tableColumn id=\"1\" name=\"Name\""),
    content="true",
  )
}

///|
test "table roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(sheet.add_table("A1:C1", "TableX", ["A", "B", "C"]))
  let parsed = read(write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(parsed_sheet.tables().length(), content="1")
  inspect(parsed_sheet.tables()[0].name, content="TableX")
  inspect(parsed_sheet.tables()[0].range, content="A1:C1")
  inspect(parsed_sheet.tables()[0].range_ref, content="A1:C1")
  inspect(parsed_sheet.tables()[0].columns, content="[\"A\", \"B\", \"C\"]")
}

///|
test "table columns mismatch" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let result = try sheet.add_table("A1:B2", "BadTable", ["OnlyOne"]) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result,
    content="Err(InvalidTable(msg=\"table columns do not match range\"))",
  )
}

///|
test "table style flags and header row" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(
    sheet.add_table(
      "A1:B2",
      "Table1",
      ["Name", "Value"],
      show_first_column=true,
      show_last_column=true,
      show_row_stripes=false,
      show_column_stripes=true,
      show_header_row=false,
    ),
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let table_xml = match archive.get("xl/tables/table1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("table1.xml utf8 decode failed")
      }
    None => fail("missing table1.xml")
  }
  inspect(table_xml.contains("ref=\"A2:B2\""), content="true")
  inspect(table_xml.contains("headerRowCount=\"0\""), content="true")
  inspect(table_xml.contains("<autoFilter "), content="false")
  inspect(
    table_xml.contains(
      "showFirstColumn=\"1\" showLastColumn=\"1\" showRowStripes=\"0\" showColumnStripes=\"1\"",
    ),
    content="true",
  )
  let parsed = read(bytes)
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  let table = parsed_sheet.tables()[0]
  inspect(table.range, content="A2:B2")
  inspect(table.range_ref, content="A2:B2")
  inspect(table.show_header_row, content="false")
  inspect(table.show_first_column, content="true")
  inspect(table.show_last_column, content="true")
  inspect(table.show_row_stripes, content="false")
  inspect(table.show_column_stripes, content="true")
}

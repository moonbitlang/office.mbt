///|
test "number format style write" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let style_id = workbook.add_style(Style::number_format("0.00"))
  sheet.set_cell("A1", "1.23")
  workbook.set_cell_style("Sheet1", "A1", style_id)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let styles_xml = match archive.get("xl/styles.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("styles.xml utf8 decode failed")
      }
    None => fail("missing styles.xml")
  }
  inspect(styles_xml.contains("formatCode=\"0.00\""), content="true")
  inspect(styles_xml.contains("numFmtId=\"164\""), content="true")
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("s=\"1\""), content="true")
}

///|
test "style roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let style_id = workbook.add_style(Style::number_format("0%"))
  workbook.set_cell("Sheet1", "B2", "0.5")
  workbook.set_cell_style("Sheet1", "B2", style_id)
  let parsed = read(write(workbook))
  inspect(parsed.styles().length(), content="2")
  inspect(parsed.get_cell_style("Sheet1", "B2"), content="Some(1)")
}

///|
test "invalid style id" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result = try? workbook.set_cell_style("Sheet1", "A1", 1)
  inspect(result, content="Err(InvalidStyleId(index=1))")
}

///|
test "default font roundtrip" {
  let workbook = Workbook::new()
  workbook.set_default_font("Arial")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let styles_xml = match archive.get("xl/styles.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("styles.xml utf8 decode failed")
      }
    None => fail("missing styles.xml")
  }
  inspect(styles_xml.contains("name val=\"Arial\""), content="true")
  let parsed = read(bytes)
  inspect(parsed.get_default_font(), content="Arial")
}

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
  let style_id = workbook.new_style(Style::number_format("0%"))
  assert_eq(workbook.get_style(style_id), Style::number_format("0%"))
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
test "conditional style roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let style_id = workbook.new_conditional_style(Style::number_format("0.00"))
  let opt = ConditionalFormatOptions::new("cell")
  opt.criteria = "="
  opt.value = "1"
  opt.format = Some(style_id)
  sheet.set_conditional_format("A1", [opt])
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
  inspect(styles_xml.contains("dxfs count=\"1\""), content="true")
  inspect(styles_xml.contains("formatCode=\"0.00\""), content="true")
  let parsed = read(bytes)
  assert_eq(parsed.get_conditional_style(0), Style::number_format("0.00"))
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

///|
test "cell style font write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let font = Font::with_values(
    bold=true,
    size=14.0,
    color="FF0000",
    family="Arial",
  )
  let style_id = workbook.new_style(Style::font(font))
  sheet.set_cell("A1", "hello")
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
  inspect(styles_xml.contains("<fonts count=\"2\">"), content="true")
  inspect(styles_xml.contains("<b/>"), content="true")
  inspect(styles_xml.contains("sz val=\"14"), content="true")
  inspect(styles_xml.contains("color rgb=\"FFFF0000\""), content="true")
  inspect(styles_xml.contains("name val=\"Arial\""), content="true")
  inspect(styles_xml.contains("fontId=\"1\""), content="true")
  inspect(styles_xml.contains("applyFont=\"1\""), content="true")
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::font(font))
}

///|
test "conditional style font write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let font = Font::with_values(bold=true)
  let style_id = workbook.new_conditional_style(Style::font(font))
  let opt = ConditionalFormatOptions::new("cell")
  opt.criteria = "="
  opt.value = "1"
  opt.format = Some(style_id)
  sheet.set_conditional_format("A1", [opt])
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
  inspect(styles_xml.contains("dxfs count=\"1\""), content="true")
  inspect(styles_xml.contains("<dxf><font><b/>"), content="true")
  let parsed = read(bytes)
  assert_eq(parsed.get_conditional_style(0), Style::font(font))
}

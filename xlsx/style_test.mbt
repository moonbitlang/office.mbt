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

///|
test "cell style fill write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::solid("FF0000")
  let style_id = workbook.new_style(Style::fill(fill))
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
  inspect(styles_xml.contains("<fills count=\"3\">"), content="true")
  inspect(
    styles_xml.contains(
      "patternFill patternType=\"solid\"><fgColor rgb=\"FFFF0000\"/>",
    ),
    content="true",
  )
  inspect(styles_xml.contains("fillId=\"2\""), content="true")
  inspect(styles_xml.contains("applyFill=\"1\""), content="true")
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::fill(fill))
}

///|
test "conditional style fill write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::solid("00FF00")
  let style_id = workbook.new_conditional_style(Style::fill(fill))
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
  inspect(
    styles_xml.contains(
      "<dxf><fill><patternFill patternType=\"solid\"><bgColor rgb=\"FF00FF00\"/>",
    ),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_conditional_style(0), Style::fill(fill))
}

///|
test "cell style border write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let borders : Array[Border] = [
    Border::with_values("left", style=1, color="FF0000"),
    Border::with_values("top", style=2, color="00FF00"),
  ]
  let style_id = workbook.new_style(Style::border(borders))
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
  inspect(styles_xml.contains("<borders count=\"2\">"), content="true")
  inspect(styles_xml.contains("<left style=\"thin\">"), content="true")
  inspect(styles_xml.contains("<top style=\"medium\">"), content="true")
  inspect(styles_xml.contains("color rgb=\"FFFF0000\""), content="true")
  inspect(styles_xml.contains("color rgb=\"FF00FF00\""), content="true")
  inspect(styles_xml.contains("borderId=\"1\""), content="true")
  inspect(styles_xml.contains("applyBorder=\"1\""), content="true")
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::border(borders))
}

///|
test "conditional style border write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let borders : Array[Border] = [
    Border::with_values("bottom", style=5, color="0000FF"),
  ]
  let style_id = workbook.new_conditional_style(Style::border(borders))
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
  inspect(styles_xml.contains("<dxf><border>"), content="true")
  inspect(styles_xml.contains("<bottom style=\"thick\">"), content="true")
  inspect(styles_xml.contains("color rgb=\"FF0000FF\""), content="true")
  let parsed = read(bytes)
  assert_eq(parsed.get_conditional_style(0), Style::border(borders))
}

///|
test "cell style protection write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let protection = Protection::with_values(hidden=true, locked=false)
  let style_id = workbook.new_style(Style::protection(protection))
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
  inspect(styles_xml.contains("applyProtection=\"1\""), content="true")
  inspect(
    styles_xml.contains("<protection locked=\"0\" hidden=\"1\"/>"),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::protection(protection))
}

///|
test "conditional style protection write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let protection = Protection::with_values(hidden=true)
  let style_id = workbook.new_conditional_style(Style::protection(protection))
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
  inspect(
    styles_xml.contains("<dxf><protection hidden=\"1\"/>"),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_conditional_style(0), Style::protection(protection))
}

///|
test "cell style alignment write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let alignment = Alignment::with_values(
    horizontal="center",
    vertical="center",
    wrap_text=true,
    text_rotation=45,
    indent=2,
    shrink_to_fit=true,
  )
  let style_id = workbook.new_style(Style::alignment(alignment))
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
  inspect(styles_xml.contains("applyAlignment=\"1\""), content="true")
  inspect(styles_xml.contains("horizontal=\"center\""), content="true")
  inspect(styles_xml.contains("vertical=\"center\""), content="true")
  inspect(styles_xml.contains("wrapText=\"1\""), content="true")
  inspect(styles_xml.contains("textRotation=\"45\""), content="true")
  inspect(styles_xml.contains("indent=\"2\""), content="true")
  inspect(styles_xml.contains("shrinkToFit=\"1\""), content="true")
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::alignment(alignment))
}

///|
test "conditional style alignment write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let alignment = Alignment::with_values(wrap_text=true)
  let style_id = workbook.new_conditional_style(Style::alignment(alignment))
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
  inspect(
    styles_xml.contains("<dxf><alignment wrapText=\"1\"/>"),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_conditional_style(0), Style::alignment(alignment))
}

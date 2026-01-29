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
test "excelize currency num fmt decimal places + neg red" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let style = Style::excelize_currency_num_fmt(
    165,
    decimal_places=4,
    neg_red=true,
  )
  let style_id = workbook.add_style(style)
  sheet.set_cell("A1", "-1.23")
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
  inspect(
    styles_xml.contains(
      "formatCode=\"[$$-409]#,##0.0000;[Red][$$-409]#,##0.0000\"",
    ),
    content="true",
  )
}

///|
test "excelize custom num fmt empty rejects" {
  let result = try Style::excelize_custom_num_fmt("") catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result,
    content="Err(InvalidOptions(msg=\"custom number format can not be empty\"))",
  )
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
test "styles extLst roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let archive = @zip.read(write(workbook)) catch {
    err => fail("zip read failed: \{err}")
  }
  let styles_xml = match archive.get("xl/styles.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing styles.xml")
  }
  let ext_block = "  <extLst><ext uri=\"urn:mbtexcel:test\"><test xmlns=\"urn:mbtexcel:testns\"/></ext></extLst>\n"
  let updated_styles = styles_xml.replace_all(
    old="</styleSheet>",
    new="\{ext_block}</styleSheet>",
  )
  let updated_archive = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name != "xl/styles.xml" {
      updated_archive.add(
        entry.name,
        entry.data,
        compression=entry.compression,
        data_descriptor=entry.data_descriptor,
      )
    }
  }
  updated_archive.add("xl/styles.xml", @encoding/utf8.encode(updated_styles))
  let updated_bytes = @zip.write(updated_archive) catch {
    err => fail("zip write failed: \{err}")
  }
  let parsed = read(updated_bytes)
  let roundtrip = write(parsed)
  let roundtrip_archive = @zip.read(roundtrip) catch {
    err => fail("zip read failed: \{err}")
  }
  let roundtrip_styles = match roundtrip_archive.get("xl/styles.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing styles.xml")
  }
  inspect(
    roundtrip_styles.contains("uri=\"urn:mbtexcel:test\""),
    content="true",
  )
  inspect(
    roundtrip_styles.contains("xmlns=\"urn:mbtexcel:testns\""),
    content="true",
  )
}

///|
test "styles tableStyles defaults roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let archive = @zip.read(write(workbook)) catch {
    err => fail("zip read failed: \{err}")
  }
  let styles_xml = match archive.get("xl/styles.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing styles.xml")
  }
  let updated_styles = styles_xml
    .replace_all(
      old="defaultTableStyle=\"TableStyleMedium9\"",
      new="defaultTableStyle=\"TableStyleLight1\"",
    )
    .replace_all(
      old="defaultPivotStyle=\"PivotStyleLight16\"",
      new="defaultPivotStyle=\"PivotStyleMedium4\"",
    )
  let updated_archive = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name != "xl/styles.xml" {
      updated_archive.add(
        entry.name,
        entry.data,
        compression=entry.compression,
        data_descriptor=entry.data_descriptor,
      )
    }
  }
  updated_archive.add("xl/styles.xml", @encoding/utf8.encode(updated_styles))
  let updated_bytes = @zip.write(updated_archive) catch {
    err => fail("zip write failed: \{err}")
  }
  let parsed = read(updated_bytes)
  let roundtrip = write(parsed)
  let roundtrip_archive = @zip.read(roundtrip) catch {
    err => fail("zip read failed: \{err}")
  }
  let roundtrip_styles = match roundtrip_archive.get("xl/styles.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing styles.xml")
  }
  inspect(
    roundtrip_styles.contains("defaultTableStyle=\"TableStyleLight1\""),
    content="true",
  )
  inspect(
    roundtrip_styles.contains("defaultPivotStyle=\"PivotStyleMedium4\""),
    content="true",
  )
}

///|
test "cell style font write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let font = Font::with_values(
    bold=true,
    strike=true,
    shadow=true,
    size=14.0,
    color="FF0000",
    charset=1,
    family_number=1,
    scheme="minor",
    vert_align="superscript",
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
  inspect(styles_xml.contains("<strike/>"), content="true")
  inspect(styles_xml.contains("<shadow/>"), content="true")
  inspect(styles_xml.contains("sz val=\"14"), content="true")
  inspect(styles_xml.contains("color rgb=\"FFFF0000\""), content="true")
  inspect(styles_xml.contains("charset val=\"1\""), content="true")
  inspect(styles_xml.contains("<family val=\"1\""), content="true")
  inspect(styles_xml.contains("vertAlign val=\"superscript\""), content="true")
  inspect(styles_xml.contains("scheme val=\"minor\""), content="true")
  inspect(styles_xml.contains("name val=\"Arial\""), content="true")
  inspect(styles_xml.contains("fontId=\"1\""), content="true")
  inspect(styles_xml.contains("applyFont=\"1\""), content="true")
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::font(font))
}

///|
test "cell style font theme/indexed color write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let font = Font::with_values(
    bold=true,
    size=11.0,
    family="Calibri",
    color_theme=4,
    color_tint=0.25,
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
  inspect(
    styles_xml.contains("color theme=\"4\" tint=\"0.25\""),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::font(font))
}

///|
test "cell style font indexed color write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let font = Font::with_values(size=11.0, family="Calibri", color_indexed=2)
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
  inspect(styles_xml.contains("color indexed=\"2\""), content="true")
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
test "cell style fill transparency write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::solid("FF0000", transparency=50)
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
      "patternFill patternType=\"solid\"><fgColor rgb=\"80FF0000\"/>",
    ),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::fill(fill))
}

///|
test "cell style fill theme color write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::solid_theme(4, tint=0.25)
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
  inspect(
    styles_xml.contains(
      "patternFill patternType=\"solid\"><fgColor theme=\"4\" tint=\"0.25\"/>",
    ),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::fill(fill))
}

///|
test "cell style gradient fill write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::gradient("FF0000", "00FF00", shading=0)
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
  inspect(styles_xml.contains("<gradientFill degree=\"90\""), content="true")
  inspect(
    styles_xml.contains("<stop position=\"0\"><color rgb=\"FFFF0000\"/>"),
    content="true",
  )
  inspect(
    styles_xml.contains("<stop position=\"1\"><color rgb=\"FF00FF00\"/>"),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_style(style_id), Style::fill(fill))
}

///|
test "cell style gradient fill path variant write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::gradient("FF0000", "00FF00", shading=12)
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
  inspect(styles_xml.contains("<gradientFill type=\"path\""), content="true")
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
test "conditional style fill transparency write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::solid("00FF00", transparency=50)
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
      "<dxf><fill><patternFill patternType=\"solid\"><bgColor rgb=\"8000FF00\"/>",
    ),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_conditional_style(0), Style::fill(fill))
}

///|
test "conditional style fill theme color write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::solid_bg_theme(4, tint=0.25)
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
      "<dxf><fill><patternFill patternType=\"solid\"><bgColor theme=\"4\" tint=\"0.25\"/>",
    ),
    content="true",
  )
  let parsed = read(bytes)
  assert_eq(parsed.get_conditional_style(0), Style::fill(fill))
}

///|
test "conditional style gradient fill write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let fill = Fill::gradient("FF0000", "00FF00", shading=0)
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
    styles_xml.contains("<dxf><fill><gradientFill degree=\"90\""),
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
test "cell style diagonal border write + roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let borders : Array[Border] = [
    Border::with_values("diagonalUp", style=6, color="A020F0"),
    Border::with_values("diagonalDown", style=6, color="A020F0"),
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
  inspect(styles_xml.contains("diagonalUp=\"1\""), content="true")
  inspect(styles_xml.contains("diagonalDown=\"1\""), content="true")
  inspect(styles_xml.contains("<diagonal style=\"double\">"), content="true")
  inspect(styles_xml.contains("color rgb=\"FFA020F0\""), content="true")
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

///|
test "shape parsed on read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let shape = @xlsx.Shape::new(
    "C3",
    "rect",
    macro_name="MyMacro",
    text="Hello",
    fill_color="8EB9FF",
    fill_transparency=60,
    line_color="4286F4",
    line_width=1.2,
    name="Shape 1",
    alt_text="Alt",
    locked=false,
    print_object=false,
    positioning=TwoCell,
  )
  workbook.add_shape("Sheet1", shape)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(sheet.shapes().length(), content="1")
  let got = sheet.shapes()[0]
  inspect(got.reference, content="C3")
  inspect(got.cell, content="C3")
  inspect(got.shape_type, content="rect")
  inspect(got.macro_alias, content="MyMacro")
  inspect(got.macro_name, content="MyMacro")
  debug_inspect(got.format.name, content="Some(\"Shape 1\")")
  debug_inspect(got.format.alt_text, content="Some(\"Alt\")")
  debug_inspect(got.format.print_object, content="Some(false)")
  debug_inspect(got.format.locked, content="Some(false)")
  debug_inspect(got.format.positioning, content="Some(TwoCell)")
  debug_inspect(got.fill.color, content="Some(\"8EB9FF\")")
  debug_inspect(got.fill.transparency, content="Some(60)")
  inspect(got.fill_color, content="8EB9FF")
  inspect(got.fill_transparency, content="60")
  debug_inspect(got.line.color, content="Some(\"4286F4\")")
  inspect(got.line_color, content="4286F4")
  inspect(got.line.width is Some(_), content="true")
  inspect((got.line_width - 1.2).abs() < 0.0001, content="true")
  inspect(got.name, content="Shape 1")
  inspect(got.alt_text, content="Alt")
  inspect(got.locked, content="false")
  inspect(got.print_object, content="false")
  debug_inspect(got.positioning, content="TwoCell")
  inspect(got.paragraph.length() > 0, content="true")
  inspect(got.paragraph[0].text, content="Hello")
}

///|
test "native absolute shape geometry survives normalized roundtrip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_shape("Sheet1", @xlsx.Shape::new("A1", "rect"))
  let archive = @zip.read(@xlsx.write(workbook)) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let drawing_path = "xl/drawings/drawing1.xml"
  let absolute_drawing =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    #|  <xdr:absoluteAnchor>
    #|    <xdr:pos x="19050" y="28575"/>
    #|    <xdr:ext cx="95250" cy="190500"/>
    #|    <xdr:sp>
    #|      <xdr:nvSpPr><xdr:cNvPr id="1" name="Absolute shape"/><xdr:cNvSpPr/></xdr:nvSpPr>
    #|      <xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="95250" cy="190500"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr>
    #|    </xdr:sp>
    #|    <xdr:clientData/>
    #|  </xdr:absoluteAnchor >
    #|</xdr:wsDr>
  assert_true(
    archive.replace(drawing_path, @encoding/utf8.encode(absolute_drawing)),
  )
  let parsed = @xlsx.read(@zip.write(archive))
  let sheet = parsed.sheet("Sheet1").unwrap()
  inspect(sheet.shapes().length(), content="1")
  let shape = sheet.shapes()[0]
  inspect(shape.reference, content="A1")
  inspect(shape.width, content="10")
  inspect(shape.height, content="20")
  debug_inspect(shape.format.offset_x, content="Some(2)")
  debug_inspect(shape.format.offset_y, content="Some(3)")
  debug_inspect(shape.positioning, content="Absolute")

  let normalized = @xlsx.write(parsed)
  let normalized_archive = @zip.read(normalized) catch {
    err => fail("normalized zip read failed: \{repr(err)}")
  }
  let normalized_drawing = match normalized_archive.get(drawing_path) {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("normalized drawing utf8 decode failed")
      }
    None => fail("normalized drawing missing")
  }
  assert_true(
    normalized_drawing.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
  )
  assert_true(normalized_drawing.contains("<xdr:colOff>19050</xdr:colOff>"))
  assert_true(normalized_drawing.contains("<xdr:rowOff>28575</xdr:rowOff>"))
  let reparsed = @xlsx.read(normalized)
  let reparsed_shape = reparsed.sheet("Sheet1").unwrap().shapes()[0]
  inspect(reparsed_shape.width, content="10")
  inspect(reparsed_shape.height, content="20")
  debug_inspect(reparsed_shape.format.offset_x, content="Some(2)")
  debug_inspect(reparsed_shape.format.offset_y, content="Some(3)")
  debug_inspect(reparsed_shape.positioning, content="Absolute")
}

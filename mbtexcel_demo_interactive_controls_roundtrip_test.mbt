///|
fn assert_demo_interactive_controls_archive(bytes : Bytes) -> Unit raise {
  let archive = @zip.read(bytes)
  inspect(archive.get("xl/worksheets/sheet1.xml") is Some(_), content="true")
  inspect(archive.get("xl/worksheets/sheet2.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/worksheets/_rels/sheet1.xml.rels") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/drawings/drawing1.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/drawings/_rels/drawing1.xml.rels") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/drawings/vmlDrawing1.vml") is Some(_), content="true")
  inspect(archive.get("xl/charts/chart1.xml") is Some(_), content="true")

  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  let sheet_rels = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 rels")
  }
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }

  let workbook_ids = demo_rel_attr_values(workbook_rels, "Id")
  let sheet_ids = demo_rel_attr_values(sheet_rels, "Id")
  let drawing_ids = demo_rel_attr_values(drawing_rels, "Id")
  let sheet_targets = demo_rel_attr_values(sheet_rels, "Target")
  let drawing_targets = demo_rel_attr_values(drawing_rels, "Target")
  inspect(demo_unique(workbook_ids), content="true")
  inspect(demo_unique(sheet_ids), content="true")
  inspect(demo_unique(drawing_ids), content="true")
  inspect(
    demo_has_value(sheet_targets, "../drawings/drawing1.xml"),
    content="true",
  )
  inspect(
    demo_has_value(sheet_targets, "../drawings/vmlDrawing1.vml"),
    content="true",
  )
  inspect(
    demo_has_value(drawing_targets, "../charts/chart1.xml"),
    content="true",
  )

  let sheet1_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 xml")
  }
  inspect(sheet1_xml.contains("<drawing r:id="), content="true")
  inspect(sheet1_xml.contains("<legacyDrawing r:id="), content="true")
  inspect(sheet1_xml.contains("<dataValidations count=\"2\">"), content="true")

  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook xml")
  }
  inspect(
    workbook_xml.contains("<definedName name=\"BasePrice\">"),
    content="true",
  )
  inspect(
    workbook_xml.contains("<definedName name=\"ShippingOn\">"),
    content="true",
  )

  let vml_xml = match archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing vml drawing")
  }
  inspect(vml_xml.contains("ObjectType=\"Scroll\""), content="true")
  inspect(vml_xml.contains("ObjectType=\"Spin\""), content="true")
  inspect(vml_xml.contains("ObjectType=\"Checkbox\""), content="true")
  inspect(vml_xml.contains("<x:FmlaLink>B4</x:FmlaLink>"), content="true")
  inspect(vml_xml.contains("<x:FmlaLink>B5</x:FmlaLink>"), content="true")
  inspect(vml_xml.contains("<x:FmlaLink>B6</x:FmlaLink>"), content="true")

  let content_types = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.vmlDrawing\"",
    ),
    content="true",
  )
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.chart+xml\"",
    ),
    content="true",
  )
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.drawing+xml\"",
    ),
    content="true",
  )
}

///|
test "demo interactive controls: writer output remains consistent after roundtrip" {
  let bytes = @demos.demo_interactive_controls_bytes()
  assert_demo_interactive_controls_archive(bytes)

  let parsed = read(bytes)
  debug_inspect(parsed.sheet_name(0), content="Some(\"UI\")")
  debug_inspect(parsed.sheet_name(1), content="Some(\"Model\")")

  let roundtrip_bytes = write(parsed)
  assert_demo_interactive_controls_archive(roundtrip_bytes)
}

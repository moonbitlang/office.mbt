///|
fn assert_demo_combo_chart_archive(bytes : Bytes) -> Unit raise {
  let archive = @zip.read(bytes)
  inspect(archive.get("xl/charts/chart1.xml") is Some(_), content="true")
  inspect(archive.get("xl/drawings/drawing1.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/worksheets/_rels/sheet1.xml.rels") is Some(_),
    content="true",
  )
  inspect(
    archive.get("xl/drawings/_rels/drawing1.xml.rels") is Some(_),
    content="true",
  )

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
    demo_has_value(drawing_targets, "../charts/chart1.xml"),
    content="true",
  )

  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 xml")
  }
  inspect(sheet_xml.contains("<drawing r:id=\"rId1\"/>"), content="true")

  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing xml")
  }
  inspect(
    drawing_xml.contains(
      "uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"",
    ),
    content="true",
  )
  inspect(drawing_xml.contains("<c:chart"), content="true")
  inspect(drawing_xml.contains("r:id=\"rId1\""), content="true")

  let content_types = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
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
test "demo combo chart: writer output remains consistent after roundtrip" {
  let bytes = @demos.demo_combo_chart_bytes()
  assert_demo_combo_chart_archive(bytes)

  let roundtrip_bytes = @mbtexcel.write(@mbtexcel.read(bytes))
  assert_demo_combo_chart_archive(roundtrip_bytes)
}

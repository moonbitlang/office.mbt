///|
fn assert_demo_dashboard_archive(bytes : Bytes) -> Unit raise {
  let archive = @zip.read(bytes)
  inspect(archive.get("xl/worksheets/sheet1.xml") is Some(_), content="true")
  inspect(archive.get("xl/worksheets/sheet2.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/worksheets/_rels/sheet1.xml.rels") is Some(_),
    content="true",
  )
  inspect(
    archive.get("xl/worksheets/_rels/sheet2.xml.rels") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/tables/table1.xml") is Some(_), content="true")
  inspect(archive.get("xl/charts/chart1.xml") is Some(_), content="true")
  inspect(archive.get("xl/drawings/drawing2.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/drawings/_rels/drawing2.xml.rels") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/media/image1.png") is Some(_), content="true")
  inspect(archive.get("xl/calcChain.xml") is Some(_), content="true")

  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  let sheet1_rels = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 rels")
  }
  let sheet2_rels = match archive.get("xl/worksheets/_rels/sheet2.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet2 rels")
  }
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing2.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }

  let workbook_ids = demo_rel_attr_values(workbook_rels, "Id")
  let workbook_targets = demo_rel_attr_values(workbook_rels, "Target")
  let sheet1_ids = demo_rel_attr_values(sheet1_rels, "Id")
  let sheet1_targets = demo_rel_attr_values(sheet1_rels, "Target")
  let sheet2_ids = demo_rel_attr_values(sheet2_rels, "Id")
  let sheet2_targets = demo_rel_attr_values(sheet2_rels, "Target")
  let drawing_ids = demo_rel_attr_values(drawing_rels, "Id")
  let drawing_targets = demo_rel_attr_values(drawing_rels, "Target")
  inspect(demo_unique(workbook_ids), content="true")
  inspect(demo_unique(sheet1_ids), content="true")
  inspect(demo_unique(sheet2_ids), content="true")
  inspect(demo_unique(drawing_ids), content="true")
  inspect(
    demo_has_value(workbook_targets, "worksheets/sheet1.xml"),
    content="true",
  )
  inspect(
    demo_has_value(workbook_targets, "worksheets/sheet2.xml"),
    content="true",
  )
  inspect(demo_has_value(workbook_targets, "calcChain.xml"), content="true")
  inspect(
    demo_has_value(sheet1_targets, "../tables/table1.xml"),
    content="true",
  )
  inspect(
    demo_has_value(sheet2_targets, "../drawings/drawing2.xml"),
    content="true",
  )
  inspect(
    demo_has_value(drawing_targets, "../media/image1.png"),
    content="true",
  )
  inspect(
    demo_has_value(drawing_targets, "../charts/chart1.xml"),
    content="true",
  )

  let sheet2_xml = match archive.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet2 xml")
  }
  inspect(sheet2_xml.contains("<drawing r:id="), content="true")

  let drawing_xml = match archive.get("xl/drawings/drawing2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing xml")
  }
  inspect(drawing_xml.contains("<a:blip r:embed=\"rId1\"/>"), content="true")
  inspect(drawing_xml.contains("<c:chart"), content="true")
  inspect(drawing_xml.contains("r:id=\"rId2\""), content="true")

  let content_types = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(content_types.contains("ContentType=\"image/png\""), content="true")
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml\"",
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
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.calcChain+xml\"",
    ),
    content="true",
  )
}

///|
test "demo dashboard: writer output remains consistent after roundtrip" {
  let bytes = @demos.demo_dashboard_bytes()
  assert_demo_dashboard_archive(bytes)

  let parsed = @mbtexcel.read(bytes)
  debug_inspect(parsed.sheet_name(0), content="Some(\"Data\")")
  debug_inspect(parsed.sheet_name(1), content="Some(\"Dashboard\")")

  let roundtrip_bytes = @mbtexcel.write(parsed)
  assert_demo_dashboard_archive(roundtrip_bytes)
}

///|
fn assert_demo_ooxml_showcase_archive(bytes : Bytes) -> Unit raise {
  let archive = @zip.read(bytes)
  inspect(archive.get("xl/worksheets/sheet1.xml") is Some(_), content="true")
  inspect(archive.get("xl/worksheets/sheet2.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/worksheets/_rels/sheet1.xml.rels") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/comments1.xml") is Some(_), content="true")
  inspect(archive.get("xl/drawings/vmlDrawing1.vml") is Some(_), content="true")
  inspect(archive.get("xl/drawings/vmlDrawing2.vml") is Some(_), content="true")
  inspect(
    archive.get("xl/drawings/_rels/vmlDrawing2.vml.rels") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/media/image1.png") is Some(_), content="true")
  inspect(archive.get("xl/media/image2.png") is Some(_), content="true")

  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  let sheet1_rels = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 rels")
  }
  let vml2_rels = match archive.get("xl/drawings/_rels/vmlDrawing2.vml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing vmlDrawing2 rels")
  }

  let workbook_ids = demo_rel_attr_values(workbook_rels, "Id")
  let workbook_targets = demo_rel_attr_values(workbook_rels, "Target")
  let sheet1_ids = demo_rel_attr_values(sheet1_rels, "Id")
  let sheet1_targets = demo_rel_attr_values(sheet1_rels, "Target")
  let vml2_ids = demo_rel_attr_values(vml2_rels, "Id")
  let vml2_targets = demo_rel_attr_values(vml2_rels, "Target")
  inspect(demo_unique(workbook_ids[:]), content="true")
  inspect(demo_unique(sheet1_ids[:]), content="true")
  inspect(demo_unique(vml2_ids[:]), content="true")
  inspect(
    demo_has_value(workbook_targets[:], "worksheets/sheet1.xml"),
    content="true",
  )
  inspect(
    demo_has_value(workbook_targets[:], "worksheets/sheet2.xml"),
    content="true",
  )
  inspect(demo_has_value(sheet1_targets[:], "../comments1.xml"), content="true")
  inspect(
    demo_has_value(sheet1_targets[:], "../drawings/vmlDrawing1.vml"),
    content="true",
  )
  inspect(
    demo_has_value(sheet1_targets[:], "../drawings/vmlDrawing2.vml"),
    content="true",
  )
  inspect(
    demo_has_value(sheet1_targets[:], "../media/image2.png"),
    content="true",
  )
  inspect(
    demo_has_value(sheet1_targets[:], "https://github.com/xuri/excelize"),
    content="true",
  )
  inspect(
    demo_has_value(vml2_targets[:], "../media/image1.png"),
    content="true",
  )

  let sheet1_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 xml")
  }
  inspect(sheet1_xml.contains("<legacyDrawing r:id="), content="true")
  inspect(sheet1_xml.contains("<legacyDrawingHF r:id="), content="true")
  inspect(sheet1_xml.contains("<picture r:id="), content="true")
  inspect(
    sheet1_xml.contains("location=\"Data!A1\" display=\"Jump to Data!A1\""),
    content="true",
  )

  let comments_xml = match archive.get("xl/comments1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing comments1 xml")
  }
  inspect(comments_xml.contains("<author>mbtexcel</author>"), content="true")
  inspect(comments_xml.contains("<comment ref=\"C5\""), content="true")

  let content_types = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml\"",
    ),
    content="true",
  )
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.vmlDrawing\"",
    ),
    content="true",
  )
  inspect(content_types.contains("ContentType=\"image/png\""), content="true")
}

///|
test "demo ooxml showcase: writer output remains consistent after roundtrip" {
  let bytes = @demos.demo_ooxml_showcase_bytes()
  assert_demo_ooxml_showcase_archive(bytes)

  let parsed = read(bytes)
  debug_inspect(parsed.sheet_name(0), content="Some(\"Showcase\")")
  debug_inspect(parsed.sheet_name(1), content="Some(\"Data\")")

  let roundtrip_bytes = write(parsed)
  assert_demo_ooxml_showcase_archive(roundtrip_bytes)
}

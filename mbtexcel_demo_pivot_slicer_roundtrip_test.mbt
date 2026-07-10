///|
fn assert_demo_pivot_slicer_archive(bytes : Bytes) -> Unit raise {
  let archive = @zip.read(bytes)
  inspect(
    archive.get("xl/slicerCaches/slicerCache1.xml") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/slicers/slicer1.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/pivotCache/pivotCacheDefinition1.xml") is Some(_),
    content="true",
  )
  inspect(
    archive.get("xl/pivotTables/pivotTable1.xml") is Some(_),
    content="true",
  )
  inspect(
    archive.get("xl/worksheets/_rels/sheet2.xml.rels") is Some(_),
    content="true",
  )

  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  let sheet_rels = match archive.get("xl/worksheets/_rels/sheet2.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet2 rels")
  }
  let workbook_targets = demo_rel_attr_values(workbook_rels, "Target")
  let workbook_ids = demo_rel_attr_values(workbook_rels, "Id")
  let sheet_targets = demo_rel_attr_values(sheet_rels, "Target")
  let sheet_ids = demo_rel_attr_values(sheet_rels, "Id")
  inspect(demo_unique(workbook_ids), content="true")
  inspect(demo_unique(sheet_ids), content="true")
  inspect(
    demo_has_value(workbook_targets, "slicerCaches/slicerCache1.xml"),
    content="true",
  )
  inspect(
    demo_has_value(workbook_targets, "pivotCache/pivotCacheDefinition1.xml"),
    content="true",
  )
  inspect(
    demo_has_value(sheet_targets, "../slicers/slicer1.xml"),
    content="true",
  )
  inspect(
    demo_has_value(sheet_targets, "../pivotTables/pivotTable1.xml"),
    content="true",
  )

  let sheet_xml = match archive.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet2 xml")
  }
  inspect(sheet_xml.contains("mc:Ignorable=\"x14\""), content="true")
  inspect(sheet_xml.contains("<x14:slicerList"), content="true")

  let slicer_cache_xml = match archive.get("xl/slicerCaches/slicerCache1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing slicer cache xml")
  }
  inspect(slicer_cache_xml.contains("<pivotTables>"), content="true")
  inspect(
    slicer_cache_xml.contains("<pivotTable tabId=\"2\" name=\"PivotTable1\"/>"),
    content="true",
  )
  inspect(slicer_cache_xml.contains("pivotCacheId=\"1\""), content="true")
  inspect(
    slicer_cache_xml.contains(
      "xmlns:xr10=\"http://schemas.microsoft.com/office/spreadsheetml/2016/revision10\"",
    ),
    content="true",
  )

  let slicer_xml = match archive.get("xl/slicers/slicer1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing slicer xml")
  }
  inspect(slicer_xml.contains("cache=\"Slicer_Region\""), content="true")
  inspect(slicer_xml.contains("caption=\"Region\""), content="true")

  let content_types = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.ms-excel.slicer+xml\"",
    ),
    content="true",
  )
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.ms-excel.slicerCache+xml\"",
    ),
    content="true",
  )
}

///|
test "demo pivot slicer: writer output remains consistent after roundtrip" {
  let bytes = @demos.demo_pivot_slicer_bytes()
  assert_demo_pivot_slicer_archive(bytes)

  let roundtrip_bytes = write(read(bytes))
  assert_demo_pivot_slicer_archive(roundtrip_bytes)
}

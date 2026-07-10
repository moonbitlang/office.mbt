///|
fn assert_demo_stream_archive(bytes : Bytes, rows : Int) -> Unit raise {
  let archive = @zip.read(bytes)
  inspect(archive.get("xl/worksheets/sheet1.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/worksheets/_rels/sheet1.xml.rels") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/tables/table1.xml") is Some(_), content="true")
  inspect(archive.get("xl/sharedStrings.xml") is Some(_), content="true")

  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  let sheet_rels = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 rels")
  }
  let workbook_ids = demo_rel_attr_values(workbook_rels, "Id")
  let sheet_ids = demo_rel_attr_values(sheet_rels, "Id")
  let sheet_targets = demo_rel_attr_values(sheet_rels, "Target")
  inspect(demo_unique(workbook_ids), content="true")
  inspect(demo_unique(sheet_ids), content="true")
  inspect(demo_has_value(sheet_targets, "../tables/table1.xml"), content="true")

  let end_row = rows + 1
  let range_ref = "A1:E\{end_row}"
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 xml")
  }
  inspect(sheet_xml.contains("dimension ref=\"\{range_ref}\""), content="true")
  inspect(sheet_xml.contains("<tablePart r:id=\"rId1\"/>"), content="true")

  let table_xml = match archive.get("xl/tables/table1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing table xml")
  }
  inspect(table_xml.contains("ref=\"\{range_ref}\""), content="true")
  inspect(
    table_xml.contains("<autoFilter ref=\"\{range_ref}\"/>"),
    content="true",
  )

  let content_types = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml\"",
    ),
    content="true",
  )
}

///|
test "demo stream big: writer output remains consistent after roundtrip" {
  let rows = 3000
  let bytes = @demos.demo_stream_big_bytes(rows~)
  assert_demo_stream_archive(bytes, rows)

  let parsed = @mbtexcel.read(bytes)
  inspect(parsed.get_cell("Big", "A1") is Some(_), content="true")
  inspect(parsed.get_cell("Big", "A3001") is Some(_), content="true")

  let roundtrip_bytes = @mbtexcel.write(parsed)
  assert_demo_stream_archive(roundtrip_bytes, rows)
}

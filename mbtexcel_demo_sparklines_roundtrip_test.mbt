///|
fn demo_count_tag(xml : String, tag : String) -> Int {
  let mut count = 0
  let mut first = true
  for _ in xml.split(tag) {
    if first {
      first = false
      continue
    }
    count = count + 1
  }
  count
}

///|
fn assert_demo_sparklines_archive(bytes : Bytes) -> Unit raise {
  let archive = @zip.read(bytes)
  inspect(archive.get("xl/worksheets/sheet1.xml") is Some(_), content="true")
  inspect(archive.get("xl/sharedStrings.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/worksheets/_rels/sheet1.xml.rels") is None,
    content="true",
  )

  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  let workbook_ids = demo_rel_attr_values(workbook_rels, "Id")
  let workbook_targets = demo_rel_attr_values(workbook_rels, "Target")
  inspect(demo_unique(workbook_ids[:]), content="true")
  inspect(
    demo_has_value(workbook_targets[:], "worksheets/sheet1.xml"),
    content="true",
  )
  inspect(
    demo_has_value(workbook_targets[:], "sharedStrings.xml"),
    content="true",
  )

  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 xml")
  }
  inspect(sheet_xml.contains("mc:Ignorable=\"x14\""), content="true")
  inspect(sheet_xml.contains("<x14:sparklineGroups"), content="true")
  inspect(sheet_xml.contains("xmlns:xm="), content="true")
  inspect(demo_count_tag(sheet_xml, "<x14:sparkline>"), content="4")
  inspect(demo_count_tag(sheet_xml, "<xm:f>"), content="4")
  inspect(demo_count_tag(sheet_xml, "<xm:sqref>"), content="4")

  let content_types = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"",
    ),
    content="true",
  )
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"",
    ),
    content="true",
  )
}

///|
test "demo sparklines: writer output remains consistent after roundtrip" {
  let bytes = @demos.demo_sparklines_bytes()
  assert_demo_sparklines_archive(bytes)

  let parsed = read(bytes)
  let kpi = match parsed.sheet("KPI") {
    Some(value) => value
    None => fail("missing KPI sheet")
  }
  inspect(kpi.sparkline_groups().length(), content="1")
  inspect(kpi.sparkline_groups()[0].sparklines.length(), content="4")

  let roundtrip_bytes = write(parsed)
  assert_demo_sparklines_archive(roundtrip_bytes)
}

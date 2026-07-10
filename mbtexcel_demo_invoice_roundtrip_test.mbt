///|
fn assert_demo_invoice_archive(bytes : Bytes) -> Unit raise {
  let archive = @zip.read(bytes)
  inspect(archive.get("xl/worksheets/sheet1.xml") is Some(_), content="true")
  inspect(archive.get("xl/sharedStrings.xml") is Some(_), content="true")
  inspect(archive.get("xl/calcChain.xml") is Some(_), content="true")
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
  inspect(demo_unique(workbook_ids), content="true")
  inspect(
    demo_has_value(workbook_targets, "worksheets/sheet1.xml"),
    content="true",
  )
  inspect(demo_has_value(workbook_targets, "sharedStrings.xml"), content="true")
  inspect(demo_has_value(workbook_targets, "calcChain.xml"), content="true")

  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1 xml")
  }
  inspect(sheet_xml.contains("<sheetProtection "), content="true")
  inspect(sheet_xml.contains("pivotTables=\"1\""), content="true")
  inspect(sheet_xml.contains("<dataValidations count=\"1\">"), content="true")
  inspect(
    sheet_xml.contains("<formula1>\"Draft,Sent,Paid,Overdue\"</formula1>"),
    content="true",
  )
  inspect(demo_count_tag(sheet_xml, "<f>"), content="6")

  let calc_chain_xml = match archive.get("xl/calcChain.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing calcChain xml")
  }
  inspect(demo_count_tag(calc_chain_xml, "<c r="), content="6")
  inspect(calc_chain_xml.contains("r=\"F9\""), content="true")
  inspect(calc_chain_xml.contains("r=\"F15\""), content="true")

  let content_types = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(
    content_types.contains(
      "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.calcChain+xml\"",
    ),
    content="true",
  )
}

///|
test "demo invoice: writer output remains consistent after roundtrip" {
  let bytes = @demos.demo_invoice_bytes()
  assert_demo_invoice_archive(bytes)

  let parsed = read(bytes)
  debug_inspect(parsed.sheet_name(0), content="Some(\"Invoice\")")
  debug_inspect(parsed.get_cell("Invoice", "F5"), content="Some(\"Draft\")")
  debug_inspect(parsed.get_cell("Invoice", "F15"), content="Some(\"0\")")

  let roundtrip_bytes = write(parsed)
  assert_demo_invoice_archive(roundtrip_bytes)
}

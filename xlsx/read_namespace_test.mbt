///|
fn namespace_qualified_xlsx_fixture(
  strict : Bool,
  entity_paths : Bool,
) -> Bytes raise {
  let spreadsheet_namespace = if strict {
    "http://purl.oclc.org/ooxml/spreadsheetml/main"
  } else {
    "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  }
  let office_relationship_prefix = if strict {
    "http://purl.oclc.org/ooxml/officeDocument/relationships/"
  } else {
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
  }
  let office_relationship_namespace = if strict {
    "http://purl.oclc.org/ooxml/officeDocument/relationships"
  } else {
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  }
  let workbook_path = if entity_paths {
    "custom/a&b.xml"
  } else {
    "xl/workbook.xml"
  }
  let workbook_part_name = if entity_paths {
    "/custom/a&amp;b.xml"
  } else {
    "/xl/workbook.xml"
  }
  let workbook_rels_path = if entity_paths {
    "custom/_rels/a&b.xml.rels"
  } else {
    "xl/_rels/workbook.xml.rels"
  }
  let worksheet_path = if entity_paths {
    "data/a b.xml"
  } else {
    "xl/worksheets/sheet.xml"
  }
  let worksheet_part_name = if entity_paths {
    "/data/a&#x20;b.xml"
  } else {
    "/xl/worksheets/sheet.xml"
  }
  let worksheet_target = if entity_paths {
    "../data/a&#x20;b.xml"
  } else {
    "worksheets/sheet.xml"
  }
  let relationship_id = if entity_paths { "sheet&amp;1" } else { "sheet" }
  let root_target = if entity_paths {
    "custom/a&amp;b.xml"
  } else {
    "xl/workbook.xml"
  }
  let content_types = "<ct:Types xmlns:ct=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n" +
    "  <ct:Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>\n" +
    "  <ct:Override PartName=\"\{workbook_part_name}\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>\n" +
    "  <ct:Override PartName=\"\{worksheet_part_name}\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>\n" +
    "  <ct:Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>\n" +
    "</ct:Types>"
  let root_relationships = "<pkg:Relationships xmlns:pkg=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
    "  <pkg:Relationship Id=\"main\" Type=\"\{office_relationship_prefix}officeDocument\" Target=\"\{root_target}\"/>\n" +
    "</pkg:Relationships>"
  let workbook = "<s:workbook xmlns:s=\"\{spreadsheet_namespace}\" xmlns:q=\"\{office_relationship_namespace}\">\n" +
    "  <s:workbookPr date1904=\"1\" codeName=\"QualifiedBook\"/>\n" +
    "  <s:bookViews><s:workbookView activeTab=\"0\"/></s:bookViews>\n" +
    "  <s:sheets><s:sheet name=\"Qualified\" sheetId=\"1\" q:id=\"\{relationship_id}\"/></s:sheets>\n" +
    "  <s:workbookProtection lockStructure=\"1\"/>\n" +
    "  <s:calcPr calcId=\"123\" refMode=\"R1C1\"/>\n" +
    "</s:workbook>"
  let shared_strings_target = if entity_paths {
    "../xl/sharedStrings.xml"
  } else {
    "sharedStrings.xml"
  }
  let workbook_relationships = "<r:Relationships xmlns:r=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
    "  <r:Relationship Id=\"\{relationship_id}\" Type=\"\{office_relationship_prefix}worksheet\" Target=\"\{worksheet_target}\"/>\n" +
    "  <r:Relationship Id=\"strings\" Type=\"\{office_relationship_prefix}sharedStrings\" Target=\"\{shared_strings_target}\"/>\n" +
    "</r:Relationships>"
  let worksheet = "<s:worksheet xmlns:s=\"\{spreadsheet_namespace}\"><s:sheetPr codeName=\"QualifiedSheet\"/><s:dimension ref=\"A1:B1\"/><s:sheetViews><s:sheetView workbookViewId=\"0\"/></s:sheetViews><s:sheetData><s:row r=\"1\"><s:c r=\"A1\" t=\"s\"><s:v>0</s:v></s:c></s:row></s:sheetData><s:mergeCells count=\"1\"><s:mergeCell ref=\"A1:B1\"/></s:mergeCells><s:sheetProtection sheet=\"1\"/></s:worksheet>"
  let shared_strings = "<s:sst xmlns:s=\"\{spreadsheet_namespace}\" count=\"1\" uniqueCount=\"1\"><s:si><s:t>qualified-value</s:t></s:si></s:sst>"
  let archive = @zip.Archive::new()
  archive.add("[Content_Types].xml", @encoding/utf8.encode(content_types))
  archive.add("_rels/.rels", @encoding/utf8.encode(root_relationships))
  archive.add(workbook_path, @encoding/utf8.encode(workbook))
  archive.add(workbook_rels_path, @encoding/utf8.encode(workbook_relationships))
  archive.add(worksheet_path, @encoding/utf8.encode(worksheet))
  archive.add("xl/sharedStrings.xml", @encoding/utf8.encode(shared_strings))
  @zip.write(archive)
}

///|
test "namespace-qualified Transitional and Strict workbook parts read end to end" {
  for strict in [false, true] {
    let workbook = @xlsx.read(namespace_qualified_xlsx_fixture(strict, false))
    debug_inspect(workbook.get_sheet_list(), content="[\"Qualified\"]")
    debug_inspect(
      workbook.get_cell_value("Qualified", "A1"),
      content="Some(\"qualified-value\")",
    )
    assert_eq(workbook.get_workbook_props().date_1904, Some(true))
    assert_eq(workbook.get_workbook_props().code_name, Some("QualifiedBook"))
    assert_eq(workbook.get_calc_props().calc_id, Some(123U))
    assert_eq(workbook.get_calc_props().ref_mode, Some("R1C1"))
    assert_eq(workbook.get_merge_cells("Qualified"), ["A1:B1"])
    let rewritten = @zip.read(@xlsx.write(workbook))
    guard rewritten.get("xl/workbook.xml") is Some(workbook_xml) else {
      fail("missing rewritten workbook")
    }
    let workbook_text = @encoding/utf8.decode(workbook_xml) catch {
      _ => fail("rewritten workbook is not UTF-8")
    }
    assert_true(workbook_text.contains("<workbookProtection"))
    assert_true(workbook_text.contains("lockStructure=\"1\""))
  }
}

///|
test "main-part names, relationship targets, and ids decode XML entities" {
  let workbook = @xlsx.read(namespace_qualified_xlsx_fixture(false, true))
  debug_inspect(workbook.get_sheet_list(), content="[\"Qualified\"]")
  debug_inspect(
    workbook.get_cell_value("Qualified", "A1"),
    content="Some(\"qualified-value\")",
  )
}

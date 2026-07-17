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
    "</ct:Types>"
  let root_relationships = "<pkg:Relationships xmlns:pkg=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
    "  <pkg:Relationship Id=\"main\" Type=\"\{office_relationship_prefix}officeDocument\" Target=\"\{root_target}\"/>\n" +
    "</pkg:Relationships>"
  let workbook = "<s:workbook xmlns:s=\"\{spreadsheet_namespace}\" xmlns:q=\"\{office_relationship_namespace}\">\n" +
    "  <s:sheets><s:sheet name=\"Qualified\" sheetId=\"1\" q:id=\"\{relationship_id}\"/></s:sheets>\n" +
    "</s:workbook>"
  let workbook_relationships = "<r:Relationships xmlns:r=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
    "  <r:Relationship Id=\"\{relationship_id}\" Type=\"\{office_relationship_prefix}worksheet\" Target=\"\{worksheet_target}\"/>\n" +
    "</r:Relationships>"
  let worksheet = "<worksheet xmlns=\"\{spreadsheet_namespace}\"><sheetData><row r=\"1\"><c r=\"A1\" t=\"str\"><v>qualified-value</v></c></row></sheetData></worksheet>"
  let archive = @zip.Archive::new()
  archive.add("[Content_Types].xml", @encoding/utf8.encode(content_types))
  archive.add("_rels/.rels", @encoding/utf8.encode(root_relationships))
  archive.add(workbook_path, @encoding/utf8.encode(workbook))
  archive.add(workbook_rels_path, @encoding/utf8.encode(workbook_relationships))
  archive.add(worksheet_path, @encoding/utf8.encode(worksheet))
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

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
    "data/a%20b.xml"
  } else {
    "xl/worksheets/sheet.xml"
  }
  let worksheet_part_name = if entity_paths {
    "/data/a&#x25;20b.xml"
  } else {
    "/xl/worksheets/sheet.xml"
  }
  let worksheet_target = if entity_paths {
    "../data/a&#x25;20b.xml"
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
fn unicode_part_name_xlsx_fixture() -> Bytes raise {
  let spreadsheet_namespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  let relationship_namespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  let relationship_prefix = relationship_namespace + "/"
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    #|  <Override PartName="/custom/文.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    #|  <Override PartName="/xl/worksheets/sheet.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
    #|  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
    #|</Types>
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/文.xml"/>
    #|</Relationships>
  let workbook = "<workbook xmlns=\"\{spreadsheet_namespace}\" xmlns:r=\"\{relationship_namespace}\"><sheets><sheet name=\"Unicode\" sheetId=\"1\" r:id=\"sheet\"/></sheets></workbook>"
  let workbook_relationships = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"sheet\" Type=\"\{relationship_prefix}worksheet\" Target=\"../xl/worksheets/sheet.xml\"/><Relationship Id=\"strings\" Type=\"\{relationship_prefix}sharedStrings\" Target=\"../xl/sharedStrings.xml\"/></Relationships>"
  let worksheet = "<worksheet xmlns=\"\{spreadsheet_namespace}\"><sheetData><row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c></row></sheetData></worksheet>"
  let shared_strings = "<sst xmlns=\"\{spreadsheet_namespace}\" count=\"1\" uniqueCount=\"1\"><si><t>unicode-part</t></si></sst>"
  let archive = @zip.Archive::new()
  archive.add("[Content_Types].xml", @encoding/utf8.encode(content_types))
  archive.add("_rels/.rels", @encoding/utf8.encode(root_relationships))
  archive.add("custom/%E6%96%87.xml", @encoding/utf8.encode(workbook))
  archive.add(
    "custom/_rels/%E6%96%87.xml.rels",
    @encoding/utf8.encode(workbook_relationships),
  )
  archive.add("xl/worksheets/sheet.xml", @encoding/utf8.encode(worksheet))
  archive.add("xl/sharedStrings.xml", @encoding/utf8.encode(shared_strings))
  @zip.write(archive)
}

///|
test "physical ZIP names follow Unicode logical OPC part names end to end" {
  let workbook = @xlsx.read(unicode_part_name_xlsx_fixture())
  debug_inspect(workbook.get_sheet_list(), content="[\"Unicode\"]")
  debug_inspect(
    workbook.get_cell_value("Unicode", "A1"),
    content="Some(\"unicode-part\")",
  )
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

///|
test "mixed-case workbook media type reads end to end" {
  let archive = @zip.read(namespace_qualified_xlsx_fixture(false, false))
  guard archive.get("[Content_Types].xml") is Some(content_type_bytes) else {
    fail("missing content types fixture part")
  }
  let content_types = @encoding/utf8.decode(content_type_bytes) catch {
    _ => fail("content types fixture is not UTF-8")
  }
  let original = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"
  let mixed = "Application/Vnd.Openxmlformats-Officedocument.Spreadsheetml.Sheet.Main+Xml"
  let updated = content_types.replace(old=original, new=mixed)
  if updated == content_types {
    fail("workbook media type marker was not found")
  }
  assert_true(
    archive.replace("[Content_Types].xml", @encoding/utf8.encode(updated)),
  )
  let parsed = @xlsx.read(@zip.write(archive))
  debug_inspect(parsed.get_sheet_list(), content="[\"Qualified\"]")
  debug_inspect(
    parsed.get_cell_value("Qualified", "A1"),
    content="Some(\"qualified-value\")",
  )
}

///|
test "mixed-case content-type PartName matches the workbook part" {
  let archive = @zip.read(namespace_qualified_xlsx_fixture(false, false))
  guard archive.get("[Content_Types].xml") is Some(content_type_bytes) else {
    fail("missing content types fixture part")
  }
  let content_types = @encoding/utf8.decode(content_type_bytes) catch {
    _ => fail("content types fixture is not UTF-8")
  }
  let updated = content_types.replace(
    old="PartName=\"/xl/workbook.xml\"",
    new="PartName=\"/XL/WORKBOOK.XML\"",
  )
  if updated == content_types {
    fail("workbook PartName marker was not found")
  }
  assert_true(
    archive.replace("[Content_Types].xml", @encoding/utf8.encode(updated)),
  )
  let parsed = @xlsx.read(@zip.write(archive))
  debug_inspect(parsed.get_sheet_list(), content="[\"Qualified\"]")
  debug_inspect(
    parsed.get_cell_value("Qualified", "A1"),
    content="Some(\"qualified-value\")",
  )
}

///|
test "SpreadsheetML-looking extension payload cannot create sheets or cells" {
  for strict in [false, true] {
    let bytes = namespace_qualified_xlsx_fixture(strict, false)
    let archive = @zip.read(bytes)
    guard archive.get("xl/workbook.xml") is Some(workbook_bytes) else {
      fail("missing workbook fixture part")
    }
    let workbook_xml = @encoding/utf8.decode(workbook_bytes) catch {
      _ => fail("workbook fixture is not UTF-8")
    }
    let workbook_with_decoy = workbook_xml.replace(
      old="  <s:sheets>",
      new="  <s:extLst><s:ext uri=\"urn:mbtexcel:decoy\"><s:sheet name=\"Decoy\" sheetId=\"99\" q:id=\"sheet\"/></s:ext></s:extLst>\n  <s:sheets>",
    )
    if workbook_with_decoy == workbook_xml {
      fail("workbook injection marker was not found")
    }
    assert_true(
      archive.replace(
        "xl/workbook.xml",
        @encoding/utf8.encode(workbook_with_decoy),
      ),
    )
    guard archive.get("xl/worksheets/sheet.xml") is Some(worksheet_bytes) else {
      fail("missing worksheet fixture part")
    }
    let worksheet_xml = @encoding/utf8.decode(worksheet_bytes) catch {
      _ => fail("worksheet fixture is not UTF-8")
    }
    let worksheet_with_decoy = worksheet_xml.replace(
      old="<s:sheetData>",
      new="<s:extLst><s:ext uri=\"urn:mbtexcel:decoy\"><s:row r=\"99\"><s:c r=\"Z99\" t=\"str\"><s:v>phantom</s:v></s:c></s:row></s:ext></s:extLst><s:sheetData>",
    )
    if worksheet_with_decoy == worksheet_xml {
      fail("worksheet injection marker was not found")
    }
    assert_true(
      archive.replace(
        "xl/worksheets/sheet.xml",
        @encoding/utf8.encode(worksheet_with_decoy),
      ),
    )
    let parsed = @xlsx.read(@zip.write(archive))
    debug_inspect(parsed.get_sheet_list(), content="[\"Qualified\"]")
    debug_inspect(parsed.get_cell_value("Qualified", "Z99"), content="None")
    debug_inspect(
      parsed.get_cell_value("Qualified", "A1"),
      content="Some(\"qualified-value\")",
    )
  }
}

///|
test "cell payload cannot escape its element or cross a namespace boundary" {
  let archive = @zip.read(namespace_qualified_xlsx_fixture(false, false))
  guard archive.get("xl/worksheets/sheet.xml") is Some(worksheet_bytes) else {
    fail("missing worksheet fixture part")
  }
  let worksheet_xml = @encoding/utf8.decode(worksheet_bytes) catch {
    _ => fail("worksheet fixture is not UTF-8")
  }
  let two_cells = worksheet_xml.replace(
    old="<s:c r=\"A1\" t=\"s\"><s:v>0</s:v></s:c>",
    new="<s:c r=\"A1\"/><s:c r=\"B1\" t=\"str\"><s:f>1+1</s:f><s:v>second</s:v></s:c>",
  )
  if two_cells == worksheet_xml {
    fail("worksheet cell marker was not found")
  }
  assert_true(
    archive.replace("xl/worksheets/sheet.xml", @encoding/utf8.encode(two_cells)),
  )
  let parsed = @xlsx.read(@zip.write(archive))
  debug_inspect(parsed.get_cell_value("Qualified", "A1"), content="Some(\"\")")
  debug_inspect(parsed.get_cell_formula("Qualified", "A1"), content="None")
  debug_inspect(
    parsed.get_cell_value("Qualified", "B1"),
    content="Some(\"second\")",
  )
  debug_inspect(
    parsed.get_cell_formula("Qualified", "B1"),
    content="Some(\"1+1\")",
  )

  let foreign_value = two_cells.replace(
    old="<s:c r=\"A1\"/>",
    new="<s:c r=\"A1\" t=\"str\"><v xmlns=\"urn:foreign\">injected</v></s:c>",
  )
  assert_true(
    archive.replace(
      "xl/worksheets/sheet.xml",
      @encoding/utf8.encode(foreign_value),
    ),
  )
  let foreign_parsed = @xlsx.read(@zip.write(archive))
  debug_inspect(
    foreign_parsed.get_cell_value("Qualified", "A1"),
    content="Some(\"\")",
  )
  debug_inspect(
    foreign_parsed.get_cell_value("Qualified", "B1"),
    content="Some(\"second\")",
  )
}

///|
test "foreign core-looking elements cannot supply XLSX data" {
  let archive = @zip.read(namespace_qualified_xlsx_fixture(false, false))
  guard archive.get("xl/worksheets/sheet.xml") is Some(worksheet_bytes) else {
    fail("missing worksheet fixture part")
  }
  let worksheet_xml = @encoding/utf8.decode(worksheet_bytes) catch {
    _ => fail("worksheet fixture is not UTF-8")
  }
  let with_foreign_merge = worksheet_xml.replace(
    old="<s:mergeCells count=\"1\">",
    new="<mergeCells xmlns=\"urn:foreign\"><mergeCell ref=\"C1:D1\"/></mergeCells><s:mergeCells count=\"1\">",
  )
  assert_true(
    archive.replace(
      "xl/worksheets/sheet.xml",
      @encoding/utf8.encode(with_foreign_merge),
    ),
  )
  let parsed = @xlsx.read(@zip.write(archive))
  assert_eq(parsed.get_merge_cells("Qualified"), ["A1:B1"])

  let foreign_strings = @zip.read(
    namespace_qualified_xlsx_fixture(false, false),
  )
  assert_true(
    foreign_strings.replace(
      "xl/sharedStrings.xml",
      @encoding/utf8.encode(
        "<sst xmlns=\"urn:foreign\"><si><t>spoof</t></si></sst>",
      ),
    ),
  )
  try @xlsx.read(@zip.write(foreign_strings)) catch {
    @xlsx.InvalidXml(msg~) =>
      inspect(msg, content="sst document element is invalid")
    _ => fail("unexpected foreign shared-string error")
  } noraise {
    _ => fail("expected foreign shared-string root rejection")
  }
}

///|
test "XML whitespace spellings preserve cells values and formulas" {
  let archive = @zip.read(namespace_qualified_xlsx_fixture(false, false))
  guard archive.get("xl/worksheets/sheet.xml") is Some(worksheet_bytes) else {
    fail("missing worksheet fixture part")
  }
  let worksheet_xml = @encoding/utf8.decode(worksheet_bytes) catch {
    _ => fail("worksheet fixture is not UTF-8")
  }
  let spaced = worksheet_xml.replace(
    old="<s:c r=\"A1\" t=\"s\"><s:v>0</s:v></s:c>",
    new="<s:c\nr=\"A1\" t=\"str\"><s:f\nt=\"normal\">1+1</s:f ><s:v>two</s:v ></s:c >",
  )
  assert_true(
    archive.replace("xl/worksheets/sheet.xml", @encoding/utf8.encode(spaced)),
  )
  let parsed = @xlsx.read(@zip.write(archive))
  debug_inspect(
    parsed.get_cell_value("Qualified", "A1"),
    content="Some(\"two\")",
  )
  debug_inspect(
    parsed.get_cell_formula("Qualified", "A1"),
    content="Some(\"1+1\")",
  )
}

///|
test "malformed entities fail and phonetic annotations stay out of cell text" {
  let malformed = @zip.read(namespace_qualified_xlsx_fixture(false, false))
  guard malformed.get("xl/worksheets/sheet.xml") is Some(worksheet_bytes) else {
    fail("missing worksheet fixture part")
  }
  let worksheet_xml = @encoding/utf8.decode(worksheet_bytes) catch {
    _ => fail("worksheet fixture is not UTF-8")
  }
  assert_true(
    malformed.replace(
      "xl/worksheets/sheet.xml",
      @encoding/utf8.encode(
        worksheet_xml.replace(old="<s:v>0</s:v>", new="<s:v>&bogus;</s:v>"),
      ),
    ),
  )
  try @xlsx.read(@zip.write(malformed)) catch {
    @xlsx.InvalidXml(_) => ()
    _ => fail("unexpected malformed entity error")
  } noraise {
    _ => fail("expected malformed entity rejection")
  }

  let phonetic = @zip.read(namespace_qualified_xlsx_fixture(false, false))
  guard phonetic.get("xl/sharedStrings.xml") is Some(shared_bytes) else {
    fail("missing shared-string fixture part")
  }
  let shared_xml = @encoding/utf8.decode(shared_bytes) catch {
    _ => fail("shared-string fixture is not UTF-8")
  }
  assert_true(
    phonetic.replace(
      "xl/sharedStrings.xml",
      @encoding/utf8.encode(
        shared_xml.replace(
          old="<s:t>qualified-value</s:t>",
          new="<s:t>漢字</s:t><s:rPh sb=\"0\" eb=\"2\"><s:t>かんじ</s:t></s:rPh>",
        ),
      ),
    ),
  )
  assert_true(
    phonetic.replace(
      "xl/worksheets/sheet.xml",
      @encoding/utf8.encode(
        worksheet_xml.replace(
          old="</s:row>",
          new="<s:c r=\"B1\" t=\"inlineStr\"><s:is><s:t>東京</s:t><s:rPh sb=\"0\" eb=\"2\"><s:t>とうきょう</s:t></s:rPh></s:is></s:c></s:row>",
        ),
      ),
    ),
  )
  let parsed = @xlsx.read(@zip.write(phonetic))
  debug_inspect(
    parsed.get_cell_value("Qualified", "A1"),
    content="Some(\"漢字\")",
  )
  debug_inspect(
    parsed.get_cell_value("Qualified", "B1"),
    content="Some(\"東京\")",
  )
}

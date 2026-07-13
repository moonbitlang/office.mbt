///|
fn inventory_alias_target(
  inventory : @raw.RawInventory,
  wanted : String,
) -> String? {
  for part in inventory.parts {
    for alias_name in part.aliases {
      if alias_name == wanted {
        return Some(part.name)
      }
    }
  }
  None
}

///|
fn raw_test_archive(entries : Array[(String, Bytes)]) -> Bytes raise {
  let archive = @zip.Archive::new()
  for entry in entries {
    archive.add(entry.0, entry.1)
  }
  @zip.write(archive)
}

///|
fn relocated_docx_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/custom/main.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/main.xml\"/></Relationships>",
      ),
    ),
    (
      "custom/main.xml",
      @utf8.encode(
        "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:sectPr/></w:body></w:document>",
      ),
    ),
    (
      "custom/_rels/main.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>",
      ),
    ),
  ])
}

///|
fn relocated_xlsx_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/custom/book.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/data/first.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/book.xml\"/></Relationships>",
      ),
    ),
    (
      "custom/book.xml",
      @utf8.encode(
        "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Moved\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>",
      ),
    ),
    (
      "custom/_rels/book.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"../data/first.xml\"/></Relationships>",
      ),
    ),
    (
      "data/first.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
      ),
    ),
  ])
}

///|
fn ambiguous_sheet_alias_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/custom/book.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/data/first.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/data/second.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/book.xml\"/></Relationships>",
      ),
    ),
    (
      "custom/book.xml",
      @utf8.encode(
        "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Data\" sheetId=\"1\" r:id=\"rId1\"/><sheet name=\"data\" sheetId=\"2\" r:id=\"rId2\"/></sheets></workbook>",
      ),
    ),
    (
      "custom/_rels/book.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"../data/first.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"../data/second.xml\"/></Relationships>",
      ),
    ),
    (
      "data/first.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
      ),
    ),
    (
      "data/second.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
      ),
    ),
  ])
}

///|
fn hostile_relationship_docx_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/custom/main.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/><Override PartName=\"/custom/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/><Override PartName=\"/vendor/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"vendorMain\" Type=\"https://vendor.example/relationships/officeDocument\" Target=\"vendor/decoy.xml\"/><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/main.xml\"/></Relationships>",
      ),
    ),
    (
      "custom/main.xml",
      @utf8.encode(
        "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:sectPr/></w:body></w:document>",
      ),
    ),
    (
      "custom/_rels/main.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"vendorStyles\" Type=\"https://vendor.example/relationships/styles\" Target=\"../vendor/styles.xml\"/><Relationship Id=\"styles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>",
      ),
    ),
    (
      "custom/styles.xml",
      @utf8.encode(
        "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
      ),
    ),
    ("vendor/styles.xml", @utf8.encode("<vendor/>")),
    ("vendor/decoy.xml", @utf8.encode("<decoy/>")),
  ])
}

///|
fn hostile_relationship_xlsx_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/custom/book.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/data/good.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/data/evil.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/data/wrong-role.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/book.xml\"/></Relationships>",
      ),
    ),
    (
      "custom/book.xml",
      @utf8.encode(
        "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:v=\"https://vendor.example/relationships\"><sheets><sheet name=\"Good\" sheetId=\"1\" v:id=\"evil\" r:id=\"good\"/><sheet name=\"WrongRole\" sheetId=\"2\" r:id=\"wrongRole\"/><sheet name=\"WrongType\" sheetId=\"3\" r:id=\"wrongType\"/></sheets></workbook>",
      ),
    ),
    (
      "custom/_rels/book.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"evil\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"../data/evil.xml\"/><Relationship Id=\"good\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"../data/good.xml\"/><Relationship Id=\"wrongRole\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"../data/wrong-role.xml\"/><Relationship Id=\"wrongType\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"../data/not-a-sheet.xml\"/></Relationships>",
      ),
    ),
    (
      "data/good.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
      ),
    ),
    (
      "data/evil.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
      ),
    ),
    (
      "data/wrong-role.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
      ),
    ),
    ("data/not-a-sheet.xml", @utf8.encode("<other/>")),
  ])
}

///|
fn mixed_case_docx_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/CUSTOM/MAIN.XML\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/main.xml\"/></Relationships>",
      ),
    ),
    (
      "CUSTOM/MAIN.XML",
      @utf8.encode(
        "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:sectPr/></w:body></w:document>",
      ),
    ),
    (
      "CUSTOM/_rels/MAIN.XML.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>",
      ),
    ),
  ])
}

///|
fn mixed_case_xlsx_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/CUSTOM/BOOK.XML\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/DATA/FIRST.XML\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/book.xml\"/></Relationships>",
      ),
    ),
    (
      "CUSTOM/BOOK.XML",
      @utf8.encode(
        "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Mixed\" sheetId=\"1\" r:id=\"sheet\"/></sheets></workbook>",
      ),
    ),
    (
      "CUSTOM/_rels/BOOK.XML.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"sheet\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"../data/first.xml\"/></Relationships>",
      ),
    ),
    (
      "DATA/FIRST.XML",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
      ),
    ),
  ])
}

///|
fn strict_docx_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>",
      ),
    ),
    (
      "word/document.xml",
      @utf8.encode(
        "<w:document xmlns:w=\"http://purl.oclc.org/ooxml/wordprocessingml/main\"><w:body><w:p/><w:sectPr/></w:body></w:document>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>",
      ),
    ),
  ])
}

///|
fn strict_xlsx_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
      ),
    ),
    (
      "xl/workbook.xml",
      @utf8.encode(
        "<workbook xmlns=\"http://purl.oclc.org/ooxml/spreadsheetml/main\" xmlns:r=\"http://purl.oclc.org/ooxml/officeDocument/relationships\"><sheets><sheet name=\"Strict\" sheetId=\"1\" r:id=\"sheet\"/></sheets></workbook>",
      ),
    ),
    (
      "xl/_rels/workbook.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"sheet\" Type=\"http://purl.oclc.org/ooxml/officeDocument/relationships/worksheet\" Target=\"worksheets/sheet.xml\"/></Relationships>",
      ),
    ),
    (
      "xl/worksheets/sheet.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://purl.oclc.org/ooxml/spreadsheetml/main\"><sheetData/></worksheet>",
      ),
    ),
  ])
}

///|
fn colliding_literal_docx_fixture() -> Bytes raise {
  let source = @zip.read(relocated_docx_fixture())
  let output = @zip.Archive::new()
  for entry in source.entries() {
    let data = if entry.name() == "[Content_Types].xml" {
      @utf8.encode(
        @utf8.decode(entry.data()).replace(
          old="</Types>",
          new="<Override PartName=\"/document\" ContentType=\"application/xml\"/></Types>",
        ),
      )
    } else {
      entry.data()
    }
    output.add(entry.name(), data)
  }
  output.add("document", @utf8.encode("<literal/>"))
  @zip.write(output)
}

///|
fn raw_reencode_package_xml_as_utf16(data : BytesView) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    let payload = if entry.name() == "[Content_Types].xml" ||
      entry.name() == "word/document.xml" {
      let text = @utf8.decode(entry.data(), ignore_bom=true).replace_all(
        old="UTF-8",
        new="UTF-16",
      )
      @utf16.encode(text, bom=true)
    } else if entry.name().has_suffix(".rels") {
      let text = @utf8.decode(entry.data(), ignore_bom=true).replace_all(
        old="UTF-8",
        new="UTF-16",
      )
      @utf16.encode(text, bom=true, endianness=Big)
    } else {
      entry.data()
    }
    result.add(
      entry.name(),
      payload,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  @zip.write(result)
}

///|
test "raw inventory resolves DOCX parts through semantic aliases" {
  let data = @word.new_blank_docx()
  let inventory = @raw.raw_inventory("blank.docx", data)
  inspect(inventory.format.name(), content="docx")
  debug_inspect(
    inventory_alias_target(inventory, "/document"),
    content="Some(\"word/document.xml\")",
  )
  debug_inspect(
    inventory_alias_target(inventory, "/styles"),
    content="Some(\"word/styles.xml\")",
  )
  debug_inspect(
    inventory_alias_target(inventory, "/content-types"),
    content="Some(\"[Content_Types].xml\")",
  )
  let document = @raw.raw_read("blank.docx", data, "/document")
  inspect(document.info.xml, content="true")
  inspect(document.xml_text().contains("<w:document"), content="true")
}

///|
test "raw inventory resolves XLSX worksheet names and positions" {
  let workbook = @excel.new_file()
  workbook.set_sheet_name("Sheet1", "Quarter One")
  ignore(workbook.new_sheet("Quarter Two"))
  let data = @excel.write(workbook)
  let inventory = @raw.raw_inventory("book.xlsx", data)
  inspect(inventory.format.name(), content="xlsx")
  debug_inspect(
    inventory_alias_target(inventory, "/workbook"),
    content="Some(\"xl/workbook.xml\")",
  )
  debug_inspect(
    inventory_alias_target(inventory, "/Quarter One"),
    content="Some(\"xl/worksheets/sheet1.xml\")",
  )
  debug_inspect(
    inventory_alias_target(inventory, "/sheet[2]"),
    content="Some(\"xl/worksheets/sheet2.xml\")",
  )
  let sheet = @raw.raw_read("book.xlsx", data, "/quarter two")
  inspect(sheet.info.name, content="xl/worksheets/sheet2.xml")
  inspect(sheet.xml_text().contains("<worksheet"), content="true")
}

///|
test "raw read rejects unknown and binary-terminal part access" {
  let data = @word.new_blank_docx()
  try @raw.raw_read("blank.docx", data, "/missing.xml") catch {
    RawError(code~, ..) => inspect(code, content="office.raw.unknown_part")
  } noraise {
    _ => fail("expected an unknown part to fail")
  }
}

///|
test "raw aliases follow relocated DOCX and XLSX relationship graphs" {
  let docx = relocated_docx_fixture()
  let docx_inventory = @raw.raw_inventory("relocated.docx", docx)
  debug_inspect(
    inventory_alias_target(docx_inventory, "/document"),
    content="Some(\"custom/main.xml\")",
  )
  debug_inspect(
    inventory_alias_target(docx_inventory, "/document/relationships"),
    content="Some(\"custom/_rels/main.xml.rels\")",
  )
  inspect(
    @raw.raw_read("relocated.docx", docx, "/DOCUMENT").info.name,
    content="custom/main.xml",
  )

  let xlsx = relocated_xlsx_fixture()
  let xlsx_inventory = @raw.raw_inventory("relocated.xlsx", xlsx)
  debug_inspect(
    inventory_alias_target(xlsx_inventory, "/workbook"),
    content="Some(\"custom/book.xml\")",
  )
  debug_inspect(
    inventory_alias_target(xlsx_inventory, "/Moved"),
    content="Some(\"data/first.xml\")",
  )
  inspect(
    @raw.raw_read("relocated.xlsx", xlsx, "/sheet[1]").info.name,
    content="data/first.xml",
  )
}

///|
test "raw reads UTF-16 XML but span edits fail with a stable encoding error" {
  let data = raw_reencode_package_xml_as_utf16(@word.new_blank_docx())
  let document = @raw.raw_read("utf16.docx", data, "/document")
  inspect(document.xml_text().contains("<w:document"), content="true")
  let request = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body",
    SetAttribute,
    attribute="test",
    value="value",
  )
  try @raw.raw_edit(Docx, data, request) catch {
    RawError(code~, ..) =>
      inspect(code, content="office.raw.unsupported_xml_encoding")
  } noraise {
    _ => fail("expected UTF-16 span editing to fail")
  }
}

///|
test "case-insensitive semantic alias collisions fail closed" {
  let data = ambiguous_sheet_alias_fixture()
  try @raw.raw_read("ambiguous.xlsx", data, "/DATA") catch {
    RawError(code~, ..) => inspect(code, content="office.raw.ambiguous_part")
  } noraise {
    _ => fail("expected colliding sheet aliases to fail")
  }
  inspect(
    @raw.raw_read("ambiguous.xlsx", data, "/sheet[2]").info.name,
    content="data/second.xml",
  )
}

///|
test "raw aliases trust only standardized relationship types and content types" {
  let docx = hostile_relationship_docx_fixture()
  let docx_inventory = @raw.raw_inventory("hostile.docx", docx)
  assert_eq(
    inventory_alias_target(docx_inventory, "/document"),
    Some("custom/main.xml"),
  )
  assert_eq(
    inventory_alias_target(docx_inventory, "/styles"),
    Some("custom/styles.xml"),
  )
  let xlsx = hostile_relationship_xlsx_fixture()
  let xlsx_inventory = @raw.raw_inventory("hostile.xlsx", xlsx)
  assert_eq(
    inventory_alias_target(xlsx_inventory, "/Good"),
    Some("data/good.xml"),
  )
  assert_eq(inventory_alias_target(xlsx_inventory, "/WrongRole"), None)
  assert_eq(inventory_alias_target(xlsx_inventory, "/WrongType"), None)
  assert_eq(
    @raw.raw_read("hostile.xlsx", xlsx, "/sheet[1]").info.name,
    "data/good.xml",
  )
}

///|
test "raw relationship targets resolve to exact archive spelling" {
  let data = mixed_case_docx_fixture()
  let inventory = @raw.raw_inventory("mixed.docx", data)
  assert_eq(
    inventory_alias_target(inventory, "/document"),
    Some("CUSTOM/MAIN.XML"),
  )
  assert_eq(
    @raw.raw_read("mixed.docx", data, "/document").info.name,
    "CUSTOM/MAIN.XML",
  )
  let request = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body",
    SetAttribute,
    attribute="mixed",
    value="true",
  )
  let edited = @raw.raw_edit(Docx, data, request)
  assert_eq(edited.part, "CUSTOM/MAIN.XML")
  assert_true(
    @raw.raw_read("mixed.docx", edited.bytes, "part:/CUSTOM/MAIN.XML")
    .xml_text()
    .contains("mixed=\"true\""),
  )
  let xlsx = mixed_case_xlsx_fixture()
  let xlsx_inventory = @raw.raw_inventory("mixed.xlsx", xlsx)
  assert_eq(
    inventory_alias_target(xlsx_inventory, "/Mixed"),
    Some("DATA/FIRST.XML"),
  )
  assert_eq(
    @raw.raw_read("mixed.xlsx", xlsx, "/sheet[1]").info.name,
    "DATA/FIRST.XML",
  )
  let xlsx_request = @raw.raw_edit_request(
    "/sheet[1]",
    "/x:worksheet/x:sheetData",
    SetAttribute,
    attribute="mixed",
    value="true",
  )
  let xlsx_edited = @raw.raw_edit(Xlsx, xlsx, xlsx_request)
  assert_eq(xlsx_edited.part, "DATA/FIRST.XML")
  assert_true(
    @raw.raw_read("mixed.xlsx", xlsx_edited.bytes, "part:/DATA/FIRST.XML")
    .xml_text()
    .contains("mixed=\"true\""),
  )
}

///|
test "raw selector collisions require an explicit alias or literal mode" {
  let data = colliding_literal_docx_fixture()
  try @raw.raw_read("collision.docx", data, "/document") catch {
    RawError(code~, ..) => assert_eq(code, "office.raw.ambiguous_part")
  } noraise {
    _ => fail("expected alias-literal collision to fail closed")
  }
  let semantic = @raw.raw_read("collision.docx", data, "alias:/document")
  assert_eq(semantic.info.name, "custom/main.xml")
  let literal = @raw.raw_read("collision.docx", data, "part:/document")
  assert_eq(literal.info.name, "document")
  assert_eq(literal.xml_text(), "<literal/>")
}

///|
test "raw selectors derive Strict OOXML namespaces and bind xml automatically" {
  let docx = strict_docx_fixture()
  assert_eq(
    inventory_alias_target(@raw.raw_inventory("strict.docx", docx), "/document"),
    Some("word/document.xml"),
  )
  let docx_request = @raw.raw_edit_request(
    "/document",
    "/w:document/w:body",
    SetAttribute,
    attribute="xml:space",
    value="preserve",
  )
  let docx_edited = @raw.raw_edit(Docx, docx, docx_request)
  assert_true(
    @raw.raw_read("strict.docx", docx_edited.bytes, "/document")
    .xml_text()
    .contains("xml:space=\"preserve\""),
  )

  let xlsx = strict_xlsx_fixture()
  assert_eq(
    inventory_alias_target(@raw.raw_inventory("strict.xlsx", xlsx), "/Strict"),
    Some("xl/worksheets/sheet.xml"),
  )
  let xlsx_request = @raw.raw_edit_request(
    "/sheet[1]",
    "/x:worksheet/x:sheetData",
    SetAttribute,
    attribute="strict",
    value="true",
  )
  let xlsx_edited = @raw.raw_edit(Xlsx, xlsx, xlsx_request)
  assert_true(
    @raw.raw_read("strict.xlsx", xlsx_edited.bytes, "/sheet[1]")
    .xml_text()
    .contains("strict=\"true\""),
  )
}

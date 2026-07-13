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

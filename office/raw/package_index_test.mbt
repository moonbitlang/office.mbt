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
fn raw_test_replace_entry(
  data : BytesView,
  name : String,
  payload : Bytes,
) -> Bytes raise {
  let source = @zip.read(data)
  let output = @zip.Archive::new()
  let mut found = false
  for entry in source.entries() {
    if entry.name() == name {
      output.add(
        entry.name(),
        payload,
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
      found = true
    } else {
      output.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  if !found {
    fail("raw test fixture is missing entry '\{name}'")
  }
  @zip.write(output)
}

///|
fn raw_test_transform_xml_entry(
  data : BytesView,
  name : String,
  transform : (String) -> String,
) -> Bytes raise {
  let source = @zip.read(data)
  let payload = match source.get(name) {
    Some(value) => @utf8.decode(value, ignore_bom=true)
    None => fail("raw test fixture is missing XML entry '\{name}'")
  }
  raw_test_replace_entry(data, name, @utf8.encode(transform(payload)))
}

///|
fn raw_test_add_entry(
  data : BytesView,
  name : String,
  payload : Bytes,
) -> Bytes raise {
  let source = @zip.read(data)
  let output = @zip.Archive::new()
  for entry in source.entries() {
    output.add(
      entry.name(),
      entry.data(),
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  output.add(name, payload)
  @zip.write(output)
}

///|
fn overwrite_raw_test_u32(
  bytes : Array[Byte],
  offset : Int,
  value : Int,
) -> Unit {
  let raw = value.reinterpret_as_uint()
  bytes[offset] = (raw & 0xff).to_byte()
  bytes[offset + 1] = ((raw >> 8) & 0xff).to_byte()
  bytes[offset + 2] = ((raw >> 16) & 0xff).to_byte()
  bytes[offset + 3] = ((raw >> 24) & 0xff).to_byte()
}

///|
fn forge_raw_test_central_uncompressed_sizes(
  source : Bytes,
  declared : Int,
) -> (Bytes, Int) {
  let bytes = source.to_array()
  let mut count = 0
  for offset = 0; offset + 27 < bytes.length(); offset = offset + 1 {
    if bytes[offset] == b'P' &&
      bytes[offset + 1] == b'K' &&
      bytes[offset + 2] == b'\x01' &&
      bytes[offset + 3] == b'\x02' {
      overwrite_raw_test_u32(bytes, offset + 24, declared)
      count = count + 1
    }
  }
  (Bytes::from_array(bytes), count)
}

///|
fn raw_inventory_error_for(
  path : String,
  bytes : Bytes,
) -> (String, String) raise {
  try @raw.raw_inventory(path, bytes) catch {
    RawError(code~, details~, ..) =>
      (code, details.unwrap_or(Json::empty_object()).stringify())
  } noraise {
    _ => fail("expected raw inventory to fail")
  }
}

///|
fn raw_inventory_error(bytes : Bytes) -> (String, String) raise {
  raw_inventory_error_for("limits.docx", bytes)
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
fn sheet_ordinal_gap_fixture() -> Bytes raise {
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/valid.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
      ),
    ),
    (
      "xl/workbook.xml",
      @utf8.encode(
        "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Invalid\" sheetId=\"1\" r:id=\"missing\"/><sheet name=\"Valid\" sheetId=\"2\" r:id=\"valid\"/></sheets></workbook>",
      ),
    ),
    (
      "xl/_rels/workbook.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"valid\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/valid.xml\"/></Relationships>",
      ),
    ),
    (
      "xl/worksheets/valid.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
      ),
    ),
  ])
}

///|
fn alias_budget_xlsx_fixture() -> Bytes raise {
  let sheets = StringBuilder::new()
  let relationships = StringBuilder::new()
  for index = 1; index <= 2049; index = index + 1 {
    sheets.write_string(
      "<sheet name=\"Sheet\{index}\" sheetId=\"\{index}\" r:id=\"r\{index}\"/>",
    )
    |> ignore
    relationships.write_string(
      "<Relationship Id=\"r\{index}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"../data/shared.xml\"/>",
    )
    |> ignore
  }
  raw_test_archive([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/data/shared.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
      ),
    ),
    (
      "xl/workbook.xml",
      @utf8.encode(
        "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>" +
        sheets.to_string() +
        "</sheets></workbook>",
      ),
    ),
    (
      "xl/_rels/workbook.xml.rels",
      @utf8.encode(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
        relationships.to_string() +
        "</Relationships>",
      ),
    ),
    (
      "data/shared.xml",
      @utf8.encode(
        "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>",
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

///|
test "raw resolver rejects collisions and namespace-spoofed OPC metadata before generic detection" {
  let original = @word.new_blank_docx()
  let collision = raw_test_add_entry(
    original,
    "WORD/DOCUMENT.XML",
    @utf8.encode("<decoy/>"),
  )
  assert_eq(raw_inventory_error(collision).0, "office.raw.invalid_package")

  let overlong_entry = raw_test_add_entry(original, "x".repeat(1025), b"")
  assert_eq(raw_inventory_error(overlong_entry).0, "office.raw.invalid_package")

  let wrong_manifest_namespace = raw_test_transform_xml_entry(
    original,
    "[Content_Types].xml",
    text => {
      text.replace_all(
        old="http://schemas.openxmlformats.org/package/2006/content-types",
        new="https://vendor.invalid/content-types",
      )
    },
  )
  assert_eq(
    raw_inventory_error(wrong_manifest_namespace).0,
    "office.raw.invalid_package",
  )

  let duplicate_default = raw_test_transform_xml_entry(
    original,
    "[Content_Types].xml",
    text => {
      text.replace(
        old="</Types>",
        new="<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/></Types>",
      )
    },
  )
  assert_eq(
    raw_inventory_error(duplicate_default).0,
    "office.raw.invalid_package",
  )

  let wrong_relationship_namespace = raw_test_transform_xml_entry(
    original,
    "_rels/.rels",
    text => {
      text.replace_all(
        old="http://schemas.openxmlformats.org/package/2006/relationships",
        new="https://vendor.invalid/relationships",
      )
    },
  )
  assert_eq(
    raw_inventory_error(wrong_relationship_namespace).0,
    "office.raw.invalid_relationship",
  )

  let wrong_unused_relationship_namespace = raw_test_add_entry(
    relocated_docx_fixture(),
    "_rels/[Content_Types].xml.rels",
    @utf8.encode(
      "<Relationships xmlns=\"https://vendor.invalid/relationships\"/>",
    ),
  )
  assert_eq(
    raw_inventory_error(wrong_unused_relationship_namespace).0,
    "office.raw.invalid_relationship",
  )

  let duplicate_relationship_id = raw_test_transform_xml_entry(
    original,
    "_rels/.rels",
    text => {
      text.replace(
        old="</Relationships>",
        new="<Relationship Id=\"rId1\" Type=\"urn:duplicate\" Target=\"https://example.invalid\" TargetMode=\"External\"/></Relationships>",
      )
    },
  )
  assert_eq(
    raw_inventory_error(duplicate_relationship_id).0,
    "office.raw.invalid_relationship",
  )

  let invalid_target_mode = raw_test_transform_xml_entry(
    original,
    "_rels/.rels",
    text => {
      text.replace(
        old="</Relationships>",
        new="<Relationship Id=\"invalid-mode\" Type=\"urn:test\" Target=\"https://example.invalid\" TargetMode=\"Remote\"/></Relationships>",
      )
    },
  )
  assert_eq(
    raw_inventory_error(invalid_target_mode).0,
    "office.raw.invalid_relationship",
  )

  let oversized_main = raw_test_replace_entry(
    original,
    "word/document.xml",
    Bytes::make(8 * 1024 * 1024 + 1, b'x'),
  )
  let (oversized_code, oversized_details) = raw_inventory_error(oversized_main)
  assert_eq(oversized_code, "office.raw.resource_limit")
  assert_true(oversized_details.contains("metadata_xml_bytes"))
}

///|
test "XLSX numeric aliases preserve workbook declaration ordinals" {
  let data = sheet_ordinal_gap_fixture()
  let inventory = @raw.raw_inventory("ordinal-gap.xlsx", data)
  assert_eq(inventory_alias_target(inventory, "/sheet[1]"), None)
  assert_eq(
    inventory_alias_target(inventory, "/sheet[2]"),
    Some("xl/worksheets/valid.xml"),
  )
  assert_eq(
    @raw.raw_read("ordinal-gap.xlsx", data, "/sheet[2]").info.name,
    "xl/worksheets/valid.xml",
  )
  try @raw.raw_read("ordinal-gap.xlsx", data, "/sheet[1]") catch {
    RawError(code~, ..) => assert_eq(code, "office.raw.unknown_part")
  } noraise {
    _ => fail("invalid first declaration must leave an alias gap")
  }
}

///|
test "maximum supported part names remain readable and mutable" {
  let name = "parts/" + "x".repeat(1014) + ".xml"
  assert_eq(name.length(), 1024)
  let with_entry = raw_test_add_entry(
    @word.new_blank_docx(),
    name,
    @utf8.encode("<extra/>"),
  )
  let data = raw_test_transform_xml_entry(with_entry, "[Content_Types].xml", text => {
    text.replace(
      old="</Types>",
      new="<Override PartName=\"/\{name}\" ContentType=\"application/xml\"/></Types>",
    )
  })
  let selector = "part:/" + name
  assert_eq(
    @raw.raw_read("max-name.docx", data, selector).xml_text(),
    "<extra/>",
  )
  let mutation = @raw.raw_replace_part(
    Docx,
    data,
    selector,
    "<extra changed=\"true\"/>",
  )
  assert_true(
    @raw.raw_read("max-name.docx", mutation.bytes, selector)
    .xml_text()
    .contains("changed=\"true\""),
  )
}

///|
test "Strict OOXML aliases reject cross-dialect relationship families" {
  let wrong_root = raw_test_transform_xml_entry(
    strict_docx_fixture(),
    "_rels/.rels",
    text => {
      text.replace_all(
        old="http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument",
        new="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
      )
    },
  )
  assert_eq(
    raw_inventory_error_for("strict.docx", wrong_root).0,
    "office.raw.invalid_relationship",
  )

  let wrong_id_namespace = raw_test_transform_xml_entry(
    strict_xlsx_fixture(),
    "xl/workbook.xml",
    text => {
      text.replace_all(
        old="http://purl.oclc.org/ooxml/officeDocument/relationships",
        new="http://schemas.openxmlformats.org/officeDocument/2006/relationships",
      )
    },
  )
  assert_eq(
    raw_inventory_error_for("strict.xlsx", wrong_id_namespace).0,
    "office.raw.invalid_relationship",
  )

  let wrong_type_family = raw_test_transform_xml_entry(
    strict_xlsx_fixture(),
    "xl/_rels/workbook.xml.rels",
    text => {
      text.replace_all(
        old="http://purl.oclc.org/ooxml/officeDocument/relationships/worksheet",
        new="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet",
      )
    },
  )
  let inventory = @raw.raw_inventory("strict.xlsx", wrong_type_family)
  assert_eq(inventory_alias_target(inventory, "/Strict"), None)
  assert_eq(inventory_alias_target(inventory, "/sheet[1]"), None)
}

///|
test "raw alias construction enforces its per-part budget incrementally" {
  let (code, details) = raw_inventory_error_for(
    "aliases.xlsx",
    alias_budget_xlsx_fixture(),
  )
  assert_eq(code, "office.raw.resource_limit")
  assert_true(details.contains("semantic_aliases"))
}

///|
test "raw metadata preflight bounds namespace expansion and scope work" {
  let original = @word.new_blank_docx()
  let oversized_uri = "urn:" + "x".repeat(2046)
  let oversized_namespace = raw_test_replace_entry(
    original,
    "word/document.xml",
    @utf8.encode(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:q=\"\{oversized_uri}\"><w:body><w:sectPr/></w:body></w:document>",
    ),
  )
  let (uri_code, uri_details) = raw_inventory_error(oversized_namespace)
  assert_eq(uri_code, "office.raw.resource_limit")
  assert_true(uri_details.contains("xml_namespace_uri_bytes"))

  let bounded_uri = "urn:" + "x".repeat(2044)
  let expanded = StringBuilder::new()
  expanded.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:q=\"\{bounded_uri}\"><w:body>",
  )
  |> ignore
  for _ in 0..<2100 {
    expanded.write_string("<q:x/>") |> ignore
  }
  expanded.write_string("<w:sectPr/></w:body></w:document>") |> ignore
  let expanded_package = raw_test_replace_entry(
    original,
    "word/document.xml",
    @utf8.encode(expanded.to_string()),
  )
  let (expanded_code, expanded_details) = raw_inventory_error(expanded_package)
  assert_eq(expanded_code, "office.raw.resource_limit")
  assert_true(expanded_details.contains("xml_expanded_name_bytes"))

  let scoped = StringBuilder::new()
  scoped.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"",
  )
  |> ignore
  for index in 0..<200 {
    scoped.write_string(" xmlns:p\{index}=\"urn:p\{index}\"") |> ignore
  }
  scoped.write_string("><w:body>") |> ignore
  for _ in 0..<2500 {
    scoped.write_string("<w:p/>") |> ignore
  }
  scoped.write_string("<w:sectPr/></w:body></w:document>") |> ignore
  let scoped_package = raw_test_replace_entry(
    original,
    "word/document.xml",
    @utf8.encode(scoped.to_string()),
  )
  let (scope_code, scope_details) = raw_inventory_error(scoped_package)
  assert_eq(scope_code, "office.raw.resource_limit")
  assert_true(scope_details.contains("xml_namespace_scope_work"))
}

///|
test "raw ZIP expansion limits retain resource codes and details" {
  let count_archive = @zip.Archive::new()
  for index in 0..<8193 {
    count_archive.add("entry-\{index}", b"")
  }
  let (count_code, count_details) = raw_inventory_error(
    @zip.write(count_archive),
  )
  assert_eq(count_code, "office.raw.resource_limit")
  assert_true(count_details.contains("entry_count"))

  let entry_archive = @zip.Archive::new()
  entry_archive.add("entry", b"")
  let (entry_bytes, entry_records) = forge_raw_test_central_uncompressed_sizes(
    @zip.write(entry_archive),
    64 * 1024 * 1024 + 1,
  )
  assert_eq(entry_records, 1)
  let (entry_code, entry_details) = raw_inventory_error(entry_bytes)
  assert_eq(entry_code, "office.raw.resource_limit")
  assert_true(entry_details.contains("entry_uncompressed_bytes"))

  let aggregate_archive = @zip.Archive::new()
  for index in 0..<5 {
    aggregate_archive.add("aggregate-\{index}", b"")
  }
  let (aggregate_bytes, aggregate_records) = forge_raw_test_central_uncompressed_sizes(
    @zip.write(aggregate_archive),
    60 * 1024 * 1024,
  )
  assert_eq(aggregate_records, 5)
  let (aggregate_code, aggregate_details) = raw_inventory_error(aggregate_bytes)
  assert_eq(aggregate_code, "office.raw.resource_limit")
  assert_true(aggregate_details.contains("total_uncompressed_bytes"))
}

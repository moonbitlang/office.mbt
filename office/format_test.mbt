///|
fn replace_archive_part(
  data : BytesView,
  name : String,
  replacement : Bytes,
) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  let mut replaced = false
  for entry in source.entries() {
    let entry_data = if entry.name() == name {
      replaced = true
      replacement
    } else {
      entry.data()
    }
    result.add(
      entry.name(),
      entry_data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  if !replaced {
    fail("test archive did not contain \{name}")
  }
  @zip.write(result)
}

///|
fn append_archive_part(
  data : BytesView,
  name : String,
  content : Bytes,
) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    if entry.name() == name {
      fail("test archive already contained \{name}")
    }
    result.add(
      entry.name(),
      entry.data(),
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  result.add(name, content)
  @zip.write(result)
}

///|
fn rename_archive_part(
  data : BytesView,
  old_name : String,
  new_name : String,
) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  let mut renamed = false
  for entry in source.entries() {
    let name = if entry.name() == old_name {
      renamed = true
      new_name
    } else {
      entry.name()
    }
    result.add(
      name,
      entry.data(),
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  if !renamed {
    fail("test archive did not contain \{old_name}")
  }
  @zip.write(result)
}

///|
fn prepend_utf8_bom(data : BytesView) -> Bytes {
  let bytes : Array[Byte] = [0xef, 0xbb, 0xbf]
  for byte in data {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
fn corrupt_stored_payload(data : Bytes, payload : BytesView) -> Bytes raise {
  let bytes = data.to_array()
  let mut payload_at = -1
  for i in 0..<(bytes.length() - payload.length() + 1) {
    let mut matches = true
    for j in 0..<payload.length() {
      if bytes[i + j] != payload[j] {
        matches = false
        break
      }
    }
    if matches {
      payload_at = i
      break
    }
  }
  if payload_at < 0 {
    fail("test payload was not stored verbatim in the archive")
  }
  bytes[payload_at] = b'j'
  Bytes::from_array(bytes)
}

///|
fn relocate_xlsx_main_part(data : BytesView) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    let (name, entry_data) = match entry.name() {
      "xl/workbook.xml" => ("xl/customWorkbook.xml", entry.data())
      "xl/_rels/workbook.xml.rels" =>
        ("xl/_rels/customWorkbook.xml.rels", entry.data())
      "[Content_Types].xml" => {
        let text = @utf8.decode(entry.data(), ignore_bom=true)
        (
          entry.name(),
          @utf8.encode(
            text.replace(old="/xl/workbook.xml", new="/xl/customWorkbook.xml"),
          ),
        )
      }
      "_rels/.rels" => {
        let text = @utf8.decode(entry.data(), ignore_bom=true)
        (
          entry.name(),
          @utf8.encode(
            text.replace(
              old="Target=\"xl/workbook.xml\"",
              new="Target=\"xl/customWorkbook.xml\"",
            ),
          ),
        )
      }
      _ => (entry.name(), entry.data())
    }
    result.add(
      name,
      entry_data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  @zip.write(result)
}

///|
fn add_root_level_relationships(data : BytesView) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    result.add(
      entry.name(),
      entry.data(),
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  result.add("custom.xml", @utf8.encode("<custom/>"))
  result.add(
    "_rels/custom.xml.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"https://example.com/relationships/workbook\" Target=\"xl/workbook.xml\"/></Relationships>",
    ),
  )
  @zip.write(result)
}

///|
fn reencode_identification_parts_as_utf16(data : BytesView) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    let entry_data = if entry.name() == "[Content_Types].xml" ||
      entry.name() == "xl/workbook.xml" ||
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
      entry_data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  @zip.write(result)
}

///|
fn prefix_xlsx_package_xml(
  data : BytesView,
  dangling_sheet_target : Bool,
) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    let entry_data = if entry.name() == "[Content_Types].xml" {
      let mut text = @utf8.decode(entry.data(), ignore_bom=true)
      text = text.replace(
        old="<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">",
        new="<ct:Types xmlns:ct=\"http://schemas.openxmlformats.org/package/2006/content-types\">",
      )
      text = text.replace(old="</Types>", new="</ct:Types>")
      text = text.replace_all(old="<Default ", new="<ct:Default\n  ")
      text = text.replace_all(old="<Override ", new="<ct:Override\n  ")
      if !text.contains("<ct:Types") || !text.contains("<ct:Default\n") {
        fail("test could not prefix generated content types")
      }
      @utf8.encode(text)
    } else if entry.name().has_suffix(".rels") {
      let mut text = @utf8.decode(entry.data(), ignore_bom=true)
      text = text.replace(
        old="<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
        new="<r:Relationships xmlns:r=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
      )
      text = text.replace(old="</Relationships>", new="</r:Relationships>")
      text = text.replace_all(old="<Relationship ", new="<r:Relationship\n  ")
      if !text.contains("<r:Relationships") ||
        !text.contains("<r:Relationship\n") {
        fail("test could not prefix generated relationships")
      }
      if dangling_sheet_target && entry.name() == "xl/_rels/workbook.xml.rels" {
        let updated = text.replace(
          old="Target=\"worksheets/sheet1.xml\"",
          new="Target=\"worksheets/missing.xml\"",
        )
        if updated == text {
          fail("test could not replace the generated worksheet target")
        }
        text = updated
      }
      @utf8.encode(text)
    } else {
      entry.data()
    }
    result.add(
      entry.name(),
      entry_data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  @zip.write(result)
}

///|
fn misalign_docx_main_part(data : BytesView) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    let entry_data = if entry.name() == "_rels/.rels" {
      @utf8.encode(
        @utf8.decode(entry.data(), ignore_bom=true).replace(
          old="Target=\"word/document.xml\"",
          new="Target=\"custom/main.xml\"",
        ),
      )
    } else {
      entry.data()
    }
    result.add(
      entry.name(),
      entry_data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
    if entry.name() == "word/document.xml" {
      result.add(
        "custom/main.xml",
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  @zip.write(result)
}

///|
fn add_root_relationship(
  data : BytesView,
  relationship : String,
) -> Bytes raise {
  let archive = @zip.read(data)
  let root_relationships = archive.get("_rels/.rels").unwrap()
  let text = @utf8.decode(root_relationships, ignore_bom=true)
  let updated = text.replace(
    old="</Relationships>",
    new=relationship + "</Relationships>",
  )
  if updated == text {
    fail("test could not add a root relationship")
  }
  replace_archive_part(data, "_rels/.rels", @utf8.encode(updated))
}

///|
fn add_malformed_docx_relationship(data : BytesView) -> Bytes raise {
  add_root_relationship(data, "<Relationship Target=\"word/document.xml\"/>")
}

///|
fn misdeclare_relationship_content_type(data : BytesView) -> Bytes raise {
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let text = @utf8.decode(content_types, ignore_bom=true)
  let updated = text.replace(
    old="application/vnd.openxmlformats-package.relationships+xml",
    new="application/octet-stream",
  )
  if updated == text {
    fail("test could not replace the relationship content type")
  }
  replace_archive_part(data, "[Content_Types].xml", @utf8.encode(updated))
}

///|
fn declare_xlsx_main_as_default(data : BytesView) -> Bytes raise {
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let text = @utf8.decode(content_types, ignore_bom=true)
  let without_override = text.replace(
    old="<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>",
    new="",
  )
  let updated = without_override.replace(
    old="<Default Extension=\"xml\" ContentType=\"application/xml\"/>",
    new="<Default Extension=\"xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>",
  )
  if without_override == text || updated == without_override {
    fail("test could not declare the workbook main content type by default")
  }
  replace_archive_part(data, "[Content_Types].xml", @utf8.encode(updated))
}

///|
test "detect_format identifies generated xlsx" {
  let workbook = @excel.new_file()
  let data = @excel.write(workbook)
  inspect(@office.detect_format("book.xlsx", data).name(), content="xlsx")
}

///|
test "detect_format accepts a default XLSX main content type" {
  let data = declare_xlsx_main_as_default(@excel.write(@excel.new_file()))
  inspect(@office.detect_format("book.xlsx", data).name(), content="xlsx")
}

///|
test "detect_format follows a relocated XLSX workbook main part" {
  let relocated = relocate_xlsx_main_part(@excel.write(@excel.new_file()))
  inspect(@office.detect_format("book.xlsx", relocated).name(), content="xlsx")
}

///|
test "detect_format compares OPC part names case-insensitively" {
  let mixed_case = rename_archive_part(
    @excel.write(@excel.new_file()),
    "xl/workbook.xml",
    "xl/Workbook.xml",
  )
  inspect(@office.detect_format("book.xlsx", mixed_case).name(), content="xlsx")
}

///|
test "detect_format rejects case-equivalent duplicate OPC parts" {
  let data = @excel.write(@excel.new_file())
  let archive = @zip.read(data)
  let duplicate = append_archive_part(
    data,
    "xl/Workbook.xml",
    archive.get("xl/workbook.xml").unwrap(),
  )
  try @office.detect_format("book.xlsx", duplicate) catch {
    err =>
      inspect(
        Show::to_string(err).contains("duplicate entry name: xl/workbook.xml"),
        content="true",
      )
  } noraise {
    _ => fail("expected a case-equivalent duplicate part")
  }
}

///|
test "detect_format accepts relationships for root-level source parts" {
  let with_root_relationships = add_root_level_relationships(
    @excel.write(@excel.new_file()),
  )
  inspect(
    @office.detect_format("book.xlsx", with_root_relationships).name(),
    content="xlsx",
  )
}

///|
test "detect_format rejects orphan relationship parts" {
  let broken = append_archive_part(
    @excel.write(@excel.new_file()),
    "xl/_rels/ghost.xml.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"https://example.com/relationships/workbook\" Target=\"workbook.xml\"/></Relationships>",
    ),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "relationship part has no source part: xl/_rels/ghost.xml.rels -> xl/ghost.xml",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected an orphan relationship part")
  }
}

///|
test "detect_format decodes UTF-16 package XML in either byte order" {
  let utf16 = reencode_identification_parts_as_utf16(
    @excel.write(@excel.new_file()),
  )
  inspect(@office.detect_format("book.xlsx", utf16).name(), content="xlsx")
}

///|
test "detect_format accepts namespace-prefixed and line-broken package XML" {
  let prefixed = prefix_xlsx_package_xml(@excel.write(@excel.new_file()), false)
  inspect(@office.detect_format("book.xlsx", prefixed).name(), content="xlsx")
}

///|
test "detect_format checks namespace-prefixed relationship targets" {
  let broken = prefix_xlsx_package_xml(@excel.write(@excel.new_file()), true)
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: relationship in xl/_rels/workbook.xml.rels points to a missing part: worksheets/missing.xml -> xl/worksheets/missing.xml",
      )
  } noraise {
    _ => fail("expected missing namespace-prefixed relationship target")
  }
}

///|
test "detect_format rejects relationships targeting package metadata" {
  let broken = add_root_relationship(
    @excel.write(@excel.new_file()),
    "<Relationship Id=\"rMetadata\" Type=\"https://example.com/relationships/metadata\" Target=\"[Content_Types].xml\"/>",
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "relationship in _rels/.rels points to package metadata: [Content_Types].xml -> [Content_Types].xml",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected a relationship to package metadata")
  }
}

///|
test "detect_format rejects absolute and network-path internal targets" {
  let source = @excel.write(@excel.new_file())
  for
    case in [
      ("//example.test/part.xml", "example.test/part.xml"),
      ("https://example.test/part.xml", "https:/example.test/part.xml"),
    ] {
    let (target, collapsed_name) = case
    let with_collapsed_part = append_archive_part(
      source,
      collapsed_name,
      @utf8.encode("<part/>"),
    )
    let broken = add_root_relationship(
      with_collapsed_part,
      "<Relationship Id=\"rAbsolute\" Type=\"https://example.com/relationships/test\" Target=\"\{target}\"/>",
    )
    try @office.detect_format("book.xlsx", broken) catch {
      err =>
        assert_true(
          Show::to_string(err).contains(
            "relationship in _rels/.rels has an invalid Target: \{target}",
          ),
        )
    } noraise {
      _ => fail("expected invalid internal target: \{target}")
    }
  }
}

///|
test "detect_format rejects an invalid relationship content type" {
  let broken = misdeclare_relationship_content_type(
    @excel.write(@excel.new_file()),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "relationship parts have an invalid default content type: application/octet-stream",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected an invalid relationship content type")
  }
}

///|
test "detect_format accepts a UTF-8 BOM in content types" {
  let data = @excel.write(@excel.new_file())
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let with_bom = replace_archive_part(
    data,
    "[Content_Types].xml",
    prepend_utf8_bom(content_types),
  )
  inspect(@office.detect_format("book.xlsx", with_bom).name(), content="xlsx")
}

///|
test "detect_format requires the XLSX officeDocument relationship" {
  let data = @excel.write(@excel.new_file())
  let broken = replace_archive_part(
    data,
    "_rels/.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"></Relationships>",
    ),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: XLSX root relationships do not declare an officeDocument relationship",
      )
  } noraise {
    _ => fail("expected missing officeDocument relationship")
  }
}

///|
test "detect_format requires an XLSX workbook main-part root" {
  let data = @excel.write(@excel.new_file())
  let broken = replace_archive_part(
    data,
    "xl/workbook.xml",
    @utf8.encode(
      "<notWorkbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"/>",
    ),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: XLSX main part root element is not workbook",
      )
  } noraise {
    _ => fail("expected invalid workbook root")
  }
}

///|
test "detect_format rejects CRC-corrupted XLSX entries" {
  let workbook = @excel.new_file()
  workbook.set_cell("Sheet1", "A1", "hello")
  let corrupted = corrupt_stored_payload(@excel.write(workbook), b"hello")
  try @office.detect_format("book.xlsx", corrupted) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "entry data does not match its stored CRC-32",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected CRC mismatch")
  }
}

///|
test "detect_format identifies generated docx" {
  let data = @word.new_blank_docx()
  inspect(@office.detect_format("report.docx", data).name(), content="docx")
}

///|
test "detect_format identifies DOCX with UTF-16 package XML" {
  let utf16 = reencode_identification_parts_as_utf16(@word.new_blank_docx())
  inspect(@office.detect_format("report.docx", utf16).name(), content="docx")
}

///|
test "detect_format binds the DOCX relationship to its declared main part" {
  let broken = misalign_docx_main_part(@word.new_blank_docx())
  try @office.detect_format("report.docx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: DOCX officeDocument relationship targets 'custom/main.xml', but content types declare 'word/document.xml'",
      )
  } noraise {
    _ => fail("expected DOCX main-part mismatch")
  }
}

///|
test "detect_format rejects malformed DOCX relationship metadata" {
  let broken = add_malformed_docx_relationship(@word.new_blank_docx())
  try @office.detect_format("report.docx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains("relationship in _rels/.rels has no Id"),
        content="true",
      )
  } noraise {
    _ => fail("expected malformed DOCX relationship metadata")
  }
}

///|
test "detect_format rejects extension and package mismatch" {
  let data = @word.new_blank_docx()
  try @office.detect_format("report.xlsx", data) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="file extension says xlsx, but package content is docx",
      )
  } noraise {
    _ => fail("expected format mismatch")
  }
}

///|
test "detect_format rejects unsupported extension before reading content" {
  try @office.detect_format("report.pdf", b"not a package") catch {
    err =>
      inspect(
        Show::to_string(err),
        content="unsupported file extension for 'report.pdf' (expected .xlsx or .docx)",
      )
  } noraise {
    _ => fail("expected unsupported extension")
  }
}

///|
test "detect_format rejects an invalid zip" {
  try @office.detect_format("report.docx", b"not a package") catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: archive is not a readable ZIP",
      )
  } noraise {
    _ => fail("expected invalid package")
  }
}

///|
test "detect_format does not accept a content-type marker in an XML comment" {
  let archive = @zip.Archive::new()
  archive.add(
    "[Content_Types].xml",
    @utf8.encode(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><!-- application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml --></Types>",
    ),
  )
  let data = @zip.write(archive)
  try @office.detect_format("book.xlsx", data) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: content types do not declare an XLSX or DOCX main part",
      )
  } noraise {
    _ => fail("expected invalid package")
  }
}

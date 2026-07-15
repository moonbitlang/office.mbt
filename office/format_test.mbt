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
      entry.data().to_owned()
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
fn append_content_type_override(
  data : BytesView,
  part_name : String,
  content_type : String,
) -> Bytes raise {
  let archive = @zip.read(data)
  guard archive.get("[Content_Types].xml") is Some(bytes) else {
    fail("test archive did not contain [Content_Types].xml")
  }
  let text = @utf8.decode(bytes, ignore_bom=true)
  let updated = text.replace(
    old="</Types>",
    new="<Override PartName=\"/\{part_name}\" ContentType=\"\{content_type}\"/></Types>",
  )
  if updated == text {
    fail("test could not extend [Content_Types].xml")
  }
  replace_archive_part(data, "[Content_Types].xml", @utf8.encode(updated))
}

///|
fn format_hash_clustered_relationship_names(
  count : Int,
  bucket_mask : Int,
) -> Array[String] {
  let names : Array[String] = []
  let mut candidate = 0
  while names.length() < count {
    let name = "word/stress/_rels/n\{candidate}.bin.rels"
    if (name.hash() & bucket_mask) == 0 {
      names.push(name)
    }
    candidate += 1
  }
  names
}

///|
fn add_relationship_stress_parts(data : BytesView, count : Int) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  let mut content_types_updated = false
  for entry in source.entries() {
    let content = if entry.name() == "[Content_Types].xml" {
      let text = @utf8.decode(entry.data(), ignore_bom=true)
      let updated = text.replace(
        old="</Types>",
        new="<Default Extension=\"bin\" ContentType=\"application/octet-stream\"/></Types>",
      )
      if updated == text {
        fail("test could not add the binary content-type default")
      }
      content_types_updated = true
      @utf8.encode(updated)
    } else {
      entry.data().to_owned()
    }
    result.add(
      entry.name(),
      content,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  if !content_types_updated {
    fail("test archive did not contain [Content_Types].xml")
  }
  let relationships = @utf8.encode(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>",
  )
  for
    relationships_name in format_hash_clustered_relationship_names(count, 0x3FF) {
    assert_eq(relationships_name.hash() & 0x3FF, 0)
    let file_name = relationships_name[18:relationships_name.length() - 5]
    let source_name = "word/stress/\{file_name}"
    result.add(source_name, b"")
    result.add(relationships_name, relationships)
  }
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
fn first_segment_colon_xlsx(target : String) -> Bytes raise {
  let archive = @zip.Archive::new()
  archive.add(
    "[Content_Types].xml",
    @utf8.encode(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/1:workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/></Types>",
    ),
  )
  archive.add(
    "_rels/.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"\{target}\"/></Relationships>",
    ),
  )
  archive.add(
    "1:workbook.xml",
    @utf8.encode(
      "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheets/></workbook>",
    ),
  )
  archive.add(
    "_rels/1:workbook.xml.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>",
    ),
  )
  @zip.write(archive)
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
      entry.data().to_owned()
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
fn reencode_archive_part_as_utf16(
  data : BytesView,
  name : String,
  declaration : String,
  bom : Bool,
  endianness : @utf16.Endian,
) -> Bytes raise {
  let source = @zip.read(data)
  guard source.get(name) is Some(part) else {
    fail("test archive did not contain \{name}")
  }
  let text = @utf8.decode(part, ignore_bom=true)
  let updated = text.replace(old="UTF-8", new=declaration)
  if updated == text {
    fail("test archive part did not declare UTF-8")
  }
  replace_archive_part(data, name, @utf16.encode(updated, bom~, endianness~))
}

///|
fn detect_format_error(filename : String, data : BytesView) -> String raise {
  try @office.detect_format(filename, data) catch {
    err => Show::to_string(err)
  } noraise {
    _ => fail("expected Office format detection to fail")
  }
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
      entry.data().to_owned()
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
      entry.data().to_owned()
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
fn replace_xlsx_main_target(data : BytesView, target : String) -> Bytes raise {
  let archive = @zip.read(data)
  let root_relationships = archive.get("_rels/.rels").unwrap()
  let text = @utf8.decode(root_relationships, ignore_bom=true)
  let updated = text.replace(
    old="Target=\"xl/workbook.xml\"",
    new="Target=\"\{target}\"",
  )
  if updated == text {
    fail("test could not replace the generated XLSX main target")
  }
  replace_archive_part(data, "_rels/.rels", @utf8.encode(updated))
}

///|
fn add_empty_segment_to_xlsx_main_target(data : BytesView) -> Bytes raise {
  replace_xlsx_main_target(data, "xl//workbook.xml")
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
fn replace_xml_default_content_type(
  data : BytesView,
  replacement : String,
) -> Bytes raise {
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let text = @utf8.decode(content_types, ignore_bom=true)
  let updated = text.replace(
    old="ContentType=\"application/xml\"",
    new="ContentType=\"\{replacement}\"",
  )
  if updated == text {
    fail("test could not replace the XML default content type")
  }
  replace_archive_part(data, "[Content_Types].xml", @utf8.encode(updated))
}

///|
fn replace_styles_override_content_type(
  data : BytesView,
  replacement : String,
) -> Bytes raise {
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let text = @utf8.decode(content_types, ignore_bom=true)
  let updated = text.replace(
    old="ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"",
    new="ContentType=\"\{replacement}\"",
  )
  if updated == text {
    fail("test could not replace the styles override content type")
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
fn vary_xlsx_content_type_case(data : BytesView) -> Bytes raise {
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let text = @utf8.decode(content_types, ignore_bom=true)
  let main_varied = text.replace(
    old="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
    new="Application/Vnd.OpenXmlFormats-OfficeDocument.SpreadsheetML.Sheet.Main+Xml",
  )
  let updated = main_varied.replace(
    old="application/vnd.openxmlformats-package.relationships+xml",
    new="Application/Vnd.OpenXmlFormats-Package.Relationships+Xml",
  )
  if main_varied == text || updated == main_varied {
    fail("test could not vary generated content-type casing")
  }
  replace_archive_part(data, "[Content_Types].xml", @utf8.encode(updated))
}

///|
fn add_content_type_default_child(data : BytesView) -> Bytes raise {
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let text = @utf8.decode(content_types, ignore_bom=true)
  let updated = text.replace(
    old="<Default Extension=\"xml\" ContentType=\"application/xml\"/>",
    new="<Default Extension=\"xml\" ContentType=\"application/xml\"><unexpected/></Default>",
  )
  if updated == text {
    fail("test could not add a Default child")
  }
  replace_archive_part(data, "[Content_Types].xml", @utf8.encode(updated))
}

///|
fn add_content_type_override_text(data : BytesView) -> Bytes raise {
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let text = @utf8.decode(content_types, ignore_bom=true)
  let updated = text.replace(
    old="<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>",
    new="<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\">unexpected</Override>",
  )
  if updated == text {
    fail("test could not add Override text")
  }
  replace_archive_part(data, "[Content_Types].xml", @utf8.encode(updated))
}

///|
fn add_manifest_content_type_override(data : BytesView) -> Bytes raise {
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let text = @utf8.decode(content_types, ignore_bom=true)
  let updated = text.replace(
    old="</Types>",
    new="<Override PartName=\"/[Content_Types].xml\" ContentType=\"application/xml\"/></Types>",
  )
  if updated == text {
    fail("test could not add a manifest content-type override")
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
test "detect_format compares OPC media types case-insensitively" {
  let data = vary_xlsx_content_type_case(@excel.write(@excel.new_file()))
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
    archive.get("xl/workbook.xml").unwrap().to_owned(),
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
test "detect_format rejects malformed OPC entry paths" {
  let source = @excel.write(@excel.new_file())
  for
    case in [
      ("custom//data.xml", "entry name contains an empty segment"),
      ("custom/%ZZ.xml", "entry name is not a valid OPC URI path"),
    ] {
    let (name, expected) = case
    let broken = append_archive_part(source, name, @utf8.encode("<data/>"))
    try @office.detect_format("book.xlsx", broken) catch {
      err => assert_true(Show::to_string(err).contains(expected))
    } noraise {
      _ => fail("expected malformed OPC entry path: \{name}")
    }
  }
}

///|
test "detect_format rejects derivable OPC part names in either archive order" {
  let source = @excel.write(@excel.new_file())
  let orders : Array[(String, String)] = [
    ("custom/a.xml", "custom/a.xml/b.xml"),
    ("custom/a.xml/b.xml", "custom/a.xml"),
  ]
  for order in orders {
    let broken = append_archive_part(
      append_archive_part(source, order.0, @utf8.encode("<first/>")),
      order.1,
      @utf8.encode("<second/>"),
    )
    try @office.detect_format("book.xlsx", broken) catch {
      err =>
        assert_true(
          Show::to_string(err).contains(
            "part name is derivable from another part name",
          ),
        )
    } noraise {
      _ => fail("expected derivable OPC PartNames to be rejected")
    }
  }
}

///|
test "detect_format rejects an override for the content-types manifest" {
  let broken = add_manifest_content_type_override(
    @excel.write(@excel.new_file()),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "content-type override names the reserved manifest: /[Content_Types].xml",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected an override for the reserved manifest")
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
test "detect_format classifies Relationships parts by their final path segments" {
  let source = @excel.write(@excel.new_file())
  let ordinary = append_content_type_override(
    append_archive_part(
      source,
      "word/_rels/nested/ghost.rels",
      @utf8.encode("<ordinary/>"),
    ),
    "word/_rels/nested/ghost.rels",
    "application/xml",
  )
  inspect(@office.detect_format("book.xlsx", ordinary).name(), content="xlsx")

  let nested_source = append_content_type_override(
    append_archive_part(source, "word/_rels/data.bin", b"payload"),
    "word/_rels/data.bin",
    "application/octet-stream",
  )
  let nested_relationships = append_archive_part(
    nested_source,
    "word/_rels/_rels/data.bin.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>",
    ),
  )
  inspect(
    @office.detect_format("book.xlsx", nested_relationships).name(),
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
test "detect_format accepts explicitly labelled BOMless UTF-16 package XML" {
  let source = @excel.write(@excel.new_file())
  let little = reencode_archive_part_as_utf16(
    source,
    "[Content_Types].xml",
    "UTF-16LE",
    false,
    Little,
  )
  inspect(@office.detect_format("book.xlsx", little).name(), content="xlsx")
  let big = reencode_archive_part_as_utf16(
    source,
    "[Content_Types].xml",
    "UTF-16BE",
    false,
    Big,
  )
  inspect(@office.detect_format("book.xlsx", big).name(), content="xlsx")
}

///|
test "detect_format rejects mismatched UTF-16 BOM and declarations" {
  let source = @excel.write(@excel.new_file())
  let expected = "invalid Office package: [Content_Types].xml is not well-formed XML"
  let cases : Array[(@utf16.Endian, Bool, String)] = [
    (Little, false, "UTF-16"),
    (Big, false, "UTF-16"),
    (Little, true, "UTF-16LE"),
    (Big, true, "UTF-16BE"),
  ]
  for case in cases {
    let (endianness, bom, declaration) = case
    let broken = reencode_archive_part_as_utf16(
      source, "[Content_Types].xml", declaration, bom, endianness,
    )
    assert_eq(detect_format_error("book.xlsx", broken), expected)
  }
}

///|
test "detect_format requires labels on BOMless UTF-16 package XML" {
  let source = @excel.write(@excel.new_file())
  guard @zip.read(source).get("[Content_Types].xml") is Some(part) else {
    fail("test workbook is missing its content-types manifest")
  }
  let text = @utf8.decode(part, ignore_bom=true)
  let expected = "invalid Office package: [Content_Types].xml is not well-formed XML"
  let endiannesses : Array[@utf16.Endian] = [Little, Big]
  for endianness in endiannesses {
    let broken = replace_archive_part(
      source,
      "[Content_Types].xml",
      @utf16.encode(text, bom=false, endianness~),
    )
    assert_eq(detect_format_error("book.xlsx", broken), expected)
  }
}

///|
test "detect_format rejects declarations that contradict UTF-8 package XML" {
  let source = @excel.write(@excel.new_file())
  let archive = @zip.read(source)
  guard archive.get("[Content_Types].xml") is Some(types_bytes) else {
    fail("test workbook is missing its content-types manifest")
  }
  let types = @utf8.decode(types_bytes, ignore_bom=true)
  let contradictory = types.replace(old="UTF-8", new="UTF-16")
  assert_true(contradictory != types)
  let broken = replace_archive_part(
    source,
    "[Content_Types].xml",
    @utf8.encode(contradictory),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: [Content_Types].xml is not well-formed XML",
      )
  } noraise {
    _ => fail("expected a contradictory XML declaration to fail")
  }
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
    "<Relationship Id=\"rMetadata\" Type=\"https://example.com/relationships/metadata\" Target=\"_rels/.rels\"/>",
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "relationship in _rels/.rels points to package metadata: _rels/.rels -> _rels/.rels",
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
test "relative targets require an unambiguous first-segment colon" {
  try
    @office.detect_format(
      "ambiguous.xlsx",
      first_segment_colon_xlsx("1:workbook.xml"),
    )
  catch {
    err => {
      let message = Show::to_string(err)
      if !message.contains(
          "XLSX officeDocument relationship has an invalid Target",
        ) {
        fail("unexpected target diagnostic: \{message}")
      }
    }
  } noraise {
    _ => fail("expected an ambiguous first-segment colon to fail")
  }
  inspect(
    @office.detect_format(
      "explicit-relative.xlsx",
      first_segment_colon_xlsx("./1:workbook.xml"),
    ).name(),
    content="xlsx",
  )
}

///|
test "detect_format rejects empty relationship target segments" {
  let broken = add_empty_segment_to_xlsx_main_target(
    @excel.write(@excel.new_file()),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: XLSX officeDocument relationship has an invalid Target",
      )
  } noraise {
    _ => fail("expected an empty relationship target segment")
  }
}

///|
test "detect_format shares package-rooted OPC target normalization" {
  let source = @excel.write(@excel.new_file())
  let rooted = replace_xlsx_main_target(source, "/xl/./workbook.xml")
  assert_eq(@office.detect_format("book.xlsx", rooted), Xlsx)
  let escaping = replace_xlsx_main_target(source, "/../xl/workbook.xml")
  try @office.detect_format("book.xlsx", escaping) catch {
    error =>
      inspect(
        Show::to_string(error),
        content="invalid Office package: XLSX officeDocument relationship has an invalid Target",
      )
  } noraise {
    _ => fail("expected above-root package target rejection")
  }
}

///|
test "detect_format requires absolute relationship Type IRIs" {
  let broken = add_root_relationship(
    @excel.write(@excel.new_file()),
    "<Relationship Id=\"rRelativeType\" Type=\"worksheet\" Target=\"xl/workbook.xml\"/>",
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "relationship in _rels/.rels has a non-absolute Type: worksheet",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected a relative relationship Type")
  }
}

///|
test "detect_format rejects invalid characters in relationship Type IRIs" {
  let broken = add_root_relationship(
    @excel.write(@excel.new_file()),
    "<Relationship Id=\"rInvalidType\" Type=\"https://example.com/{invalid}\" Target=\"xl/workbook.xml\"/>",
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "relationship in _rels/.rels has an invalid Type IRI: https://example.com/{invalid}",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected an invalid relationship Type IRI")
  }
}

///|
test "detect_format rejects malformed relationship Type IRI components" {
  let source = @excel.write(@excel.new_file())
  for
    rel_type in [
      "https://example.com/a[b]", "https://example.com:port/path", "https://user@@example.com/path",
      "https://[2001:db8:::1]/path",
    ] {
    let broken = add_root_relationship(
      source,
      "<Relationship Id=\"rInvalidType\" Type=\"\{rel_type}\" Target=\"xl/workbook.xml\"/>",
    )
    try @office.detect_format("book.xlsx", broken) catch {
      err =>
        assert_true(
          Show::to_string(err).contains(
            "relationship in _rels/.rels has an invalid Type IRI: \{rel_type}",
          ),
        )
    } noraise {
      _ => fail("expected a malformed relationship Type IRI: \{rel_type}")
    }
  }
}

///|
test "detect_format requires relationship IDs to be XML NCNames" {
  let broken = add_root_relationship(
    @excel.write(@excel.new_file()),
    "<Relationship Id=\"1 bad\" Type=\"https://example.com/relationships/test\" Target=\"xl/workbook.xml\"/>",
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "relationship in _rels/.rels has an invalid Id: 1 bad",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected an invalid relationship Id")
  }
}

///|
test "detect_format validates external relationship target URIs" {
  let source = @excel.write(@excel.new_file())
  for
    target in [
      "\\bad", "https://example.com/{invalid}", "https://example.com/a[b]", "https://example.com:port/path",
      "https://user@@example.com/path", "https://[2001:db8:::1]/path", "file:///C:\\bad{path}",
      "file:///C:\\bad%ZZ", "file:///\\\\server", "file:///\\\\server\\", "file:///\\\\server\\bad{share}\\file.docx",
      "file:///\\\\server\\share\\bad%ZZ",
    ] {
    let broken = add_root_relationship(
      source,
      "<Relationship Id=\"rExternal\" Type=\"https://example.com/relationships/test\" Target=\"\{target}\" TargetMode=\"External\"/>",
    )
    try @office.detect_format("book.xlsx", broken) catch {
      err =>
        assert_true(
          Show::to_string(err).contains(
            "relationship in _rels/.rels has an invalid external Target: \{target}",
          ),
        )
    } noraise {
      _ => fail("expected an invalid external relationship target: \{target}")
    }
  }
}

///|
test "detect_format accepts valid external IRI references and Unicode IDs" {
  let source = @excel.write(@excel.new_file())
  for
    case in [
      ("rél", "https://example.com/a%20b?q=x/y&amp;v=1#frag"),
      ("rIpv6", "https://user:pass@[2001:db8::1]:443/path"),
      ("rUrn", "urn:example:component"),
      ("rRelative", "../relative/path?x/y"),
      (
        "rUnicodeHttps", "https://例え.テスト/資料/文書.docx?名前=値#節",
      ),
      ("rUnicodeRelative", "../資料/文書.docx?名前=値"),
      ("rFileHost", "file://server/共有/文書.docx"),
    ] {
    let (id, target) = case
    let with_external = add_root_relationship(
      source,
      "<Relationship Id=\"\{id}\" Type=\"https://example.com/relationships/test\" Target=\"\{target}\" TargetMode=\"External\"/>",
    )
    inspect(
      @office.detect_format("book.xlsx", with_external).name(),
      content="xlsx",
    )
  }
}

///|
test "detect_format accepts Office Windows drive and UNC file IRIs" {
  let source = @excel.write(@excel.new_file())
  for
    case in [
      (
        "rDrive", "file:///C:\\Documents%20and%20Settings\\Kokoskova\\Laďulik\\Sablona.dot",
      ),
      ("rUnc", "file:///\\\\server\\共有\\文書.docx"),
    ] {
    let (id, target) = case
    let with_external = add_root_relationship(
      source,
      "<Relationship Id=\"\{id}\" Type=\"https://example.com/relationships/template\" Target=\"\{target}\" TargetMode=\"External\"/>",
    )
    inspect(
      @office.detect_format("book.xlsx", with_external).name(),
      content="xlsx",
    )
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
test "detect_format rejects malformed auxiliary content types" {
  let source = @excel.write(@excel.new_file())
  for content_type in ["not a media type", "application", "application/"] {
    let broken = replace_xml_default_content_type(source, content_type)
    try @office.detect_format("book.xlsx", broken) catch {
      err =>
        assert_true(
          Show::to_string(err).contains(
            "[Content_Types].xml: Default has an invalid ContentType: \{content_type}",
          ),
        )
    } noraise {
      _ => fail("expected a malformed auxiliary content type: \{content_type}")
    }
  }
}

///|
test "detect_format validates content types on auxiliary overrides" {
  let content_type = "not a media type"
  let broken = replace_styles_override_content_type(
    @excel.write(@excel.new_file()),
    content_type,
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      assert_true(
        Show::to_string(err).contains(
          "[Content_Types].xml: Override has an invalid ContentType: \{content_type}",
        ),
      )
  } noraise {
    _ => fail("expected a malformed auxiliary override content type")
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
test "detect_format rejects duplicate attributes in every required XML layer" {
  let source = @excel.write(@excel.new_file())
  for
    case in [
      ("[Content_Types].xml", "<Types "),
      ("_rels/.rels", "<Relationships "),
      ("xl/workbook.xml", "<workbook "),
    ] {
    let (part_name, root_start) = case
    let archive = @zip.read(source)
    let text = @utf8.decode(archive.get(part_name).unwrap(), ignore_bom=true)
    let malformed = text.replace(
      old=root_start,
      new=root_start + "duplicate=\"first\" duplicate=\"second\" ",
    )
    if malformed == text {
      fail("test could not add duplicate attributes to \{part_name}")
    }
    let broken = replace_archive_part(
      source,
      part_name,
      @utf8.encode(malformed),
    )
    try @office.detect_format("book.xlsx", broken) catch {
      err =>
        inspect(
          Show::to_string(err),
          content="invalid Office package: \{part_name} is not well-formed XML",
        )
    } noraise {
      _ => fail("expected duplicate attributes in \{part_name} to be rejected")
    }
  }
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
test "detect_format follows Unicode logical OPC part names" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_override(
    "/word/é.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override("/word/É.xml", "application/xml")
  builder.add_relationship(
    "rMain", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/é.xml",
  )
  builder.add_part(
    "word/é.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  // OPC part-name identity folds ASCII only: these are two distinct parts.
  builder.add_part("word/É.xml", @utf8.encode("<extra/>"))
  let data = builder.build()
  let archive = @zip.read(data)
  assert_true(archive.get("word/%C3%A9.xml") is Some(_))
  assert_true(archive.get("word/%C3%89.xml") is Some(_))
  inspect(@office.detect_format("unicode.docx", data).name(), content="docx")
}

///|
test "detect_format rejects mixed main relationship and OOXML dialects" {
  let source = @word.new_blank_docx()
  let archive = @zip.read(source)
  guard archive.get("_rels/.rels") is Some(root_rels) else {
    fail("test DOCX has no root relationships")
  }
  let relationships = @utf8.decode(root_rels, ignore_bom=true)
  let transitional = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
  let strict = "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"
  let mixed = relationships.replace(old=transitional, new=strict)
  assert_true(mixed != relationships)
  let broken = replace_archive_part(source, "_rels/.rels", @utf8.encode(mixed))
  try @office.detect_format("report.docx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: DOCX officeDocument relationship dialect does not match the main OOXML namespace",
      )
  } noraise {
    _ => fail("expected mixed OOXML dialects to be rejected")
  }
}

///|
test "detect_format ignores deterministic hash clustering in package names" {
  let data = add_relationship_stress_parts(@word.new_blank_docx(), 512)
  inspect(@office.detect_format("report.docx", data).name(), content="docx")
}

///|
test "detect_format identifies DOCX with UTF-16 package XML" {
  let utf16 = reencode_identification_parts_as_utf16(@word.new_blank_docx())
  inspect(@office.detect_format("report.docx", utf16).name(), content="docx")
}

///|
test "detect_format applies ProcessContent to UTF-16 root relationships" {
  let wrapped = replace_archive_part(
    @word.new_blank_docx(),
    "_rels/.rels",
    @utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
        #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        #| xmlns:v="urn:mbtexcel:test:vendor"
        #| mc:Ignorable="v" mc:ProcessContent="v:Wrapper">
        #| <v:Wrapper><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></v:Wrapper>
        #|</Relationships>
      ),
    ),
  )
  let utf16 = reencode_identification_parts_as_utf16(wrapped)
  inspect(@office.detect_format("report.docx", utf16).name(), content="docx")
}

///|
test "detect_format selects understood relationship AlternateContent" {
  let selected = replace_archive_part(
    @word.new_blank_docx(),
    "_rels/.rels",
    @utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
        #| xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships"
        #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">
        #| <mc:AlternateContent>
        #|  <mc:Choice Requires="r"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></mc:Choice>
        #|  <mc:Fallback><Relationship Id="decoy" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/missing.xml"/></mc:Fallback>
        #| </mc:AlternateContent>
        #|</Relationships>
      ),
    ),
  )
  inspect(@office.detect_format("report.docx", selected).name(), content="docx")
}

///|
test "detect_format collapses relationship identity whitespace" {
  let padded = replace_archive_part(
    @word.new_blank_docx(),
    "_rels/.rels",
    @utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id=" &#x9; rId1 &#xA; " Type=" http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument " Target=" word/document.xml "/></Relationships>
      ),
    ),
  )
  inspect(@office.detect_format("report.docx", padded).name(), content="docx")
}

///|
test "detect_format accepts Unicode relationship Type IRIs" {
  let data = add_root_relationship(
    @word.new_blank_docx(),
    "<Relationship Id=\"unicodeType\" Type=\"https://例え.テスト/型\" Target=\"https://例え.テスト/文書\" TargetMode=\"External\"/>",
  )
  inspect(@office.detect_format("report.docx", data).name(), content="docx")
}

///|
test "detect_format accepts Relationship simple content" {
  let data = add_root_relationship(
    @word.new_blank_docx(),
    "<Relationship Id=\"simpleContent\" Type=\"https://example.com/relationships/note\" Target=\"https://example.com/note\" TargetMode=\"External\">schema string content</Relationship>",
  )
  inspect(@office.detect_format("report.docx", data).name(), content="docx")
}

///|
test "detect_format retains unknown MCE attributes for closed validation" {
  let annotated = replace_archive_part(
    @word.new_blank_docx(),
    "_rels/.rels",
    @utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
        #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        #| mc:Bogus="retained"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
      ),
    ),
  )
  try @office.detect_format("report.docx", annotated) catch {
    err => {
      let message = Show::to_string(err)
      assert_true(
        message.contains(
          "_rels/.rels Relationships has an undeclared attribute: {http://schemas.openxmlformats.org/markup-compatibility/2006}Bogus",
        ),
      )
    }
  } noraise {
    _ => fail("expected an unknown MCE attribute to remain schema-visible")
  }
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
test "detect_format rejects content inside OPC metadata declarations" {
  let source = @excel.write(@excel.new_file())
  for
    case in [
      (
        add_content_type_default_child(source),
        "[Content_Types].xml: Default element is not empty",
      ),
      (
        add_content_type_override_text(source),
        "[Content_Types].xml: Override element is not empty",
      ),
      (
        add_root_relationship(
          source, "<Relationship Id=\"rNested\" Type=\"https://example.com/relationships/test\" Target=\"xl/workbook.xml\"><unexpected/></Relationship>",
        ),
        "relationship in _rels/.rels contains a child element",
      ),
    ] {
    let (broken, expected) = case
    try @office.detect_format("book.xlsx", broken) catch {
      err => assert_true(Show::to_string(err).contains(expected))
    } noraise {
      _ => fail("expected non-empty OPC metadata declaration")
    }
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

///|
fn style_map_embedding_zip(entries : Array[(String, String)]) -> Bytes raise {
  let archive = @mbtzip.Archive::new()
  for entry in entries {
    let (path, text) = entry
    archive.add(path, @utf8.encode(text), compression=Deflate)
  }
  @mbtzip.write(archive)
}

///|
fn normal_style_map_embedding_docx() -> Bytes raise {
  let original_relationships_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/></Relationships>"
  let original_content_types_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"png\" ContentType=\"image/png\"/></Types>"
  style_map_embedding_docx_from_parts(
    original_relationships_xml, original_content_types_xml,
  )
}

///|
fn style_map_embedding_docx_from_parts(
  relationships_xml : String,
  content_types_xml : String,
) -> Bytes raise {
  style_map_embedding_zip([
    ("word/_rels/document.xml.rels", relationships_xml),
    ("[Content_Types].xml", content_types_xml),
  ])
}

///|
fn expected_embedded_style_map_relationships_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/><Relationship Id=\"rMammothStyleMap\" Type=\"http://schemas.zwobble.org/mammoth/style-map\" Target=\"/mammoth/style-map\"/></Relationships>"
}

///|
fn expected_embedded_style_map_content_types_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"png\" ContentType=\"image/png\"/><Override PartName=\"/mammoth/style-map\" ContentType=\"text/prs.mammoth.style-map\"/></Types>"
}

///|
/// Independent CRC-32 (bit-serial, IEEE polynomial), implemented locally so
/// header checks below do not depend on the zip package under test.
fn independent_crc32(data : BytesView) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for byte in data {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      if (crc & 1) != 0 {
        crc = (crc >> 1) ^ 0xEDB88320
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xFFFFFFFF
}

///|
fn zip_u16_at(data : BytesView, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn zip_u32_at(data : BytesView, offset : Int) -> UInt {
  data[offset].to_uint() |
  (data[offset + 1].to_uint() << 8) |
  (data[offset + 2].to_uint() << 16) |
  (data[offset + 3].to_uint() << 24)
}

///|
fn zip_name_at(data : BytesView, offset : Int, length : Int) -> String raise {
  @utf8.decode(data[offset:offset + length].to_owned())
}

///|
/// Structural ZIP validation done directly on the archive bytes — an
/// independent oracle replacing the external-fzip roundtrip the old test
/// performed. Walks the end-of-central-directory record, every central
/// directory header, and every referenced local file header, checking
/// signatures, name agreement, entry order, and that the recorded CRC-32 of
/// each expected part equals an independently computed CRC of its known
/// plaintext. (Content equivalence itself is asserted separately via
/// `open_zip`; the fixture corpus of real Word files pins that reader.)
fn assert_zip_well_formed(
  bytes : Bytes,
  expected_parts : Array[(String, String)],
) -> Unit raise {
  let data = bytes[:]
  // End of central directory: signature PK\x05\x06, no comment expected.
  let eocd = data.length() - 22
  assert_true(eocd >= 0)
  assert_eq(zip_u32_at(data, eocd), 0x06054B50)
  let entry_count = zip_u16_at(data, eocd + 10)
  assert_eq(entry_count, expected_parts.length())
  let central_size = zip_u32_at(data, eocd + 12).reinterpret_as_int()
  let central_offset = zip_u32_at(data, eocd + 16).reinterpret_as_int()
  assert_eq(central_offset + central_size, eocd)
  // Walk the central directory in order.
  let mut cursor = central_offset
  for index in 0..<entry_count {
    assert_eq(zip_u32_at(data, cursor), 0x02014B50)
    let compression_method = zip_u16_at(data, cursor + 10)
    assert_true(compression_method == 0 || compression_method == 8)
    let crc = zip_u32_at(data, cursor + 16)
    let name_len = zip_u16_at(data, cursor + 28)
    let extra_len = zip_u16_at(data, cursor + 30)
    let comment_len = zip_u16_at(data, cursor + 32)
    let local_offset = zip_u32_at(data, cursor + 42).reinterpret_as_int()
    let name = zip_name_at(data, cursor + 46, name_len)
    let (expected_name, expected_text) = expected_parts[index]
    assert_eq(name, expected_name)
    assert_eq(crc, independent_crc32(@utf8.encode(expected_text)))
    // The referenced local header must exist, agree on the name, and use the
    // same compression method.
    assert_eq(zip_u32_at(data, local_offset), 0x04034B50)
    let local_name_len = zip_u16_at(data, local_offset + 26)
    assert_eq(zip_name_at(data, local_offset + 30, local_name_len), name)
    assert_eq(zip_u16_at(data, local_offset + 8), compression_method)
    cursor = cursor + 46 + name_len + extra_len + comment_len
  }
}

///|
test "embedded style map output is a well-formed ZIP (independent check)" {
  let written = @docx2html.embed_style_map(
    normal_style_map_embedding_docx(),
    "p => h1",
  )
  assert_zip_well_formed(written, [
    (
      "word/_rels/document.xml.rels",
      expected_embedded_style_map_relationships_xml(),
    ),
    ("[Content_Types].xml", expected_embedded_style_map_content_types_xml()),
    ("mammoth/style-map", "p => h1"),
  ])
}

///|
test "embedded style map can be written and read" {
  let written = @docx2html.embed_style_map(
    normal_style_map_embedding_docx(),
    "p => h1",
  )
  debug_inspect(
    @docx2html.read_embedded_style_map(written),
    content="Some(\"p => h1\")",
  )
  let zip = @docx2html.open_zip(written)
  inspect(zip.read_text("mammoth/style-map").unwrap(), content="p => h1")
  inspect(
    zip.read_text("word/_rels/document.xml.rels").unwrap(),
    content=expected_embedded_style_map_relationships_xml(),
  )
  inspect(
    zip.read_text("[Content_Types].xml").unwrap(),
    content=expected_embedded_style_map_content_types_xml(),
  )
}

///|
test "re-embedding style map replaces original metadata" {
  let first = @docx2html.embed_style_map(
    normal_style_map_embedding_docx(),
    "p => h1",
  )
  let second = @docx2html.embed_style_map(first, "p => h2")
  debug_inspect(
    @docx2html.read_embedded_style_map(second),
    content="Some(\"p => h2\")",
  )
  let zip = @docx2html.open_zip(second)
  inspect(
    zip.read_text("word/_rels/document.xml.rels").unwrap(),
    content=expected_embedded_style_map_relationships_xml(),
  )
  inspect(
    zip.read_text("[Content_Types].xml").unwrap(),
    content=expected_embedded_style_map_content_types_xml(),
  )
}

///|
test "embedding style map preserves permitted physical ZIP entry spelling" {
  let relationships_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>"
  let content_types_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Override PartName=\"/MAMMOTH/STYLE-MAP\" ContentType=\"application/old\"/></Types>"
  let written = @docx2html.embed_style_map(
    style_map_embedding_zip([
      ("WORD/_RELS/DOCUMENT.XML.RELS", relationships_xml),
      ("[Content_Types].xml", content_types_xml),
      ("MAMMOTH/STYLE-MAP", "old"),
    ]),
    "p => h1",
  )
  let archive = @mbtzip.read(written)
  guard archive.get("WORD/_RELS/DOCUMENT.XML.RELS") is Some(relationships) else {
    fail("expected original relationships entry spelling")
  }
  inspect(
    @utf8.decode(relationships),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rMammothStyleMap\" Type=\"http://schemas.zwobble.org/mammoth/style-map\" Target=\"/mammoth/style-map\"/></Relationships>",
  )
  guard archive.get("[Content_Types].xml") is Some(content_types) else {
    fail("expected required content-types entry spelling")
  }
  inspect(
    @utf8.decode(content_types),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Override PartName=\"/MAMMOTH/STYLE-MAP\" ContentType=\"text/prs.mammoth.style-map\"/></Types>",
  )
  guard archive.get("MAMMOTH/STYLE-MAP") is Some(style_map) else {
    fail("expected original style-map entry spelling")
  }
  inspect(@utf8.decode(style_map), content="p => h1")
  assert_true(archive.get("word/_rels/document.xml.rels") is None)
  assert_true(archive.get("mammoth/style-map") is None)
}

///|
test "embedding style map rejects duplicate ZIP identities without panicking" {
  let relationships_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>"
  let content_types_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>"
  let aliased = style_map_embedding_zip([
    ("word/_rels/document.xml.rels", relationships_xml),
    ("[Content_Types].xml", content_types_xml),
    ("custom.xml", "first"),
    ("CUSTOM.XML", "second"),
  ])
  try @docx2html.embed_style_map(aliased, "p => h1") catch {
    InvalidZip(message~) =>
      assert_true(
        message.has_prefix(
          "duplicate ZIP entry names after case normalization:",
        ),
      )
    _ => fail("expected InvalidZip")
  } noraise {
    _ => fail("expected case-alias failure")
  }
  let duplicated = style_map_embedding_zip([
    ("word/_rels/document.xml.rels", relationships_xml),
    ("[Content_Types].xml", content_types_xml),
    ("custom.xml", "first"),
    ("custom.xml", "second"),
  ])
  try @docx2html.embed_style_map(duplicated, "p => h1") catch {
    InvalidZip(message~) =>
      inspect(message, content="duplicate ZIP entry name: custom.xml")
    _ => fail("expected InvalidZip")
  } noraise {
    _ => fail("expected duplicate-name failure")
  }
}

///|
test "embedding style map preserves existing metadata" {
  let relationships_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rExternal\" Type=\"http://example.com/relationship\" Target=\"https://example.com\" TargetMode=\"External\"/></Relationships>"
  let content_types_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n<Default Extension=\"png\" ContentType=\"image/png\"/><Ignored/><Override PartName=\"/custom.xml\" ContentType=\"application/custom+xml\"/></Types>"
  let written = @docx2html.embed_style_map(
    style_map_embedding_docx_from_parts(relationships_xml, content_types_xml),
    "p => h1",
  )
  let zip = @docx2html.open_zip(written)
  inspect(
    zip.read_text("word/_rels/document.xml.rels").unwrap(),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rExternal\" Type=\"http://example.com/relationship\" Target=\"https://example.com\" TargetMode=\"External\"/><Relationship Id=\"rMammothStyleMap\" Type=\"http://schemas.zwobble.org/mammoth/style-map\" Target=\"/mammoth/style-map\"/></Relationships>",
  )
  inspect(
    zip.read_text("[Content_Types].xml").unwrap(),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"png\" ContentType=\"image/png\"/><Override PartName=\"/custom.xml\" ContentType=\"application/custom+xml\"/><Override PartName=\"/mammoth/style-map\" ContentType=\"text/prs.mammoth.style-map\"/></Types>",
  )
}

///|
test "embedding style map normalizes a dot-aliased content-type override" {
  let relationships_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>"
  let content_types_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Override PartName=\"/mammoth/./style-map\" ContentType=\"application/old\"/></Types>"
  let written = @docx2html.embed_style_map(
    style_map_embedding_docx_from_parts(relationships_xml, content_types_xml),
    "p => h1",
  )
  let zip = @docx2html.open_zip(written)
  inspect(
    zip.read_text("[Content_Types].xml").unwrap(),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Override PartName=\"/mammoth/style-map\" ContentType=\"text/prs.mammoth.style-map\"/></Types>",
  )
}

///|
test "embedding style map rejects ambiguous normalized metadata" {
  let empty_relationships = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>"
  let duplicate_overrides = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Override PartName=\"/mammoth/style-map\" ContentType=\"application/one\"/><Override PartName=\"/MAMMOTH/./STYLE-MAP\" ContentType=\"application/two\"/></Types>"
  let override_input = style_map_embedding_docx_from_parts(
    empty_relationships, duplicate_overrides,
  )
  try @docx2html.embed_style_map(override_input, "p => h1") catch {
    InvalidXml(message~) =>
      inspect(
        message,
        content="duplicate embedded style-map content-type override after OPC path normalization",
      )
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected duplicate override failure")
  }
  let duplicate_relationships = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rMammothStyleMap\" Type=\"http://example.com/one\" Target=\"one\"/><Relationship Id=\"rMammothStyleMap\" Type=\"http://example.com/two\" Target=\"two\"/></Relationships>"
  let empty_content_types = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>"
  let relationship_input = style_map_embedding_docx_from_parts(
    duplicate_relationships, empty_content_types,
  )
  try @docx2html.embed_style_map(relationship_input, "p => h1") catch {
    InvalidXml(message~) =>
      inspect(
        message,
        content="duplicate embedded style-map relationship Id: rMammothStyleMap",
      )
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected duplicate relationship failure")
  }
}

///|
test "embedding style map reports invalid archives and missing metadata" {
  try @docx2html.embed_style_map(b"not a zip", "p => h1") catch {
    InvalidZip(message~) =>
      inspect(message.has_prefix("invalid ZIP archive:"), content="true")
    _ => fail("expected InvalidZip")
  } noraise {
    _ => fail("expected invalid ZIP failure")
  }
  let missing_relationships = style_map_embedding_zip([
    (
      "[Content_Types].xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>",
    ),
  ])
  try @docx2html.embed_style_map(missing_relationships, "p => h1") catch {
    MissingPart(message~) =>
      inspect(
        message,
        content="missing DOCX part: word/_rels/document.xml.rels",
      )
    _ => fail("expected MissingPart")
  } noraise {
    _ => fail("expected missing metadata failure")
  }
}

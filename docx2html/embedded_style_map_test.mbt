///|
fn style_map_embedding_fixture_text(text : String) -> FixedArray[Byte] {
  FixedArray::from_array(@utf8.encode(text).to_array())
}

///|
fn normal_style_map_embedding_docx() -> Bytes {
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
) -> Bytes {
  Bytes::from_array(
    @fzip.zip_sync([
      (
        "word/_rels/document.xml.rels",
        style_map_embedding_fixture_text(relationships_xml),
      ),
      (
        "[Content_Types].xml",
        style_map_embedding_fixture_text(content_types_xml),
      ),
    ]),
  )
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
test "embedded style map can be written and read" {
  let written = @docx2html.embed_style_map(
    normal_style_map_embedding_docx()[:],
    "p => h1",
  )
  debug_inspect(
    @docx2html.read_embedded_style_map(written[:]),
    content="Some(\"p => h1\")",
  )
  let zip = @docx2html.open_zip(written[:])
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
    normal_style_map_embedding_docx()[:],
    "p => h1",
  )
  let second = @docx2html.embed_style_map(first[:], "p => h2")
  debug_inspect(
    @docx2html.read_embedded_style_map(second[:]),
    content="Some(\"p => h2\")",
  )
  let zip = @docx2html.open_zip(second[:])
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
test "embedding style map preserves existing metadata" {
  let relationships_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rExternal\" Type=\"http://example.com/relationship\" Target=\"https://example.com\" TargetMode=\"External\"/></Relationships>"
  let content_types_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n<Default Extension=\"png\" ContentType=\"image/png\"/><Ignored/><Override PartName=\"/custom.xml\" ContentType=\"application/custom+xml\"/></Types>"
  let written = @docx2html.embed_style_map(
    style_map_embedding_docx_from_parts(relationships_xml, content_types_xml)[:],
    "p => h1",
  )
  let zip = @docx2html.open_zip(written[:])
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
test "embedding style map reports invalid archives and missing metadata" {
  try @docx2html.embed_style_map(b"not a zip"[:], "p => h1") catch {
    InvalidZip(message~) =>
      inspect(message.has_prefix("invalid ZIP archive:"), content="true")
    _ => fail("expected InvalidZip")
  } noraise {
    _ => fail("expected invalid ZIP failure")
  }
  let missing_relationships = Bytes::from_array(
    @fzip.zip_sync([
      (
        "[Content_Types].xml",
        style_map_embedding_fixture_text(
          "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>",
        ),
      ),
    ]),
  )
  try @docx2html.embed_style_map(missing_relationships[:], "p => h1") catch {
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

// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
fn empty_body_reader(relationships : Relationships) -> BodyReader {
  {
    styles: {},
    zip: { entries: {} },
    relationships,
    content_types: { defaults: {}, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: default_external_file_access(),
    read_images: true,
  }
}

///|
fn body_reader_with_numbering(
  styles : Map[String, StyleInfo],
  numbering : NumberingMap,
) -> BodyReader {
  {
    styles,
    zip: { entries: {} },
    relationships: { relationships: [] },
    content_types: { defaults: {}, overrides: {} },
    base_path: "word",
    numbering,
    messages: [],
    external_files: default_external_file_access(),
    read_images: true,
  }
}

///|
fn numbering_from_xml(
  xml : String,
  styles : Map[String, StyleInfo],
) -> NumberingMap raise DocxError {
  read_numbering_xml(
    read_xml_string(xml, namespace_map=office_namespace_map()),
    styles,
  )
}

///|
fn zip_with_text(path : String, text : String) -> ZipArchive {
  let entries : Map[String, Bytes] = {}
  entries[path] = @utf8.encode(text)
  { entries, }
}

///|
fn styles_from_xml(xml : String) -> Map[String, StyleInfo] raise DocxError {
  read_styles(zip_with_text("word/styles.xml", xml), "word/styles.xml")
}

///|
fn relationship_part(relationship_type : String, target : String) -> String {
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rPart\" Type=\"" +
  relationship_type +
  "\" Target=\"" +
  target +
  "\" /></Relationships>"
}

///|
fn empty_docx_zip() -> ZipArchive {
  let xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body /></w:document>
  zip_with_text("word/document.xml", xml)
}

///|
fn run_properties_from_xml(
  properties_xml : String,
  styles? : Map[String, StyleInfo] = {},
) -> RunProperties raise DocxError {
  let xml = "<w:r xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:rPr>" +
    properties_xml +
    "</w:rPr></w:r>"
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  match
    body_reader_with_numbering(styles, NumberingMap::empty()).read_element(root)[0] {
    Run(properties~, ..) => properties
    _ => abort("expected run")
  }
}

///|
fn body_elements_from_xml(
  element_xml : String,
) -> Array[DocumentElement] raise DocxError {
  let xml = "<w:root xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    element_xml +
    "</w:root>"
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  empty_body_reader({ relationships: [] }).read_children(root.children)
}

///|
fn paragraph_properties_from_xml(
  properties_xml : String,
  styles? : Map[String, StyleInfo] = {},
) -> ParagraphProperties raise DocxError {
  let xml = "<w:p xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:pPr>" +
    properties_xml +
    "</w:pPr></w:p>"
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  match
    body_reader_with_numbering(styles, NumberingMap::empty()).read_element(root)[0] {
    Paragraph(properties~, ..) => properties
    _ => abort("expected paragraph")
  }
}

///|
fn paragraph_numbering_from_xml(
  properties_xml : String,
  styles : Map[String, StyleInfo],
  numbering : NumberingMap,
) -> Numbering? raise DocxError {
  let xml = "<w:p xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:pPr>" +
    properties_xml +
    "</w:pPr></w:p>"
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  match body_reader_with_numbering(styles, numbering).read_element(root)[0] {
    Paragraph(properties~, ..) => properties.numbering
    _ => abort("expected paragraph")
  }
}

///|
fn footnotes_from_xml(xml : String) -> NotesReadResult raise DocxError {
  read_note_part(
    zip_with_text("word/footnotes.xml", xml),
    note_type="footnote",
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    fallback_path="word/footnotes.xml",
    styles={},
    numbering=NumberingMap::empty(),
    content_types={ defaults: {}, overrides: {} },
    document_relationships={ relationships: [] },
    base_path="word",
  )
}

///|
fn comments_from_xml(xml : String) -> CommentsReadResult raise DocxError {
  read_comments_for_document(
    zip_with_text("word/comments.xml", xml),
    {},
    NumberingMap::empty(),
    { defaults: {}, overrides: {} },
    { relationships: [] },
    "word",
  )
}

///|
test "style document matchers follow Mammoth predicate semantics" {
  let plain = paragraph([])
  let styled = paragraph([], properties={
    style_id: Some("Heading1"),
    style_name: Some("Heading 1"),
    numbering: None,
    alignment: None,
    indent: Indent::default(),
  })
  let ordered_level_one = paragraph([], properties={
    style_id: None,
    style_name: None,
    numbering: Some({ is_ordered: true, level: 1 }),
    alignment: None,
    indent: Indent::default(),
  })
  let ordered_level_zero = paragraph([], properties={
    style_id: None,
    style_name: None,
    numbering: Some({ is_ordered: true, level: 0 }),
    alignment: None,
    indent: Indent::default(),
  })
  let unordered_level_one = paragraph([], properties={
    style_id: None,
    style_name: None,
    numbering: Some({ is_ordered: false, level: 1 }),
    alignment: None,
    indent: Indent::default(),
  })
  let highlighted = run(
    [text("mark")],
    properties=run_properties_from_xml("<w:highlight w:val=\"yellow\" />"),
  )
  let red_highlighted = run(
    [text("mark")],
    properties=run_properties_from_xml("<w:highlight w:val=\"red\" />"),
  )
  debug_inspect(
    [
      ParagraphMatcher(style_id=None, style_name=None, numbering=None).matches(
        plain,
      ),
      ParagraphMatcher(style_id=None, style_name=None, numbering=None).matches(
        styled,
      ),
      ParagraphMatcher(
        style_id=Some("Heading1"),
        style_name=None,
        numbering=None,
      ).matches(plain),
      ParagraphMatcher(
        style_id=Some("Heading1"),
        style_name=None,
        numbering=None,
      ).matches(styled),
      ParagraphMatcher(
        style_id=Some("Heading2"),
        style_name=None,
        numbering=None,
      ).matches(styled),
      ParagraphMatcher(
        style_id=None,
        style_name=Some(ExactStyleName("heading 1")),
        numbering=None,
      ).matches(styled),
      ParagraphMatcher(
        style_id=None,
        style_name=Some(PrefixStyleName("Head")),
        numbering=None,
      ).matches(styled),
      ParagraphMatcher(
        style_id=None,
        style_name=None,
        numbering=Some({ is_ordered: true, level: 1 }),
      ).matches(plain),
      ParagraphMatcher(
        style_id=None,
        style_name=None,
        numbering=Some({ is_ordered: true, level: 1 }),
      ).matches(ordered_level_one),
      ParagraphMatcher(
        style_id=None,
        style_name=None,
        numbering=Some({ is_ordered: true, level: 1 }),
      ).matches(ordered_level_zero),
      ParagraphMatcher(
        style_id=None,
        style_name=None,
        numbering=Some({ is_ordered: true, level: 1 }),
      ).matches(unordered_level_one),
      HighlightMatcher(None).matches(plain),
      HighlightMatcher(None).matches(highlighted),
      HighlightMatcher(Some("yellow")).matches(highlighted),
      HighlightMatcher(Some("yellow")).matches(red_highlighted),
    ],
    content=(
      #|[
      #|  true,
      #|  true,
      #|  false,
      #|  true,
      #|  false,
      #|  true,
      #|  true,
      #|  false,
      #|  true,
      #|  false,
      #|  false,
      #|  false,
      #|  true,
      #|  true,
      #|  false,
      #|]
    ),
  )
}

///|
test "docx content types include Mammoth image fallbacks" {
  let content_types = ContentTypes::{ defaults: {}, overrides: {} }
  inspect(
    content_types.find_content_type("word/media/hat.png"),
    content="image/png",
  )
  inspect(
    content_types.find_content_type("word/media/hat.PnG"),
    content="image/png",
  )
  inspect(
    content_types.find_content_type("word/media/hat.jpeg"),
    content="image/jpeg",
  )
  inspect(
    content_types.find_content_type("word/media/hat.jpg"),
    content="image/jpeg",
  )
  inspect(
    content_types.find_content_type("word/media/hat.gif"),
    content="image/gif",
  )
  inspect(
    content_types.find_content_type("word/media/hat.bmp"),
    content="image/bmp",
  )
  inspect(
    content_types.find_content_type("word/media/hat.tif"),
    content="image/tiff",
  )
  inspect(
    content_types.find_content_type("word/media/hat.tiff"),
    content="image/tiff",
  )
  inspect(content_types.find_content_type("word/media/hat"), content="")
  inspect(content_types.find_content_type("word/media/hat.emf"), content="")
  let with_default = ContentTypes::{
    defaults: { "png": "image/custom-png" },
    overrides: { "word/media/hat.png": "image/hat" },
  }
  inspect(
    with_default.find_content_type("word/media/other.png"),
    content="image/custom-png",
  )
  inspect(
    with_default.find_content_type("/word/media/hat.png"),
    content="image/hat",
  )
}

///|
test "docx content types reader handles defaults and overrides" {
  let content_types = read_content_types(
    zip_with_text(
      "[Content_Types].xml",
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        #|  <Default Extension="png" ContentType="image/png" />
        #|  <Override PartName="/word/media/hat.png" ContentType="image/hat" />
        #|</Types>
      ),
    ),
  )
  inspect(
    content_types.find_content_type("word/media/other.png"),
    content="image/png",
  )
  inspect(
    content_types.find_content_type("word/media/hat.png"),
    content="image/hat",
  )
}

///|
test "docx relationships reader finds targets by id and type" {
  let relationships = read_relationships(
    zip_with_text(
      "_rels/.rels",
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        #|  <Relationship Id="rId2" Target="docProps/core.xml" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" />
        #|  <Relationship Id="rId1" Target="word/document.xml" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" />
        #|  <Relationship Id="rId3" Target="word/document2.xml" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" TargetMode="External" />
        #|</Relationships>
      ),
    ),
    "_rels/.rels",
  )
  inspect(
    relationships.find_target_by_id("rId1").unwrap(),
    content="word/document.xml",
  )
  debug_inspect(
    relationships.find_targets_by_type(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    ),
    content="[\"word/document.xml\", \"word/document2.xml\"]",
  )
  debug_inspect(
    relationships.find_targets_by_type(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    ),
    content="[]",
  )
  inspect(
    relationships.find_by_id("rId3").unwrap().target_mode.unwrap(),
    content="External",
  )
}

///|
test "docx external file URI paths follow Mammoth local URI rules" {
  debug_inspect(
    external_uri_to_path("file:///a/b/c", platform="linux"),
    content="Some(\"/a/b/c\")",
  )
  debug_inspect(
    external_uri_to_path("file:///a%20b", platform="linux"),
    content="Some(\"/a b\")",
  )
  debug_inspect(
    external_uri_to_path("file://localhost/a/b/c", platform="linux"),
    content="Some(\"/a/b/c\")",
  )
  debug_inspect(
    external_uri_to_path("file://localhost", platform="linux"),
    content="Some(\"/\")",
  )
  debug_inspect(
    external_uri_to_path("file://localhost?x", platform="linux"),
    content="Some(\"/?x\")",
  )
  debug_inspect(
    external_uri_to_path("file://", platform="linux"),
    content="Some(\"null\")",
  )
  debug_inspect(
    external_uri_to_path("file://?x", platform="linux"),
    content="Some(\"?x\")",
  )
  debug_inspect(
    external_uri_to_path("file://?#frag", platform="linux"),
    content="Some(\"?\")",
  )
  debug_inspect(
    external_uri_to_path("file://example/a/b/c", platform="linux"),
    content="None",
  )
  debug_inspect(
    external_uri_to_path("file://example", platform="linux"),
    content="None",
  )
  debug_inspect(
    external_uri_to_path("file:///c:/a", platform="linux"),
    content="Some(\"/c:/a\")",
  )
  debug_inspect(
    external_uri_to_path("file:///C:/a", platform="win32"),
    content="Some(\"C:/a\")",
  )
  debug_inspect(
    external_uri_to_path("a%20b/c", platform="linux"),
    content="Some(\"a b/c\")",
  )
  debug_inspect(
    external_uri_to_path("//host/path", platform="linux"),
    content="Some(\"//host/path\")",
  )
  debug_inspect(
    external_uri_to_path("a#b:c", platform="linux"),
    content="Some(\"a\")",
  )
  debug_inspect(external_uri_to_path("a%zz", platform="linux"), content="None")
  debug_inspect(external_uri_to_path("a%", platform="linux"), content="None")
  debug_inspect(external_uri_to_path("%ff", platform="linux"), content="None")
  debug_inspect(
    external_file_candidate_paths("a%20b/c"),
    content="[\"a%20b/c\", \"a b/c\"]",
  )
  debug_inspect(
    external_file_candidate_paths("a#frag"),
    content="[\"a#frag\", \"a\"]",
  )
  debug_inspect(external_file_candidate_paths("a%zz"), content="[\"a%zz\"]")
  debug_inspect(external_file_candidate_paths("%ff"), content="[\"%ff\"]")
  debug_inspect(
    external_file_candidate_paths("http://example.com/a.png"),
    content="[\"http://example.com/a.png\"]",
  )
}

///|
test "docx main document path follows package relationships and fallback" {
  let office_document_type = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
  let from_relationship = zip_with_text(
    "_rels/.rels",
    relationship_part(office_document_type, "/word/document2.xml"),
  )
  from_relationship.entries["word/document2.xml"] = @utf8.encode(" ")
  inspect(
    find_main_document_path(from_relationship),
    content="word/document2.xml",
  )
  let fallback = zip_with_text("word/document.xml", " ")
  inspect(find_main_document_path(fallback), content="word/document.xml")
}

///|
test "docx part targets match Mammoth URI resolution" {
  inspect(
    resolve_part_target("one/two", "three/four"),
    content="one/two/three/four",
  )
  inspect(resolve_part_target("one/two", "/three/four"), content="three/four")
}

///|
test "docx related part paths use existing relationship targets before fallbacks" {
  let relationship_types = [
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
  ]
  let fallback_paths = [
    "word/comments.xml", "word/endnotes.xml", "word/footnotes.xml", "word/numbering.xml",
    "word/styles.xml",
  ]
  let resolved : Array[String] = []
  for index in 0..<relationship_types.length() {
    let relationship_type = relationship_types[index]
    let fallback_path = fallback_paths[index]
    let relationships = Relationships::{
      relationships: [
        {
          id: "rPart",
          relationship_type,
          target: "target-path.xml",
          target_mode: None,
        },
      ],
    }
    resolved.push(
      find_part_path(
        zip_with_text("word/target-path.xml", " "),
        relationships,
        relationship_type~,
        base_path="word",
        fallback_path~,
      ),
    )
    resolved.push(
      find_part_path(
        zip_with_text(fallback_path, " "),
        relationships,
        relationship_type~,
        base_path="word",
        fallback_path~,
      ),
    )
  }
  debug_inspect(
    resolved,
    content=(
      #|[
      #|  "word/target-path.xml",
      #|  "word/comments.xml",
      #|  "word/target-path.xml",
      #|  "word/endnotes.xml",
      #|  "word/target-path.xml",
      #|  "word/footnotes.xml",
      #|  "word/target-path.xml",
      #|  "word/numbering.xml",
      #|  "word/target-path.xml",
      #|  "word/styles.xml",
      #|]
    ),
  )
}

///|
test "docx xml part reader reports missing parts" {
  try read_xml_part({ entries: {} }, "word/missing.xml") catch {
    MissingPart(message~) =>
      inspect(message, content="missing DOCX part: word/missing.xml")
    _ => fail("expected MissingPart")
  } noraise {
    _ => fail("expected missing part failure")
  }
}

///|
test "xml reader follows Mammoth basic parsing semantics" {
  let empty = read_xml_string("<body/>")
  inspect(empty.name, content="body")
  inspect(empty.children.length(), content="0")
  let separate_close = read_xml_string("<body></body>")
  inspect(separate_close.children.length(), content="0")
  let attrs = read_xml_string("<body name=\"bob\"/>")
  inspect(attrs.attributes.get_or_default("name", ""), content="bob")
  match read_xml_string("<body>Hello!</body>").children[0] {
    XmlText(value) => inspect(value, content="Hello!")
    _ => fail("expected text")
  }
  let children = read_xml_string(
    "<body><a/><b index=\"1\"/><b index=\"2\"/></body>",
  )
  inspect(children.children.length(), content="3")
  inspect(
    children.first("b").unwrap().attributes.get_or_default("index", ""),
    content="1",
  )
  inspect(
    read_xml_string("<w:body xmlns:w=\"word\"/>").name,
    content="{word}body",
  )
  let mapped = read_xml_string("<w:body xmlns:w=\"word\" w:val=\"Hello!\"/>", namespace_map={
    "word": "x",
  })
  inspect(mapped.name, content="x:body")
  inspect(mapped.attributes.get_or_default("x:val", ""), content="Hello!")
  let package_relationships_xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" /></Relationships>
  let package_relationships = read_xml_string(
    package_relationships_xml,
    namespace_map=office_namespace_map(),
  )
  inspect(package_relationships.name, content="relationships:Relationships")
  inspect(
    package_relationships.first_or_empty("relationships:Relationship").attributes.get_or_default(
      "Id", "",
    ),
    content="rId1",
  )
  inspect(
    read_xml_string("<?xml version=\"1.0\" ?>\n<body/>").name,
    content="body",
  )
  let fallback_xml =
    #|<numbering xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice Requires="w14"><choice /></mc:Choice><mc:Fallback><fallback /></mc:Fallback></mc:AlternateContent></numbering>
  let fallback = read_xml_string(
    fallback_xml,
    namespace_map=office_namespace_map(),
  )
  inspect(fallback.children.length(), content="1")
  match fallback.children[0] {
    XmlElement(element) => inspect(element.name, content="fallback")
    _ => fail("expected fallback element")
  }
  let no_fallback_xml =
    #|<numbering xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice Requires="w14"><choice /></mc:Choice></mc:AlternateContent></numbering>
  let no_fallback = read_xml_string(
    no_fallback_xml,
    namespace_map=office_namespace_map(),
  )
  inspect(no_fallback.children.length(), content="0")
  try read_xml_string("<bo") catch {
    InvalidXml(..) => ()
    _ => fail("expected invalid XML error")
  } noraise {
    _ => fail("expected invalid XML error")
  }
}

///|
test "docx reader reads paragraph style alignment and indent properties" {
  let styles : Map[String, StyleInfo] = {
    "paragraph:Heading1": {
      style_id: "Heading1",
      style_type: "paragraph",
      name: "Heading 1",
    },
  }
  let properties = paragraph_properties_from_xml(
    "<w:pStyle w:val=\"Heading1\" /><w:jc w:val=\"center\" /><w:ind w:start=\"720\" w:left=\"40\" w:right=\"1440\" w:firstLine=\"360\" w:hanging=\"120\" />",
    styles~,
  )
  debug_inspect(properties.style_id, content="Some(\"Heading1\")")
  debug_inspect(properties.style_name, content="Some(\"Heading 1\")")
  debug_inspect(properties.alignment, content="Some(\"center\")")
  debug_inspect(
    [
      properties.indent.start,
      properties.indent.end,
      properties.indent.first_line,
      properties.indent.hanging,
    ],
    content="[Some(\"720\"), Some(\"1440\"), Some(\"360\"), Some(\"120\")]",
  )
  let fallback = paragraph_properties_from_xml(
    "<w:ind w:left=\"720\" w:end=\"1440\" />",
  )
  debug_inspect(
    [fallback.indent.start, fallback.indent.end],
    content="[Some(\"720\"), Some(\"1440\")]",
  )
  let end_precedence = paragraph_properties_from_xml(
    "<w:ind w:end=\"720\" w:right=\"40\" />",
  )
  debug_inspect(end_precedence.indent.end, content="Some(\"720\")")
  let blank_values = paragraph_properties_from_xml(
    "<w:jc w:val=\"\" /><w:ind w:start=\"\" w:left=\"720\" w:end=\"\" w:right=\"1440\" w:firstLine=\"\" w:hanging=\"\" />",
  )
  debug_inspect(blank_values.alignment, content="None")
  debug_inspect(
    [
      blank_values.indent.start,
      blank_values.indent.end,
      blank_values.indent.first_line,
      blank_values.indent.hanging,
    ],
    content="[Some(\"720\"), Some(\"1440\"), None, None]",
  )
}

///|
test "docx reader leaves missing paragraph properties empty" {
  let properties = paragraph_properties_from_xml("")
  debug_inspect(
    [properties.style_id, properties.style_name, properties.alignment],
    content="[None, None, None]",
  )
  debug_inspect(
    [
      properties.indent.start,
      properties.indent.end,
      properties.indent.first_line,
      properties.indent.hanging,
    ],
    content="[None, None, None, None]",
  )
  let empty_indent = paragraph_properties_from_xml("<w:ind />")
  debug_inspect(
    [
      empty_indent.indent.start,
      empty_indent.indent.end,
      empty_indent.indent.first_line,
      empty_indent.indent.hanging,
    ],
    content="[None, None, None, None]",
  )
}

///|
test "docx reader treats empty style references as missing like Mammoth" {
  let reader = empty_body_reader({ relationships: [] })
  let paragraph_xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:pStyle w:val="" /></w:pPr></w:p>
  match
    reader.read_element(
      read_xml_string(paragraph_xml, namespace_map=office_namespace_map()),
    )[0] {
    Paragraph(properties~, ..) =>
      debug_inspect(
        [properties.style_id, properties.style_name],
        content="[None, None]",
      )
    _ => fail("expected paragraph")
  }
  let run_xml =
    #|<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:rPr><w:rStyle w:val="" /></w:rPr></w:r>
  match
    reader.read_element(
      read_xml_string(run_xml, namespace_map=office_namespace_map()),
    )[0] {
    Run(properties~, ..) =>
      debug_inspect(
        [properties.style_id, properties.style_name],
        content="[None, None]",
      )
    _ => fail("expected run")
  }
  let table_xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tblPr><w:tblStyle w:val="" /></w:tblPr></w:tbl>
  match
    reader.read_element(
      read_xml_string(table_xml, namespace_map=office_namespace_map()),
    )[0] {
    Table(properties~, ..) =>
      debug_inspect(
        [properties.style_id, properties.style_name],
        content="[None, None]",
      )
    _ => fail("expected table")
  }
  debug_inspect(reader.messages, content="[]")
}

///|
test "docx reader reads run style id and name like Mammoth" {
  let unstyled = run_properties_from_xml("")
  debug_inspect(
    [unstyled.style_id, unstyled.style_name],
    content="[None, None]",
  )
  let styles : Map[String, StyleInfo] = {
    "character:Heading1Char": {
      style_id: "Heading1Char",
      style_type: "character",
      name: "Heading 1 Char",
    },
  }
  let styled = run_properties_from_xml(
    "<w:rStyle w:val=\"Heading1Char\" />",
    styles~,
  )
  debug_inspect(
    [styled.style_id, styled.style_name],
    content="[Some(\"Heading1Char\"), Some(\"Heading 1 Char\")]",
  )
}

///|
test "docx reader reads inline control elements like Mammoth" {
  debug_inspect(
    body_elements_from_xml("<w:tab /><w:noBreakHyphen /><w:softHyphen />"),
    content="[Tab, Text(\"‑\"), Text(\"­\")]",
  )
}

///|
test "docx body reader uses mc fallback content like Mammoth" {
  let with_fallback_xml =
    #|<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><mc:Choice Requires="wps"><w:t>Choice</w:t></mc:Choice><mc:Fallback><w:t>Fallback</w:t></mc:Fallback></mc:AlternateContent>
  let with_fallback = read_xml_string(
    with_fallback_xml,
    namespace_map=office_namespace_map(),
  )
  debug_inspect(
    empty_body_reader({ relationships: [] }).read_element(with_fallback),
    content="[Text(\"Fallback\")]",
  )
  let without_fallback_xml =
    #|<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><mc:Choice Requires="wps"><w:t>Choice</w:t></mc:Choice></mc:AlternateContent>
  let without_fallback = read_xml_string(
    without_fallback_xml,
    namespace_map=office_namespace_map(),
  )
  debug_inspect(
    empty_body_reader({ relationships: [] }).read_element(without_fallback),
    content="[]",
  )
}

///|
test "docx reader maps break types like Mammoth" {
  debug_inspect(
    body_elements_from_xml(
      "<w:br /><w:br w:type=\"textWrapping\" /><w:br w:type=\"page\" /><w:br w:type=\"column\" />",
    ),
    content="[Break(Line), Break(Line), Break(Page), Break(Column)]",
  )
}

///|
test "docx reader reads references and bookmarks like Mammoth" {
  debug_inspect(
    body_elements_from_xml(
      "<w:footnoteReference w:id=\"4\" /><w:endnoteReference w:id=\"7\" /><w:commentReference w:id=\"9\" /><w:bookmarkStart w:name=\"_Peter\" w:id=\"42\" />",
    ),
    content=(
      #|[
      #|  NoteReference(note_type="footnote", note_id="4"),
      #|  NoteReference(note_type="endnote", note_id="7"),
      #|  CommentReference("9"),
      #|  BookmarkStart("_Peter"),
      #|]
    ),
  )
  debug_inspect(
    body_elements_from_xml(
      "<w:bookmarkStart w:name=\"_GoBack\" /><w:bookmarkEnd />",
    ),
    content="[]",
  )
  debug_inspect(
    body_elements_from_xml("<w:bookmarkStart />"),
    content="[BookmarkStart(\"undefined\")]",
  )
  debug_inspect(
    body_elements_from_xml(
      "<w:footnoteReference /><w:endnoteReference /><w:commentReference />",
    ),
    content=(
      #|[
      #|  NoteReference(note_type="footnote", note_id="undefined"),
      #|  NoteReference(note_type="endnote", note_id="undefined"),
      #|  CommentReference("undefined"),
      #|]
    ),
  )
}

///|
test "docx reader ignores Mammoth ignored body elements without warnings" {
  let xml =
    #|<w:root xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:annotationRef /><w:bookmarkEnd /><w:sectPr /><w:proofErr /><w:lastRenderedPageBreak /><w:commentRangeStart /><w:commentRangeEnd /><w:del /><w:footnoteRef /><w:endnoteRef /><w:txbxContent /><w:pPr /><w:rPr /><w:tblPr /><w:tblGrid /><w:trPr /></w:root>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = empty_body_reader({ relationships: [] })
  debug_inspect(reader.read_children(root.children), content="[]")
  debug_inspect(reader.messages, content="[]")
}

///|
test "docx reader uses structured document tag content without checkbox" {
  debug_inspect(
    body_elements_from_xml(
      "<w:sdt><w:sdtContent><w:t>Blackdown</w:t></w:sdtContent></w:sdt>",
    ),
    content="[Text(\"Blackdown\")]",
  )
}

///|
test "docx reader ignores raw XML text nodes in children" {
  match body_elements_from_xml("<w:r>[text]</w:r>")[0] {
    Run(children~, ..) => debug_inspect(children, content="[]")
    _ => fail("expected run")
  }
}

///|
test "docx reader reads Mammoth run boolean properties" {
  let enabled = run_properties_from_xml(
    "<w:b /><w:i w:val=\"true\" /><w:strike w:val=\"1\" /><w:caps /><w:smallCaps />",
  )
  debug_inspect(
    [
      enabled.is_bold,
      enabled.is_italic,
      enabled.is_strikethrough,
      enabled.is_all_caps,
      enabled.is_small_caps,
    ],
    content="[true, true, true, true, true]",
  )
  let explicit_true = run_properties_from_xml(
    "<w:b w:val=\"true\" /><w:i w:val=\"1\" /><w:strike w:val=\"true\" /><w:caps w:val=\"1\" /><w:smallCaps w:val=\"true\" />",
  )
  debug_inspect(
    [
      explicit_true.is_bold,
      explicit_true.is_italic,
      explicit_true.is_strikethrough,
      explicit_true.is_all_caps,
      explicit_true.is_small_caps,
    ],
    content="[true, true, true, true, true]",
  )
  let disabled = run_properties_from_xml(
    "<w:b w:val=\"false\" /><w:i w:val=\"0\" /><w:strike w:val=\"false\" /><w:caps w:val=\"0\" /><w:smallCaps w:val=\"false\" />",
  )
  debug_inspect(
    [
      disabled.is_bold,
      disabled.is_italic,
      disabled.is_strikethrough,
      disabled.is_all_caps,
      disabled.is_small_caps,
    ],
    content="[false, false, false, false, false]",
  )
}

///|
test "docx reader reads underline with Mammoth special cases" {
  let missing = run_properties_from_xml("").is_underline
  let empty_value = run_properties_from_xml("<w:u />").is_underline
  let false_value = run_properties_from_xml("<w:u w:val=\"false\" />").is_underline
  let zero_value = run_properties_from_xml("<w:u w:val=\"0\" />").is_underline
  let none_value = run_properties_from_xml("<w:u w:val=\"none\" />").is_underline
  let single_value = run_properties_from_xml("<w:u w:val=\"single\" />").is_underline
  let true_value = run_properties_from_xml("<w:u w:val=\"true\" />").is_underline
  let one_value = run_properties_from_xml("<w:u w:val=\"1\" />").is_underline
  debug_inspect(
    [
      missing, empty_value, false_value, zero_value, none_value, single_value, true_value,
      one_value,
    ],
    content="[false, false, false, false, false, true, true, true]",
  )
}

///|
test "docx reader reads run font vertical alignment and highlight properties" {
  let defaults = run_properties_from_xml("")
  debug_inspect(defaults.vertical_alignment, content="Baseline")
  debug_inspect(defaults.font, content="None")
  debug_inspect(defaults.font_size, content="None")
  debug_inspect(defaults.highlight, content="None")
  let properties = run_properties_from_xml(
    "<w:vertAlign w:val=\"superscript\" /><w:rFonts w:ascii=\"Arial\" /><w:sz w:val=\"28\" /><w:highlight w:val=\"yellow\" />",
  )
  debug_inspect(properties.vertical_alignment, content="Superscript")
  debug_inspect(properties.font, content="Some(\"Arial\")")
  debug_inspect(properties.font_size, content="Some(14)")
  debug_inspect(properties.highlight, content="Some(\"yellow\")")
  let subscript = run_properties_from_xml("<w:vertAlign w:val=\"subscript\" />")
  debug_inspect(subscript.vertical_alignment, content="Subscript")
  let blank_font = run_properties_from_xml("<w:rFonts w:ascii=\"\" />")
  debug_inspect(blank_font.font, content="None")
}

///|
test "docx reader does not include run properties as run children" {
  let xml =
    #|<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:rPr><w:rStyle w:val="Heading1Char" /></w:rPr></w:r>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  match empty_body_reader({ relationships: [] }).read_element(root)[0] {
    Run(children~, ..) => debug_inspect(children, content="[]")
    _ => fail("expected run")
  }
}

///|
test "docx reader treats empty highlight as no highlight" {
  debug_inspect(
    [
      read_highlight(None),
      read_highlight(Some("")),
      read_highlight(Some("none")),
      read_highlight(Some("yellow")),
    ],
    content="[None, None, None, Some(\"yellow\")]",
  )
}

///|
test "docx reader reads font size with Mammoth unsigned decimal semantics" {
  let overflowing_decimal = "999999999999999999999999999999999999999999999999999999999999"
  debug_inspect(
    [
      read_font_size(None),
      read_font_size(Some("28")),
      read_font_size(Some("28a")),
      read_font_size(Some("-2")),
      read_font_size(Some("+2")),
      read_font_size(Some(" 28")),
      read_font_size(Some("")),
      read_font_size(Some(overflowing_decimal)),
    ],
    content="[None, Some(14), None, None, None, None, None, None]",
  )
}

///|
test "docx hyperlink reader replaces external URL fragment when anchor is set" {
  let xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="r42" w:anchor="fragment"><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let without_fragment_reader = empty_body_reader({
    relationships: [
      {
        id: "r42",
        relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
        target: "http://example.com/",
        target_mode: Some("External"),
      },
    ],
  })
  match without_fragment_reader.read_element(root)[0] {
    Hyperlink(href~, ..) =>
      debug_inspect(href, content="Some(\"http://example.com/#fragment\")")
    _ => fail("expected hyperlink")
  }
  let reader = empty_body_reader({
    relationships: [
      {
        id: "r42",
        relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
        target: "http://example.com/#previous",
        target_mode: Some("External"),
      },
    ],
  })
  let elements = reader.read_element(root)
  match elements[0] {
    Hyperlink(href~, anchor~, target_frame~, ..) => {
      debug_inspect(href, content="Some(\"http://example.com/#fragment\")")
      debug_inspect(anchor, content="None")
      debug_inspect(target_frame, content="None")
    }
    _ => fail("expected hyperlink")
  }
  let empty_anchor_xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="r42" w:anchor=""><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let empty_anchor = read_xml_string(
    empty_anchor_xml,
    namespace_map=office_namespace_map(),
  )
  match reader.read_element(empty_anchor)[0] {
    Hyperlink(href~, anchor~, target_frame~, ..) => {
      debug_inspect(href, content="Some(\"http://example.com/#previous\")")
      debug_inspect(anchor, content="None")
      debug_inspect(target_frame, content="None")
    }
    _ => fail("expected hyperlink")
  }
}

///|
test "docx hyperlink reader follows Mammoth target forms" {
  let external_xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="r42"><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let external = read_xml_string(
    external_xml,
    namespace_map=office_namespace_map(),
  )
  let reader = empty_body_reader({
    relationships: [
      {
        id: "r42",
        relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
        target: "http://example.com",
        target_mode: Some("External"),
      },
    ],
  })
  match reader.read_element(external)[0] {
    Hyperlink(href~, anchor~, target_frame~, children~) => {
      debug_inspect(href, content="Some(\"http://example.com\")")
      debug_inspect(anchor, content="None")
      debug_inspect(target_frame, content="None")
      match children[0] {
        Run(..) => ()
        _ => fail("expected run child")
      }
    }
    _ => fail("expected hyperlink")
  }
  let internal_xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:anchor="_Peter"><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let internal = read_xml_string(
    internal_xml,
    namespace_map=office_namespace_map(),
  )
  match empty_body_reader({ relationships: [] }).read_element(internal)[0] {
    Hyperlink(href~, anchor~, target_frame~, children~) => {
      debug_inspect(href, content="None")
      debug_inspect(anchor, content="Some(\"_Peter\")")
      debug_inspect(target_frame, content="None")
      match children[0] {
        Run(..) => ()
        _ => fail("expected run child")
      }
    }
    _ => fail("expected hyperlink")
  }
  let target_frame_xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:anchor="Introduction" w:tgtFrame="_blank" />
  let target_frame = read_xml_string(
    target_frame_xml,
    namespace_map=office_namespace_map(),
  )
  match empty_body_reader({ relationships: [] }).read_element(target_frame)[0] {
    Hyperlink(target_frame~, ..) =>
      debug_inspect(target_frame, content="Some(\"_blank\")")
    _ => fail("expected hyperlink")
  }
  let empty_target_frame_xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:anchor="Introduction" w:tgtFrame="" />
  let empty_target_frame = read_xml_string(
    empty_target_frame_xml,
    namespace_map=office_namespace_map(),
  )
  match
    empty_body_reader({ relationships: [] }).read_element(empty_target_frame)[0] {
    Hyperlink(target_frame~, ..) => debug_inspect(target_frame, content="None")
    _ => fail("expected hyperlink")
  }
  let empty_relationship_id_xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="" w:anchor="Introduction"><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let empty_relationship_id = read_xml_string(
    empty_relationship_id_xml,
    namespace_map=office_namespace_map(),
  )
  match
    empty_body_reader({ relationships: [] }).read_element(empty_relationship_id)[0] {
    Hyperlink(href~, anchor~, target_frame~, children~) => {
      debug_inspect(href, content="None")
      debug_inspect(anchor, content="Some(\"Introduction\")")
      debug_inspect(target_frame, content="None")
      match children[0] {
        Run(..) => ()
        _ => fail("expected run child")
      }
    }
    _ => fail("expected internal hyperlink")
  }
  let empty_anchor_xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:anchor=""><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let empty_anchor = read_xml_string(
    empty_anchor_xml,
    namespace_map=office_namespace_map(),
  )
  match empty_body_reader({ relationships: [] }).read_element(empty_anchor)[0] {
    Run(..) => ()
    _ => fail("expected transparent hyperlink children")
  }
}

///|
test "docx hyperlink reader preserves children when no target is present" {
  let xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  match elements[0] {
    Run(..) => ()
    _ => fail("expected hyperlink children")
  }
}

///|
test "docx hyperlink reader preserves children when relationship target is missing" {
  let xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="missing"><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = empty_body_reader({ relationships: [] })
  match reader.read_element(root)[0] {
    Hyperlink(children~, href=None, anchor=None, target_frame=None) =>
      inspect(
        convert_document_to_html(document(children)).value,
        content="Hello",
      )
    _ => fail("expected unaddressed hyperlink")
  }
  debug_inspect(reader.messages, content="[]")
}

///|
test "docx structured document tag checkbox without content is read" {
  let xml =
    #|<w:sdt xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wordml="http://schemas.microsoft.com/office/word/2010/wordml"><w:sdtPr><wordml:checkbox /></w:sdtPr></w:sdt>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  debug_inspect(elements, content="[Checkbox(false)]")
  let unchecked_xml =
    #|<w:sdt xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wordml="http://schemas.microsoft.com/office/word/2010/wordml"><w:sdtPr><wordml:checkbox><wordml:checked wordml:val="0" /></wordml:checkbox></w:sdtPr></w:sdt>
  let unchecked = read_xml_string(
    unchecked_xml,
    namespace_map=office_namespace_map(),
  )
  debug_inspect(
    empty_body_reader({ relationships: [] }).read_element(unchecked),
    content="[Checkbox(false)]",
  )
  let checked_xml =
    #|<w:sdt xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wordml="http://schemas.microsoft.com/office/word/2010/wordml"><w:sdtPr><wordml:checkbox><wordml:checked wordml:val="1" /></wordml:checkbox></w:sdtPr></w:sdt>
  let checked = read_xml_string(
    checked_xml,
    namespace_map=office_namespace_map(),
  )
  debug_inspect(
    empty_body_reader({ relationships: [] }).read_element(checked),
    content="[Checkbox(true)]",
  )
}

///|
test "docx structured document tag checkbox replaces content character" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wordml="http://schemas.microsoft.com/office/word/2010/wordml"><w:tr><w:sdt><w:sdtPr><wordml:checkbox><wordml:checked wordml:val="1" /></wordml:checkbox></w:sdtPr><w:sdtContent><w:tc><w:p><w:r><w:t>\u{2610}</w:t></w:r></w:p></w:tc></w:sdtContent></w:sdt></w:tr></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<table><tr><td><p><input type=\"checkbox\" checked=\"checked\" /></p></td></tr></table>",
  )
}

///|
test "docx structured document tag checkbox keeps trailing content" {
  let xml =
    #|<w:sdt xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wordml="http://schemas.microsoft.com/office/word/2010/wordml"><w:sdtPr><wordml:checkbox><wordml:checked wordml:val="1" /></wordml:checkbox></w:sdtPr><w:sdtContent><w:p><w:r><w:t>\u{2610}</w:t></w:r></w:p><w:p><w:r><w:t>After</w:t></w:r></w:p></w:sdtContent></w:sdt>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<p><input type=\"checkbox\" checked=\"checked\" /></p><p>After</p>",
  )
}

///|
test "docx structured document tag checkbox falls back for empty text" {
  let xml =
    #|<w:sdt xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wordml="http://schemas.microsoft.com/office/word/2010/wordml"><w:sdtPr><wordml:checkbox /></w:sdtPr><w:sdtContent><w:p><w:r><w:t></w:t></w:r></w:p></w:sdtContent></w:sdt>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<input type=\"checkbox\" />",
  )
}

///|
test "docx structured document tag checkbox ignores deleted content" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wordml="http://schemas.microsoft.com/office/word/2010/wordml"><w:tr><w:sdt><w:sdtPr><wordml:checkbox><wordml:checked wordml:val="1" /></wordml:checkbox></w:sdtPr><w:sdtContent><w:tc><w:p><w:r><w:t>\u{2610}</w:t></w:r><w:del><w:r><w:t>\u{2610}</w:t></w:r></w:del></w:p></w:tc></w:sdtContent></w:sdt></w:tr></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<table><tr><td><p><input type=\"checkbox\" checked=\"checked\" /></p></td></tr></table>",
  )
}

///|
test "docx table properties include table style name" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tblPr><w:tblStyle w:val="TableNormal" /></w:tblPr></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = BodyReader::{
    styles: {
      "TableNormal": {
        style_id: "TableNormal",
        style_type: "table",
        name: "Normal Table",
      },
    },
    zip: { entries: {} },
    relationships: { relationships: [] },
    content_types: { defaults: {}, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: default_external_file_access(),
    read_images: true,
  }
  debug_inspect(
    reader.read_element(root),
    content=(
      #|[
      #|  Table(
      #|    children=[],
      #|    properties={ style_id: Some("TableNormal"), style_name: Some("Normal Table") },
      #|  ),
      #|]
    ),
  )
}

///|
test "docx table style warnings match Mammoth" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tblPr><w:tblStyle w:val="TableNormal" /></w:tblPr></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = empty_body_reader({ relationships: [] })
  match reader.read_element(root)[0] {
    Table(properties~, ..) => {
      debug_inspect(properties.style_id, content="Some(\"TableNormal\")")
      debug_inspect(properties.style_name, content="None")
    }
    _ => fail("expected table")
  }
  debug_inspect(
    reader.messages,
    content=(
      #|[Warning("Table style with ID TableNormal was referenced but not defined in the document")]
    ),
  )
}

///|
test "docx styles are keyed by type and keep first duplicate" {
  let styles = styles_from_xml(
    (
      #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:style w:type="table" w:styleId="TableNormal"><w:name w:val="Normal Table" /></w:style>
      #|  <w:style w:type="table" w:styleId="TableNormal"><w:name w:val="Table Normal" /></w:style>
      #|  <w:style w:type="paragraph" w:styleId="Shared"><w:name w:val="Shared Paragraph" /></w:style>
      #|  <w:style w:type="character" w:styleId="Shared"><w:name w:val="Shared Character" /></w:style>
      #|  <w:style w:type="paragraph" w:styleId="NoName" />
      #|</w:styles>
    ),
  )
  match styles.find_style("table", "TableNormal") {
    Some(style) => inspect(style.name, content="Normal Table")
    None => fail("expected table style")
  }
  match styles.find_style("paragraph", "TableNormal") {
    None => ()
    Some(_) => fail("expected table style not to match paragraph lookup")
  }
  let legacy_wrong_type : Map[String, StyleInfo] = {
    "Shared": { style_id: "Shared", style_type: "table", name: "Shared Table" },
  }
  match legacy_wrong_type.find_style("paragraph", "Shared") {
    None => ()
    Some(_) => fail("expected mismatched style type to be ignored")
  }
  let paragraph_xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:pStyle w:val="Shared" /></w:pPr></w:p>
  let paragraph = read_xml_string(
    paragraph_xml,
    namespace_map=office_namespace_map(),
  )
  let paragraph_reader = body_reader_with_numbering(
    styles,
    NumberingMap::empty(),
  )
  match paragraph_reader.read_element(paragraph)[0] {
    Paragraph(properties~, ..) =>
      debug_inspect(properties.style_name, content="Some(\"Shared Paragraph\")")
    _ => fail("expected paragraph")
  }
  let run_xml =
    #|<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:rPr><w:rStyle w:val="Shared" /></w:rPr></w:r>
  let run = read_xml_string(run_xml, namespace_map=office_namespace_map())
  let run_reader = body_reader_with_numbering(styles, NumberingMap::empty())
  match run_reader.read_element(run)[0] {
    Run(properties~, ..) =>
      debug_inspect(properties.style_name, content="Some(\"Shared Character\")")
    _ => fail("expected run")
  }
  let no_name_xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:pStyle w:val="NoName" /></w:pPr></w:p>
  let no_name = read_xml_string(
    no_name_xml,
    namespace_map=office_namespace_map(),
  )
  let no_name_reader = body_reader_with_numbering(styles, NumberingMap::empty())
  match no_name_reader.read_element(no_name)[0] {
    Paragraph(properties~, ..) =>
      debug_inspect(properties.style_name, content="None")
    _ => fail("expected no-name paragraph")
  }
  debug_inspect(no_name_reader.messages, content="[]")
}

///|
test "docx styles reader extracts numbering style num ids" {
  let styles = styles_from_xml(
    (
      #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:style w:type="numbering" w:styleId="List1" />
      #|  <w:style w:type="numbering" w:styleId="List2"><w:pPr><w:numPr><w:numId w:val="42" /></w:numPr></w:pPr></w:style>
      #|</w:styles>
    ),
  )
  match styles.find_style("numbering", "List1") {
    Some(style) => inspect(style.name, content="")
    None => fail("expected numbering style without num id")
  }
  match styles.find_style("numbering", "List2") {
    Some(style) => inspect(style.name, content="42")
    None => fail("expected numbering style with num id")
  }
}

///|
test "docx reader resolves hyperlink relationships from document part" {
  let document_xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    #|  <w:body>
    #|    <w:p><w:hyperlink r:id="rId6"><w:r><w:t>coconuts</w:t></w:r></w:hyperlink></w:p>
    #|  </w:body>
    #|</w:document>
  let relationships_xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId6" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="http://www.example.com" TargetMode="External" />
    #|</Relationships>
  let zip = zip_with_text("word/document.xml", document_xml)
  zip.entries["word/_rels/document.xml.rels"] = @utf8.encode(relationships_xml)
  let result = read_docx_zip_with_messages(zip)
  match result.document {
    Document(children~, ..) =>
      match children[0] {
        Paragraph(children=paragraph_children, ..) =>
          match paragraph_children[0] {
            Hyperlink(href=Some(href), children=link_children, ..) => {
              inspect(href, content="http://www.example.com")
              inspect(link_children.length(), content="1")
            }
            _ => fail("expected hyperlink")
          }
        _ => fail("expected paragraph")
      }
    _ => fail("expected document")
  }
  inspect(
    convert_document_to_html(result.document).value,
    content="<p><a href=\"http://www.example.com\">coconuts</a></p>",
  )
}

///|
test "docx reader resolves styles from document relationships" {
  let document_xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:pStyle w:val="Custom" /></w:pPr></w:p></w:body></w:document>
  let styles_xml =
    #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:styleId="Custom"><w:name w:val="Custom Style" /></w:style></w:styles>
  let zip = zip_with_text("word/document.xml", document_xml)
  zip.entries["word/_rels/document.xml.rels"] = @utf8.encode(
    relationship_part(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
      "custom-styles.xml",
    ),
  )
  zip.entries["word/custom-styles.xml"] = @utf8.encode(styles_xml)
  match read_docx_zip_with_messages(zip).document {
    Document(children~, ..) =>
      match children[0] {
        Paragraph(properties~, ..) =>
          debug_inspect(properties.style_name, content="Some(\"Custom Style\")")
        _ => fail("expected paragraph")
      }
    _ => fail("expected document")
  }
}

///|
test "docx body reader records Mammoth-compatible warnings" {
  let paragraph_xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:pStyle w:val="Heading1" /></w:pPr></w:p>
  let paragraph = read_xml_string(
    paragraph_xml,
    namespace_map=office_namespace_map(),
  )
  let paragraph_reader = empty_body_reader({ relationships: [] })
  let paragraph_elements = paragraph_reader.read_element(paragraph)
  match paragraph_elements[0] {
    Paragraph(properties~, ..) => {
      debug_inspect(properties.style_id, content="Some(\"Heading1\")")
      debug_inspect(properties.style_name, content="None")
    }
    _ => fail("expected paragraph")
  }
  debug_inspect(
    paragraph_reader.messages,
    content=(
      #|[Warning("Paragraph style with ID Heading1 was referenced but not defined in the document")]
    ),
  )
  let run_xml =
    #|<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:rPr><w:rStyle w:val="Heading1Char" /></w:rPr></w:r>
  let run = read_xml_string(run_xml, namespace_map=office_namespace_map())
  let run_reader = empty_body_reader({ relationships: [] })
  match run_reader.read_element(run)[0] {
    Run(properties~, ..) => {
      debug_inspect(properties.style_id, content="Some(\"Heading1Char\")")
      debug_inspect(properties.style_name, content="None")
    }
    _ => fail("expected run")
  }
  debug_inspect(
    run_reader.messages,
    content=(
      #|[Warning("Run style with ID Heading1Char was referenced but not defined in the document")]
    ),
  )
  let break_xml =
    #|<w:br xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:type="unknownBreakType" />
  let break_element = read_xml_string(
    break_xml,
    namespace_map=office_namespace_map(),
  )
  let break_reader = empty_body_reader({ relationships: [] })
  debug_inspect(break_reader.read_element(break_element), content="[]")
  debug_inspect(
    break_reader.messages,
    content=(
      #|[Warning("Unsupported break type: unknownBreakType")]
    ),
  )
  let unknown_xml =
    #|<w:not-an-element xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" />
  let unknown = read_xml_string(
    unknown_xml,
    namespace_map=office_namespace_map(),
  )
  let unknown_reader = empty_body_reader({ relationships: [] })
  debug_inspect(unknown_reader.read_element(unknown), content="[]")
  debug_inspect(
    unknown_reader.messages,
    content=(
      #|[Warning("An unrecognised element was ignored: w:not-an-element")]
    ),
  )
  let office_word_wrap_xml =
    #|<w10:wrap xmlns:w10="urn:schemas-microsoft-com:office:word" />
  let office_word_wrap = read_xml_string(
    office_word_wrap_xml,
    namespace_map=office_namespace_map(),
  )
  let office_word_reader = empty_body_reader({ relationships: [] })
  debug_inspect(office_word_reader.read_element(office_word_wrap), content="[]")
  debug_inspect(office_word_reader.messages, content="[]")
}

///|
test "docx note and comment reader warnings are preserved" {
  let footnotes_xml =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:id="1"><w:not-an-element /></w:footnote></w:footnotes>
  let styles : Map[String, StyleInfo] = {}
  let numbering = NumberingMap::empty()
  let content_types = ContentTypes::{ defaults: {}, overrides: {} }
  let document_relationships = Relationships::{ relationships: [] }
  let base_path = "word"
  let footnotes = read_note_part(
    zip_with_text("word/footnotes.xml", footnotes_xml),
    note_type="footnote",
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    fallback_path="word/footnotes.xml",
    styles~,
    numbering~,
    content_types~,
    document_relationships~,
    base_path~,
  )
  inspect(footnotes.notes.length(), content="1")
  debug_inspect(
    footnotes.messages,
    content=(
      #|[Warning("An unrecognised element was ignored: w:not-an-element")]
    ),
  )
  let comments_xml =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0"><w:not-an-element /></w:comment></w:comments>
  let comments = read_comments_for_document(
    zip_with_text("word/comments.xml", comments_xml),
    styles,
    numbering,
    content_types,
    document_relationships,
    base_path,
  )
  inspect(comments.comments.length(), content="1")
  debug_inspect(
    comments.messages,
    content=(
      #|[Warning("An unrecognised element was ignored: w:not-an-element")]
    ),
  )
  let docx = empty_docx_zip()
  docx.entries["word/footnotes.xml"] = @utf8.encode(footnotes_xml)
  docx.entries["word/comments.xml"] = @utf8.encode(comments_xml)
  debug_inspect(
    read_docx_zip_with_messages(docx).messages,
    content=(
      #|[Warning("An unrecognised element was ignored: w:not-an-element")]
    ),
  )
}

///|
test "docx related parts fall back when relationship target is missing" {
  let footnotes_xml =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:id="1"><w:p /></w:footnote></w:footnotes>
  let styles : Map[String, StyleInfo] = {}
  let numbering = NumberingMap::empty()
  let content_types = ContentTypes::{ defaults: {}, overrides: {} }
  let document_relationships = Relationships::{
    relationships: [
      {
        id: "rFootnotes",
        relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
        target: "missing-footnotes.xml",
        target_mode: None,
      },
    ],
  }
  let footnotes = read_note_part(
    zip_with_text("word/footnotes.xml", footnotes_xml),
    note_type="footnote",
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    fallback_path="word/footnotes.xml",
    styles~,
    numbering~,
    content_types~,
    document_relationships~,
    base_path="word",
  )
  inspect(footnotes.notes.length(), content="1")
}

///|
test "docx document xml reader rejects missing body" {
  let root = read_xml_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body2 /></w:document>",
    namespace_map=office_namespace_map(),
  )
  try
    read_document_xml_with_messages(
      root,
      {},
      NumberingMap::empty(),
      { entries: {} },
      { relationships: [] },
      { defaults: {}, overrides: {} },
      "word",
      [],
      [],
    )
  catch {
    InvalidXml(message~) =>
      inspect(
        message,
        content="Could not find the body element: are you sure this is a docx file?",
      )
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected missing body error")
  }
}

///|
test "docx reader messages are deduplicated when prepended" {
  debug_inspect(
    prepend_messages(
      { value: "", messages: [Warning("same"), Warning("converted")] },
      [Warning("same"), Warning("read")],
    ).messages,
    content=(
      #|[Warning("same"), Warning("read"), Warning("converted")]
    ),
  )
}

///|
test "docx notes reader reads bodies and ignores separators" {
  let footnotes = footnotes_from_xml(
    (
      #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:footnote w:id="1"><w:p><w:r><w:t>Body</w:t></w:r></w:p></w:footnote>
      #|  <w:footnote><w:p><w:r><w:t>Missing ID</w:t></w:r></w:p></w:footnote>
      #|  <w:footnote w:id="2" w:type="separator"><w:p><w:r><w:t>Separator</w:t></w:r></w:p></w:footnote>
      #|  <w:footnote w:id="3" w:type="continuationSeparator"><w:p><w:r><w:t>Continuation</w:t></w:r></w:p></w:footnote>
      #|</w:footnotes>
    ),
  )
  inspect(footnotes.notes.length(), content="2")
  inspect(footnotes.notes[0].note_id, content="1")
  inspect(
    convert_document_to_html(document(footnotes.notes[0].body)).value,
    content="<p>Body</p>",
  )
  inspect(footnotes.notes[1].note_id, content="undefined")
}

///|
test "docx comments reader reads ids bodies and optional attributes" {
  let comments = comments_from_xml(
    (
      #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:comment w:id="1"><w:p><w:r><w:t>Missing</w:t></w:r></w:p></w:comment>
      #|  <w:comment w:id="2" w:author=" " w:initials=" "><w:p><w:r><w:t>Blank</w:t></w:r></w:p></w:comment>
      #|  <w:comment w:id="3" w:author="The Piemaker" w:initials="TP"><w:p><w:r><w:t>Present</w:t></w:r></w:p></w:comment>
      #|  <w:comment><w:p><w:r><w:t>Missing ID</w:t></w:r></w:p></w:comment>
      #|</w:comments>
    ),
  )
  inspect(comments.comments.length(), content="4")
  inspect(comments.comments[0].comment_id, content="1")
  inspect(
    convert_document_to_html(document(comments.comments[0].body)).value,
    content="<p>Missing</p>",
  )
  inspect(comments.comments[0].author_name, content="")
  inspect(comments.comments[0].author_initials, content="")
  inspect(comments.comments[1].author_name, content="")
  inspect(comments.comments[1].author_initials, content="")
  inspect(comments.comments[2].author_name, content="The Piemaker")
  inspect(comments.comments[2].author_initials, content="TP")
  inspect(comments.comments[3].comment_id, content="undefined")
}

///|
test "docx numbering xml maps explicit and style-based list levels" {
  let numbering = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42">
      #|    <w:lvl w:ilvl="0"><w:numFmt w:val="bullet" /><w:pStyle w:val="ListBullet" /></w:lvl>
      #|    <w:lvl w:ilvl="1"><w:numFmt w:val="decimal" /></w:lvl>
      #|  </w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  match numbering.find_level("47", "0") {
    Some(level) => {
      inspect(level.is_ordered, content="false")
      inspect(level.level, content="1")
    }
    None => fail("expected numbering level")
  }
  match numbering.find_level("47", "1") {
    Some(level) => {
      inspect(level.is_ordered, content="true")
      inspect(level.level, content="2")
    }
    None => fail("expected numbering level")
  }
  match numbering.find_level_by_paragraph_style_id("ListBullet") {
    Some(level) => {
      inspect(level.is_ordered, content="false")
      inspect(level.level, content="1")
    }
    None => fail("expected paragraph style numbering level")
  }
}

///|
test "docx numbering xml handles missing references and level defaults" {
  let ignored_abstract = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum><w:lvl w:ilvl="0"><w:numFmt w:val="decimal" /></w:lvl></w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  debug_inspect(ignored_abstract.find_level("47", "0"), content="None")
  let missing_reference = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  debug_inspect(missing_reference.find_level("47", "0"), content="None")
  debug_inspect(missing_reference.find_level("missing", "0"), content="None")
  let missing_level = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42"><w:lvl w:ilvl="1"><w:numFmt w:val="decimal" /></w:lvl></w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  debug_inspect(missing_level.find_level("47", "0"), content="None")
  let missing_style_link = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42"><w:numStyleLink w:val="List1" /></w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  debug_inspect(missing_style_link.find_level("47", "0"), content="None")
  let missing_level_index = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42"><w:lvl><w:numFmt w:val="decimal" /></w:lvl></w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  match missing_level_index.find_level("47", "0") {
    Some(level) => {
      inspect(level.is_ordered, content="true")
      inspect(level.level, content="1")
    }
    None => fail("expected fallback level")
  }
  let explicit_level_wins = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42"><w:lvl><w:numFmt w:val="decimal" /></w:lvl><w:lvl w:ilvl="0"><w:numFmt w:val="bullet" /></w:lvl></w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  match explicit_level_wins.find_level("47", "0") {
    Some(level) => inspect(level.is_ordered, content="false")
    None => fail("expected explicit level")
  }
  let missing_num_format = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42"><w:lvl w:ilvl="0" /></w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  match missing_num_format.find_level("47", "0") {
    Some(level) => inspect(level.is_ordered, content="true")
    None => fail("expected ordered default")
  }
  let malformed_level_index = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42"><w:lvl w:ilvl="abc"><w:numFmt w:val="decimal" /></w:lvl></w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  match malformed_level_index.find_level("47", "abc") {
    Some(level) => inspect(level.level, content="1")
    None => fail("expected malformed level index fallback")
  }
}

///|
test "docx numbering xml ignores missing level index when explicit zero exists" {
  let explicit_before_missing = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42">
      #|    <w:lvl w:ilvl="0"><w:numFmt w:val="bullet" /></w:lvl>
      #|    <w:lvl><w:numFmt w:val="decimal" /></w:lvl>
      #|  </w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  match explicit_before_missing.find_level("47", "0") {
    Some(level) => inspect(level.is_ordered, content="false")
    None => fail("expected explicit level")
  }
  let explicit_after_missing = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42">
      #|    <w:lvl><w:numFmt w:val="decimal" /></w:lvl>
      #|    <w:lvl w:ilvl="0"><w:numFmt w:val="bullet" /></w:lvl>
      #|  </w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  match explicit_after_missing.find_level("47", "0") {
    Some(level) => inspect(level.is_ordered, content="false")
    None => fail("expected explicit level")
  }
}

///|
test "docx numbering xml follows numbering style links" {
  let numbering = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="100"><w:numStyleLink w:val="List1" /></w:abstractNum>
      #|  <w:abstractNum w:abstractNumId="101">
      #|    <w:lvl w:ilvl="0"><w:numFmt w:val="decimal" /></w:lvl>
      #|  </w:abstractNum>
      #|  <w:num w:numId="200"><w:abstractNumId w:val="100" /></w:num>
      #|  <w:num w:numId="201"><w:abstractNumId w:val="101" /></w:num>
      #|</w:numbering>
    ),
    { "List1": { style_id: "List1", style_type: "numbering", name: "201" } },
  )
  match numbering.find_level("200", "0") {
    Some(level) => {
      inspect(level.is_ordered, content="true")
      inspect(level.level, content="1")
    }
    None => fail("expected linked numbering level")
  }
}

///|
test "docx paragraph numbering uses numbering xml semantics" {
  let numbering = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42">
      #|    <w:lvl w:ilvl="0"><w:numFmt w:val="bullet" /><w:pStyle w:val="ListBullet" /></w:lvl>
      #|    <w:lvl w:ilvl="1"><w:numFmt w:val="decimal" /></w:lvl>
      #|  </w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  let explicit_xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:numPr><w:ilvl w:val="1" /><w:numId w:val="47" /></w:numPr></w:pPr></w:p>
  let explicit = read_xml_string(
    explicit_xml,
    namespace_map=office_namespace_map(),
  )
  let explicit_reader = body_reader_with_numbering({}, numbering)
  match explicit_reader.read_element(explicit)[0] {
    Paragraph(properties~, ..) =>
      match properties.numbering {
        Some(level) => {
          inspect(level.is_ordered, content="true")
          inspect(level.level, content="2")
        }
        None => fail("expected explicit numbering")
      }
    _ => fail("expected paragraph")
  }
  match
    paragraph_numbering_from_xml(
      "<w:pStyle w:val=\"NoStyle\" /><w:numPr><w:numId w:val=\"47\" /></w:numPr>",
      {},
      numbering,
    ) {
    Some(level) => {
      inspect(level.is_ordered, content="false")
      inspect(level.level, content="1")
    }
    None => fail("expected numId-only fallback numbering")
  }
  let style_xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:pStyle w:val="ListBullet" /></w:pPr></w:p>
  let style_paragraph = read_xml_string(
    style_xml,
    namespace_map=office_namespace_map(),
  )
  let style_reader = body_reader_with_numbering(
    {
      "ListBullet": {
        style_id: "ListBullet",
        style_type: "paragraph",
        name: "List Bullet",
      },
    },
    numbering,
  )
  match style_reader.read_element(style_paragraph)[0] {
    Paragraph(properties~, ..) =>
      match properties.numbering {
        Some(level) => {
          inspect(level.is_ordered, content="false")
          inspect(level.level, content="1")
        }
        None => fail("expected style numbering")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "docx paragraph numbering follows Mammoth fallback order" {
  let numbering = numbering_from_xml(
    (
      #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|  <w:abstractNum w:abstractNumId="42">
      #|    <w:lvl w:ilvl="0"><w:numFmt w:val="bullet" /></w:lvl>
      #|    <w:lvl w:ilvl="1"><w:numFmt w:val="decimal" /><w:pStyle w:val="ListDecimal" /></w:lvl>
      #|  </w:abstractNum>
      #|  <w:num w:numId="47"><w:abstractNumId w:val="42" /></w:num>
      #|</w:numbering>
    ),
    {},
  )
  debug_inspect(
    paragraph_numbering_from_xml(
      "<w:numPr><w:numId w:val=\"47\" /></w:numPr>",
      {},
      numbering,
    ),
    content="Some({ is_ordered: false, level: 1 })",
  )
  debug_inspect(
    paragraph_numbering_from_xml(
      "<w:pStyle w:val=\"ListDecimal\" /><w:numPr><w:numId w:val=\"47\" /></w:numPr>",
      {
        "ListDecimal": {
          style_id: "ListDecimal",
          style_type: "paragraph",
          name: "List Decimal",
        },
      },
      numbering,
    ),
    content="Some({ is_ordered: true, level: 2 })",
  )
  debug_inspect(
    paragraph_numbering_from_xml(
      "<w:numPr><w:ilvl w:val=\"1\" /></w:numPr>",
      {},
      numbering,
    ),
    content="None",
  )
}

///|
test "docx table vertical merges become row spans" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tr><w:tc><w:p /></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart" /></w:tcPr><w:p /></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge w:val="continue" /></w:tcPr><w:p /></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge /></w:tcPr><w:p /></w:tc></w:tr><w:tr><w:tc><w:p /></w:tc></w:tr></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<table><tr><td></td></tr><tr><td rowspan=\"3\"></td></tr><tr></tr><tr></tr><tr><td></td></tr></table>",
  )
}

///|
test "docx table vertical merges account for column spans" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tr><w:tc><w:p /></w:tc><w:tc><w:p /></w:tc><w:tc><w:tcPr><w:vMerge w:val="restart" /></w:tcPr><w:p /></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:gridSpan w:val="2" /></w:tcPr><w:p /></w:tc><w:tc><w:tcPr><w:vMerge w:val="continue" /></w:tcPr><w:p /></w:tc></w:tr><w:tr><w:tc><w:p /></w:tc><w:tc><w:p /></w:tc><w:tc><w:tcPr><w:vMerge w:val="continue" /></w:tcPr><w:p /></w:tc></w:tr><w:tr><w:tc><w:p /></w:tc><w:tc><w:p /></w:tc><w:tc><w:p /></w:tc></w:tr></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<table><tr><td></td><td></td><td rowspan=\"3\"></td></tr><tr><td colspan=\"2\"></td></tr><tr><td></td><td></td></tr><tr><td></td><td></td><td></td></tr></table>",
  )
}

///|
test "docx table vertical merges do not cross misaligned cells" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tr><w:tc><w:tcPr><w:gridSpan w:val="2" /><w:vMerge w:val="restart" /></w:tcPr><w:p /></w:tc></w:tr><w:tr><w:tc><w:p /></w:tc><w:tc><w:tcPr><w:vMerge w:val="continue" /></w:tcPr><w:p /></w:tc></w:tr></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<table><tr><td colspan=\"2\"></td></tr><tr><td></td><td></td></tr></table>",
  )
}

///|
test "docx table row header property marks leading header rows" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tr><w:trPr><w:tblHeader /></w:trPr></w:tr><w:tr /></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<table><thead><tr></tr></thead><tbody><tr></tr></tbody></table>",
  )
}

///|
test "docx table reader warns when row span calculation is unreliable" {
  let non_row_xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tr><w:tc><w:p /></w:tc></w:tr><w:p><w:r><w:t>Between</w:t></w:r></w:p><w:tr><w:tc><w:p /></w:tc></w:tr></w:tbl>
  let non_row = read_xml_string(
    non_row_xml,
    namespace_map=office_namespace_map(),
  )
  let non_row_reader = empty_body_reader({ relationships: [] })
  inspect(
    convert_document_to_html(document(non_row_reader.read_element(non_row))).value,
    content="<table><tr><td></td></tr><p>Between</p><tr><td></td></tr></table>",
  )
  debug_inspect(
    non_row_reader.messages,
    content=(
      #|[Warning("unexpected non-row element in table, cell merging may be incorrect")]
    ),
  )
  let non_cell_xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tr><w:tc><w:p /></w:tc><w:p><w:r><w:t>Between</w:t></w:r></w:p><w:tc><w:p /></w:tc></w:tr></w:tbl>
  let non_cell = read_xml_string(
    non_cell_xml,
    namespace_map=office_namespace_map(),
  )
  let non_cell_reader = empty_body_reader({ relationships: [] })
  inspect(
    convert_document_to_html(document(non_cell_reader.read_element(non_cell))).value,
    content="<table><tr><td></td><p>Between</p><td></td></tr></table>",
  )
  debug_inspect(
    non_cell_reader.messages,
    content=(
      #|[Warning("unexpected non-cell element in table row, cell merging may be incorrect")]
    ),
  )
}

///|
test "docx table deleted rows are ignored" {
  let xml =
    #|<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tr><w:trPr><w:del /></w:trPr><w:tc><w:p><w:r><w:t>Deleted</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>Kept</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<table><tr><td><p>Kept</p></td></tr></table>",
  )
}

///|
test "docx table grid spans follow Mammoth parseInt behavior" {
  let cases = [
    ("2abc", 2),
    (" 3", 3),
    ("+4", 4),
    ("-2", -2),
    ("", 1),
    ("abc", 1),
  ]
  for item in cases {
    let (value, expected) = item
    let xml = "<w:tc xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:tcPr><w:gridSpan w:val=\"" +
      value +
      "\" /></w:tcPr><w:p /></w:tc>"
    let root = read_xml_string(xml, namespace_map=office_namespace_map())
    match empty_body_reader({ relationships: [] }).read_element(root)[0] {
      TableCell(col_span~, row_span~, ..) => {
        inspect(col_span, content=expected.to_string())
        inspect(row_span, content="1")
      }
      _ => fail("expected table cell")
    }
  }
}

///|
test "docx deleted paragraph read directly is ignored" {
  let xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:rPr><w:del /></w:rPr></w:pPr><w:r><w:t>Deleted</w:t></w:r></w:p>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  debug_inspect(
    empty_body_reader({ relationships: [] }).read_element(root),
    content="[]",
  )
}

///|
test "docx deleted paragraph content is prepended to next paragraph" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:rPr><w:del /></w:rPr></w:pPr><w:r><w:t>One</w:t></w:r></w:p><w:p><w:r><w:t>Two</w:t></w:r></w:p><w:p><w:r><w:t>Three</w:t></w:r></w:p></w:body>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_children(
    root.children,
  )
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<p>OneTwo</p><p>Three</p>",
  )
}

///|
fn complex_field_paragraph_html(instruction : String) -> String raise DocxError {
  let xml = "<w:p xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText>" +
    instruction +
    "</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:t>Hello</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r></w:p>"
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  convert_document_to_html(document(elements)).value
}

///|
fn body_elements_html_from_xml(element_xml : String) -> String raise DocxError {
  convert_document_to_html(document(body_elements_from_xml(element_xml))).value
}

///|
test "docx complex field instruction text is not emitted" {
  debug_inspect(
    body_elements_from_xml(
      "<w:instrText> HYPERLINK \"http://example.com\"</w:instrText>",
    ),
    content="[]",
  )
}

///|
fn manual_word_text_element(value : String) -> XmlElement {
  xml_element("w:t", children=[xml_text(value)])
}

///|
fn manual_word_run_element(value : String) -> XmlElement {
  xml_element("w:r", children=[XmlElement(manual_word_text_element(value))])
}

///|
fn manual_word_paragraph_element(value : String) -> XmlElement {
  xml_element("w:p", children=[XmlElement(manual_word_run_element(value))])
}

///|
fn manual_word_text_box_element(value : String) -> XmlElement {
  xml_element("w:txbxContent", children=[
    XmlElement(manual_word_paragraph_element(value)),
  ])
}

///|
fn manual_alternate_content(
  choice : XmlElement,
  fallback : XmlElement,
) -> XmlElement {
  xml_element("mc:AlternateContent", children=[
    XmlElement(xml_element("mc:Choice", children=[XmlElement(choice)])),
    XmlElement(xml_element("mc:Fallback", children=[XmlElement(fallback)])),
  ])
}

///|
test "docx complex field hyperlinks are read" {
  inspect(
    complex_field_paragraph_html(" HYPERLINK \"http://example.com\""),
    content="<p><a href=\"http://example.com\">Hello</a></p>",
  )
  inspect(
    complex_field_paragraph_html(" HYPERLINK http://example.com"),
    content="<p><a href=\"http://example.com\">Hello</a></p>",
  )
  inspect(
    complex_field_paragraph_html(
      " HYPERLINK http://example.com \\o \"tooltip\"",
    ),
    content="<p><a href=\"http://example.com\">Hello</a></p>",
  )
  inspect(complex_field_paragraph_html(" HYPERLINK "), content="<p>Hello</p>")
  inspect(
    complex_field_paragraph_html(" HYPERLINKS http://example.com"),
    content="<p>Hello</p>",
  )
  inspect(
    complex_field_paragraph_html(" HYPERLINK\\l InternalLink"),
    content="<p>Hello</p>",
  )
  inspect(
    complex_field_paragraph_html(" HYPERLINK \\o \"tooltip\""),
    content="<p>Hello</p>",
  )
  inspect(
    complex_field_paragraph_html(" HYPERLINK \\l \"InternalLink\""),
    content="<p><a href=\"#InternalLink\">Hello</a></p>",
  )
  inspect(
    complex_field_paragraph_html(" HYPERLINK \\l "),
    content="<p>Hello</p>",
  )
  inspect(
    complex_field_paragraph_html(" HYPERLINK \\l InternalLink"),
    content="<p><a href=\"#InternalLink\">Hello</a></p>",
  )
  inspect(
    complex_field_paragraph_html(" HYPERLINK \"http://example.com"),
    content="<p><a href=\"&quot;http://example.com\">Hello</a></p>",
  )
}

///|
test "docx complex field helpers tolerate non-field descendants" {
  let element = xml_element("w:r", children=[
    xml_text("ignored"),
    XmlElement(xml_element("w:t", children=[xml_text("plain")])),
  ])
  debug_inspect(read_complex_field_checkbox_checked(element), content="None")
}

///|
test "docx malformed complex field boundaries fail open" {
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:t>Hello</w:t></w:r></w:p>",
    ),
    content="<p>Hello</p>",
  )
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"end\" /></w:r><w:r><w:t>Hello</w:t></w:r></w:p>",
    ),
    content="<p>Hello</p>",
  )
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> HYPERLINK \"http://example.com\"</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:t>Hello</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r></w:p>",
    ),
    content="<p><a href=\"http://example.com\">Hello</a></p>",
  )
  inspect(
    body_elements_html_from_xml("<w:p>ignored<w:r><w:t>Hello</w:t></w:r></w:p>"),
    content="<p>Hello</p>",
  )
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> UNKNOWN </w:instrText><w:r><w:fldChar w:fldCharType=\"end\" /></w:r><w:r><w:t>Hello</w:t></w:r></w:p>",
    ),
    content="<p>Hello</p>",
  )
}

///|
test "docx complex field hyperlinks can wrap non-run elements" {
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> HYPERLINK \"http://example.com\"</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:tab /><w:r><w:fldChar w:fldCharType=\"end\" /></w:r></w:p>",
    ),
    content="<p><a href=\"http://example.com\">\t</a></p>",
  )
}

///|
test "docx complex field hyperlink instructions can be split across runs" {
  let xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:r><w:fldChar w:fldCharType="begin" /></w:r><w:r><w:instrText> HYPE</w:instrText></w:r><w:r><w:instrText>RLINK "http://example.com"</w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate" /></w:r><w:r><w:t>Hello</w:t></w:r><w:r><w:fldChar w:fldCharType="end" /></w:r></w:p>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<p><a href=\"http://example.com\">Hello</a></p>",
  )
}

///|
test "docx complex field hyperlink scope follows field boundaries" {
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> HYPERLINK \"http://example.com\"</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r><w:r><w:t>After</w:t></w:r></w:p>",
    ),
    content="<p>After</p>",
  )
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> HYPERLINK \"http://example.com\"</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> AUTHOR \"John Doe\"</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r><w:r><w:t>this is a hyperlink</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r></w:p>",
    ),
    content="<p><a href=\"http://example.com\">this is a hyperlink</a></p>",
  )
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> HYPERLINK \"http://example.com\"</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> AUTHOR \"John Doe\"</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:t>John Doe</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r></w:p>",
    ),
    content="<p><a href=\"http://example.com\">John Doe</a></p>",
  )
  inspect(
    body_elements_html_from_xml(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:instrText> HYPERLINK \"http://example.com\"</w:instrText><w:r><w:fldChar w:fldCharType=\"separate\" /></w:r><w:r><w:fldChar w:fldCharType=\"begin\" /></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r><w:r><w:t>Hello</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\" /></w:r></w:p>",
    ),
    content="<p><a href=\"http://example.com\">Hello</a></p>",
  )
}

///|
test "docx text boxes read alternate content fallback" {
  let xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice Requires="wps"><w:txbxContent><w:p><w:r><w:t>Choice</w:t></w:r></w:p></w:txbxContent></mc:Choice><mc:Fallback><w:txbxContent><w:p><w:r><w:t>Fallback</w:t></w:r></w:p></w:txbxContent></mc:Fallback></mc:AlternateContent></w:p>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<p>Fallback</p>",
  )
}

///|
test "docx text box helper handles alternate content root" {
  let xml =
    #|<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><mc:Choice Requires="wps"><w:txbxContent><w:p><w:r><w:t>Choice</w:t></w:r></w:p></w:txbxContent></mc:Choice><mc:Fallback><w:txbxContent><w:p><w:r><w:t>Fallback</w:t></w:r></w:p></w:txbxContent></mc:Fallback></mc:AlternateContent>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_text_box_elements(
    root,
  )
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<p>Fallback</p>",
  )
}

///|
test "docx body reader handles unspliced alternate content nodes" {
  let direct_alternate = manual_alternate_content(
    manual_word_text_element("Choice"),
    manual_word_text_element("Fallback"),
  )
  inspect(
    convert_document_to_html(
      document(
        empty_body_reader({ relationships: [] }).read_element(direct_alternate),
      ),
    ).value,
    content="Fallback",
  )
  let paragraph_alternate = xml_element("w:p", children=[
    XmlElement(
      manual_alternate_content(
        manual_word_text_box_element("Choice"),
        manual_word_text_box_element("Fallback"),
      ),
    ),
  ])
  inspect(
    convert_document_to_html(
      document(
        empty_body_reader({ relationships: [] }).read_element(
          paragraph_alternate,
        ),
      ),
    ).value,
    content="<p>Fallback</p>",
  )
  let pict_alternate = xml_element("w:p", children=[
    XmlElement(
      xml_element("w:r", children=[
        XmlElement(manual_word_text_element("Before")),
        XmlElement(
          xml_element("w:pict", children=[
            xml_text("ignored"),
            XmlElement(
              manual_alternate_content(
                xml_element("v:shape", children=[
                  XmlElement(manual_word_text_box_element("Choice")),
                ]),
                xml_element("v:shape", children=[
                  XmlElement(manual_word_text_box_element("Fallback")),
                ]),
              ),
            ),
            xml_text("ignored"),
          ]),
        ),
        XmlElement(manual_word_text_element("After")),
      ]),
    ),
  ])
  inspect(
    convert_document_to_html(
      document(
        empty_body_reader({ relationships: [] }).read_element(pict_alternate),
      ),
    ).value,
    content="<p>BeforeAfter</p><p>Fallback</p>",
  )
  let text_box_with_raw_text = xml_element("v:textbox", children=[
    xml_text("ignored"),
    XmlElement(manual_word_text_box_element("Visible")),
    xml_text("ignored"),
  ])
  inspect(
    convert_document_to_html(
      document(
        empty_body_reader({ relationships: [] }).read_text_box_elements(
          text_box_with_raw_text,
        ),
      ),
    ).value,
    content="<p>Visible</p>",
  )
}

///|
test "docx w:pict images are appended after their containing paragraph" {
  let xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:r><w:t>Before</w:t></w:r><w:r><w:pict><v:shape><v:imagedata r:id="rImage" /></v:shape></w:pict></w:r><w:r><w:t>After</w:t></w:r></w:p>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = drawing_image_reader()
  let elements = reader.read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<p>BeforeAfter</p><img src=\"data:image/png;base64,YWJj\" />",
  )
  debug_inspect(reader.messages, content="[]")
}

///|
test "docx w:pict preserves mixed extra element order after paragraphs" {
  let image_first_xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:r><w:t>Before</w:t></w:r><w:r><w:pict><v:shape><v:imagedata r:id="rImage" /><v:textbox><w:txbxContent><w:p><w:r><w:t>Box</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r><w:r><w:t>After</w:t></w:r></w:p>
  let image_first = read_xml_string(
    image_first_xml,
    namespace_map=office_namespace_map(),
  )
  let image_first_reader = drawing_image_reader()
  inspect(
    convert_document_to_html(
      document(image_first_reader.read_element(image_first)),
    ).value,
    content="<p>BeforeAfter</p><img src=\"data:image/png;base64,YWJj\" /><p>Box</p>",
  )
  debug_inspect(image_first_reader.messages, content="[]")
  let textbox_first_xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:r><w:t>Before</w:t></w:r><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>Box</w:t></w:r></w:p></w:txbxContent></v:textbox><v:imagedata r:id="rImage" /></v:shape></w:pict></w:r><w:r><w:t>After</w:t></w:r></w:p>
  let textbox_first = read_xml_string(
    textbox_first_xml,
    namespace_map=office_namespace_map(),
  )
  let textbox_first_reader = drawing_image_reader()
  inspect(
    convert_document_to_html(
      document(textbox_first_reader.read_element(textbox_first)),
    ).value,
    content="<p>BeforeAfter</p><p>Box</p><img src=\"data:image/png;base64,YWJj\" />",
  )
  debug_inspect(textbox_first_reader.messages, content="[]")
}

///|
test "docx w:pict extra content uses alternate fallback" {
  let xml =
    #|<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><w:r><w:t>Before</w:t></w:r><w:r><w:pict>ignored<mc:AlternateContent><mc:Choice Requires="wps"><v:shape><w:txbxContent><w:p><w:r><w:t>Choice</w:t></w:r></w:p></w:txbxContent></v:shape></mc:Choice><mc:Fallback><v:shape><w:txbxContent><w:p><w:r><w:t>Fallback</w:t></w:r></w:p></w:txbxContent></v:shape></mc:Fallback></mc:AlternateContent>ignored</w:pict></w:r><w:r><w:t>After</w:t></w:r></w:p>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  inspect(
    convert_document_to_html(document(elements)).value,
    content="<p>BeforeAfter</p><p>Fallback</p>",
  )
}

///|
test "docx structured checkbox replacement recurses through containers" {
  let nested = Document(
    children=[
      Hyperlink(
        children=[
          Table(
            children=[
              TableRow(
                children=[
                  TableCell(
                    children=[text("placeholder")],
                    col_span=1,
                    row_span=1,
                  ),
                ],
                is_header=false,
              ),
            ],
            properties=TableProperties::default(),
          ),
        ],
        href=None,
        anchor=None,
        target_frame=None,
      ),
    ],
    notes=[],
    comments=[],
  )
  let (replaced, found) = replace_first_text_in_element(nested, true)
  inspect(found, content="true")
  inspect(
    convert_document_to_html(replaced).value,
    content="<table><tr><td><input type=\"checkbox\" checked=\"checked\" /></td></tr></table>",
  )
  let (unchanged, tab_found) = replace_first_text_in_element(tab(), true)
  inspect(tab_found, content="false")
  debug_inspect(unchanged, content="Tab")
}

///|
fn complex_field_checkbox_html(
  checkbox_children : String,
  separate~ : Bool,
  instruction_text? : String = " FORMCHECKBOX ",
) -> String raise DocxError {
  let separate_xml = if separate {
    "<w:r><w:fldChar w:fldCharType=\"separate\" /></w:r>"
  } else {
    ""
  }
  let xml = "<w:p xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:r><w:fldChar w:fldCharType=\"begin\"><w:ffData><w:checkBox>" +
    checkbox_children +
    "</w:checkBox></w:ffData></w:fldChar></w:r><w:instrText>" +
    instruction_text +
    "</w:instrText>" +
    separate_xml +
    "<w:r><w:fldChar w:fldCharType=\"end\" /></w:r></w:p>"
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  convert_document_to_html(document(elements)).value
}

///|
test "docx complex field checkboxes are read" {
  inspect(
    complex_field_checkbox_html("", separate=false),
    content="<p><input type=\"checkbox\" /></p>",
  )
  inspect(
    complex_field_checkbox_html("<w:default w:val=\"1\" />", separate=false),
    content="<p><input type=\"checkbox\" checked=\"checked\" /></p>",
  )
  inspect(
    complex_field_checkbox_html("<w:default w:val=\"0\" />", separate=false),
    content="<p><input type=\"checkbox\" /></p>",
  )
  inspect(
    complex_field_checkbox_html(
      "<w:default w:val=\"1\" /><w:checked w:val=\"0\" />",
      separate=false,
    ),
    content="<p><input type=\"checkbox\" /></p>",
  )
  inspect(
    complex_field_checkbox_html(
      "<w:default w:val=\"0\" /><w:checked w:val=\"1\" />",
      separate=true,
    ),
    content="<p><input type=\"checkbox\" checked=\"checked\" /></p>",
  )
  inspect(
    complex_field_checkbox_html(
      "",
      separate=false,
      instruction_text=" NOTFORMCHECKBOX ",
    ),
    content="<p><input type=\"checkbox\" /></p>",
  )
  inspect(
    complex_field_checkbox_html(
      "",
      separate=false,
      instruction_text="FORMCHECKBOXES",
    ),
    content="<p><input type=\"checkbox\" /></p>",
  )
  inspect(
    complex_field_checkbox_html(
      "",
      separate=false,
      instruction_text="formcheckbox",
    ),
    content="",
  )
}

///|
test "style map matcher helpers cover run property predicates" {
  inspect(style_warning_label("numbering"), content="numbering")
  let cases : Array[(DocumentMatcher, RunProperties, Bool)] = [
    (RunPropertyMatcher("bold"), run_properties_from_xml("<w:b />"), true),
    (RunPropertyMatcher("italic"), run_properties_from_xml("<w:i />"), true),
    (
      RunPropertyMatcher("underline"),
      run_properties_from_xml("<w:u w:val=\"single\" />"),
      true,
    ),
    (
      RunPropertyMatcher("strikethrough"),
      run_properties_from_xml("<w:strike />"),
      true,
    ),
    (RunPropertyMatcher("allCaps"), run_properties_from_xml("<w:caps />"), true),
    (
      RunPropertyMatcher("smallCaps"),
      run_properties_from_xml("<w:smallCaps />"),
      true,
    ),
    (RunPropertyMatcher("bold"), run_properties_from_xml(""), false),
  ]
  for item in cases {
    let (matcher, properties, expected) = item
    inspect(
      matcher.matches(Run(children=[], properties~)),
      content=expected.to_string(),
    )
  }
}

///|
fn symbol_html(font : String, char : String) -> String raise DocxError {
  let xml = "<w:sym xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" w:font=\"" +
    font +
    "\" w:char=\"" +
    char +
    "\" />"
  let element = read_xml_string(xml, namespace_map=office_namespace_map())
  convert_document_to_html(
    document(empty_body_reader({ relationships: [] }).read_element(element)),
  ).value
}

///|
test "docx symbols are mapped from supported dingbat fonts" {
  inspect(symbol_html("Wingdings", "28"), content="\u{1F57F}")
  inspect(symbol_html("Wingdings", " 28"), content="\u{1F57F}")
  inspect(symbol_html("Wingdings", "0028"), content="\u{1F57F}")
  inspect(symbol_html("Wingdings", "28zz"), content="\u{1F57F}")
  inspect(symbol_html("Wingdings", "F028"), content="\u{1F57F}")
  inspect(symbol_html("Wingdings", "29"), content="\u{2706}")
  inspect(symbol_html("Wingdings", "2a"), content="\u{1F582}")
  inspect(symbol_html("Wingdings", "2b"), content="\u{1F583}")
  inspect(symbol_html("Wingdings", "3e"), content="\u{2707}")
  inspect(symbol_html("Wingdings", "3f"), content="\u{270D}")
  inspect(symbol_html("Wingdings", "40"), content="\u{1F58E}")
  inspect(symbol_html("Wingdings", "41"), content="\u{270C}")
  inspect(symbol_html("Wingdings", "42"), content="\u{1F58F}")
  inspect(symbol_html("Wingdings", "2c"), content="\u{1F4EA}")
  inspect(symbol_html("Wingdings", "2f"), content="\u{1F4ED}")
  inspect(symbol_html("Symbol", "26"), content="&amp;")
  inspect(symbol_html("Symbol", "24"), content="\u{2203}")
  inspect(symbol_html("Symbol", "25"), content="%")
  inspect(symbol_html("Symbol", "22"), content="\u{2200}")
  inspect(symbol_html("Symbol", "23"), content="#")
  inspect(symbol_html("Symbol", "64"), content="\u{3B4}")
  inspect(symbol_html("Symbol", "65"), content="\u{3B5}")
  inspect(symbol_html("Symbol", "66"), content="\u{3C6}")
  inspect(symbol_html("Symbol", "67"), content="\u{3B3}")
  inspect(symbol_html("Symbol", "68"), content="\u{3B7}")
  inspect(symbol_html("Symbol", "69"), content="\u{3B9}")
  inspect(symbol_html("Symbol", "6a"), content="\u{3D5}")
  inspect(symbol_html("Symbol", "6b"), content="\u{3BA}")
  inspect(symbol_html("Symbol", "28"), content="(")
  inspect(symbol_html("Symbol", "29"), content=")")
  inspect(symbol_html("Symbol", "2a"), content="*")
  inspect(symbol_html("Symbol", "27"), content="\u{220D}")
  inspect(symbol_html("Webdings", "61"), content="\u{2714}")
  inspect(symbol_html("Webdings", "62"), content="\u{1F6B2}")
  inspect(symbol_html("Webdings", "63"), content="\u{2B1C}")
  inspect(symbol_html("Wingdings 2", "52"), content="\u{2611}")
  inspect(symbol_html("Wingdings 2", "53"), content="\u{2BBD}")
  inspect(symbol_html("Wingdings 2", "54"), content="\u{2612}")
  inspect(symbol_html("Wingdings 2", "64"), content="\u{1F667}")
  inspect(symbol_html("Wingdings 2", "65"), content="\u{1F65A}")
  inspect(symbol_html("Wingdings 2", "66"), content="\u{1F658}")
  inspect(symbol_html("Wingdings 2", "67"), content="\u{1F659}")
  inspect(symbol_html("Wingdings 2", "68"), content="\u{1F65B}")
  inspect(symbol_html("Wingdings 2", "55"), content="\u{2BBE}")
  inspect(symbol_html("Wingdings 2", "56"), content="\u{2BBF}")
  inspect(symbol_html("Wingdings 2", "57"), content="\u{1F6C7}")
  inspect(symbol_html("Wingdings 2", "58"), content="\u{29B8}")
  inspect(symbol_html("Wingdings 2", "69"), content="\u{24EA}")
  inspect(symbol_html("Wingdings 2", "6a"), content="\u{2460}")
  inspect(symbol_html("Wingdings 2", "6b"), content="\u{2461}")
  inspect(symbol_html("Wingdings 3", "21"), content="\u{2B60}")
  inspect(symbol_html("Wingdings 3", "22"), content="\u{2B62}")
  inspect(symbol_html("Wingdings 3", "23"), content="\u{2B61}")
  inspect(symbol_html("Wingdings 3", "24"), content="\u{2B63}")
  inspect(symbol_html("Wingdings 3", "25"), content="\u{2B66}")
  inspect(symbol_html("Wingdings 3", "26"), content="\u{2B67}")
  inspect(symbol_html("Wingdings 3", "27"), content="\u{2B69}")
  inspect(symbol_html("Wingdings 3", "28"), content="\u{2B68}")
  inspect(symbol_html("Wingdings", "2d"), content="\u{1F4EB}")
  inspect(symbol_html("Wingdings", "2e"), content="\u{1F4EC}")
  inspect(symbol_html("Wingdings", "30"), content="\u{1F5C0}")
  inspect(symbol_html("Wingdings", "43"), content="\u{1F44D}")
  inspect(symbol_html("Wingdings", "44"), content="\u{1F44E}")
  inspect(symbol_html("Wingdings", "45"), content="\u{261C}")
  inspect(symbol_html("Wingdings", "46"), content="\u{261E}")
}

///|
test "docx symbols warn when unsupported like Mammoth" {
  let xml =
    #|<w:sym xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:font="Dingwings" w:char="28" />
  let element = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = empty_body_reader({ relationships: [] })
  debug_inspect(reader.read_element(element), content="[]")
  debug_inspect(
    reader.messages,
    content=(
      #|[Warning("A w:sym element with an unsupported character was ignored: char 28 in font Dingwings")]
    ),
  )
  let lowercase_private_use = read_xml_string(
    "<w:sym xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" w:font=\"Wingdings\" w:char=\"f028\" />",
    namespace_map=office_namespace_map(),
  )
  let lowercase_reader = empty_body_reader({ relationships: [] })
  debug_inspect(
    lowercase_reader.read_element(lowercase_private_use),
    content="[]",
  )
  debug_inspect(
    lowercase_reader.messages,
    content=(
      #|[Warning("A w:sym element with an unsupported character was ignored: char f028 in font Wingdings")]
    ),
  )
  let invalid_hex = read_xml_string(
    "<w:sym xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" w:font=\"Wingdings\" w:char=\"zz\" />",
    namespace_map=office_namespace_map(),
  )
  let invalid_hex_reader = empty_body_reader({ relationships: [] })
  debug_inspect(invalid_hex_reader.read_element(invalid_hex), content="[]")
  debug_inspect(
    invalid_hex_reader.messages,
    content=(
      #|[Warning("A w:sym element with an unsupported character was ignored: char zz in font Wingdings")]
    ),
  )
  let invalid_private_use = read_xml_string(
    "<w:sym xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" w:font=\"Dingwings\" w:char=\"F0zz\" />",
    namespace_map=office_namespace_map(),
  )
  let invalid_private_use_reader = empty_body_reader({ relationships: [] })
  debug_inspect(
    invalid_private_use_reader.read_element(invalid_private_use),
    content="[]",
  )
  debug_inspect(
    invalid_private_use_reader.messages,
    content=(
      #|[Warning("A w:sym element with an unsupported character was ignored: char F0zz in font Dingwings")]
    ),
  )
  let missing_char = read_xml_string(
    "<w:sym xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" w:font=\"Wingdings\" />",
    namespace_map=office_namespace_map(),
  )
  let missing_char_reader = empty_body_reader({ relationships: [] })
  debug_inspect(missing_char_reader.read_element(missing_char), content="[]")
  debug_inspect(
    missing_char_reader.messages,
    content=(
      #|[Warning("A w:sym element with an unsupported character was ignored: char undefined in font Wingdings")]
    ),
  )
}

///|
fn read_vml_wrapper_html(tag : String) -> String raise DocxError {
  let xml = "<" +
    tag +
    " xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:r><w:t>Hello</w:t></w:r></" +
    tag +
    ">"
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  convert_document_to_html(document(elements)).value
}

///|
test "docx vml containers pass through children" {
  inspect(read_vml_wrapper_html("v:roundrect"), content="Hello")
  inspect(read_vml_wrapper_html("v:shape"), content="Hello")
  inspect(read_vml_wrapper_html("v:textbox"), content="Hello")
  inspect(read_vml_wrapper_html("v:group"), content="Hello")
  inspect(read_vml_wrapper_html("v:rect"), content="Hello")
}

///|
test "docx transparent wrappers pass through children" {
  inspect(read_vml_wrapper_html("w:drawing"), content="Hello")
  inspect(read_vml_wrapper_html("w:ins"), content="Hello")
  inspect(read_vml_wrapper_html("w:object"), content="Hello")
  inspect(read_vml_wrapper_html("w:smartTag"), content="Hello")
}

///|
fn drawing_image_reader_with_images(read_images : Bool) -> BodyReader {
  {
    styles: {},
    zip: { entries: { "word/media/tiny.png": b"abc" } },
    relationships: {
      relationships: [
        {
          id: "rImage",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "media/tiny.png",
          target_mode: None,
        },
        {
          id: "rLink",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
          target: "http://example.com",
          target_mode: Some("External"),
        },
      ],
    },
    content_types: { defaults: { "png": "image/png" }, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: default_external_file_access(),
    read_images,
  }
}

///|
fn drawing_image_reader() -> BodyReader {
  drawing_image_reader_with_images(true)
}

///|
test "docx image reader skips DrawingML and VML reads when disabled" {
  let drawing_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let drawing = read_xml_string(
    drawing_xml,
    namespace_map=office_namespace_map(),
  )
  let drawing_reader = drawing_image_reader_with_images(false)
  debug_inspect(drawing_reader.read_element(drawing), content="[]")
  debug_inspect(drawing_reader.messages, content="[]")
  let vml_xml =
    #|<v:imagedata xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rImage" />
  let vml = read_xml_string(vml_xml, namespace_map=office_namespace_map())
  let vml_reader = drawing_image_reader_with_images(false)
  debug_inspect(vml_reader.read_element(vml), content="[]")
  debug_inspect(vml_reader.messages, content="[]")
  let direct_reader = drawing_image_reader_with_images(false)
  debug_inspect(
    direct_reader.read_image_by_relationship("rImage", alt_text=None),
    content="None",
  )
  debug_inspect(
    direct_reader.read_linked_image_by_relationship("rImage", alt_text=None),
    content="None",
  )
  debug_inspect(direct_reader.messages, content="[]")
}

///|
test "docx drawing image hyperlink wraps image" {
  let xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture"><a:hlinkClick r:id="rLink" /></wp:docPr><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = drawing_image_reader()
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<a href=\"http://example.com\"><img src=\"data:image/png;base64,YWJj\" /></a>",
  )
}

///|
test "docx strict DrawingML image namespaces are read" {
  let xml =
    #|<wp:inline xmlns:wp="http://purl.oclc.org/ooxml/drawingml/wordprocessingDrawing" xmlns:a="http://purl.oclc.org/ooxml/drawingml/main" xmlns:pic="http://purl.oclc.org/ooxml/drawingml/picture" xmlns:r="http://purl.oclc.org/ooxml/officeDocument/relationships"><wp:docPr id="1" name="Picture" descr="Strict image" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  inspect(root.name, content="wp:inline")
  let reader = drawing_image_reader()
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img alt=\"Strict image\" src=\"data:image/png;base64,YWJj\" />",
  )
}

///|
test "docx linked DrawingML images use the external loader" {
  let xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture" descr="It's a hat" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:link="rLinkedImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = BodyReader::{
    styles: {},
    zip: { entries: {} },
    relationships: {
      relationships: [
        {
          id: "rLinkedImage",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "file:///media/hat.png",
          target_mode: None,
        },
      ],
    },
    content_types: { defaults: {}, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: external_file_access_options(true, fn(path) {
      if path == "file:///media/hat.png" {
        Some(b"abc")
      } else {
        None
      }
    }),
    read_images: true,
  }
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img alt=\"It's a hat\" src=\"data:image/png;base64,YWJj\" />",
  )
  debug_inspect(reader.messages, content="[]")
}

///|
test "docx linked DrawingML image loader tries decoded file URI paths" {
  let xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:link="rLinkedImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = BodyReader::{
    styles: {},
    zip: { entries: {} },
    relationships: {
      relationships: [
        {
          id: "rLinkedImage",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "file:///media/tiny%20picture.png",
          target_mode: None,
        },
      ],
    },
    content_types: { defaults: {}, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: external_file_access_options(true, fn(path) {
      if path == "/media/tiny picture.png" {
        Some(b"abc")
      } else {
        None
      }
    }),
    read_images: true,
  }
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img src=\"data:image/png;base64,YWJj\" />",
  )
  debug_inspect(reader.messages, content="[]")
}

///|
test "docx embedded DrawingML images ignore relationship target mode" {
  let xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture" descr="It's a hat" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rEmbeddedImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = BodyReader::{
    styles: {},
    zip: { entries: { "word/media/hat.png": b"abc" } },
    relationships: {
      relationships: [
        {
          id: "rEmbeddedImage",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "media/hat.png",
          target_mode: Some("External"),
        },
      ],
    },
    content_types: { defaults: { "png": "image/png" }, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: default_external_file_access(),
    read_images: true,
  }
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img alt=\"It's a hat\" src=\"data:image/png;base64,YWJj\" />",
  )
  debug_inspect(reader.messages, content="[]")
}

///|
test "docx DrawingML image relationship ids follow Mammoth truthiness" {
  let blank_embed_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="" r:link="rLinkedImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let blank_embed = read_xml_string(
    blank_embed_xml,
    namespace_map=office_namespace_map(),
  )
  let linked_reader = BodyReader::{
    styles: {},
    zip: { entries: {} },
    relationships: {
      relationships: [
        {
          id: "rLinkedImage",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "file:///media/hat.png",
          target_mode: Some("External"),
        },
      ],
    },
    content_types: { defaults: {}, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: external_file_access_options(true, fn(path) {
      if path == "file:///media/hat.png" {
        Some(b"abc")
      } else {
        None
      }
    }),
    read_images: true,
  }
  inspect(
    convert_document_to_html(document(linked_reader.read_element(blank_embed))).value,
    content="<img src=\"data:image/png;base64,YWJj\" />",
  )
  debug_inspect(linked_reader.messages, content="[]")
  let blank_drawing_link_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture"><a:hlinkClick r:id="" /></wp:docPr><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let blank_drawing_link = read_xml_string(
    blank_drawing_link_xml,
    namespace_map=office_namespace_map(),
  )
  let blank_link_reader = BodyReader::{
    styles: {},
    zip: { entries: { "word/media/tiny.png": b"abc" } },
    relationships: {
      relationships: [
        {
          id: "rImage",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "media/tiny.png",
          target_mode: None,
        },
        {
          id: "",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
          target: "http://example.com/blank",
          target_mode: Some("External"),
        },
      ],
    },
    content_types: { defaults: { "png": "image/png" }, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: default_external_file_access(),
    read_images: true,
  }
  inspect(
    convert_document_to_html(
      document(blank_link_reader.read_element(blank_drawing_link)),
    ).value,
    content="<img src=\"data:image/png;base64,YWJj\" />",
  )
  debug_inspect(blank_link_reader.messages, content="[]")
}

///|
test "docx drawing image alt text follows Mammoth precedence" {
  let description_and_title =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture" descr="It's a hat" title="hat" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let root = read_xml_string(
    description_and_title,
    namespace_map=office_namespace_map(),
  )
  let reader = drawing_image_reader()
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img alt=\"It's a hat\" src=\"data:image/png;base64,YWJj\" />",
  )
  let blank_description =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture" descr=" " title="It's a hat" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let root = read_xml_string(
    blank_description,
    namespace_map=office_namespace_map(),
  )
  let reader = drawing_image_reader()
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img alt=\"It's a hat\" src=\"data:image/png;base64,YWJj\" />",
  )
  let title_only =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture" title="It's a hat" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let root = read_xml_string(title_only, namespace_map=office_namespace_map())
  let reader = drawing_image_reader()
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img alt=\"It's a hat\" src=\"data:image/png;base64,YWJj\" />",
  )
}

///|
test "docx anchored drawing images are read" {
  let xml =
    #|<wp:anchor xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture" descr="It's a hat" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:anchor>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = drawing_image_reader()
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img alt=\"It's a hat\" src=\"data:image/png;base64,YWJj\" />",
  )
}

///|
test "docx vml image title becomes alt text" {
  let xml =
    #|<v:imagedata xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rImage" o:title="It's a hat" />
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let reader = drawing_image_reader()
  inspect(
    convert_document_to_html(document(reader.read_element(root))).value,
    content="<img alt=\"It's a hat\" src=\"data:image/png;base64,YWJj\" />",
  )
}

///|
test "docx drawing image reader follows Mammoth picture chain" {
  let loose_blip_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:blip r:embed="rImage" /></wp:inline>
  let loose_blip = read_xml_string(
    loose_blip_xml,
    namespace_map=office_namespace_map(),
  )
  let loose_blip_reader = drawing_image_reader()
  debug_inspect(loose_blip_reader.read_element(loose_blip), content="[]")
  debug_inspect(loose_blip_reader.messages, content="[]")
  let loose_link_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:hlinkClick r:id="rLink" /><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let loose_link = read_xml_string(
    loose_link_xml,
    namespace_map=office_namespace_map(),
  )
  let loose_link_reader = drawing_image_reader()
  inspect(
    convert_document_to_html(
      document(loose_link_reader.read_element(loose_link)),
    ).value,
    content="<img src=\"data:image/png;base64,YWJj\" />",
  )
  let missing_link_relationship_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture"><a:hlinkClick r:id="missing" /></wp:docPr><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let missing_link_relationship = read_xml_string(
    missing_link_relationship_xml,
    namespace_map=office_namespace_map(),
  )
  let missing_link_relationship_reader = drawing_image_reader()
  inspect(
    convert_document_to_html(
      document(
        missing_link_relationship_reader.read_element(missing_link_relationship),
      ),
    ).value,
    content="<img src=\"data:image/png;base64,YWJj\" />",
  )
  let link_without_id_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><wp:docPr id="1" name="Picture"><a:hlinkClick /></wp:docPr><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let link_without_id = read_xml_string(
    link_without_id_xml,
    namespace_map=office_namespace_map(),
  )
  let link_without_id_reader = drawing_image_reader()
  inspect(
    convert_document_to_html(
      document(link_without_id_reader.read_element(link_without_id)),
    ).value,
    content="<img src=\"data:image/png;base64,YWJj\" />",
  )
}

///|
test "docx image reader records Mammoth-compatible warnings" {
  let drawing_without_blip_id =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let missing_blip = read_xml_string(
    drawing_without_blip_id,
    namespace_map=office_namespace_map(),
  )
  let missing_blip_reader = empty_body_reader({ relationships: [] })
  debug_inspect(missing_blip_reader.read_element(missing_blip), content="[]")
  debug_inspect(
    missing_blip_reader.messages,
    content=(
      #|[Warning("Could not find image file for a:blip element")]
    ),
  )
  let missing_relationship_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rMissing" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let missing_relationship = read_xml_string(
    missing_relationship_xml,
    namespace_map=office_namespace_map(),
  )
  let missing_relationship_reader = empty_body_reader({ relationships: [] })
  debug_inspect(
    missing_relationship_reader.read_element(missing_relationship),
    content="[]",
  )
  debug_inspect(
    missing_relationship_reader.messages,
    content=(
      #|[Warning("Could not find image file for a:blip element")]
    ),
  )
  let missing_entry_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rMissingEntry" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let missing_entry = read_xml_string(
    missing_entry_xml,
    namespace_map=office_namespace_map(),
  )
  let missing_entry_reader = BodyReader::{
    styles: {},
    zip: { entries: {} },
    relationships: {
      relationships: [
        {
          id: "rMissingEntry",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "media/missing.png",
          target_mode: None,
        },
      ],
    },
    content_types: { defaults: { "png": "image/png" }, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: default_external_file_access(),
    read_images: true,
  }
  debug_inspect(missing_entry_reader.read_element(missing_entry), content="[]")
  debug_inspect(
    missing_entry_reader.messages,
    content=(
      #|[Warning("Could not find image file for a:blip element")]
    ),
  )
  let vml_without_id =
    #|<v:imagedata xmlns:v="urn:schemas-microsoft-com:vml" />
  let vml = read_xml_string(
    vml_without_id,
    namespace_map=office_namespace_map(),
  )
  let vml_reader = empty_body_reader({ relationships: [] })
  debug_inspect(vml_reader.read_element(vml), content="[]")
  debug_inspect(
    vml_reader.messages,
    content=(
      #|[Warning("A v:imagedata element without a relationship ID was ignored")]
    ),
  )
  let vml_with_empty_id =
    #|<v:imagedata xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="" />
  let empty_vml = read_xml_string(
    vml_with_empty_id,
    namespace_map=office_namespace_map(),
  )
  let empty_vml_reader = empty_body_reader({ relationships: [] })
  debug_inspect(empty_vml_reader.read_element(empty_vml), content="[]")
  debug_inspect(
    empty_vml_reader.messages,
    content=(
      #|[Warning("A v:imagedata element without a relationship ID was ignored")]
    ),
  )
  let vml_missing_relationship =
    #|<v:imagedata xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rMissing" />
  let missing_vml = read_xml_string(
    vml_missing_relationship,
    namespace_map=office_namespace_map(),
  )
  let missing_vml_reader = empty_body_reader({ relationships: [] })
  debug_inspect(missing_vml_reader.read_element(missing_vml), content="[]")
  debug_inspect(missing_vml_reader.messages, content="[]")
  let missing_linked_relationship_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:link="rMissing" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let missing_linked_relationship = read_xml_string(
    missing_linked_relationship_xml,
    namespace_map=office_namespace_map(),
  )
  let missing_linked_relationship_reader = empty_body_reader({
    relationships: [],
  })
  debug_inspect(
    missing_linked_relationship_reader.read_element(missing_linked_relationship),
    content="[]",
  )
  debug_inspect(
    missing_linked_relationship_reader.messages,
    content=(
      #|[Warning("Could not find image file for a:blip element")]
    ),
  )
  let external_image_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:link="rExternal" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let external_image = read_xml_string(
    external_image_xml,
    namespace_map=office_namespace_map(),
  )
  let external_reader = BodyReader::{
    styles: {},
    zip: { entries: {} },
    relationships: {
      relationships: [
        {
          id: "rExternal",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "tiny-picture.png",
          target_mode: Some("External"),
        },
      ],
    },
    content_types: { defaults: {}, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: default_external_file_access(),
    read_images: true,
  }
  debug_inspect(external_reader.read_element(external_image), content="[]")
  debug_inspect(
    external_reader.messages,
    content=(
      #|[Error("could not read external image 'tiny-picture.png', external file access is disabled")]
    ),
  )
  let unsupported_type_xml =
    #|<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage" /></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline>
  let unsupported_type = read_xml_string(
    unsupported_type_xml,
    namespace_map=office_namespace_map(),
  )
  let unsupported_reader = BodyReader::{
    styles: {},
    zip: { entries: { "word/media/hat.emf": b"abc" } },
    relationships: {
      relationships: [
        {
          id: "rImage",
          relationship_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
          target: "media/hat.emf",
          target_mode: None,
        },
      ],
    },
    content_types: { defaults: { "emf": "image/x-emf" }, overrides: {} },
    base_path: "word",
    numbering: NumberingMap::empty(),
    messages: [],
    external_files: default_external_file_access(),
    read_images: true,
  }
  inspect(
    unsupported_reader.read_element(unsupported_type).length(),
    content="1",
  )
  debug_inspect(
    unsupported_reader.messages,
    content=(
      #|[Warning("Image of type image/x-emf is unlikely to display in web browsers")]
    ),
  )
}

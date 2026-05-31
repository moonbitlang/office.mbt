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
  }
}

///|
test "docx hyperlink reader replaces external URL fragment when anchor is set" {
  let xml =
    #|<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="r42" w:anchor="fragment"><w:r><w:t>Hello</w:t></w:r></w:hyperlink>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
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
test "docx structured document tag checkbox without content is read" {
  let xml =
    #|<w:sdt xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wordml="http://schemas.microsoft.com/office/word/2010/wordml"><w:sdtPr><wordml:checkbox /></w:sdtPr></w:sdt>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let elements = empty_body_reader({ relationships: [] }).read_element(root)
  debug_inspect(elements, content="[Checkbox(false)]")
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

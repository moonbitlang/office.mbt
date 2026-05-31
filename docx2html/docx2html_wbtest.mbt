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

// N0b1 source-tree identity and budget witnesses. Reader-order projection,
// field state, and SDT/Markup Compatibility transforms deliberately belong to
// N0b2-N0b4.

///|
fn retained_wml_elements(
  scan : StoryScan,
  local_name : String,
) -> Array[ScannedElement] {
  let found : Array[ScannedElement] = []
  for element in scan.elements() {
    if is_wml_uri(element.uri) && element.local_name == local_name {
      found.push(element)
    }
  }
  found
}

///|
fn assert_projection_source_refuses(
  source : String,
  budget : ProjectionSourceBudget,
  fragment : String,
) -> Unit raise {
  try
    scan_projection_source_tree(@utf8.encode(source), budget~) |> ignore
  catch {
    ResourceLimit(limit~, message~) => {
      let limit_name = match limit {
        DocxXmlSourceUnits => "DocxXmlSourceUnits"
        DocxXmlTokens => "DocxXmlTokens"
        DocxXmlTokenLength => "DocxXmlTokenLength"
        DocxXmlMaterializedCharacters => "DocxXmlMaterializedCharacters"
        DocxXmlNestingDepth => "DocxXmlNestingDepth"
      }
      assert_true(limit_name.contains(fragment) || message.contains(fragment))
    }
    Unsupported(message~) => assert_true(message.contains(fragment))
    _ => fail("unexpected projection source error")
  } noraise {
    _ => fail("expected projection source refusal containing: " + fragment)
  }
}

///|
test "projection source tree retains identity links spans and lexical maps" {
  let source =
    #|<x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><x:body><x:p><x:r><x:t>A&amp;😀</x:t></x:r><x:r><x:fldChar x:fldCharType="begin"/><x:sym x:font="Wingdings" x:char="F0FC"/></x:r></x:p><x:p><x:r><x:t/></x:r></x:p></x:body></x:document>
  let bytes = @utf8.encode(source)
  let scan = scan_projection_source_tree(bytes)
  let elements = scan.elements()
  for index, element in elements {
    assert_eq(element.identity, index)
  }

  let paragraphs = retained_wml_elements(scan, "p")
  let runs = retained_wml_elements(scan, "r")
  let texts = retained_wml_elements(scan, "t")
  debug_inspect(
    (
      paragraphs.map(p => p.physical_path(elements)),
      runs.map(r => r.physical_path(elements)),
      texts.map(t => t.physical_path(elements)),
    ),
    content=(
      #|(
      #|  ["/w:document[1]/w:body[1]/w:p[1]", "/w:document[1]/w:body[1]/w:p[2]"],
      #|  [
      #|    "/w:document[1]/w:body[1]/w:p[1]/w:r[1]",
      #|    "/w:document[1]/w:body[1]/w:p[1]/w:r[2]",
      #|    "/w:document[1]/w:body[1]/w:p[2]/w:r[1]",
      #|  ],
      #|  [
      #|    "/w:document[1]/w:body[1]/w:p[1]/w:r[1]/w:t[1]",
      #|    "/w:document[1]/w:body[1]/w:p[2]/w:r[1]/w:t[1]",
      #|  ],
      #|)
    ),
  )

  let first_run = runs[0]
  let second_run = runs[1]
  assert_eq(elements[first_run.parent_index].identity, paragraphs[0].identity)
  assert_eq(
    elements[paragraphs[0].first_child_index].identity,
    first_run.identity,
  )
  assert_eq(first_run.next_sibling_index, second_run.identity)
  assert_eq(second_run.next_sibling_index, -1)

  let first_text = texts[0]
  debug_inspect(
    @utf8.decode(bytes[first_text.byte_start:first_text.byte_end]),
    content="\"<x:t>A&amp;😀</x:t>\"",
  )
  guard first_text.text_map is Some(mapped) else {
    fail("expected retained w:t lexical map")
  }
  debug_inspect(
    (mapped.projection, mapped.projection.length(), mapped.tokens.length()),
    content="(\"A&😀\", 4, 3)",
  )
  // There is no byte position inside `<w:t/>`; treating the following byte
  // as an empty text boundary would let later surgery write outside the tag.
  assert_true(texts[1].text_map is None)

  let fields = retained_wml_elements(scan, "fldChar")
  let symbols = retained_wml_elements(scan, "sym")
  debug_inspect(
    (fields[0].field_char_type, symbols[0].symbol_font, symbols[0].symbol_char),
    content="(Some(\"begin\"), Some(\"Wingdings\"), Some(\"F0FC\"))",
  )
}

///|
test "projection source identity normalizes strict default namespaces" {
  let source =
    #|<document xmlns="http://purl.oclc.org/ooxml/wordprocessingml/main" xmlns:s="http://purl.oclc.org/ooxml/wordprocessingml/main" xmlns:q="urn:not-word"><body><p><r><fldChar q:fldCharType="end" s:fldCharType="begin"/><sym q:font="Fake" s:font="Symbol" q:char="0" s:char="F041"/></r></p></body></document>
  let scan = scan_projection_source_tree(@utf8.encode(source))
  let elements = scan.elements()
  let run = retained_wml_elements(scan, "r")[0]
  debug_inspect(
    run.physical_path(elements),
    content="\"/w:document[1]/w:body[1]/w:p[1]/w:r[1]\"",
  )
  let field = retained_wml_elements(scan, "fldChar")[0]
  let symbol = retained_wml_elements(scan, "sym")[0]
  debug_inspect(
    (field.field_char_type, symbol.symbol_font, symbol.symbol_char),
    content="(Some(\"begin\"), Some(\"Symbol\"), Some(\"F041\"))",
  )
}

///|
test "projection source identity uses canonical sibling ordinals across WML dialects" {
  let source =
    #|<root xmlns:t="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:s="http://purl.oclc.org/ooxml/wordprocessingml/main"><t:p/><s:p/></root>
  let scan = scan_projection_source_tree(@utf8.encode(source))
  let elements = scan.elements()
  debug_inspect(
    retained_wml_elements(scan, "p").map(p => p.physical_path(elements)),
    content="[\"/root[1]/w:p[1]\", \"/root[1]/w:p[2]\"]",
  )
}

///|
test "projection source identity seeds the implicit xml namespace" {
  let source =
    #|<root><xml:x/><x/></root>
  let scan = scan_projection_source_tree(@utf8.encode(source))
  let elements = scan.elements()
  debug_inspect(
    elements[1:].map(element => element.physical_path(elements)),
    content=(
      #|[
      #|  "/root[1]/{36:http://www.w3.org/XML/1998/namespace}x[1]",
      #|  "/root[1]/x[1]",
      #|]
    ),
  )
}

///|
test "projection source attributes follow reader precedence across WML dialects" {
  let source =
    #|<root xmlns:t="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:s="http://purl.oclc.org/ooxml/wordprocessingml/main"><t:fldChar t:fldCharType="begin" s:fldCharType="end"/><s:fldChar s:fldCharType="end" t:fldCharType="begin"/><t:sym t:font="Transitional" s:font="Strict" t:char="F041" s:char="F042"/><s:sym s:font="Strict" t:font="Transitional" s:char="F042" t:char="F041"/></root>
  let scan = scan_projection_source_tree(@utf8.encode(source))
  let fields = retained_wml_elements(scan, "fldChar")
  let symbols = retained_wml_elements(scan, "sym")
  let reader = @xml.read_xml_string_strict(
    source,
    namespace_map=office_namespace_map(),
  )
  let reader_fields = reader.descendants_by_tag_name("w:fldChar")
  let reader_symbols = reader.descendants_by_tag_name("w:sym")
  debug_inspect(
    (
      fields.map(field => field.field_char_type),
      symbols.map(symbol => (symbol.symbol_font, symbol.symbol_char)),
      reader_fields.map(field => field.attributes.get("w:fldCharType")),
      reader_symbols.map(symbol => {
        (symbol.attributes.get("w:font"), symbol.attributes.get("w:char"))
      }),
    ),
    content=(
      #|(
      #|  [Some("end"), Some("begin")],
      #|  [(Some("Strict"), Some("F042")), (Some("Transitional"), Some("F041"))],
      #|  [Some("end"), Some("begin")],
      #|  [(Some("Strict"), Some("F042")), (Some("Transitional"), Some("F041"))],
      #|)
    ),
  )
}

///|
test "annotation-only scans ignore projection-only attribute lookalikes" {
  let source = StringBuilder()
  source.write_string("<q:root xmlns:q=\"urn:not-word\" q:font=\"")
  for _ in 0..<(max_annotation_relevant_attribute_bytes + 1) {
    source.write_char('x')
  }
  source.write_string("\"/>")
  let scan = scan_story(@utf8.encode(source.to_string()))
  debug_inspect(
    (scan.root is Some(_), scan.elements().length()),
    content="(true, 0)",
  )
}

///|
test "projection source element and depth limits have exact witnesses" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>x</w:t></w:r></w:p></w:body></w:document>
  let accepted = scan_projection_source_tree(
    @utf8.encode(source),
    budget=projection_source_budget(
      max_elements=5,
      max_attribute_chars=1024,
      max_depth=5,
      max_text_bytes=1,
      max_text_tokens=1,
    ),
  )
  inspect(accepted.elements().length(), content="5")
  assert_projection_source_refuses(
    source,
    projection_source_budget(
      max_elements=4,
      max_attribute_chars=1024,
      max_depth=5,
      max_text_bytes=1,
      max_text_tokens=1,
    ),
    "DocxXmlTokens",
  )
  assert_projection_source_refuses(
    source,
    projection_source_budget(
      max_elements=5,
      max_attribute_chars=1024,
      max_depth=4,
      max_text_bytes=1,
      max_text_tokens=1,
    ),
    "DocxXmlNestingDepth",
  )
}

///|
test "projection source attribute and text limits are cumulative and exact" {
  let no_text =
    #|<a xmlns:w="u"/>
  ignore(
    scan_projection_source_tree(
      @utf8.encode(no_text),
      budget=projection_source_budget(
        max_elements=1,
        max_attribute_chars=9,
        max_depth=1,
        max_text_bytes=0,
        max_text_tokens=0,
      ),
    ),
  )
  assert_projection_source_refuses(
    no_text,
    projection_source_budget(
      max_elements=1,
      max_attribute_chars=8,
      max_depth=1,
      max_text_bytes=0,
      max_text_tokens=0,
    ),
    "DocxXmlMaterializedCharacters",
  )
  let two_attributes =
    #|<a xmlns:w="u"><b w:id="1"/></a>
  ignore(
    scan_projection_source_tree(
      @utf8.encode(two_attributes),
      budget=projection_source_budget(
        max_elements=2,
        max_attribute_chars=16,
        max_depth=2,
        max_text_bytes=0,
        max_text_tokens=0,
      ),
    ),
  )
  assert_projection_source_refuses(
    two_attributes,
    projection_source_budget(
      max_elements=2,
      max_attribute_chars=15,
      max_depth=2,
      max_text_bytes=0,
      max_text_tokens=0,
    ),
    "DocxXmlMaterializedCharacters",
  )

  let one_tag_two_attributes =
    #|<a xmlns:x="u" xmlns:y="v"/>
  ignore(
    scan_projection_source_tree(
      @utf8.encode(one_tag_two_attributes),
      budget=projection_source_budget(
        max_elements=1,
        max_attribute_chars=17,
        max_depth=1,
        max_text_bytes=0,
        max_text_tokens=0,
      ),
    ),
  )
  assert_projection_source_refuses(
    one_tag_two_attributes,
    projection_source_budget(
      max_elements=1,
      max_attribute_chars=16,
      max_depth=1,
      max_text_bytes=0,
      max_text_tokens=0,
    ),
    "DocxXmlMaterializedCharacters",
  )

  // Every retained namespace declaration consumes one attribute tuple and
  // one binding/scope token. Prove the exact cumulative boundary with enough
  // short unique prefixes to exercise the amplification shape.
  let many_bindings = StringBuilder()
  many_bindings.write_string("<a")
  for index in 0..<64 {
    many_bindings.write_string(" xmlns:p\{index}=\"u\"")
  }
  many_bindings.write_string("/>")
  ignore(
    scan_projection_source_tree(
      @utf8.encode(many_bindings.to_string()),
      budget=projection_source_budget(
        max_elements=1,
        max_attribute_chars=4096,
        max_retained_tokens=192,
        max_depth=1,
        max_text_bytes=0,
        max_text_tokens=0,
      ),
    ),
  )
  assert_projection_source_refuses(
    many_bindings.to_string(),
    projection_source_budget(
      max_elements=1,
      max_attribute_chars=4096,
      max_retained_tokens=191,
      max_depth=1,
      max_text_bytes=0,
      max_text_tokens=0,
    ),
    "DocxXmlTokens",
  )

  // Root QName + namespace declaration = 13. Each child then retains its
  // three-byte source QName plus a ten-character `{5:urn:x}local` key.
  let derived_keys =
    #|<r xmlns:q="urn:x"><q:a/><q:b/></r>
  ignore(
    scan_projection_source_tree(
      @utf8.encode(derived_keys),
      budget=projection_source_budget(
        max_elements=3,
        max_attribute_chars=39,
        max_depth=2,
        max_text_bytes=0,
        max_text_tokens=0,
      ),
    ),
  )
  assert_projection_source_refuses(
    derived_keys,
    projection_source_budget(
      max_elements=3,
      max_attribute_chars=38,
      max_depth=2,
      max_text_bytes=0,
      max_text_tokens=0,
    ),
    "DocxXmlMaterializedCharacters",
  )

  // Root QName + namespace declaration + child QName + canonical `mc:` key.
  // The rendered prefix is three characters, so the exact boundary must
  // include all three rather than sharing WML's two-character `w:` charge.
  let mc_uri = "http://schemas.openxmlformats.org/markup-compatibility/2006"
  let mc_child = "<r xmlns:m=\"" + mc_uri + "\"><m:Fallback/></r>"
  let mc_exact = "r".length() +
    "xmlns:m".length() +
    mc_uri.length() +
    "m:Fallback".length() +
    "mc:Fallback".length()
  ignore(
    scan_projection_source_tree(
      @utf8.encode(mc_child),
      budget=projection_source_budget(
        max_elements=2,
        max_attribute_chars=mc_exact,
        max_depth=2,
        max_text_bytes=0,
        max_text_tokens=0,
      ),
    ),
  )
  assert_projection_source_refuses(
    mc_child,
    projection_source_budget(
      max_elements=2,
      max_attribute_chars=mc_exact - 1,
      max_depth=2,
      max_text_bytes=0,
      max_text_tokens=0,
    ),
    "DocxXmlMaterializedCharacters",
  )

  let source =
    #|<w:t xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">A&amp;😀</w:t>
  ignore(
    scan_projection_source_tree(
      @utf8.encode(source),
      budget=projection_source_budget(
        max_elements=1,
        max_attribute_chars=1024,
        max_depth=1,
        max_text_bytes=10,
        max_text_tokens=3,
      ),
    ),
  )
  assert_projection_source_refuses(
    source,
    projection_source_budget(
      max_elements=1,
      max_attribute_chars=1024,
      max_depth=1,
      max_text_bytes=9,
      max_text_tokens=3,
    ),
    "w:t source byte budget",
  )
  assert_projection_source_refuses(
    source,
    projection_source_budget(
      max_elements=1,
      max_attribute_chars=1024,
      max_depth=1,
      max_text_bytes=10,
      max_text_tokens=2,
    ),
    "w:t token budget",
  )

  let two_texts =
    #|<r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:t>A</w:t><w:t>B</w:t></r>
  ignore(
    scan_projection_source_tree(
      @utf8.encode(two_texts),
      budget=projection_source_budget(
        max_elements=3,
        max_attribute_chars=1024,
        max_depth=2,
        max_text_bytes=2,
        max_text_tokens=2,
      ),
    ),
  )
  assert_projection_source_refuses(
    two_texts,
    projection_source_budget(
      max_elements=3,
      max_attribute_chars=1024,
      max_depth=2,
      max_text_bytes=1,
      max_text_tokens=2,
    ),
    "w:t source byte budget",
  )
  assert_projection_source_refuses(
    two_texts,
    projection_source_budget(
      max_elements=3,
      max_attribute_chars=1024,
      max_depth=2,
      max_text_bytes=2,
      max_text_tokens=1,
    ),
    "w:t token budget",
  )
}

///|
test "projection source mode fails closed on ambiguous physical structure" {
  let mismatched =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body></w:document></w:body>
  assert_projection_source_refuses(
    mismatched,
    projection_source_budget(),
    "mismatched closing tag",
  )
  let prefix_mismatch =
    #|<a:r xmlns:a="urn:same" xmlns:b="urn:same"></b:r>
  assert_projection_source_refuses(
    prefix_mismatch,
    projection_source_budget(),
    "mismatched closing tag",
  )
  let malformed_close =
    #|<a></a junk>
  assert_projection_source_refuses(
    malformed_close,
    projection_source_budget(),
    "malformed closing-tag content",
  )
  for
    case in [
      ("<root/ junk=\"x\">", "malformed self-closing-tag content"),
      ("<root bad></root>", "valueless attribute"),
      ("<root></ root>", "whitespace after a closing-tag opener"),
      ("<root/><", "unterminated markup opener"),
    ] {
    assert_projection_source_refuses(case.0, projection_source_budget(), case.1)
  }
  // These inputs remain accepted by the legacy non-retaining scan. N0b1's
  // strictness is confined to the physical-identity mode.
  for
    source in [
      "<root/ junk=\"x\">", "<root bad></root>", "<root></ root>", "<root/><",
    ] {
    assert_true(scan_story(@utf8.encode(source)).root() is Some(_))
  }
  let multiple =
    #|<a/><b/>
  assert_projection_source_refuses(
    multiple,
    projection_source_budget(),
    "multiple root elements",
  )
  let oversized_close = StringBuilder()
  oversized_close.write_string("<a></")
  for _ in 0..<(max_annotation_relevant_attribute_bytes + 1) {
    oversized_close.write_char('a')
  }
  oversized_close.write_char('>')
  assert_projection_source_refuses(
    oversized_close.to_string(),
    projection_source_budget(),
    "DocxXmlTokenLength",
  )
}

///|
test "projection source mode refuses unbound and reserved namespace identities" {
  for
    case in [
      ("<root><p:x/><x/></root>", "unbound namespace prefix"),
      ("<root xmlns:xml=\"urn:evil\"/>", "invalid xml namespace binding"),
      (
        "<root xmlns:p=\"http://www.w3.org/XML/1998/namespace\"/>", "reserved XML namespace",
      ),
      ("<root xmlns:xmlns=\"urn:evil\"/>", "invalid xmlns namespace binding"),
    ] {
    assert_projection_source_refuses(case.0, projection_source_budget(), case.1)
  }
}

///|
test "projection source physical paths length-prefix arbitrary namespace URIs" {
  let source =
    #|<root xmlns:u="u" xmlns:v="v" xmlns:q="u}a[1]/{v"><u:a><v:b/></u:a><q:b/></root>
  let scan = scan_projection_source_tree(@utf8.encode(source))
  let elements = scan.elements()
  let nested = elements[2].physical_path(elements)
  let sibling = elements[3].physical_path(elements)
  assert_false(nested == sibling)
  debug_inspect(
    (nested, sibling),
    content=(
      #|("/root[1]/{1:u}a[1]/{1:v}b[1]", "/root[1]/{9:u}a[1]/{v}b[1]")
    ),
  )
}

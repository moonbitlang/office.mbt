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
  debug_inspect(fields[0].field_char_type, content="Some(\"begin\")")
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
  debug_inspect(field.field_char_type, content="Some(\"begin\")")
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
  let reader = @xml.read_xml_string_strict(
    source,
    namespace_map=office_namespace_map(),
  )
  let reader_fields = reader.descendants_by_tag_name("w:fldChar")
  let reader_symbols = reader.descendants_by_tag_name("w:sym")
  debug_inspect(
    (
      fields.map(field => field.field_char_type),
      reader_fields.map(field => field.attributes.get("w:fldCharType")),
      reader_symbols.map(symbol => {
        (symbol.attributes.get("w:font"), symbol.attributes.get("w:char"))
      }),
    ),
    content=(
      #|(
      #|  [Some("end"), Some("begin")],
      #|  [Some("end"), Some("begin")],
      #|  [(Some("Strict"), Some("F042")), (Some("Transitional"), Some("F041"))],
      #|)
    ),
  )
}

///|
test "duplicate-WML-attribute precedence is identical in every scan mode" {
  // #462 phase C: last-wins everywhere (the XML reader's canonical-map
  // overwrite precedence). Before unification the legacy annotation scan
  // took the first match, so the same document resolved different marker
  // identities depending on which scan produced them — unacceptable once
  // the index adopts retained projection scans.
  let source =
    #|<root xmlns:t="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:s="http://purl.oclc.org/ooxml/wordprocessingml/main"><t:commentRangeStart t:id="first" s:id="last"/></root>
  let legacy = scan_story(@utf8.encode(source))
  let retained = scan_projection_source_tree(@utf8.encode(source))
  debug_inspect(
    (legacy.markers()[0].id(), retained.markers()[0].id()),
    content="(\"last\", \"last\")",
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

  // Every source attribute QName is charged before it is materialized, even
  // when the annotation scanner does not retain its value. The ordinary p:x
  // name consumes one character-budget slice and one fixed-size token.
  let ordinary_attribute =
    #|<a xmlns:p="u" p:x="ignored"/>
  ignore(
    scan_projection_source_tree(
      @utf8.encode(ordinary_attribute),
      budget=projection_source_budget(
        max_elements=1,
        max_attribute_chars=12,
        max_retained_tokens=4,
        max_depth=1,
        max_text_bytes=0,
        max_text_tokens=0,
      ),
    ),
  )
  assert_projection_source_refuses(
    ordinary_attribute,
    projection_source_budget(
      max_elements=1,
      max_attribute_chars=11,
      max_retained_tokens=4,
      max_depth=1,
      max_text_bytes=0,
      max_text_tokens=0,
    ),
    "DocxXmlMaterializedCharacters",
  )
  assert_projection_source_refuses(
    ordinary_attribute,
    projection_source_budget(
      max_elements=1,
      max_attribute_chars=12,
      max_retained_tokens=3,
      max_depth=1,
      max_text_bytes=0,
      max_text_tokens=0,
    ),
    "DocxXmlTokens",
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

  let mixed_text =
    #|<r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:t>A</w:t><w:instrText>&amp;😀</w:instrText></r>
  ignore(
    scan_projection_source_tree(
      @utf8.encode(mixed_text),
      budget=projection_source_budget(
        max_elements=3,
        max_attribute_chars=1024,
        max_depth=2,
        max_text_bytes=10,
        max_text_tokens=3,
      ),
    ),
  )
  assert_projection_source_refuses(
    mixed_text,
    projection_source_budget(
      max_elements=3,
      max_attribute_chars=1024,
      max_depth=2,
      max_text_bytes=9,
      max_text_tokens=3,
    ),
    "source byte budget",
  )
  assert_projection_source_refuses(
    mixed_text,
    projection_source_budget(
      max_elements=3,
      max_attribute_chars=1024,
      max_depth=2,
      max_text_bytes=10,
      max_text_tokens=2,
    ),
    "token budget",
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
      ("<root p:x=\"1\"/>", "unbound attribute namespace prefix"),
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

///|
/// `w:name` is retained for ONE question — is this Word's `_GoBack`
/// caret? — and `_GoBack` is seven characters, so a longer value is
/// dropped rather than charged. It matters because the capture charges
/// the SHARED retained-character pool: an unbounded name would let a
/// bookmark-heavy story exhaust the ceiling every read verb in the
/// toolkit depends on, on a document that read fine before this
/// attribute was retained at all.
///
/// Measured, not guessed: the test finds the smallest ceiling each
/// story scans under, so it pins the CHARGE rather than a number that
/// drifts with unrelated retention changes.
test "a bookmark name too long to be _GoBack costs no retained characters" {
  let head =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
  let tail = "</w:body></w:document>"
  fn story(name : (Int) -> String?) -> String {
    let markers = StringBuilder()
    for index in 0..<12 {
      match name(index) {
        Some(value) =>
          markers.write_string(
            "<w:bookmarkStart w:id=\"\{index}\" w:name=\"\{value}\"/>",
          )
        None => markers.write_string("<w:bookmarkStart w:id=\"\{index}\"/>")
      }
    }
    head + markers.to_string() + tail
  }

  // The smallest retained-character ceiling this story scans under.
  fn minimal_ceiling(source : String) -> Int {
    for ceiling = 8; ceiling <= 16384; ceiling = ceiling + 8 {
      let mut fits = true
      ignore(
        scan_projection_source_tree(
          @utf8.encode(source),
          budget=projection_source_budget(
            max_elements=64,
            max_attribute_chars=ceiling,
            max_depth=8,
            max_text_bytes=64,
            max_text_tokens=64,
          ),
        ),
      ) catch {
        _ => fits = false
      }
      if fits {
        return ceiling
      }
    }
    -1
  }

  let bare = minimal_ceiling(story(_ => None))
  assert_true(bare > 0)
  // THE INVARIANT: what a declined name costs does not grow with the
  // name. Word's real cross-reference names and one two hundred
  // characters long charge the same, because neither VALUE is retained
  // — only the attribute's QName and its fixed slot, which were charged
  // before the value's length was known. Bounded per bookmark, rather
  // than bounded by the document's longest name.
  let toc = minimal_ceiling(story(index => Some("_Toc1234567\{index}")))
  let mut padding = "_Toc"
  while padding.length() < 200 {
    padding = padding + "0123456789"
  }
  let huge = minimal_ceiling(story(index => Some(padding + "\{index}")))
  assert_eq(huge, toc)
  // THE CONTROL. Names AT the cap are retained and charged, so the
  // equality above is a fact about retention and not a measurement
  // blind to names altogether.
  let short = minimal_ceiling(story(index => Some("_GoBac\{index}")))
  assert_true(
    short > toc,
    msg="retained names must cost something: \{short} vs \{toc}",
  )
  // And the seven-character caret IS captured — the cap admits exactly
  // the value the question is about.
  let scan = scan_projection_source_tree(
    @utf8.encode(
      head + "<w:bookmarkStart w:id=\"1\" w:name=\"_GoBack\"/>" + tail,
    ),
    budget=projection_source_budget(
      max_elements=64,
      max_attribute_chars=4096,
      max_depth=8,
      max_text_bytes=64,
      max_text_tokens=64,
    ),
  )
  let marker = scan
    .elements()
    .filter(element => element.local_name == "bookmarkStart")
  assert_eq(marker.length(), 1)
  assert_eq(marker[0].bookmark_name_raw, Some("_GoBack"))
}

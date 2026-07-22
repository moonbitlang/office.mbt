///|
/// White-box nets for the repeatable-row safety gate (#207 R3): the
/// whitelist in both directions, paraId strip spans, namespace
/// discipline, and structural refusals.

///|
fn wb_row_bindings() -> Map[String, String] {
  { "w": wml_ns, "w14": w14_ns }
}

///|
fn wb_gate(xml : String) -> RowGateOutcome {
  let bytes = @utf8.encode(xml)
  row_safety_gate(bytes[:], wb_row_bindings())
}

///|
test "row gate: a plain formatted row passes with no strips" {
  let outcome = wb_gate(
    (
      #|<w:tr><w:trPr><w:trHeight w:val="240"/></w:trPr><w:tc><w:tcPr><w:tcW w:w="2000" w:type="dxa"/><w:gridSpan w:val="2"/></w:tcPr><w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">{{item}} </w:t></w:r></w:p></w:tc></w:tr>
    ),
  )
  assert_eq(outcome.refusal, None)
  assert_eq(outcome.strip_spans.length(), 0)
}

///|
test "row gate: paraId and textId strip cleanly" {
  let xml =
    #|<w:tr><w:tc><w:p w14:paraId="1A2B3C4D" w14:textId="77777777"><w:r><w:t>x</w:t></w:r></w:p></w:tc></w:tr>
  let outcome = wb_gate(xml)
  assert_eq(outcome.refusal, None)
  assert_eq(outcome.strip_spans.length(), 2)
  // deleting the spans (descending) leaves well-formed markup with no
  // doubled whitespace
  let bytes = @utf8.encode(xml)
  let mut rebuilt = xml
  let mut index = outcome.strip_spans.length() - 1
  while index >= 0 {
    let (start, end) = outcome.strip_spans[index]
    rebuilt = rebuilt.substring(start=0, end=start) +
      rebuilt.substring(start=end)
    index -= 1
  }
  assert_eq(
    rebuilt, "<w:tr><w:tc><w:p><w:r><w:t>x</w:t></w:r></w:p></w:tc></w:tr>",
  )
  ignore(bytes)
}

///|
test "row gate: refusal matrix" {
  for
    xml_and_fragment in [
      (
        "<w:tr><w:tc><w:p><w:bookmarkStart w:id=\"0\" w:name=\"b\"/><w:r><w:t>x</w:t></w:r></w:p></w:tc></w:tr>",
        "bookmarkStart",
      ),
      (
        "<w:tr><w:tc><w:tcPr><w:vMerge w:val=\"restart\"/></w:tcPr><w:p/></w:tc></w:tr>",
        "vMerge",
      ),
      (
        "<w:tr><w:tc><w:tbl><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl></w:tc></w:tr>",
        "tbl",
      ),
      (
        "<w:tr><w:tc><w:p><w:r><w:drawing/></w:r></w:p></w:tc></w:tr>", "drawing",
      ),
      (
        "<w:tr><w:tc><w:p><w:r w:rsidR=\"00AB\" r:id=\"rId9\"><w:t>x</w:t></w:r></w:p></w:tc></w:tr>",
        "no namespace binding",
      ),
      (
        "<w:tr><w:tc><w:p><w:r><w:t val=\"x\">x</w:t></w:r></w:p></w:tc></w:tr>",
        "}val",
      ),
      ("<w:tr><w:tc><!-- note --><w:p/></w:tc></w:tr>", "comments"),
      ("<w:tr><w:tc><w:p><q:zap/></w:p></w:tc></w:tr>", "no namespace binding"),
    ] {
    let (xml, fragment) = xml_and_fragment
    let outcome = wb_gate(xml)
    match outcome.refusal {
      Some(reason) => assert_true(reason.contains(fragment))
      None => fail("expected refusal containing: " + fragment)
    }
  }
}

///|
test "row gate: same-tag bindings resolve before names and scope to the subtree" {
  // an element that BINDS an alien namespace and uses it refuses via
  // the element whitelist, not via missing-binding
  let alien = wb_gate(
    "<w:tr><w:tc><w:p xmlns:x=\"urn:alien\"><x:zap/></w:p></w:tc></w:tr>",
  )
  match alien.refusal {
    Some(reason) => assert_true(reason.contains("{urn:alien}zap"))
    None => fail("expected the alien element to refuse")
  }
  // rebinding w to something else makes even w:t refuse (exact URIs,
  // not prefixes, drive the whitelist)
  let rebound = wb_gate(
    "<w:tr><w:tc><w:p xmlns:w=\"urn:alien\"><w:r><w:t>x</w:t></w:r></w:p></w:tc></w:tr>",
  )
  assert_true(rebound.refusal is Some(_))
  // a sibling AFTER the binding element must not inherit its bindings
  let sibling = wb_gate(
    "<w:tr><w:tc><w:p xmlns:x=\"urn:alien\"/><w:p><w:r><w:t>x</w:t></w:r></w:p></w:tc></w:tr>",
  )
  assert_eq(sibling.refusal, None)
}

///|
test "row gate: entity-spelled namespace bindings decode" {
  let outcome = wb_gate(
    "<w:tr><w:tc><w:p xmlns:v=\"urn:a&amp;b\"><v:zap/></w:p></w:tc></w:tr>",
  )
  match outcome.refusal {
    Some(reason) => assert_true(reason.contains("{urn:a&b}zap"))
    None => fail("expected the entity-bound namespace to resolve and refuse")
  }
}

///|
test "part root bindings seed w and w14" {
  let part = @utf8.encode(
    (
      #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:body/></w:document>
    ),
  )
  guard part_root_bindings(part) is Some(bindings) else {
    fail("root bindings must parse")
  }
  assert_eq(bindings.get("w"), Some(wml_ns))
  assert_eq(bindings.get("w14"), Some(w14_ns))
}

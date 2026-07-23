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
  // query INSIDE the body, where the root's declarations are in scope
  let text = @utf8.decode(part)
  guard text.find("<w:body") is Some(body_at) else { fail("body missing") }
  guard part_bindings_at(part[:], body_at + 1) is Some(bindings) else {
    fail("root bindings must parse")
  }
  assert_eq(bindings.get("w"), Some(wml_ns))
  assert_eq(bindings.get("w14"), Some(w14_ns))
}

///|
test "part bindings walk sees ancestors and respects closes" {
  let part = @utf8.encode(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:body><w:tbl xmlns:w2=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:tr><w:tc/></w:tr></w:tbl>" +
    "<w:p xmlns:q=\"urn:gone\"/><w:p/></w:body></w:document>",
  )
  let text = @utf8.decode(part)
  // inside the table: w2 (bound on w:tbl) is in scope
  guard text.find("<w:tr") is Some(tr_at) else { fail("tr missing") }
  guard part_bindings_at(part[:], tr_at) is Some(inside) else {
    fail("bindings at tr must parse")
  }
  assert_eq(inside.get("w2"), Some(wml_ns))
  // after the self-closing paragraph: its q binding is out of scope
  guard text.find("<w:p/>") is Some(after_at) else { fail("plain p missing") }
  guard part_bindings_at(part[:], after_at) is Some(outside) else {
    fail("bindings after must parse")
  }
  assert_eq(outside.get("q"), None)
  assert_eq(outside.get("w2"), None)
}

///|
test "row gate accepts numeric refs in binding values and aliased WML prefixes" {
  // an alias prefix bound (with a numeric ref spelling) to the WML URI
  // resolves per-URI: w2:r is {WML}r and passes (the t element alone is
  // held to the literal w:t spelling elsewhere)
  let outcome = wb_gate(
    "<w:tr><w:tc><w:p xmlns:w2=\"http://schemas.openxmlformats.org/wordprocessingml/2006/mai&#x6E;\">" +
    "<w2:r><w:t>x</w:t></w2:r></w:p></w:tc></w:tr>",
  )
  assert_eq(outcome.refusal, None)
}

///|
test "row gate: per-element attribute discipline" {
  // w:val is fine on w:jc but alien on w:p
  let misplaced = wb_gate(
    "<w:tr><w:tc><w:p w:val=\"x\"><w:r><w:t>y</w:t></w:r></w:p></w:tc></w:tr>",
  )
  assert_true(misplaced.refusal is Some(_))
  // xml:space belongs to w:t alone
  let space_on_p = wb_gate(
    "<w:tr><w:tc><w:p xml:space=\"preserve\"><w:r><w:t>y</w:t></w:r></w:p></w:tc></w:tr>",
  )
  assert_true(space_on_p.refusal is Some(_))
}

///|
test "row gate admits Word invoice formatting; refuses aliased w:t" {
  // a realistic Word-authored row with theme borders, conditional
  // format flags, theme fonts, autospacing, and tblPrEx borders
  let rich = wb_gate(
    (
      #|<w:tr><w:trPr><w:cnfStyle w:val="100000000000" w:firstRow="1" w:lastColumn="0"/><w:tblPrEx><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto" w:themeColor="text1" w:themeTint="80"/></w:tblBorders></w:tblPrEx></w:trPr><w:tc><w:tcPr><w:tcW w:w="2000" w:type="dxa"/><w:tcBorders><w:bottom w:val="single" w:sz="4" w:themeShade="40" w:shadow="0" w:frame="1"/></w:tcBorders><w:shd w:val="clear" w:fill="auto" w:themeFillTint="20"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:beforeAutospacing="1" w:line="240" w:lineRule="auto"/><w:ind w:left="0" w:startChars="0"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Calibri" w:asciiTheme="minorHAnsi" w:hAnsiTheme="minorHAnsi"/><w:u w:val="single" w:themeColor="hyperlink"/></w:rPr><w:t xml:space="preserve">{{item}}</w:t></w:r></w:p></w:tc></w:tr>
    ),
  )
  assert_eq(rich.refusal, None)
  // an aliased text element resolves to {WML}t but refuses at the gate
  let aliased = wb_gate(
    "<w:tr><w:tc><w:p><w:r><w2:t xmlns:w2=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">x</w2:t></w:r></w:p></w:tc></w:tr>",
  )
  match aliased.refusal {
    Some(reason) => assert_true(reason.contains("literal w:t"))
    None => fail("aliased w:t must refuse at the gate")
  }
}

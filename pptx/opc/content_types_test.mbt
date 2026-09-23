// Modified for office.mbt: follow the workspace warning conventions.

///|
let ct_ns_test : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
fn ct_xml(body : String) -> String {
  "<?xml version=\"1.0\"?>" +
  "<Types xmlns=\"" +
  ct_ns_test +
  "\">" +
  body +
  "</Types>"
}

///|
test "parse simple Default + Override" {
  let xml = ct_xml(
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
    "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
    "<Override PartName=\"/ppt/p.xml\" ContentType=\"application/special+xml\"/>",
  )
  let ct = @opc.ContentTypes::parse(@fzip.str_to_u8(xml))
  debug_inspect(ct.defaults.length(), content="2")
  debug_inspect(ct.overrides.length(), content="1")
}

///|
test "resolve: Override wins over Default" {
  let ct = @opc.ContentTypes::new()
    .with_default("xml", "application/xml")
    .with_override("/ppt/p.xml", "application/special+xml")
  debug_inspect(
    ct.resolve("/ppt/p.xml").unwrap(),
    content="\"application/special+xml\"",
  )
  debug_inspect(
    ct.resolve("/ppt/q.xml").unwrap(),
    content="\"application/xml\"",
  )
}

///|
test "resolve: extension lookup is case-insensitive" {
  let ct = @opc.ContentTypes::new().with_default("XML", "application/xml")
  debug_inspect(ct.resolve("/foo.xml").unwrap(), content="\"application/xml\"")
  debug_inspect(ct.resolve("/foo.XML").unwrap(), content="\"application/xml\"")
  debug_inspect(ct.resolve("/foo.Xml").unwrap(), content="\"application/xml\"")
}

///|
test "resolve: unknown extension returns None" {
  let ct = @opc.ContentTypes::new().with_default("xml", "application/xml")
  debug_inspect(ct.resolve("/foo.bin") is None, content="true")
  debug_inspect(ct.resolve("/foo") is None, content="true") // no extension
}

///|
test "parse rejects elements outside the content-types namespace" {
  let xml = "<?xml version=\"1.0\"?><Types><Default Extension=\"xml\" ContentType=\"x\"/></Types>"
  try @opc.ContentTypes::parse(@fzip.str_to_u8(xml)) catch {
    MalformedPackage(_) => ()
    _ => fail("expected MalformedPackage")
  } noraise {
    _ => fail("expected MalformedPackage")
  }
}

///|
test "parse rejects missing required attribute" {
  let xml = ct_xml("<Default Extension=\"xml\"/>")
  try @opc.ContentTypes::parse(@fzip.str_to_u8(xml)) catch {
    MalformedPackage(_) => ()
    _ => fail("expected MalformedPackage")
  } noraise {
    _ => fail("expected MalformedPackage")
  }
}

///|
test "serialize -> parse round trip preserves entries" {
  let original = @opc.ContentTypes::new()
    .with_default(
      "rels", "application/vnd.openxmlformats-package.relationships+xml",
    )
    .with_default("xml", "application/xml")
    .with_override(
      "/ppt/presentation.xml", "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml",
    )
  let bytes = original.serialize()
  let reparsed = @opc.ContentTypes::parse(bytes)
  debug_inspect(
    reparsed.defaults.length() == original.defaults.length(),
    content="true",
  )
  debug_inspect(
    reparsed.overrides.length() == original.overrides.length(),
    content="true",
  )
  for i in 0..<original.defaults.length() {
    let (ext_r, ct_r) = reparsed.defaults[i]
    let (ext_o, ct_o) = original.defaults[i]
    debug_inspect(ext_r == ext_o, content="true")
    debug_inspect(ct_r == ct_o, content="true")
  }
  for i in 0..<original.overrides.length() {
    let (pn_r, ct_r) = reparsed.overrides[i]
    let (pn_o, ct_o) = original.overrides[i]
    debug_inspect(pn_r == pn_o, content="true")
    debug_inspect(ct_r == ct_o, content="true")
  }
}

///|
test "with_default and with_override are immutable" {
  let base = @opc.ContentTypes::new()
  let plus_default = base.with_default("xml", "application/xml")
  // base unchanged
  debug_inspect(base.defaults.length(), content="0")
  debug_inspect(plus_default.defaults.length(), content="1")
  let plus_both = plus_default.with_override("/p.xml", "x/y")
  debug_inspect(plus_default.overrides.length(), content="0")
  debug_inspect(plus_both.overrides.length(), content="1")
}

///|
fn xml_security_nested_source(count : Int) -> String {
  let builder = StringBuilder()
  for _ in 0..<count {
    builder.write_string("<a>")
  }
  for _ in 0..<count {
    builder.write_string("</a>")
  }
  builder.to_string()
}

///|
fn strict_xml_error(source : String) -> String raise {
  try @xml.read_xml_string_strict(source) catch {
    InvalidXml(message~) => message
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected strict XML parsing to fail")
  }
}

///|
test "strict XML rejects duplicate attributes without changing tolerant parsing" {
  let source = "<root id=\"first\" id=\"second\"/>"
  debug_inspect(
    @xml.read_xml_string(source).attributes.get("id"),
    content="Some(\"second\")",
  )
  inspect(strict_xml_error(source), content="duplicate XML attribute: id")
  inspect(
    strict_xml_error(
      "<root xmlns:a=\"urn:shared\" xmlns:b=\"urn:shared\" a:id=\"first\" b:id=\"second\"/>",
    ),
    content="duplicate expanded XML attribute: {urn:shared}id",
  )
}

///|
test "strict XML expands valid namespaces and entities" {
  let root = @xml.read_xml_string_strict(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><r:root xmlns:r=\"urn:root\" xmlns:a=\"urn:attr\" a:id=\"one&#x20;two\" xml:lang=\"en\">ok &amp; &#65;</r:root>",
  )
  inspect(root.name, content="{urn:root}root")
  debug_inspect(
    root.attributes.get("{urn:attr}id"),
    content="Some(\"one two\")",
  )
  debug_inspect(
    root.attributes.get("{http://www.w3.org/XML/1998/namespace}lang"),
    content="Some(\"en\")",
  )
  inspect(root.text(), content="ok & A")
  inspect(@xml.read_xml_string_strict("<é/>").name, content="é")
}

///|
test "strict XML normalizes source line endings but preserves references" {
  let root = @xml.read_xml_string_strict(
    "<root note=\"one\r\ntwo\">one\r\ntwo&#xD;three</root>",
  )
  debug_inspect(root.attributes.get("note"), content="Some(\"one two\")")
  inspect(root.text(), content="one\ntwo\rthree")
}

///|
test "strict XML rejects malformed entities and illegal characters" {
  for
    source in [
      "<a>&unknown;</a>", "<a>raw & text</a>", "<a>&#;</a>", "<a>&#x;</a>", "<a>&#xD800;</a>",
      "<a>&#x110000;</a>", "<a x=\"raw < text\"/>", "<a>raw ]]></a>",
    ] {
    ignore(strict_xml_error(source))
  }
  let illegal = "<a>" + Int::unsafe_to_char(1).to_string() + "</a>"
  inspect(strict_xml_error(illegal), content="illegal XML character")
  inspect(@xml.read_xml_string("<a>&unknown;</a>").text(), content="&unknown;")
}

///|
test "strict XML enforces qualified names and namespace bindings" {
  for
    source in [
      "<1root/>", "<a:b:c/>", "<root 1id=\"x\"/>", "<p:root/>", "<root p:id=\"x\"/>",
      "<root xmlns:xml=\"urn:not-xml\"/>", "<root xmlns:xmlns=\"urn:bad\"/>", "<root xmlns:p=\"\"/>",
      "<root xmlns:p=\"urn:bad space\"/>",
    ] {
    ignore(strict_xml_error(source))
  }
}

///|
test "strict XML enforces declarations comments and attribute separators" {
  for
    source in [
      " <?xml version=\"1.0\"?><root/>", "<?XML version=\"1.0\"?><root/>", "<?xml encoding=\"UTF-8\"?><root/>",
      "<?xml version=\"1.1\"?><root/>", "<?xml version=\"1.0\" version=\"1.0\"?><root/>",
      "<!DOCTYPE root><root/>", "<root><!-- bad -- comment --></root>", "<root a=\"1\"b=\"2\"/>",
      "<root><?xml version=\"1.0\"?></root>",
    ] {
    ignore(strict_xml_error(source))
  }
  inspect(
    @xml.read_xml_string_strict(
      "<!-- before --><?build ok?><root/><!-- after -->",
    ).name,
    content="root",
  )
}

///|
test "xml parser rejects element nesting deeper than its safety limit" {
  try @xml.read_xml_string(xml_security_nested_source(600)) catch {
    InvalidXml(message~) => inspect(message, content="XML nesting too deep")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected deep nesting to raise")
  }
}

///|
test "xml parser accepts moderate element nesting" {
  let root = @xml.read_xml_string(xml_security_nested_source(100))
  inspect(root.name, content="a")
}

///|
test "strict XML depth limit fails closed on native and Wasm" {
  try @xml.read_xml_string_strict(xml_security_nested_source(300)) catch {
    InvalidXml(message~) => inspect(message, content="XML nesting too deep")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected deep strict XML to raise")
  }
}

///|
test "xml parser raises on malformed UTF-16 text instead of panicking" {
  let source = "<a>" + Int::unsafe_to_char(0xD800).to_string() + "</a>"
  try @xml.read_xml_string(source) catch {
    InvalidXml(message~) =>
      inspect(message, content="invalid UTF-16 in XML content")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected malformed UTF-16 to raise")
  }
}

///|
test "xml parser raises on malformed UTF-16 attribute instead of panicking" {
  let source = "<a b=\"" + Int::unsafe_to_char(0xDC00).to_string() + "\"/>"
  try @xml.read_xml_string(source) catch {
    InvalidXml(message~) =>
      inspect(message, content="invalid UTF-16 in XML content")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected malformed UTF-16 to raise")
  }
}

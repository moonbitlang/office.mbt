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
fn namespace_heavy_source(binding_count : Int, child_count : Int) -> String {
  let builder = StringBuilder()
  builder.write_string("<root")
  for index in 0..<binding_count {
    builder.write_string(" xmlns:n\{index}=\"urn:n\{index}\"")
  }
  builder.write_string(">")
  for _ in 0..<child_count {
    builder.write_string("<child/>")
  }
  builder.write_string("</root>")
  builder.to_string()
}

///|
fn reused_long_namespace_source(uri_chars : Int, child_count : Int) -> String {
  let builder = StringBuilder()
  builder.write_string("<root xmlns:n=\"")
  builder.write_string("u".repeat(uri_chars))
  builder.write_string("\">")
  for _ in 0..<child_count {
    builder.write_string("<n:x/>")
  }
  builder.write_string("</root>")
  builder.to_string()
}

///|
fn popped_namespace_scope_source(
  binding_count : Int,
  sibling_count : Int,
) -> String {
  let builder = StringBuilder()
  builder.write_string("<root><heavy")
  for index in 0..<binding_count {
    builder.write_string(" xmlns:n\{index}=\"urn:n\{index}\"")
  }
  builder.write_string("/>")
  for _ in 0..<sibling_count {
    builder.write_string("<light/>")
  }
  builder.write_string("</root>")
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
fn limited_xml_error(
  source : Bytes,
  budget : @xml.XmlReadBudget,
) -> String raise {
  try @xml.read_xml_bytes_strict_limited(source, budget) catch {
    InvalidXml(message~) => message
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected limited XML parsing to fail")
  }
}

///|
fn limited_xml_write_error(
  element : @xml.XmlElement,
  max_output_bytes : Int,
) -> String raise {
  try @xml.write_xml_fragment_limited(element, max_output_bytes~) catch {
    InvalidXml(message~) => message
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected limited XML serialization to fail")
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
  let cdata = @xml.read_xml_string_strict(
    "<root><![CDATA[one\r\ntwo\rthree &amp;]]></root>",
  )
  inspect(cdata.text(), content="one\ntwo\nthree &amp;")
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
test "limited XML parser charges source before decoding" {
  let budget = @xml.xml_read_budget(
    max_source_units=3,
    max_tokens=32,
    max_materialized_chars=128,
    max_token_chars=32,
  )
  inspect(
    limited_xml_error(@utf8.encode("<a/>"), budget),
    content="XML source budget exceeded",
  )
}

///|
test "limited XML parser bounds tokens, token length, and copied characters" {
  let token_budget = @xml.xml_read_budget(
    max_source_units=64,
    max_tokens=3,
    max_materialized_chars=64,
    max_token_chars=16,
  )
  inspect(
    limited_xml_error(@utf8.encode("<r><x/></r>"), token_budget),
    content="XML token budget exceeded",
  )
  let length_budget = @xml.xml_read_budget(
    max_source_units=64,
    max_tokens=32,
    max_materialized_chars=64,
    max_token_chars=4,
  )
  inspect(
    limited_xml_error(@utf8.encode("<abcdef/>"), length_budget),
    content="XML token length budget exceeded",
  )
  let chars_budget = @xml.xml_read_budget(
    max_source_units=64,
    max_tokens=32,
    max_materialized_chars=5,
    max_token_chars=16,
  )
  inspect(
    limited_xml_error(@utf8.encode("<a x=\"1234\"/>"), chars_budget),
    content="XML materialized character budget exceeded",
  )
}

///|
test "one limited XML budget is cumulative across package parts" {
  let budget = @xml.xml_read_budget(
    max_source_units=12,
    max_tokens=4,
    max_materialized_chars=8,
    max_token_chars=4,
  )
  inspect(
    @xml.read_xml_bytes_strict_limited(@utf8.encode("<a/>"), budget).name,
    content="a",
  )
  inspect(
    @xml.read_xml_bytes_strict_limited(@utf8.encode("<b/>"), budget).name,
    content="b",
  )
  inspect(
    limited_xml_error(@utf8.encode("<c/>"), budget),
    content="XML token budget exceeded",
  )
}

///|
test "limited XML parser charges namespace scope delta work" {
  let source = @utf8.encode(namespace_heavy_source(32, 16))
  let bounded = @xml.xml_read_budget(
    max_source_units=16 * 1024,
    max_tokens=180,
    max_materialized_chars=16 * 1024,
    max_token_chars=128,
  )
  inspect(
    limited_xml_error(source, bounded),
    content="XML token budget exceeded",
  )
  let ample = @xml.xml_read_budget(
    max_source_units=16 * 1024,
    max_tokens=400,
    max_materialized_chars=16 * 1024,
    max_token_chars=128,
  )
  inspect(
    @xml.read_xml_bytes_strict_limited(source, ample).name,
    content="root",
  )
}

///|
test "limited XML parser charges names derived from reused namespace URIs" {
  let source = @utf8.encode(reused_long_namespace_source(4_096, 64))
  let budget = @xml.xml_read_budget(
    max_source_units=64 * 1024,
    max_tokens=10_000,
    max_materialized_chars=64 * 1024,
    max_token_chars=8 * 1024,
  )
  inspect(
    limited_xml_error(source, budget),
    content="XML materialized character budget exceeded",
  )
}

///|
test "namespace scope deltas stay linear after a large child scope" {
  let source = @utf8.encode(popped_namespace_scope_source(256, 2_000))
  let budget = @xml.xml_read_budget(
    max_source_units=128 * 1024,
    // Element/name tokens, declaration deltas, and derived prefixes are all
    // linear in 256 declarations plus 2,000 siblings. A full namespace-map
    // snapshot for every sibling would exceed this structural-work ceiling.
    max_tokens=6_000,
    max_materialized_chars=256 * 1024,
    max_token_chars=4 * 1024,
  )
  inspect(
    @xml.read_xml_bytes_strict_limited(source, budget).name,
    content="root",
  )
}

///|
test "strict XML bounds attacker-controlled diagnostic tokens before joining" {
  let entity = "x".repeat(4096)
  let message = strict_xml_error("<a>&\{entity};</a>")
  assert_true(message.length() < 200)
  assert_true(message.contains("…"))
}

///|
test "limited XML writer sizes escaped UTF-8 output before serialization" {
  let escaped = @xml.xml_element("root", children=[@xml.xml_text("&&")])
  inspect(
    @xml.write_xml_fragment_limited(escaped, max_output_bytes=23),
    content="<root>&amp;&amp;</root>",
  )
  inspect(
    limited_xml_write_error(escaped, 22),
    content="XML serialization byte limit exceeded",
  )
  let unicode = @xml.xml_element("x", children=[@xml.xml_text("界")])
  inspect(
    @xml.write_xml_fragment_limited(unicode, max_output_bytes=10),
    content="<x>界</x>",
  )
  inspect(
    limited_xml_write_error(unicode, 9),
    content="XML serialization byte limit exceeded",
  )
}

///|
test "limited XML writer rejects excessive nesting before recursive output" {
  let mut element = @xml.xml_element("n")
  for _ in 0..<256 {
    element = @xml.xml_element("n", children=[XmlElement(element)])
  }
  inspect(
    limited_xml_write_error(element, 1024 * 1024),
    content="XML serialization nesting limit exceeded",
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

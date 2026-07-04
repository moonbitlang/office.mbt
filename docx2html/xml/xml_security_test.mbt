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
test "xml parser rejects element nesting deeper than 512" {
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

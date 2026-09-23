///|
test "malformed markup raises instead of panicking" {
  for
    input in [
      "<a ", "<root ", "<root a=", "<root a='unterminated", "<root a='1' a='2'/>",
      "<root>&#0;</root>", "<root>&#99999999999999999999999999999999;</root>", "<a/><b/>",
      "<root><!-- broken -- comment --></root>", "<root xmlns:p='urn:x' xmlns:q='urn:x' p:a='1' q:a='2'/>",
      "<!DOCTYPE root [<!ENTITY x 'value'>]><root>&x;</root>",
    ] {
    let rejected = try {
      ignore(drain(input))
      false
    } catch {
      _ => true
    }
    debug_inspect(rejected, content="true")
  }
}

///|
test "entity text coalescing retains adjacent elements and CDATA" {
  let events = drain("<root>A&amp;B<child/>C&#x1F600;<![CDATA[D]]>E</root>")
  debug_inspect(kinds(events), content="\"STSETCTE\"")
  match events[4] {
    Text(text) => debug_inspect(text, content="\"C😀\"")
    _ => fail("expected decoded text after empty child")
  }
}

///|
test "attribute whitespace survives writer and backend reader" {
  let writer = @xml.XmlWriter::new()
  writer.start_element(@xml.QName::unqualified("root"))
  writer.attribute(@xml.QName::unqualified("value"), "a\tb\nc\rd")
  writer.end_element()
  let events = drain(writer.to_string())
  match events[0] {
    StartElement(_, attributes) =>
      debug_inspect(attributes[0].1, content="\"a\\tb\\nc\\rd\"")
    _ => fail("expected element")
  }
}

///|
test "namespace shadowing and predefined xml prefix" {
  let events = drain(
    "<root xmlns='urn:outer' xml:lang='en'><child xmlns='urn:inner'/><tail/></root>",
  )
  match (events[0], events[1], events[3]) {
    (StartElement(root, attrs), StartElement(child, _), StartElement(tail, _)) => {
      debug_inspect(
        (root.uri, child.uri, tail.uri),
        content="(\"urn:outer\", \"urn:inner\", \"urn:outer\")",
      )
      debug_inspect(
        attrs[0].0.uri,
        content="\"http://www.w3.org/XML/1998/namespace\"",
      )
    }
    _ => fail("expected nested elements")
  }
}

///|
test "valid whitespace before an empty-element close" {
  debug_inspect(kinds(drain("<a />")), content="\"SE\"")
}

///|
test "XML 0.5 writer preserves attribute whitespace through the Office reader" {
  for value in ["a\tb\nc\rd", "a\r\nb", "\t", "\n", "\r", " a b "] {
    let writer = @parser.Writer::new()
    writer.empty_element("root", [("value", value)])
    let reader = @xml.XmlReader::new(writer.to_string())
    match reader.next() {
      Some(StartElement(_, attributes)) =>
        debug_inspect(attributes[0].1 == value, content="true")
      _ => fail("expected root element")
    }
  }
}

// Modified for office.mbt: follow the workspace warning conventions.

///|
let a_uri : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
let p_uri : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

///|
test "single empty element self-closes" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.end_element()
  debug_inspect(w.to_string(), content="\"<foo/>\"")
}

///|
test "element with text" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.text("hello")
  w.end_element()
  debug_inspect(w.to_string(), content="\"<foo>hello</foo>\"")
}

///|
test "element with attribute" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.attribute(@xml.QName::unqualified("id"), "42")
  w.end_element()
  debug_inspect(w.to_string(), content="\"<foo id=\\\"42\\\"/>\"")
}

///|
test "nested elements" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("a"))
  w.start_element(@xml.QName::unqualified("b"))
  w.text("x")
  w.end_element()
  w.end_element()
  debug_inspect(w.to_string(), content="\"<a><b>x</b></a>\"")
}

///|
test "namespace prefix lookup" {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("a", a_uri)
  w.start_element(@xml.QName::new(a_uri, "rect"))
  w.namespace_attr("a", a_uri)
  w.attribute(@xml.QName::unqualified("id"), "1")
  w.end_element()
  let expected = "<a:rect xmlns:a=\"" + a_uri + "\" id=\"1\"/>"
  debug_inspect(w.to_string() == expected, content="true")
}

///|
test "attribute escaping" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.attribute(@xml.QName::unqualified("v"), "a&b<c>d\"e\nf")
  w.end_element()
  debug_inspect(
    w.to_string(),
    content="\"<foo v=\\\"a&amp;b&lt;c&gt;d&quot;e&#10;f\\\"/>\"",
  )
}

///|
test "text escaping" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.text("if a < b && c > 0")
  w.end_element()
  debug_inspect(
    w.to_string(),
    content="\"<foo>if a &lt; b &amp;&amp; c &gt; 0</foo>\"",
  )
}

///|
test "CDATA section" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.cdata("raw <stuff> & things")
  w.end_element()
  debug_inspect(
    w.to_string(),
    content="\"<foo><![CDATA[raw <stuff> & things]]></foo>\"",
  )
}

///|
test "CDATA payload with ]]> is rejected" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  try w.cdata("oops ]]> closing") catch {
    WriterMisuse(_) => ()
    _ => fail("expected WriterMisuse")
  } noraise {
    _ => fail("expected WriterMisuse")
  }
}

///|
test "attribute outside start tag is rejected" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  w.text("body")
  try w.attribute(@xml.QName::unqualified("late"), "x") catch {
    WriterMisuse(_) => ()
    _ => fail("expected WriterMisuse")
  } noraise {
    _ => fail("expected WriterMisuse")
  }
}

///|
test "to_string with unclosed elements is rejected" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("foo"))
  try w.to_string() catch {
    WriterMisuse(_) => ()
    _ => fail("expected WriterMisuse")
  } noraise {
    _ => fail("expected WriterMisuse")
  }
}

///|
test "unbound prefix raises UnboundPrefix" {
  let w = @xml.XmlWriter::new()
  try w.start_element(@xml.QName::new(a_uri, "rect")) catch {
    UnboundPrefix(_) => ()
    _ => fail("expected UnboundPrefix")
  } noraise {
    _ => fail("expected UnboundPrefix")
  }
}

///|
test "xml declaration prelude" {
  let w = @xml.XmlWriter::new()
  w.xml_declaration()
  w.start_element(@xml.QName::unqualified("doc"))
  w.end_element()
  debug_inspect(
    w.to_string(),
    content="\"<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\" standalone=\\\"yes\\\"?><doc/>\"",
  )
}

///|
test "ooxml-style root: presentation with namespaces" {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("p", p_uri)
  w.bind_namespace("a", a_uri)
  w.xml_declaration()
  w.start_element(@xml.QName::new(p_uri, "presentation"))
  w.namespace_attr("p", p_uri)
  w.namespace_attr("a", a_uri)
  w.start_element(@xml.QName::new(a_uri, "theme"))
  w.end_element()
  w.end_element()
  let expected = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<p:presentation xmlns:p=\"" +
    p_uri +
    "\" xmlns:a=\"" +
    a_uri +
    "\"><a:theme/></p:presentation>"
  debug_inspect(w.to_string() == expected, content="true")
}

///|
test "pending attributes stay with their element and preserve order" {
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("root"))
  w.attribute(@xml.QName::unqualified("a"), "1")
  w.attribute(@xml.QName::unqualified("b"), "2")
  w.start_element(@xml.QName::unqualified("first"))
  w.attribute(@xml.QName::unqualified("c"), "3")
  w.end_element()
  w.start_element(@xml.QName::unqualified("second"))
  w.text("")
  w.end_element()
  w.end_element()
  debug_inspect(
    w.to_string(),
    content="\"<root a=\\\"1\\\" b=\\\"2\\\"><first c=\\\"3\\\"/><second></second></root>\"",
  )
}

///|
test "backend escaping preserves quotes and whitespace through the reader" {
  let value = "\"'&<>\t\n\r\r\n"
  let w = @xml.XmlWriter::new()
  w.start_element(@xml.QName::unqualified("root"))
  w.attribute(@xml.QName::unqualified("value"), value)
  w.text("\"'&<>")
  w.cdata("raw <text>")
  w.end_element()
  let reader = @xml.XmlReader::new(w.to_string())
  match reader.next() {
    Some(StartElement(_, attrs)) =>
      debug_inspect(attrs[0].1 == value, content="true")
    _ => fail("expected root")
  }
  match reader.next() {
    Some(Text(text)) => debug_inspect(text, content="\"\\\"'&<>\"")
    _ => fail("expected text")
  }
  match reader.next() {
    Some(CData(text)) => debug_inspect(text, content="\"raw <text>\"")
    _ => fail("expected CDATA")
  }
}

///|
test "backend validation errors remain typed XML errors" {
  for
    (name, attrs) in [
      ("bad name", []),
      ("root", [("id", "1"), ("id", "2")]),
      ("root", [("bad name", "value")]),
      ("root", [("id", "\u{0}")]),
    ] {
    let w = @xml.XmlWriter::new()
    let rejected = try {
      w.start_element(@xml.QName::unqualified(name))
      for (name, value) in attrs {
        w.attribute(@xml.QName::unqualified(name), value)
      }
      w.end_element()
      false
    } catch {
      WriterMisuse(_) => true
      _ => false
    }
    debug_inspect(rejected, content="true")
  }
}

///|
test "declarations must precede all elements and occur only once" {
  for position in [0, 1, 2] {
    let w = @xml.XmlWriter::new()
    if position > 0 {
      w.start_element(@xml.QName::unqualified("root"))
      if position == 2 {
        w.end_element()
      }
    } else {
      w.xml_declaration()
    }
    let rejected = try {
      w.xml_declaration()
      false
    } catch {
      WriterMisuse(_) => true
      _ => false
    }
    debug_inspect(rejected, content="true")
  }
}

///|
test "backend rejects missing and multiple roots" {
  let w = @xml.XmlWriter::new()
  let missing = try {
    ignore(w.to_string())
    false
  } catch {
    WriterMisuse(_) => true
    _ => false
  }
  debug_inspect(missing, content="true")
  w.start_element(@xml.QName::unqualified("first"))
  w.end_element()
  let multiple = try {
    w.start_element(@xml.QName::unqualified("second"))
    w.end_element()
    false
  } catch {
    WriterMisuse(_) => true
    _ => false
  }
  debug_inspect(multiple, content="true")
}

///|
test "closing tags retain the prefix used when their element was opened" {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("p", "urn:test")
  w.start_element(@xml.QName::new("urn:test", "root"))
  w.namespace_attr("p", "urn:test")
  w.bind_namespace("q", "urn:test")
  w.start_element(@xml.QName::new("urn:test", "child"))
  w.namespace_attr("q", "urn:test")
  w.end_element()
  w.end_element()
  debug_inspect(
    w.to_string(),
    content="\"<p:root xmlns:p=\\\"urn:test\\\"><q:child xmlns:q=\\\"urn:test\\\"/></p:root>\"",
  )
}

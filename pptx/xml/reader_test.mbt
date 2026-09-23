// Modified for office.mbt: follow the workspace warning conventions.
// Helper: drain a reader to an Array of events.

///|
fn drain(input : String) -> Array[@xml.XmlEvent] raise @xml.XmlError {
  let r = @xml.XmlReader::new(input)
  let out : Array[@xml.XmlEvent] = []
  while true {
    match r.next() {
      Some(e) => out.push(e)
      None => break
    }
  }
  out
}

///|
fn ev_kind(e : @xml.XmlEvent) -> String {
  match e {
    StartElement(_, _) => "S"
    EndElement(_) => "E"
    Text(_) => "T"
    CData(_) => "C"
  }
}

///|
fn kinds(events : Array[@xml.XmlEvent]) -> String {
  let buf = StringBuilder()
  for e in events {
    buf.write_string(ev_kind(e))
  }
  buf.to_string()
}

///|
test "single empty element" {
  let events = drain("<foo/>")
  debug_inspect(events.length(), content="2")
  debug_inspect(events[0] is StartElement(_, _), content="true")
  debug_inspect(events[1] is EndElement(_), content="true")
}

///|
test "element with text" {
  let events = drain("<foo>hello</foo>")
  debug_inspect(kinds(events), content="\"STE\"")
  match events[1] {
    Text(s) => debug_inspect(s, content="\"hello\"")
    _ => fail("expected Text")
  }
}

///|
test "nested elements" {
  let events = drain("<a><b>x</b><c/></a>")
  // <a> S, <b> S, "x" T, </b> E, <c/> S+E, </a> E  ⇒ 7 events
  debug_inspect(kinds(events), content="\"SSTESEE\"")
}

///|
test "attribute parsing and order preserved" {
  let events = drain("<foo a=\"1\" b='2' c=\"3\"/>")
  match events[0] {
    StartElement(_, attrs) => {
      debug_inspect(attrs.length(), content="3")
      debug_inspect(attrs[0].0.local_name, content="\"a\"")
      debug_inspect(attrs[0].1, content="\"1\"")
      debug_inspect(attrs[1].0.local_name, content="\"b\"")
      debug_inspect(attrs[1].1, content="\"2\"")
      debug_inspect(attrs[2].0.local_name, content="\"c\"")
      debug_inspect(attrs[2].1, content="\"3\"")
    }
    _ => fail("expected StartElement")
  }
}

///|
test "entity decoding in text" {
  let events = drain("<foo>a &amp; b &lt; c &gt; d &quot; e &apos; f</foo>")
  match events[1] {
    Text(s) => debug_inspect(s, content="\"a & b < c > d \\\" e ' f\"")
    _ => fail("expected Text")
  }
}

///|
test "numeric entity decoding" {
  let events = drain("<foo>A&#65;B&#x42;C</foo>")
  match events[1] {
    Text(s) => debug_inspect(s, content="\"AABBC\"")
    _ => fail("expected Text")
  }
}

///|
test "CDATA content emitted raw" {
  let events = drain("<foo><![CDATA[a < b & c]]></foo>")
  debug_inspect(kinds(events), content="\"SCE\"")
  match events[1] {
    CData(s) => debug_inspect(s, content="\"a < b & c\"")
    _ => fail("expected CData")
  }
}

///|
test "comment is skipped" {
  let events = drain("<foo><!-- ignore me --><bar/></foo>")
  debug_inspect(kinds(events), content="\"SSEE\"")
}

///|
test "xml declaration is skipped" {
  let events = drain("<?xml version=\"1.0\" encoding=\"UTF-8\"?><foo/>")
  debug_inspect(kinds(events), content="\"SE\"")
}

///|
test "namespace prefix resolution" {
  let xml = "<a:rect xmlns:a=\"http://x\" xmlns:b=\"http://y\"><b:fill/></a:rect>"
  let events = drain(xml)
  debug_inspect(kinds(events), content="\"SSEE\"")
  match events[0] {
    StartElement(name, _) => {
      debug_inspect(name.uri, content="\"http://x\"")
      debug_inspect(name.local_name, content="\"rect\"")
    }
    _ => fail("expected StartElement")
  }
  match events[1] {
    StartElement(name, _) => {
      debug_inspect(name.uri, content="\"http://y\"")
      debug_inspect(name.local_name, content="\"fill\"")
    }
    _ => fail("expected StartElement")
  }
}

///|
test "default namespace applies to elements but not unprefixed attributes" {
  let xml = "<root xmlns=\"http://x\" id=\"1\"><child/></root>"
  let events = drain(xml)
  match events[0] {
    StartElement(name, attrs) => {
      debug_inspect(name.uri, content="\"http://x\"")
      debug_inspect(attrs.length(), content="1")
      // The `id` attribute is unprefixed; it must NOT inherit the default namespace.
      debug_inspect(attrs[0].0.uri, content="\"\"")
      debug_inspect(attrs[0].0.local_name, content="\"id\"")
    }
    _ => fail("expected StartElement")
  }
  match events[1] {
    StartElement(name, _) => debug_inspect(name.uri, content="\"http://x\"")
    _ => fail("expected StartElement")
  }
}

///|
test "attribute with prefix is namespaced" {
  let xml = "<root xmlns:r=\"http://r\" r:id=\"42\"/>"
  let events = drain(xml)
  match events[0] {
    StartElement(_, attrs) => {
      debug_inspect(attrs.length(), content="1")
      debug_inspect(attrs[0].0.uri, content="\"http://r\"")
      debug_inspect(attrs[0].0.local_name, content="\"id\"")
      debug_inspect(attrs[0].1, content="\"42\"")
    }
    _ => fail("expected StartElement")
  }
}

///|
test "mismatched end tag raises" {
  try drain("<a></b>") catch {
    MismatchedEndTag(_) => ()
    _ => fail("expected MismatchedEndTag")
  } noraise {
    _ => fail("expected MismatchedEndTag")
  }
}

///|
test "unbound prefix raises" {
  try drain("<a:x/>") catch {
    UnboundPrefix(_) => ()
    _ => fail("expected UnboundPrefix")
  } noraise {
    _ => fail("expected UnboundPrefix")
  }
}

///|
test "unexpected EOF raises" {
  try drain("<a>unfinished") catch {
    UnexpectedEof => ()
    _ => fail("expected UnexpectedEof")
  } noraise {
    _ => fail("expected UnexpectedEof")
  }
}

///|
test "empty input returns no events" {
  let events = drain("")
  debug_inspect(events.length(), content="0")
}

///|
test "whitespace between root and elements is ignored" {
  let events = drain("  \n  <foo/>  \n  ")
  debug_inspect(kinds(events), content="\"SE\"")
}

///|
test "ooxml-style snippet round-trip events" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
    " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<a:theme><a:rect id=\"1\"/></a:theme>" +
    "</p:presentation>"
  let events = drain(xml)
  debug_inspect(kinds(events), content="\"SSSEEE\"")
  // First event: <p:presentation>
  match events[0] {
    StartElement(name, _) => {
      debug_inspect(
        name.uri,
        content="\"http://schemas.openxmlformats.org/presentationml/2006/main\"",
      )
      debug_inspect(name.local_name, content="\"presentation\"")
    }
    _ => fail("expected StartElement")
  }
  // Second event: <a:theme>
  match events[1] {
    StartElement(name, _) => {
      debug_inspect(
        name.uri,
        content="\"http://schemas.openxmlformats.org/drawingml/2006/main\"",
      )
      debug_inspect(name.local_name, content="\"theme\"")
    }
    _ => fail("expected StartElement")
  }
  // Third event: <a:rect id="1"/>
  match events[2] {
    StartElement(name, attrs) => {
      debug_inspect(name.local_name, content="\"rect\"")
      debug_inspect(attrs.length(), content="1")
      debug_inspect(attrs[0].0.local_name, content="\"id\"")
      debug_inspect(attrs[0].1, content="\"1\"")
    }
    _ => fail("expected StartElement")
  }
}

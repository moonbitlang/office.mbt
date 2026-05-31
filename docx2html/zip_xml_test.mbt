///|
fn hello_zip_bytes() -> Bytes {
  try! @base64.decode(
    "UEsDBAoDAAAAAE+WpETV4Dm3DAAAAAwAAAAFAAAAaGVsbG9IZWxsbyB3b3JsZApQSwECPwMKAwAAAABPlqRE1eA5twwAAAAMAAAABQAAAAAAAAAAACCApIEAAAAAaGVsbG9QSwUGAAAAAAEAAQAzAAAALwAAAAAA",
  )
}

///|
test "zip archive reads vendored fixture bytes" {
  let zip = @docx2html.open_zip(hello_zip_bytes()[:])
  assert_true(zip.exists("hello"))
  match zip.read_text("hello") {
    Some(text) => inspect(text, content="Hello world\n")
    None => fail("missing hello entry")
  }
}

///|
test "zip archive reports invalid zip and invalid UTF-8 parts" {
  try @docx2html.open_zip(b"not a zip") catch {
    InvalidZip(message~) =>
      inspect(message.has_prefix("invalid ZIP archive:"), content="true")
    _ => fail("expected InvalidZip")
  } noraise {
    _ => fail("expected invalid ZIP failure")
  }
  let entries : Map[String, Bytes] = { "bad.xml": Bytes::from_array([b'\xFF']) }
  let zip = @docx2html.ZipArchive::{ entries, }
  try zip.read_text("bad.xml") catch {
    InvalidXml(message~) =>
      inspect(message, content="part is not valid UTF-8: bad.xml")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected invalid UTF-8 failure")
  }
}

///|
test "zip path helpers match Mammoth behavior" {
  let (dir, base) = @docx2html.split_zip_path("a/b/c")
  inspect(dir, content="a/b")
  inspect(base, content="c")
  let (absolute_dir, absolute_base) = @docx2html.split_zip_path("/a/b/c")
  inspect(absolute_dir, content="/a/b")
  inspect(absolute_base, content="c")
  let (empty_dir, name) = @docx2html.split_zip_path("name")
  inspect(empty_dir, content="")
  inspect(name, content="name")
  inspect(@docx2html.join_zip_path(["a", "b"]), content="a/b")
  inspect(@docx2html.join_zip_path(["a/b", "c"]), content="a/b/c")
  inspect(@docx2html.join_zip_path(["a", "b/c"]), content="a/b/c")
  inspect(@docx2html.join_zip_path(["/a/b", "c"]), content="/a/b/c")
  inspect(@docx2html.join_zip_path(["a", ""]), content="a")
  inspect(@docx2html.join_zip_path(["", "b"]), content="b")
  inspect(@docx2html.join_zip_path(["a", "", "b/c"]), content="a/b/c")
  inspect(@docx2html.join_zip_path(["a", "/b"]), content="/b")
  inspect(@docx2html.join_zip_path(["a", "/b", "c"]), content="/b/c")
  inspect(@docx2html.join_zip_path(["/a", "/b"]), content="/b")
  inspect(@docx2html.join_zip_path(["/a"]), content="/a")
}

///|
test "xml reads elements attributes text and namespaces" {
  let namespaces : Map[String, String] = { "word": "w" }
  let root = @docx2html.read_xml_string(
    "<?xml version=\"1.0\" ?>\n<w:body xmlns:w=\"word\" w:val=\"A &amp; B\"><w:p>Hello &lt; XML</w:p></w:body>",
    namespace_map=namespaces,
  )
  debug_inspect(
    root,
    content=(
      #|{
      #|  name: "w:body",
      #|  attributes: { "w:val": "A & B" },
      #|  children: [XmlElement({ name: "w:p", attributes: {}, children: [XmlText("Hello < XML")] })],
      #|}
    ),
  )
  inspect(root.first_or_empty("w:p").text(), content="Hello < XML")
}

///|
test "xml helpers expose text edge cases and recursive descendants" {
  let root = @docx2html.xml_element("root", children=[
    @docx2html.xml_text("prefix"),
    XmlElement(
      @docx2html.xml_element("child", children=[
        XmlElement(
          @docx2html.xml_element("target", children=[
            @docx2html.xml_text("leaf"),
          ]),
        ),
      ]),
    ),
  ])
  inspect(root.descendants_by_tag_name("target").length(), content="1")
  inspect(root.first_or_empty("missing").text(), content="")
  try root.text() catch {
    InvalidXml(message~) =>
      inspect(message, content="element does not contain simple text")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML text failure")
  }
  try
    @docx2html.xml_element("root", children=[
      XmlElement(@docx2html.xml_element("child")),
    ]).text()
  catch {
    InvalidXml(message~) =>
      inspect(message, content="element does not contain simple text")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML text failure")
  }
}

///|
test "xml parser handles comments cdata declarations and entities" {
  let root = @docx2html.read_xml_string(
    (
      #|<?xml version="1.0"?><!--before--><root><!--ignored--><![CDATA[A < B]]><?inside?><!DOCTYPE ignored><child attr="&quot;&apos;&gt;">x &gt; &quot; &apos; &unknown; &</child></root>
    ),
  )
  inspect(root.children.length(), content="2")
  match root.children[0] {
    XmlText(value) => inspect(value, content="A < B")
    _ => fail("expected CDATA text")
  }
  let child = root.first_or_empty("child")
  inspect(child.attributes.get_or_default("attr", ""), content="\"'>")
  inspect(child.text(), content="x > \" ' &unknown; &")
}

///|
test "xml reader uses mc fallback content like Mammoth" {
  let namespaces : Map[String, String] = {
    "http://schemas.openxmlformats.org/markup-compatibility/2006": "mc",
  }
  let root = @docx2html.read_xml_string(
    (
      #|<numbering xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice Requires="w14"><choice /></mc:Choice><mc:Fallback><fallback /></mc:Fallback></mc:AlternateContent></numbering>
    ),
    namespace_map=namespaces,
  )
  debug_inspect(
    root.children,
    content="[XmlElement({ name: \"fallback\", attributes: {}, children: [] })]",
  )
  let ignored = @docx2html.read_xml_string(
    (
      #|<numbering xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice Requires="w14"><choice /></mc:Choice></mc:AlternateContent></numbering>
    ),
    namespace_map=namespaces,
  )
  debug_inspect(ignored.children, content="[]")
}

///|
test "xml reports malformed documents" {
  try @docx2html.read_xml_string("<body><p></body>") catch {
    InvalidXml(message~) =>
      inspect(message, content="mismatched closing tag: expected p got body")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
  try @docx2html.read_xml_string("<>") catch {
    InvalidXml(message~) => inspect(message, content="expected XML name")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
  try @docx2html.read_xml_string("<root attr=>") catch {
    InvalidXml(message~) =>
      inspect(message, content="expected quoted attribute value")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
  try @docx2html.read_xml_string("<root attr=") catch {
    InvalidXml(message~) =>
      inspect(message, content="expected quoted attribute value")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
  try @docx2html.read_xml_string("<root attr\"value\" />") catch {
    InvalidXml(message~) => inspect(message, content="expected `=`")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
  try @docx2html.read_xml_string("<root attr=\"value>") catch {
    InvalidXml(message~) =>
      inspect(message, content="unterminated attribute value")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
  try @docx2html.read_xml_string("<root") catch {
    InvalidXml(message~) => inspect(message, content="expected XML name")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
}

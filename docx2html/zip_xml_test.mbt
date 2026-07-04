///|
fn hello_zip_bytes() -> Bytes {
  try! @base64.decode(
    "UEsDBAoDAAAAAE+WpETV4Dm3DAAAAAwAAAAFAAAAaGVsbG9IZWxsbyB3b3JsZApQSwECPwMKAwAAAABPlqRE1eA5twwAAAAMAAAABQAAAAAAAAAAACCApIEAAAAAaGVsbG9QSwUGAAAAAAEAAQAzAAAALwAAAAAA",
  )
}

///|
test "zip archive reads vendored fixture bytes" {
  let zip = @docx2html.open_zip(hello_zip_bytes())
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
test "xml namespace mapping follows Mammoth reader behavior" {
  let unmapped = @docx2html.read_xml_string("<w:body xmlns:w=\"word\" />")
  inspect(unmapped.name, content="{word}body")
  let namespace_map : Map[String, String] = { "word": "x" }
  let mapped = @docx2html.read_xml_string(
    "<w:body xmlns:w=\"word\" w:val=\"Hello!\" />",
    namespace_map~,
  )
  inspect(mapped.name, content="x:body")
  inspect(mapped.attributes.get_or_default("x:val", ""), content="Hello!")
  let empty_prefix = @docx2html.read_xml_string(
    "<w:body xmlns:w=\"word\" w:val=\"Hello!\" />",
    namespace_map={ "word": "" },
  )
  inspect(empty_prefix.name, content="{word}body")
  inspect(
    empty_prefix.attributes.get_or_default("{word}val", ""),
    content="Hello!",
  )
  let default_namespace = @docx2html.read_xml_string(
    "<body xmlns=\"music\" />",
    namespace_map={ "music": "" },
  )
  inspect(default_namespace.name, content="{music}body")
  let root = @docx2html.read_xml_string(
    "<body><a /><b index=\"1\" /><b index=\"2\" /></body>",
  )
  match root.first("b") {
    Some(first) =>
      inspect(first.attributes.get_or_default("index", ""), content="1")
    None => fail("expected first b element")
  }
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
      #|<?xml version="1.0"?><!--before--><root><!--ignored--><![CDATA[A < B]]><?inside?><!DOCTYPE ignored><child attr="&quot;&apos;&gt;&#169;&#x1F600;&#x41;">x &#169;&#x1f600;&#x41; &gt; &quot; &apos; &unknown; &; &</child></root>
    ),
  )
  inspect(root.children.length(), content="2")
  match root.children[0] {
    XmlText(value) => inspect(value, content="A < B")
    _ => fail("expected CDATA text")
  }
  let child = root.first_or_empty("child")
  inspect(
    child.attributes.get_or_default("attr", ""),
    content="\"'>\u{A9}\u{1F600}A",
  )
  inspect(child.text(), content="x \u{A9}\u{1F600}A > \" ' &unknown; &; &")
}

///|
test "xml parser scans skipped content containing surrogate pairs" {
  let root = @docx2html.read_xml_string(
    "<root><!-- skip \u{1F600} safely --><child /></root>",
  )
  inspect(root.children.length(), content="1")
  inspect(root.first_or_empty("child").name, content="child")
  let text = @docx2html.read_xml_string("<root>x \u{1F600} &amp; y</root>")
  inspect(text.text(), content="x \u{1F600} & y")
}

///|
test "xml parser follows xmldom numeric entity edge cases" {
  let root = @docx2html.read_xml_string(
    "<root attr=\"&#xG;&#12a;&#X41;&#x;&#;\">&#xG;&#12a;&#X41;&#x;&#55296;&#999999999999999999999;&#-1;&#;</root>",
  )
  let attr = root.attributes.get_or_default("attr", "")
  inspect(attr.length(), content="7")
  inspect(attr[0].to_int(), content="0")
  inspect(attr[1].to_int(), content="12")
  inspect(attr[2].to_int(), content="0")
  inspect(attr[3].to_int(), content="0")
  match attr.find("&#;") {
    Some(_) => ()
    None => fail("expected empty numeric entity to remain raw in attribute")
  }
  let text = root.text()
  inspect(text[0].to_int(), content="0")
  inspect(text[1].to_int(), content="12")
  inspect(text[2].to_int(), content="0")
  inspect(text[3].to_int(), content="0")
  match text.find("&#55296;") {
    Some(_) => ()
    None => fail("expected surrogate entity to remain raw")
  }
  match text.find("&#999999999999999999999;") {
    Some(_) => ()
    None => fail("expected out-of-range entity to remain raw")
  }
  match text.find("&#-1;") {
    Some(_) => ()
    None => fail("expected non-word numeric entity to remain raw")
  }
  match text.find("&#;") {
    Some(_) => ()
    None => fail("expected empty numeric entity to remain raw")
  }
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
test "xml writer follows Mammoth element and namespace output" {
  inspect(
    @docx2html.write_xml_string(@docx2html.xml_element("root")),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root/>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", attributes={ "ignored": "yes" }, children=[
        XmlElement(
          @docx2html.xml_element("child", attributes={
            "TargetMode": "External",
            "Target": "target.xml",
            "Type": "type",
            "Id": "rId1",
          }),
        ),
      ]),
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root><child Id=\"rId1\" Type=\"type\" Target=\"target.xml\" TargetMode=\"External\"/></root>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", children=[
        XmlElement(@docx2html.xml_element("album")),
        XmlElement(@docx2html.xml_element("single")),
      ]),
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root><album/><single/></root>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", children=[
        XmlElement(
          @docx2html.xml_element("album", children=[
            XmlElement(@docx2html.xml_element("year")),
            XmlElement(@docx2html.xml_element("song")),
          ]),
        ),
      ]),
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root><album><year/><song/></album></root>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", children=[
        XmlElement(
          @docx2html.xml_element("album", attributes={
            "title": "Everything in Transit",
          }),
        ),
      ]),
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root><album title=\"Everything in Transit\"/></root>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", children=[
        XmlElement(
          @docx2html.xml_element("album", attributes={ "title": "\"<&>" }, children=[
            @docx2html.xml_text("Everything <&> Transit"),
          ]),
        ),
      ]),
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root><album title=\"&quot;&lt;&amp;&gt;\">Everything &lt;&amp;&gt; Transit</album></root>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", children=[
        XmlElement(
          @docx2html.xml_element("album", attributes={
            "z": "last",
            "a": "first",
          }),
        ),
      ]),
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root><album a=\"first\" z=\"last\"/></root>",
  )
  inspect(
    @docx2html.write_xml_string(@docx2html.xml_element("{music}root"), namespaces={
      "m": "music",
    }),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><m:root xmlns:m=\"music\"/>",
  )
  inspect(
    @docx2html.write_xml_string(@docx2html.xml_element("{music}root"), namespaces={
      "z": "zoo",
      "": "default",
      "m": "music",
    }),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><m:root xmlns=\"default\" xmlns:m=\"music\" xmlns:z=\"zoo\"/>",
  )
  inspect(
    @docx2html.write_xml_string(@docx2html.xml_element("{unknown}root"), namespaces={
      "m": "music",
    }),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><{unknown}root xmlns:m=\"music\"/>",
  )
  inspect(
    @docx2html.write_xml_string(@docx2html.xml_element("{broken"), namespaces={
      "m": "music",
    }),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><{broken xmlns:m=\"music\"/>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", children=[
        XmlElement(@docx2html.xml_element("{music}album")),
      ]),
      namespaces={ "m": "music" },
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root xmlns:m=\"music\"><m:album/></root>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", children=[
        XmlElement(@docx2html.xml_element("m:album")),
      ]),
      namespaces={ "m": "music" },
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root xmlns:m=\"music\"><m:album/></root>",
  )
  inspect(
    @docx2html.write_xml_string(
      @docx2html.xml_element("root", children=[
        XmlElement(@docx2html.xml_element("{music}album")),
      ]),
      namespaces={ "": "music" },
    ),
    content="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root xmlns=\"music\"><album/></root>",
  )
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
  try @docx2html.read_xml_string("<body/><other/>") catch {
    InvalidXml(message~) =>
      inspect(message, content="unexpected content after document element")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
  let with_trailing_misc = @docx2html.read_xml_string(
    "<body/>   <!-- trailing --><?ok?>",
  )
  inspect(with_trailing_misc.name, content="body")
}

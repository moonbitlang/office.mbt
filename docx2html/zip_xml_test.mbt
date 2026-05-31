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
test "zip path helpers match Mammoth behavior" {
  let (dir, base) = @docx2html.split_zip_path("a/b/c")
  inspect(dir, content="a/b")
  inspect(base, content="c")
  let (empty_dir, name) = @docx2html.split_zip_path("name")
  inspect(empty_dir, content="")
  inspect(name, content="name")
  inspect(@docx2html.join_zip_path(["a", "", "b/c"]), content="a/b/c")
  inspect(@docx2html.join_zip_path(["a", "/b", "c"]), content="/b/c")
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
test "xml reports malformed documents" {
  try @docx2html.read_xml_string("<body><p></body>") catch {
    InvalidXml(message~) =>
      inspect(message, content="mismatched closing tag: expected p got body")
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected XML parse failure")
  }
}

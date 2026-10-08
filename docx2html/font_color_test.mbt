///|
test "DOCX font color reaches HTML" {
  let bytes = hf_package(
    document="<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:rPr><w:color w:val=\"C00000\"/></w:rPr><w:t>red</w:t></w:r></w:p></w:body></w:document>",
  )
  debug_inspect(
    @docx2html.convert_to_html(bytes).value,
    content="\"<p><span style=\\\"color: #C00000\\\">red</span></p>\"",
  )
}

///|
fn color_document(
  body : String,
  styles? : String = "",
  theme? : String = "",
  strict? : Bool = false,
  settings? : String = "",
) -> Bytes {
  let archive = @mbtzip.Archive()
  let ns = if strict {
    "http://purl.oclc.org/ooxml/wordprocessingml/main"
  } else {
    "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  }
  let rel = if strict {
    "http://purl.oclc.org/ooxml/officeDocument/relationships/"
  } else {
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
  }
  for
    (path, text) in [
      (
        "[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/><Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/><Override PartName=\"/assets/colors.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/></Types>",
      ),
      (
        "_rels/.rels",
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"doc\" Type=\"\{rel}officeDocument\" Target=\"word/document.xml\"/></Relationships>",
      ),
      (
        "word/document.xml",
        "<w:document xmlns:w=\"\{ns}\"><w:body>\{body}</w:body></w:document>",
      ),
      (
        "word/_rels/document.xml.rels",
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"styles\" Type=\"\{rel}styles\" Target=\"styles.xml\"/><Relationship Id=\"theme\" Type=\"\{rel}theme\" Target=\"../assets/colors.xml\"/><Relationship Id=\"settings\" Type=\"\{rel}settings\" Target=\"settings.xml\"/></Relationships>",
      ),
      ("word/styles.xml", "<w:styles xmlns:w=\"\{ns}\">\{styles}</w:styles>"),
      (
        "assets/colors.xml",
        "<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><a:themeElements><a:clrScheme name=\"Trial\">\{theme}</a:clrScheme></a:themeElements></a:theme>",
      ),
    ] {
    archive.add(path, @utf8.encode(text))
  }
  archive.add(
    "word/settings.xml",
    @utf8.encode("<w:settings xmlns:w=\"\{ns}\">\{settings}</w:settings>"),
  )
  try! @mbtzip.write_preserving(archive)
}

///|
test "DOCX colors inherit defaults paragraph and character styles with direct override" {
  let styles =
    #|<w:docDefaults><w:rPrDefault><w:rPr><w:color w:val="112233"/></w:rPr></w:rPrDefault></w:docDefaults>
    #|<w:style w:type="paragraph" w:styleId="Base"><w:rPr><w:color w:val="00FF00"/></w:rPr></w:style>
    #|<w:style w:type="paragraph" w:styleId="Body"><w:basedOn w:val="Base"/></w:style>
    #|<w:style w:type="character" w:styleId="Blue"><w:rPr><w:color w:val="0000FF"/></w:rPr></w:style>
  let body =
    #|<w:p><w:r><w:t>default</w:t></w:r></w:p>
    #|<w:p><w:pPr><w:pStyle w:val="Body"/></w:pPr><w:r><w:t>paragraph</w:t></w:r><w:r><w:rPr><w:rStyle w:val="Blue"/></w:rPr><w:t>character</w:t></w:r><w:r><w:rPr><w:rStyle w:val="Blue"/><w:color w:val="ff0000"/></w:rPr><w:t>direct</w:t></w:r><w:r><w:rPr><w:color w:val="auto"/></w:rPr><w:t>auto</w:t></w:r></w:p>
    #|<w:p><w:r><w:t>default again</w:t></w:r></w:p>
  debug_inspect(
    @docx2html.convert_to_html(color_document(body, styles~)).value,
    content=(
      #|"<p><span style=\"color: #112233\">default</span></p><p><span style=\"color: #00FF00\">paragraph</span><span style=\"color: #0000FF\">character</span><span style=\"color: #FF0000\">direct</span><span style=\"color: initial\">auto</span></p><p><span style=\"color: #112233\">default again</span></p>"
    ),
  )
}

///|
test "DOCX theme uses relationships and overrides cached RGB in strict and transitional documents" {
  for strict in [false, true] {
    let body =
      #|<w:p><w:r><w:rPr><w:color w:val="FF0000" w:themeColor="accent1"/></w:rPr><w:t>theme</w:t></w:r><w:r><w:rPr><w:color w:themeColor="dark1"/></w:rPr><w:t>system</w:t></w:r></w:p>
    let theme =
      #|<a:accent1><a:srgbClr val="4F81BD"/></a:accent1><a:dk1><a:sysClr val="windowText" lastClr="123456"/></a:dk1>
    debug_inspect(
      @docx2html.convert_to_html(color_document(body, theme~, strict~)).value,
      content=(
        #|"<p><span style=\"color: #4F81BD\">theme</span><span style=\"color: #123456\">system</span></p>"
      ),
    )
  }
}

///|
test "DOCX theme tint and shade modify luminance and tint wins" {
  let body =
    #|<w:p><w:r><w:rPr><w:color w:themeColor="accent1" w:themeTint="99"/></w:rPr><w:t>tint</w:t></w:r><w:r><w:rPr><w:color w:themeColor="accent2" w:themeShade="BF"/></w:rPr><w:t>shade</w:t></w:r><w:r><w:rPr><w:color w:themeColor="accent1" w:themeTint="99" w:themeShade="00"/></w:rPr><w:t>both</w:t></w:r></w:p>
  let theme =
    #|<a:accent1><a:srgbClr val="4F81BD"/></a:accent1><a:accent2><a:srgbClr val="C0504D"/></a:accent2>
  debug_inspect(
    @docx2html.convert_to_html(color_document(body, theme~)).value,
    content=(
      #|"<p><span style=\"color: #95B3D7\">tint</span><span style=\"color: #943734\">shade</span><span style=\"color: #95B3D7\">both</span></p>"
    ),
  )
}

///|
test "DOCX invalid colors do not become CSS and unresolved themes use RGB fallback" {
  let body =
    #|<w:p><w:r><w:rPr><w:color w:val="red; display:none"/></w:rPr><w:t>invalid</w:t></w:r><w:r><w:rPr><w:color w:val="123abc" w:themeColor="accent6"/></w:rPr><w:t>fallback</w:t></w:r></w:p>
  debug_inspect(
    @docx2html.convert_to_html(color_document(body)).value,
    content=(
      #|"<p>invalid<span style=\"color: #123ABC\">fallback</span></p>"
    ),
  )
}

///|
test "DOCX cyclic styles terminate and automatic default resets inherited color" {
  let styles =
    #|<w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:rPr><w:color w:val="ABCDEF"/></w:rPr></w:style>
    #|<w:style w:type="character" w:styleId="A"><w:basedOn w:val="B"/></w:style>
    #|<w:style w:type="character" w:styleId="B"><w:basedOn w:val="A"/></w:style>
  let body =
    #|<w:p><w:r><w:rPr><w:rStyle w:val="A"/></w:rPr><w:t>cycle</w:t></w:r><w:r><w:rPr><w:color w:val="auto"/></w:rPr><w:t>reset</w:t></w:r></w:p>
  debug_inspect(
    @docx2html.convert_to_html(color_document(body, styles~)).value,
    content=(
      #|"<p><span style=\"color: #ABCDEF\">cycle</span><span style=\"color: initial\">reset</span></p>"
    ),
  )
}

///|
test "DOCX color write and read preserve RGB and auto while Markdown stays plain" {
  let body = [
    @docx2html.paragraph([
      @docx2html.run(
        [@docx2html.text("red")],
        properties=@docx2html.run_properties(color=Some("C00000"), is_bold=true),
      ),
      @docx2html.run(
        [@docx2html.text("auto")],
        properties=@docx2html.run_properties(color=Some("auto")),
      ),
    ]),
  ]
  let bytes = @docx2html.write_docx(body)
  debug_inspect(
    @docx2html.convert_to_html(bytes).value,
    content=(
      #|"<p><strong><span style=\"color: #C00000\"><span style=\"font-size: 12pt\">red</span></span></strong><span style=\"color: initial\"><span style=\"font-size: 12pt\">auto</span></span></p>"
    ),
  )
  debug_inspect(
    @docx2html.convert(bytes, output_format=Markdown).value,
    content=(
      #|"__red__auto\n\n"
    ),
  )
}

///|
test "DOCX programmatic invalid color cannot inject CSS" {
  let body = @docx2html.document([
    @docx2html.paragraph([
      @docx2html.run(
        [@docx2html.text("safe")],
        properties=@docx2html.run_properties(color=Some("red; display:none")),
      ),
    ]),
  ])
  debug_inspect(
    @docx2html.convert_document_to_html(body).value,
    content="\"<p>safe</p>\"",
  )
}

///|
test "DOCX theme colors also resolve in inherited styles and identity transforms" {
  let styles =
    #|<w:style w:type="paragraph" w:styleId="Base"><w:rPr><w:color w:val="000000" w:themeColor="accent1" w:themeTint="FF"/></w:rPr></w:style>
    #|<w:style w:type="paragraph" w:styleId="Child"><w:basedOn w:val="Base"/></w:style>
  let theme =
    #|<a:accent1><a:srgbClr val="123456"/></a:accent1>
  let body =
    #|<w:p><w:pPr><w:pStyle w:val="Child"/></w:pPr><w:r><w:t>first</w:t></w:r></w:p><w:p><w:pPr><w:pStyle w:val="Child"/></w:pPr><w:r><w:t>cached</w:t></w:r></w:p>
  debug_inspect(
    @docx2html.convert_to_html(color_document(body, styles~, theme~)).value,
    content="\"<p><span style=\\\"color: #123456\\\">first</span></p><p><span style=\\\"color: #123456\\\">cached</span></p>\"",
  )
}

///|
test "DOCX invalid authored colors fail instead of being silently lost" {
  let body = [
    @docx2html.paragraph([
      @docx2html.run(
        [@docx2html.text("invalid")],
        properties=@docx2html.run_properties(color=Some("red")),
      ),
    ]),
  ]
  let rejected = try {
    ignore(@docx2html.write_docx(body))
    false
  } catch {
    Unsupported(..) => true
    _ => false
  }
  debug_inspect(rejected, content="true")
}

///|
test "DOCX color scheme mapping is simultaneous and precedes tint" {
  let settings =
    #|<w:clrSchemeMapping w:accent1="accent2" w:accent2="accent1" w:t1="accent2"/>
  let theme =
    #|<a:accent1><a:srgbClr val="FF0000"/></a:accent1><a:accent2><a:srgbClr val="0000FF"/></a:accent2>
  let body =
    #|<w:p><w:r><w:rPr><w:color w:themeColor="accent1"/></w:rPr><w:t>blue</w:t></w:r><w:r><w:rPr><w:color w:themeColor="accent2"/></w:rPr><w:t>red</w:t></w:r><w:r><w:rPr><w:color w:themeColor="text1" w:themeTint="00"/></w:rPr><w:t>white</w:t></w:r></w:p>
  debug_inspect(
    @docx2html.convert_to_html(color_document(body, settings~, theme~)).value,
    content="\"<p><span style=\\\"color: #0000FF\\\">blue</span><span style=\\\"color: #FF0000\\\">red</span><span style=\\\"color: #FFFFFF\\\">white</span></p>\"",
  )
}

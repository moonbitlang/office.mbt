///|
test "default HTML uses the closed Word highlight palette" {
  let names = [
    "black", "blue", "cyan", "green", "magenta", "red", "yellow", "white", "darkBlue",
    "darkCyan", "darkGreen", "darkMagenta", "darkRed", "darkYellow", "darkGray",
    "lightGray", "none", "banana", "red; color: black",
  ]
  let html = names.map(name => {
    @docx2html.convert_document_to_html(
      run_text(name, run_properties(highlight=Some(name))),
    ).value
  })
  debug_inspect(
    html,
    content=(
      #|[
      #|  "<span style=\"background-color: #000000\">black</span>",
      #|  "<span style=\"background-color: #0000FF\">blue</span>",
      #|  "<span style=\"background-color: #00FFFF\">cyan</span>",
      #|  "<span style=\"background-color: #00FF00\">green</span>",
      #|  "<span style=\"background-color: #FF00FF\">magenta</span>",
      #|  "<span style=\"background-color: #FF0000\">red</span>",
      #|  "<span style=\"background-color: #FFFF00\">yellow</span>",
      #|  "<span style=\"background-color: #FFFFFF\">white</span>",
      #|  "<span style=\"background-color: #000080\">darkBlue</span>",
      #|  "<span style=\"background-color: #008080\">darkCyan</span>",
      #|  "<span style=\"background-color: #008000\">darkGreen</span>",
      #|  "<span style=\"background-color: #800080\">darkMagenta</span>",
      #|  "<span style=\"background-color: #800000\">darkRed</span>",
      #|  "<span style=\"background-color: #808000\">darkYellow</span>",
      #|  "<span style=\"background-color: #808080\">darkGray</span>",
      #|  "<span style=\"background-color: #C0C0C0\">lightGray</span>",
      #|  "none",
      #|  "banana",
      #|  "red; color: black",
      #|]
    ),
  )
}

///|
test "highlight inherits per property and none cancels inherited highlighting" {
  let styles =
    #|<w:docDefaults><w:rPrDefault><w:rPr><w:highlight w:val="yellow"/></w:rPr></w:rPrDefault></w:docDefaults>
    #|<w:style w:type="paragraph" w:styleId="Base"><w:rPr><w:highlight w:val="green"/></w:rPr></w:style>
    #|<w:style w:type="paragraph" w:styleId="Body"><w:basedOn w:val="Base"/><w:rPr><w:color w:val="123456"/></w:rPr></w:style>
    #|<w:style w:type="character" w:styleId="Blue"><w:rPr><w:highlight w:val="cyan"/></w:rPr></w:style>
    #|<w:style w:type="character" w:styleId="Child"><w:basedOn w:val="Blue"/></w:style>
    #|<w:style w:type="character" w:styleId="Reset"><w:basedOn w:val="Blue"/><w:rPr><w:highlight w:val="none"/></w:rPr></w:style>
  let body =
    #|<w:p><w:r><w:t>default</w:t></w:r></w:p>
    #|<w:p><w:pPr><w:pStyle w:val="Body"/></w:pPr><w:r><w:t>paragraph</w:t></w:r><w:r><w:rPr><w:rStyle w:val="Child"/></w:rPr><w:t>character</w:t></w:r><w:r><w:rPr><w:rStyle w:val="Child"/><w:highlight w:val="red"/></w:rPr><w:t>direct</w:t></w:r><w:r><w:rPr><w:highlight w:val="none"/></w:rPr><w:t>reset</w:t></w:r><w:r><w:rPr><w:rStyle w:val="Reset"/></w:rPr><w:t>style reset</w:t></w:r></w:p>
    #|<w:p><w:r><w:t>default again</w:t></w:r></w:p>
  for strict in [false, true] {
    debug_inspect(
      @docx2html.convert_to_html(color_document(body, styles~, strict~)).value,
      content=(
        #|"<p><span style=\"background-color: #FFFF00\">default</span></p><p><span style=\"background-color: #00FF00\"><span style=\"color: #123456\">paragraph</span></span><span style=\"background-color: #00FFFF\"><span style=\"color: #123456\">character</span></span><span style=\"background-color: #FF0000\"><span style=\"color: #123456\">direct</span></span><span style=\"color: #123456\">resetstyle reset</span></p><p><span style=\"background-color: #FFFF00\">default again</span></p>"
      ),
    )
  }
}

///|
test "highlight cycles missing styles and default styles resolve deterministically" {
  let styles =
    #|<w:docDefaults><w:rPrDefault><w:rPr><w:highlight w:val="yellow"/></w:rPr></w:rPrDefault></w:docDefaults>
    #|<w:style w:type="paragraph" w:styleId="Default" w:default="1"><w:rPr><w:highlight w:val="green"/></w:rPr></w:style>
    #|<w:style w:type="character" w:styleId="A"><w:basedOn w:val="B"/></w:style>
    #|<w:style w:type="character" w:styleId="B"><w:basedOn w:val="A"/></w:style>
  let body =
    #|<w:p><w:r><w:rPr><w:rStyle w:val="A"/></w:rPr><w:t>cycle</w:t></w:r><w:r><w:rPr><w:rStyle w:val="B"/></w:rPr><w:t>cached</w:t></w:r></w:p>
    #|<w:p><w:pPr><w:pStyle w:val="Missing"/></w:pPr><w:r><w:t>missing</w:t></w:r></w:p>
  debug_inspect(
    @docx2html.convert_to_html(color_document(body, styles~)).value,
    content=(
      #|"<p><span style=\"background-color: #00FF00\">cyclecached</span></p><p><span style=\"background-color: #FFFF00\">missing</span></p>"
    ),
  )
}

///|
test "custom highlight mapping wins and none remains unhighlighted" {
  let body =
    #|<w:p><w:r><w:rPr><w:highlight w:val="yellow"/></w:rPr><w:t>custom</w:t></w:r><w:r><w:rPr><w:highlight w:val="none"/></w:rPr><w:t>reset</w:t></w:r><w:r><w:rPr><w:shd w:fill="FFFF00"/></w:rPr><w:t>shading</w:t></w:r></w:p>
  debug_inspect(
    @docx2html.convert_to_html(color_document(body), style_map=[
      "highlight => mark",
    ]).value,
    content=(
      #|"<p><mark>custom</mark>resetshading</p>"
    ),
  )
}

///|
test "explicit no highlight round trips" {
  let body = [
    @docx2html.paragraph([
      @docx2html.run(
        [@docx2html.text("reset")],
        properties=@docx2html.run_properties(highlight=Some("none")),
      ),
    ]),
  ]
  let bytes = @docx2html.write_docx(body)
  debug_inspect(
    @docx2html.read_docx(bytes) ==
    @docx2html.document(with_writer_font_defaults(body)),
    content=(
      #|true
    ),
  )
  debug_inspect(
    @docx2html.convert_to_html(bytes).value,
    content=(
      #|"<p><span style=\"font-size: 12pt\">reset</span></p>"
    ),
  )
}

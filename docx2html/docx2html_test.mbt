///|
test "result messages are deduplicated when combined" {
  let first = @docx2html.ConversionResult::{
    value: "a",
    messages: [Warning("same"), Warning("first")],
  }
  let second = @docx2html.ConversionResult::{
    value: "b",
    messages: [Warning("same"), Error("bad")],
  }
  debug_inspect(
    first.combine(second),
    content=(
      #|{
      #|  value: "ab",
      #|  messages: [Warning("same"), Warning("first"), Error("bad")],
      #|}
    ),
  )
}

///|
test "raw text recursively extracts text and tabs" {
  let element = @docx2html.document([
    @docx2html.paragraph([
      @docx2html.text("Hello"),
      @docx2html.tab(),
      @docx2html.run([@docx2html.text("world")]),
    ]),
    @docx2html.line_break(),
  ])
  inspect(element.to_raw_text(), content="Hello\tworld\n\n")
}

///|
test "html writer escapes text and attributes" {
  let attrs : Map[String, String] = { "title": "\"quoted\" & <tag>" }
  let nodes = [
    @docx2html.html_element("p", attributes=attrs, children=[
      @docx2html.html_text("A < B & C > D"),
    ]),
  ]
  inspect(
    @docx2html.write_html(nodes),
    content="<p title=\"&quot;quoted&quot; &amp; &lt;tag&gt;\">A &lt; B &amp; C &gt; D</p>",
  )
}

///|
test "markdown writer handles common inline elements" {
  let nodes = [
    @docx2html.html_element("p", children=[
      @docx2html.html_text("Hello "),
      @docx2html.html_element("strong", children=[@docx2html.html_text("bold")]),
      @docx2html.html_text(" and "),
      @docx2html.html_element("em", children=[@docx2html.html_text("em")]),
    ]),
  ]
  inspect(
    @docx2html.write_markdown(nodes),
    content="Hello __bold__ and *em*\n\n",
  )
}

///|
test "markdown writer emits links and images" {
  let link_attrs : Map[String, String] = { "href": "https://example.test" }
  let image_attrs : Map[String, String] = {
    "src": "data:image/png;base64,abc",
    "alt": "tiny",
  }
  let nodes = [
    @docx2html.html_element("p", children=[
      @docx2html.html_element("a", attributes=link_attrs, children=[
        @docx2html.html_text("link"),
      ]),
      @docx2html.html_text(" "),
      @docx2html.html_element("img", attributes=image_attrs),
    ]),
  ]
  inspect(
    @docx2html.write_markdown(nodes),
    content="[link](https://example.test) ![tiny](data:image/png;base64,abc)\n\n",
  )
}

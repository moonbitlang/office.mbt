///|
test "result messages are deduplicated when combined" {
  let first = @docx2html.ConversionResult::{
    value: "a",
    messages: [@docx2html.warning("same"), @docx2html.warning("first")],
  }
  let second = @docx2html.ConversionResult::{
    value: "b",
    messages: [@docx2html.warning("same"), @docx2html.error("bad")],
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
  debug_inspect(
    @docx2html.combine_results([
      first,
      second,
      {
        value: "c",
        messages: [@docx2html.error("bad"), @docx2html.warning("last")],
      },
    ]),
    content=(
      #|{
      #|  value: "abc",
      #|  messages: [Warning("same"), Warning("first"), Error("bad"), Warning("last")],
      #|}
    ),
  )
  debug_inspect(
    @docx2html.combine_results([]),
    content="{ value: \"\", messages: [] }",
  )
}

///|
test "conversion defaults and result mapping preserve messages" {
  inspect(
    @docx2html.convert_document_to_html(@docx2html.paragraph([])).value,
    content="",
  )
  inspect(@docx2html.default_style_map_lines().length() > 0, content="true")
  let result = @docx2html.ConversionResult::{
    value: "walking",
    messages: [@docx2html.warning("same")],
  }
  debug_inspect(
    result.map(fn(value) { value + " on imported air" }),
    content="{ value: \"walking on imported air\", messages: [Warning(\"same\")] }",
  )
  debug_inspect(
    result.flat_map(fn(value) {
      {
        value: value + " home",
        messages: [@docx2html.warning("same"), @docx2html.error("late")],
      }
    }),
    content="{ value: \"walking home\", messages: [Warning(\"same\"), Error(\"late\")] }",
  )
}

///|
test "generic document conversion selects typed output format" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Hello.")]),
  ])
  inspect(@docx2html.convert_document(doc).value, content="<p>Hello.</p>")
  inspect(
    @docx2html.convert_document(doc, output_format=Markdown).value,
    content="Hello\\.\n\n",
  )
  inspect(
    @docx2html.convert_document(doc, output_format=Html, pretty_print=true).value,
    content="<p>\n  Hello.\n</p>",
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
test "raw text converts individual upstream element cases" {
  inspect(@docx2html.text("Hello.").to_raw_text(), content="Hello.")
  inspect(@docx2html.tab().to_raw_text(), content="\t")
  inspect(@docx2html.line_break().to_raw_text(), content="")
  inspect(
    @docx2html.Hyperlink(
      children=[@docx2html.text("linked")],
      href=Some("http://example.com"),
      anchor=None,
      target_frame=None,
    ).to_raw_text(),
    content="linked",
  )
}

///|
test "raw text terminates paragraphs with blank lines" {
  let element = @docx2html.paragraph([
    @docx2html.text("Hello "),
    @docx2html.text("world."),
  ])
  inspect(element.to_raw_text(), content="Hello world.\n\n")
}

///|
test "raw text and descendants recurse through table nodes" {
  let table = @docx2html.Table(
    children=[
      TableRow(
        children=[
          TableCell(
            children=[@docx2html.paragraph([@docx2html.text("Cell")])],
            col_span=1,
            row_span=1,
          ),
        ],
        is_header=false,
      ),
    ],
    properties=@docx2html.TableProperties::default(),
  )
  inspect(table.to_raw_text(), content="Cell\n\n")
  inspect(@docx2html.document_descendants(table).length(), content="4")
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
  inspect(@docx2html.write_html([@docx2html.html_text("\"")]), content="\"")
}

///|
test "pretty html writer follows Mammoth indentation rules" {
  inspect(
    @docx2html.write_html(
      [
        @docx2html.html_element("p", children=[
          @docx2html.html_text("One"),
          @docx2html.html_element("em", children=[@docx2html.html_text("Two")]),
        ]),
      ],
      pretty_print=true,
    ),
    content="<p>\n  One<em>Two</em>\n</p>",
  )
  inspect(
    @docx2html.write_html(
      [
        @docx2html.html_element("ul", children=[
          @docx2html.html_element("li", children=[@docx2html.html_text("One")]),
          @docx2html.html_element("li", children=[@docx2html.html_text("Two")]),
        ]),
      ],
      pretty_print=true,
    ),
    content="<ul>\n  <li>\n    One\n  </li>\n  <li>\n    Two\n  </li>\n</ul>",
  )
  inspect(
    @docx2html.write_html(
      [
        @docx2html.html_element("pre", children=[
          @docx2html.html_text("One\nTwo"),
        ]),
      ],
      pretty_print=true,
    ),
    content="<pre>One\nTwo</pre>",
  )
  inspect(
    @docx2html.write_html(
      [
        @docx2html.html_element("pre", children=[
          @docx2html.html_element("p", children=[
            @docx2html.html_text("One\nTwo"),
          ]),
        ]),
      ],
      pretty_print=true,
    ),
    content="<pre><p>One\nTwo</p></pre>",
  )
  inspect(
    @docx2html.write_html(
      [
        @docx2html.html_element("p", children=[@docx2html.html_text("One\nTwo")]),
      ],
      pretty_print=true,
    ),
    content="<p>\n  One\n  Two\n</p>",
  )
  inspect(
    @docx2html.write_html(
      [
        @docx2html.html_element("p", children=[
          @docx2html.html_text("One"),
          @docx2html.html_text("Two"),
        ]),
      ],
      pretty_print=true,
    ),
    content="<p>\n  OneTwo\n</p>",
  )
  inspect(
    @docx2html.write_html(
      [@docx2html.html_element("p", children=[@docx2html.html_element("br")])],
      pretty_print=true,
    ),
    content="<p>\n  <br />\n</p>",
  )
  inspect(
    @docx2html.write_html(
      [
        @docx2html.html_element("div", children=[
          @docx2html.html_element("div", children=[
            @docx2html.html_element("div", children=[
              @docx2html.html_text("Hello"),
            ]),
          ]),
        ]),
      ],
      pretty_print=true,
    ),
    content="<div>\n  <div>\n    <div>\n      Hello\n    </div>\n  </div>\n</div>",
  )
  inspect(
    @docx2html.write_html(
      [@docx2html.html_element("br"), @docx2html.html_text("After")],
      pretty_print=true,
    ),
    content="<br />\nAfter",
  )
  inspect(
    @docx2html.write_html(
      [@docx2html.html_text("After\n\n")],
      pretty_print=true,
    ),
    content="After\n  ",
  )
  inspect(
    @docx2html.write_html([
      @docx2html.html_element("input", attributes={
        "z": "1",
        "disabled": "disabled",
        "checked": "checked",
      }),
    ]),
    content="<input checked=\"checked\" disabled=\"disabled\" z=\"1\" />",
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
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("blah", children=[@docx2html.html_text("Hello")]),
    ]),
    content="Hello",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("a", children=[@docx2html.html_text("Hello")]),
    ]),
    content="Hello",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("p", children=[
        @docx2html.html_text("Hello "),
        @docx2html.html_element("strong", children=[
          @docx2html.html_text("ipsum "),
          @docx2html.html_element("em", children=[@docx2html.html_text("dolor")]),
        ]),
      ]),
    ]),
    content="Hello __ipsum *dolor*__\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("p", children=[
        @docx2html.html_text("Lorem "),
        @docx2html.html_element("strong", children=[
          @docx2html.html_text("ipsum "),
          @docx2html.html_element("em", children=[@docx2html.html_text("dolor")]),
          @docx2html.html_text(" sit"),
        ]),
        @docx2html.html_text(" amet"),
      ]),
    ]),
    content="Lorem __ipsum *dolor* sit__ amet\n\n",
  )
}

///|
test "markdown writer escapes text and handles breaks and headings" {
  inspect(
    @docx2html.escape_markdown_text("\\`*_{}[]()#+-.!"),
    content=(
      #|\\\`\*\_\{\}\[\]\(\)\#\+\-\.\!
    ),
  )
  inspect(
    @docx2html.write_markdown([@docx2html.html_text("\\*")]),
    content="\\\\\\*",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_text("Hello World"),
      @docx2html.html_element("br"),
    ]),
    content="Hello World  \n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("h1", children=[@docx2html.html_text("Hello")]),
    ]),
    content="# Hello\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("h6", children=[@docx2html.html_text("Hello")]),
    ]),
    content="###### Hello\n\n",
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

///|
test "markdown writer follows Mammoth image edge cases" {
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("img", attributes={
        "src": "http://example.com/image.jpg",
      }),
    ]),
    content="![](http://example.com/image.jpg)",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("img", attributes={ "alt": "Alt Text" }),
    ]),
    content="![Alt Text]()",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("img", attributes={
        "src": "http://example.com/image.jpg",
        "alt": "A*B",
      }),
    ]),
    content="![A*B](http://example.com/image.jpg)",
  )
  inspect(
    @docx2html.write_markdown([@docx2html.html_element("img")]),
    content="",
  )
}

///|
test "markdown writer preserves element ids as anchors" {
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("h1", attributes={ "id": "start" }, children=[
        @docx2html.html_text("Hello"),
      ]),
    ]),
    content="# <a id=\"start\"></a>Hello\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("h1", attributes={ "id": "a&\"b" }, children=[
        @docx2html.html_text("Hello"),
      ]),
    ]),
    content="# <a id=\"a&\"b\"></a>Hello\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element(
        "a",
        attributes={ "href": "http://example.com", "id": "start" },
        children=[@docx2html.html_text("Hello")],
      ),
    ]),
    content="<a id=\"start\"></a>[Hello](http://example.com)",
  )
}

///|
test "markdown writer follows Mammoth list rules" {
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("li", children=[@docx2html.html_text("Hello")]),
    ]),
    content="- Hello\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("li", attributes={ "id": "item-1" }, children=[
        @docx2html.html_text("Hello"),
      ]),
    ]),
    content="- <a id=\"item-1\"></a>Hello\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("ol", children=[
        @docx2html.html_element("li", children=[@docx2html.html_text("Hello")]),
        @docx2html.html_element("li", children=[@docx2html.html_text("World")]),
      ]),
    ]),
    content="1. Hello\n2. World\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("ol", children=[
        @docx2html.html_element("li", children=[
          @docx2html.html_text("Outer One"),
          @docx2html.html_element("ol", children=[
            @docx2html.html_element("li", children=[
              @docx2html.html_text("Nested One"),
            ]),
            @docx2html.html_element("li", children=[
              @docx2html.html_text("Nested Two"),
            ]),
          ]),
        ]),
        @docx2html.html_element("li", children=[
          @docx2html.html_text("Outer Two"),
        ]),
      ]),
    ]),
    content="1. Outer One\n\t1. Nested One\n\t2. Nested Two\n2. Outer Two\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("ul", children=[
        @docx2html.html_element("li", children=[
          @docx2html.html_text("Outer One"),
          @docx2html.html_element("ul", children=[
            @docx2html.html_element("li", children=[
              @docx2html.html_text("Nested One"),
            ]),
            @docx2html.html_element("li", children=[
              @docx2html.html_text("Nested Two"),
            ]),
          ]),
        ]),
        @docx2html.html_element("li", children=[
          @docx2html.html_text("Outer Two"),
        ]),
      ]),
    ]),
    content="- Outer One\n\t- Nested One\n\t- Nested Two\n- Outer Two\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("ol", children=[
        @docx2html.html_element("li", children=[
          @docx2html.html_text("Outer One"),
          @docx2html.html_element("ol", children=[
            @docx2html.html_element("li", children=[
              @docx2html.html_text("Nested One"),
              @docx2html.html_element("ol", children=[
                @docx2html.html_element("li", children=[
                  @docx2html.html_text("Inner One"),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
    ]),
    content="1. Outer One\n\t1. Nested One\n\t\t1. Inner One\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("ol", children=[
        @docx2html.html_element("li", children=[
          @docx2html.html_text("Hello "),
          @docx2html.html_element("strong", children=[
            @docx2html.html_text("Strong"),
          ]),
          @docx2html.html_text(" World"),
        ]),
        @docx2html.html_element("li", children=[
          @docx2html.html_text("Hello "),
          @docx2html.html_element("em", children=[
            @docx2html.html_text("Emphasis"),
          ]),
          @docx2html.html_text(" World"),
        ]),
      ]),
    ]),
    content="1. Hello __Strong__ World\n2. Hello *Emphasis* World\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("p", children=[
        @docx2html.html_text("Hello World"),
      ]),
      @docx2html.html_element("ul", children=[
        @docx2html.html_element("li", children=[
          @docx2html.html_text("First Item"),
        ]),
        @docx2html.html_element("li", children=[
          @docx2html.html_text("Second Item"),
        ]),
      ]),
      @docx2html.html_element("p", children=[
        @docx2html.html_text("Hello World"),
      ]),
    ]),
    content="Hello World\n\n- First Item\n- Second Item\n\nHello World\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("ol", children=[
        @docx2html.html_element("li", children=[@docx2html.html_text("First")]),
      ]),
      @docx2html.html_element("p", children=[@docx2html.html_text("Hello")]),
      @docx2html.html_element("ol", children=[
        @docx2html.html_element("li", children=[@docx2html.html_text("Second")]),
      ]),
    ]),
    content="1. First\n\nHello\n\n1. Second\n\n",
  )
  inspect(
    @docx2html.write_markdown([
      @docx2html.html_element("ul", children=[
        @docx2html.html_text("Intro"),
        @docx2html.html_element("li", children=[@docx2html.html_text("Item")]),
      ]),
    ]),
    content="Intro- Item\n\n",
  )
}

///|
test "document markdown conversion uses style maps" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.run([@docx2html.text("marked")])]),
  ])
  inspect(
    @docx2html.convert_document_to_markdown(doc, style_map=["r => strong"]).value,
    content="__marked__\n\n",
  )
}

///|
test "document markdown conversion honors common converter options" {
  let heading = @docx2html.document([
    @docx2html.paragraph(
      [@docx2html.text("Title")],
      properties=@docx2html.paragraph_properties(
        style_id=Some("Heading1"),
        style_name=Some("Heading 1"),
      ),
    ),
  ])
  let default_heading = @docx2html.convert_document_to_markdown(heading)
  inspect(default_heading.value, content="# Title\n\n")
  debug_inspect(default_heading.messages, content="[]")
  let without_default_style_map = @docx2html.convert_document_to_markdown(
    heading,
    include_default_style_map=false,
  )
  inspect(without_default_style_map.value, content="Title\n\n")
  debug_inspect(
    without_default_style_map.messages,
    content=(
      #|[Warning("Unrecognised paragraph style: 'Heading 1' (Style ID: Heading1)")]
    ),
  )
  inspect(
    @docx2html.convert_document_to_markdown(
      @docx2html.paragraph([]),
      ignore_empty_paragraphs=false,
    ).value,
    content="\n\n",
  )
  inspect(
    @docx2html.convert_document_to_markdown(
      NoteReference(note_type="footnote", note_id="4"),
      id_prefix="doc-42-",
    ).value,
    content="<a id=\"doc-42-footnote-ref-4\"></a>[\\[1\\]](#doc-42-footnote-4)",
  )
}

///|
test "document markdown conversion renders images comments and diagnostics" {
  let image = @docx2html.Image::{
    content_type: "image/png",
    alt_text: Some("chart"),
    data: b"abc",
  }
  inspect(
    @docx2html.convert_document_to_markdown(
      @docx2html.paragraph([Image(image)]),
    ).value,
    content="![chart](data:image/png;base64,YWJj)\n\n",
  )
  let convert_image = fn(_image : @docx2html.Image) {
    @docx2html.image_conversion(
      [@docx2html.html_element("img", attributes={ "src": "custom:image/png" })],
      messages=[Warning("custom markdown image warning")],
    )
  }
  let custom_image = @docx2html.convert_document_to_markdown(
    @docx2html.paragraph([Image(image)]),
    convert_image~,
  )
  inspect(custom_image.value, content="![](custom:image/png)\n\n")
  debug_inspect(
    custom_image.messages,
    content="[Warning(\"custom markdown image warning\")]",
  )
  let comment = @docx2html.Comment::{
    comment_id: "4",
    body: [@docx2html.paragraph([@docx2html.text("Who's there?")])],
    author_name: "The Piemaker",
    author_initials: "TP",
  }
  let doc = @docx2html.document(
    [
      @docx2html.paragraph([
        @docx2html.text("Knock knock"),
        CommentReference("4"),
      ]),
    ],
    comments=[comment],
  )
  let markdown = @docx2html.convert_document_to_markdown(
    doc,
    style_map=["comment-reference => sup"],
    id_prefix="doc-42-",
  )
  inspect(
    markdown.value,
    content=(
      #|Knock knock<a id="doc-42-comment-ref-4"></a>[\[TP1\]](#doc-42-comment-4)
      #|
      #|<a id="doc-42-comment-4"></a>Comment \[TP1\]Who's there? [↑](#doc-42-comment-ref-4)
      #|
      #|
    ),
  )
  debug_inspect(markdown.messages, content="[]")
}

///|
test "document converter maps paragraphs and escapes text" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("A < B")]),
  ])
  let result = @docx2html.convert_document_to_html(doc)
  inspect(result.value, content="<p>A &lt; B</p>")
  debug_inspect(result.messages, content="[]")
}

///|
test "document converter handles long documents without stack growth" {
  let paragraphs : Array[@docx2html.DocumentElement] = []
  let expected = StringBuilder()
  for _ in 0..<1000 {
    paragraphs.push(@docx2html.paragraph([@docx2html.text("Hello.")]))
    expected.write_string("<p>Hello.</p>")
  }
  assert_eq(
    @docx2html.convert_document_to_html(@docx2html.document(paragraphs)).value,
    expected.to_string(),
  )
}

///|
test "document transforms are applied before conversion" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Hello.")]),
  ])
  let transform_document = @docx2html.transform_paragraphs(fn(_paragraph) {
    @docx2html.paragraph([@docx2html.text("Goodbye.")])
  })
  inspect(
    @docx2html.convert_document_to_html(doc, transform_document~).value,
    content="<p>Goodbye.</p>",
  )
}

///|
test "document transforms are applied before markdown conversion" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Hello.")]),
  ])
  let transform_document = @docx2html.transform_paragraphs(fn(_paragraph) {
    @docx2html.paragraph([@docx2html.text("Goodbye.")])
  })
  inspect(
    @docx2html.convert_document_to_markdown(doc, transform_document~).value,
    content="Goodbye\\.\n\n",
  )
}

///|
test "document transform type helpers leave non-matching roots unchanged" {
  let run = @docx2html.run([])
  let paragraph_transform = @docx2html.transform_paragraphs(fn(_) {
    @docx2html.tab()
  })
  inspect(paragraph_transform(run).to_raw_text(), content="")
  let paragraph = @docx2html.paragraph([])
  let run_transform = @docx2html.transform_runs(fn(_) { @docx2html.tab() })
  inspect(run_transform(paragraph).to_raw_text(), content="\n\n")
}

///|
test "document transform helpers follow Mammoth post-order traversal" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.run([@docx2html.text("x")])]),
  ])
  let mut count = 0
  let transformed = @docx2html.transform_elements(doc, fn(element) {
    count = count + 1
    match element {
      Text(value) => @docx2html.text(value + count.to_string())
      Run(children~, properties~) =>
        Run(
          children=children + [@docx2html.text("r" + count.to_string())],
          properties~,
        )
      Paragraph(children~, properties~) =>
        Paragraph(
          children=children + [@docx2html.text("p" + count.to_string())],
          properties~,
        )
      Document(children~, notes~, comments~) =>
        Document(
          children=children + [@docx2html.text("d" + count.to_string())],
          notes~,
          comments~,
        )
      _ => element
    }
  })
  inspect(transformed.to_raw_text(), content="x1r2p3\n\nd4")
}

///|
test "document transform helpers can target runs and descendants" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.run([@docx2html.text("Hello")])]),
  ])
  let transform_document = @docx2html.transform_runs(fn(_run) {
    @docx2html.run([@docx2html.text("Run")])
  })
  inspect(
    @docx2html.convert_document_to_html(doc, transform_document~).value,
    content="<p>Run</p>",
  )
  let runs = @docx2html.document_descendants_where(doc, fn(element) {
    element is Run(..)
  })
  inspect(runs.length(), content="1")
  inspect(
    @docx2html.document_descendants(@docx2html.text("leaf")).length(),
    content="0",
  )
}

///|
test "document descendants can be filtered like Mammoth getDescendantsOfType" {
  let doc = @docx2html.document([
    @docx2html.paragraph([
      @docx2html.run([@docx2html.text("first")]),
      @docx2html.hyperlink(
        [@docx2html.run([@docx2html.text("linked")])],
        href=Some("https://example.test"),
      ),
    ]),
    @docx2html.paragraph([@docx2html.text("second")]),
  ])
  let runs = @docx2html.document_descendants_where(doc, fn(element) {
    element is Run(..)
  })
  inspect(runs.length(), content="2")
  inspect(@docx2html.document(runs).to_raw_text(), content="firstlinked")
  let paragraphs = @docx2html.document_descendants_where(doc, fn(element) {
    element is Paragraph(..)
  })
  inspect(paragraphs.length(), content="2")
  inspect(
    @docx2html.document(paragraphs).to_raw_text(),
    content="firstlinked\n\nsecond\n\n",
  )
}

///|
test "document transforms recurse through hyperlinks and tables" {
  let link = @docx2html.Hyperlink(
    children=[@docx2html.text("Link")],
    href=Some("http://example.com"),
    anchor=None,
    target_frame=None,
  )
  let table = @docx2html.Table(
    children=[
      TableRow(
        children=[
          TableCell(children=[@docx2html.text("Cell")], col_span=1, row_span=1),
        ],
        is_header=false,
      ),
    ],
    properties=@docx2html.TableProperties::default(),
  )
  let doc = @docx2html.document([link, table])
  let transformed = @docx2html.transform_elements(doc, fn(element) {
    match element {
      Text(value) => @docx2html.text(value + "!")
      _ => element
    }
  })
  inspect(
    @docx2html.convert_document_to_html(transformed).value,
    content="<a href=\"http://example.com\">Link!</a><table><tr><td>Cell!</td></tr></table>",
  )
  inspect(@docx2html.document_descendants(link).length(), content="1")
}

///|
test "document converter ignores empty paragraphs by default" {
  let doc = @docx2html.document([@docx2html.paragraph([])])
  inspect(@docx2html.convert_document_to_html(doc).value, content="")
  inspect(
    @docx2html.convert_document_to_html(doc, ignore_empty_paragraphs=false).value,
    content="<p></p>",
  )
}

///|
test "document converter uses style mappings before defaults" {
  let properties = @docx2html.ParagraphProperties::{
    style_id: Some("Heading1"),
    style_name: None,
    numbering: None,
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Title")], properties~),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc).value,
    content="<h1>Title</h1>",
  )
  inspect(
    @docx2html.convert_document_to_html(doc, style_map=["p.Heading1 => h2"]).value,
    content="<h2>Title</h2>",
  )
}

///|
test "style map html paths preserve classes and attributes" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Hello.")]),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc, style_map=[
      "p => div.aside.note[lang='fr'] > h2:fresh",
    ]).value,
    content="<div class=\"aside note\" lang=\"fr\"><h2>Hello.</h2></div>",
  )
  inspect(
    @docx2html.convert_document_to_html(doc, style_map=["p => p.a\\:b"]).value,
    content="<p class=\"a:b\">Hello.</p>",
  )
}

///|
test "style map bang html path ignores matched content" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Ignored")]),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc, style_map=["p => !"]).value,
    content="",
  )
}

///|
fn expect_style_mapping(line : String) -> @docx2html.StyleMapping {
  match @docx2html.read_style_mapping(line) {
    Some(mapping) => mapping
    None => abort("expected style mapping")
  }
}

///|
test "style map parser reads upstream html path forms" {
  let path_mapping = expect_style_mapping(
    "p => div.tip.help[lang='fr'][data-x='y']:fresh",
  )
  match path_mapping.from {
    ParagraphMatcher(style_id=None, style_name=None, numbering=None) => ()
    _ => fail("expected plain paragraph matcher")
  }
  let path = path_mapping.to[0]
  inspect(path.tag, content="div")
  inspect(path.attributes.get_or_default("class", ""), content="tip help")
  inspect(path.attributes.get_or_default("lang", ""), content="fr")
  inspect(path.attributes.get_or_default("data-x", ""), content="y")
  debug_inspect(path.fresh, content="true")
  let choice = expect_style_mapping("p => ul|ol > li")
  inspect(choice.to[0].tag, content="ul|ol")
  inspect(choice.to[1].tag, content="li")
  debug_inspect(expect_style_mapping("r =>").to, content="[]")
  debug_inspect(expect_style_mapping("r =>   ").to, content="[]")
  let separator = expect_style_mapping("p => p:separator('\\r\\n\\t\\'\\\\')").to[0].separator
  inspect(separator.unwrap(), content="\r\n\t'\\")
  inspect(expect_style_mapping("p => \\:x").to[0].tag, content=":x")
}

///|
test "style map parser reads upstream document matcher forms" {
  match expect_style_mapping("p.Heading1 => h1").from {
    ParagraphMatcher(style_id=Some("Heading1"), style_name=None, numbering=None) =>
      ()
    _ => fail("expected paragraph style ID matcher")
  }
  match expect_style_mapping("p[style-name^='Heading'] => h1").from {
    ParagraphMatcher(
      style_id=None,
      style_name=Some(PrefixStyleName("Heading")),
      numbering=None
    ) => ()
    _ => fail("expected paragraph style-name prefix matcher")
  }
  match expect_style_mapping("p:ordered-list(1) => ol > li").from {
    ParagraphMatcher(numbering=Some(numbering), ..) =>
      debug_inspect(numbering, content="{ is_ordered: true, level: 1 }")
    _ => fail("expected ordered list matcher")
  }
  match expect_style_mapping("r => span").from {
    RunMatcher(style_id=None, style_name=None) => ()
    _ => fail("expected plain run matcher")
  }
  match expect_style_mapping("r.Emphasis => em").from {
    RunMatcher(style_id=Some("Emphasis"), style_name=None) => ()
    _ => fail("expected run style ID matcher")
  }
  match expect_style_mapping("r[style-name='Code'] => code").from {
    RunMatcher(style_id=None, style_name=Some(ExactStyleName("Code"))) => ()
    _ => fail("expected run style-name matcher")
  }
  match expect_style_mapping("table => table").from {
    TableMatcher(style_id=None, style_name=None) => ()
    _ => fail("expected plain table matcher")
  }
  match expect_style_mapping("table.TableNormal => table").from {
    TableMatcher(style_id=Some("TableNormal"), style_name=None) => ()
    _ => fail("expected table style ID matcher")
  }
  match expect_style_mapping("table[style-name='Normal Table'] => table").from {
    TableMatcher(style_id=None, style_name=Some(ExactStyleName("Normal Table"))) =>
      ()
    _ => fail("expected table style-name matcher")
  }
  match expect_style_mapping("b => strong").from {
    RunPropertyMatcher("bold") => ()
    _ => fail("expected bold matcher")
  }
  match expect_style_mapping("i => em").from {
    RunPropertyMatcher("italic") => ()
    _ => fail("expected italic matcher")
  }
  match expect_style_mapping("u => span.underline").from {
    RunPropertyMatcher("underline") => ()
    _ => fail("expected underline matcher")
  }
  match expect_style_mapping("strike => s").from {
    RunPropertyMatcher("strikethrough") => ()
    _ => fail("expected strikethrough matcher")
  }
  match expect_style_mapping("all-caps => span").from {
    RunPropertyMatcher("allCaps") => ()
    _ => fail("expected all-caps matcher")
  }
  match expect_style_mapping("small-caps => span").from {
    RunPropertyMatcher("smallCaps") => ()
    _ => fail("expected small-caps matcher")
  }
  match expect_style_mapping("highlight => mark").from {
    HighlightMatcher(None) => ()
    _ => fail("expected highlight matcher")
  }
  match expect_style_mapping("highlight[color='yellow'] => mark").from {
    HighlightMatcher(Some("yellow")) => ()
    _ => fail("expected highlight color matcher")
  }
  match expect_style_mapping("comment-reference => sup").from {
    CommentReferenceMatcher => ()
    _ => fail("expected comment reference matcher")
  }
  match expect_style_mapping("br[type='line'] => br").from {
    BreakMatcher(Line) => ()
    _ => fail("expected line break matcher")
  }
  match expect_style_mapping("br[type='page'] => hr").from {
    BreakMatcher(Page) => ()
    _ => fail("expected page break matcher")
  }
  match expect_style_mapping("br[type='column'] => span").from {
    BreakMatcher(Column) => ()
    _ => fail("expected column break matcher")
  }
}

///|
test "style map parser handles malformed and escaped edge cases" {
  debug_inspect(@docx2html.read_style_mapping("wat => p"), content="None")
  debug_inspect(@docx2html.read_style_mapping(" => p"), content="None")
  debug_inspect(@docx2html.read_style_mapping("p=> h1"), content="None")
  debug_inspect(@docx2html.read_style_mapping("p =>h1"), content="None")
  match expect_style_mapping("p.Heading[style-name='Title'] => h1").from {
    ParagraphMatcher(
      style_id=Some("Heading"),
      style_name=Some(_),
      numbering=None
    ) => ()
    _ => fail("expected paragraph style ID before attributes")
  }
  debug_inspect(
    @docx2html.read_style_mapping("highlight[color='yellow] => mark"),
    content="None",
  )
  debug_inspect(
    @docx2html.read_style_mapping("p[style-name^='Heading] => h1"),
    content="None",
  )
  debug_inspect(
    @docx2html.read_style_mapping("p:ordered-list(x) => ol > li"),
    content="None",
  )
  debug_inspect(
    @docx2html.read_style_mapping("p:ordered-list(2 => ol > li"),
    content="None",
  )
  match
    expect_style_mapping("p:ordered-list(2):unordered-list(3) => ul > li").from {
    ParagraphMatcher(numbering=Some({ is_ordered: false, level: 3 }), ..) => ()
    _ => fail("expected later list suffix to win")
  }
  inspect(@docx2html.read_style_map(["p => span "]).length(), content="0")
  let separator = expect_style_mapping("p => span:separator('---')").to[0].separator
  inspect(separator.unwrap(), content="---")
  let fresh_separator = expect_style_mapping("p => span:fresh:separator('x')").to[0]
  inspect(fresh_separator.separator.unwrap(), content="x")
  debug_inspect(fresh_separator.fresh, content="true")
  let escaped_attr = expect_style_mapping("p => span[data-x='a\\'b']").to[0]
  inspect(escaped_attr.attributes.get_or_default("data-x", ""), content="a'b")
  let attr_with_delimiters = expect_style_mapping("p => span[data-x='a>b:c']").to[0]
  inspect(
    attr_with_delimiters.attributes.get_or_default("data-x", ""),
    content="a>b:c",
  )
  let separator_with_delimiters = expect_style_mapping(
      "p => pre:separator('a>b:c')",
    ).to[0]
  inspect(separator_with_delimiters.separator.unwrap(), content="a>b:c")
  let escaped_attr_name = expect_style_mapping("p => span[data\\:x='a\\:b']").to[0]
  inspect(
    escaped_attr_name.attributes.get_or_default("data:x", ""),
    content="a:b",
  )
  debug_inspect(
    @docx2html.read_style_mapping("p => span[data-x='a'.tail]"),
    content="None",
  )
  debug_inspect(
    @docx2html.read_style_mapping("p => span[data-x='abc"),
    content="None",
  )
  debug_inspect(
    @docx2html.read_style_mapping("p => span[data-x]"),
    content="None",
  )
  debug_inspect(
    @docx2html.read_style_mapping("p => span[data-x='a']#"),
    content="None",
  )
  debug_inspect(
    @docx2html.read_style_mapping("p => span:separator('x'):fresh"),
    content="None",
  )
  debug_inspect(@docx2html.read_style_mapping("p => ul>li"), content="None")
  inspect(expect_style_mapping("p => x\\:y").to[0].tag, content="x:y")
}

///|
test "style map string reader follows Mammoth option rules" {
  debug_inspect(
    @docx2html.read_style_map_string(
      "\n# p.SectionTitle => h3\n  # p.SectionTitle => h4\n  p.SectionTitle => h2  \n\n",
    ),
    content="[\"p.SectionTitle => h2\"]",
  )
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Title")], properties={
      style_id: Some("Heading1"),
      style_name: None,
      numbering: None,
      alignment: None,
      indent: @docx2html.Indent::default(),
    }),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc).value,
    content="<h1>Title</h1>",
  )
  inspect(
    @docx2html.convert_document_to_html(doc, style_map=["p.Heading1 => h2"]).value,
    content="<h2>Title</h2>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      doc,
      style_map=@docx2html.read_style_map_string("p.Heading1 => h3"),
    ).value,
    content="<h3>Title</h3>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      doc,
      style_map=["p.Heading1 => h2"],
      include_default_style_map=false,
    ).value,
    content="<h2>Title</h2>",
  )
}

///|
test "style map parser exposes Mammoth diagnostics for preflight validation" {
  let parsed = @docx2html.parse_style_map([
    "p.Heading1 => h1", "????", "r => strong",
  ])
  inspect(parsed.mappings.length(), content="2")
  match parsed.mappings[0].from {
    ParagraphMatcher(style_id=Some("Heading1"), style_name=None, numbering=None) =>
      ()
    _ => fail("expected paragraph style mapping")
  }
  match parsed.mappings[1].from {
    RunMatcher(style_id=None, style_name=None) => ()
    _ => fail("expected run mapping")
  }
  debug_inspect(
    parsed.messages,
    content=(
      #|[Warning("Did not understand this style mapping, so ignored it: ????\nError was at character number 1: Expected element type but got unrecognisedCharacter \"?\"")]
    ),
  )
  let parsed_string = @docx2html.parse_style_map_string(
    "\n# ignored\np.SectionTitle => h2\np => span#\n",
  )
  inspect(parsed_string.mappings.length(), content="1")
  debug_inspect(
    parsed_string.messages,
    content=(
      #|[Warning("Did not understand this style mapping, so ignored it: p => span#\nError was at character number 10: Expected end but got unrecognisedCharacter \"#\"")]
    ),
  )
}

///|
test "style map separator is inserted only when html elements collapse" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("One")]),
    @docx2html.paragraph([@docx2html.text("Two")]),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc, style_map=[
      "p => pre:separator('\\n')",
    ]).value,
    content="<pre>One\nTwo</pre>",
  )
}

///|
test "html path matching follows Mammoth tag choice and attribute rules" {
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.html_element("ol", children=[@docx2html.html_text("One")]),
        @docx2html.html_element("ul|ol", children=[@docx2html.html_text("Two")]),
      ]),
    ),
    content="<ol>OneTwo</ol>",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.html_element("p", attributes={ "class": "tip" }, children=[
          @docx2html.html_text("One"),
        ]),
        @docx2html.html_element("p", attributes={ "class": "tip help" }, children=[
          @docx2html.html_text("Two"),
        ]),
        @docx2html.html_element("p", attributes={ "class": "tip help" }, children=[
          @docx2html.html_text("Three"),
        ]),
      ]),
    ),
    content="<p class=\"tip\">One</p><p class=\"tip help\">TwoThree</p>",
  )
}

///|
test "default nested list mappings collapse across orderedness" {
  let unordered_parent = @docx2html.ParagraphProperties::{
    style_id: None,
    style_name: None,
    numbering: Some({ is_ordered: false, level: 1 }),
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  let ordered_child = @docx2html.ParagraphProperties::{
    style_id: None,
    style_name: None,
    numbering: Some({ is_ordered: true, level: 2 }),
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  inspect(
    @docx2html.convert_document_to_html(
      @docx2html.document([
        @docx2html.paragraph(
          [@docx2html.text("Parent")],
          properties=unordered_parent,
        ),
        @docx2html.paragraph(
          [@docx2html.text("Child")],
          properties=ordered_child,
        ),
      ]),
    ).value,
    content="<ul><li>Parent<ol><li>Child</li></ol></li></ul>",
  )
  let ordered_parent = @docx2html.ParagraphProperties::{
    style_id: None,
    style_name: None,
    numbering: Some({ is_ordered: true, level: 1 }),
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  let unordered_child = @docx2html.ParagraphProperties::{
    style_id: None,
    style_name: None,
    numbering: Some({ is_ordered: false, level: 2 }),
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  inspect(
    @docx2html.convert_document_to_html(
      @docx2html.document([
        @docx2html.paragraph(
          [@docx2html.text("Parent")],
          properties=ordered_parent,
        ),
        @docx2html.paragraph(
          [@docx2html.text("Child")],
          properties=unordered_child,
        ),
      ]),
    ).value,
    content="<ol><li>Parent<ul><li>Child</li></ul></li></ol>",
  )
}

///|
test "html simplifier removes empty nodes before collapsing" {
  inspect(
    @docx2html.write_html(@docx2html.simplify_html([@docx2html.html_text("")])),
    content="",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([@docx2html.html_element("p")]),
    ),
    content="",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.html_element("p", children=[@docx2html.html_text("")]),
      ]),
    ),
    content="",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([@docx2html.html_element("br")]),
    ),
    content="<br />",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.html_element("p", children=[
          @docx2html.html_text("Hello"),
          @docx2html.html_text(""),
        ]),
      ]),
    ),
    content="<p>Hello</p>",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.html_element("blockquote", children=[
          @docx2html.html_element("p", children=[@docx2html.html_text("Hello")]),
        ]),
        @docx2html.html_element("blockquote", children=[
          @docx2html.html_element("p", children=[@docx2html.html_text("there")]),
        ]),
      ]),
    ),
    content="<blockquote><p>Hellothere</p></blockquote>",
  )
}

///|
test "html simplifier follows Mammoth freshness collapse rules" {
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.fresh_html_element("p", children=[
          @docx2html.html_text("Hello"),
        ]),
        @docx2html.fresh_html_element("p", children=[
          @docx2html.html_text(" there"),
        ]),
      ]),
    ),
    content="<p>Hello</p><p> there</p>",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.fresh_html_element("p", children=[
          @docx2html.html_text("Hello"),
        ]),
        @docx2html.html_element("p", children=[@docx2html.html_text(" there")]),
      ]),
    ),
    content="<p>Hello there</p>",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.html_element("p", children=[@docx2html.html_text("Hello")]),
        @docx2html.fresh_html_element("p"),
        @docx2html.html_element("p", children=[@docx2html.html_text(" there")]),
      ]),
    ),
    content="<p>Hello there</p>",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.simplify_html([
        @docx2html.html_element("pre", children=[@docx2html.html_text("Hello")]),
        @docx2html.html_element(
          "pre",
          children=[@docx2html.html_text(" there")],
          separator="\n",
        ),
      ]),
    ),
    content="<pre>Hello\n there</pre>",
  )
}

///|
test "invalid style maps warn and keep valid mappings" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Walking on imported air")]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "", " => p", "=> p", "????", "p h1", "p => h1", "r => span a", "p => span#",
    "p:ordered-list(x) => ol > li",
  ])
  inspect(result.value, content="<h1>Walking on imported air</h1>")
  debug_inspect(
    result.messages,
    content=(
      #|[
      #|  Warning("Did not understand this style mapping, so ignored it: \nError was at character number 1: Expected element type but got end"),
      #|  Warning("Did not understand this style mapping, so ignored it:  => p\nError was at character number 1: Expected element type but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: => p\nError was at character number 1: Expected element type but got arrow"),
      #|  Warning("Did not understand this style mapping, so ignored it: ????\nError was at character number 1: Expected element type but got unrecognisedCharacter \"?\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p h1\nError was at character number 3: Expected arrow but got identifier \"h1\""),
      #|  Warning("Did not understand this style mapping, so ignored it: r => span a\nError was at character number 10: Expected end but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span#\nError was at character number 10: Expected end but got unrecognisedCharacter \"#\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p:ordered-list(x) => ol > li\nError was at character number 16: Expected integer but got identifier \"x\""),
      #|]
    ),
  )
}

///|
test "style map named matcher diagnostics match Mammoth" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Walking on imported air")]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "r[bad='x'] => span", "table[bad='x'] => table", "highlight[bad='yellow'] => mark",
    "br[bad='line'] => br",
  ])
  inspect(result.value, content="<p>Walking on imported air</p>")
  debug_inspect(
    result.messages,
    content=(
      #|[
      #|  Warning("Did not understand this style mapping, so ignored it: r[bad='x'] => span\nError was at character number 3: Expected identifier \"style-name\" but got identifier \"bad\""),
      #|  Warning("Did not understand this style mapping, so ignored it: table[bad='x'] => table\nError was at character number 7: Expected identifier \"style-name\" but got identifier \"bad\""),
      #|  Warning("Did not understand this style mapping, so ignored it: highlight[bad='yellow'] => mark\nError was at character number 11: Expected identifier \"color\" but got identifier \"bad\""),
      #|  Warning("Did not understand this style mapping, so ignored it: br[bad='line'] => br\nError was at character number 4: Expected identifier \"type\" but got identifier \"bad\""),
      #|]
    ),
  )
}

///|
test "style map malformed suffix diagnostics match Mammoth" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Walking on imported air")]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "p. => h1", "p[style-name] => h1", "p[style-name='Heading' => h1", "p:foo(1) => p",
    "p: => p", "p:ordered-list => p", "r:ordered-list(1) => span", "br => br", "p => ul>li",
    "p => span.",
  ])
  inspect(result.value, content="<p>Walking on imported air</p>")
  debug_inspect(
    result.messages,
    content=(
      #|[
      #|  Warning("Did not understand this style mapping, so ignored it: p. => h1\nError was at character number 3: Expected identifier but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: p[style-name] => h1\nError was at character number 13: Expected style name matcher but got close-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: p[style-name='Heading' => h1\nError was at character number 23: Expected close-square-bracket but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: p:foo(1) => p\nError was at character number 2: Expected whitespace but got colon"),
      #|  Warning("Did not understand this style mapping, so ignored it: p: => p\nError was at character number 2: Expected whitespace but got colon"),
      #|  Warning("Did not understand this style mapping, so ignored it: p:ordered-list => p\nError was at character number 15: Expected open-paren but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: r:ordered-list(1) => span\nError was at character number 2: Expected whitespace but got colon"),
      #|  Warning("Did not understand this style mapping, so ignored it: br => br\nError was at character number 3: Expected open-square-bracket but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul>li\nError was at character number 8: Expected end but got gt"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span.\nError was at character number 11: Expected identifier but got end"),
      #|]
    ),
  )
}

///|
test "style map malformed html path diagnostics match Mammoth" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Walking on imported air")]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "p => span:separator", "p => span:separator(x)", "p => span:separator('x'", "p => span:separator('x'):fresh",
    "p => span:", "p => .tip", "p => span[=]", "p => span[data-x]", "p => span[data-x='",
    "p => span[data-x='abc", "p => span[data-x='a\\\\b", "p => ul| > li", "p => ul > !",
    "p => >", "p => |", "p => |li",
  ])
  inspect(result.value, content="<p>Walking on imported air</p>")
  debug_inspect(
    result.messages,
    content=(
      #|[
      #|  Warning("Did not understand this style mapping, so ignored it: p => span:separator\nError was at character number 10: Expected end but got colon"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span:separator(x)\nError was at character number 10: Expected end but got colon"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span:separator('x'\nError was at character number 10: Expected end but got colon"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span:separator('x'):fresh\nError was at character number 25: Expected end but got colon"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span:\nError was at character number 10: Expected end but got colon"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => .tip\nError was at character number 6: Expected end but got dot"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span[=]\nError was at character number 11: Expected identifier but got equals"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span[data-x]\nError was at character number 17: Expected equals but got close-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span[data-x='\nError was at character number 18: Expected string but got unterminated-string"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span[data-x='abc\nError was at character number 18: Expected string but got unterminated-string \"abc\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p => span[data-x='a\\\\b\nError was at character number 18: Expected string but got unterminated-string \"a\\\\b\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul| > li\nError was at character number 8: Expected end but got choice"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul > !\nError was at character number 8: Expected end but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => >\nError was at character number 6: Expected end but got gt"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => |\nError was at character number 6: Expected end but got choice"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => |li\nError was at character number 6: Expected end but got choice"),
      #|]
    ),
  )
}

///|
test "style map delimiter token diagnostics match Mammoth" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Walking on imported air")]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "p ^= h1", "p [] => h1", "p () => h1", "p ! => h1", "p 123 => h1", "p 'abc => h1",
    "p 'a\\\\b => h1",
  ])
  inspect(result.value, content="<p>Walking on imported air</p>")
  debug_inspect(
    result.messages,
    content=(
      #|[
      #|  Warning("Did not understand this style mapping, so ignored it: p ^= h1\nError was at character number 3: Expected arrow but got startsWith"),
      #|  Warning("Did not understand this style mapping, so ignored it: p [] => h1\nError was at character number 3: Expected arrow but got open-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: p () => h1\nError was at character number 3: Expected arrow but got open-paren"),
      #|  Warning("Did not understand this style mapping, so ignored it: p ! => h1\nError was at character number 3: Expected arrow but got bang \"!\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p 123 => h1\nError was at character number 3: Expected arrow but got integer \"123\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p 'abc => h1\nError was at character number 3: Expected arrow but got unterminated-string \"abc => h1\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p 'a\\\\b => h1\nError was at character number 3: Expected arrow but got unterminated-string \"a\\\\b => h1\""),
      #|]
    ),
  )
}

///|
test "style map malformed nested html path diagnostics match Mammoth" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Walking on imported air")]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "p => ul >li", "p => ul >", "p => ul > span[=]", "p => ul > span[data-x]", "p => ul > span[data-x=]",
    "p => ul > span:separator('x'):fresh", "p => ul > span:fresh:separator('x')",
  ])
  inspect(result.value, content="<ul><span>Walking on imported air</span></ul>")
  debug_inspect(
    result.messages,
    content=(
      #|[
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul >li\nError was at character number 8: Expected end but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul >\nError was at character number 8: Expected end but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul > span[=]\nError was at character number 16: Expected end but got equals"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul > span[data-x]\nError was at character number 22: Expected end but got close-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul > span[data-x=]\nError was at character number 23: Expected end but got close-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: p => ul > span:separator('x'):fresh\nError was at character number 30: Expected end but got colon"),
      #|]
    ),
  )
}

///|
test "style map malformed named value diagnostics match Mammoth" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Walking on imported air")]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "p[=] => h1", "p[style-name^] => h1", "p[style-name='", "highlight[=] => mark",
    "highlight[color] => mark", "highlight[color=] => mark", "highlight[color='yellow' => mark",
    "br[=] => br", "br[type] => br", "br[type=] => br", "br[type='page' => hr", "br[type='weird'] => hr",
    "p:ordered-list() => p", "p:ordered-list(1 => p",
  ])
  inspect(result.value, content="<p>Walking on imported air</p>")
  debug_inspect(
    result.messages,
    content=(
      #|[
      #|  Warning("Did not understand this style mapping, so ignored it: p[=] => h1\nError was at character number 3: Expected identifier \"style-name\" but got equals"),
      #|  Warning("Did not understand this style mapping, so ignored it: p[style-name^] => h1\nError was at character number 13: Expected style name matcher but got unrecognisedCharacter \"^\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p[style-name='\nError was at character number 14: Expected string but got unterminated-string"),
      #|  Warning("Did not understand this style mapping, so ignored it: highlight[=] => mark\nError was at character number 11: Expected identifier \"color\" but got equals"),
      #|  Warning("Did not understand this style mapping, so ignored it: highlight[color] => mark\nError was at character number 16: Expected equals but got close-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: highlight[color=] => mark\nError was at character number 17: Expected string but got close-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: highlight[color='yellow' => mark\nError was at character number 25: Expected close-square-bracket but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: br[=] => br\nError was at character number 4: Expected identifier \"type\" but got equals"),
      #|  Warning("Did not understand this style mapping, so ignored it: br[type] => br\nError was at character number 8: Expected equals but got close-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: br[type=] => br\nError was at character number 9: Expected string but got close-square-bracket"),
      #|  Warning("Did not understand this style mapping, so ignored it: br[type='page' => hr\nError was at character number 15: Expected close-square-bracket but got whitespace"),
      #|  Warning("Did not understand this style mapping, so ignored it: br[type='weird'] => hr\nError was at character number 10: Expected break type but got identifier \"weird\""),
      #|  Warning("Did not understand this style mapping, so ignored it: p:ordered-list() => p\nError was at character number 16: Expected integer but got close-paren"),
      #|  Warning("Did not understand this style mapping, so ignored it: p:ordered-list(1 => p\nError was at character number 17: Expected close-paren but got whitespace"),
      #|]
    ),
  )
}

///|
test "style map style-name prefix matchers are honored" {
  let heading_properties = @docx2html.ParagraphProperties::{
    style_id: None,
    style_name: Some("Heading Special"),
    numbering: None,
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  let doc = @docx2html.document([
    @docx2html.paragraph(
      [@docx2html.text("Title")],
      properties=heading_properties,
    ),
    @docx2html.paragraph([@docx2html.text("Body")]),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc, style_map=[
      "p[style-name^='Heading'] => h1:fresh",
    ]).value,
    content="<h1>Title</h1><p>Body</p>",
  )
  let caret_properties = @docx2html.ParagraphProperties::{
    style_id: None,
    style_name: Some("^Heading"),
    numbering: None,
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  inspect(
    @docx2html.convert_document_to_html(
      @docx2html.paragraph(
        [@docx2html.text("Caret")],
        properties=caret_properties,
      ),
      style_map=["p[style-name='^Heading'] => h2:fresh"],
    ).value,
    content="<h2>Caret</h2>",
  )
  let table = @docx2html.Table(children=[], properties={
    style_id: None,
    style_name: Some("Normal Table"),
  })
  inspect(
    @docx2html.convert_document_to_html(table, style_map=[
      "table[style-name^='Normal'] => table.normal-table:fresh",
    ]).value,
    content="<table class=\"normal-table\"></table>",
  )
}

///|
test "style map style-name matchers are case-insensitive" {
  let paragraph_properties = @docx2html.ParagraphProperties::{
    style_id: Some("MixedHeading"),
    style_name: Some("heaDING 1"),
    numbering: None,
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  let run_properties = @docx2html.RunProperties::{
    style_id: Some("MixedRun"),
    style_name: Some("stRoNg"),
    is_bold: false,
    is_underline: false,
    is_italic: false,
    is_strikethrough: false,
    is_all_caps: false,
    is_small_caps: false,
    vertical_alignment: Baseline,
    font: None,
    font_size: None,
    highlight: None,
  }
  let table_properties = @docx2html.TableProperties::{
    style_id: Some("MixedTable"),
    style_name: Some("normal table"),
  }
  let doc = @docx2html.document([
    @docx2html.paragraph(
      [@docx2html.text("Title")],
      properties=paragraph_properties,
    ),
    @docx2html.paragraph([
      @docx2html.run([@docx2html.text("Run")], properties=run_properties),
    ]),
    Table(children=[], properties=table_properties),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "p[style-name='Heading 1'] => h1:fresh", "r[style-name='Strong'] => strong",
    "table[style-name^='Normal'] => table.normal-table:fresh",
  ])
  inspect(
    result.value,
    content="<h1>Title</h1><p><strong>Run</strong></p><table class=\"normal-table\"></table>",
  )
  debug_inspect(result.messages, content="[]")
}

///|
test "document converter warns for unrecognised styles" {
  let paragraph_properties = @docx2html.ParagraphProperties::{
    style_id: Some("MysteryParagraph"),
    style_name: Some("Mystery Paragraph"),
    numbering: None,
    alignment: None,
    indent: @docx2html.Indent::default(),
  }
  let paragraph_doc = @docx2html.document([
    @docx2html.paragraph(
      [@docx2html.text("Hello.")],
      properties=paragraph_properties,
    ),
  ])
  debug_inspect(
    @docx2html.convert_document_to_html(paragraph_doc).messages,
    content=(
      #|[Warning("Unrecognised paragraph style: 'Mystery Paragraph' (Style ID: MysteryParagraph)")]
    ),
  )
  let run_properties = @docx2html.RunProperties::{
    style_id: Some("MysteryRun"),
    style_name: Some("Mystery Run"),
    is_bold: false,
    is_underline: false,
    is_italic: false,
    is_strikethrough: false,
    is_all_caps: false,
    is_small_caps: false,
    vertical_alignment: Baseline,
    font: None,
    font_size: None,
    highlight: None,
  }
  debug_inspect(
    @docx2html.convert_document_to_html(
      @docx2html.run([@docx2html.text("Hello.")], properties=run_properties),
    ).messages,
    content=(
      #|[Warning("Unrecognised run style: 'Mystery Run' (Style ID: MysteryRun)")]
    ),
  )
  let table_properties = @docx2html.TableProperties::{
    style_id: Some("MysteryTable"),
    style_name: Some("Mystery Table"),
  }
  let table_result = @docx2html.convert_document_to_html(
    Table(children=[], properties=table_properties),
  )
  inspect(table_result.value, content="<table></table>")
  debug_inspect(table_result.messages, content="[]")
}

///|
fn run_properties(
  is_bold? : Bool = false,
  is_underline? : Bool = false,
  is_italic? : Bool = false,
  is_strikethrough? : Bool = false,
  is_all_caps? : Bool = false,
  is_small_caps? : Bool = false,
  vertical_alignment? : @docx2html.VerticalAlignment = Baseline,
  highlight? : String? = None,
) -> @docx2html.RunProperties {
  @docx2html.run_properties(
    is_bold~,
    is_underline~,
    is_italic~,
    is_strikethrough~,
    is_all_caps~,
    is_small_caps~,
    vertical_alignment~,
    highlight~,
  )
}

///|
fn run_text(
  text : String,
  properties : @docx2html.RunProperties,
) -> @docx2html.DocumentElement {
  @docx2html.run([@docx2html.text(text)], properties~)
}

///|
test "document converter wraps inline run properties" {
  let bold = @docx2html.RunProperties::{
    style_id: None,
    style_name: None,
    is_bold: true,
    is_underline: false,
    is_italic: false,
    is_strikethrough: false,
    is_all_caps: false,
    is_small_caps: false,
    vertical_alignment: Baseline,
    font: None,
    font_size: None,
    highlight: None,
  }
  let doc = @docx2html.document([
    @docx2html.paragraph([
      @docx2html.run([@docx2html.text("one")], properties=bold),
      @docx2html.run([@docx2html.text("two")], properties=bold),
    ]),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc).value,
    content="<p><strong>onetwo</strong></p>",
  )
}

///|
test "document converter matches Mammoth run property wrappers" {
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(is_bold=true, is_italic=true)),
    ).value,
    content="<strong><em>Hello.</em></strong>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(vertical_alignment=Superscript)),
    ).value,
    content="<sup>Hello.</sup>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(vertical_alignment=Subscript)),
    ).value,
    content="<sub>Hello.</sub>",
  )
}

///|
test "document converter follows Mammoth run property style-map overrides" {
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(is_underline=true)),
    ).value,
    content="Hello.",
  )
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(is_bold=true)),
      style_map=["b => em"],
    ).value,
    content="<em>Hello.</em>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(is_bold=true, is_underline=true)),
      style_map=["u => u"],
    ).value,
    content="<strong><u>Hello.</u></strong>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(is_strikethrough=true)),
    ).value,
    content="<s>Hello.</s>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(is_strikethrough=true)),
      style_map=["strike => del"],
    ).value,
    content="<del>Hello.</del>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      run_text("Hello.", run_properties(is_italic=true)),
      style_map=["i => strong"],
    ).value,
    content="<strong>Hello.</strong>",
  )
  let impossible_run_list = @docx2html.convert_document_to_html(
    run_text("Hello.", run_properties()),
    style_map=["r:ordered-list(1) => span"],
  )
  inspect(impossible_run_list.value, content="Hello.")
  debug_inspect(
    impossible_run_list.messages,
    content=(
      #|[Warning("Did not understand this style mapping, so ignored it: r:ordered-list(1) => span\nError was at character number 2: Expected whitespace but got colon")]
    ),
  )
}

///|
test "document converter maps caps and highlight run properties" {
  let all_caps = run_text("Hello.", run_properties(is_all_caps=true))
  inspect(@docx2html.convert_document_to_html(all_caps).value, content="Hello.")
  inspect(
    @docx2html.convert_document_to_html(all_caps, style_map=["all-caps => span"]).value,
    content="<span>Hello.</span>",
  )
  let small_caps = run_text("Hello.", run_properties(is_small_caps=true))
  inspect(
    @docx2html.convert_document_to_html(small_caps).value,
    content="Hello.",
  )
  inspect(
    @docx2html.convert_document_to_html(small_caps, style_map=[
      "small-caps => span",
    ]).value,
    content="<span>Hello.</span>",
  )
  let highlighted = run_text("Hello.", run_properties(highlight=Some("yellow")))
  inspect(
    @docx2html.convert_document_to_html(highlighted).value,
    content="Hello.",
  )
  inspect(
    @docx2html.convert_document_to_html(highlighted, style_map=[
      "highlight => mark",
    ]).value,
    content="<mark>Hello.</mark>",
  )
  let paragraph = @docx2html.paragraph([
    run_text("Yellow", run_properties(highlight=Some("yellow"))),
    run_text("Red", run_properties(highlight=Some("red"))),
  ])
  inspect(
    @docx2html.convert_document_to_html(paragraph, style_map=[
      "highlight[color='yellow'] => mark.yellow", "highlight => mark",
    ]).value,
    content="<p><mark class=\"yellow\">Yellow</mark><mark>Red</mark></p>",
  )
}

///|
test "document converter renders hyperlink anchors and targets" {
  let external_with_anchor = @docx2html.document([
    Hyperlink(
      children=[@docx2html.run([@docx2html.text("Hello.")])],
      href=Some("http://example.com/#old"),
      anchor=Some("new"),
      target_frame=None,
    ),
  ])
  inspect(
    @docx2html.convert_document_to_html(external_with_anchor).value,
    content="<a href=\"http://example.com/#new\">Hello.</a>",
  )
  let anchor_doc = @docx2html.document([
    Hyperlink(
      children=[@docx2html.run([@docx2html.text("Hello.")])],
      href=None,
      anchor=Some("_Peter"),
      target_frame=None,
    ),
  ])
  inspect(
    @docx2html.convert_document_to_html(anchor_doc, id_prefix="doc-42-").value,
    content="<a href=\"#doc-42-_Peter\">Hello.</a>",
  )
  let target_doc = @docx2html.document([
    Hyperlink(
      children=[@docx2html.run([@docx2html.text("Hello.")])],
      href=None,
      anchor=Some("start"),
      target_frame=Some("_blank"),
    ),
  ])
  inspect(
    @docx2html.convert_document_to_html(target_doc).value,
    content="<a href=\"#start\" target=\"_blank\">Hello.</a>",
  )
}

///|
test "document converter collapses adjacent hyperlinks with the same target" {
  let doc = @docx2html.document([
    Hyperlink(
      children=[@docx2html.run([@docx2html.text("Hello ")])],
      href=Some("http://www.example.com"),
      anchor=None,
      target_frame=None,
    ),
    Hyperlink(
      children=[@docx2html.run([@docx2html.text("world")])],
      href=Some("http://www.example.com"),
      anchor=None,
      target_frame=None,
    ),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc).value,
    content="<a href=\"http://www.example.com\">Hello world</a>",
  )
}

///|
test "document converter collapses unaddressed hyperlinks to children" {
  let doc = @docx2html.document([
    Hyperlink(
      children=[@docx2html.run([@docx2html.text("Plain")])],
      href=None,
      anchor=None,
      target_frame=None,
    ),
  ])
  inspect(@docx2html.convert_document_to_html(doc).value, content="Plain")
}

///|
test "document converter renders bookmarks and tabs like Mammoth" {
  inspect(
    @docx2html.convert_document_to_html(
      @docx2html.document([BookmarkStart("_Peter")]),
      id_prefix="doc-42-",
    ).value,
    content="<a id=\"doc-42-_Peter\"></a>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      @docx2html.paragraph([BookmarkStart("_Peter")]),
      id_prefix="doc-42-",
    ).value,
    content="<p><a id=\"doc-42-_Peter\"></a></p>",
  )
  inspect(
    @docx2html.convert_document_to_html(@docx2html.tab()).value,
    content="\t",
  )
}

///|
test "document converter renders checkboxes like Mammoth" {
  inspect(
    @docx2html.convert_document_to_html(@docx2html.checkbox(false)).value,
    content="<input type=\"checkbox\" />",
  )
  inspect(
    @docx2html.convert_document_to_html(@docx2html.checkbox(true)).value,
    content="<input type=\"checkbox\" checked=\"checked\" />",
  )
}

///|
test "document helper constructors cover common Mammoth nodes" {
  let linked = @docx2html.hyperlink(
    [@docx2html.run([@docx2html.text("Hello.")])],
    href=Some("http://example.com/#old"),
    anchor=Some("new"),
    target_frame=Some("_blank"),
  )
  inspect(
    @docx2html.convert_document_to_html(linked).value,
    content="<a href=\"http://example.com/#new\" target=\"_blank\">Hello.</a>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      @docx2html.document([@docx2html.bookmark_start("_Peter")]),
      id_prefix="doc-42-",
    ).value,
    content="<a id=\"doc-42-_Peter\"></a>",
  )
  let media = @docx2html.image("image/png", b"abc", alt_text=Some("pic"))
  inspect(
    @docx2html.convert_document_to_html(media).value,
    content="<img alt=\"pic\" src=\"data:image/png;base64,YWJj\" />",
  )
  let note = @docx2html.note("footnote", "4", [
    @docx2html.paragraph([@docx2html.text("Who's there?")]),
  ])
  let comment = @docx2html.comment(
    "7",
    [@docx2html.paragraph([@docx2html.text("Comment body")])],
    author_name="The Piemaker",
    author_initials="TP",
  )
  let doc = @docx2html.document(
    [
      @docx2html.paragraph([
        @docx2html.text("Knock knock"),
        @docx2html.run([@docx2html.note_reference("footnote", "4")]),
        @docx2html.comment_reference("7"),
      ]),
    ],
    notes=[note],
    comments=[comment],
  )
  inspect(
    @docx2html.convert_document_to_html(
      doc,
      style_map=["comment-reference => sup"],
      id_prefix="doc-42-",
    ).value,
    content="<p>Knock knock<sup><a href=\"#doc-42-footnote-4\" id=\"doc-42-footnote-ref-4\">[1]</a><a href=\"#doc-42-comment-7\" id=\"doc-42-comment-ref-7\">[TP1]</a></sup></p><ol><li id=\"doc-42-footnote-4\"><p>Who's there? <a href=\"#doc-42-footnote-ref-4\">↑</a></p></li></ol><dl><dt id=\"doc-42-comment-7\">Comment [TP1]</dt><dd><p>Comment body <a href=\"#doc-42-comment-ref-7\">↑</a></p></dd></dl>",
  )
}

///|
test "document property helpers mirror Mammoth option defaults" {
  let blank_paragraph = @docx2html.paragraph_properties(
    style_name=Some(""),
    alignment=Some(""),
    indent=@docx2html.indent(start=Some("720"), end=Some("")),
    numbering=Some(@docx2html.numbering(true, 1)),
  )
  debug_inspect(blank_paragraph.style_name, content="None")
  debug_inspect(blank_paragraph.alignment, content="None")
  debug_inspect(blank_paragraph.indent.start, content="Some(\"720\")")
  debug_inspect(blank_paragraph.indent.end, content="None")
  let blank_run = @docx2html.run_properties(
    style_name=Some(""),
    font=Some(""),
    highlight=Some(""),
  )
  debug_inspect(blank_run.style_name, content="None")
  debug_inspect(blank_run.font, content="None")
  debug_inspect(blank_run.highlight, content="None")
  let doc = @docx2html.document([
    @docx2html.paragraph(
      [@docx2html.text("Title")],
      properties=@docx2html.paragraph_properties(style_name=Some("Heading 1")),
    ),
    @docx2html.paragraph([
      @docx2html.run(
        [@docx2html.text("Marked")],
        properties=@docx2html.run_properties(
          is_bold=true,
          highlight=Some("yellow"),
        ),
      ),
    ]),
    @docx2html.table(
      [],
      properties=@docx2html.table_properties(style_name=Some("Normal Table")),
    ),
  ])
  inspect(
    @docx2html.convert_document_to_html(doc, style_map=[
      "p[style-name='Heading 1'] => h2", "highlight[color='yellow'] => mark", "table[style-name='Normal Table'] => table.normal-table",
    ]).value,
    content="<h2>Title</h2><p><strong><mark>Marked</mark></strong></p><table class=\"normal-table\"></table>",
  )
}

///|
fn table_cell(
  children : Array[@docx2html.DocumentElement],
  col_span? : Int = 1,
  row_span? : Int = 1,
) -> @docx2html.DocumentElement {
  @docx2html.table_cell(children, col_span~, row_span~)
}

///|
fn table_row(
  children : Array[@docx2html.DocumentElement],
  is_header? : Bool = false,
) -> @docx2html.DocumentElement {
  @docx2html.table_row(children, is_header~)
}

///|
fn test_table(
  children : Array[@docx2html.DocumentElement],
) -> @docx2html.DocumentElement {
  @docx2html.table(children)
}

///|
fn paragraph_of_text(text : String) -> @docx2html.DocumentElement {
  @docx2html.paragraph([@docx2html.text(text)])
}

///|
test "document converter renders table structure like Mammoth" {
  let table = test_table([
    table_row([
      table_cell([paragraph_of_text("Top left")]),
      table_cell([paragraph_of_text("Top right")]),
    ]),
    table_row([
      table_cell([paragraph_of_text("Bottom left")]),
      table_cell([paragraph_of_text("Bottom right")]),
    ]),
  ])
  inspect(
    @docx2html.convert_document_to_html(table).value,
    content="<table><tr><td><p>Top left</p></td><td><p>Top right</p></td></tr><tr><td><p>Bottom left</p></td><td><p>Bottom right</p></td></tr></table>",
  )
  inspect(
    @docx2html.convert_document_to_html(test_table([@docx2html.tab()])).value,
    content="<table>\t</table>",
  )
  let styled_table = @docx2html.Table(children=[], properties={
    style_id: None,
    style_name: Some("Normal Table"),
  })
  inspect(
    @docx2html.convert_document_to_html(styled_table, style_map=[
      "table[style-name='Normal Table'] => table.normal-table",
    ]).value,
    content="<table class=\"normal-table\"></table>",
  )
}

///|
test "document converter preserves empty table rows and cells" {
  inspect(
    @docx2html.convert_document_to_html(
      test_table([
        table_row([
          table_cell([paragraph_of_text("")]),
          table_cell([paragraph_of_text("Top right")]),
        ]),
      ]),
    ).value,
    content="<table><tr><td></td><td><p>Top right</p></td></tr></table>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      test_table([
        table_row([table_cell([paragraph_of_text("Row 1")])]),
        table_row([]),
      ]),
    ).value,
    content="<table><tr><td><p>Row 1</p></td></tr><tr></tr></table>",
  )
}

///|
test "document converter writes table cell spans" {
  inspect(
    @docx2html.convert_document_to_html(
      test_table([
        table_row([
          table_cell([paragraph_of_text("Top left")], col_span=2),
          table_cell([paragraph_of_text("Top right")]),
        ]),
      ]),
    ).value,
    content="<table><tr><td colspan=\"2\"><p>Top left</p></td><td><p>Top right</p></td></tr></table>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      test_table([table_row([table_cell([], row_span=2)])]),
    ).value,
    content="<table><tr><td rowspan=\"2\"></td></tr></table>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      table_cell([paragraph_of_text("Cell")], col_span=2, row_span=3),
    ).value,
    content="<td colspan=\"2\" rowspan=\"3\"><p>Cell</p></td>",
  )
}

///|
test "document converter groups leading header table rows" {
  let table = @docx2html.Table(
    children=[
      TableRow(
        children=[
          TableCell(
            children=[@docx2html.paragraph([@docx2html.text("Head")])],
            col_span=1,
            row_span=1,
          ),
        ],
        is_header=true,
      ),
    ],
    properties=@docx2html.TableProperties::default(),
  )
  inspect(
    @docx2html.convert_document_to_html(table).value,
    content="<table><thead><tr><th><p>Head</p></th></tr></thead></table>",
  )
  let mixed_table = @docx2html.Table(
    children=[
      TableRow(
        children=[
          TableCell(
            children=[@docx2html.paragraph([@docx2html.text("H1")])],
            col_span=1,
            row_span=1,
          ),
        ],
        is_header=true,
      ),
      TableRow(
        children=[
          TableCell(
            children=[@docx2html.paragraph([@docx2html.text("H2")])],
            col_span=1,
            row_span=1,
          ),
        ],
        is_header=true,
      ),
      TableRow(
        children=[
          TableCell(
            children=[@docx2html.paragraph([@docx2html.text("Body")])],
            col_span=1,
            row_span=1,
          ),
        ],
        is_header=false,
      ),
    ],
    properties=@docx2html.TableProperties::default(),
  )
  inspect(
    @docx2html.convert_document_to_html(mixed_table).value,
    content="<table><thead><tr><th><p>H1</p></th></tr><tr><th><p>H2</p></th></tr></thead><tbody><tr><td><p>Body</p></td></tr></tbody></table>",
  )
  let all_header_table = @docx2html.Table(
    children=[
      TableRow(
        children=[TableCell(children=[], col_span=1, row_span=1)],
        is_header=true,
      ),
    ],
    properties=@docx2html.TableProperties::default(),
  )
  inspect(
    @docx2html.convert_document_to_html(all_header_table).value,
    content="<table><thead><tr><th></th></tr></thead></table>",
  )
}

///|
test "document converter preserves unexpected table children" {
  let table = test_table([
    table_row(
      [table_cell([paragraph_of_text("Head")]), @docx2html.tab()],
      is_header=true,
    ),
    @docx2html.tab(),
  ])
  inspect(
    @docx2html.convert_document_to_html(table).value,
    content="<table><thead><tr><th><p>Head</p></th>\t</tr></thead><tbody>\t</tbody></table>",
  )
}

///|
test "document converter maps break types through style maps" {
  let run = @docx2html.run([
    @docx2html.page_break(),
    @docx2html.line_break(),
    @docx2html.column_break(),
  ])
  inspect(@docx2html.convert_document_to_html(run).value, content="<br />")
  inspect(
    @docx2html.convert_document_to_html(run, style_map=[
      "br[type='page'] => hr:fresh", "br[type='line'] => br.line-break", "br[type='column'] => span.column-break",
    ]).value,
    content="<hr /><br class=\"line-break\" />",
  )
  inspect(
    @docx2html.convert_document_to_html(@docx2html.column_break(), style_map=[
      "br[type='column'] => hr",
    ]).value,
    content="<hr />",
  )
  let unknown = @docx2html.convert_document_to_html(@docx2html.line_break(), style_map=[
    "br[type='weird'] => hr",
  ])
  inspect(unknown.value, content="<br />")
  debug_inspect(
    unknown.messages,
    content=(
      #|[Warning("Did not understand this style mapping, so ignored it: br[type='weird'] => hr\nError was at character number 10: Expected break type but got identifier \"weird\"")]
    ),
  )
}

///|
test "document converter renders footnote references like Mammoth" {
  inspect(
    @docx2html.convert_document_to_html(
      NoteReference(note_type="footnote", note_id="4"),
      id_prefix="doc-42-",
    ).value,
    content="<sup><a href=\"#doc-42-footnote-4\" id=\"doc-42-footnote-ref-4\">[1]</a></sup>",
  )
  let note = @docx2html.Note::{
    note_type: "footnote",
    note_id: "4",
    body: [@docx2html.paragraph([@docx2html.text("Who's there?")])],
  }
  let doc = @docx2html.document(
    [
      @docx2html.paragraph([
        @docx2html.text("Knock knock"),
        @docx2html.run([NoteReference(note_type="footnote", note_id="4")]),
      ]),
    ],
    notes=[note],
  )
  inspect(
    @docx2html.convert_document_to_html(doc, id_prefix="doc-42-").value,
    content="<p>Knock knock<sup><a href=\"#doc-42-footnote-4\" id=\"doc-42-footnote-ref-4\">[1]</a></sup></p><ol><li id=\"doc-42-footnote-4\"><p>Who's there? <a href=\"#doc-42-footnote-ref-4\">↑</a></p></li></ol>",
  )
}

///|
test "document converter tolerates missing note and comment bodies" {
  let doc = @docx2html.document([
    @docx2html.paragraph([
      @docx2html.text("Knock knock"),
      @docx2html.run([NoteReference(note_type="footnote", note_id="missing")]),
      CommentReference("missing"),
    ]),
  ])
  inspect(
    @docx2html.convert_document_to_html(
      doc,
      style_map=["comment-reference => sup"],
      id_prefix="doc-42-",
    ).value,
    content="<p>Knock knock<sup><a href=\"#doc-42-footnote-missing\" id=\"doc-42-footnote-ref-missing\">[1]</a></sup></p>",
  )
}

///|
test "document converter appends note backlinks without paragraph bodies" {
  let empty_note = @docx2html.Note::{
    note_type: "footnote",
    note_id: "empty",
    body: [],
  }
  let loose_note = @docx2html.Note::{
    note_type: "footnote",
    note_id: "loose",
    body: [@docx2html.text("Loose")],
  }
  let doc = @docx2html.document(
    [
      @docx2html.paragraph([
        @docx2html.run([NoteReference(note_type="footnote", note_id="empty")]),
        @docx2html.run([NoteReference(note_type="footnote", note_id="loose")]),
      ]),
    ],
    notes=[empty_note, loose_note],
  )
  inspect(
    @docx2html.convert_document_to_html(doc, id_prefix="doc-42-").value,
    content="<p><sup><a href=\"#doc-42-footnote-empty\" id=\"doc-42-footnote-ref-empty\">[1]</a><a href=\"#doc-42-footnote-loose\" id=\"doc-42-footnote-ref-loose\">[2]</a></sup></p><ol><li id=\"doc-42-footnote-empty\"><p> <a href=\"#doc-42-footnote-ref-empty\">↑</a></p></li><li id=\"doc-42-footnote-loose\">Loose<p> <a href=\"#doc-42-footnote-ref-loose\">↑</a></p></li></ol>",
  )
}

///|
test "document converter emits data uri images" {
  let image = @docx2html.Image::{
    content_type: "image/jpeg",
    alt_text: Some("alt"),
    data: b"abc",
  }
  let doc = @docx2html.document([@docx2html.paragraph([Image(image)])])
  inspect(
    @docx2html.convert_document_to_html(doc).value,
    content="<p><img alt=\"alt\" src=\"data:image/jpeg;base64,YWJj\" /></p>",
  )
}

///|
test "image helper follows Mammoth alt attribute merging" {
  let without_alt = @docx2html.Image::{
    content_type: "image/jpeg",
    alt_text: None,
    data: b"abc",
  }
  inspect(
    @docx2html.write_html(
      @docx2html.img_element(fn(_image) { { "src": "<src>" } })(without_alt).nodes,
    ),
    content="<img src=\"&lt;src&gt;\" />",
  )
  let with_alt = @docx2html.Image::{
    content_type: "image/jpeg",
    alt_text: Some("<alt>"),
    data: b"abc",
  }
  inspect(
    @docx2html.write_html(
      @docx2html.img_element(fn(_image) { { "src": "<src>" } })(with_alt).nodes,
    ),
    content="<img alt=\"&lt;alt&gt;\" src=\"&lt;src&gt;\" />",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.img_element(fn(_image) {
        { "alt": "<alt override>", "src": "<src>" }
      })(with_alt).nodes,
    ),
    content="<img alt=\"&lt;alt override&gt;\" src=\"&lt;src&gt;\" />",
  )
  inspect(
    @docx2html.write_html(
      @docx2html.inline_image(fn(_image) { { "src": "<src>" } })(with_alt).nodes,
    ),
    content="<img alt=\"&lt;alt&gt;\" src=\"&lt;src&gt;\" />",
  )
  inspect(
    @docx2html.write_html(@docx2html.data_uri_image(with_alt).nodes),
    content="<img alt=\"&lt;alt&gt;\" src=\"data:image/jpeg;base64,YWJj\" />",
  )
}

///|
test "document converter accepts custom image converters" {
  let image = @docx2html.Image::{
    content_type: "image/jpeg",
    alt_text: Some("default alt"),
    data: b"abc",
  }
  let doc = @docx2html.document([@docx2html.paragraph([Image(image)])])
  let convert_image = @docx2html.img_element(fn(image) {
    {
      "alt": "override " + image.content_type,
      "src": "custom:" + image.content_type,
    }
  })
  inspect(
    @docx2html.convert_document_to_html(doc, convert_image~).value,
    content="<p><img alt=\"override image/jpeg\" src=\"custom:image/jpeg\" /></p>",
  )
}

///|
test "custom image converters inspect eager image bytes" {
  let image = @docx2html.Image::{
    content_type: "image/png",
    alt_text: None,
    data: b"Not an image at all!",
  }
  let doc = @docx2html.document([@docx2html.paragraph([Image(image)])])
  let convert_image = fn(image : @docx2html.Image) {
    let alt = try @utf8.decode(image.data[:]) catch {
      _ => ""
    } noraise {
      text => text
    }
    @docx2html.image_conversion([
      @docx2html.fresh_html_element("img", attributes={ "alt": alt }),
    ])
  }
  inspect(
    @docx2html.convert_document_to_html(doc, convert_image~).value,
    content="<p><img alt=\"Not an image at all!\" /></p>",
  )
}

///|
test "document converter records custom image converter messages" {
  let image = @docx2html.Image::{
    content_type: "image/jpeg",
    alt_text: None,
    data: b"abc",
  }
  let doc = @docx2html.document([@docx2html.paragraph([Image(image)])])
  let convert_image = fn(_image) {
    @docx2html.image_conversion([], messages=[Warning("skipped image")])
  }
  let result = @docx2html.convert_document_to_html(doc, convert_image~)
  inspect(result.value, content="")
  debug_inspect(result.messages, content="[Warning(\"skipped image\")]")
}

///|
test "document converter uses blank comment label initials" {
  let comment = @docx2html.Comment::{
    comment_id: "4",
    body: [@docx2html.paragraph([@docx2html.text("Who's there?")])],
    author_name: "",
    author_initials: "",
  }
  let doc = @docx2html.document(
    [@docx2html.paragraph([CommentReference("4")])],
    comments=[comment],
  )
  inspect(
    @docx2html.convert_document_to_html(
      doc,
      style_map=["comment-reference => sup"],
      id_prefix="doc-42-",
    ).value,
    content="<p><sup><a href=\"#doc-42-comment-4\" id=\"doc-42-comment-ref-4\">[1]</a></sup></p><dl><dt id=\"doc-42-comment-4\">Comment [1]</dt><dd><p>Who's there? <a href=\"#doc-42-comment-ref-4\">↑</a></p></dd></dl>",
  )
}

///|
test "document converter ignores comments unless style mapped" {
  let comment = @docx2html.Comment::{
    comment_id: "4",
    body: [@docx2html.paragraph([@docx2html.text("Who's there?")])],
    author_name: "The Piemaker",
    author_initials: "TP",
  }
  let doc = @docx2html.document(
    [
      @docx2html.paragraph([
        @docx2html.text("Knock knock"),
        CommentReference("4"),
      ]),
    ],
    comments=[comment],
  )
  inspect(
    @docx2html.convert_document_to_html(doc).value,
    content="<p>Knock knock</p>",
  )
  inspect(
    @docx2html.convert_document_to_html(
      doc,
      style_map=["comment-reference => sup"],
      id_prefix="doc-42-",
    ).value,
    content="<p>Knock knock<sup><a href=\"#doc-42-comment-4\" id=\"doc-42-comment-ref-4\">[TP1]</a></sup></p><dl><dt id=\"doc-42-comment-4\">Comment [TP1]</dt><dd><p>Who's there? <a href=\"#doc-42-comment-ref-4\">↑</a></p></dd></dl>",
  )
}

///|
test "document converter resolves nested comment references against root comments" {
  let comment = @docx2html.Comment::{
    comment_id: "4",
    body: [@docx2html.paragraph([@docx2html.text("Who's there?")])],
    author_name: "The Piemaker",
    author_initials: "TP",
  }
  let nested = @docx2html.Document(
    children=[
      @docx2html.paragraph([@docx2html.text("Nested"), CommentReference("4")]),
    ],
    notes=[],
    comments=[],
  )
  let doc = @docx2html.document([nested], comments=[comment])
  inspect(
    @docx2html.convert_document_to_html(
      doc,
      style_map=["comment-reference => sup"],
      id_prefix="doc-42-",
    ).value,
    content="<p>Nested<sup><a href=\"#doc-42-comment-4\" id=\"doc-42-comment-ref-4\">[TP1]</a></sup></p><dl><dt id=\"doc-42-comment-4\">Comment [TP1]</dt><dd><p>Who's there? <a href=\"#doc-42-comment-ref-4\">↑</a></p></dd></dl>",
  )
}

///|
test "document converter handles long documents like Mammoth" {
  let paragraphs : Array[@docx2html.DocumentElement] = []
  for _ in 0..<1000 {
    paragraphs.push(paragraph_of_text("Hello."))
  }
  inspect(
    @docx2html.convert_document_to_html(@docx2html.document(paragraphs)).value.has_prefix(
      "<p>Hello.</p>",
    ),
    content="true",
  )
}

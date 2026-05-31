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
        @docx2html.html_element("p", children=[
          @docx2html.html_text("One"),
          @docx2html.html_text("Two"),
        ]),
      ],
      pretty_print=true,
    ),
    content="<p>\n  OneTwo\n</p>",
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
        @docx2html.html_element("li", children=[@docx2html.html_text("First")]),
      ]),
      @docx2html.html_element("p", children=[@docx2html.html_text("Hello")]),
      @docx2html.html_element("ol", children=[
        @docx2html.html_element("li", children=[@docx2html.html_text("Second")]),
      ]),
    ]),
    content="1. First\n\nHello\n\n1. Second\n\n",
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
test "document converter maps paragraphs and escapes text" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("A < B")]),
  ])
  let result = @docx2html.convert_document_to_html(doc)
  inspect(result.value, content="<p>A &lt; B</p>")
  debug_inspect(result.messages, content="[]")
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
      @docx2html.simplify_html([@docx2html.html_element("br")]),
    ),
    content="<br />",
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
test "invalid style maps warn and keep valid mappings" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Walking on imported air")]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "????", "p => h1", "r => span a",
  ])
  inspect(result.value, content="<h1>Walking on imported air</h1>")
  debug_inspect(
    result.messages,
    content=(
      #|[
      #|  Warning("Did not understand this style mapping, so ignored it: ????\nError was at character number 1: Expected element type but got unrecognisedCharacter \"?\""),
      #|  Warning("Did not understand this style mapping, so ignored it: r => span a\nError was at character number 10: Expected end but got whitespace"),
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
test "document converter renders hyperlink anchors and targets" {
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
test "document converter renders header table rows with th cells" {
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
    content="<table><tr><th><p>Head</p></th></tr></table>",
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

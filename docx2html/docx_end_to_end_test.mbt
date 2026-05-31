///|
test "convert_to_html reads single paragraph docx fixture" {
  let result = @docx2html.convert_to_html(single_paragraph_docx()[:])
  inspect(result.value, content="<p>Walking on imported air</p>")
  debug_inspect(result.messages, content="[]")
}

///|
test "read_docx reads single paragraph docx fixture" {
  match @docx2html.read_docx(single_paragraph_docx()[:]) {
    Document(children~, notes~, comments~) => {
      inspect(notes.length(), content="0")
      inspect(comments.length(), content="0")
      match children[0] {
        Paragraph(children=paragraph_children, ..) =>
          match paragraph_children[0] {
            Run(children=run_children, ..) =>
              debug_inspect(
                run_children,
                content=(
                  #|[Text("Walking on imported air")]
                ),
              )
            _ => fail("expected run")
          }
        _ => fail("expected paragraph")
      }
    }
    _ => fail("expected document")
  }
}

///|
test "pretty printing expands element content" {
  let result = @docx2html.convert_to_html(
    single_paragraph_docx()[:],
    pretty_print=true,
  )
  inspect(result.value, content="<p>\n  Walking on imported air\n</p>")
  debug_inspect(result.messages, content="[]")
}

///|
test "convert_to_html reads XML with UTF-8 byte order mark" {
  let result = @docx2html.convert_to_html(utf8_bom_docx()[:])
  inspect(result.value, content="<p>This XML has a byte order mark.</p>")
  debug_inspect(result.messages, content="[]")
}

///|
test "empty paragraphs are ignored unless requested" {
  inspect(@docx2html.convert_to_html(empty_docx()[:]).value, content="")
  inspect(
    @docx2html.convert_to_html(empty_docx()[:], ignore_empty_paragraphs=false).value,
    content="<p></p>",
  )
}

///|
test "extract_raw_text reads docx text" {
  let result = @docx2html.extract_raw_text(single_paragraph_docx()[:])
  inspect(result.value, content="Walking on imported air\n\n")
}

///|
test "extract_raw_text reads list docx text" {
  let result = @docx2html.extract_raw_text(simple_list_docx()[:])
  inspect(result.value, content="Apple\n\nBanana\n\n")
}

///|
test "extract_raw_text matches Mammoth fixture outputs" {
  inspect(
    @docx2html.extract_raw_text(utf8_bom_docx()[:]).value,
    content="This XML has a byte order mark.\n\n",
  )
  inspect(@docx2html.extract_raw_text(empty_docx()[:]).value, content="\n\n")
  inspect(
    @docx2html.extract_raw_text(tables_docx()[:]).value,
    content="Above\n\nTop left\n\nTop right\n\nBottom left\n\nBottom right\n\nBelow\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(underline_docx()[:]).value,
    content="The Sunset Tree\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(strikethrough_docx()[:]).value,
    content="Today's Special: Salmon Sold out\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(strict_format_docx()[:]).value,
    content="Test\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(footnotes_docx()[:]).value,
    content="Ouch.\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(endnotes_docx()[:]).value,
    content="Ouch.\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(comments_docx()[:]).value,
    content="Ouch.\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(text_box_docx()[:]).value,
    content="\n\nDatum plane\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(tiny_picture_docx()[:]).value,
    content="\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(tiny_picture_target_base_relative_docx()[:]).value,
    content="\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(footnote_hyperlink_docx()[:]).value,
    content="\n\n",
  )
  inspect(
    @docx2html.extract_raw_text(embedded_style_map_docx()[:]).value,
    content="Walking on imported air\n\n",
  )
  let external_picture = @docx2html.extract_raw_text(external_picture_docx()[:])
  inspect(external_picture.value, content="\n\n")
  debug_inspect(external_picture.messages, content="[]")
}

///|
test "convert_to_markdown reads docx text" {
  let result = @docx2html.convert_to_markdown(single_paragraph_docx()[:])
  inspect(result.value, content="Walking on imported air\n\n")
}

///|
test "convert_to_markdown reads docx list structure" {
  let result = @docx2html.convert_to_markdown(simple_list_docx()[:])
  inspect(result.value, content="- Apple\n- Banana\n\n")
}

///|
test "convert_to_markdown matches Mammoth fixture outputs" {
  inspect(
    @docx2html.convert_to_markdown(utf8_bom_docx()[:]).value,
    content="This XML has a byte order mark\\.\n\n",
  )
  inspect(@docx2html.convert_to_markdown(empty_docx()[:]).value, content="")
  inspect(
    @docx2html.convert_to_markdown(tables_docx()[:]).value,
    content="Above\n\nTop left\n\nTop right\n\nBottom left\n\nBottom right\n\nBelow\n\n",
  )
  inspect(
    @docx2html.convert_to_markdown(underline_docx()[:]).value,
    content="__The Sunset Tree__\n\n",
  )
  inspect(
    @docx2html.convert_to_markdown(strikethrough_docx()[:]).value,
    content="Today's Special: Salmon Sold out\n\n",
  )
  inspect(
    @docx2html.convert_to_markdown(strict_format_docx()[:]).value,
    content="Test\n\n",
  )
  inspect(
    @docx2html.convert_to_markdown(tiny_picture_docx()[:]).value,
    content="![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=)\n\n",
  )
  inspect(
    @docx2html.convert_to_markdown(tiny_picture_target_base_relative_docx()[:]).value,
    content="![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=)\n\n",
  )
  inspect(
    @docx2html.convert_to_markdown(endnotes_docx()[:]).value,
    content=(
      #|Ouch<a id="endnote-ref-2"></a>[\[1\]](#endnote-2)\.<a id="endnote-ref-3"></a>[\[2\]](#endnote-3)
      #|
      #|1. <a id="endnote-2"></a> A tachyon walks into a bar\. [↑](#endnote-ref-2)
      #|
      #|
      #|2. <a id="endnote-3"></a> Fin\. [↑](#endnote-ref-3)
      #|
      #|
      #|
      #|
    ),
  )
  inspect(
    @docx2html.convert_to_markdown(footnote_hyperlink_docx()[:]).value,
    content=(
      #|<a id="footnote-ref-1"></a>[\[1\]](#footnote-1)
      #|
      #|1. <a id="footnote-1"></a> [Example](http://www.example.com) [↑](#footnote-ref-1)
      #|
      #|
      #|
      #|
    ),
  )
  inspect(
    @docx2html.convert_to_markdown(comments_docx()[:]).value,
    content="Ouch\\.\n\n",
  )
  inspect(
    @docx2html.convert_to_markdown(comments_docx()[:], id_prefix="doc-42-", style_map=[
      "comment-reference => sup",
    ]).value,
    content=(
      #|Ouch<a id="doc-42-comment-ref-0"></a>[\[MW1\]](#doc-42-comment-0)\.<a id="doc-42-comment-ref-2"></a>[\[MW2\]](#doc-42-comment-2)
      #|
      #|<a id="doc-42-comment-0"></a>Comment \[MW1\]A tachyon walks into a bar\. [↑](#doc-42-comment-ref-0)
      #|
      #|<a id="doc-42-comment-2"></a>Comment \[MW2\]Fin\. [↑](#doc-42-comment-ref-2)
      #|
      #|
    ),
  )
  inspect(
    @docx2html.convert_to_markdown(text_box_docx()[:]).value,
    content="Datum plane\n\n",
  )
  inspect(
    @docx2html.convert_to_markdown(embedded_style_map_docx()[:]).value,
    content="# Walking on imported air\n\n",
  )
  let external_picture = @docx2html.convert_to_markdown(
    external_picture_docx()[:],
  )
  inspect(external_picture.value, content="")
  debug_inspect(
    external_picture.messages,
    content=(
      #|[Error("could not read external image 'tiny-picture.png', external file access is disabled")]
    ),
  )
}

///|
test "convert_to_markdown preserves empty paragraphs when requested" {
  let result = @docx2html.convert_to_markdown(
    empty_docx()[:],
    ignore_empty_paragraphs=false,
  )
  inspect(result.value, content="\n\n")
}

///|
test "convert_to_html applies document transform option" {
  let transform_document = @docx2html.transform_paragraphs(fn(_paragraph) {
    @docx2html.paragraph([@docx2html.text("Goodbye.")])
  })
  let result = @docx2html.convert_to_html(
    single_paragraph_docx()[:],
    transform_document~,
  )
  inspect(result.value, content="<p>Goodbye.</p>")
}

///|
test "convert_to_markdown applies document transform option" {
  let transform_document = @docx2html.transform_paragraphs(fn(_paragraph) {
    @docx2html.paragraph([@docx2html.text("Goodbye.")])
  })
  let result = @docx2html.convert_to_markdown(
    single_paragraph_docx()[:],
    transform_document~,
  )
  inspect(result.value, content="Goodbye\\.\n\n")
}

///|
test "simple list is converted to list elements" {
  let result = @docx2html.convert_to_html(simple_list_docx()[:])
  inspect(result.value, content="<ul><li>Apple</li><li>Banana</li></ul>")
  let without_default_style_map = @docx2html.convert_to_html(
    simple_list_docx()[:],
    include_default_style_map=false,
  )
  inspect(without_default_style_map.value, content="<p>Apple</p><p>Banana</p>")
  debug_inspect(
    without_default_style_map.messages,
    content=(
      #|[Warning("Unrecognised paragraph style: 'List Paragraph' (Style ID: ListParagraph)")]
    ),
  )
}

///|
test "word tables are converted to html tables" {
  let result = @docx2html.convert_to_html(tables_docx()[:])
  inspect(
    result.value,
    content="<p>Above</p><table><tr><td><p>Top left</p></td><td><p>Top right</p></td></tr><tr><td><p>Bottom left</p></td><td><p>Bottom right</p></td></tr></table><p>Below</p>",
  )
  debug_inspect(result.messages, content="[]")
}

///|
test "underline is ignored by default and configurable" {
  inspect(
    @docx2html.convert_to_html(underline_docx()[:]).value,
    content="<p><strong>The Sunset Tree</strong></p>",
  )
  inspect(
    @docx2html.convert_to_html(underline_docx()[:], style_map=["u => em"]).value,
    content="<p><strong>The <em>Sunset</em> Tree</strong></p>",
  )
}

///|
test "strikethrough uses default and custom mappings" {
  inspect(
    @docx2html.convert_to_html(strikethrough_docx()[:]).value,
    content="<p><s>Today's Special: Salmon</s> Sold out</p>",
  )
  inspect(
    @docx2html.convert_to_html(strikethrough_docx()[:], style_map=[
      "strike => del",
    ]).value,
    content="<p><del>Today's Special: Salmon</del> Sold out</p>",
  )
}

///|
test "strict docx format is read" {
  let result = @docx2html.convert_to_html(strict_format_docx()[:])
  inspect(result.value, content="<p>Test</p>")
  debug_inspect(result.messages, content="[]")
}

///|
test "invalid docx without main document raises Mammoth-compatible error" {
  try @docx2html.convert_to_html(empty_zip()[:]) catch {
    MissingPart(message~) =>
      inspect(
        message,
        content="Could not find main document part. Are you sure this is a valid .docx file?",
      )
    _ => fail("expected MissingPart")
  } noraise {
    _ => fail("expected missing main document failure")
  }
}

///|
test "inline images referenced relative to document part are included" {
  let result = @docx2html.convert_to_html(tiny_picture_docx()[:])
  inspect(
    result.value,
    content="<p><img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=\" /></p>",
  )
}

///|
test "convert_to_html applies custom image converter to docx images" {
  let convert_image = @docx2html.img_element(fn(image) {
    { "src": image.content_type }
  })
  let result = @docx2html.convert_to_html(
    tiny_picture_docx()[:],
    convert_image~,
  )
  inspect(result.value, content="<p><img src=\"image/png\" /></p>")
  let convert_image_from_data = @docx2html.img_element(fn(image) {
    let encoded = @base64.encode(image.data[:])
    { "src": encoded[:2].to_owned() + "," + image.content_type }
  })
  let data_result = @docx2html.convert_to_html(
    tiny_picture_docx()[:],
    convert_image=convert_image_from_data,
  )
  inspect(data_result.value, content="<p><img src=\"iV,image/png\" /></p>")
  debug_inspect(data_result.messages, content="[]")
}

///|
test "inline images referenced relative to package base are included" {
  let result = @docx2html.convert_to_html(
    tiny_picture_target_base_relative_docx()[:],
  )
  inspect(
    result.value,
    content="<p><img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=\" /></p>",
  )
}

///|
test "external linked images produce Mammoth-compatible error messages" {
  let result = @docx2html.convert_to_html(external_picture_docx()[:])
  inspect(result.value, content="")
  debug_inspect(
    result.messages,
    content=(
      #|[Error("could not read external image 'tiny-picture.png', external file access is disabled")]
    ),
  )
}

///|
fn tiny_picture_png() -> Bytes {
  try! @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=",
    ignore_whitespace=true,
  )
}

///|
test "external linked images can be loaded when explicitly enabled" {
  let result = @docx2html.convert_to_html(
    external_picture_docx()[:],
    external_file_access=true,
    read_external_file=fn(path) {
      if path == "tiny-picture.png" {
        Some(tiny_picture_png())
      } else {
        None
      }
    },
  )
  inspect(
    result.value,
    content="<p><img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=\" /></p>",
  )
  debug_inspect(result.messages, content="[]")
}

///|
test "external linked images report unknown path without a loader" {
  let result = @docx2html.convert_to_html(
    external_picture_docx()[:],
    external_file_access=true,
  )
  inspect(result.value, content="")
  debug_inspect(
    result.messages,
    content=(
      #|[Error("could not find external image 'tiny-picture.png', path of input document is unknown")]
    ),
  )
}

///|
test "footnotes are appended to text" {
  let result = @docx2html.convert_to_html(
    footnotes_docx()[:],
    id_prefix="doc-42-",
  )
  inspect(
    result.value,
    content="<p>Ouch<sup><a href=\"#doc-42-footnote-1\" id=\"doc-42-footnote-ref-1\">[1]</a></sup>.<sup><a href=\"#doc-42-footnote-2\" id=\"doc-42-footnote-ref-2\">[2]</a></sup></p><ol><li id=\"doc-42-footnote-1\"><p> A tachyon walks into a bar. <a href=\"#doc-42-footnote-ref-1\">↑</a></p></li><li id=\"doc-42-footnote-2\"><p> Fin. <a href=\"#doc-42-footnote-ref-2\">↑</a></p></li></ol>",
  )
  debug_inspect(result.messages, content="[]")
  let markdown = @docx2html.convert_to_markdown(footnotes_docx()[:])
  inspect(
    markdown.value,
    content=(
      #|Ouch<a id="footnote-ref-1"></a>[\[1\]](#footnote-1)\.<a id="footnote-ref-2"></a>[\[2\]](#footnote-2)
      #|
      #|1. <a id="footnote-1"></a> A tachyon walks into a bar\. [↑](#footnote-ref-1)
      #|
      #|
      #|2. <a id="footnote-2"></a> Fin\. [↑](#footnote-ref-2)
      #|
      #|
      #|
      #|
    ),
  )
}

///|
test "endnotes are appended to text" {
  let result = @docx2html.convert_to_html(
    endnotes_docx()[:],
    id_prefix="doc-42-",
  )
  inspect(
    result.value,
    content="<p>Ouch<sup><a href=\"#doc-42-endnote-2\" id=\"doc-42-endnote-ref-2\">[1]</a></sup>.<sup><a href=\"#doc-42-endnote-3\" id=\"doc-42-endnote-ref-3\">[2]</a></sup></p><ol><li id=\"doc-42-endnote-2\"><p> A tachyon walks into a bar. <a href=\"#doc-42-endnote-ref-2\">↑</a></p></li><li id=\"doc-42-endnote-3\"><p> Fin. <a href=\"#doc-42-endnote-ref-3\">↑</a></p></li></ol>",
  )
  debug_inspect(result.messages, content="[]")
}

///|
test "relationships are handled inside footnotes" {
  let result = @docx2html.convert_to_html(
    footnote_hyperlink_docx()[:],
    id_prefix="doc-42-",
  )
  inspect(
    result.value,
    content="<p><sup><a href=\"#doc-42-footnote-1\" id=\"doc-42-footnote-ref-1\">[1]</a></sup></p><ol><li id=\"doc-42-footnote-1\"><p> <a href=\"http://www.example.com\">Example</a> <a href=\"#doc-42-footnote-ref-1\">↑</a></p></li></ol>",
  )
  debug_inspect(result.messages, content="[]")
}

///|
test "comments are appended when comment references are style mapped" {
  inspect(
    @docx2html.convert_to_html(comments_docx()[:]).value,
    content="<p>Ouch.</p>",
  )
  let result = @docx2html.convert_to_html(
    comments_docx()[:],
    id_prefix="doc-42-",
    style_map=["comment-reference => sup"],
  )
  inspect(
    result.value,
    content="<p>Ouch<sup><a href=\"#doc-42-comment-0\" id=\"doc-42-comment-ref-0\">[MW1]</a></sup>.<sup><a href=\"#doc-42-comment-2\" id=\"doc-42-comment-ref-2\">[MW2]</a></sup></p><dl><dt id=\"doc-42-comment-0\">Comment [MW1]</dt><dd><p>A tachyon walks into a bar. <a href=\"#doc-42-comment-ref-0\">↑</a></p></dd><dt id=\"doc-42-comment-2\">Comment [MW2]</dt><dd><p>Fin. <a href=\"#doc-42-comment-ref-2\">↑</a></p></dd></dl>",
  )
  debug_inspect(result.messages, content="[]")
}

///|
test "embedded style maps are combined after explicit mappings" {
  debug_inspect(
    @docx2html.read_embedded_style_map(embedded_style_map_docx()[:]),
    content="Some(\"p => h1\")",
  )
  inspect(
    @docx2html.convert_to_html(embedded_style_map_docx()[:]).value,
    content="<h1>Walking on imported air</h1>",
  )
  inspect(
    @docx2html.convert_to_html(embedded_style_map_docx()[:], style_map=[
      "p => p",
    ]).value,
    content="<p>Walking on imported air</p>",
  )
  inspect(
    @docx2html.convert_to_html(embedded_style_map_docx()[:], style_map=[
      "r => strong",
    ]).value,
    content="<h1><strong>Walking on imported air</strong></h1>",
  )
  inspect(
    @docx2html.convert_to_html(
      embedded_style_map_docx()[:],
      include_default_style_map=false,
    ).value,
    content="<h1>Walking on imported air</h1>",
  )
  inspect(
    @docx2html.convert_to_html(
      embedded_style_map_docx()[:],
      include_default_style_map=false,
      include_embedded_style_map=false,
    ).value,
    content="<p>Walking on imported air</p>",
  )
}

///|
test "invalid explicit style maps warn while valid mappings still apply" {
  let result = @docx2html.convert_to_html(single_paragraph_docx()[:], style_map=[
    "????", "p => h1",
  ])
  inspect(result.value, content="<h1>Walking on imported air</h1>")
  debug_inspect(
    result.messages,
    content=(
      #|[Warning("Did not understand this style mapping, so ignored it: ????\nError was at character number 1: Expected element type but got unrecognisedCharacter \"?\"")]
    ),
  )
}

///|
test "text boxes are appended after their containing paragraph" {
  let result = @docx2html.convert_to_html(text_box_docx()[:])
  inspect(result.value, content="<p>Datum plane</p>")
  debug_inspect(result.messages, content="[]")
}

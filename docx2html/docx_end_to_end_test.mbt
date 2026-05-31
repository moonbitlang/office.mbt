///|
test "convert_to_html reads single paragraph docx fixture" {
  let result = @docx2html.convert_to_html(single_paragraph_docx()[:])
  inspect(result.value, content="<p>Walking on imported air</p>")
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
test "convert_to_markdown reads docx text" {
  let result = @docx2html.convert_to_markdown(single_paragraph_docx()[:])
  inspect(result.value, content="Walking on imported air\n\n")
}

///|
test "simple list is converted to list elements" {
  let result = @docx2html.convert_to_html(simple_list_docx()[:])
  inspect(result.value, content="<ul><li>Apple</li><li>Banana</li></ul>")
}

///|
test "word tables are converted to html tables" {
  let result = @docx2html.convert_to_html(tables_docx()[:])
  inspect(
    result.value,
    content="<p>Above</p><table><tr><td><p>Top left</p></td><td><p>Top right</p></td></tr><tr><td><p>Bottom left</p></td><td><p>Bottom right</p></td></tr></table><p>Below</p>",
  )
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
test "inline images referenced relative to document part are included" {
  let result = @docx2html.convert_to_html(tiny_picture_docx()[:])
  inspect(
    result.value,
    content="<p><img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=\" /></p>",
  )
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
      include_embedded_style_map=false,
    ).value,
    content="<p>Walking on imported air</p>",
  )
}

///|
test "text boxes are appended after their containing paragraph" {
  let result = @docx2html.convert_to_html(text_box_docx()[:])
  inspect(result.value, content="<p>Datum plane</p>")
  debug_inspect(result.messages, content="[]")
}

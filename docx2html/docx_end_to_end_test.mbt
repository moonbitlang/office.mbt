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

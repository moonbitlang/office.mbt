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

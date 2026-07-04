///|
fn PdfDocument::pdf_tweak_black_text_page(
  self : PdfDocument,
  page : @page.PdfPage,
  colour : @colour.PdfContentColour,
) -> @page.PdfPage raise @core.PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_text_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_text_xobject(
  colour : @colour.PdfContentColour,
  document : PdfDocument,
  resources : @syntax.PdfObject,
  streams : ArrayView[@syntax.PdfObject],
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_text_ops(colour, ops))]
}

///|
fn PdfDocument::pdf_tweak_black_lines_page(
  self : PdfDocument,
  page : @page.PdfPage,
  colour : @colour.PdfContentColour,
) -> @page.PdfPage raise @core.PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_lines_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_lines_xobject(
  colour : @colour.PdfContentColour,
  document : PdfDocument,
  resources : @syntax.PdfObject,
  streams : ArrayView[@syntax.PdfObject],
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_lines_ops(colour, ops))]
}

///|
fn PdfDocument::pdf_tweak_black_fills_page(
  self : PdfDocument,
  page : @page.PdfPage,
  colour : @colour.PdfContentColour,
) -> @page.PdfPage raise @core.PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_fills_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_fills_xobject(
  colour : @colour.PdfContentColour,
  document : PdfDocument,
  resources : @syntax.PdfObject,
  streams : ArrayView[@syntax.PdfObject],
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_fills_ops(colour, ops))]
}

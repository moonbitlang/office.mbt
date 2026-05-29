///|
/// Remove text rendering-mode operators so hidden text is rendered normally.
pub fn pdf_reveal_hidden_text_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_Tr(_) => ()
      _ => output.push(op)
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_reveal_hidden_text_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_reveal_hidden_text_ops(ops))],
  }
}

///|
fn pdf_tweak_reveal_hidden_text_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_reveal_hidden_text_ops(ops))]
}

///|
/// Reveal hidden text on selected one-based pages and their Form XObjects.
///
/// This ports the `cpdftweak.ml` reveal-hidden-text behavior by removing all
/// `Tr` text rendering-mode operators from selected content streams.
pub fn PdfDocument::reveal_hidden_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, pdf_tweak_reveal_hidden_text_xobject)
      rewritten.push(document.pdf_tweak_reveal_hidden_text_page(page))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::reveal_hidden_text`.
pub fn pdf_reveal_hidden_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.reveal_hidden_text(page_numbers)
}

///|
/// Compatibility wrapper matching cpdftweak's `reveal_hidden_text` argument order.
pub fn pdf_reveal_hidden_text_cpdf_order(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.reveal_hidden_text(page_numbers)
}

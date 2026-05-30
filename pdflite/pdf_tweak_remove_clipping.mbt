///|
/// Remove clipping-path setup sequences from parsed content operators.
///
/// This ports `cpdftweak.ml`'s `remove_clipping_ops`: only the exact `W n`
/// sequence is rewritten, becoming just `n`.
pub fn pdf_remove_clipping_ops(
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = []
  let mut index = 0
  while index < ops.length() {
    if index + 1 < ops.length() && ops[index] == Op_W && ops[index + 1] == Op_n {
      output.push(Op_n)
      index += 2
    } else {
      output.push(ops[index])
      index += 1
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_remove_clipping_page(
  self : PdfDocument,
  page : @page.PdfPage,
) -> @page.PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  { ..page, content: [pdf_content_stream_of_ops(pdf_remove_clipping_ops(ops))] }
}

///|
fn pdf_tweak_remove_clipping_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_remove_clipping_ops(ops))]
}

///|
/// Remove clipping paths from selected one-based pages and their Form XObjects.
pub fn PdfDocument::remove_clipping(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, pdf_tweak_remove_clipping_xobject)
      rewritten.push(document.pdf_tweak_remove_clipping_page(page))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_clipping`.
pub fn pdf_remove_clipping(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_clipping(page_numbers)
}

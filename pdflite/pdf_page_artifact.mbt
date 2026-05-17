///|
fn PdfDocument::pdf_page_mark_all_as_artifact_streams(
  self : PdfDocument,
  resources : PdfObject,
  content : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = self.pdf_page_parse_content_ops(resources, content)
  let marked : Array[PdfContentOp] = [pdf_content_begin_artifact()]
  for op in ops {
    marked.push(op)
  }
  marked.push(pdf_content_end_artifact())
  [pdf_content_stream_of_ops(marked)]
}

///|
fn PdfDocument::pdf_page_mark_all_as_artifact_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let content = self.pdf_page_mark_all_as_artifact_streams(
    page.resources,
    page.content,
  )
  self.process_xobjects(page, fn(document, resources, streams) raise PdfError {
    document.pdf_page_mark_all_as_artifact_streams(resources, streams)
  })
  { ..page, content, }
}

///|
/// Mark every page content stream and referenced Form XObject as a PDF/UA artifact.
pub fn PdfDocument::mark_all_as_artifact(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let rewritten : Array[PdfPage] = []
  for page in document.pages_of_pagetree() {
    rewritten.push(document.pdf_page_mark_all_as_artifact_page(page))
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::mark_all_as_artifact`.
pub fn pdf_mark_all_as_artifact(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.mark_all_as_artifact()
}

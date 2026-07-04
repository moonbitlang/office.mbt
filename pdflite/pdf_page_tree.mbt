///|
/// Read the document page tree into `@page.PdfPage` records.
///
/// Inherited resources, media boxes, crop boxes, and rotation are resolved
/// while walking the tree. Malformed page-tree structure raises `@core.PdfError`.
pub fn PdfDocument::pages_of_pagetree(
  self : PdfDocument,
) -> Array[@page.PdfPage] raise @core.PdfError {
  let last_mediabox : Ref[@syntax.PdfObject] = {
    val: pdf_page_default_mediabox(),
  }
  self.pdf_pages_of_node(
    pdf_page_root_pages_node(self),
    None,
    None,
    None,
    Rotate0,
    last_mediabox,
    0,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::pages_of_pagetree`.
pub fn pdf_pages_of_pagetree(
  document : PdfDocument,
) -> Array[@page.PdfPage] raise @core.PdfError {
  document.pages_of_pagetree()
}

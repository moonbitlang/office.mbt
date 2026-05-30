///|
/// Typeset cpdftype elements into PDF pages and per-page tag metadata.
///
/// The input stream is numbered, laid out, and paginated before content
/// operators are emitted. The supplied document is mutated only for font and
/// annotation objects; callers can add the returned pages to a page tree.
pub fn PdfDocument::pdf_type_typeset(
  self : PdfDocument,
  process_struct_tree : Bool,
  lmargin : Double,
  rmargin : Double,
  tmargin : Double,
  bmargin : Double,
  paper : @geometry.PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeTypesetResult raise @core.PdfError {
  let numbered = pdf_type_number_tags(elements)
  let laid_out = pdf_type_layout(lmargin, rmargin, paper, numbered)
  let paginated = pdf_type_paginate(tmargin, bmargin, paper, laid_out)
  let page_height = @geometry.unit_points(paper.height(), paper.unit())
  let state = pdf_type_initial_state(lmargin, tmargin)
  for element in paginated {
    state.write_element(
      self, process_struct_tree, lmargin, tmargin, paper, page_height, element,
    )
  }
  state.write_page(self, process_struct_tree, paper)
  { pages: state.pages, tags: state.tags_out }
}

///|
/// Compatibility wrapper for `PdfDocument::pdf_type_typeset`.
pub fn pdf_type_typeset(
  document : PdfDocument,
  process_struct_tree : Bool,
  lmargin : Double,
  rmargin : Double,
  tmargin : Double,
  bmargin : Double,
  paper : @geometry.PaperSize,
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeTypesetResult raise @core.PdfError {
  document.pdf_type_typeset(
    process_struct_tree, lmargin, rmargin, tmargin, bmargin, paper, elements,
  )
}

///|
/// Compatibility wrapper matching cpdftype's `typeset` argument order.
pub fn pdf_type_typeset_cpdf_order(
  process_struct_tree : Bool,
  lmargin : Double,
  rmargin : Double,
  tmargin : Double,
  bmargin : Double,
  paper : @geometry.PaperSize,
  document : PdfDocument,
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeTypesetResult raise @core.PdfError {
  document.pdf_type_typeset(
    process_struct_tree, lmargin, rmargin, tmargin, bmargin, paper, elements,
  )
}

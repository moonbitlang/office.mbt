///|
/// Replace the document page tree with `pages`.
///
/// When `change_references` is true, page-object references in destinations,
/// actions, annotations, and bookmarks are rewritten from the old page set to
/// the new one. `matrices` can transform destination coordinates for pages
/// whose geometry changed, and `changes` can map old page serials to new
/// serials when page counts differ.
pub fn PdfDocument::change_pages(
  self : PdfDocument,
  pages : ArrayView[@page.PdfPage],
  change_references? : Bool = false,
  matrices? : ArrayView[(Int, @geometry.TransformMatrix)] = [],
  changes? : ArrayView[(Int, Int)] = [],
) -> PdfDocument raise PdfError {
  let old_page_numbers = self.page_reference_numbers()
  let pdf = self.copy()
  let page_root_number = pdf.add_pagetree(pages)
  ignore(pdf.add_root(page_root_number, []))
  if change_references {
    let new_page_numbers = pdf.page_reference_numbers()
    let reference_changes = if changes.length() > 0 {
      pdf_page_reference_changes_from_serials(
        old_page_numbers, new_page_numbers, changes,
      )
    } else if old_page_numbers.length() != new_page_numbers.length() {
      []
    } else {
      pdf_page_reference_changes(old_page_numbers, new_page_numbers)
    }
    pdf.pdf_page_renumber_references(reference_changes)
    if matrices.length() > 0 {
      pdf.pdf_page_transform_matrix_destinations(
        matrices,
        new_page_numbers,
        old_page_numbers.length() == new_page_numbers.length(),
      )
    } else {
      pdf
    }
  } else {
    pdf
  }
}

///|
/// Compatibility wrapper for `PdfDocument::change_pages`.
pub fn pdf_change_pages(
  change_references : Bool,
  document : PdfDocument,
  pages : ArrayView[@page.PdfPage],
  matrices? : ArrayView[(Int, @geometry.TransformMatrix)] = [],
  changes? : ArrayView[(Int, Int)] = [],
) -> PdfDocument raise PdfError {
  document.change_pages(pages, change_references~, matrices~, changes~)
}

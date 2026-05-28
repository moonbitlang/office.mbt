///|
fn PdfDocument::pdf_attach_remove_from_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let kept = match self.lookup_direct(pdf_attach_annots_key(), page.rest) {
    Some(PdfArray(annotations)) => {
      let kept : Array[PdfObject] = Array::new(capacity=annotations.length())
      for annotation in annotations {
        if !self.pdf_attach_is_file_attachment_annotation(annotation) {
          kept.push(annotation)
        }
      }
      kept
    }
    _ => []
  }
  {
    ..page,
    rest: page.rest.add_dict_entry(pdf_attach_annots_key(), PdfArray(kept)),
  }
}

///|
/// Remove document-level embedded files and page-level file attachment annotations.
///
/// The original document is left unchanged. Non-file-attachment annotations are
/// preserved.
pub fn PdfDocument::remove_attached_files(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for page in pages {
    rewritten.push(document.pdf_attach_remove_from_page(page))
  }
  let cleaned = document.change_pages(rewritten, change_references=true)
  ignore(
    cleaned.remove_chain([
      pdf_attach_root_key(),
      pdf_attach_names_key(),
      pdf_attach_embedded_files_key(),
    ]),
  )
  cleaned
}

///|
/// Compatibility wrapper for `PdfDocument::remove_attached_files`.
pub fn pdf_remove_attached_files(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_attached_files()
}

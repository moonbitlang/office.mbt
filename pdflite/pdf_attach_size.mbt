///|
fn PdfDocument::pdf_attach_document_size(
  self : PdfDocument,
) -> Int raise PdfError {
  let mut total = 0
  let catalog = self.catalog()
  match self.lookup_direct(pdf_attach_names_key(), catalog) {
    Some(names) =>
      match self.lookup_direct(pdf_attach_embedded_files_key(), names) {
        Some(tree) =>
          for entry in self.read_name_tree(tree) {
            total += self.pdf_attach_file_spec_raw_size(entry.1)
          }
        None => ()
      }
    None => ()
  }
  total
}

///|
fn PdfDocument::pdf_attach_page_size(self : PdfDocument) -> Int raise PdfError {
  let mut total = 0
  for page in self.pages_of_pagetree() {
    match self.lookup_direct(pdf_attach_annots_key(), page.rest) {
      Some(PdfArray(annotations)) =>
        for annotation in annotations {
          if self.pdf_attach_is_file_attachment_annotation(annotation) {
            match self.lookup_direct(pdf_attach_fs_key(), annotation) {
              Some(file_spec) =>
                total += self.pdf_attach_file_spec_raw_size(file_spec)
              None => ()
            }
          }
        }
      _ => ()
    }
  }
  total
}

///|
/// Return the total raw byte size of all embedded file attachment streams.
pub fn PdfDocument::size_attached_files(
  self : PdfDocument,
) -> Int raise PdfError {
  self.pdf_attach_document_size() + self.pdf_attach_page_size()
}

///|
/// Compatibility wrapper for `PdfDocument::size_attached_files`.
pub fn pdf_size_attached_files(document : PdfDocument) -> Int raise PdfError {
  document.size_attached_files()
}

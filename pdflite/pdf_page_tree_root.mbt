///|
fn pdf_page_root_entries_without_catalog_keys(
  object : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match object {
    PdfNull => []
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, _) = entry
        if key != pdf_page_type_key() && key != pdf_page_pages_key() {
          output.push(entry)
        }
      }
      output
    }
    _ => raise DictionaryExpected
  }
}

///|
/// Add or replace the catalog root pointing at a page-tree root.
///
/// Existing catalog entries are preserved except `/Type` and `/Pages`; `extras`
/// can add or replace other catalog entries. The document trailer `/Root` is
/// updated and the document is mutated in place.
pub fn PdfDocument::add_root(
  self : PdfDocument,
  page_root_number : Int,
  extras : ArrayView[(PdfName, PdfObject)],
) -> Int raise PdfError {
  let mut root = PdfDictionary([
    (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
    (pdf_page_pages_key(), PdfIndirect(page_root_number)),
  ])
  let current_root = match self.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => PdfNull
  }
  for entry in pdf_page_root_entries_without_catalog_keys(current_root) {
    let (key, value) = entry
    root = root.add_dict_entry(key, value)
  }
  for entry in extras {
    let (key, value) = entry
    if key != pdf_page_type_key() && key != pdf_page_pages_key() {
      root = root.add_dict_entry(key, value)
    }
  }
  let root_number = self.add_object(root)
  self.set_root(root_number)
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_page_root_key(), PdfIndirect(root_number)),
  )
  root_number
}

///|
/// Copy a document, add a catalog root, and return the copy.
pub fn pdf_add_root(
  page_root_number : Int,
  extras : ArrayView[(PdfName, PdfObject)],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  let pdf = document.copy()
  ignore(pdf.add_root(page_root_number, extras))
  pdf
}

///|
/// Build the smallest useful PDF document: one blank A4 page and a catalog.
pub fn pdf_minimum_valid_pdf() -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let page_root_number = document.add_pagetree([pdf_page_blank(paper_a4)])
  ignore(document.add_root(page_root_number, []))
  document
}

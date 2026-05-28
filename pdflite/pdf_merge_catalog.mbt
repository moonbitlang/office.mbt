///|
fn pdf_merge_catalog_extra_key(key : PdfName) -> Bool {
  !(key == pdf_merge_type_key() ||
  key == pdf_merge_pages_key() ||
  key == pdf_merge_page_labels_key() ||
  key == pdf_merge_outlines_key() ||
  key == pdf_merge_dests_key() ||
  key == pdf_merge_names_key() ||
  key == pdf_merge_ocproperties_key() ||
  key == pdf_merge_acroform_key() ||
  key == pdf_merge_struct_tree_root_key() ||
  key == pdf_merge_open_action_key())
}

///|
fn pdf_merge_catalog_extra_entries(
  documents : ArrayView[PdfDocument],
) -> Array[(PdfName, PdfObject)] raise PdfError {
  let entries : Array[(PdfName, PdfObject)] = []
  let seen = pdf_merge_name_set()
  for document in documents {
    match document.pdf_merge_catalog() {
      PdfDictionary(root_entries) =>
        for entry in root_entries {
          let (key, _) = entry
          if pdf_merge_catalog_extra_key(key) && !seen.contains(key) {
            entries.push(entry)
            seen.add(key)
          }
        }
      _ => ()
    }
  }
  entries
}

///|
fn PdfDocument::pdf_merge_catalog_entry(
  self : PdfDocument,
  key : PdfName,
) -> PdfObject? raise PdfError {
  self.lookup_direct(key, self.pdf_merge_catalog())
}

///|
fn PdfDocument::pdf_merge_add_catalog_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
) -> PdfDocument raise PdfError {
  let root = self.pdf_merge_catalog()
  let new_root = self.add_object(root.add_dict_entry(key, value))
  self.set_root(new_root)
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_merge_root_key(), PdfIndirect(new_root)),
  )
  self
}

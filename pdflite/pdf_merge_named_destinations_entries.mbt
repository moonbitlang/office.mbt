///|
fn PdfDocument::pdf_merge_name_tree_entries(
  self : PdfDocument,
  tree_key : PdfName,
) -> Array[(PdfBytes, PdfObject)] raise PdfError {
  match self.pdf_merge_catalog_entry(pdf_merge_names_key()) {
    Some(names) =>
      match self.lookup_direct(tree_key, names) {
        Some(tree) => self.read_name_tree(tree)
        None => []
      }
    None => []
  }
}

///|
fn pdf_merge_name_dictionary_entries(
  documents : ArrayView[PdfDocument],
) -> Array[(PdfName, Array[(PdfBytes, PdfObject)])] raise PdfError {
  let output : Array[(PdfName, Array[(PdfBytes, PdfObject)])] = []
  for tree_key in pdf_merge_namedict_tree_keys() {
    let entries : Array[(PdfBytes, PdfObject)] = []
    for document in documents {
      for entry in document.pdf_merge_name_tree_entries(tree_key) {
        entries.push(entry)
      }
    }
    if entries.length() > 0 {
      output.push((tree_key, entries))
    }
  }
  output
}

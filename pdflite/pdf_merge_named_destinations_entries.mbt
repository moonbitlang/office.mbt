///|
fn PdfDocument::pdf_merge_name_tree_entries(
  self : PdfDocument,
  tree_key : @core.PdfName,
) -> Array[(@core.PdfBytes, @syntax.PdfObject)] raise @core.PdfError {
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
) -> Array[(@core.PdfName, Array[(@core.PdfBytes, @syntax.PdfObject)])] raise @core.PdfError {
  let output : Array[
    (@core.PdfName, Array[(@core.PdfBytes, @syntax.PdfObject)]),
  ] = []
  for tree_key in pdf_merge_namedict_tree_keys() {
    let entries : Array[(@core.PdfBytes, @syntax.PdfObject)] = []
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

///|
/// Merge several name trees when the caller guarantees there are no clashes.
///
/// Entries are read from every input tree and rebuilt into a single sorted name
/// tree. This function does not report duplicate keys; callers that require
/// conflict handling should check the inputs before calling it.
pub fn PdfDocument::merge_name_trees_no_clash(
  self : PdfDocument,
  trees : ArrayView[PdfObject],
) -> PdfObject {
  let entries : Array[(PdfBytes, PdfObject)] = Array::new(
    capacity=trees.length(),
  )
  for tree in trees {
    for entry in self.read_name_tree(tree) {
      entries.push(entry)
    }
  }
  self.build_name_tree(entries)
}

///|
/// Compatibility wrapper for `PdfDocument::merge_name_trees_no_clash`.
pub fn pdf_merge_name_trees_no_clash(
  document : PdfDocument,
  trees : ArrayView[PdfObject],
) -> PdfObject {
  document.merge_name_trees_no_clash(trees)
}

///|
/// Merge several number trees when the caller guarantees there are no clashes.
///
/// Entries are read from every input tree and rebuilt into a single sorted
/// number tree. Duplicate-key handling follows the read/build helpers and is
/// not reported as an error.
pub fn PdfDocument::merge_number_trees_no_clash(
  self : PdfDocument,
  trees : ArrayView[PdfObject],
) -> PdfObject {
  let entries : Array[(Int, PdfObject)] = Array::new(capacity=trees.length())
  for tree in trees {
    for entry in self.read_number_tree(tree) {
      entries.push(entry)
    }
  }
  self.build_number_tree(entries)
}

///|
/// Compatibility wrapper for `PdfDocument::merge_number_trees_no_clash`.
pub fn pdf_merge_number_trees_no_clash(
  document : PdfDocument,
  trees : ArrayView[PdfObject],
) -> PdfObject {
  document.merge_number_trees_no_clash(trees)
}

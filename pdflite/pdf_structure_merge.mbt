///|
fn PdfDocument::pdf_structure_merged_parent_tree_entries(
  self : PdfDocument,
  structure_tree_roots : ArrayView[@syntax.PdfObject],
) -> Array[(Int, @syntax.PdfObject)] {
  let entries : Array[(Int, @syntax.PdfObject)] = Array::new(
    capacity=structure_tree_roots.length(),
  )
  for root in structure_tree_roots {
    for entry in self.pdf_merge_structure_parent_tree_entries(root) {
      entries.push(entry)
    }
  }
  entries
}

///|
fn pdf_structure_tree_root_object_number(root : @syntax.PdfObject) -> Int {
  match root {
    PdfIndirect(number) => number
    _ => 0
  }
}

///|
/// Merge structure tree roots from source documents into a target document.
///
/// Returns the resulting structure-tree root object number, or `None` when no
/// source document has a structure tree. When multiple roots are merged, parent
/// trees and root metadata are combined in `document`; `add_toplevel_document`
/// wraps merged children in a PDF 2.0 top-level `/Document` structure element.
pub fn pdf_merge_structure_trees(
  document : PdfDocument,
  documents : ArrayView[PdfDocument],
  add_toplevel_document? : Bool = false,
) -> Int? raise PdfError {
  let structure_tree_roots = pdf_merge_structure_tree_roots(documents)
  let has_multiple_structure_roots = structure_tree_roots.length() > 1
  let parent_tree_entries : Array[(Int, @syntax.PdfObject)] = if has_multiple_structure_roots {
    document.pdf_structure_merged_parent_tree_entries(structure_tree_roots)
  } else {
    []
  }
  match
    document.pdf_merge_structure_tree_root(
      structure_tree_roots, parent_tree_entries, add_toplevel_document,
    ) {
    Some(root) => Some(pdf_structure_tree_root_object_number(root))
    None => None
  }
}

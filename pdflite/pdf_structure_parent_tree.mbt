///|
fn PdfDocument::pdf_structure_parent_tree_catalog(
  self : PdfDocument,
) -> PdfObject? {
  Some(self.catalog()) catch {
    _ => None
  }
}

///|
fn PdfDocument::pdf_structure_root_parent_tree_entries(
  self : PdfDocument,
) -> Array[(Int, PdfObject)] {
  match self.pdf_structure_parent_tree_catalog() {
    Some(catalog) =>
      match self.lookup_direct(pdf_structure_struct_tree_root_key(), catalog) {
        Some(root) =>
          match self.lookup_direct(pdf_structure_parent_tree_key(), root) {
            Some(parent_tree) => self.read_number_tree(parent_tree)
            None => []
          }
        None => []
      }
    None => []
  }
}

///|
fn pdf_structure_changed_parent_tree_key(
  changes : @hashmap.HashMap[Int, Int],
  old_key : Int,
) -> Int? {
  changes.get(old_key)
}

///|
fn pdf_structure_apply_parent_tree_changes(
  entries : ArrayView[(Int, PdfObject)],
  changes : ArrayView[(Int, Int)],
) -> Array[(Int, PdfObject)] {
  let change_map = pdf_merge_parent_tree_change_map(changes)
  let output : Array[(Int, PdfObject)] = Array::new(capacity=entries.length())
  for entry in entries {
    let (old_key, value) = entry
    match pdf_structure_changed_parent_tree_key(change_map, old_key) {
      Some(new_key) =>
        output.push(
          (new_key, pdf_merge_renumber_struct_parent_object(value, change_map)),
        )
      None => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_structure_replace_parent_tree(
  self : PdfDocument,
  parent_tree : PdfObject,
) -> Unit raise PdfError {
  match self.trailer_dict().lookup_immediate(pdf_structure_root_key()) {
    Some(root) =>
      if self.direct(root) != PdfNull {
        self.replace_chain(
          [
            pdf_structure_root_key(),
            pdf_structure_struct_tree_root_key(),
            pdf_structure_parent_tree_key(),
          ],
          parent_tree,
        )
      }
    None => {
      let catalog = self.lookup_object_or_null(self.root())
      match catalog.lookup_immediate(pdf_structure_struct_tree_root_key()) {
        Some(PdfIndirect(root_number)) => {
          let root = self.lookup_object_or_null(root_number)
          self.add_object_given_number(
            root_number,
            root.add_dict_entry(pdf_structure_parent_tree_key(), parent_tree),
          )
        }
        Some(root) =>
          self.add_object_given_number(
            self.root(),
            catalog.add_dict_entry(
              pdf_structure_struct_tree_root_key(),
              root.add_dict_entry(pdf_structure_parent_tree_key(), parent_tree),
            ),
          )
        None => ()
      }
    }
  }
}

///|
/// Renumber structure parent-tree keys across documents before merging.
///
/// The documents are mutated in place. Parent-tree keys are reassigned to a
/// single increasing sequence, and structure parent references inside each
/// document are updated to match the rebuilt number trees.
pub fn pdf_renumber_parent_trees(
  documents : ArrayView[PdfDocument],
) -> Unit raise PdfError {
  if documents.length() > 1 {
    let all_changes : Array[Array[(Int, Int)]] = Array::new(
      capacity=documents.length(),
    )
    let all_entries : Array[Array[(Int, PdfObject)]] = Array::new(
      capacity=documents.length(),
    )
    let mut next_key = 0
    for document in documents {
      let entries = document.pdf_structure_root_parent_tree_entries()
      let changes : Array[(Int, Int)] = Array::new(capacity=entries.length())
      for entry in entries {
        let (old_key, _) = entry
        changes.push((old_key, next_key))
        next_key += 1
      }
      all_entries.push(entries)
      all_changes.push(changes)
    }
    for index in 0..<documents.length() {
      let document = documents[index]
      let changes = all_changes[index]
      if changes.length() > 0 {
        document.pdf_merge_renumber_struct_parent_entries(changes)
        document.pdf_structure_replace_parent_tree(
          document.build_number_tree(
            pdf_structure_apply_parent_tree_changes(all_entries[index], changes),
          ),
        )
      }
    }
  }
}

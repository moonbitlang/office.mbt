///|
fn pdf_merge_structure_tree_roots(
  documents : ArrayView[PdfDocument],
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  let roots : Array[@syntax.PdfObject] = []
  for document in documents {
    match
      document
      .pdf_merge_catalog()
      .lookup_immediate(pdf_merge_struct_tree_root_key()) {
      Some(root) => roots.push(root)
      None => ()
    }
  }
  roots
}

///|
fn PdfDocument::pdf_merge_structure_tree_root_k_items(
  self : PdfDocument,
  root : @syntax.PdfObject,
) -> Array[@syntax.PdfObject] {
  match self.direct(root).lookup_immediate(pdf_merge_k_key()) {
    Some(PdfArray(items)) => [ for item in items => item ]
    Some(item) => [item]
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_structure_parent_tree_entries(
  self : PdfDocument,
  root : @syntax.PdfObject,
) -> Array[(Int, @syntax.PdfObject)] {
  match self.lookup_direct(pdf_merge_parent_tree_key(), root) {
    Some(parent_tree) => self.read_number_tree(parent_tree)
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_structure_name_tree_entries(
  self : PdfDocument,
  structure_tree_roots : ArrayView[@syntax.PdfObject],
  key : @core.PdfName,
) -> Array[(@core.PdfBytes, @syntax.PdfObject)] {
  let entries : Array[(@core.PdfBytes, @syntax.PdfObject)] = []
  for root in structure_tree_roots {
    match self.lookup_direct(key, root) {
      Some(tree) =>
        for entry in self.read_name_tree(tree) {
          entries.push(entry)
        }
      None => ()
    }
  }
  entries
}

///|
fn PdfDocument::pdf_merge_structure_dictionary(
  self : PdfDocument,
  structure_tree_roots : ArrayView[@syntax.PdfObject],
  key : @core.PdfName,
) -> @syntax.PdfObject? {
  let builder = pdf_merge_dictionary_builder()
  for root in structure_tree_roots {
    match self.lookup_direct(key, root) {
      Some(PdfDictionary(root_entries)) =>
        for entry in root_entries {
          let (entry_key, value) = entry
          builder.add_entry(entry_key, value)
        }
      _ => ()
    }
  }
  if builder.entries.length() > 0 {
    Some(PdfDictionary(builder.entries))
  } else {
    None
  }
}

///|
fn pdf_merge_object_member(
  objects : ArrayView[@syntax.PdfObject],
  object : @syntax.PdfObject,
) -> Bool {
  for existing in objects {
    if existing == object {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn PdfDocument::pdf_merge_structure_array(
  self : PdfDocument,
  structure_tree_roots : ArrayView[@syntax.PdfObject],
  key : @core.PdfName,
) -> Array[@syntax.PdfObject] {
  let values : Array[@syntax.PdfObject] = []
  for root in structure_tree_roots {
    match self.lookup_direct(key, root) {
      Some(PdfArray(items)) =>
        for item in items {
          if !pdf_merge_object_member(values, item) {
            values.push(item)
          }
        }
      _ => ()
    }
  }
  values
}

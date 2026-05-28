///|
fn pdf_merge_structure_tree_roots(
  documents : ArrayView[PdfDocument],
) -> Array[PdfObject] raise PdfError {
  let roots : Array[PdfObject] = []
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
  root : PdfObject,
) -> Array[PdfObject] {
  match self.direct(root).lookup_immediate(pdf_merge_k_key()) {
    Some(PdfArray(items)) => [ for item in items => item ]
    Some(item) => [item]
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_structure_parent_tree_entries(
  self : PdfDocument,
  root : PdfObject,
) -> Array[(Int, PdfObject)] {
  match self.lookup_direct(pdf_merge_parent_tree_key(), root) {
    Some(parent_tree) => self.read_number_tree(parent_tree)
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_structure_name_tree_entries(
  self : PdfDocument,
  structure_tree_roots : ArrayView[PdfObject],
  key : PdfName,
) -> Array[(PdfBytes, PdfObject)] {
  let entries : Array[(PdfBytes, PdfObject)] = []
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
  structure_tree_roots : ArrayView[PdfObject],
  key : PdfName,
) -> PdfObject? {
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
  objects : ArrayView[PdfObject],
  object : PdfObject,
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
  structure_tree_roots : ArrayView[PdfObject],
  key : PdfName,
) -> Array[PdfObject] {
  let values : Array[PdfObject] = []
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

///|
fn pdf_merge_parent_tree_change_map(
  changes : ArrayView[(Int, Int)],
) -> @hashmap.HashMap[Int, Int] {
  let values : @hashmap.HashMap[Int, Int] = HashMap([])
  for change in changes {
    let (old, replacement) = change
    if !values.contains(old) {
      values[old] = replacement
    }
  }
  values
}

///|
fn pdf_merge_changed_parent_tree_key(
  changes : @hashmap.HashMap[Int, Int],
  old_key : Int,
) -> Int? {
  changes.get(old_key)
}

///|
fn pdf_merge_renumber_struct_parent_object(
  object : PdfObject,
  changes : @hashmap.HashMap[Int, Int],
) -> PdfObject {
  match object {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        if key == pdf_merge_struct_parent_key() ||
          key == pdf_merge_struct_parents_key() {
          match value {
            PdfInteger(old_key) =>
              match pdf_merge_changed_parent_tree_key(changes, old_key) {
                Some(new_key) => output.push((key, PdfInteger(new_key)))
                None => output.push(entry)
              }
            _ =>
              output.push(
                (key, pdf_merge_renumber_struct_parent_object(value, changes)),
              )
          }
        } else {
          output.push(
            (key, pdf_merge_renumber_struct_parent_object(value, changes)),
          )
        }
      }
      PdfDictionary(output)
    }
    PdfArray(items) =>
      PdfArray(
        [
          for item in items => {
            pdf_merge_renumber_struct_parent_object(item, changes)
          }
        ],
      )
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_merge_renumber_struct_parent_object(
          stream.dictionary,
          changes,
        ),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn pdf_merge_renumber_struct_parent_entry(
  entry : PdfObjectEntry,
  changes : @hashmap.HashMap[Int, Int],
) -> PdfObjectEntry {
  match entry.data {
    ObjectParsed(object) =>
      {
        data: ObjectParsed(
          pdf_merge_renumber_struct_parent_object(object, changes),
        ),
        generation: entry.generation,
      }
    ObjectParsedAlreadyDecrypted(object) =>
      {
        data: ObjectParsedAlreadyDecrypted(
          pdf_merge_renumber_struct_parent_object(object, changes),
        ),
        generation: entry.generation,
      }
    _ => { data: entry.data, generation: entry.generation }
  }
}

///|
fn PdfDocument::pdf_merge_renumber_struct_parent_entries(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> Unit {
  if changes.length() > 0 {
    let change_map = pdf_merge_parent_tree_change_map(changes)
    for number in self.object_numbers() {
      let entry = self.objects.get_entry(number).unwrap()
      self.objects.set_entry(
        number,
        pdf_merge_renumber_struct_parent_entry(entry, change_map),
      )
    }
  }
}

///|
fn pdf_merge_renumber_parent_trees(
  documents : ArrayView[PdfDocument],
) -> Array[(Int, PdfObject)] raise PdfError {
  let merged_entries : Array[(Int, PdfObject)] = []
  let mut next_key = 0
  for document in documents {
    let changes : Array[(Int, Int)] = []
    for root in pdf_merge_structure_tree_roots([document]) {
      for entry in document.pdf_merge_structure_parent_tree_entries(root) {
        let (old_key, value) = entry
        changes.push((old_key, next_key))
        merged_entries.push((next_key, value))
        next_key += 1
      }
    }
    document.pdf_merge_renumber_struct_parent_entries(changes)
  }
  merged_entries
}

///|
fn PdfDocument::pdf_merge_structure_parented_item(
  self : PdfDocument,
  item : PdfObject,
  parent_number : Int,
) -> PdfObject raise PdfError {
  match item {
    PdfIndirect(number) => {
      let object = self.lookup_object_or_null(number)
      match object {
        PdfDictionary(_) | PdfStreamObject(_) =>
          self.add_object_given_number(
            number,
            object.add_dict_entry(
              pdf_merge_parent_key(),
              PdfIndirect(parent_number),
            ),
          )
        _ => ()
      }
      item
    }
    PdfDictionary(_) =>
      item.add_dict_entry(pdf_merge_parent_key(), PdfIndirect(parent_number))
    _ => item
  }
}

///|
fn PdfDocument::pdf_merge_structure_tree_root(
  self : PdfDocument,
  structure_tree_roots : ArrayView[PdfObject],
  parent_tree_entries : ArrayView[(Int, PdfObject)],
  add_toplevel_document : Bool,
) -> PdfObject? raise PdfError {
  if structure_tree_roots.length() == 0 {
    None
  } else if structure_tree_roots.length() == 1 {
    Some(structure_tree_roots[0])
  } else {
    let root_number = self.add_object(PdfNull)
    let kids : Array[PdfObject] = []
    for root in structure_tree_roots {
      for item in self.pdf_merge_structure_tree_root_k_items(root) {
        kids.push(self.pdf_merge_structure_parented_item(item, root_number))
      }
    }
    let entries : Array[(PdfName, PdfObject)] = [
      (pdf_merge_type_key(), PdfNameObject(pdf_merge_struct_tree_root_key())),
    ]
    let id_tree_entries = self.pdf_merge_structure_name_tree_entries(
      structure_tree_roots,
      pdf_merge_id_tree_key(),
    )
    if id_tree_entries.length() > 0 {
      entries.push(
        (pdf_merge_id_tree_key(), self.build_name_tree(id_tree_entries)),
      )
    }
    if parent_tree_entries.length() > 0 {
      entries.push(
        (
          pdf_merge_parent_tree_key(),
          self.build_number_tree(parent_tree_entries),
        ),
      )
    }
    match
      self.pdf_merge_structure_dictionary(
        structure_tree_roots,
        pdf_merge_role_map_key(),
      ) {
      Some(role_map) => entries.push((pdf_merge_role_map_key(), role_map))
      None => ()
    }
    match
      self.pdf_merge_structure_dictionary(
        structure_tree_roots,
        pdf_merge_class_map_key(),
      ) {
      Some(class_map) => entries.push((pdf_merge_class_map_key(), class_map))
      None => ()
    }
    let namespaces = self.pdf_merge_structure_array(
      structure_tree_roots,
      pdf_merge_namespaces_key(),
    )
    let pdf2_namespace_number = if add_toplevel_document {
      let number = self.add_object(
        PdfDictionary([
          (
            pdf_merge_ns_key(),
            PdfString(@ascii.encode("http://iso.org/pdf2/ssn")),
          ),
        ]),
      )
      namespaces.insert(0, PdfIndirect(number))
      Some(number)
    } else {
      None
    }
    if namespaces.length() > 0 {
      entries.push((pdf_merge_namespaces_key(), PdfArray(namespaces)))
    }
    let lexicon = self.pdf_merge_structure_array(
      structure_tree_roots,
      pdf_merge_pronunciation_lexicon_key(),
    )
    if lexicon.length() > 0 {
      entries.push((pdf_merge_pronunciation_lexicon_key(), PdfArray(lexicon)))
    }
    let af = self.pdf_merge_structure_array(
      structure_tree_roots,
      pdf_merge_af_key(),
    )
    if af.length() > 0 {
      entries.push((pdf_merge_af_key(), PdfArray(af)))
    }
    if kids.length() > 0 {
      let root_k = match pdf2_namespace_number {
        Some(namespace_number) => {
          let top_level_number = self.add_object(
            PdfDictionary([
              (pdf_merge_ns_key(), PdfIndirect(namespace_number)),
              (pdf_merge_s_key(), PdfNameObject(pdf_merge_document_name)),
              (pdf_merge_parent_key(), PdfIndirect(root_number)),
              (pdf_merge_k_key(), pdf_structure_k_object(kids)),
            ]),
          )
          PdfIndirect(top_level_number)
        }
        None => pdf_structure_k_object(kids)
      }
      entries.push((pdf_merge_k_key(), root_k))
    }
    self.add_object_given_number(root_number, PdfDictionary(entries))
    Some(PdfIndirect(root_number))
  }
}

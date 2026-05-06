///|
fn pdf_structure_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_structure_pg_key_name : PdfName = pdf_structure_name("/Pg")

///|
fn pdf_structure_pg_key() -> PdfName {
  pdf_structure_pg_key_name
}

///|
let pdf_structure_obj_key_name : PdfName = pdf_structure_name("/Obj")

///|
fn pdf_structure_obj_key() -> PdfName {
  pdf_structure_obj_key_name
}

///|
let pdf_structure_root_key_name : PdfName = pdf_structure_name("/Root")

///|
fn pdf_structure_root_key() -> PdfName {
  pdf_structure_root_key_name
}

///|
let pdf_structure_struct_tree_root_key_name : PdfName = pdf_structure_name(
  "/StructTreeRoot",
)

///|
fn pdf_structure_struct_tree_root_key() -> PdfName {
  pdf_structure_struct_tree_root_key_name
}

///|
let pdf_structure_parent_tree_key_name : PdfName = pdf_structure_name(
  "/ParentTree",
)

///|
fn pdf_structure_parent_tree_key() -> PdfName {
  pdf_structure_parent_tree_key_name
}

///|
let pdf_structure_k_key_name : PdfName = pdf_structure_name("/K")

///|
fn pdf_structure_k_key() -> PdfName {
  pdf_structure_k_key_name
}

///|
priv struct PdfStructureNumberSet {
  values : @hashmap.HashMap[Int, Bool]
}

///|
fn pdf_structure_number_set(numbers : ArrayView[Int]) -> PdfStructureNumberSet {
  let values : @hashmap.HashMap[Int, Bool] = @hashmap.HashMap::new()
  for number in numbers {
    values[number] = true
  }
  { values, }
}

///|
fn PdfStructureNumberSet::contains(
  self : PdfStructureNumberSet,
  number : Int,
) -> Bool {
  self.values.contains(number)
}

///|
fn pdf_structure_push_unique_with_seen(
  numbers : Array[Int],
  seen : PdfStructureNumberSet,
  number : Int,
) -> Unit {
  if !seen.contains(number) {
    numbers.push(number)
    seen.values[number] = true
  }
}

///|
fn PdfDocument::pdf_structure_indirect_number(
  self : PdfDocument,
  object_number : Int,
  key : PdfName,
) -> Int? {
  match self.direct(PdfIndirect(object_number)).lookup_immediate(key) {
    Some(PdfIndirect(number)) => Some(number)
    _ => None
  }
}

///|
fn PdfDocument::pdf_structure_object_has_deleted_page_in_set(
  self : PdfDocument,
  object : PdfObject,
  deleted_pages : PdfStructureNumberSet,
) -> Bool {
  match self.direct(object).lookup_immediate(pdf_structure_pg_key()) {
    Some(PdfIndirect(page_number)) => deleted_pages.contains(page_number)
    _ => false
  }
}

///|
fn PdfDocument::pdf_structure_indirect_survives_in_set(
  self : PdfDocument,
  object_number : Int,
  deleted_pages : PdfStructureNumberSet,
) -> Bool {
  if self.lookup_object_or_null(object_number) == PdfNull {
    false
  } else {
    match
      (
        self.pdf_structure_indirect_number(
          object_number,
          pdf_structure_pg_key(),
        ),
        self.pdf_structure_indirect_number(
          object_number,
          pdf_structure_obj_key(),
        ),
      ) {
      (Some(page_number), _) if deleted_pages.contains(page_number) => false
      (_, Some(page_number)) if deleted_pages.contains(page_number) => false
      _ => true
    }
  }
}

///|
fn PdfDocument::pdf_structure_k_item_survives_in_set(
  self : PdfDocument,
  item : PdfObject,
  deleted_pages : PdfStructureNumberSet,
) -> Bool {
  match item {
    PdfIndirect(object_number) =>
      self.pdf_structure_indirect_survives_in_set(object_number, deleted_pages)
    _ => true
  }
}

///|
fn PdfDocument::pdf_structure_filter_k_items_in_set(
  self : PdfDocument,
  items : ArrayView[PdfObject],
  deleted_pages : PdfStructureNumberSet,
) -> Array[PdfObject]? {
  let output : Array[PdfObject] = []
  let mut changed = false
  for item in items {
    if self.pdf_structure_k_item_survives_in_set(item, deleted_pages) {
      output.push(item)
    } else {
      changed = true
    }
  }
  if changed {
    Some(output)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_structure_filtered_k_value_in_set(
  self : PdfDocument,
  object : PdfObject,
  deleted_pages : PdfStructureNumberSet,
) -> Array[PdfObject]? {
  match self.direct(object) {
    PdfDictionary(_) as dictionary =>
      match dictionary.lookup_immediate(pdf_structure_k_key()) {
        Some(PdfInteger(_)) => None
        Some(PdfIndirect(_) as child) =>
          self.pdf_structure_filter_k_items_in_set([child], deleted_pages)
        Some(PdfArray(children)) =>
          self.pdf_structure_filter_k_items_in_set(children, deleted_pages)
        _ => None
      }
    _ => None
  }
}

///|
fn pdf_structure_k_object(items : ArrayView[PdfObject]) -> PdfObject {
  if items.length() == 1 {
    items[0]
  } else {
    PdfArray([ for item in items => item ])
  }
}

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
  let output : Array[(Int, PdfObject)] = []
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
pub fn pdf_renumber_parent_trees(
  documents : ArrayView[PdfDocument],
) -> Unit raise PdfError {
  if documents.length() > 1 {
    let all_changes : Array[Array[(Int, Int)]] = []
    let all_entries : Array[Array[(Int, PdfObject)]] = []
    let mut next_key = 0
    for document in documents {
      let entries = document.pdf_structure_root_parent_tree_entries()
      let changes : Array[(Int, Int)] = []
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

///|
fn PdfDocument::pdf_structure_trim_deleted_pages(
  self : PdfDocument,
  deleted_page_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  if deleted_page_numbers.length() > 0 {
    let deleted_pages = pdf_structure_number_set(deleted_page_numbers)
    let mut changed = true
    while changed {
      changed = false
      let deletions : Array[Int] = []
      let deletion_seen = pdf_structure_number_set([])
      for object_number in self.object_numbers() {
        if self.pdf_structure_object_has_deleted_page_in_set(
            self.lookup_object_or_null(object_number),
            deleted_pages,
          ) {
          pdf_structure_push_unique_with_seen(
            deletions, deletion_seen, object_number,
          )
        }
      }
      for object_number in deletions {
        if self.lookup_object_or_null(object_number) != PdfNull {
          self.remove_object(object_number)
          changed = true
        }
      }
      let replacements : Array[(Int, PdfObject)] = []
      for object_number in self.object_numbers() {
        let object = self.lookup_object_or_null(object_number)
        match
          self.pdf_structure_filtered_k_value_in_set(object, deleted_pages) {
          Some([]) =>
            pdf_structure_push_unique_with_seen(
              deletions, deletion_seen, object_number,
            )
          Some(filtered) =>
            replacements.push(
              (
                object_number,
                object.replace_dict_entry(
                  pdf_structure_k_key(),
                  pdf_structure_k_object(filtered),
                ),
              ),
            )
          None => ()
        }
      }
      for object_number in deletions {
        if self.lookup_object_or_null(object_number) != PdfNull {
          self.remove_object(object_number)
          changed = true
        }
      }
      for replacement in replacements {
        let (object_number, object) = replacement
        if self.lookup_object_or_null(object_number) != PdfNull {
          self.add_object_given_number(object_number, object)
          changed = true
        }
      }
    }
  }
}

///|
pub fn PdfDocument::trim_structure_tree(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  let all_page_numbers = self.page_reference_numbers()
  let kept_page_numbers = pdf_page_select_numbers(
    all_page_numbers, page_numbers,
  )
  self.pdf_structure_trim_deleted_pages(
    pdf_page_deleted_numbers(all_page_numbers, kept_page_numbers),
  )
}

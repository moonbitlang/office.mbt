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
  object : @syntax.PdfObject,
  changes : @hashmap.HashMap[Int, Int],
) -> @syntax.PdfObject {
  match object {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, @syntax.PdfObject)] = []
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
) -> Array[(Int, @syntax.PdfObject)] raise PdfError {
  let merged_entries : Array[(Int, @syntax.PdfObject)] = []
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

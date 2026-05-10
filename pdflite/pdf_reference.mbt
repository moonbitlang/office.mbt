///|
fn pdf_reference_key_is_excluded(
  key : PdfName,
  no_follow_entries : ArrayView[PdfName],
) -> Bool {
  for excluded in no_follow_entries {
    if excluded == key {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_reference_dictionary_contains(
  entries : ArrayView[(PdfName, PdfObject)],
  marker : (PdfName, PdfObject),
) -> Bool {
  for entry in entries {
    if entry == marker {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_reference_should_follow_dictionary(
  entries : ArrayView[(PdfName, PdfObject)],
  no_follow_contains : ArrayView[(PdfName, PdfObject)],
) -> Bool {
  for marker in no_follow_contains {
    if pdf_reference_dictionary_contains(entries, marker) {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn PdfDocument::collect_referenced_object_numbers(
  self : PdfDocument,
  found : @hashmap.HashMap[Int, Bool],
  object : PdfObject,
  no_follow_entries : ArrayView[PdfName],
  no_follow_contains : ArrayView[(PdfName, PdfObject)],
) -> Unit {
  match object {
    PdfIndirect(number) =>
      if number > 0 && !found.contains(number) {
        let resolved = self.lookup_object_or_null(number)
        match resolved {
          PdfDictionary(entries) =>
            if pdf_reference_should_follow_dictionary(
                entries, no_follow_contains,
              ) {
              found[number] = true
              self.collect_referenced_object_numbers(
                found, resolved, no_follow_entries, no_follow_contains,
              )
            }
          _ => {
            found[number] = true
            self.collect_referenced_object_numbers(
              found, resolved, no_follow_entries, no_follow_contains,
            )
          }
        }
      }
    PdfArray(items) =>
      for item in items {
        self.collect_referenced_object_numbers(
          found, item, no_follow_entries, no_follow_contains,
        )
      }
    PdfDictionary(entries) =>
      for entry in entries {
        if !pdf_reference_key_is_excluded(entry.0, no_follow_entries) {
          self.collect_referenced_object_numbers(
            found,
            entry.1,
            no_follow_entries,
            no_follow_contains,
          )
        }
      }
    PdfStreamObject(stream) =>
      self.collect_referenced_object_numbers(
        found,
        stream.dictionary,
        no_follow_entries,
        no_follow_contains,
      )
    _ => ()
  }
}

///|
pub fn PdfDocument::referenced_object_numbers(
  self : PdfDocument,
  object : PdfObject,
  no_follow_entries? : ArrayView[PdfName] = [],
  no_follow_contains? : ArrayView[(PdfName, PdfObject)] = [],
) -> Array[Int] {
  let found : @hashmap.HashMap[Int, Bool] = @hashmap.HashMap([])
  self.collect_referenced_object_numbers(
    found, object, no_follow_entries, no_follow_contains,
  )
  let numbers = found.keys().to_array()
  numbers.sort()
  numbers
}

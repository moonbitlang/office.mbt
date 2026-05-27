///|
priv struct PdfPageReferenceMap {
  values : @hashmap.HashMap[Int, Int]
}

///|
fn pdf_page_reference_map(
  changes : ArrayView[(Int, Int)],
) -> PdfPageReferenceMap {
  let values : @hashmap.HashMap[Int, Int] = HashMap([])
  for change in changes {
    let (old_number, new_number) = change
    if !values.contains(old_number) {
      values[old_number] = new_number
    }
  }
  { values, }
}

///|
fn PdfPageReferenceMap::changed_reference(
  self : PdfPageReferenceMap,
  number : Int,
) -> Int {
  match self.values.get(number) {
    Some(new_number) => new_number
    None => number
  }
}

///|
fn pdf_page_renumber_object_with_map(
  object : PdfObject,
  changes : PdfPageReferenceMap,
) -> PdfObject {
  match object {
    PdfIndirect(number) => PdfIndirect(changes.changed_reference(number))
    PdfArray(items) => {
      let output : Array[PdfObject] = Array::new(capacity=items.length())
      for item in items {
        output.push(pdf_page_renumber_object_with_map(item, changes))
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, value) = entry
        output.push((key, pdf_page_renumber_object_with_map(value, changes)))
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_page_renumber_object_with_map(
          stream.dictionary,
          changes,
        ),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn pdf_page_renumber_entry_with_map(
  entry : PdfObjectEntry,
  changes : PdfPageReferenceMap,
) -> PdfObjectEntry {
  match entry.data {
    ObjectParsed(object) =>
      {
        data: ObjectParsed(pdf_page_renumber_object_with_map(object, changes)),
        generation: entry.generation,
      }
    ObjectParsedAlreadyDecrypted(object) =>
      {
        data: ObjectParsedAlreadyDecrypted(
          pdf_page_renumber_object_with_map(object, changes),
        ),
        generation: entry.generation,
      }
    _ => { data: entry.data, generation: entry.generation }
  }
}

///|
fn PdfDocument::pdf_page_renumber_references(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> Unit {
  let change_map = pdf_page_reference_map(changes)
  for number in self.object_numbers() {
    let entry = self.objects.get_entry(number).unwrap()
    self.objects.set_entry(
      number,
      pdf_page_renumber_entry_with_map(entry, change_map),
    )
  }
}

///|
fn pdf_page_reference_changes(
  old_numbers : ArrayView[Int],
  new_numbers : ArrayView[Int],
) -> Array[(Int, Int)] raise PdfError {
  if old_numbers.length() != new_numbers.length() {
    raise PageTreeExpected
  }
  let changes : Array[(Int, Int)] = Array::new(capacity=old_numbers.length())
  for i in 0..<old_numbers.length() {
    changes.push((old_numbers[i], new_numbers[i]))
  }
  changes
}

///|
fn pdf_page_reference_changes_from_serials(
  old_numbers : ArrayView[Int],
  new_numbers : ArrayView[Int],
  changes : ArrayView[(Int, Int)],
) -> Array[(Int, Int)] raise PdfError {
  let output : Array[(Int, Int)] = Array::new(capacity=changes.length())
  for change in changes {
    let (old_page, new_page) = change
    if old_page < 1 ||
      old_page > old_numbers.length() ||
      new_page < 1 ||
      new_page > new_numbers.length() {
      raise PageTreeExpected
    }
    output.push((old_numbers[old_page - 1], new_numbers[new_page - 1]))
  }
  output
}

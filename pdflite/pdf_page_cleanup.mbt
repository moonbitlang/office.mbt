///|
fn PdfDocument::pdf_page_object_numbers_in_map(
  self : PdfDocument,
) -> Array[Int] {
  let object_numbers = self.object_numbers()
  let page_numbers : Array[Int] = Array::new(capacity=object_numbers.length())
  for number in object_numbers {
    let object = self.lookup_object_or_null(number)
    match object.lookup_immediate(pdf_page_type_key()) {
      Some(PdfNameObject(name)) if name == pdf_page_type_page() =>
        page_numbers.push(number)
      _ => ()
    }
  }
  page_numbers
}

///|
fn pdf_page_nullify_references(
  object : PdfObject,
  deleted_pages : @number_set.PdfNumberSet,
) -> PdfObject {
  match object {
    PdfIndirect(number) if deleted_pages.contains(number) => PdfNull
    PdfArray(items) => {
      let output : Array[PdfObject] = Array::new(capacity=items.length())
      for item in items {
        output.push(pdf_page_nullify_references(item, deleted_pages))
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, value) = entry
        output.push((key, pdf_page_nullify_references(value, deleted_pages)))
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_page_nullify_references(
          stream.dictionary,
          deleted_pages,
        ),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn pdf_page_nullify_entry(
  entry : PdfObjectEntry,
  deleted_pages : @number_set.PdfNumberSet,
) -> PdfObjectEntry {
  match entry.data {
    ObjectParsed(object) =>
      {
        data: ObjectParsed(pdf_page_nullify_references(object, deleted_pages)),
        generation: entry.generation,
      }
    ObjectParsedAlreadyDecrypted(object) =>
      {
        data: ObjectParsedAlreadyDecrypted(
          pdf_page_nullify_references(object, deleted_pages),
        ),
        generation: entry.generation,
      }
    _ => { data: entry.data, generation: entry.generation }
  }
}

///|
fn PdfDocument::pdf_page_nullify_deleted_page_references(
  self : PdfDocument,
) -> Unit raise PdfError {
  let page_numbers = self.pdf_page_object_numbers_in_map()
  let active_page_numbers = self.page_reference_numbers()
  if page_numbers.length() != active_page_numbers.length() {
    let deleted_pages = pdf_page_deleted_numbers(
      page_numbers, active_page_numbers,
    )
    let deleted_page_set = @number_set.pdf_number_set(deleted_pages)
    for number in self.object_numbers() {
      let entry = self.objects.get_entry(number).unwrap()
      self.objects.set_entry(
        number,
        pdf_page_nullify_entry(entry, deleted_page_set),
      )
    }
  }
}

///|
fn PdfDocument::pdf_referenced_from_object(
  self : PdfDocument,
  found : @hashmap.HashMap[Int, Bool],
  object : PdfObject,
) -> Unit {
  match object {
    PdfIndirect(number) =>
      if number > 0 && !found.contains(number) {
        found[number] = true
        let resolved = self.lookup_object_or_null(number)
        if resolved != PdfNull {
          self.pdf_referenced_from_object(found, resolved)
        }
      }
    PdfArray(items) =>
      for item in items {
        self.pdf_referenced_from_object(found, item)
      }
    PdfDictionary(entries) =>
      for entry in entries {
        let (_, value) = entry
        self.pdf_referenced_from_object(found, value)
      }
    PdfStreamObject(stream) =>
      self.pdf_referenced_from_object(found, stream.dictionary)
    _ => ()
  }
}

///|
/// Remove objects that are no longer reachable from the trailer or root.
///
/// References to deleted pages are first nulled from destinations and actions.
/// The document is mutated in place.
pub fn PdfDocument::remove_unreferenced(
  self : PdfDocument,
) -> Unit raise PdfError {
  self.pdf_page_nullify_deleted_page_references()
  let found : @hashmap.HashMap[Int, Bool] = HashMap([])
  if self.trailer_dict().lookup_immediate(pdf_page_root_key()) is None &&
    self.root() > 0 {
    found[self.root()] = true
    self.pdf_referenced_from_object(
      found,
      self.lookup_object_or_null(self.root()),
    )
  }
  self.pdf_referenced_from_object(found, self.trailer_dict())
  let object_numbers = self.object_numbers()
  let to_remove : Array[Int] = Array::new(capacity=object_numbers.length())
  for number in object_numbers {
    if !found.contains(number) {
      to_remove.push(number)
    }
  }
  for number in to_remove {
    self.remove_object(number)
  }
}

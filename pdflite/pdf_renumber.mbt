///|
fn pdf_renumber_document_with_changes(
  document : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> PdfDocument raise PdfError {
  let output = document.copy()
  let old_numbers = output.object_numbers()
  let change_map = pdf_page_reference_map(changes)
  let entries : Array[(Int, PdfObjectEntry)] = []
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  for number in old_numbers {
    let new_number = change_map.changed_reference(number)
    if new_number < 1 || seen.contains(new_number) {
      raise InvalidObjectNumber(new_number)
    }
    seen[new_number] = true
    let entry = output.objects.get_entry(number).unwrap()
    entries.push(
      (new_number, pdf_page_renumber_entry_with_map(entry, change_map)),
    )
  }
  let objects = pdf_objects_of_entries(entries)
  for number in output.objects.object_stream_ids.keys() {
    if output.objects.object_map.contains(number) {
      let new_number = change_map.changed_reference(number)
      objects.object_stream_ids[new_number] = output.objects.object_stream_ids
        .get(number)
        .unwrap()
    }
  }
  {
    ..output,
    root: change_map.changed_reference(output.root()),
    objects,
    trailer_dict: pdf_page_renumber_object_with_map(
      output.trailer_dict(),
      change_map,
    ),
  }
}

///|
pub fn PdfDocument::renumber_objects(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> PdfDocument raise PdfError {
  pdf_renumber_document_with_changes(self, changes)
}

///|
pub fn PdfDocument::renumber_objects_compact(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let numbers = self.object_numbers()
  let changes : Array[(Int, Int)] = []
  for index, number in numbers {
    changes.push((number, index + 1))
  }
  pdf_renumber_document_with_changes(self, changes)
}

///|
pub fn PdfDocument::renumber_objects_by_offset(
  self : PdfDocument,
  offset : Int,
) -> PdfDocument raise PdfError {
  if offset < 0 {
    raise InvalidObjectNumber(offset)
  }
  if offset == 0 {
    self.copy()
  } else {
    let old_numbers = self.object_numbers()
    let changes : Array[(Int, Int)] = [
      for number in old_numbers => (number, number + offset)
    ]
    pdf_renumber_document_with_changes(self, changes)
  }
}

///|
pub fn pdf_renumber_documents(
  documents : ArrayView[PdfDocument],
) -> Array[PdfDocument] raise PdfError {
  let output : Array[PdfDocument] = []
  let mut base = 1
  for document in documents {
    let numbers = document.object_numbers()
    let changes : Array[(Int, Int)] = []
    for index, number in numbers {
      changes.push((number, base + index))
    }
    base += numbers.length()
    output.push(pdf_renumber_document_with_changes(document, changes))
  }
  output
}

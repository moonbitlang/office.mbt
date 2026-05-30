///|
priv struct PdfSqueezeDuplicateCandidate {
  number : Int
  object : @syntax.PdfObject
}

///|
fn pdf_squeeze_materialized_object(
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: stream.dictionary,
        data: StreamGot(@syntax.pdf_stream_data_bytes(stream.data)),
      })
    _ => object
  }
}

///|
fn pdf_squeeze_duplicate_candidate(
  number : Int,
  object : @syntax.PdfObject,
) -> PdfSqueezeDuplicateCandidate raise PdfError {
  { number, object: pdf_squeeze_materialized_object(object) }
}

///|
fn PdfDocument::pdf_squeeze_skip_duplicate_candidate(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_squeeze_type_key(), object) {
    Some(PdfNameObject(name)) if name == pdf_squeeze_page_name() => true
    _ =>
      match self.lookup_direct(pdf_squeeze_subtype_key(), object) {
        Some(PdfNameObject(name)) => pdf_squeeze_annotation_subtype(name)
        _ => false
      }
  }
}

///|
fn PdfDocument::pdf_squeeze_duplicate_object_changes(
  self : PdfDocument,
) -> Array[(Int, Int)] raise PdfError {
  let entries = self.parsed_object_entries()
  let unique : Array[PdfSqueezeDuplicateCandidate] = Array::new(
    capacity=entries.length(),
  )
  let changes : Array[(Int, Int)] = Array::new(capacity=entries.length())
  for entry in entries {
    let (number, _, object) = entry
    let candidate = pdf_squeeze_duplicate_candidate(number, object)
    if !self.pdf_squeeze_skip_duplicate_candidate(candidate.object) {
      let duplicate = for existing in unique {
        if existing.object == candidate.object {
          changes.push((candidate.number, existing.number))
          break true
        }
      } nobreak {
        false
      }
      if !duplicate {
        unique.push(candidate)
      }
    }
  }
  changes
}

///|
fn PdfDocument::pdf_squeeze_apply_duplicate_changes(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> Unit {
  if changes.length() > 0 {
    let change_map = pdf_page_reference_map(changes)
    self.pdf_page_renumber_references(changes)
    self.set_trailer_dict(
      pdf_page_renumber_object_with_map(self.trailer_dict(), change_map),
    )
    for change in changes {
      let (duplicate_number, _) = change
      self.remove_object(duplicate_number)
    }
  }
}

///|
fn PdfDocument::pdf_squeeze_prune_duplicate_objects_once(
  self : PdfDocument,
) -> Unit raise PdfError {
  self.pdf_squeeze_apply_duplicate_changes(
    self.pdf_squeeze_duplicate_object_changes(),
  )
}

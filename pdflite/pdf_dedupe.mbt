///|
priv struct PdfDuplicateStreamCandidate {
  number : Int
  dictionary : PdfObject
  data : BytesView
}

///|
fn pdf_duplicate_stream_candidate(
  number : Int,
  object : PdfObject,
) -> PdfDuplicateStreamCandidate? {
  match object {
    PdfStreamObject({ dictionary, data }) =>
      Some({ number, dictionary, data: try! pdf_stream_data_view(data) })
    _ => None
  }
}

///|
fn PdfDuplicateStreamCandidate::equals(
  self : PdfDuplicateStreamCandidate,
  other : PdfDuplicateStreamCandidate,
) -> Bool {
  self.dictionary == other.dictionary && self.data == other.data
}

///|
fn PdfDocument::pdf_duplicate_stream_changes(
  self : PdfDocument,
) -> Array[(Int, Int)] {
  let unique_streams_by_length : @hashmap.HashMap[
    Int,
    Array[PdfDuplicateStreamCandidate],
  ] = @hashmap.HashMap([])
  let changes : Array[(Int, Int)] = []
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    match pdf_duplicate_stream_candidate(number, object) {
      Some(candidate) => {
        let length = candidate.data.length()
        let unique_streams = match unique_streams_by_length.get(length) {
          Some(streams) => streams
          None => {
            let streams : Array[PdfDuplicateStreamCandidate] = []
            unique_streams_by_length[length] = streams
            streams
          }
        }
        let is_duplicate = for canonical in unique_streams {
          if canonical.equals(candidate) {
            changes.push((number, canonical.number))
            break true
          }
        } nobreak {
          false
        }
        if !is_duplicate {
          unique_streams.push(candidate)
        }
      }
      None => ()
    }
  }
  changes
}

///|
pub fn PdfDocument::remove_duplicate_fonts(self : PdfDocument) -> Unit {
  let changes = self.pdf_duplicate_stream_changes()
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
pub fn pdf_remove_duplicate_fonts(document : PdfDocument) -> Unit {
  document.remove_duplicate_fonts()
}

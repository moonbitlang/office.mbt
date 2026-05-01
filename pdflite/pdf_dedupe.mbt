///|
fn pdf_duplicate_stream_equal(left : PdfObject, right : PdfObject) -> Bool {
  match (left, right) {
    (
      PdfStreamObject(
        { dictionary: left_dictionary, data: StreamGot(left_data) }
      ),
      PdfStreamObject(
        { dictionary: right_dictionary, data: StreamGot(right_data) }
      ),
    ) => left_dictionary == right_dictionary && left_data == right_data
    _ => false
  }
}

///|
fn PdfDocument::pdf_duplicate_stream_changes(
  self : PdfDocument,
) -> Array[(Int, Int)] {
  let unique_streams : Array[(Int, PdfObject)] = []
  let changes : Array[(Int, Int)] = []
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    match object {
      PdfStreamObject({ data: StreamGot(_), .. }) => {
        let is_duplicate = for entry in unique_streams {
          let (canonical_number, canonical_object) = entry
          if pdf_duplicate_stream_equal(canonical_object, object) {
            changes.push((number, canonical_number))
            break true
          }
        } nobreak {
          false
        }
        if !is_duplicate {
          unique_streams.push((number, object))
        }
      }
      _ => ()
    }
  }
  changes
}

///|
pub fn PdfDocument::remove_duplicate_fonts(self : PdfDocument) -> Unit {
  let changes = self.pdf_duplicate_stream_changes()
  if changes.length() > 0 {
    self.pdf_page_renumber_references(changes)
    self.set_trailer_dict(
      pdf_page_renumber_object(self.trailer_dict(), changes),
    )
    for change in changes {
      let (duplicate_number, _) = change
      self.remove_object(duplicate_number)
    }
  }
}

///|
fn ByteCursor::read_reconstructed_xref_stream_section_at(
  self : ByteCursor,
  position : Int,
) -> (PdfXRefSection, Int) raise PdfError {
  self.seek_pdf_absolute(position)
  let section = self.read_pdf_xref_stream_section()
  (section, self.absolute_position())
}

///|
fn ByteCursor::read_reconstructed_classic_xref_section_at(
  self : ByteCursor,
  position : Int,
) -> (PdfXRefSection, Int) raise PdfError {
  self.seek_pdf_absolute(position)
  let section = self.read_pdf_xref_section()
  guard section.stream_object_number is None else { raise XRefExpected }
  (section, self.absolute_position())
}

///|
fn pdf_read_reconstructed_classic_xref_sections(
  data : BytesView,
) -> Array[(Int, PdfXRefSection)] {
  let sections : Array[(Int, PdfXRefSection)] = Array::new(capacity=1)
  let cursor = byte_cursor_of_view(data)
  let mut position = 0
  while position < data.length() {
    if pdf_view_matches_ascii_at(data, position, [120, 114, 101, 102]) {
      let parsed : Result[(PdfXRefSection, Int), Error] = try? cursor.read_reconstructed_classic_xref_section_at(
        position,
      )
      match parsed {
        Ok((section, next_position)) => {
          sections.push((position, section))
          position = next_position
        }
        Err(_) => position += 4
      }
    } else {
      position += 1
    }
  }
  sections
}

///|
fn pdf_read_reconstructed_xref_stream_sections(
  data : BytesView,
) -> Array[PdfXRefSection] {
  let sections : Array[PdfXRefSection] = Array::new(capacity=1)
  let cursor = byte_cursor_of_view(data)
  let mut position = 0
  while position < data.length() {
    if pdf_reader_reconstruction_indirect_header_at(data, position) {
      let parsed : Result[(PdfXRefSection, Int), Error] = try? cursor.read_reconstructed_xref_stream_section_at(
        position,
      )
      match parsed {
        Ok((section, next_position)) => {
          sections.push(section)
          position = next_position
        }
        Err(_) =>
          position = pdf_reader_reconstruction_skip_malformed_object(
            data, position,
          ).unwrap()
      }
    } else {
      position += 1
    }
  }
  sections
}

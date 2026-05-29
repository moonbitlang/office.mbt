///|
fn pdf_cursor_read_reconstructed_xref_stream_section_at(
  cursor : ByteCursor,
  position : Int,
) -> (PdfXRefSection, Int) raise PdfError {
  cursor.seek_absolute(position)
  let section = pdf_cursor_read_xref_stream_section(cursor)
  (section, cursor.absolute_position())
}

///|
fn pdf_cursor_read_reconstructed_classic_xref_section_at(
  cursor : ByteCursor,
  position : Int,
) -> (PdfXRefSection, Int) raise PdfError {
  cursor.seek_absolute(position)
  let section = pdf_cursor_read_xref_section(cursor)
  guard section.stream_object_number is None else { raise XRefExpected }
  (section, cursor.absolute_position())
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
      let parsed : Result[(PdfXRefSection, Int), Error] = try? pdf_cursor_read_reconstructed_classic_xref_section_at(
        cursor, position,
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
    if @reader.pdf_reader_reconstruction_indirect_header_at(data, position) {
      let parsed : Result[(PdfXRefSection, Int), Error] = try? pdf_cursor_read_reconstructed_xref_stream_section_at(
        cursor, position,
      )
      match parsed {
        Ok((section, next_position)) => {
          sections.push(section)
          position = next_position
        }
        Err(_) =>
          position = @reader.pdf_reader_reconstruction_skip_malformed_object(
            data, position,
          ).unwrap()
      }
    } else {
      position += 1
    }
  }
  sections
}

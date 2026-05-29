///|
fn pdf_cursor_read_reconstructed_trailer_at(
  cursor : ByteCursor,
  position : Int,
) -> PdfObject raise PdfError {
  cursor.seek_absolute(position)
  pdf_cursor_read_trailer_dictionary(cursor)
}

///|
fn pdf_cursor_read_reconstructed_xref_stream_trailer_at(
  cursor : ByteCursor,
  position : Int,
) -> PdfObject raise PdfError {
  cursor.seek_absolute(position)
  let parsed = pdf_cursor_read_reconstructed_indirect_prefix_at_current(cursor)
  match parsed.object {
    PdfDictionary(_) as dictionary =>
      if pdf_reader_xref_stream_type_ok(dictionary) {
        pdf_reader_stream_dictionary_without_xref_keys(dictionary)
      } else {
        raise XRefExpected
      }
    _ => raise XRefExpected
  }
}

///|
fn pdf_read_reconstructed_trailers(
  data : BytesView,
  include_xref_streams : Bool,
) -> Array[PdfObject] {
  let trailers : Array[PdfObject] = Array::new(capacity=1)
  let cursor = byte_cursor_of_view(data)
  for position in 0..<data.length() {
    if pdf_view_matches_ascii_at(data, position, [
        116, 114, 97, 105, 108, 101, 114,
      ]) {
      let trailer : Result[PdfObject, Error] = try? pdf_cursor_read_reconstructed_trailer_at(
        cursor, position,
      )
      match trailer {
        Ok(object) => trailers.push(object)
        Err(_) => ()
      }
    } else if include_xref_streams &&
      pdf_reader_reconstruction_indirect_header_at(data, position) {
      let trailer : Result[PdfObject, Error] = try? pdf_cursor_read_reconstructed_xref_stream_trailer_at(
        cursor, position,
      )
      match trailer {
        Ok(object) => trailers.push(object)
        Err(_) => ()
      }
    }
  }
  trailers
}

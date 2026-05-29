///|
fn pdf_read_reconstructed_xrefs(
  data : BytesView,
) -> Array[PdfClassicXRefEntry] raise PdfError {
  let xrefs : Array[PdfClassicXRefEntry] = Array::new(capacity=16)
  let cursor = byte_cursor_of_view(data)
  let xref_index = pdf_classic_xref_index(xrefs)
  let mut position = 0
  while position < data.length() {
    if pdf_reader_reconstruction_indirect_header_at(data, position) {
      cursor.seek_absolute(position)
      let parsed : Result[(PdfParsedIndirectObject, Int?), Error] = try? pdf_cursor_read_reconstructed_indirect_scan_candidate_at_current(
        cursor,
        xrefs,
        xref_index=Some(xref_index),
      )
      match parsed {
        Ok((object, next_position)) => {
          if object.number > 0 {
            let xref : PdfClassicXRefEntry = {
              object_number: object.number,
              offset: position,
              generation: object.generation,
              in_use: true,
              object_stream: None,
            }
            xrefs.push(xref)
            if !xref_index.entries.contains(xref.object_number) {
              xref_index.entries[xref.object_number] = xref
            }
          }
          match next_position {
            Some(next) if next > position => position = next
            _ => position += 1
          }
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
  xrefs
}

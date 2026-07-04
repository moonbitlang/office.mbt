///|
fn pdf_reader_startxref_root_uses_object_stream(
  data : BytesView,
) -> Bool raise @core.PdfError {
  let cursor = @core.byte_cursor_of_view(data)
  ignore(@reader.pdf_read_header_from_cursor(cursor))
  cursor.seek_absolute(@reader.pdf_read_startxref_position(cursor.view()))
  let section = pdf_cursor_read_xref_section(cursor)
  let root = match
    section.trailer.lookup_immediate(@reader.pdf_reader_root_name()) {
    Some(PdfIndirect(root)) => root
    _ => -1
  }
  for entry in section.entries {
    if entry.object_number == root && entry.in_use {
      match entry.object_stream {
        Some(_) => break true
        None => ()
      }
    }
  } nobreak {
    false
  }
}

///|
fn pdf_reader_startxref_root_uses_object_stream_or_false(
  data : BytesView,
) -> Bool {
  try pdf_reader_startxref_root_uses_object_stream(data) catch {
    _ => false
  } noraise {
    value => value
  }
}

///|
fn pdf_reader_startxref_object_stream_root_unusable(
  data : BytesView,
) -> Bool raise @core.PdfError {
  let cursor = @core.byte_cursor_of_view(data)
  ignore(@reader.pdf_read_header_from_cursor(cursor))
  cursor.seek_absolute(@reader.pdf_read_startxref_position(cursor.view()))
  let section = pdf_cursor_read_xref_section(cursor)
  match section.trailer.lookup_immediate(@reader.pdf_reader_root_name()) {
    Some(PdfIndirect(root)) =>
      match @reader.pdf_classic_xref_lookup(section.entries, root) {
        Some(entry) =>
          match entry.object_stream {
            Some(root_reference) =>
              match
                @reader.pdf_classic_xref_lookup(
                  section.entries,
                  root_reference.object_stream_number,
                ) {
                Some(entry) =>
                  match entry.object_stream {
                    Some(_) => true
                    None => {
                      let object_stream_xref = entry
                      let xref_index = @reader.pdf_classic_xref_index(
                        section.entries,
                      )
                      cursor.seek_absolute(object_stream_xref.offset)
                      let parsed = pdf_cursor_read_first_indirect_object_at_current(
                        cursor,
                        section.entries,
                        xref_index=Some(xref_index),
                      )
                      if parsed.number != root_reference.object_stream_number ||
                        parsed.generation != object_stream_xref.generation {
                        true
                      } else {
                        let document = pdf_document_empty()
                        document.load_object_given_number(
                          parsed.number,
                          parsed.object,
                          generation=parsed.generation,
                        )
                        let context = document.read_object_stream_context(
                          root_reference.object_stream_number,
                        )
                        let root_object = context.read_reference(root_reference)
                        root_object.0 != root
                      }
                    }
                  }
                None => true
              }
            None => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn pdf_reader_startxref_object_stream_root_unusable_or_true(
  data : BytesView,
) -> Bool {
  try pdf_reader_startxref_object_stream_root_unusable(data) catch {
    _ => true
  } noraise {
    value => value
  }
}

///|
fn pdf_reader_object_stream_error_allows_reconstruction(
  data : BytesView,
) -> Bool {
  if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
    !pdf_reader_startxref_object_stream_root_unusable_or_true(data)
  } else {
    true
  }
}

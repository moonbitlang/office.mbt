///|
fn PdfDocument::load_reconstructed_xref_stream_plain_objects(
  self : PdfDocument,
  data : BytesView,
  sections : ArrayView[PdfXRefSection],
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  let cursor = byte_cursor_of_view(data)
  let xref_stream_refs = @reader.pdf_reader_reconstruction_xref_stream_refs(
    sections,
  )
  let xref_stream_ref_set = @reader.pdf_reader_xref_stream_ref_set(
    xref_stream_refs,
  )
  let xref_index = pdf_classic_xref_index(xrefs)
  for xref in xrefs {
    match xref.object_stream {
      Some(_) => ()
      None =>
        if xref.in_use &&
          xref.object_number != 0 &&
          !xref_stream_ref_set.contains(xref.object_number, xref.offset) {
          try {
            cursor.seek_absolute(xref.offset)
            let parsed = pdf_cursor_read_first_indirect_object_at_current(
              cursor,
              xrefs,
              xref_index=Some(xref_index),
            )
            if parsed.number == xref.object_number &&
              parsed.generation == xref.generation {
              self.load_object_given_number(
                parsed.number,
                parsed.object,
                generation=parsed.generation,
              )
            }
          } catch {
            _ => ()
          }
        }
    }
  }
}

///|
fn PdfDocument::load_reconstructed_classic_xref_plain_objects(
  self : PdfDocument,
  data : BytesView,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  let cursor = byte_cursor_of_view(data)
  let xref_index = pdf_classic_xref_index(xrefs)
  for xref in xrefs {
    if xref.in_use && xref.object_number != 0 {
      try {
        cursor.seek_absolute(xref.offset)
        let parsed = pdf_cursor_read_first_indirect_object_at_current(
          cursor,
          xrefs,
          xref_index=Some(xref_index),
        )
        if parsed.number == xref.object_number &&
          parsed.generation == xref.generation {
          self.load_object_given_number(
            parsed.number,
            parsed.object,
            generation=parsed.generation,
          )
        }
      } catch {
        _ => ()
      }
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_embedded_objects(
  self : PdfDocument,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  for group in pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let context_result : Result[PdfObjectStreamContext, Error] = try? self.read_object_stream_context(
      object_stream_number,
    )
    match context_result {
      Ok(context) =>
        for entry in group.1 {
          let xref = entry.0
          let reference = entry.1
          if reference.object_stream_number == object_stream_number {
            try {
              let (object_number, object) = context.read_reference(reference)
              if object_number == xref.object_number {
                self.load_object_given_number(xref.object_number, object)
              }
            } catch {
              _ => ()
            }
          }
        }
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_physical_object_stream_members(
  self : PdfDocument,
) -> Unit {
  for object_stream_number in self.object_numbers() {
    let context_result : Result[PdfObjectStreamContext, Error] = try? self.read_object_stream_context(
      object_stream_number,
    )
    match context_result {
      Ok(context) =>
        for index in 0..<context.pairs.length() {
          let loaded_member : Result[(Int, PdfObject), Error] = try? context.read_reference({
              object_stream_number,
              index,
            },
          )
          match loaded_member {
            Ok((object_number, object)) =>
              if self.lookup_object_or_null(object_number) is PdfNull {
                self.load_object_given_number(object_number, object)
              }
            Err(_) => ()
          }
        }
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_embedded_objects_with_passwords(
  self : PdfDocument,
  xrefs : ArrayView[PdfClassicXRefEntry],
  user_password : BytesView?,
  owner_password : BytesView?,
) -> Unit {
  for group in pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let context_result : Result[(PdfObjectStreamContext, Bool), Error] = try? self.read_object_stream_context_with_passwords(
      object_stream_number, user_password, owner_password,
    )
    match context_result {
      Ok((context, already_decrypted)) =>
        for entry in group.1 {
          let xref = entry.0
          let reference = entry.1
          if reference.object_stream_number == object_stream_number {
            try {
              let (object_number, object) = context.read_reference(reference)
              if object_number == xref.object_number {
                if already_decrypted {
                  self.load_object_given_number_already_decrypted(
                    xref.object_number,
                    object,
                  )
                } else {
                  self.load_object_given_number(xref.object_number, object)
                }
              }
            } catch {
              _ => ()
            }
          }
        }
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_objects(
  self : PdfDocument,
  data : BytesView,
  sections : ArrayView[PdfXRefSection],
) -> Unit {
  let xrefs = @reader.pdf_reader_reconstruction_xref_stream_entries(sections)
  self.load_reconstructed_xref_stream_plain_objects(data, sections, xrefs)
  self.load_reconstructed_xref_stream_embedded_objects(xrefs)
}

///|
fn pdf_reconstructed_plain_xref_should_load(
  xref : PdfClassicXRefEntry,
  xref_stream_ref_set : @reader.PdfReaderXRefStreamRefSet?,
  skip_object_stream_entries : Bool,
) -> Bool {
  if !xref.in_use || xref.object_number == 0 {
    false
  } else {
    let object_stream_ok = !skip_object_stream_entries ||
      xref.object_stream is None
    let xref_stream_ok = match xref_stream_ref_set {
      Some(refs) => !refs.contains(xref.object_number, xref.offset)
      None => true
    }
    object_stream_ok && xref_stream_ok
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_plain_objects(
  self : PdfDocument,
  data : BytesView,
  sections : ArrayView[PdfXRefSection],
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  let xref_stream_refs = @reader.pdf_reader_reconstruction_xref_stream_refs(
    sections,
  )
  let xref_stream_ref_set = @reader.pdf_reader_xref_stream_ref_set(
    xref_stream_refs,
  )
  self.load_reconstructed_plain_xref_objects(
    data,
    xrefs,
    Some(xref_stream_ref_set),
    true,
  )
}

///|
fn PdfDocument::load_reconstructed_plain_xref_objects(
  self : PdfDocument,
  data : BytesView,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_stream_ref_set : @reader.PdfReaderXRefStreamRefSet?,
  skip_object_stream_entries : Bool,
) -> Unit {
  let xref_index = pdf_classic_xref_index(xrefs)
  let cursor = byte_cursor_of_view(data)
  for xref in xrefs {
    let should_load = pdf_reconstructed_plain_xref_should_load(
      xref, xref_stream_ref_set, skip_object_stream_entries,
    )
    if should_load {
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
fn PdfDocument::load_reconstructed_classic_xref_plain_objects(
  self : PdfDocument,
  data : BytesView,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  self.load_reconstructed_plain_xref_objects(data, xrefs, None, false)
}

///|
fn PdfDocument::load_reconstructed_object_xrefs(
  self : PdfDocument,
  data : BytesView,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_coverage : @reader.PdfReconstructedXRefCoverage,
) -> Unit {
  let cursor = byte_cursor_of_view(data)
  for xref in xrefs {
    let parsed_result : Result[PdfParsedIndirectObject, Error] = try? pdf_cursor_read_reconstructed_object_at(
      cursor,
      xref.offset,
      xrefs,
    )
    match parsed_result {
      Ok(parsed) =>
        if parsed.number > 0 &&
          parsed.number == xref.object_number &&
          parsed.generation == xref.generation &&
          !xref_coverage.contains(parsed.number, xref.offset) &&
          !@reader.pdf_reader_object_is_xref_stream(parsed.object) {
          self.load_object_given_number(
            parsed.number,
            parsed.object,
            generation=parsed.generation,
          )
        }
      Err(_) => ()
    }
  }
}

///|
fn PdfDocument::load_reconstructed_xref_stream_embedded_objects(
  self : PdfDocument,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  for group in @reader.pdf_reader_object_stream_groups(xrefs) {
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
  for group in @reader.pdf_reader_object_stream_groups(xrefs) {
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

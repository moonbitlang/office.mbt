///|
fn pdf_reconstructed_plain_xref_should_load(
  xref : @reader.PdfClassicXRefEntry,
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
  sections : ArrayView[@reader.PdfXRefSection],
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
) -> Unit raise @core.PdfError {
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
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  xref_stream_ref_set : @reader.PdfReaderXRefStreamRefSet?,
  skip_object_stream_entries : Bool,
) -> Unit {
  let xref_index = @reader.pdf_classic_xref_index(xrefs)
  let cursor = @core.byte_cursor_of_view(data)
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
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
) -> Unit {
  self.load_reconstructed_plain_xref_objects(data, xrefs, None, false)
}

///|
fn PdfDocument::load_reconstructed_object_xrefs(
  self : PdfDocument,
  data : BytesView,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  xref_coverage : @reader.PdfReconstructedXRefCoverage,
) -> Unit {
  let cursor = @core.byte_cursor_of_view(data)
  for xref in xrefs {
    let parsed_result : Result[@syntax.PdfParsedIndirectObject, Error] = try
      pdf_cursor_read_reconstructed_object_at(cursor, xref.offset, xrefs)
    catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
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

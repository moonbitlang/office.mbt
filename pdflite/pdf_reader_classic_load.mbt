///|
fn pdf_classic_plain_xref_should_load(
  xref : @reader.PdfClassicXRefEntry,
  xref_stream_ref_set : @reader.PdfReaderXRefStreamRefSet,
) -> Bool {
  xref.in_use &&
  xref.object_number != 0 &&
  xref.object_stream is None &&
  !xref_stream_ref_set.contains(xref.object_number, xref.offset)
}

///|
fn PdfDocument::load_classic_plain_xref_objects(
  self : PdfDocument,
  cursor : ByteCursor,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  xref_stream_refs : ArrayView[(Int, Int)],
) -> Unit raise PdfError {
  let xref_stream_ref_set = @reader.pdf_reader_xref_stream_ref_set(
    xref_stream_refs,
  )
  let xref_index = @reader.pdf_classic_xref_index(xrefs)
  for xref in xrefs {
    if pdf_classic_plain_xref_should_load(xref, xref_stream_ref_set) {
      cursor.seek_absolute(xref.offset)
      let parsed = pdf_cursor_read_first_indirect_object_at_current(
        cursor,
        xrefs,
        xref_index=Some(xref_index),
      )
      if parsed.number != xref.object_number ||
        parsed.generation != xref.generation {
        raise XRefEntryExpected
      }
      self.load_object_given_number(
        parsed.number,
        parsed.object,
        generation=parsed.generation,
      )
    }
  }
}

///|
fn PdfDocument::load_classic_object_stream_entries(
  self : PdfDocument,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  user_password : BytesView?,
  owner_password : BytesView?,
) -> Unit raise PdfError {
  for group in @reader.pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let (context, already_decrypted) = self.read_object_stream_context_with_passwords(
      object_stream_number, user_password, owner_password,
    )
    self.load_embedded_objects_from_context(
      group.1,
      object_stream_number,
      context,
      already_decrypted,
    )
  }
}

///|
fn PdfDocument::load_classic_xrefs(
  self : PdfDocument,
  cursor : ByteCursor,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  xref_stream_refs : ArrayView[(Int, Int)],
  user_password : BytesView?,
  owner_password : BytesView?,
) -> Unit raise PdfError {
  self.load_classic_plain_xref_objects(cursor, xrefs, xref_stream_refs)
  self.load_classic_object_stream_entries(xrefs, user_password, owner_password)
  self.sanitize_reader_trailer()
}

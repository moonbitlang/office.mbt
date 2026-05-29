///|
fn ByteCursor::read_reconstructed_object_at(
  self : ByteCursor,
  position : Int,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfParsedIndirectObject raise PdfError {
  self.seek_absolute(position)
  self.read_reconstructed_indirect_object_at_current(xrefs)
}

///|
fn ByteCursor::lex_reconstructed_indirect_object_tokens_at_current(
  self : ByteCursor,
) -> Array[PdfLexeme] raise PdfError {
  let start = self.absolute_position()
  let mut search = start
  let mut done = false
  let mut found = false
  let mut output : Array[PdfLexeme] = []
  while !done {
    let endobj = pdf_find_ascii_from(self.view(), search, [
      101, 110, 100, 111, 98, 106,
    ])
    let end = if endobj < 0 { self.length() } else { endobj + 6 }
    let cursor = byte_cursor_of_view(self.view_at_absolute(start, end - start))
    let tokens : Result[Array[PdfLexeme], Error] = try? pdf_cursor_lex_tokens(
      cursor,
    )
    match tokens {
      Ok(tokens) => {
        output = tokens
        self.seek_absolute(start + cursor.absolute_position())
        found = true
        done = true
      }
      Err(_) => if endobj < 0 { done = true } else { search = endobj + 1 }
    }
  }
  if found {
    output
  } else {
    raise ParseIndirectObjectExpected
  }
}

///|
fn ByteCursor::read_reconstructed_indirect_prefix_at_current(
  self : ByteCursor,
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _, _) = pdf_parse_indirect_object_segment_at(
    self.lex_reconstructed_indirect_object_tokens_at_current(),
    0,
  )
  object
}

///|
fn ByteCursor::read_reconstructed_indirect_scan_candidate_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index? : PdfClassicXRefIndex? = None,
) -> (PdfParsedIndirectObject, Int?) raise PdfError {
  let (object, _, complete) = pdf_parse_indirect_object_segment_at(
    self.lex_reconstructed_indirect_object_tokens_at_current(),
    0,
  )
  if complete {
    (object, Some(self.absolute_position()))
  } else if pdf_cursor_stopped_at_stream_candidate(self) {
    let length_result : Result[Int, Error] = try? pdf_cursor_resolve_classic_stream_length(
      self,
      object.object,
      xrefs,
      xref_index,
    )
    let stream = match length_result {
      Ok(length) =>
        pdf_cursor_finish_stream_object_with_length(
          self,
          object,
          length,
          defer_stream_data=true,
        )
      Err(_) => pdf_cursor_finish_malformed_stream_object(self, object)
    }
    (stream, Some(self.absolute_position()))
  } else {
    (object, None)
  }
}

///|
fn ByteCursor::read_reconstructed_indirect_object_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _) = self.read_reconstructed_indirect_scan_candidate_at_current(
    xrefs,
  )
  object
}

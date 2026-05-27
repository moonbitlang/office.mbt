///|
fn ByteCursor::lex_first_pdf_indirect_object_tokens(
  self : ByteCursor,
) -> Array[PdfLexeme] raise PdfError {
  let tokens : Array[PdfLexeme] = []
  let mut done = false
  while !done {
    match self.lex_pdf_token() {
      StopLexing | LexNone => done = true
      LexEndObj as token => {
        tokens.push(token)
        done = true
      }
      token => tokens.push(token)
    }
  }
  tokens
}

///|
fn ByteCursor::read_plain_indirect_object_at_current(
  self : ByteCursor,
) -> PdfParsedIndirectObject raise PdfError {
  let (objects, prefix) = pdf_parse_indirect_object_segments(
    self.lex_first_pdf_indirect_object_tokens(),
  )
  if objects.length() > 0 {
    objects[0]
  } else {
    match prefix {
      Some(prefix) =>
        if self.stopped_at_pdf_stream_candidate() {
          raise StreamLengthExpected
        } else {
          prefix
        }
      None => raise ParseIndirectObjectExpected
    }
  }
}

///|
fn ByteCursor::stopped_at_pdf_stream_candidate(self : ByteCursor) -> Bool {
  let position = self.absolute_position()
  self.matches_pdf_ascii_at(position, [115]) &&
  !self.matches_pdf_ascii_at(position, [
    115, 116, 97, 114, 116, 120, 114, 101, 102,
  ])
}

///|
fn ByteCursor::read_first_indirect_object_segment_at_current(
  self : ByteCursor,
) -> (PdfParsedIndirectObject, Bool) raise PdfError {
  let (object, _, complete) = pdf_parse_indirect_object_segment_at(
    self.lex_first_pdf_indirect_object_tokens(),
    0,
  )
  (object, complete)
}

///|
fn ByteCursor::resolve_classic_stream_length(
  self : ByteCursor,
  object : PdfObject,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index : PdfClassicXRefIndex?,
) -> Int raise PdfError {
  match object.lookup_immediate(pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    Some(PdfIndirect(number)) => {
      let xref = match xref_index {
        Some(index) => index.lookup(number)
        None => pdf_classic_xref_lookup(xrefs, number)
      }
      match xref {
        Some(xref) => {
          let saved_position = self.absolute_position()
          self.seek_pdf_absolute(xref.offset)
          let parsed_result : Result[(PdfParsedIndirectObject, Bool), Error] = try? self.read_first_indirect_object_segment_at_current()
          self.seek_pdf_absolute(saved_position)
          let (parsed, complete) = match parsed_result {
            Ok(parsed) => parsed
            Err(_) => raise StreamLengthExpected
          }
          if parsed.number != number || parsed.generation != xref.generation {
            raise XRefEntryExpected
          }
          if !complete {
            raise StreamLengthExpected
          }
          match parsed.object {
            PdfInteger(length) if length >= 0 => length
            _ => raise StreamLengthExpected
          }
        }
        None => raise StreamLengthExpected
      }
    }
    _ => raise StreamLengthExpected
  }
}

///|
fn ByteCursor::read_first_indirect_object_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index? : PdfClassicXRefIndex? = None,
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _, complete) = pdf_parse_indirect_object_segment_at(
    self.lex_first_pdf_indirect_object_tokens(),
    0,
  )
  if complete {
    object
  } else if !self.stopped_at_pdf_stream_candidate() {
    object
  } else {
    let length_result : Result[Int, Error] = try? self.resolve_classic_stream_length(
      object.object,
      xrefs,
      xref_index,
    )
    match length_result {
      Ok(length) =>
        self.finish_pdf_stream_object_with_length(
          object,
          length,
          defer_stream_data=true,
        )
      Err(_) => self.finish_pdf_malformed_stream_object(object)
    }
  }
}

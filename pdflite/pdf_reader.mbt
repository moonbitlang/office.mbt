///|
fn ByteCursor::read_pdf_xref_section(
  self : ByteCursor,
) -> PdfXRefSection raise PdfError {
  let position = self.absolute_position()
  if self.matches_pdf_ascii_at(position, [120, 114, 101, 102]) {
    let entries = self.read_pdf_classic_xref_entries()
    let trailer = self.read_pdf_trailer_dictionary()
    { entries, trailer, stream_object_number: None, stream_object_offset: None }
  } else {
    self.read_pdf_xref_stream_section()
  }
}

///|
fn ByteCursor::read_pdf_trailer_dictionary(
  self : ByteCursor,
) -> PdfObject raise PdfError {
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii([116, 114, 97, 105, 108, 101, 114], TrailerExpected)
  self.drop_pdf_whitespace()
  let object = pdf_parse_single_lexeme_object(self.lex_pdf_tokens())
  match object {
    PdfDictionary(_) => object
    _ => raise TrailerExpected
  }
}

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
fn ByteCursor::read_pdf_linearized_marker(
  self : ByteCursor,
) -> Bool raise PdfError {
  ignore(self.read_pdf_header())
  let parsed = self.read_plain_indirect_object_at_current()
  match parsed.object.lookup_immediate(pdf_reader_linearized_name()) {
    Some(PdfInteger(_)) | Some(PdfReal(_)) => true
    _ => false
  }
}

///|
fn pdf_read_was_linearized(data : BytesView) -> Bool {
  let result : Result[Bool, Error] = try? byte_cursor_of_view(data).read_pdf_linearized_marker()
  match result {
    Ok(value) => value
    Err(_) => false
  }
}

///|
/// Return whether the input appears to be a linearized PDF.
///
/// The check reads the first indirect object after the header and looks for a
/// numeric `/Linearized` entry. Parse failures are treated as `false`.
pub fn pdf_is_linearized(data : BytesView) -> Bool {
  pdf_read_was_linearized(data)
}

///|
/// Count document revisions by following xref `/Prev` links.
///
/// Revision `1` is the newest revision referenced by `startxref`; larger numbers
/// walk backward through older revisions. Linearized hint-table revisions are
/// excluded from the returned count.
pub fn pdf_revisions_from_view(data : BytesView) -> Int raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(cursor.read_pdf_header())
  let mut current_xref = pdf_read_startxref_position(data)
  let mut revisions = 0
  let mut done = false
  while !done {
    if revisions >= 1024 {
      raise XRefExpected
    }
    cursor.seek_pdf_absolute(current_xref)
    let section = cursor.read_pdf_xref_section()
    revisions += 1
    match pdf_trailer_prev_position(section.trailer) {
      Some(previous) => current_xref = previous
      None => done = true
    }
  }
  if pdf_is_linearized(data) && revisions > 1 {
    revisions - 1
  } else {
    revisions
  }
}

///|
/// Count document revisions from owned PDF bytes.
pub fn pdf_revisions_from_bytes(data : PdfBytes) -> Int raise PdfError {
  pdf_revisions_from_view(data)
}

///|
fn ByteCursor::resolve_classic_stream_length(
  self : ByteCursor,
  object : PdfObject,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index? : PdfClassicXRefIndex? = None,
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
      xref_index~,
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

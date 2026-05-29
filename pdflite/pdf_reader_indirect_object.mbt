///|
fn pdf_cursor_lex_first_indirect_object_tokens(
  cursor : ByteCursor,
) -> Array[PdfLexeme] raise PdfError {
  let tokens : Array[PdfLexeme] = []
  let mut done = false
  while !done {
    match pdf_cursor_lex_token(cursor) {
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
fn pdf_cursor_read_plain_indirect_object_at_current(
  cursor : ByteCursor,
) -> PdfParsedIndirectObject raise PdfError {
  let (objects, prefix) = @syntax.pdf_parse_indirect_object_segments(
    pdf_cursor_lex_first_indirect_object_tokens(cursor),
  )
  if objects.length() > 0 {
    objects[0]
  } else {
    match prefix {
      Some(prefix) =>
        if pdf_cursor_stopped_at_stream_candidate(cursor) {
          raise StreamLengthExpected
        } else {
          prefix
        }
      None => raise ParseIndirectObjectExpected
    }
  }
}

///|
fn pdf_cursor_stopped_at_stream_candidate(cursor : ByteCursor) -> Bool {
  let position = cursor.absolute_position()
  @syntax.pdf_cursor_matches_ascii_at(cursor, position, [115]) &&
  !@syntax.pdf_cursor_matches_ascii_at(cursor, position, [
    115, 116, 97, 114, 116, 120, 114, 101, 102,
  ])
}

///|
fn pdf_cursor_read_first_indirect_object_segment_at_current(
  cursor : ByteCursor,
) -> (PdfParsedIndirectObject, Bool) raise PdfError {
  let (object, _, complete) = @syntax.pdf_parse_indirect_object_segment_at(
    pdf_cursor_lex_first_indirect_object_tokens(cursor),
    0,
  )
  (object, complete)
}

///|
fn pdf_cursor_resolve_classic_stream_length(
  cursor : ByteCursor,
  object : PdfObject,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index : PdfClassicXRefIndex?,
) -> Int raise PdfError {
  match object.lookup_immediate(@reader.pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    Some(PdfIndirect(number)) => {
      let xref = match xref_index {
        Some(index) => index.lookup(number)
        None => pdf_classic_xref_lookup(xrefs, number)
      }
      match xref {
        Some(xref) => {
          let saved_position = cursor.absolute_position()
          cursor.seek_absolute(xref.offset)
          let parsed_result : Result[(PdfParsedIndirectObject, Bool), Error] = try? pdf_cursor_read_first_indirect_object_segment_at_current(
            cursor,
          )
          cursor.seek_absolute(saved_position)
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
fn pdf_cursor_read_first_indirect_object_at_current(
  cursor : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
  xref_index? : PdfClassicXRefIndex? = None,
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _, complete) = @syntax.pdf_parse_indirect_object_segment_at(
    pdf_cursor_lex_first_indirect_object_tokens(cursor),
    0,
  )
  if complete {
    object
  } else if !pdf_cursor_stopped_at_stream_candidate(cursor) {
    object
  } else {
    let length_result : Result[Int, Error] = try? pdf_cursor_resolve_classic_stream_length(
      cursor,
      object.object,
      xrefs,
      xref_index,
    )
    match length_result {
      Ok(length) =>
        pdf_cursor_finish_stream_object_with_length(
          cursor,
          object,
          length,
          defer_stream_data=true,
        )
      Err(_) => pdf_cursor_finish_malformed_stream_object(cursor, object)
    }
  }
}

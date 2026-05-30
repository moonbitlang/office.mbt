///|
fn pdf_cursor_read_reconstructed_object_at(
  cursor : ByteCursor,
  position : Int,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
) -> @syntax.PdfParsedIndirectObject raise PdfError {
  cursor.seek_absolute(position)
  pdf_cursor_read_reconstructed_indirect_object_at_current(cursor, xrefs)
}

///|
fn pdf_cursor_lex_reconstructed_indirect_object_tokens_at_current(
  cursor : ByteCursor,
) -> Array[@syntax.PdfLexeme] raise PdfError {
  let start = cursor.absolute_position()
  let mut search = start
  let mut done = false
  let mut found = false
  let mut output : Array[@syntax.PdfLexeme] = []
  while !done {
    let endobj = pdf_find_ascii_from(cursor.view(), search, [
      101, 110, 100, 111, 98, 106,
    ])
    let end = if endobj < 0 { cursor.length() } else { endobj + 6 }
    let segment = byte_cursor_of_view(
      cursor.view_at_absolute(start, end - start),
    )
    let tokens : Result[Array[@syntax.PdfLexeme], Error] = try? @syntax.pdf_cursor_lex_tokens(
      segment,
    )
    match tokens {
      Ok(tokens) => {
        output = tokens
        cursor.seek_absolute(start + segment.absolute_position())
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
fn pdf_cursor_read_reconstructed_indirect_prefix_at_current(
  cursor : ByteCursor,
) -> @syntax.PdfParsedIndirectObject raise PdfError {
  let (object, _, _) = @syntax.pdf_parse_indirect_object_segment_at(
    pdf_cursor_lex_reconstructed_indirect_object_tokens_at_current(cursor),
    0,
  )
  object
}

///|
fn pdf_cursor_read_reconstructed_indirect_scan_candidate_at_current(
  cursor : ByteCursor,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  xref_index? : @reader.PdfClassicXRefIndex? = None,
) -> (@syntax.PdfParsedIndirectObject, Int?) raise PdfError {
  let (object, _, complete) = @syntax.pdf_parse_indirect_object_segment_at(
    pdf_cursor_lex_reconstructed_indirect_object_tokens_at_current(cursor),
    0,
  )
  if complete {
    (object, Some(cursor.absolute_position()))
  } else if pdf_cursor_stopped_at_stream_candidate(cursor) {
    let length_result : Result[Int, Error] = try? pdf_cursor_resolve_classic_stream_length(
      cursor,
      object.object,
      xrefs,
      xref_index,
    )
    let stream = match length_result {
      Ok(length) =>
        pdf_cursor_finish_stream_object_with_length(
          cursor,
          object,
          length,
          defer_stream_data=true,
        )
      Err(_) => pdf_cursor_finish_malformed_stream_object(cursor, object)
    }
    (stream, Some(cursor.absolute_position()))
  } else {
    (object, None)
  }
}

///|
fn pdf_cursor_read_reconstructed_indirect_object_at_current(
  cursor : ByteCursor,
  xrefs : ArrayView[@reader.PdfClassicXRefEntry],
) -> @syntax.PdfParsedIndirectObject raise PdfError {
  let (object, _) = pdf_cursor_read_reconstructed_indirect_scan_candidate_at_current(
    cursor, xrefs,
  )
  object
}

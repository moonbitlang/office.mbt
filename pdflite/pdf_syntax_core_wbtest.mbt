// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "private stream data materialization reports invalid deferred slices" {
  let cursor = byte_cursor_of_bytes(@ascii.encode("abc"))
  let bad_position : Result[BytesView, Error] = try? @syntax.pdf_stream_data_view(
    StreamToGet(stream_to_get(cursor, -1, 1)),
  )
  guard bad_position is Err(PdfError::InvalidCursorPosition(-1)) else {
    fail("expected PdfError::InvalidCursorPosition")
  }

  let bad_length : Result[BytesView, Error] = try? @syntax.pdf_stream_data_view(
    StreamToGet(stream_to_get(cursor, 0, -1)),
  )
  guard bad_length is Err(PdfError::InvalidReadLength(-1)) else {
    fail("expected PdfError::InvalidReadLength")
  }

  let too_long : Result[BytesView, Error] = try? @syntax.pdf_stream_data_view(
    StreamToGet(stream_to_get(cursor, 2, 2)),
  )
  guard too_long is Err(PdfError::EndOfInput) else {
    fail("expected PdfError::EndOfInput")
  }
}

///|
test "private stream data no-crypt decrypt returns bytes" {
  let source = @ascii.encode("abc")
  let copied = @syntax.PdfStreamDataNoCrypt.decrypt(source)
  @test.assert_eq(copied, source)
}

///|
test "parser prefix helper reports malformed indirect prefixes" {
  @test.assert_eq(
    @syntax.pdf_lexeme_indirect_object_header_at(
      [LexInt(1), LexInt(0), LexObj],
      0,
    ),
    true,
  )
  @test.assert_eq(
    @syntax.pdf_lexeme_indirect_object_header_at(
      [LexInt(1), LexInt(0), LexNull],
      0,
    ),
    false,
  )
  let too_short : Result[PdfParsedIndirectObject, Error] = try? @syntax.pdf_parse_indirect_object_prefix_lexemes([
      LexInt(1),
      LexInt(0),
    ],
  )
  guard too_short is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected PdfError::ParseIndirectObjectExpected")
  }
  let bad_header : Result[PdfParsedIndirectObject, Error] = try? @syntax.pdf_parse_indirect_object_prefix_lexemes([
      LexInt(1),
      LexInt(0),
      LexNull,
    ],
  )
  guard bad_header is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected PdfError::ParseIndirectObjectExpected")
  }
  @test.assert_eq(
    try! @syntax.pdf_parse_indirect_object_prefix_lexemes([
      LexInt(2),
      LexInt(0),
      LexObj,
      LexEndObj,
    ]),
    { number: 2, generation: 0, object: PdfNull },
  )
}

///|
test "core byte-view helpers cover boundary cases through root facade" {
  let cursor = byte_cursor_of_bytes(@ascii.encode("abc"))
  let bad_seek : Result[Unit, Error] = try? cursor.seek_absolute(-1)
  guard bad_seek is Err(PdfError::InvalidCursorPosition(-1)) else {
    fail("expected PdfError::InvalidCursorPosition")
  }

  let view = @ascii.encode("abc")[:]
  @test.assert_eq(pdf_view_matches_ascii_at(view, -1, [97]), false)
  @test.assert_eq(pdf_view_matches_ascii_at(view, 2, [98, 99]), false)
  @test.assert_eq(pdf_find_last_ascii(view, []), 3)
  @test.assert_eq(pdf_find_last_ascii(view[:1], [97, 98]), -1)
  @test.assert_eq(pdf_find_last_ascii(view, [120]), -1)

  let empty_number : Result[Int, Error] = try? pdf_parse_ascii_int_view(
    Bytes::new(0),
  )
  guard empty_number is Err(PdfError::NumberExpected) else {
    fail("expected PdfError::NumberExpected")
  }
  let bad_number : Result[Int, Error] = try? pdf_parse_ascii_int_view(
    @ascii.encode("12a"),
  )
  guard bad_number is Err(PdfError::NumberExpected) else {
    fail("expected PdfError::NumberExpected")
  }
  let overflow_number : Result[Int, Error] = try? pdf_parse_ascii_int_view(
    @ascii.encode("2147483648"),
  )
  guard overflow_number is Err(PdfError::NumberExpected) else {
    fail("expected PdfError::NumberExpected")
  }
  @test.assert_eq(
    try! pdf_parse_ascii_int_view(@ascii.encode("2147483647")),
    2147483647,
  )
  @test.assert_eq(@syntax.pdf_number_view_int(Bytes::new(0)), None)
  @test.assert_eq(@syntax.pdf_number_view_int(@ascii.encode("+")), None)
  @test.assert_eq(@syntax.pdf_number_view_int(@ascii.encode("-")), None)
}

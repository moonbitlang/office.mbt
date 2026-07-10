// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "private stream data materialization reports invalid deferred slices" {
  let cursor = @core.byte_cursor_of_bytes(b"abc")
  let bad_position : Result[BytesView, Error] = try
    @syntax.pdf_stream_data_view(
      StreamToGet(@syntax.stream_to_get(cursor, -1, 1)),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_position is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected @core.PdfError::InvalidCursorPosition")
  }

  let bad_length : Result[BytesView, Error] = try
    @syntax.pdf_stream_data_view(
      StreamToGet(@syntax.stream_to_get(cursor, 0, -1)),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_length is Err(@core.PdfError::InvalidReadLength(-1)) else {
    fail("expected @core.PdfError::InvalidReadLength")
  }

  let too_long : Result[BytesView, Error] = try
    @syntax.pdf_stream_data_view(
      StreamToGet(@syntax.stream_to_get(cursor, 2, 2)),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard too_long is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput")
  }
}

///|
test "private stream data no-crypt decrypt returns bytes" {
  let source = b"abc"
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
  let too_short : Result[@syntax.PdfParsedIndirectObject, Error] = try
    @syntax.pdf_parse_indirect_object_prefix_lexemes([LexInt(1), LexInt(0)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard too_short is Err(@core.PdfError::ParseIndirectObjectExpected) else {
    fail("expected @core.PdfError::ParseIndirectObjectExpected")
  }
  let bad_header : Result[@syntax.PdfParsedIndirectObject, Error] = try
    @syntax.pdf_parse_indirect_object_prefix_lexemes([
      LexInt(1),
      LexInt(0),
      LexNull,
    ])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_header is Err(@core.PdfError::ParseIndirectObjectExpected) else {
    fail("expected @core.PdfError::ParseIndirectObjectExpected")
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
  let cursor = @core.byte_cursor_of_bytes(b"abc")
  let bad_seek : Result[Unit, Error] = try cursor.seek_absolute(-1) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_seek is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected @core.PdfError::InvalidCursorPosition")
  }

  let view = b"abc"[:]
  @test.assert_eq(@core.pdf_view_matches_ascii_at(view, -1, [97]), false)
  @test.assert_eq(@core.pdf_view_matches_ascii_at(view, 2, [98, 99]), false)
  @test.assert_eq(@core.pdf_find_last_ascii(view, []), 3)
  @test.assert_eq(@core.pdf_find_last_ascii(view[:1], [97, 98]), -1)
  @test.assert_eq(@core.pdf_find_last_ascii(view, [120]), -1)

  let empty_number : Result[Int, Error] = try
    @core.pdf_parse_ascii_int_view(Bytes::new(0))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard empty_number is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }
  let bad_number : Result[Int, Error] = try
    @core.pdf_parse_ascii_int_view(b"12a")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_number is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }
  let overflow_number : Result[Int, Error] = try
    @core.pdf_parse_ascii_int_view(b"2147483648")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard overflow_number is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }
  @test.assert_eq(
    try! @core.pdf_parse_ascii_int_view(b"2147483647"),
    2147483647,
  )
  @test.assert_eq(@syntax.pdf_number_view_int(Bytes::new(0)), None)
  @test.assert_eq(@syntax.pdf_number_view_int(b"+"), None)
  @test.assert_eq(@syntax.pdf_number_view_int(b"-"), None)
}

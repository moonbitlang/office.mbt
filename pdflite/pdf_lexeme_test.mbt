///|
fn lexeme_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn lexeme_view_to_ints_for_test(view : BytesView) -> Array[Int] {
  view.to_array().map(byte => byte.to_int())
}

///|
test "PDF byte predicates match CamlPDF whitespace and delimiters" {
  for value in [0, 9, 10, 12, 13, 32] {
    @test.assert_eq(@core.pdf_is_whitespace_byte(value), true)
  }
  @test.assert_eq(@core.pdf_is_newline_byte(10), true)
  @test.assert_eq(@core.pdf_is_newline_byte(13), true)
  @test.assert_eq(@core.pdf_is_newline_byte(32), false)
  for value in [40, 41, 47, 60, 62, 91, 93, 123, 125, 37] {
    @test.assert_eq(@core.pdf_is_delimiter_byte(value), true)
  }
  @test.assert_eq(@core.pdf_is_not_whitespace_byte(65), true)
  @test.assert_eq(@core.pdf_is_whitespace_or_delimiter_byte(47), true)
  @test.assert_eq(@core.pdf_is_whitespace_or_delimiter_byte(65), false)
}

///|
test "@syntax.pdf_cursor_drop_whitespace leaves delimiter untouched" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([32, 10, 47, 78, 97, 109, 101]),
  )
  @syntax.pdf_cursor_drop_whitespace(cursor)
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(cursor.peek_byte(), 47)
}

///|
test "@syntax.pdf_cursor_read_regular_token_view leaves delimiter untouched" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([32, 65, 66, 67, 47, 68]),
  )
  let view = @syntax.pdf_cursor_read_regular_token_view(cursor)
  @test.assert_eq(lexeme_view_to_ints_for_test(view), [65, 66, 67])
  @test.assert_eq(cursor.peek_byte(), 47)
  @test.assert_eq(cursor.position(), 4)
}

///|
test "@syntax.PdfLexeme token shape stores byte-oriented names and strings" {
  let name = @core.pdf_name_of_bytes(lexeme_bytes_for_test([47, 84, 121]))
  let string = lexeme_bytes_for_test([0, 255])
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexNull), "LexNull")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexBool(false)), "LexBool")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexName(name)), "LexName")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexString(string)), "LexString")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexInt(42)), "LexInt")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexReal(1.5)), "LexReal")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexEndStream), "LexEndStream")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexObj), "LexObj")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexEndObj), "LexEndObj")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(StopLexing), "StopLexing")
  @test.assert_eq(@syntax.pdf_lexeme_debug_name(LexNone), "LexNone")
}

///|
test "@syntax.pdf_string_of_lexeme mirrors CamlPDF debug token rendering" {
  let name = @core.pdf_name_of_bytes(lexeme_bytes_for_test([47, 78]))
  @test.assert_eq(@syntax.pdf_string_of_lexeme(LexInt(42)), "Int 42")
  @test.assert_eq(@syntax.pdf_string_of_lexeme(LexReal(1.5)), "Float 1.5")
  @test.assert_eq(
    @syntax.pdf_string_of_lexeme(LexString(lexeme_bytes_for_test([65, 66]))),
    "String AB",
  )
  @test.assert_eq(@syntax.pdf_string_of_lexeme(LexName(name)), "Ident /N")
  @test.assert_eq(@syntax.pdf_string_of_lexeme(LexNull), "Nothing")
  @test.assert_eq(@syntax.pdf_string_of_lexeme(LexBool(true)), "GenLexNone")
  @test.assert_eq(
    @syntax.pdf_string_of_lexemes([LexNull, LexInt(7), LexName(name)]),
    "\n Nothing\n Int 7\n Ident /N",
  )
}

///|
test "@syntax.pdf_cursor_lex_bool and @syntax.pdf_cursor_lex_number parse booleans and numbers" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      116, 114, 117, 101, 32, 45, 52, 50, 32, 46, 53, 32, 45, 45, 50,
    ]),
  )
  @test.assert_eq(@syntax.pdf_cursor_lex_bool(cursor), LexBool(true))
  @test.assert_eq(@syntax.pdf_cursor_lex_number(cursor), LexInt(-42))
  @test.assert_eq(@syntax.pdf_cursor_lex_number(cursor), LexReal(0.5))
  @test.assert_eq(@syntax.pdf_cursor_lex_number(cursor), LexInt(-2))
  @test.assert_eq(
    @syntax.pdf_cursor_lex_number(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([43, 49, 55])),
    ),
    LexInt(17),
  )
  @test.assert_eq(
    @syntax.pdf_cursor_lex_number(
      @core.byte_cursor_of_bytes(
        lexeme_bytes_for_test([45, 50, 49, 52, 55, 52, 56, 51, 54, 52, 56]),
      ),
    ),
    LexInt(-2147483648),
  )
  @test.assert_eq(
    @syntax.pdf_cursor_lex_number(
      @core.byte_cursor_of_bytes(
        lexeme_bytes_for_test([50, 49, 52, 55, 52, 56, 51, 54, 52, 55]),
      ),
    ),
    LexInt(2147483647),
  )
  let false_cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([102, 97, 108, 115, 101]),
  )
  @test.assert_eq(@syntax.pdf_cursor_lex_bool(false_cursor), LexBool(false))
  @test.assert_eq(
    @syntax.pdf_cursor_lex_number(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([])),
    ),
    LexNone,
  )
  @test.assert_eq(
    @syntax.pdf_cursor_lex_number(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([255])),
    ),
    LexNone,
  )
  @test.assert_eq(
    @syntax.pdf_cursor_lex_number(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([46])),
    ),
    LexNone,
  )
  @test.assert_eq(
    @syntax.pdf_cursor_lex_number(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([49, 65])),
    ),
    LexNone,
  )
  let huge_integer_cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57, 57,
      57, 57, 57, 57, 57, 57,
    ]),
  )
  let huge_integer = @syntax.pdf_cursor_lex_number(huge_integer_cursor)
  guard huge_integer is LexReal(_) else {
    fail("expected oversized integer to fall back to LexReal")
  }
  @test.assert_eq(
    @syntax.pdf_cursor_lex_bool(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([109, 97, 121, 98, 101])),
    ),
    LexNone,
  )
}

///|
test "@core.ByteCursor lexes PDF names as bytes including slash and hex escapes" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      47, 65, 35, 50, 48, 66, 35, 52, 49, 35, 54, 49, 35, 65, 70, 35, 97, 102, 32,
      47, 67,
    ]),
  )
  let first = try! @syntax.pdf_cursor_lex_name(cursor)
  guard first is LexName(name) else { fail("expected LexName") }
  @test.assert_eq(name.bytes().to_array().map(byte => byte.to_int()), [
    47, 65, 32, 66, 65, 97, 175, 175,
  ])
  @test.assert_eq(cursor.peek_byte(), 32)
  @syntax.pdf_cursor_drop_whitespace(cursor)
  let second = try! @syntax.pdf_cursor_lex_name(cursor)
  guard second is LexName(second_name) else { fail("expected second LexName") }
  @test.assert_eq(second_name.bytes().to_array().map(byte => byte.to_int()), [
    47, 67,
  ])
  @test.assert_eq(
    try! @syntax.pdf_cursor_lex_name(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([65])),
    ),
    LexNone,
  )
}

///|
test "@core.ByteCursor reports malformed PDF name hex escapes" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([47, 65, 35, 90, 90]),
  )
  let result : Result[@syntax.PdfLexeme, Error] = try
    @syntax.pdf_cursor_lex_name(cursor)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::InvalidHexEscape) else {
    fail("expected @core.PdfError::InvalidHexEscape")
  }
}

///|
test "@core.ByteCursor lexes PDF comments and leaves newline for whitespace scan" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([37, 65, 66, 13, 10, 49]),
  )
  @test.assert_eq(
    @syntax.pdf_cursor_lex_comment(cursor),
    LexComment(lexeme_bytes_for_test([])),
  )
  @test.assert_eq(cursor.peek_byte(), 13)
  @syntax.pdf_cursor_drop_whitespace(cursor)
  @test.assert_eq(@syntax.pdf_cursor_lex_number(cursor), LexInt(1))
  @test.assert_eq(
    @syntax.pdf_cursor_lex_comment(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([65])),
    ),
    LexNone,
  )
}

///|
test "@syntax.pdf_cursor_lex_literal_string lexes PDF literal strings as bytes" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      40, 65, 92, 110, 66, 92, 48, 53, 51, 92, 40, 67, 92, 41, 41, 32, 40, 120, 40,
      121, 41, 122, 41,
    ]),
  )
  let first = try! @syntax.pdf_cursor_lex_literal_string(cursor)
  guard first is LexString(first_bytes) else { fail("expected LexString") }
  @test.assert_eq(first_bytes.to_array().map(byte => byte.to_int()), [
    65, 10, 66, 43, 40, 67, 41,
  ])
  @syntax.pdf_cursor_drop_whitespace(cursor)
  let second = try! @syntax.pdf_cursor_lex_literal_string(cursor)
  guard second is LexString(second_bytes) else {
    fail("expected second LexString")
  }
  @test.assert_eq(second_bytes.to_array().map(byte => byte.to_int()), [
    120, 40, 121, 41, 122,
  ])
  let escapes = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      40, 92, 114, 92, 116, 92, 98, 92, 102, 92, 53, 65, 92, 53, 51, 65, 41,
    ]),
  )
  let escaped = try! @syntax.pdf_cursor_lex_literal_string(escapes)
  guard escaped is LexString(escaped_bytes) else {
    fail("expected escaped LexString")
  }
  @test.assert_eq(escaped_bytes.to_array().map(byte => byte.to_int()), [
    13, 9, 8, 12, 5, 65, 43, 65,
  ])
}

///|
test "@syntax.pdf_cursor_lex_literal_string treats backslash newline as continuation" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([40, 65, 92, 13, 10, 66, 41]),
  )
  let lexeme = try! @syntax.pdf_cursor_lex_literal_string(cursor)
  guard lexeme is LexString(bytes) else { fail("expected LexString") }
  @test.assert_eq(bytes.to_array().map(byte => byte.to_int()), [65, 66])
  let carriage_return = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([40, 65, 92, 13, 66, 41]),
  )
  let lexeme = try! @syntax.pdf_cursor_lex_literal_string(carriage_return)
  guard lexeme is LexString(bytes) else { fail("expected LexString") }
  @test.assert_eq(bytes.to_array().map(byte => byte.to_int()), [65, 66])
  let line_feed = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([40, 65, 92, 10, 66, 41]),
  )
  let lexeme = try! @syntax.pdf_cursor_lex_literal_string(line_feed)
  guard lexeme is LexString(bytes) else { fail("expected LexString") }
  @test.assert_eq(bytes.to_array().map(byte => byte.to_int()), [65, 66])
  @test.assert_eq(
    try! @syntax.pdf_cursor_lex_literal_string(
      @core.byte_cursor_of_bytes(lexeme_bytes_for_test([65])),
    ),
    LexNone,
  )
  let missing_escaped_cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([40, 65, 92]),
  )
  let missing_escaped : Result[@syntax.PdfLexeme, Error] = try
    @syntax.pdf_cursor_lex_literal_string(missing_escaped_cursor)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_escaped is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput")
  }
  let unterminated_cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([40, 65]),
  )
  let unterminated : Result[@syntax.PdfLexeme, Error] = try
    @syntax.pdf_cursor_lex_literal_string(unterminated_cursor)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unterminated is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput")
  }
}

///|
test "@core.ByteCursor lexes PDF hex strings and rejects malformed hex" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([60, 32, 52, 49, 32, 50, 62]),
  )
  let lexeme = try! @syntax.pdf_cursor_lex_hex_string(cursor)
  guard lexeme is LexString(bytes) else { fail("expected LexString") }
  @test.assert_eq(bytes.to_array().map(byte => byte.to_int()), [65, 32])

  let malformed = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([60, 52, 90, 62]),
  )
  let result : Result[@syntax.PdfLexeme, Error] = try
    @syntax.pdf_cursor_lex_hex_string(malformed)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::InvalidHexEscape) else {
    fail("expected @core.PdfError::InvalidHexEscape")
  }

  let dict = @core.byte_cursor_of_bytes(lexeme_bytes_for_test([60, 60]))
  @test.assert_eq(try! @syntax.pdf_cursor_lex_hex_string(dict), LexNone)
  @test.assert_eq(dict.peek_byte(), 60)

  let empty = @core.byte_cursor_of_bytes(lexeme_bytes_for_test([60]))
  @test.assert_eq(
    try! @syntax.pdf_cursor_lex_hex_string(empty),
    LexString(lexeme_bytes_for_test([])),
  )
  let dangling = @core.byte_cursor_of_bytes(lexeme_bytes_for_test([60, 52]))
  @test.assert_eq(
    try! @syntax.pdf_cursor_lex_hex_string(dangling),
    LexString(lexeme_bytes_for_test([])),
  )
  let bad_high = @core.byte_cursor_of_bytes(lexeme_bytes_for_test([60, 90, 62]))
  let result : Result[@syntax.PdfLexeme, Error] = try
    @syntax.pdf_cursor_lex_hex_string(bad_high)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::InvalidHexEscape) else {
    fail("expected @core.PdfError::InvalidHexEscape")
  }
}

///|
test "@syntax.pdf_cursor_lex_delimiter leaves single angle starts unread" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([32, 91, 32, 93, 32, 60, 60, 32, 62, 62, 32, 60]),
  )
  @test.assert_eq(@syntax.pdf_cursor_lex_delimiter(cursor), LexLeftSquare)
  @test.assert_eq(@syntax.pdf_cursor_lex_delimiter(cursor), LexRightSquare)
  @test.assert_eq(@syntax.pdf_cursor_lex_delimiter(cursor), LexLeftDict)
  @test.assert_eq(@syntax.pdf_cursor_lex_delimiter(cursor), LexRightDict)
  @test.assert_eq(@syntax.pdf_cursor_lex_delimiter(cursor), LexNone)
  @test.assert_eq(cursor.peek_byte(), 60)
}

///|
test "@core.ByteCursor lexes PDF keywords and rewinds malformed endobj suffixes" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      110, 117, 108, 108, 32, 111, 98, 106, 32, 101, 110, 100, 111, 98, 106, 53,
      32, 82, 32, 101, 110, 100, 115, 116, 114, 101, 97, 109,
    ]),
  )
  @test.assert_eq(try! @syntax.pdf_cursor_lex_keyword(cursor), LexNull)
  @test.assert_eq(try! @syntax.pdf_cursor_lex_keyword(cursor), LexObj)
  @test.assert_eq(try! @syntax.pdf_cursor_lex_keyword(cursor), LexEndObj)
  @test.assert_eq(@syntax.pdf_cursor_lex_number(cursor), LexInt(5))
  @test.assert_eq(try! @syntax.pdf_cursor_lex_keyword(cursor), LexR)
  @test.assert_eq(try! @syntax.pdf_cursor_lex_keyword(cursor), LexEndStream)
}

///|
test "@syntax.pdf_lex_view scans primitive PDF object syntax" {
  let tokens = try! @syntax.pdf_lex_bytes(
    lexeme_bytes_for_test([
      37, 99, 10, 60, 60, 32, 47, 84, 121, 112, 101, 32, 47, 80, 97, 103, 101, 32,
      47, 65, 32, 91, 49, 32, 50, 32, 51, 32, 48, 32, 82, 93, 32, 47, 83, 32, 40,
      65, 92, 110, 66, 41, 32, 62, 62, 32, 115, 116, 97, 114, 116, 120, 114, 101,
      102,
    ]),
  )
  @test.assert_eq(tokens.map(@syntax.pdf_lexeme_debug_name), [
    "LexComment", "LexLeftDict", "LexName", "LexName", "LexName", "LexLeftSquare",
    "LexInt", "LexInt", "LexInt", "LexInt", "LexR", "LexRightSquare", "LexName",
    "LexString", "LexRightDict",
  ])
}

///|
test "@syntax.pdf_lex_view and @syntax.pdf_lex_single_view lex borrowed byte slices" {
  let data = lexeme_bytes_for_test([90, 32, 91, 49, 32, 50, 93, 32, 90])
  @test.assert_eq(try! @syntax.pdf_lex_single_view(data[2:7]), LexLeftSquare)
  let tokens = try! @syntax.pdf_lex_view(data[2:7])
  @test.assert_eq(tokens.map(@syntax.pdf_lexeme_debug_name), [
    "LexLeftSquare", "LexInt", "LexInt", "LexRightSquare",
  ])
}

///|
test "@syntax.pdf_cursor_lex_token dispatches booleans hex strings and stop markers" {
  let cursor = @core.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      102, 97, 108, 115, 101, 32, 60, 52, 49, 62, 32, 115, 105, 122, 101, 32, 73,
    ]),
  )
  @test.assert_eq(try! @syntax.pdf_cursor_lex_token(cursor), LexBool(false))
  let hex = try! @syntax.pdf_cursor_lex_token(cursor)
  guard hex is LexString(bytes) else { fail("expected LexString") }
  @test.assert_eq(bytes, lexeme_bytes_for_test([65]))
  @test.assert_eq(try! @syntax.pdf_cursor_lex_token(cursor), StopLexing)
  try! cursor.seek(16)
  @test.assert_eq(try! @syntax.pdf_cursor_lex_token(cursor), StopLexing)
}

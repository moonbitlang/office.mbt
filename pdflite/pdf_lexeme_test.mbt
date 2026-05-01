///|
fn lexeme_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn lexeme_view_to_ints_for_test(view : BytesView) -> Array[Int] {
  view.to_array().map(byte => byte.to_int())
}

///|
test "PDF byte predicates match CamlPDF whitespace and delimiters" {
  for value in [0, 9, 10, 12, 13, 32] {
    @test.assert_eq(@pdflite.pdf_is_whitespace_byte(value), true)
  }
  @test.assert_eq(@pdflite.pdf_is_newline_byte(10), true)
  @test.assert_eq(@pdflite.pdf_is_newline_byte(13), true)
  @test.assert_eq(@pdflite.pdf_is_newline_byte(32), false)
  for value in [40, 41, 47, 60, 62, 91, 93, 123, 125, 37] {
    @test.assert_eq(@pdflite.pdf_is_delimiter_byte(value), true)
  }
  @test.assert_eq(@pdflite.pdf_is_not_whitespace_byte(65), true)
  @test.assert_eq(@pdflite.pdf_is_whitespace_or_delimiter_byte(47), true)
  @test.assert_eq(@pdflite.pdf_is_whitespace_or_delimiter_byte(65), false)
}

///|
test "ByteCursor drops PDF whitespace and leaves delimiter untouched" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([32, 10, 47, 78, 97, 109, 101]),
  )
  cursor.drop_pdf_whitespace()
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(cursor.peek_byte(), 47)
}

///|
test "ByteCursor reads regular token views without consuming delimiter" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([32, 65, 66, 67, 47, 68]),
  )
  let view = cursor.read_pdf_regular_token_view()
  @test.assert_eq(lexeme_view_to_ints_for_test(view), [65, 66, 67])
  @test.assert_eq(cursor.peek_byte(), 47)
  @test.assert_eq(cursor.position(), 4)
}

///|
test "PdfLexeme token shape stores byte-oriented names and strings" {
  let name = @pdflite.pdf_name_of_bytes(lexeme_bytes_for_test([47, 84, 121]))
  let string = lexeme_bytes_for_test([0, 255])
  @test.assert_eq(@pdflite.pdf_lexeme_debug_name(LexName(name)), "LexName")
  @test.assert_eq(
    @pdflite.pdf_lexeme_debug_name(LexString(string)),
    "LexString",
  )
  @test.assert_eq(@pdflite.pdf_lexeme_debug_name(LexInt(42)), "LexInt")
}

///|
test "ByteCursor lexes PDF booleans and numbers" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      116, 114, 117, 101, 32, 45, 52, 50, 32, 46, 53, 32, 45, 45, 50,
    ]),
  )
  @test.assert_eq(cursor.lex_pdf_bool(), LexBool(true))
  @test.assert_eq(cursor.lex_pdf_number(), LexInt(-42))
  @test.assert_eq(cursor.lex_pdf_number(), LexReal(0.5))
  @test.assert_eq(cursor.lex_pdf_number(), LexInt(-2))
}

///|
test "ByteCursor lexes PDF names as bytes including slash and hex escapes" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([47, 65, 35, 50, 48, 66, 32, 47, 67]),
  )
  let first = try! cursor.lex_pdf_name()
  guard first is LexName(name) else { fail("expected LexName") }
  @test.assert_eq(name.bytes().to_array().map(byte => byte.to_int()), [
    47, 65, 32, 66,
  ])
  @test.assert_eq(cursor.peek_byte(), 32)
  cursor.drop_pdf_whitespace()
  let second = try! cursor.lex_pdf_name()
  guard second is LexName(second_name) else { fail("expected second LexName") }
  @test.assert_eq(second_name.bytes().to_array().map(byte => byte.to_int()), [
    47, 67,
  ])
}

///|
test "ByteCursor reports malformed PDF name hex escapes" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([47, 65, 35, 90, 90]),
  )
  let result : Result[@pdflite.PdfLexeme, Error] = try? cursor.lex_pdf_name()
  guard result is Err(@pdflite.PdfError::InvalidHexEscape) else {
    fail("expected InvalidHexEscape")
  }
}

///|
test "ByteCursor lexes PDF comments and leaves newline for whitespace scan" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([37, 65, 66, 13, 10, 49]),
  )
  @test.assert_eq(
    cursor.lex_pdf_comment(),
    LexComment(lexeme_bytes_for_test([])),
  )
  @test.assert_eq(cursor.peek_byte(), 13)
  cursor.drop_pdf_whitespace()
  @test.assert_eq(cursor.lex_pdf_number(), LexInt(1))
}

///|
test "ByteCursor lexes PDF literal strings as bytes" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      40, 65, 92, 110, 66, 92, 48, 53, 51, 92, 40, 67, 92, 41, 41, 32, 40, 120, 40,
      121, 41, 122, 41,
    ]),
  )
  let first = try! cursor.lex_pdf_literal_string()
  guard first is LexString(first_bytes) else { fail("expected LexString") }
  @test.assert_eq(first_bytes.to_array().map(byte => byte.to_int()), [
    65, 10, 66, 43, 40, 67, 41,
  ])
  cursor.drop_pdf_whitespace()
  let second = try! cursor.lex_pdf_literal_string()
  guard second is LexString(second_bytes) else {
    fail("expected second LexString")
  }
  @test.assert_eq(second_bytes.to_array().map(byte => byte.to_int()), [
    120, 40, 121, 41, 122,
  ])
}

///|
test "ByteCursor treats backslash newline in PDF literal strings as continuation" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([40, 65, 92, 13, 10, 66, 41]),
  )
  let lexeme = try! cursor.lex_pdf_literal_string()
  guard lexeme is LexString(bytes) else { fail("expected LexString") }
  @test.assert_eq(bytes.to_array().map(byte => byte.to_int()), [65, 66])
}

///|
test "ByteCursor lexes PDF hex strings and rejects malformed hex" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([60, 32, 52, 49, 32, 50, 62]),
  )
  let lexeme = try! cursor.lex_pdf_hex_string()
  guard lexeme is LexString(bytes) else { fail("expected LexString") }
  @test.assert_eq(bytes.to_array().map(byte => byte.to_int()), [65, 32])

  let malformed = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([60, 52, 90, 62]),
  )
  let result : Result[@pdflite.PdfLexeme, Error] = try? malformed.lex_pdf_hex_string()
  guard result is Err(@pdflite.PdfError::InvalidHexEscape) else {
    fail("expected InvalidHexEscape")
  }

  let dict = @pdflite.byte_cursor_of_bytes(lexeme_bytes_for_test([60, 60]))
  @test.assert_eq(try! dict.lex_pdf_hex_string(), LexNone)
  @test.assert_eq(dict.peek_byte(), 60)
}

///|
test "ByteCursor lexes PDF delimiters without consuming single angle starts" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([32, 91, 32, 93, 32, 60, 60, 32, 62, 62, 32, 60]),
  )
  @test.assert_eq(cursor.lex_pdf_delimiter(), LexLeftSquare)
  @test.assert_eq(cursor.lex_pdf_delimiter(), LexRightSquare)
  @test.assert_eq(cursor.lex_pdf_delimiter(), LexLeftDict)
  @test.assert_eq(cursor.lex_pdf_delimiter(), LexRightDict)
  @test.assert_eq(cursor.lex_pdf_delimiter(), LexNone)
  @test.assert_eq(cursor.peek_byte(), 60)
}

///|
test "ByteCursor lexes PDF keywords and rewinds malformed endobj suffixes" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    lexeme_bytes_for_test([
      110, 117, 108, 108, 32, 111, 98, 106, 32, 101, 110, 100, 111, 98, 106, 53,
      32, 82, 32, 101, 110, 100, 115, 116, 114, 101, 97, 109,
    ]),
  )
  @test.assert_eq(try! cursor.lex_pdf_keyword(), LexNull)
  @test.assert_eq(try! cursor.lex_pdf_keyword(), LexObj)
  @test.assert_eq(try! cursor.lex_pdf_keyword(), LexEndObj)
  @test.assert_eq(cursor.lex_pdf_number(), LexInt(5))
  @test.assert_eq(try! cursor.lex_pdf_keyword(), LexR)
  @test.assert_eq(try! cursor.lex_pdf_keyword(), LexEndStream)
}

///|
test "ByteCursor lex_pdf_tokens scans primitive PDF object syntax" {
  let tokens = try! @pdflite.pdf_lex_bytes(
    lexeme_bytes_for_test([
      37, 99, 10, 60, 60, 32, 47, 84, 121, 112, 101, 32, 47, 80, 97, 103, 101, 32,
      47, 65, 32, 91, 49, 32, 50, 32, 51, 32, 48, 32, 82, 93, 32, 47, 83, 32, 40,
      65, 92, 110, 66, 41, 32, 62, 62, 32, 115, 116, 97, 114, 116, 120, 114, 101,
      102,
    ]),
  )
  @test.assert_eq(tokens.map(@pdflite.pdf_lexeme_debug_name), [
    "LexComment", "LexLeftDict", "LexName", "LexName", "LexName", "LexLeftSquare",
    "LexInt", "LexInt", "LexInt", "LexInt", "LexR", "LexRightSquare", "LexName",
    "LexString", "LexRightDict",
  ])
}

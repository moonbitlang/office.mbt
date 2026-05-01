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

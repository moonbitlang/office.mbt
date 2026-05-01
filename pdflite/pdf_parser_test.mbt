///|
fn parser_name_for_test(values : ArrayView[Int]) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(try! @pdflite.pdf_bytes_of_int_array(values))
}

///|
fn parser_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
test "pdf_parse_lexemes converts primitive lexemes to PdfObject values" {
  let name = parser_name_for_test([47, 78])
  let string = parser_bytes_for_test([65, 0])
  @test.assert_eq(
    try! @pdflite.pdf_parse_lexemes([
      LexComment(parser_bytes_for_test([])),
      LexNull,
      LexBool(true),
      LexInt(42),
      LexReal(2.5),
      LexString(string),
      LexName(name),
    ]),
    [
      PdfNull,
      PdfBoolean(true),
      PdfInteger(42),
      PdfReal(2.5),
      PdfString(string),
      PdfNameObject(name),
    ],
  )
}

///|
test "pdf_parse_single_lexeme_object parses arrays dictionaries and indirect references" {
  let key_type = parser_name_for_test([47, 84, 121, 112, 101])
  let key_kids = parser_name_for_test([47, 75, 105, 100, 115])
  let parsed = try! @pdflite.pdf_parse_single_lexeme_object([
    LexLeftDict,
    LexName(key_type),
    LexName(parser_name_for_test([47, 80, 97, 103, 101])),
    LexName(key_kids),
    LexLeftSquare,
    LexInt(7),
    LexInt(0),
    LexR,
    LexInt(8),
    LexRightSquare,
    LexRightDict,
  ])
  let expected = @pdflite.pdf_dictionary([
    (key_type, PdfNameObject(parser_name_for_test([47, 80, 97, 103, 101]))),
    (key_kids, @pdflite.pdf_array([PdfIndirect(7), PdfInteger(8)])),
  ])
  @test.assert_eq(parsed, expected)
}

///|
test "pdf_parse_single_lexeme_object mirrors CamlPDF empty dictionary recovery" {
  let parsed = try! @pdflite.pdf_parse_single_lexeme_object([
    LexLeftDict,
    LexInt(1),
    LexInt(2),
    LexRightDict,
  ])
  @test.assert_eq(parsed, @pdflite.pdf_dictionary([]))
  let odd = try! @pdflite.pdf_parse_single_lexeme_object([
    LexLeftDict,
    LexName(parser_name_for_test([47, 79, 100, 100])),
    LexRightDict,
  ])
  @test.assert_eq(odd, @pdflite.pdf_dictionary([]))
}

///|
test "pdf_parse_single_lexeme_object reports non-single and malformed inputs" {
  let many : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_parse_single_lexeme_object([
      LexInt(1),
      LexInt(2),
    ],
  )
  guard many is Err(@pdflite.PdfError::ParseSingleObjectExpected) else {
    fail("expected ParseSingleObjectExpected")
  }
  let bad : Result[Array[@pdflite.PdfObject], Error] = try? @pdflite.pdf_parse_lexemes([
      LexRightSquare,
    ],
  )
  guard bad is Err(@pdflite.PdfError::ParseObjectExpected) else {
    fail("expected ParseObjectExpected")
  }
}

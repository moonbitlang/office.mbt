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

///|
test "pdf_parse_object_from_bytes lexes and parses primitive PDF bytes" {
  let type_key = parser_name_for_test([47, 84, 121, 112, 101])
  let media_box_key = parser_name_for_test([
    47, 77, 101, 100, 105, 97, 66, 111, 120,
  ])
  let contents_key = parser_name_for_test([
    47, 67, 111, 110, 116, 101, 110, 116, 115,
  ])
  let parsed = try! @pdflite.pdf_parse_object_from_bytes(
    parser_bytes_for_test([
      60, 60, 32, 47, 84, 121, 112, 101, 32, 47, 80, 97, 103, 101, 32, 47, 77, 101,
      100, 105, 97, 66, 111, 120, 32, 91, 48, 32, 48, 32, 54, 49, 50, 32, 55, 57,
      50, 93, 32, 47, 67, 111, 110, 116, 101, 110, 116, 115, 32, 53, 32, 48, 32,
      82, 32, 62, 62,
    ]),
  )
  let expected = @pdflite.pdf_dictionary([
    (type_key, PdfNameObject(parser_name_for_test([47, 80, 97, 103, 101]))),
    (
      media_box_key,
      @pdflite.pdf_array([
        PdfInteger(0),
        PdfInteger(0),
        PdfInteger(612),
        PdfInteger(792),
      ]),
    ),
    (contents_key, PdfIndirect(5)),
  ])
  @test.assert_eq(parsed, expected)
}

///|
test "pdf_parse_indirect_object_from_bytes parses primitive indirect objects" {
  let type_key = parser_name_for_test([47, 84, 121, 112, 101])
  let parsed = try! @pdflite.pdf_parse_indirect_object_from_bytes(
    parser_bytes_for_test([
      55, 32, 48, 32, 111, 98, 106, 10, 60, 60, 32, 47, 84, 121, 112, 101, 32, 47,
      80, 97, 103, 101, 32, 62, 62, 10, 101, 110, 100, 111, 98, 106,
    ]),
  )
  @test.assert_eq(parsed.number, 7)
  @test.assert_eq(parsed.generation, 0)
  @test.assert_eq(
    parsed.object,
    @pdflite.pdf_dictionary([
      (type_key, PdfNameObject(parser_name_for_test([47, 80, 97, 103, 101]))),
    ]),
  )
}

///|
test "pdf_parse_indirect_object_lexemes reports malformed indirect objects" {
  let missing_header : Result[@pdflite.PdfParsedIndirectObject, Error] = try? @pdflite.pdf_parse_indirect_object_lexemes([
      LexInt(7),
      LexInt(0),
      LexNull,
    ],
  )
  guard missing_header is Err(@pdflite.PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }
  let missing_end : Result[@pdflite.PdfParsedIndirectObject, Error] = try? @pdflite.pdf_parse_indirect_object_lexemes([
      LexInt(7),
      LexInt(0),
      LexObj,
      LexNull,
    ],
  )
  guard missing_end is Err(@pdflite.PdfError::ParseEndObjectExpected) else {
    fail("expected ParseEndObjectExpected")
  }
}

///|
test "pdf_parse_indirect_objects parses multiple primitive indirect objects" {
  let objects = try! @pdflite.pdf_parse_indirect_objects([
    LexInt(1),
    LexInt(0),
    LexObj,
    LexNull,
    LexEndObj,
    LexInt(2),
    LexInt(3),
    LexObj,
    LexInt(42),
    LexEndObj,
  ])
  @test.assert_eq(objects.length(), 2)
  @test.assert_eq(objects[0].number, 1)
  @test.assert_eq(objects[0].generation, 0)
  @test.assert_eq(objects[0].object, PdfNull)
  @test.assert_eq(objects[1].number, 2)
  @test.assert_eq(objects[1].generation, 3)
  @test.assert_eq(objects[1].object, PdfInteger(42))
}

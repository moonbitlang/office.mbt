///|
fn util_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn util_lookup_for_test(
  object : @pdflite.PdfObject,
  key : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  object.lookup_immediate(key)
}

///|
test "PdfDocument remove_dict_entry_everywhere rewrites trailer objects streams and arrays" {
  let key_remove = util_name_for_test("/Remove")
  let key_keep = util_name_for_test("/Keep")
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(
    @pdflite.pdf_dictionary([
      (key_keep, PdfInteger(1)),
      (key_remove, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_remove, PdfInteger(10)),
      (key_keep, @pdflite.pdf_dictionary([(key_remove, PdfInteger(11))])),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_array([
      @pdflite.pdf_dictionary([(key_remove, PdfInteger(20))]),
      PdfInteger(3),
    ]),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(key_remove, PdfInteger(30))]),
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65, 66])),
  )
  doc.add_object_given_number(3, stream)

  doc.remove_dict_entry_everywhere(key_remove)

  @test.assert_eq(util_lookup_for_test(doc.trailer_dict(), key_remove), None)
  guard doc.lookup_object_or_null(1) is PdfDictionary(entries1) else {
    fail("expected dictionary object")
  }
  @test.assert_eq(
    util_lookup_for_test(PdfDictionary(entries1), key_remove),
    None,
  )
  guard util_lookup_for_test(PdfDictionary(entries1), key_keep)
    is Some(PdfDictionary(nested_entries)) else {
    fail("expected nested dictionary")
  }
  @test.assert_eq(
    util_lookup_for_test(PdfDictionary(nested_entries), key_remove),
    None,
  )
  guard doc.lookup_object_or_null(2)
    is PdfArray([PdfDictionary(array_entries), _]) else {
    fail("expected array dictionary")
  }
  @test.assert_eq(
    util_lookup_for_test(PdfDictionary(array_entries), key_remove),
    None,
  )
  guard doc.lookup_object_or_null(3) is PdfStreamObject(updated_stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    util_lookup_for_test(updated_stream.dictionary, key_remove),
    None,
  )
  @test.assert_eq(
    updated_stream.data,
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65, 66])),
  )
}

///|
test "PdfDocument dictionary entry rewrite honours resolved search values" {
  let key_target = util_name_for_test("/Target")
  let key_other = util_name_for_test("/Other")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(10, PdfInteger(99))
  doc.add_object_given_number(11, PdfInteger(42))
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_target, PdfIndirect(10)),
      (key_other, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([(key_target, PdfIndirect(11))]),
  )

  doc.remove_dict_entry_everywhere(key_target, search=Some(PdfInteger(99)))

  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(1), key_target),
    None,
  )
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(2), key_target),
    Some(PdfIndirect(11)),
  )

  doc.replace_dict_entry_everywhere(
    key_target,
    PdfInteger(7),
    search=Some(PdfInteger(42)),
  )
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(2), key_target),
    Some(PdfInteger(7)),
  )
}

///|
test "pdf_replace_dict_entry ignores missing keys and updates trailer" {
  let key_target = util_name_for_test("/Target")
  let key_keep = util_name_for_test("/Keep")
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(
    @pdflite.pdf_dictionary([
      (key_keep, PdfInteger(1)),
      (key_target, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(key_keep, PdfInteger(3))]),
  )

  @pdflite.pdf_replace_dict_entry(doc, key_target, PdfInteger(9))

  @test.assert_eq(
    util_lookup_for_test(doc.trailer_dict(), key_target),
    Some(PdfInteger(9)),
  )
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(1), key_keep),
    Some(PdfInteger(3)),
  )
}

///|
test "PdfDocument dict_entry_values scans dictionaries arrays streams and trailer" {
  let key_target = util_name_for_test("/Target")
  let key_nested = util_name_for_test("/Nested")
  let key_stream_value = util_name_for_test("/StreamValue")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(9, PdfInteger(99))
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_target, PdfInteger(1)),
      (
        key_nested,
        @pdflite.pdf_dictionary([
          (key_target, PdfString(@ascii.encode("nested"))),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_array([@pdflite.pdf_dictionary([(key_target, PdfReal(2.5))])]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([(key_target, PdfNameObject(key_stream_value))]),
      StreamGot(@ascii.encode("stream")),
    ),
  )
  doc.add_object_given_number(
    4,
    @pdflite.pdf_stream(PdfInteger(0), StreamGot(@ascii.encode("bad"))),
  )
  doc.set_trailer_dict(@pdflite.pdf_dictionary([(key_target, PdfIndirect(9))]))

  @test.assert_eq(@pdflite.pdf_dict_entry_values(doc, key_target), [
    PdfString(@ascii.encode("nested")),
    PdfInteger(1),
    PdfReal(2.5),
    PdfNameObject(key_stream_value),
    PdfInteger(99),
  ])
}

///|
test "pdf_print_dict_entry renders resolved values as PDF syntax" {
  let key_target = util_name_for_test("/Target")
  let key_value = util_name_for_test("/Value")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(10, PdfNameObject(key_value))
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(key_target, PdfIndirect(10))]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([(key_target, PdfString(@ascii.encode("plain")))]),
  )

  @test.assert_eq(try! @pdflite.pdf_print_dict_entry(doc, key_target), [
    @ascii.encode("/Value"),
    @ascii.encode("(plain)"),
  ])
}

///|
test "pdf_get_dict_entries renders cpdf style JSON wrappers" {
  let key_target = util_name_for_test("/Target")
  let key_other = util_name_for_test("/Other")
  let key_value = util_name_for_test("/Value")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(key_target, PdfInteger(7))]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([(key_target, PdfNameObject(key_value))]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (
        key_target,
        PdfArray([PdfBoolean(true), PdfNull, PdfReal(2.5), PdfIndirect(5)]),
      ),
    ]),
  )
  doc.add_object_given_number(
    4,
    @pdflite.pdf_dictionary([(key_target, PdfIndirect(5))]),
  )
  doc.add_object_given_number(
    5,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([(key_other, PdfInteger(1))]),
      StreamGot(@ascii.encode("payload")),
    ),
  )
  let expected : Json = [
    { "I": 7.0 },
    { "N": "/Value" },
    [true, null, { "F": 2.5 }, 5.0],
    { "S": [{ "/Other": { "I": 1.0 } }, "payload"] },
  ]

  @test.assert_eq(
    try! @pdflite.pdf_get_dict_entries(doc, key_target),
    @utf8.encode(expected.stringify()),
  )
}

///|
test "pdf_get_dict_entries emits utf8 string wrappers when requested" {
  let key_target = util_name_for_test("/Target")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(key_target, PdfString(@ascii.encode("hello")))]),
  )
  let expected : Json = [{ "U": "hello" }]

  @test.assert_eq(
    try! @pdflite.pdf_get_dict_entries(doc, key_target, utf8=true),
    @utf8.encode(expected.stringify()),
  )
}

///|
test "pdf_get_dict_entries escapes malformed string and name bytes" {
  let key_target = util_name_for_test("/Target")
  let doc = @pdflite.pdf_document_empty()
  let malformed_string = try! @pdflite.pdf_bytes_of_int_array([0xFE, 0xFF, 0x00])
  let malformed_name = @pdflite.pdf_name_of_bytes(
    try! @pdflite.pdf_bytes_of_int_array([47, 255]),
  )
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(key_target, PdfString(malformed_string))]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([(key_target, PdfNameObject(malformed_name))]),
  )
  let string_json = Json::string(
    try! @ascii.decode(@pdflite.pdf_write_hex_string(malformed_string)),
  )
  let name_json = Json::object(
    Map::of([
      (
        "N",
        Json::string(
          try! @ascii.decode(
            try! @pdflite.pdf_write_object(PdfNameObject(malformed_name)),
          ),
        ),
      ),
    ]),
  )
  let expected = @utf8.encode(Json::array([string_json, name_json]).stringify())

  @test.assert_eq(try! @pdflite.pdf_get_dict_entries(doc, key_target), expected)
  @test.assert_eq(
    try! @pdflite.pdf_get_dict_entries(doc, key_target, utf8=true),
    expected,
  )
}

///|
test "pdf_remove_dict_entry skips malformed stream dictionaries" {
  let key_remove = util_name_for_test("/Remove")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_stream(PdfInteger(1), StreamGot(@ascii.encode("x"))),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([(key_remove, PdfInteger(2))]),
  )

  @pdflite.pdf_remove_dict_entry(doc, key_remove)

  guard doc.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected malformed stream object")
  }
  @test.assert_eq(stream.dictionary, PdfInteger(1))
  @test.assert_eq(stream.data, StreamGot(@ascii.encode("x")))
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(2), key_remove),
    None,
  )
}

///|
test "pdf_check_injectible reports cpdf shell metacharacters" {
  try! @pdflite.pdf_check_injectible("safe/名前.pdf")
  let ampersand : Result[Unit, Error] = try? @pdflite.pdf_check_injectible(
    "a&b.pdf",
  )
  guard ampersand is Err(@pdflite.PdfError::InsecurePathName("a&b.pdf")) else {
    fail("expected InsecurePathName for ampersand")
  }
  let newline : Result[Unit, Error] = try? @pdflite.pdf_check_injectible(
    "a\nb.pdf",
  )
  guard newline is Err(@pdflite.PdfError::InsecurePathName("a\nb.pdf")) else {
    fail("expected InsecurePathName for newline")
  }
}

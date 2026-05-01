///|
fn writer_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn writer_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn writer_concat_bytes_for_test(
  parts : ArrayView[@pdflite.PdfBytes],
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for part in parts {
    for byte in part {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn writer_name_for_test(values : ArrayView[Int]) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(writer_bytes_for_test(values))
}

///|
fn writer_bytes_start_with_at(
  haystack : @pdflite.PdfBytes,
  needle : @pdflite.PdfBytes,
  start : Int,
) -> Bool {
  for i = 0; i < needle.length(); i = i + 1 {
    if haystack[start + i] != needle[i] {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn writer_find_bytes(
  haystack : @pdflite.PdfBytes,
  needle : @pdflite.PdfBytes,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start = 0
        start <= haystack.length() - needle.length()
        start = start + 1 {
      if writer_bytes_start_with_at(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn writer_find_bytes_from(
  haystack : @pdflite.PdfBytes,
  needle : @pdflite.PdfBytes,
  start_at : Int,
) -> Int {
  if needle.length() == 0 {
    start_at
  } else if start_at < 0 ||
    haystack.length() < needle.length() ||
    start_at > haystack.length() - needle.length() {
    -1
  } else {
    for start = start_at
        start <= haystack.length() - needle.length()
        start = start + 1 {
      if writer_bytes_start_with_at(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
test "pdf_write_object renders primitive scalar objects" {
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfNull),
    writer_bytes_for_test([110, 117, 108, 108]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfBoolean(true)),
    writer_bytes_for_test([116, 114, 117, 101]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfInteger(-42)),
    writer_bytes_for_test([45, 52, 50]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfIndirect(7)),
    writer_bytes_for_test([55, 32, 48, 32, 82]),
  )
}

///|
test "pdf_write_name renders PDF names with escapes" {
  @test.assert_eq(
    @pdflite.pdf_write_name(writer_name_for_test([47, 65, 32, 66, 35, 67, 255])),
    writer_bytes_for_test([47, 65, 35, 50, 48, 66, 35, 50, 51, 67, 35, 70, 70]),
  )
  @test.assert_eq(
    @pdflite.pdf_write_name(writer_name_for_test([65, 40, 41, 60, 62, 47, 93])),
    writer_bytes_for_test([
      47, 65, 35, 50, 56, 35, 50, 57, 35, 51, 67, 35, 51, 69, 35, 50, 70, 35, 53,
      68,
    ]),
  )
}

///|
test "pdf_write_hex_string renders byte strings as PDF hex strings" {
  @test.assert_eq(
    @pdflite.pdf_write_hex_string(
      writer_bytes_for_test([0, 10, 15, 16, 255])[:],
    ),
    writer_ascii_for_test("<000a0f10ff>"),
  )
  @test.assert_eq(
    @pdflite.pdf_write_hex_string(Bytes::new(0)[:]),
    writer_ascii_for_test("<>"),
  )
}

///|
test "pdf_write_literal_string renders byte strings as PDF literal strings" {
  let string = writer_bytes_for_test([65, 10, 40, 41, 92, 0, 255])
  @test.assert_eq(
    @pdflite.pdf_write_literal_string(string[:]),
    writer_bytes_for_test([
      40, 65, 92, 110, 92, 40, 92, 41, 92, 92, 92, 48, 48, 48, 92, 51, 55, 55, 41,
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_write_literal_string(Bytes::new(0)[:]),
    writer_ascii_for_test("()"),
  )
}

///|
test "pdf_write_object renders real numbers without exponent notation" {
  let tiny : Double = try! @strconv.from_str("1e-10")
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(tiny)),
    writer_bytes_for_test([48, 46, 48, 48, 48, 48, 48, 48]),
  )
  let small : Double = try! @strconv.from_str("0.00009")
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(small)),
    writer_bytes_for_test([48, 46, 48, 48, 48, 48, 57, 48]),
  )
  let negative_small : Double = try! @strconv.from_str("-0.00009")
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(negative_small)),
    writer_bytes_for_test([45, 48, 46, 48, 48, 48, 48, 57, 48]),
  )
  let large : Double = try! @strconv.from_str("1.25e6")
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(large)),
    writer_bytes_for_test([49, 50, 53, 48, 48, 48, 48]),
  )
  let large_exponent : Double = try! @strconv.from_str("1e21")
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(large_exponent)),
    writer_ascii_for_test("1000000000000000000000"),
  )
  let rounded_large_exponent : Double = try! @strconv.from_str(
    "1.23456789012345e21",
  )
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(rounded_large_exponent)),
    writer_ascii_for_test("1234567890120000000000"),
  )
  let carry_large_exponent : Double = try! @strconv.from_str(
    "9.999999999999e21",
  )
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(carry_large_exponent)),
    writer_ascii_for_test("10000000000000000000000"),
  )
  let precise : Double = try! @strconv.from_str("1.23456789012345")
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(precise)),
    writer_ascii_for_test("1.23456789012"),
  )
  let carry : Double = try! @strconv.from_str("999999.9999999")
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(carry)),
    writer_ascii_for_test("1000000"),
  )
  let fractional : Double = try! @strconv.from_str("0.000123456789012345")
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfReal(fractional)),
    writer_ascii_for_test("0.000123456789012"),
  )
}

///|
test "pdf_write_object escapes names and literal strings as bytes" {
  let name = writer_name_for_test([47, 65, 32, 66, 35, 67, 255])
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfNameObject(name)),
    writer_bytes_for_test([47, 65, 35, 50, 48, 66, 35, 50, 51, 67, 35, 70, 70]),
  )
  let string = writer_bytes_for_test([65, 10, 40, 41, 92, 0, 255])
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfString(string)),
    writer_bytes_for_test([
      40, 65, 92, 110, 92, 40, 92, 41, 92, 92, 92, 48, 48, 48, 92, 51, 55, 55, 41,
    ]),
  )
  let control_string = writer_bytes_for_test([13, 9, 8, 12])
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfString(control_string)),
    writer_bytes_for_test([40, 92, 114, 92, 116, 92, 98, 92, 102, 41]),
  )
}

///|
test "pdf_write_object round trips arrays and dictionaries through primitive parser" {
  let type_key = writer_name_for_test([47, 84, 121, 112, 101])
  let object = @pdflite.pdf_dictionary([
    (type_key, PdfNameObject(writer_name_for_test([47, 80, 97, 103, 101]))),
    (
      writer_name_for_test([47, 75, 105, 100, 115]),
      @pdflite.pdf_array([PdfInteger(7), PdfIndirect(8)]),
    ),
  ])
  let rendered = try! @pdflite.pdf_write_object(object)
  @test.assert_eq(try! @pdflite.pdf_parse_object_from_bytes(rendered), object)
}

///|
test "pdf_write_indirect_object renders direct stream data" {
  let length_name = writer_name_for_test([47, 76, 101, 110, 103, 116, 104])
  let object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length_name, PdfInteger(5))]),
    StreamGot(writer_bytes_for_test([72, 101, 108, 108, 111])),
  )
  let rendered = try! @pdflite.pdf_write_indirect_object({
    number: 7,
    generation: 0,
    object,
  })
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(rendered)
  @test.assert_eq(parsed.number, 7)
  @test.assert_eq(parsed.object, object)
}

///|
test "pdf_write_indirect_object adds owned stream length" {
  let object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(writer_bytes_for_test([72, 105])),
  )
  let rendered = try! @pdflite.pdf_write_indirect_object({
    number: 8,
    generation: 0,
    object,
  })
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(rendered)
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      writer_name_for_test([47, 76, 101, 110, 103, 116, 104]),
    ),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(stream.data, StreamGot(writer_bytes_for_test([72, 105])))
}

///|
test "pdf_write_object materializes deferred stream data" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    writer_bytes_for_test([65, 72, 105, 90]),
  )
  let object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamToGet(@pdflite.stream_to_get(cursor, 1, 2)),
  )
  let rendered = try! @pdflite.pdf_write_object(object)
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(
    writer_concat_bytes_for_test([
      writer_bytes_for_test([49, 32, 48, 32, 111, 98, 106, 10]),
      rendered,
      writer_bytes_for_test([10, 101, 110, 100, 111, 98, 106]),
    ]),
  )
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      writer_name_for_test([47, 76, 101, 110, 103, 116, 104]),
    ),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(stream.data, StreamGot(writer_bytes_for_test([72, 105])))
}

///|
test "pdf_write_document serializes objects with xref and trailer" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  let type_name = writer_name_for_test([47, 84, 121, 112, 101])
  let pages_name = writer_name_for_test([47, 80, 97, 103, 101, 115])
  let catalog = @pdflite.pdf_dictionary([
    (
      type_name,
      PdfNameObject(writer_name_for_test([47, 67, 97, 116, 97, 108, 111, 103])),
    ),
    (pages_name, PdfIndirect(2)),
  ])
  let kids_name = writer_name_for_test([47, 75, 105, 100, 115])
  let count_name = writer_name_for_test([47, 67, 111, 117, 110, 116])
  let pages = @pdflite.pdf_dictionary([
    (
      type_name,
      PdfNameObject(writer_name_for_test([47, 80, 97, 103, 101, 115])),
    ),
    (kids_name, @pdflite.pdf_array([])),
    (count_name, PdfInteger(0)),
  ])
  document.add_object_given_number(1, catalog)
  document.add_object_given_number(2, pages)
  let rendered = try! @pdflite.pdf_write_document(document)
  let xref_at = writer_find_bytes(
    rendered,
    writer_bytes_for_test([120, 114, 101, 102]),
  )
  let trailer_at = writer_find_bytes(
    rendered,
    writer_bytes_for_test([116, 114, 97, 105, 108, 101, 114]),
  )
  let startxref_at = writer_find_bytes(
    rendered,
    writer_bytes_for_test([115, 116, 97, 114, 116, 120, 114, 101, 102]),
  )
  let eof_at = writer_find_bytes(
    rendered,
    writer_bytes_for_test([37, 37, 69, 79, 70]),
  )
  @test.assert_eq(xref_at > 0, true)
  @test.assert_eq(trailer_at > xref_at, true)
  @test.assert_eq(startxref_at > trailer_at, true)
  @test.assert_eq(eof_at > startxref_at, true)
  let parsed = try! @pdflite.pdf_read_primitive_document_from_bytes(rendered)
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(1), catalog)
  @test.assert_eq(parsed.lookup_object_or_null(2), pages)
}

///|
test "pdf_write_document_incremental_update appends classic xref revisions" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  let value_name = writer_name_for_test([47, 86, 97, 108, 117, 101])
  let catalog = @pdflite.pdf_dictionary([(value_name, PdfInteger(1))])
  document.add_object_given_number(1, catalog)
  let original = try! @pdflite.pdf_write_document(document)
  let original_parsed = try! @pdflite.pdf_read_document_from_bytes(original)

  let updated = original_parsed.copy()
  let updated_catalog = @pdflite.pdf_dictionary([
    (value_name, PdfInteger(2)),
    (writer_name_for_test([47, 78, 101, 119]), PdfIndirect(2)),
  ])
  updated.add_object_given_number(1, updated_catalog)
  updated.add_object_given_number(2, PdfInteger(99))
  let rendered = try! @pdflite.pdf_write_document_incremental_update(
    original, updated,
  )
  @test.assert_eq(rendered.length() > original.length(), true)
  @test.assert_eq(writer_bytes_start_with_at(rendered, original, 0), true)
  @test.assert_eq(
    writer_find_bytes(
      rendered,
      writer_ascii_for_test("/Prev " + original_parsed.first_xref().to_string()),
    ) >
    0,
    true,
  )

  let reparsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(reparsed.first_xref() > original.length(), true)
  @test.assert_eq(reparsed.root(), 1)
  @test.assert_eq(reparsed.object_numbers(), [1, 2])
  @test.assert_eq(reparsed.lookup_object_or_null(1), updated_catalog)
  @test.assert_eq(reparsed.lookup_object_or_null(2), PdfInteger(99))

  let deleted = reparsed.copy()
  let deleted_catalog = @pdflite.pdf_dictionary([(value_name, PdfInteger(3))])
  deleted.add_object_given_number(1, deleted_catalog)
  deleted.remove_object(2)
  let second_update = try! @pdflite.pdf_write_document_incremental_update(
    rendered, deleted,
  )
  @test.assert_eq(
    writer_find_bytes(
      second_update,
      writer_ascii_for_test("/Prev " + reparsed.first_xref().to_string()),
    ) >
    0,
    true,
  )
  let deleted_reparsed = try! @pdflite.pdf_read_document_from_bytes(
    second_update,
  )
  @test.assert_eq(deleted_reparsed.first_xref() > rendered.length(), true)
  @test.assert_eq(deleted_reparsed.object_numbers(), [1])
  @test.assert_eq(deleted_reparsed.lookup_object_or_null(1), deleted_catalog)
  @test.assert_eq(deleted_reparsed.lookup_object_or_null(2), PdfNull)
}

///|
test "pdf_write_document_incremental_update writes only changed classic objects" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  let value_name = writer_name_for_test([47, 86, 97, 108, 117, 101])
  let catalog = @pdflite.pdf_dictionary([(value_name, PdfInteger(1))])
  document.add_object_given_number(1, catalog)
  document.add_object_given_number(2, PdfInteger(20))
  let original = try! @pdflite.pdf_write_document(document)
  let original_parsed = try! @pdflite.pdf_read_document_from_bytes(original)
  @test.assert_eq(original_parsed.event_log(), [])

  let updated = original_parsed.copy()
  updated.add_object_given_number(2, PdfInteger(30))
  updated.add_object_given_number(2, PdfInteger(40))
  let rendered = try! @pdflite.pdf_write_document_incremental_update(
    original, updated,
  )
  @test.assert_eq(
    writer_find_bytes_from(
      rendered,
      writer_ascii_for_test("2 0 obj"),
      original.length(),
    ) >
    0,
    true,
  )
  @test.assert_eq(
    writer_find_bytes_from(
      rendered,
      writer_ascii_for_test("1 0 obj"),
      original.length(),
    ),
    -1,
  )

  let reparsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(reparsed.object_numbers(), [1, 2])
  @test.assert_eq(reparsed.lookup_object_or_null(1), catalog)
  @test.assert_eq(reparsed.lookup_object_or_null(2), PdfInteger(40))
}

///|
test "pdf_write_document_incremental_update rejects originals without startxref" {
  let document = @pdflite.pdf_document_empty()
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_write_document_incremental_update(
    writer_ascii_for_test("%PDF-1.4\n%%EOF\n"),
    document,
  )
  guard result is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected StartXRefExpected")
  }
}

///|
test "pdf_write_document_with_xref_stream round trips through public reader" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  let type_name = writer_name_for_test([47, 84, 121, 112, 101])
  let catalog_name = writer_name_for_test([47, 67, 97, 116, 97, 108, 111, 103])
  let payload_name = writer_name_for_test([47, 80, 97, 121, 108, 111, 97, 100])
  let catalog = @pdflite.pdf_dictionary([
    (type_name, PdfNameObject(catalog_name)),
    (payload_name, PdfIndirect(4)),
  ])
  let payload = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(writer_ascii_for_test("xref-stream payload")),
  )
  document.add_object_given_number(1, catalog)
  document.add_object_given_number(4, payload)
  let rendered = try! @pdflite.pdf_write_document_with_xref_stream(document)
  @test.assert_eq(
    writer_find_bytes(rendered, writer_ascii_for_test("/XRef")) > 0,
    true,
  )
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 4])
  @test.assert_eq(parsed.lookup_object_or_null(1), catalog)
  guard parsed.lookup_object_or_null(4) is PdfStreamObject(stream) else {
    fail("expected stream payload")
  }
  @test.assert_eq(
    stream.data,
    StreamGot(writer_ascii_for_test("xref-stream payload")),
  )

  document.set_version(2, 0)
  let rendered_v2 = try! @pdflite.pdf_write_document_with_xref_stream(document)
  let parsed_v2 = try! @pdflite.pdf_read_document_from_bytes(rendered_v2)
  @test.assert_eq(parsed_v2.version(), (2, 0))
  @test.assert_eq(parsed_v2.object_numbers(), [1, 4])
}

///|
test "pdf_write_document_incremental_update_with_xref_stream appends xref streams" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 5)
  document.set_root(1)
  let value_name = writer_name_for_test([47, 86, 97, 108, 117, 101])
  document.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(value_name, PdfInteger(1))]),
  )
  let original = try! @pdflite.pdf_write_document_with_xref_stream(document)
  let original_parsed = try! @pdflite.pdf_read_document_from_bytes(original)
  let updated = original_parsed.copy()
  let updated_catalog = @pdflite.pdf_dictionary([
    (value_name, PdfInteger(2)),
    (writer_name_for_test([47, 78, 101, 119]), PdfIndirect(2)),
  ])
  updated.add_object_given_number(1, updated_catalog)
  updated.add_object_given_number(2, PdfInteger(42))
  let rendered = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    original, updated,
  )
  @test.assert_eq(rendered.length() > original.length(), true)
  @test.assert_eq(writer_bytes_start_with_at(rendered, original, 0), true)
  @test.assert_eq(
    writer_find_bytes(
      rendered,
      writer_ascii_for_test("/Prev " + original_parsed.first_xref().to_string()),
    ) >
    0,
    true,
  )
  @test.assert_eq(
    writer_find_bytes(rendered, writer_ascii_for_test("/XRef")) > 0,
    true,
  )
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(reparsed.version(), (1, 5))
  @test.assert_eq(reparsed.first_xref() > original.length(), true)
  @test.assert_eq(reparsed.object_numbers(), [1, 2])
  @test.assert_eq(reparsed.lookup_object_or_null(1), updated_catalog)
  @test.assert_eq(reparsed.lookup_object_or_null(2), PdfInteger(42))
}

///|
test "pdf_write_document_incremental_update_with_xref_stream writes sparse Index" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 5)
  document.set_root(1)
  let value_name = writer_name_for_test([47, 86, 97, 108, 117, 101])
  let catalog = @pdflite.pdf_dictionary([(value_name, PdfInteger(1))])
  document.add_object_given_number(1, catalog)
  document.add_object_given_number(2, PdfInteger(20))
  document.add_object_given_number(3, PdfInteger(30))
  let original = try! @pdflite.pdf_write_document_with_xref_stream(document)
  let original_parsed = try! @pdflite.pdf_read_document_from_bytes(original)
  @test.assert_eq(original_parsed.event_log(), [])

  let updated = original_parsed.copy()
  updated.add_object_given_number(2, PdfInteger(33))
  updated.add_object_given_number(2, PdfInteger(44))
  updated.remove_object(3)
  let rendered = try! @pdflite.pdf_write_document_incremental_update_with_xref_stream(
    original, updated,
  )
  @test.assert_eq(
    writer_find_bytes_from(
      rendered,
      writer_ascii_for_test("/Index"),
      original.length(),
    ) >
    0,
    true,
  )
  @test.assert_eq(
    writer_find_bytes_from(
      rendered,
      writer_ascii_for_test("2 0 obj"),
      original.length(),
    ) >
    0,
    true,
  )
  @test.assert_eq(
    writer_find_bytes_from(
      rendered,
      writer_ascii_for_test("1 0 obj"),
      original.length(),
    ),
    -1,
  )
  @test.assert_eq(
    writer_find_bytes_from(
      rendered,
      writer_ascii_for_test("3 0 obj"),
      original.length(),
    ),
    -1,
  )

  let reparsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(reparsed.object_numbers(), [1, 2])
  @test.assert_eq(reparsed.lookup_object_or_null(1), catalog)
  @test.assert_eq(reparsed.lookup_object_or_null(2), PdfInteger(44))
  @test.assert_eq(reparsed.lookup_object_or_null(3), PdfNull)
}

///|
test "pdf_write_document_incremental_update_with_compressed_xref_stream uses Flate" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 5)
  document.set_root(1)
  let value_name = writer_name_for_test([47, 86, 97, 108, 117, 101])
  document.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(value_name, PdfInteger(1))]),
  )
  let original = try! @pdflite.pdf_write_document_with_xref_stream(document)
  let original_parsed = try! @pdflite.pdf_read_document_from_bytes(original)
  let updated = original_parsed.copy()
  let updated_catalog = @pdflite.pdf_dictionary([
    (value_name, PdfInteger(3)),
    (writer_name_for_test([47, 70, 108, 97, 116, 101]), PdfIndirect(2)),
  ])
  updated.add_object_given_number(1, updated_catalog)
  updated.add_object_given_number(2, PdfInteger(88))
  let rendered = try! @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    original, updated,
  )
  @test.assert_eq(writer_bytes_start_with_at(rendered, original, 0), true)
  @test.assert_eq(
    writer_find_bytes(
      rendered,
      writer_ascii_for_test("/Prev " + original_parsed.first_xref().to_string()),
    ) >
    0,
    true,
  )
  @test.assert_eq(
    writer_find_bytes(rendered, writer_ascii_for_test("/FlateDecode")) > 0,
    true,
  )
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(reparsed.version(), (1, 5))
  @test.assert_eq(reparsed.first_xref() > original.length(), true)
  @test.assert_eq(reparsed.object_numbers(), [1, 2])
  @test.assert_eq(reparsed.lookup_object_or_null(1), updated_catalog)
  @test.assert_eq(reparsed.lookup_object_or_null(2), PdfInteger(88))
}

///|
test "pdf_write_document_with_compressed_xref_stream uses Flate and round trips" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 7)
  document.set_root(1)
  let type_name = writer_name_for_test([47, 84, 121, 112, 101])
  let catalog_name = writer_name_for_test([47, 67, 97, 116, 97, 108, 111, 103])
  document.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(type_name, PdfNameObject(catalog_name))]),
  )
  let rendered = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    document,
  )
  @test.assert_eq(
    writer_find_bytes(rendered, writer_ascii_for_test("/FlateDecode")) > 0,
    true,
  )
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.version(), (1, 7))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

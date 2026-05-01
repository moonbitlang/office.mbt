///|
fn writer_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
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

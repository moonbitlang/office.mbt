///|
test "pdf_read_header_from_cursor finds header and sets input offset" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    reader_bytes_for_test([0, 1, 2, 37, 80, 68, 70, 45, 49, 46, 55, 10, 65]),
  )
  @test.assert_eq(try! @pdflite.pdf_read_header_from_cursor(cursor), {
    major: 1,
    minor: 7,
  })
  @test.assert_eq(cursor.absolute_position(), 11)
  @test.assert_eq(cursor.position(), 8)
  @test.assert_eq(cursor.peek_byte(), 10)
}

///|
test "pdf_read_header_from_bytes defaults to PDF 2.0 when no header is found" {
  @test.assert_eq(
    try! @pdflite.pdf_read_header_from_bytes(reader_bytes_for_test([65, 66])),
    @pdflite.pdf_default_version,
  )
}

///|
test "pdf_read_header_from_bytes ignores malformed header digits" {
  @test.assert_eq(
    try! @pdflite.pdf_read_header_from_bytes(reader_pdf_ascii("%PDF-A.B\n")),
    @pdflite.pdf_default_version,
  )
}

///|
test "pdf_read_header_from_view reads borrowed slices" {
  let wrapped = reader_pdf_ascii("xx%PDF-1.6\nzz")
  @test.assert_eq(
    try! @pdflite.pdf_read_header_from_view(wrapped[2:wrapped.length() - 2]),
    { major: 1, minor: 6 },
  )
}

///|
test "pdf_document_of_parsed_indirect_objects preserves version and generations" {
  let document = @pdflite.pdf_document_of_parsed_indirect_objects(
    [
      { number: 7, generation: 2, object: PdfInteger(70) },
      { number: 3, generation: 0, object: PdfBoolean(true) },
    ],
    version={ major: 1, minor: 6 },
  )
  @test.assert_eq(document.version(), (1, 6))
  @test.assert_eq(document.object_numbers(), [3, 7])
  @test.assert_eq(document.lookup_object_or_null(7), PdfInteger(70))
}

///|
test "pdf_read_primitive_document_from_bytes loads non-stream indirect objects" {
  let document = try! @pdflite.pdf_read_primitive_document_from_bytes(
    reader_bytes_for_test([
      37, 80, 68, 70, 45, 49, 46, 52, 10, 49, 32, 48, 32, 111, 98, 106, 10, 60, 60,
      32, 47, 84, 121, 112, 101, 32, 47, 67, 97, 116, 97, 108, 111, 103, 32, 47,
      80, 97, 103, 101, 115, 32, 50, 32, 48, 32, 82, 32, 62, 62, 10, 101, 110, 100,
      111, 98, 106, 10, 50, 32, 48, 32, 111, 98, 106, 10, 91, 49, 32, 50, 93, 10,
      101, 110, 100, 111, 98, 106, 10, 120, 114, 101, 102,
    ]),
  )
  @test.assert_eq(document.version(), (1, 4))
  @test.assert_eq(document.object_numbers(), [1, 2])
  @test.assert_eq(
    document.lookup_object_or_null(2),
    @pdflite.pdf_array([PdfInteger(1), PdfInteger(2)]),
  )
}

///|
test "pdf_parse_indirect_object_from_bytes treats empty objects as null" {
  let parsed = try! @pdflite.pdf_parse_indirect_object_from_bytes(
    reader_pdf_ascii("2 0 obj\nendobj\n"),
  )
  @test.assert_eq(parsed.number, 2)
  @test.assert_eq(parsed.generation, 0)
  @test.assert_eq(parsed.object, PdfNull)
}

///|
test "pdf_parse_indirect_object_from_bytes accepts missing endobj" {
  let parsed = try! @pdflite.pdf_parse_indirect_object_from_bytes(
    reader_pdf_ascii("2 0 obj\n42\n"),
  )
  @test.assert_eq(parsed.number, 2)
  @test.assert_eq(parsed.generation, 0)
  @test.assert_eq(parsed.object, PdfInteger(42))
}

///|
test "pdf_read_primitive_document_from_view loads borrowed slices" {
  let payload = reader_pdf_ascii("%PDF-1.4\n1 0 obj\n[1 2]\nendobj\nxref")
  let wrapped = reader_wrap_view_for_test("abc", payload, "xyz")
  let document = try! @pdflite.pdf_read_primitive_document_from_view(
    wrapped[3:wrapped.length() - 3],
  )
  @test.assert_eq(document.version(), (1, 4))
  @test.assert_eq(document.object_numbers(), [1])
  @test.assert_eq(
    document.lookup_object_or_null(1),
    @pdflite.pdf_array([PdfInteger(1), PdfInteger(2)]),
  )
}

///|
test "pdf_read_primitive_document_from_bytes accepts missing plain endobj" {
  let document = try! @pdflite.pdf_read_primitive_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\n1 0 obj\n42\nxref"),
  )
  @test.assert_eq(document.object_numbers(), [1])
  @test.assert_eq(document.lookup_object_or_null(1), PdfInteger(42))
}

///|
test "pdf_read_primitive_document_from_bytes continues after missing plain endobj" {
  let document = try! @pdflite.pdf_read_primitive_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\n1 0 obj\n42\n2 0 obj\n43\nxref"),
  )
  @test.assert_eq(document.object_numbers(), [1, 2])
  @test.assert_eq(document.lookup_object_or_null(1), PdfInteger(42))
  @test.assert_eq(document.lookup_object_or_null(2), PdfInteger(43))
}

///|
test "pdf_parse_stream_object_from_bytes parses direct-length stream objects" {
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_bytes_for_test([
      55, 32, 48, 32, 111, 98, 106, 10, 60, 60, 32, 47, 76, 101, 110, 103, 116, 104,
      32, 53, 32, 62, 62, 10, 115, 116, 114, 101, 97, 109, 10, 72, 101, 108, 108,
      111, 10, 101, 110, 100, 115, 116, 114, 101, 97, 109, 10, 101, 110, 100, 111,
      98, 106,
    ]),
  )
  @test.assert_eq(parsed.number, 7)
  @test.assert_eq(parsed.generation, 0)
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(
        reader_bytes_for_test([47, 76, 101, 110, 103, 116, 104]),
      ),
    ),
    Some(PdfInteger(5)),
  )
  @test.assert_eq(
    stream.data,
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
}

///|
test "pdf_parse_stream_object_from_bytes recovers CamlPDF mismatched stream lengths" {
  let too_short = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii(
      "7 0 obj\n<< /Length 5 >>\nstream\nHello!\nendstream\nendobj",
    ),
  )
  guard too_short.object is PdfStreamObject(too_short_stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    too_short_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
    ),
    Some(PdfInteger(6)),
  )
  @test.assert_eq(too_short_stream.data, StreamGot(reader_pdf_ascii("Hello!")))

  let too_long = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii("8 0 obj\n<< /Length 8 >>\nstream\nHi\nendstream\nendobj"),
  )
  guard too_long.object is PdfStreamObject(too_long_stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    too_long_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
    ),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(too_long_stream.data, StreamGot(reader_pdf_ascii("Hi")))
}

///|
test "pdf_parse_stream_object_from_view parses borrowed stream object slices" {
  let data = reader_pdf_ascii(
    "x\n7 0 obj\n<< /Length 5 >>\nstream\nHello\nendstream\nendobj\nx",
  )
  let parsed = try! @pdflite.pdf_parse_stream_object_from_view(
    data[2:data.length() - 2],
  )
  @test.assert_eq(parsed.number, 7)
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(stream.data, StreamGot(reader_pdf_ascii("Hello")))
}

///|
test "pdf_parse_stream_object_from_bytes accepts CR and CRLF stream line breaks" {
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii(
      "7 0 obj\n<< /Length 5 >>\nstream\rHello\rendstream\nendobj",
    ),
  )
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(stream.data, StreamGot(reader_pdf_ascii("Hello")))

  let crlf = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii(
      "8 0 obj\n<< /Length 5 >>\nstream\r\nWorld\r\nendstream\nendobj",
    ),
  )
  guard crlf.object is PdfStreamObject(crlf_stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(crlf_stream.data, StreamGot(reader_pdf_ascii("World")))
}

///|
test "pdf_parse_stream_object_from_bytes ignores CamlPDF stream-start padding" {
  let padded : Array[Byte] = []
  reader_push_ascii(padded, "9 0 obj\n<< /Length 5 >>\nstream")
  reader_push_byte(padded, 32)
  reader_push_byte(padded, 9)
  reader_push_byte(padded, 0)
  reader_push_byte(padded, 12)
  reader_push_byte(padded, 10)
  reader_push_ascii(padded, "Space\nendstream\nendobj")
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(
    Bytes::from_array(padded),
  )
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(stream.data, StreamGot(reader_pdf_ascii("Space")))

  let no_line_break : Array[Byte] = []
  reader_push_ascii(no_line_break, "10 0 obj\n<< /Length 5 >>\nstream")
  reader_push_byte(no_line_break, 32)
  reader_push_byte(no_line_break, 9)
  reader_push_ascii(no_line_break, "Helloendstream\nendobj")
  let parsed_no_line_break = try! @pdflite.pdf_parse_stream_object_from_bytes(
    Bytes::from_array(no_line_break),
  )
  guard parsed_no_line_break.object is PdfStreamObject(no_line_break_stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    no_line_break_stream.data,
    StreamGot(reader_pdf_ascii("Hello")),
  )
}

///|
test "pdf_parse_stream_object_from_bytes recovers missing stream length" {
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii("7 0 obj\n<< >>\nstream\nHello\nendstream\nendobj"),
  )
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
    ),
    Some(PdfInteger(5)),
  )
  @test.assert_eq(stream.data, StreamGot(reader_pdf_ascii("Hello")))
}

///|
test "pdf_parse_stream_object_from_bytes reports malformed stream keyword" {
  let result : Result[@pdflite.PdfParsedIndirectObject, Error] = try? @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii(
      "7 0 obj\n<< /Length 5 >>\nstram\nHello\nendstream\nendobj",
    ),
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected @pdflite.PdfError::ParseStreamExpected")
  }
}

///|
test "pdf_read_primitive_document_from_bytes includes direct-length stream objects" {
  let document = try! @pdflite.pdf_read_primitive_document_from_bytes(
    reader_bytes_for_test([
      37, 80, 68, 70, 45, 49, 46, 52, 10, 49, 32, 48, 32, 111, 98, 106, 10, 60, 60,
      32, 47, 76, 101, 110, 103, 116, 104, 32, 53, 32, 62, 62, 10, 115, 116, 114,
      101, 97, 109, 10, 72, 101, 108, 108, 111, 10, 101, 110, 100, 115, 116, 114,
      101, 97, 109, 10, 101, 110, 100, 111, 98, 106, 10, 50, 32, 48, 32, 111, 98,
      106, 10, 110, 117, 108, 108, 10, 101, 110, 100, 111, 98, 106, 10, 120, 114,
      101, 102,
    ]),
  )
  @test.assert_eq(document.object_numbers(), [1, 2])
  guard document.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    stream.data,
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
  @test.assert_eq(document.lookup_object_or_null(2), PdfNull)
}

///|
test "pdf_read_classic_document_from_bytes uses xref and trailer root" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  let type_name = @pdflite.pdf_name_of_bytes(
    reader_bytes_for_test([47, 84, 121, 112, 101]),
  )
  let catalog = @pdflite.pdf_dictionary([
    (
      type_name,
      PdfNameObject(
        @pdflite.pdf_name_of_bytes(
          reader_bytes_for_test([47, 67, 97, 116, 97, 108, 111, 103]),
        ),
      ),
    ),
  ])
  document.add_object_given_number(1, catalog)
  let rendered = try! @pdflite.pdf_write_document(document)
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(rendered)
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(parsed.lookup_object_or_null(1), catalog)
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_bytes_for_test([47, 82, 111, 111, 116])),
    ),
    Some(PdfIndirect(1)),
  )
}

///|
test "pdf_read_classic_document_from_bytes skips non-digit startxref prefixes" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_prefixed_startxref_pointer(),
  )
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_classic_document_from_bytes accepts inline startxref pointers" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_inline_startxref_pointer(),
  )
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_classic_document_from_view reads borrowed slices" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  document.add_object_given_number(1, PdfInteger(42))
  let rendered = try! @pdflite.pdf_write_document(document)
  let wrapped = reader_wrap_view_for_test("abc", rendered, "xyz")
  let parsed = try! @pdflite.pdf_read_classic_document_from_view(
    wrapped[3:wrapped.length() - 3],
  )
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(42))
}

///|
test "pdf_read_classic_document_from_bytes reads stream objects by xref" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
  document.add_object_given_number(1, stream)
  let rendered = try! @pdflite.pdf_write_document(document)
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(rendered)
  guard parsed.lookup_object_or_null(1) is PdfStreamObject(parsed_stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    parsed_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(
        reader_bytes_for_test([47, 76, 101, 110, 103, 116, 104]),
      ),
    ),
    Some(PdfInteger(5)),
  )
  try! reader_assert_deferred_stream_data_for_test(
    parsed_stream,
    reader_bytes_for_test([72, 101, 108, 108, 111]),
  )
}

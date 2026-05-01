///|
fn reader_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn reader_push_byte(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
}

///|
fn reader_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text)[:] {
    output.push(byte)
  }
}

///|
fn reader_push_padded_decimal(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let text = value.to_string()
  if text.length() < width {
    for _ in 0..<(width - text.length()) {
      reader_push_byte(output, 48)
    }
  }
  reader_push_ascii(output, text)
}

///|
fn reader_push_xref_entry(
  output : Array[Byte],
  offset : Int,
  generation : Int,
) -> Unit {
  reader_push_padded_decimal(output, offset, 10)
  reader_push_byte(output, 32)
  reader_push_padded_decimal(output, generation, 5)
  reader_push_ascii(output, " n \n")
}

///|
fn reader_classic_pdf_with_indirect_stream_length() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = output.length()
  reader_push_ascii(
    output, "1 0 obj\n<< /Length 2 0 R >>\nstream\nHello\nendstream\nendobj\n",
  )
  let length_offset = output.length()
  reader_push_ascii(output, "2 0 obj\n5\nendobj\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, length_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_prev_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let original_offset = output.length()
  reader_push_ascii(output, "1 0 obj\n1\nendobj\n")
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, original_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  let updated_offset = output.length()
  reader_push_ascii(output, "1 0 obj\n2\nendobj\n")
  let second_offset = output.length()
  reader_push_ascii(output, "2 0 obj\n3\nendobj\n")
  let final_xref = output.length()
  reader_push_ascii(output, "xref\n1 2\n")
  reader_push_xref_entry(output, updated_offset, 0)
  reader_push_xref_entry(output, second_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 /Prev ")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  reader_push_ascii(output, final_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_prev_deleted_object() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let original_offset = output.length()
  reader_push_ascii(output, "1 0 obj\n1\nendobj\n")
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, original_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  let final_xref = output.length()
  reader_push_ascii(
    output, "xref\n1 1\n0000000000 00000 f \ntrailer\n<< /Root 1 0 R /Size 2 /Prev ",
  )
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  reader_push_ascii(output, final_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
test "ByteCursor read_pdf_header finds header and sets input offset" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    reader_bytes_for_test([0, 1, 2, 37, 80, 68, 70, 45, 49, 46, 55, 10, 65]),
  )
  @test.assert_eq(try! cursor.read_pdf_header(), { major: 1, minor: 7 })
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
test "pdf_parse_stream_object_from_bytes reports missing stream length" {
  let result : Result[@pdflite.PdfParsedIndirectObject, Error] = try? @pdflite.pdf_parse_stream_object_from_bytes(
    reader_bytes_for_test([
      55, 32, 48, 32, 111, 98, 106, 10, 60, 60, 32, 62, 62, 10, 115, 116, 114, 101,
      97, 109, 10,
    ]),
  )
  guard result is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected StreamLengthExpected")
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
  @test.assert_eq(
    parsed_stream.data,
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
}

///|
test "pdf_read_classic_document_from_bytes resolves indirect stream length" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_indirect_stream_length(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  guard parsed.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(
        reader_bytes_for_test([47, 76, 101, 110, 103, 116, 104]),
      ),
    ),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    stream.data,
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(5))
}

///|
test "pdf_read_classic_document_from_bytes follows trailer Prev xrefs" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_prev_xref(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(3))
}

///|
test "pdf_read_classic_document_from_bytes keeps newer deleted xref entries" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_prev_deleted_object(),
  )
  @test.assert_eq(parsed.object_numbers(), [])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfNull)
}

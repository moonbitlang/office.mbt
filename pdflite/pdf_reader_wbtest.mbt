///|
fn reader_wbtest_bytes(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn reader_wbtest_name(text : String) -> PdfName {
  pdf_name_of_bytes(reader_wbtest_bytes(text))
}

///|
fn reader_wbtest_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn reader_wbtest_xref_stream_without_root() -> PdfBytes {
  let output : Array[Byte] = []
  reader_wbtest_push_ascii(output, "%PDF-1.5\n")
  let xref_offset = output.length()
  reader_wbtest_push_ascii(
    output, "1 0 obj\n<< /Type /XRef /Size 1 /W [1 4 2] /Length 7 >>\nstream\n",
  )
  for byte in [0, 0, 0, 0, 0, 255, 255] {
    output.push(byte.to_byte())
  }
  reader_wbtest_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_wbtest_push_ascii(output, xref_offset.to_string())
  reader_wbtest_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
test "private object-stream member parser handles direct stream members" {
  let object = try! pdf_parse_object_stream_member_from_view(
    reader_wbtest_bytes("<< /Length 2 >>\nstream\nHi\nendstream"),
  )
  guard object is PdfStreamObject(stream) else {
    fail("expected stream member")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(reader_wbtest_name("/Length")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(stream.data, StreamGot(reader_wbtest_bytes("Hi")))
}

///|
test "private object-stream member parser repairs missing lengths" {
  let object = try! pdf_parse_object_stream_member_from_view(
    reader_wbtest_bytes("<< >>\nstream\nHi\nendstream"),
  )
  guard object is PdfStreamObject(stream) else {
    fail("expected repaired stream member")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(reader_wbtest_name("/Length")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(stream.data, StreamGot(reader_wbtest_bytes("Hi")))
}

///|
test "private object-stream member parser repairs mismatched lengths" {
  let object = try! pdf_parse_object_stream_member_from_view(
    reader_wbtest_bytes("<< /Length 1 >>\nstream\nHi\nendstream"),
  )
  guard object is PdfStreamObject(stream) else {
    fail("expected repaired stream member")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(reader_wbtest_name("/Length")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(stream.data, StreamGot(reader_wbtest_bytes("Hi")))
}

///|
test "private object-stream member parser reports missing endstream markers" {
  let result : Result[PdfObject, Error] = try? pdf_parse_object_stream_member_from_view(
    reader_wbtest_bytes("<< >>\nstream\nHi"),
  )
  guard result is Err(PdfError::ParseEndStreamExpected) else {
    fail("expected PdfError::ParseEndStreamExpected")
  }
}

///|
test "private object-stream member parser rejects non-dictionary streams" {
  let result : Result[PdfObject, Error] = try? pdf_parse_object_stream_member_from_view(
    reader_wbtest_bytes("7\nstream\nHi\nendstream"),
  )
  guard result is Err(PdfError::ParseSingleObjectExpected) else {
    fail("expected PdfError::ParseSingleObjectExpected")
  }
}

///|
test "private reconstructed coverage ignores xref sections without offsets" {
  let coverage = pdf_reconstructed_xref_coverage(
    reader_wbtest_bytes("%PDF-1.5\n"),
    [],
    [
      {
        entries: [],
        trailer: PdfNull,
        stream_object_number: Some(7),
        stream_object_offset: None,
      },
    ],
  )
  @test.assert_eq(coverage.contains(7, 0), false)
}

///|
test "private object-stream root reconstruction guard rejects missing trailer roots" {
  @test.assert_eq(
    pdf_reader_startxref_root_uses_object_stream(
      reader_wbtest_xref_stream_without_root(),
    ),
    false,
  )
}

///|
test "reconstructed document ignores streams that become invalid after xref recovery" {
  let parsed = try! pdf_read_document_from_bytes(
    reader_wbtest_bytes(
      "%PDF-1.4\n1 0 obj\n<< /Length 2 0 R >>\nstream\nHi\nendstream\nendobj\n2 0 obj\n999999\nendobj\n3 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 3 0 R /Size 4 >>\n",
    ),
  )
  @test.assert_eq(parsed.root(), 3)
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfNull)
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(999999))
}

///|
test "private reconstructed classic xref reader rejects xref streams" {
  let cursor = byte_cursor_of_view(
    reader_wbtest_bytes(
      "7 0 obj\n<< /Type /XRef /Size 1 /W [1 4 2] /Length 7 >>\nstream\n\\u{0}\\u{0}\\u{0}\\u{0}\\u{0}\\u{255}\\u{255}\nendstream\nendobj",
    ),
  )
  let result : Result[(PdfXRefSection, Int), Error] = try? cursor.read_reconstructed_classic_xref_section_at(
    0,
  )
  guard result is Err(PdfError::XRefExpected) else {
    fail("expected PdfError::XRefExpected")
  }
}

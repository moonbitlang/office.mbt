///|
fn test_trailer_dictionary(
  values : Array[(@core.PdfName, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  PdfDictionary(values)
}

///|
fn test_trailer_integer(value : Int) -> @syntax.PdfObject {
  PdfInteger(value)
}

///|
fn test_trailer_name(name : @core.PdfName) -> @syntax.PdfObject {
  PdfNameObject(name)
}

///|
test "trailer helpers parse prev and xref stream offsets" {
  let trailer = test_trailer_dictionary([
    (@reader.pdf_reader_prev_name(), test_trailer_integer(42)),
    (@reader.pdf_reader_xrefstm_name(), test_trailer_integer(99)),
  ])
  @test.assert_eq(try! @reader.pdf_trailer_prev_position(trailer), Some(42))
  @test.assert_eq(
    try! @reader.pdf_trailer_xref_stream_position(trailer),
    Some(99),
  )

  let empty = test_trailer_dictionary([])
  @test.assert_eq(try! @reader.pdf_trailer_prev_position(empty), None)
  @test.assert_eq(try! @reader.pdf_trailer_xref_stream_position(empty), None)
}

///|
test "trailer helpers reject malformed offsets" {
  let negative_prev : Result[Int?, Error] = try? @reader.pdf_trailer_prev_position(
    test_trailer_dictionary([
      (@reader.pdf_reader_prev_name(), test_trailer_integer(-1)),
    ]),
  )
  guard negative_prev is Err(@core.PdfError::TrailerExpected) else {
    fail("expected TrailerExpected")
  }

  let non_integer_prev : Result[Int?, Error] = try? @reader.pdf_trailer_prev_position(
    test_trailer_dictionary([
      (
        @reader.pdf_reader_prev_name(),
        test_trailer_name(@reader.pdf_reader_name("/Bad")),
      ),
    ]),
  )
  guard non_integer_prev is Err(@core.PdfError::TrailerExpected) else {
    fail("expected TrailerExpected")
  }

  let negative_xrefstm : Result[Int?, Error] = try? @reader.pdf_trailer_xref_stream_position(
    test_trailer_dictionary([
      (@reader.pdf_reader_xrefstm_name(), test_trailer_integer(-1)),
    ]),
  )
  guard negative_xrefstm is Err(@core.PdfError::XRefExpected) else {
    fail("expected XRefExpected")
  }
}

///|
test "trailer sanitization removes transient reader keys" {
  let sanitized = try! @reader.pdf_reader_sanitize_trailer(
    test_trailer_dictionary([
      (@reader.pdf_reader_prev_name(), test_trailer_integer(12)),
      (@reader.pdf_reader_xrefstm_name(), test_trailer_integer(44)),
      (@reader.pdf_reader_w_name(), PdfArray([test_trailer_integer(1)])),
      (
        @reader.pdf_reader_type_name(),
        test_trailer_name(@reader.pdf_reader_xref_name()),
      ),
      (@reader.pdf_reader_index_name(), PdfArray([test_trailer_integer(0)])),
      (
        @reader.pdf_reader_filter_name(),
        test_trailer_name(@reader.pdf_reader_name("/FlateDecode")),
      ),
      (@reader.pdf_reader_decodeparms_name(), test_trailer_dictionary([])),
      (@reader.pdf_reader_root_name(), PdfIndirect(1)),
    ]),
    8,
  )

  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_size_name()),
    Some(test_trailer_integer(8)),
  )
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_root_name()),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_prev_name()),
    None,
  )
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_xrefstm_name()),
    None,
  )
  @test.assert_eq(sanitized.lookup_immediate(@reader.pdf_reader_w_name()), None)
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_type_name()),
    None,
  )
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_index_name()),
    None,
  )
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_filter_name()),
    None,
  )
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_decodeparms_name()),
    None,
  )
}

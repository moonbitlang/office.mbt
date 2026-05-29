///|
test "object stream number offsets parse header pairs" {
  @test.assert_eq(
    try! @reader.pdf_object_stream_number_offsets(
      @ascii.encode("2 0 3 4 truefalse"),
      8,
      2,
    ),
    [(2, 0), (3, 4)],
  )
}

///|
test "object stream number offsets reject malformed headers" {
  let bad_first : Result[Array[(Int, Int)], Error] = try? @reader.pdf_object_stream_number_offsets(
    @ascii.encode("1 0"),
    4,
    1,
  )
  guard bad_first is Err(@core.PdfError::StreamDataExpected) else {
    fail("expected StreamDataExpected")
  }

  let short_header : Result[Array[(Int, Int)], Error] = try? @reader.pdf_object_stream_number_offsets(
    @ascii.encode("2 "),
    2,
    1,
  )
  guard short_header is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let malformed_pair : Result[Array[(Int, Int)], Error] = try? @reader.pdf_object_stream_number_offsets(
    @ascii.encode("/Name 0 "),
    8,
    1,
  )
  guard malformed_pair is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}

///|
test "object stream end offsets preserve duplicate starts" {
  @test.assert_eq(
    @reader.pdf_object_stream_end_offsets(
      [(2, 4), (3, 0), (4, 4), (5, 8)],
      20,
      8,
    ),
    [8, 4, 8, 12],
  )
  @test.assert_eq(
    @reader.pdf_object_stream_end_offsets([(2, 0), (3, 100)], 20, 8),
    [12, 12],
  )
}

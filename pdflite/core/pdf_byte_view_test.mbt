///|
test "byte view ascii search helpers cover boundaries" {
  let view = @ascii.encode("abc")[:]
  @test.assert_eq(@core.pdf_view_matches_ascii_at(view, -1, [97]), false)
  @test.assert_eq(@core.pdf_view_matches_ascii_at(view, 2, [98, 99]), false)
  @test.assert_eq(@core.pdf_find_last_ascii(view, []), 3)
  @test.assert_eq(@core.pdf_find_last_ascii(view[:1], [97, 98]), -1)
  @test.assert_eq(@core.pdf_find_last_ascii(view, [120]), -1)
}

///|
test "byte view ascii integer parser rejects malformed input" {
  let empty_number : Result[Int, Error] = try? @core.pdf_parse_ascii_int_view(
    Bytes::new(0),
  )
  guard empty_number is Err(@core.PdfError::NumberExpected) else {
    fail("expected PdfError::NumberExpected")
  }
  let bad_number : Result[Int, Error] = try? @core.pdf_parse_ascii_int_view(
    @ascii.encode("12a"),
  )
  guard bad_number is Err(@core.PdfError::NumberExpected) else {
    fail("expected PdfError::NumberExpected")
  }
  let overflow_number : Result[Int, Error] = try? @core.pdf_parse_ascii_int_view(
    @ascii.encode("2147483648"),
  )
  guard overflow_number is Err(@core.PdfError::NumberExpected) else {
    fail("expected PdfError::NumberExpected")
  }
  @test.assert_eq(
    try! @core.pdf_parse_ascii_int_view(@ascii.encode("2147483647")),
    2147483647,
  )
}

///|
test "byte view whitespace splitter returns borrowed token slices" {
  let tokens = @core.pdf_split_whitespace_tokens(@ascii.encode(" one\t two\n"))
  @test.assert_eq(tokens.length(), 2)
  @test.assert_eq(@core.pdf_view_equals_ascii(tokens[0], [111, 110, 101]), true)
  @test.assert_eq(@core.pdf_view_equals_ascii(tokens[1], [116, 119, 111]), true)
}

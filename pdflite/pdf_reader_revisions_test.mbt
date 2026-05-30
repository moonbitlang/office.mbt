///|
test "pdf_read_document_from_bytes records linearized first-object marker" {
  let integer_marker = try! @pdflite.pdf_read_document_from_bytes(
    reader_linearized_classic_pdf("1"),
  )
  @test.assert_eq(integer_marker.was_linearized(), true)
  @test.assert_eq(integer_marker.root(), 2)

  let real_marker = try! @pdflite.pdf_read_document_from_bytes(
    reader_linearized_classic_pdf("1.0"),
  )
  @test.assert_eq(real_marker.was_linearized(), true)

  let non_numeric_marker = try! @pdflite.pdf_read_document_from_bytes(
    reader_linearized_classic_pdf("/Name"),
  )
  @test.assert_eq(non_numeric_marker.was_linearized(), false)

  let leading_junk = try! @pdflite.pdf_read_document_from_bytes(
    reader_classic_pdf_with_leading_junk(),
  )
  @test.assert_eq(leading_junk.was_linearized(), false)
}

///|
test "pdf_is_linearized probes byte input without full parsing" {
  @test.assert_eq(
    @pdflite.pdf_is_linearized(reader_linearized_classic_pdf("1")),
    true,
  )
  @test.assert_eq(
    @pdflite.pdf_is_linearized(reader_linearized_classic_pdf("/Name")),
    false,
  )
  @test.assert_eq(
    @pdflite.pdf_is_linearized(reader_classic_pdf_with_leading_junk()),
    false,
  )
  @test.assert_eq(
    @pdflite.pdf_is_linearized(reader_pdf_ascii("not a pdf")),
    false,
  )
}

///|
test "pdf_revisions_from_bytes counts classic Prev chain revisions" {
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(
      reader_classic_pdf_with_indirect_stream_length(),
    ),
    1,
  )
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(reader_classic_pdf_with_prev_xref()),
    2,
  )
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(reader_linearized_classic_pdf("1")),
    1,
  )
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(
      reader_linearized_classic_pdf_with_prev_xref(),
    ),
    1,
  )
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(
      reader_xref_stream_pdf_with_prev_update(),
    ),
    2,
  )
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(
      reader_xref_stream_pdf_with_prev_deleted_object(),
    ),
    2,
  )
}

///|
test "pdf_revisions_from_bytes ignores trailing startxref junk after EOF" {
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(
      reader_classic_pdf_with_trailing_startxref_junk(),
    ),
    1,
  )
}

///|
test "pdf_revisions_from_bytes skips non-digit startxref prefixes" {
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(
      reader_classic_pdf_with_prefixed_startxref_pointer(),
    ),
    1,
  )
}

///|
test "pdf_revisions_from_bytes accepts inline startxref pointers" {
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_bytes(
      reader_classic_pdf_with_inline_startxref_pointer(),
    ),
    1,
  )
}

///|
test "pdf_revisions_from_view reads borrowed revision metadata slices" {
  let payload = reader_classic_pdf_with_prev_xref()
  let wrapped = reader_wrap_view_for_test("abc", payload, "xyz")
  @test.assert_eq(
    try! @pdflite.pdf_revisions_from_view(wrapped[3:wrapped.length() - 3]),
    2,
  )
}

///|
test "pdf_revisions_from_bytes reports malformed revision metadata" {
  let missing_startxref : Result[Int, Error] = try? @pdflite.pdf_revisions_from_bytes(
    reader_pdf_ascii("%PDF-1.4\nxref\n0 1\n0000000000 65535 f \n%%EOF\n"),
  )
  guard missing_startxref is Err(@core.PdfError::StartXRefExpected) else {
    fail("expected @core.PdfError::StartXRefExpected")
  }

  let malformed_prev : Result[Int, Error] = try? @pdflite.pdf_revisions_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 /Prev /Bad >>",
    ),
  )
  guard malformed_prev is Err(@core.PdfError::TrailerExpected) else {
    fail("expected @core.PdfError::TrailerExpected")
  }

  let cyclic_prev : Result[Int, Error] = try? @pdflite.pdf_revisions_from_bytes(
    reader_classic_pdf_with_self_prev_xref(),
  )
  guard cyclic_prev is Err(@core.PdfError::XRefExpected) else {
    fail("expected @core.PdfError::XRefExpected")
  }
}

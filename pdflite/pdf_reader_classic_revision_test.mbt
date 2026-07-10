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
      @core.pdf_name_of_bytes(
        reader_bytes_for_test([47, 76, 101, 110, 103, 116, 104]),
      ),
    ),
    Some(PdfIndirect(2)),
  )
  try! reader_assert_deferred_stream_data_for_test(
    stream,
    reader_bytes_for_test([72, 101, 108, 108, 111]),
  )
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(5))
}

///|
test "pdf_read_classic_document_from_bytes resolves commented indirect stream length" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_comment_stream_indirect_length(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  guard parsed.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      @core.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
    ),
    Some(PdfIndirect(2)),
  )
  try! reader_assert_deferred_stream_data_for_test(
    stream,
    reader_pdf_ascii("Hello"),
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
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
}

///|
test "pdf_read_classic_document_revision_from_bytes reads latest revision" {
  let parsed = try! @pdflite.pdf_read_classic_document_revision_from_bytes(
    reader_classic_pdf_with_prev_xref(),
    1,
  )
  @test.assert_eq(parsed.revision_read(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(3))
}

///|
test "pdf_read_document_revision_from_bytes wraps strict revision reader" {
  let parsed = try! @pdflite.pdf_read_document_revision_from_bytes(
    reader_classic_pdf_with_prev_xref(),
    1,
  )
  @test.assert_eq(parsed.revision_read(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(2))
}

///|
test "pdf_read_classic_document_revision_from_bytes reads older Prev revision" {
  let parsed = try! @pdflite.pdf_read_classic_document_revision_from_bytes(
    reader_classic_pdf_with_prev_xref(),
    2,
  )
  @test.assert_eq(parsed.revision_read(), 2)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(1))
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(parsed.first_xref() > 0, true)
}

///|
test "pdf_read_document_revision_from_view reads borrowed older revision" {
  let payload = reader_classic_pdf_with_prev_xref()
  let wrapped = reader_wrap_view_for_test("abc", payload, "xyz")
  let parsed = try! @pdflite.pdf_read_document_revision_from_view(
    wrapped[3:wrapped.length() - 3],
    2,
  )
  @test.assert_eq(parsed.revision_read(), 2)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(1))
}

///|
test "pdf_read_document_revision_with_passwords reads older revisions" {
  let bytes_result_option = try! @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
    reader_classic_pdf_with_prev_xref(),
    2,
  )
  guard bytes_result_option is Some(bytes_result) else {
    fail("expected decryption result")
  }
  @test.assert_eq(bytes_result.document.revision_read(), 2)
  @test.assert_eq(bytes_result.document.object_numbers(), [1])
  @test.assert_eq(bytes_result.document.lookup_object_or_null(1), PdfInteger(1))
  @test.assert_eq(bytes_result.denied_permissions, [])

  let payload = reader_classic_pdf_with_prev_xref()
  let wrapped = reader_wrap_view_for_test("abc", payload, "xyz")
  let view_result_option = try! @pdflite.pdf_read_document_revision_from_view_with_passwords(
    wrapped[3:wrapped.length() - 3],
    2,
    owner_password=Some(b"unused"),
  )
  guard view_result_option is Some(view_result) else {
    fail("expected borrowed-view decryption result")
  }
  @test.assert_eq(view_result.document.revision_read(), 2)
  @test.assert_eq(view_result.document.object_numbers(), [1])
  @test.assert_eq(view_result.document.lookup_object_or_null(1), PdfInteger(1))
  @test.assert_eq(view_result.denied_permissions, [])
}

///|
test "pdf_read_classic_document_revision_from_bytes reports bad revisions" {
  let invalid : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_revision_from_bytes(
      reader_classic_pdf_with_prev_xref(),
      0,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard invalid is Err(@core.PdfError::BadRevision) else {
    fail("expected @core.PdfError::BadRevision")
  }

  let missing : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_revision_from_bytes(
      reader_classic_pdf_with_prev_xref(),
      3,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing is Err(@core.PdfError::BadRevision) else {
    fail("expected @core.PdfError::BadRevision")
  }
}

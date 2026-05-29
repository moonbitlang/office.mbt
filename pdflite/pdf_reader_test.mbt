///|
test "pdf_read_document_from_bytes follows xref stream Prev chains" {
  let updated = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_prev_update(),
  )
  @test.assert_eq(updated.object_numbers(), [1])
  @test.assert_eq(updated.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(
    updated
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )

  let deleted = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_prev_deleted_object(),
  )
  @test.assert_eq(deleted.object_numbers(), [])
  @test.assert_eq(deleted.lookup_object_or_null(1), PdfNull)
}

///|
test "pdf_read_document_from_bytes follows compressed xref stream Prev chains" {
  let updated = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_compressed_prev_update(),
  )
  @test.assert_eq(updated.root(), 2)
  @test.assert_eq(updated.object_numbers(), [1, 2])
  @test.assert_eq(updated.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(
    updated
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
  @test.assert_eq(
    updated
    .trailer_dict()
    .lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/DecodeParms")),
    ),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs compressed xref stream Prev chains" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_compressed_prev_update_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let updated = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_compressed_prev_update_bad_startxref(),
  )
  @test.assert_eq(updated.first_xref(), 0)
  @test.assert_eq(updated.root(), 2)
  @test.assert_eq(updated.object_numbers(), [1, 2])
  @test.assert_eq(updated.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(
    updated
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
}

///|
test "pdf_read_document_revision_from_bytes reads xref stream older Prev revision" {
  let updated = try! @pdflite.pdf_read_document_revision_from_bytes(
    reader_xref_stream_pdf_with_prev_update(),
    2,
  )
  @test.assert_eq(updated.revision_read(), 2)
  @test.assert_eq(updated.object_numbers(), [1])
  @test.assert_eq(updated.lookup_object_or_null(1), PdfInteger(1))

  let deleted = try! @pdflite.pdf_read_document_revision_from_bytes(
    reader_xref_stream_pdf_with_prev_deleted_object(),
    2,
  )
  @test.assert_eq(deleted.revision_read(), 2)
  @test.assert_eq(deleted.object_numbers(), [1])
  @test.assert_eq(deleted.lookup_object_or_null(1), PdfInteger(1))
}

///|
test "pdf_read_document_revision_from_bytes reads compressed xref stream older Prev revision" {
  let updated = try! @pdflite.pdf_read_document_revision_from_bytes(
    reader_xref_stream_pdf_with_compressed_prev_update(),
    2,
  )
  @test.assert_eq(updated.revision_read(), 2)
  @test.assert_eq(updated.root(), 2)
  @test.assert_eq(updated.object_numbers(), [1, 2])
  @test.assert_eq(updated.lookup_object_or_null(1), PdfInteger(1))
}

///|
test "pdf_read_document_from_bytes extracts xref object-stream entries" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_object_stream(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3])
  @test.assert_eq(
    parsed.lookup_object_or_null(2),
    PdfDictionary([
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Answer")), PdfInteger(42)),
    ]),
  )
  guard parsed.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
    ),
    Some(PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/ObjStm")))),
  )
}

///|
test "pdf_read_document_from_bytes loads multiple entries from one object stream" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_two_object_stream_entries(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(
    parsed.lookup_object_or_null(2),
    PdfDictionary([
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Answer")), PdfInteger(42)),
    ]),
  )
  @test.assert_eq(
    parsed.lookup_object_or_null(5),
    PdfArray([PdfInteger(1), PdfInteger(2), PdfInteger(3)]),
  )
}

///|
test "pdf_read_document_from_bytes tolerates stream objects inside object streams" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_stream_object_in_object_stream(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3])
  guard parsed.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected malformed embedded stream object")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
    ),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(reader_stream_bytes_for_test(stream), reader_pdf_ascii("Hi"))
}

///|
test "pdf_read_document_from_bytes decodes object streams with indirect filters" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_indirect_object_stream_filter(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(
    parsed.lookup_object_or_null(5),
    PdfDictionary([
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Answer")), PdfInteger(42)),
    ]),
  )
  guard parsed.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter")),
    ),
    Some(PdfIndirect(2)),
  )
}

///|
test "pdf_read_document_from_bytes reconstructs object streams with indirect filters" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_indirect_object_stream_filter_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_indirect_object_stream_filter_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(
    parsed.lookup_object_or_null(5),
    PdfDictionary([
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Answer")), PdfInteger(42)),
    ]),
  )
  guard parsed.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter")),
    ),
    Some(PdfIndirect(2)),
  )
}

///|
test "pdf_read_document_from_bytes reconstructs physical page trees when object-stream bounds are malformed" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_bad_first_object_stream_root_and_physical_page_tree(),
  )
  guard strict is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected strict object-stream bounds failure")
  }
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_bad_first_object_stream_root_and_physical_page_tree(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(try! parsed.endpage(), 1)
  @test.assert_eq(try! parsed.page_reference_numbers(), [5])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Pages")), PdfIndirect(2)),
    ]),
  )
}

///|
test "pdf_read_document_from_bytes does not reconstruct mismatched object-stream roots" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_mismatched_object_stream_root_and_physical_catalog(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected strict object-stream mismatch failure")
  }

  let public : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_mismatched_object_stream_root_and_physical_catalog(),
  )
  guard public is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected public object-stream mismatch failure")
  }
}

///|
test "pdf_read_document_from_bytes_with_passwords rejects missing encrypted object streams" {
  let result : Result[@pdflite.PdfDecryptionResult?, Error] = try? @pdflite.pdf_read_document_from_bytes_with_passwords(
    reader_encrypted_xref_stream_pdf_with_missing_object_stream_for_test(),
  )
  guard result is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }
}

///|
test "pdf_read_document_from_bytes resolves indirect object-stream bounds" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_indirect_object_stream_bounds(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3, 5, 7])
  @test.assert_eq(
    parsed.lookup_object_or_null(7),
    PdfDictionary([
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Answer")), PdfInteger(42)),
    ]),
  )
}

///|
test "pdf_read_document_from_bytes reconstructs indirect object-stream bounds" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_indirect_object_stream_bounds_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_indirect_object_stream_bounds_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3, 5, 7])
  @test.assert_eq(
    parsed.lookup_object_or_null(7),
    PdfDictionary([
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Answer")), PdfInteger(42)),
    ]),
  )
}

///|
test "pdf_read_document_from_bytes rejects mismatched object-stream entries" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_mismatched_object_stream(),
  )
  guard result is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }
}

///|
test "pdf_read_document_from_bytes rejects invalid object-stream data slices" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_object_stream_bad_first(),
  )
  guard result is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected @pdflite.PdfError::StreamDataExpected")
  }
}

///|
test "pdf_read_document_from_bytes rejects non-xref startxref objects" {
  let non_stream : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_startxref_object_pdf("7"),
  )
  guard non_stream is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected @pdflite.PdfError::XRefExpected")
  }

  let wrong_stream_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_startxref_object_pdf("<< /Length 0 >>\nstream\n\nendstream"),
  )
  guard wrong_stream_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected @pdflite.PdfError::XRefExpected")
  }

  let explicit_wrong_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_wrong_type(),
  )
  guard explicit_wrong_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected explicit xref stream type rejection")
  }

  let non_name_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_non_name_type(),
  )
  guard non_name_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected non-name xref stream type rejection")
  }
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
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
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
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
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
    owner_password=Some(@ascii.encode("unused")),
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
  let invalid : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_revision_from_bytes(
    reader_classic_pdf_with_prev_xref(),
    0,
  )
  guard invalid is Err(@pdflite.PdfError::BadRevision) else {
    fail("expected @pdflite.PdfError::BadRevision")
  }

  let missing : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_revision_from_bytes(
    reader_classic_pdf_with_prev_xref(),
    3,
  )
  guard missing is Err(@pdflite.PdfError::BadRevision) else {
    fail("expected @pdflite.PdfError::BadRevision")
  }
}

///|
test "pdf_read_classic_document_from_bytes keeps newer deleted xref entries" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_prev_deleted_object(),
  )
  @test.assert_eq(parsed.object_numbers(), [])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfNull)
}

///|
test "pdf_read_classic_document_from_bytes accepts blank xref lines" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [])
}

///|
test "pdf_read_classic_document_from_bytes accepts malformed zero-offset xref rows" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 abcde n \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [])
  let marker_suffix = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 abcde nJunk\n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  @test.assert_eq(marker_suffix.root(), 1)
  @test.assert_eq(marker_suffix.object_numbers(), [])
}

///|
test "pdf_read_classic_document_from_bytes accepts repeated xref section markers" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "xref\nxref 0 1\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [])
}

///|
test "pdf_read_classic_document_from_bytes accepts fixed-width xref separators" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_fixed_width_xref_separators(),
  )
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
  let mixed_first = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000_65535 f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  @test.assert_eq(mixed_first.root(), 1)
  @test.assert_eq(mixed_first.object_numbers(), [])
  let mixed_second = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 65535_f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  @test.assert_eq(mixed_second.root(), 1)
  @test.assert_eq(mixed_second.object_numbers(), [])
}

///|
test "pdf_read_classic_document_from_bytes accepts CR-only xref lines" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_cr_line_endings_for_test(
      reader_classic_pdf_with_fixed_width_xref_separators(),
    ),
  )
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_classic_document_from_bytes accepts tokenized xref rows" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_unpadded_xref_entry(),
  )
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
  let free = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0 0 f\n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  @test.assert_eq(free.root(), 1)
  @test.assert_eq(free.object_numbers(), [])
}

///|
test "pdf_read_classic_document_from_bytes accepts inline xref section headers" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_inline_xref_section_header(),
  )
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
}

///|
test "pdf_read_classic_document_from_bytes accepts glued trailer dictionaries" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_glued_trailer_dictionary(),
  )
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_classic_document_from_bytes accepts missing plain endobj" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_missing_endobj_catalog(),
  )
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
}

///|
test "pdf_read_classic_document_from_bytes ignores trailing startxref junk after EOF" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_trailing_startxref_junk(),
  )
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [])
}

///|
test "pdf_read_classic_document_from_bytes reports missing startxref" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_pdf_ascii(
      "%PDF-1.4\nxref\n0 1\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 1 >>\n%%EOF\n",
    ),
  )
  guard result is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected @pdflite.PdfError::StartXRefExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports malformed startxref number" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\nstartxref\nabc\n%%EOF\n"),
  )
  guard result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected @pdflite.PdfError::NumberExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports missing xref marker" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\nstartxref\n9\n%%EOF\n"),
  )
  guard result is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected @pdflite.PdfError::XRefExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports trailerless xrefs" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_without_trailer_after_xref(),
  )
  guard result is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected @pdflite.PdfError::TrailerExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports malformed xref rows" {
  let bad_token : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 00000 q \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  guard bad_token is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }
  let short_row : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body("0\n", "<< /Root 1 0 R /Size 1 >>"),
  )
  guard short_row is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }
  let bad_fixed_digit : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000_65x35_f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  guard bad_fixed_digit is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }
  let bad_fixed_marker : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000_65535_q \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  guard bad_fixed_marker is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports malformed trailers" {
  let non_dictionary : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body("0 1\n0000000000 65535 f \n", "1"),
  )
  guard non_dictionary is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected @pdflite.PdfError::TrailerExpected")
  }
  let missing_root : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 65535 f \n", "<< /Size 1 >>",
    ),
  )
  guard missing_root is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected")
  }
  let bad_prev : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 /Prev -1 >>",
    ),
  )
  guard bad_prev is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected @pdflite.PdfError::TrailerExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes stops cyclic Prev chains" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_self_prev_xref(),
  )
  guard result is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected @pdflite.PdfError::XRefExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes recovers unreadable stream lengths" {
  let missing_xref = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_missing_indirect_stream_length(),
  )
  reader_assert_document_has_recovered_hello_stream(missing_xref)

  let non_integer = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_non_integer_stream_length(),
  )
  reader_assert_document_has_recovered_hello_stream(non_integer)

  let mismatched : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_mismatched_stream_length_xref(),
  )
  guard mismatched is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }

  let stream_length_object = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_stream_length_stream_object(),
  )
  reader_assert_document_has_recovered_hello_stream(stream_length_object)

  let negative_direct = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_negative_stream_length(),
  )
  reader_assert_document_has_recovered_hello_stream(negative_direct)
}

///|
test "pdf_read_classic_document_from_bytes reports xref object mismatches" {
  let mismatched_object : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_mismatched_object_xref(),
  )
  guard mismatched_object is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }
  let unparseable_object : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_unparseable_xref_object(),
  )
  guard unparseable_object
    is Err(@pdflite.PdfError::ParseIndirectObjectExpected) else {
    fail("expected @pdflite.PdfError::ParseIndirectObjectExpected")
  }
}

///|
test "pdf_read_document_from_bytes is the public classic reader entry point" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_classic_pdf_with_prev_xref(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(2))
}

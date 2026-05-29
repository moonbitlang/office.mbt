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

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
  guard missing_startxref is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected @pdflite.PdfError::StartXRefExpected")
  }

  let malformed_prev : Result[Int, Error] = try? @pdflite.pdf_revisions_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 /Prev /Bad >>",
    ),
  )
  guard malformed_prev is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected @pdflite.PdfError::TrailerExpected")
  }

  let cyclic_prev : Result[Int, Error] = try? @pdflite.pdf_revisions_from_bytes(
    reader_classic_pdf_with_self_prev_xref(),
  )
  guard cyclic_prev is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected @pdflite.PdfError::XRefExpected")
  }
}

///|
test "pdf_read_document_from_bytes reconstructs missing startxref PDFs" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_without_startxref(),
  )
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Size"))),
    Some(PdfInteger(3)),
  )
}

///|
test "pdf_read_document_from_view reconstructs borrowed malformed slices" {
  let payload = reader_malformed_pdf_without_startxref()
  let wrapped = reader_wrap_view_for_test("abc", payload, "xyz")
  let parsed = try! @pdflite.pdf_read_document_from_view(
    wrapped[3:wrapped.length() - 3],
  )
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
}

///|
test "pdf_read_document_from_bytes reconstructs page trees missing from xref" {
  let payload = reader_classic_pdf_with_page_tree_objects_missing_from_xref()
  let strict = try! @pdflite.pdf_read_classic_document_from_bytes(payload)
  @test.assert_eq(strict.root(), 1)
  @test.assert_eq(strict.object_numbers(), [1])
  let strict_pages : Result[Int, Error] = try? strict.endpage()
  guard strict_pages is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected @pdflite.PdfError::PageTreeExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(payload)
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3])
  @test.assert_eq(try! parsed.endpage(), 1)
}

///|
test "pdf_read_document_from_bytes reconstructs catalog missing from xref" {
  let payload = reader_classic_pdf_with_catalog_missing_from_xref()
  let strict = try! @pdflite.pdf_read_classic_document_from_bytes(payload)
  @test.assert_eq(strict.root(), 1)
  @test.assert_eq(strict.object_numbers(), [])
  let strict_catalog : Result[@pdflite.PdfObject, Error] = try? strict.catalog()
  guard strict_catalog is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(payload)
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3])
  @test.assert_eq(try! parsed.endpage(), 1)
}

///|
test "pdf_read_document_from_bytes reconstructs strings containing endobj text" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_endobj_text_in_catalog_string(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .lookup_object_or_null(1)
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Title"))),
    Some(PdfString(reader_pdf_ascii("literal endobj marker"))),
  )
}

///|
test "pdf_read_document_from_bytes reconstructs bad startxref PDFs" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs classic xref free entries with bad startxref" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_xref_deleted_payload_bad_startxref(),
  )
  guard strict is Err(_) else {
    fail("expected strict classic bad-startxref read to fail")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_classic_xref_deleted_payload_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfNull)
}

///|
test "pdf_read_document_from_bytes keeps later physical objects after classic free entries" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_classic_xref_deleted_payload_with_later_update_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(99))
}

///|
test "pdf_read_document_from_bytes reconstructs classic Prev chains with bad startxref" {
  let payload = reader_classic_catalog_pdf_with_prev_xref_bad_startxref()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    payload,
  )
  guard strict is Err(_) else {
    fail("expected strict classic Prev bad-startxref read to fail")
  }

  let parsed = @pdflite.pdf_read_document_from_bytes(payload)
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(
    parsed
    .lookup_object_or_null(1)
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Revision"))),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(3))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs malformed startxref numbers" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_malformed_startxref_number(),
  )
  guard strict is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected strict @pdflite.PdfError::NumberExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_malformed_startxref_number(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])

  let strict_overflow : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_overflow_startxref_number(),
  )
  guard strict_overflow is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected strict @pdflite.PdfError::NumberExpected")
  }
  let overflow = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_overflow_startxref_number(),
  )
  @test.assert_eq(overflow.first_xref(), 0)
  @test.assert_eq(overflow.root(), 1)
  @test.assert_eq(overflow.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs xref stream trailers" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_bad_startxref(),
  )
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Root"))),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Length"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref stream trailers without Type" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_without_type_with_bad_startxref(),
  )
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/W"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref stream object-stream roots" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_object_stream_root_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_object_stream_root_bad_startxref(),
  )
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
  guard parsed.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected retained object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
    ),
    Some(PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/ObjStm")))),
  )
}

///|
test "pdf_read_document_from_bytes does not reconstruct unsupported object-stream filters" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_bad_filtered_object_stream_root(),
  )
  let filter = match result {
    Err(@pdflite.PdfError::FilterNotSupported(filter)) => filter
    Err(@pdflite.PdfError::RootExpected) =>
      fail("unexpected @pdflite.PdfError::RootExpected")
    Err(@pdflite.PdfError::XRefExpected) =>
      fail("unexpected @pdflite.PdfError::XRefExpected")
    Err(@pdflite.PdfError::XRefEntryExpected) =>
      fail("unexpected @pdflite.PdfError::XRefEntryExpected")
    Ok(parsed) =>
      fail(
        "unexpected reconstructed document with " +
        parsed.object_numbers().length().to_string() +
        " objects",
      )
    Err(_) => fail("unexpected non-filter error")
  }
  @test.assert_eq(
    filter,
    @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/BadObjectStreamFilter")),
  )
}

///|
test "pdf_read_document_from_bytes does not reconstruct malformed object-stream decodeparms" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_bad_decodeparms_object_stream_root(),
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed object stream DecodeParms")
  }
}

///|
test "pdf_read_document_from_bytes does not reconstruct unsupported object-stream predictors" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_unsupported_predictor_object_stream_root(),
  )
  guard result is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported object stream predictor")
  }
  @test.assert_eq(predictor, 9)
}

///|
test "pdf_read_document_from_bytes reconstructs multi-revision xref stream object-stream roots" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_prev_update_with_object_stream_root_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_prev_update_with_object_stream_root_bad_startxref(),
  )
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
  @test.assert_eq(
    parsed
    .lookup_object_or_null(1)
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/New"))),
    Some(PdfBoolean(true)),
  )
  @test.assert_eq(
    parsed
    .lookup_object_or_null(1)
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Old"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes rejects truncated xref stream data" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_short_entry_data(),
  )
  guard result is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected @pdflite.PdfError::XRefEntryExpected")
  }
}

///|
test "pdf_read_document_from_bytes reconstructs out-of-range startxref PDFs" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_out_of_range_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::InvalidCursorPosition(999999)) else {
    fail("expected strict @pdflite.PdfError::InvalidCursorPosition")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_out_of_range_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs bad xref rows" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_bad_xref_entry(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected strict @pdflite.PdfError::XRefEntryExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_xref_entry(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs bad xref subsection metadata" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_bad_xref_subsection_count(),
  )
  guard strict is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected strict @pdflite.PdfError::NumberExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_xref_subsection_count(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs malformed trailers" {
  let strict_bad_trailer : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_bad_trailer_object(),
  )
  guard strict_bad_trailer is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected strict @pdflite.PdfError::TrailerExpected")
  }

  let bad_trailer = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_trailer_object(),
  )
  @test.assert_eq(bad_trailer.first_xref(), 0)
  @test.assert_eq(bad_trailer.root(), 1)
  @test.assert_eq(bad_trailer.object_numbers(), [1])

  let strict_missing_root : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_missing_root_trailer(),
  )
  guard strict_missing_root is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected strict @pdflite.PdfError::RootExpected")
  }

  let missing_root = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_missing_root_trailer(),
  )
  @test.assert_eq(missing_root.first_xref(), 0)
  @test.assert_eq(missing_root.root(), 1)
  @test.assert_eq(missing_root.object_numbers(), [1])

  let glued_trailers = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_glued_reconstruction_trailers(),
  )
  @test.assert_eq(glued_trailers.first_xref(), 0)
  @test.assert_eq(glued_trailers.root(), 1)
  @test.assert_eq(glued_trailers.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs bad object offsets" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_bad_object_offset(),
  )
  guard strict is Err(@pdflite.PdfError::ParseIndirectObjectExpected) else {
    fail("expected strict @pdflite.PdfError::ParseIndirectObjectExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_object_offset(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs indirect stream lengths" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_indirect_stream_length(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 3)
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3, 4])
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
  guard parsed.lookup_object_or_null(4) is PdfStreamObject(reconstructed) else {
    fail("expected reconstructed stream object")
  }
  @test.assert_eq(
    reconstructed.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
    ),
    Some(PdfInteger(7)),
  )
  @test.assert_eq(reconstructed.data, StreamGot(reader_pdf_ascii("Ignored")))
}

///|
test "pdf_read_document_from_bytes ignores object-looking stream data during reconstruction" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_object_header_inside_stream(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  guard parsed.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected recovered stream object")
  }
  try! reader_assert_deferred_stream_data_for_test(
    stream,
    reader_pdf_ascii("9 0 obj\n<< /Type /Catalog >>\nendobj"),
  )
}

///|
test "pdf_read_document_from_bytes skips nested object headers inside malformed objects" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_nested_object_header_in_bad_object(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 3)
  @test.assert_eq(parsed.object_numbers(), [3])
  @test.assert_eq(
    parsed.lookup_object_or_null(3),
    @pdflite.pdf_dictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
}

///|
fn reader_assert_document_has_recovered_hello_stream(
  document : @pdflite.PdfDocument,
) -> Unit raise Error {
  guard document.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected recovered stream")
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
test "pdf_read_document_from_bytes recovers unreadable stream lengths" {
  let strict = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_unreadable_stream_and_catalog(),
  )
  @test.assert_eq(strict.first_xref(), 118)
  @test.assert_eq(strict.root(), 2)
  @test.assert_eq(strict.object_numbers(), [1, 2])
  reader_assert_document_has_recovered_hello_stream(strict)

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_classic_pdf_with_unreadable_stream_and_catalog(),
  )
  @test.assert_eq(parsed.first_xref(), 118)
  @test.assert_eq(parsed.root(), 2)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(
    parsed.lookup_object_or_null(2),
    @pdflite.pdf_dictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Payload")), PdfIndirect(1)),
    ]),
  )
  reader_assert_document_has_recovered_hello_stream(parsed)

  let unparseable = try! @pdflite.pdf_read_document_from_bytes(
    reader_classic_pdf_with_unparseable_stream_length(),
  )
  @test.assert_eq(unparseable.first_xref(), 0)
  @test.assert_eq(unparseable.root(), 3)
  @test.assert_eq(unparseable.object_numbers(), [1, 3])
  reader_assert_document_has_recovered_hello_stream(unparseable)
}

///|
fn reader_assert_reconstructs_catalog(
  data : @pdflite.PdfBytes,
) -> Unit raise Error {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(data)
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 2)
  @test.assert_eq(parsed.object_numbers(), [2])
}

///|
test "pdf_read_document_from_bytes reconstructs around malformed stream markers" {
  let bad_stream = reader_classic_pdf_with_malformed_stream_and_catalog(
    "<< /Length 5 >>\nstram\nHello\nendstream",
  )
  let strict_stream : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bad_stream,
  )
  guard strict_stream is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected strict @pdflite.PdfError::ParseStreamExpected")
  }
  reader_assert_reconstructs_catalog(bad_stream)

  let bad_endstream = reader_classic_pdf_with_malformed_stream_and_catalog(
    "<< /Length 5 >>\nstream\nHello\nnot_a_stream_end",
  )
  let strict_endstream : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bad_endstream,
  )
  guard strict_endstream is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected strict @pdflite.PdfError::ParseEndStreamExpected")
  }
  reader_assert_reconstructs_catalog(bad_endstream)

  let bad_endobj = reader_classic_pdf_with_malformed_stream_and_catalog(
    "<< /Length 5 >>\nstream\nHello\nendstream\nnotendobj",
  )
  let strict_endobj : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bad_endobj,
  )
  guard strict_endobj is Err(@pdflite.PdfError::ParseEndObjectExpected) else {
    fail("expected strict @pdflite.PdfError::ParseEndObjectExpected")
  }
  reader_assert_reconstructs_catalog(bad_endobj)
}

///|
test "pdf_read_document_from_bytes reconstructs around truncated stream data" {
  let data = reader_classic_pdf_with_truncated_stream_before_catalog()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    data,
  )
  guard strict is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected strict @pdflite.PdfError::EndOfInput")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(data)
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs around malformed objects" {
  let bad_object = reader_classic_pdf_with_malformed_object_before_catalog("]")
  let strict_object : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bad_object,
  )
  guard strict_object is Err(@pdflite.PdfError::ParseObjectExpected) else {
    fail("expected strict @pdflite.PdfError::ParseObjectExpected")
  }
  let parsed_object = try! @pdflite.pdf_read_document_from_bytes(bad_object)
  @test.assert_eq(parsed_object.first_xref(), 0)
  @test.assert_eq(parsed_object.root(), 1)
  @test.assert_eq(parsed_object.object_numbers(), [1])

  let bad_name = reader_classic_pdf_with_malformed_object_before_catalog(
    "/Bad#zz",
  )
  let strict_name : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bad_name,
  )
  guard strict_name is Err(@pdflite.PdfError::InvalidHexEscape) else {
    fail("expected strict @pdflite.PdfError::InvalidHexEscape")
  }
  let parsed_name = try! @pdflite.pdf_read_document_from_bytes(bad_name)
  @test.assert_eq(parsed_name.first_xref(), 0)
  @test.assert_eq(parsed_name.root(), 1)
  @test.assert_eq(parsed_name.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reports missing reconstructed root" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\n1 0 obj\n1\nendobj\n"),
  )
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected")
  }
}

///|
test "pdf_read_document_from_bytes propagates unreconstructable errors" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\nstartxref\nabc\n%%EOF\n"),
  )
  guard result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected @pdflite.PdfError::NumberExpected")
  }
}

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

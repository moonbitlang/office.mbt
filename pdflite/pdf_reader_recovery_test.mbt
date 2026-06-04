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
        @core.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@core.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Size"))),
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
  let strict_pages : Result[Int, Error] = try strict.endpage() catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_pages is Err(@core.PdfError::PageTreeExpected) else {
    fail("expected @core.PdfError::PageTreeExpected")
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
  let strict_catalog : Result[@syntax.PdfObject, Error] = try
    strict.catalog()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_catalog is Err(@core.PdfError::RootExpected) else {
    fail("expected @core.PdfError::RootExpected")
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
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Title"))),
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
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_classic_xref_deleted_payload_bad_startxref(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
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
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(payload)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
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
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Revision"))),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(3))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs malformed startxref numbers" {
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_malformed_pdf_with_malformed_startxref_number(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::NumberExpected) else {
    fail("expected strict @core.PdfError::NumberExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_malformed_startxref_number(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])

  let strict_overflow : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_malformed_pdf_with_overflow_startxref_number(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_overflow is Err(@core.PdfError::NumberExpected) else {
    fail("expected strict @core.PdfError::NumberExpected")
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
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_xref_stream_pdf_with_bad_startxref(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::XRefExpected) else {
    fail("expected strict @core.PdfError::XRefExpected")
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
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Root"))),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Type"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Length"))),
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
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Type"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/W"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref stream object-stream roots" {
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_xref_stream_pdf_with_object_stream_root_bad_startxref(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::XRefExpected) else {
    fail("expected strict @core.PdfError::XRefExpected")
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
        @core.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@core.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
  guard parsed.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected retained object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      @core.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
    ),
    Some(PdfNameObject(@core.pdf_name_of_bytes(reader_pdf_ascii("/ObjStm")))),
  )
}

///|
test "pdf_read_document_from_bytes does not reconstruct unsupported object-stream filters" {
  let result : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_document_from_bytes(
      reader_xref_stream_pdf_with_bad_filtered_object_stream_root(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  let filter = match result {
    Err(@core.PdfError::FilterNotSupported(filter)) => filter
    Err(@core.PdfError::RootExpected) =>
      fail("unexpected @core.PdfError::RootExpected")
    Err(@core.PdfError::XRefExpected) =>
      fail("unexpected @core.PdfError::XRefExpected")
    Err(@core.PdfError::XRefEntryExpected) =>
      fail("unexpected @core.PdfError::XRefEntryExpected")
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
    @core.pdf_name_of_bytes(reader_pdf_ascii("/BadObjectStreamFilter")),
  )
}

///|
test "pdf_read_document_from_bytes does not reconstruct malformed object-stream decodeparms" {
  let result : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_document_from_bytes(
      reader_xref_stream_pdf_with_bad_decodeparms_object_stream_root(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::PredictorExpected) else {
    fail("expected malformed object stream DecodeParms")
  }
}

///|
test "pdf_read_document_from_bytes does not reconstruct unsupported object-stream predictors" {
  let result : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_document_from_bytes(
      reader_xref_stream_pdf_with_unsupported_predictor_object_stream_root(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported object stream predictor")
  }
  @test.assert_eq(predictor, 9)
}

///|
test "pdf_read_document_from_bytes reconstructs multi-revision xref stream object-stream roots" {
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_xref_stream_prev_update_with_object_stream_root_bad_startxref(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::XRefExpected) else {
    fail("expected strict @core.PdfError::XRefExpected")
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
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
  @test.assert_eq(
    parsed
    .lookup_object_or_null(1)
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/New"))),
    Some(PdfBoolean(true)),
  )
  @test.assert_eq(
    parsed
    .lookup_object_or_null(1)
    .lookup_immediate(@core.pdf_name_of_bytes(reader_pdf_ascii("/Old"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes rejects truncated xref stream data" {
  let result : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_document_from_bytes(
      reader_xref_stream_pdf_with_short_entry_data(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }
}

///|
test "pdf_read_document_from_bytes reconstructs out-of-range startxref PDFs" {
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_malformed_pdf_with_out_of_range_startxref(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::InvalidCursorPosition(999999)) else {
    fail("expected strict @core.PdfError::InvalidCursorPosition")
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
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_malformed_pdf_with_bad_xref_entry(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected strict @core.PdfError::XRefEntryExpected")
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
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_malformed_pdf_with_bad_xref_subsection_count(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::NumberExpected) else {
    fail("expected strict @core.PdfError::NumberExpected")
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
  let strict_bad_trailer : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_malformed_pdf_with_bad_trailer_object(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_bad_trailer is Err(@core.PdfError::TrailerExpected) else {
    fail("expected strict @core.PdfError::TrailerExpected")
  }

  let bad_trailer = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_trailer_object(),
  )
  @test.assert_eq(bad_trailer.first_xref(), 0)
  @test.assert_eq(bad_trailer.root(), 1)
  @test.assert_eq(bad_trailer.object_numbers(), [1])

  let strict_missing_root : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_malformed_pdf_with_missing_root_trailer(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_missing_root is Err(@core.PdfError::RootExpected) else {
    fail("expected strict @core.PdfError::RootExpected")
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
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(
      reader_malformed_pdf_with_bad_object_offset(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::ParseIndirectObjectExpected) else {
    fail("expected strict @core.PdfError::ParseIndirectObjectExpected")
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
      @core.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
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
      @core.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
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
    @syntax.pdf_dictionary([
      (
        @core.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@core.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
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
      @core.pdf_name_of_bytes(reader_pdf_ascii("/Length")),
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
    @syntax.pdf_dictionary([
      (
        @core.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@core.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
      (@core.pdf_name_of_bytes(reader_pdf_ascii("/Payload")), PdfIndirect(1)),
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
  data : @core.PdfBytes,
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
  let strict_stream : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(bad_stream)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_stream is Err(@core.PdfError::ParseStreamExpected) else {
    fail("expected strict @core.PdfError::ParseStreamExpected")
  }
  reader_assert_reconstructs_catalog(bad_stream)

  let bad_endstream = reader_classic_pdf_with_malformed_stream_and_catalog(
    "<< /Length 5 >>\nstream\nHello\nnot_a_stream_end",
  )
  let strict_endstream : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(bad_endstream)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_endstream is Err(@core.PdfError::ParseEndStreamExpected) else {
    fail("expected strict @core.PdfError::ParseEndStreamExpected")
  }
  reader_assert_reconstructs_catalog(bad_endstream)

  let bad_endobj = reader_classic_pdf_with_malformed_stream_and_catalog(
    "<< /Length 5 >>\nstream\nHello\nendstream\nnotendobj",
  )
  let strict_endobj : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(bad_endobj)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_endobj is Err(@core.PdfError::ParseEndObjectExpected) else {
    fail("expected strict @core.PdfError::ParseEndObjectExpected")
  }
  reader_assert_reconstructs_catalog(bad_endobj)
}

///|
test "pdf_read_document_from_bytes reconstructs around truncated stream data" {
  let data = reader_classic_pdf_with_truncated_stream_before_catalog()
  let strict : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(data)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict is Err(@core.PdfError::EndOfInput) else {
    fail("expected strict @core.PdfError::EndOfInput")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(data)
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs around malformed objects" {
  let bad_object = reader_classic_pdf_with_malformed_object_before_catalog("]")
  let strict_object : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(bad_object)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_object is Err(@core.PdfError::ParseObjectExpected) else {
    fail("expected strict @core.PdfError::ParseObjectExpected")
  }
  let parsed_object = try! @pdflite.pdf_read_document_from_bytes(bad_object)
  @test.assert_eq(parsed_object.first_xref(), 0)
  @test.assert_eq(parsed_object.root(), 1)
  @test.assert_eq(parsed_object.object_numbers(), [1])

  let bad_name = reader_classic_pdf_with_malformed_object_before_catalog(
    "/Bad#zz",
  )
  let strict_name : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_classic_document_from_bytes(bad_name)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard strict_name is Err(@core.PdfError::InvalidHexEscape) else {
    fail("expected strict @core.PdfError::InvalidHexEscape")
  }
  let parsed_name = try! @pdflite.pdf_read_document_from_bytes(bad_name)
  @test.assert_eq(parsed_name.first_xref(), 0)
  @test.assert_eq(parsed_name.root(), 1)
  @test.assert_eq(parsed_name.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reports missing reconstructed root" {
  let result : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_document_from_bytes(
      reader_pdf_ascii("%PDF-1.4\n1 0 obj\n1\nendobj\n"),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::RootExpected) else {
    fail("expected @core.PdfError::RootExpected")
  }
}

///|
test "pdf_read_document_from_bytes propagates unreconstructable errors" {
  let result : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_read_document_from_bytes(
      reader_pdf_ascii("%PDF-1.4\nstartxref\nabc\n%%EOF\n"),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }
}

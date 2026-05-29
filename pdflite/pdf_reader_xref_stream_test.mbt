///|
test "pdf_read_document_from_bytes reads default-index xref streams" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf(),
  )
  @test.assert_eq(parsed.version(), (1, 5))
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
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/W"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref streams with malformed stream markers" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_malformed_stream_marker(),
  )
  guard strict is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected strict @pdflite.PdfError::ParseStreamExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_malformed_stream_marker(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/W"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref streams with malformed endstream markers" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_malformed_endstream_marker(),
  )
  guard strict is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected strict @pdflite.PdfError::ParseEndStreamExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_malformed_endstream_marker(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/W"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref streams with malformed endobj markers" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_malformed_endobj_marker(),
  )
  guard strict is Err(@pdflite.PdfError::ParseEndObjectExpected) else {
    fail("expected strict @pdflite.PdfError::ParseEndObjectExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_malformed_endobj_marker(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/W"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes accepts xref streams without Type" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_without_type(),
  )
  @test.assert_eq(parsed.version(), (1, 5))
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
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reads xref stream Index ranges" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_index(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
}

///|
test "pdf_read_document_from_bytes reconstructs xref stream Index ranges" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_index_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_index_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Index"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reads xref streams with omitted type fields" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_default_in_use_width(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/W"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref streams with omitted type fields" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_default_in_use_width_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_default_in_use_width_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
}

///|
test "pdf_read_document_from_bytes skips unknown xref stream entry types" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_unknown_entry_type(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
}

///|
test "pdf_read_document_from_bytes reconstructs unknown xref stream entry types" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_unknown_entry_type_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_unknown_entry_type_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
}

///|
test "pdf_read_document_from_bytes keeps later physical objects after unknown xref entries" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_unknown_entry_with_later_physical_update_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(99))
}

///|
test "pdf_read_document_from_bytes decodes filtered xref streams" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_ascii_hex_filter(),
  )
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs filtered xref streams" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_ascii_hex_filter_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_ascii_hex_filter_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes decodes Flate xref streams" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_flate_filter(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs Flate xref streams" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_flate_filter_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_flate_filter_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes decodes Flate predictor xref streams" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_flate_predictor(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/DecodeParms")),
    ),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs Flate predictor xref streams" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_flate_predictor_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_flate_predictor_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/DecodeParms")),
    ),
    None,
  )
}

///|
test "pdf_read_document_from_bytes decodes short-name Flate predictor xref streams" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_short_flate_predictor(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/DP"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs short-name Flate predictor xref streams" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_short_flate_predictor_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_short_flate_predictor_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/DP"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes decodes xref stream filter arrays" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_filter_array(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref stream filter arrays" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_filter_array_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_filter_array_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes decodes xref stream filter arrays with predictor params" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_filter_array_predictor(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/DecodeParms")),
    ),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs xref stream filter arrays with predictor params" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_xref_stream_pdf_with_filter_array_predictor_bad_startxref(),
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected strict @pdflite.PdfError::XRefExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_filter_array_predictor_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/DecodeParms")),
    ),
    None,
  )
}

///|
test "pdf_read_document_from_bytes follows classic trailer XRefStm" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_hybrid_xref_stream_pdf(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/XRefStm"))),
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
test "pdf_read_document_from_bytes reconstructs hybrid XRefStm with bad startxref" {
  let payload = reader_hybrid_xref_stream_pdf_with_bad_startxref()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    payload,
  )
  guard strict is Err(_) else {
    fail("expected strict hybrid bad-startxref read to fail")
  }

  let parsed = @pdflite.pdf_read_document_from_bytes(payload)
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/XRefStm"))),
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
test "pdf_read_document_from_bytes follows compressed classic trailer XRefStm" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_hybrid_compressed_xref_stream_pdf(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/XRefStm"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/DecodeParms")),
    ),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reconstructs compressed hybrid XRefStm with bad startxref" {
  let payload = reader_hybrid_compressed_xref_stream_pdf_with_bad_startxref()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    payload,
  )
  guard strict is Err(_) else {
    fail("expected strict compressed hybrid bad-startxref read to fail")
  }

  let parsed = @pdflite.pdf_read_document_from_bytes(payload)
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/XRefStm"))),
    None,
  )
}

///|

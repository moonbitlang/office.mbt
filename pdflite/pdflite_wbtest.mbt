// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "pdf_duplicate_stream_equal rejects non-stream objects" {
  @test.assert_eq(
    pdf_duplicate_stream_equal(PdfInteger(1), PdfInteger(1)),
    false,
  )
  @test.assert_eq(
    pdf_duplicate_stream_equal(
      pdf_stream(PdfDictionary([]), StreamGot(@ascii.encode("a"))),
      PdfInteger(1),
    ),
    false,
  )
}

///|
test "PdfDocument copy preserves parser-private object states" {
  let doc = pdf_document_empty()
  doc.objects.set_entry(
    5,
    pdf_object_entry(ObjectParsedAlreadyDecrypted(PdfInteger(50)), generation=2),
  )
  doc.objects.object_stream_ids[8] = 5
  @test.assert_eq(doc.direct(PdfIndirect(5)), PdfInteger(50))
  let copied = doc.copy()
  @test.assert_eq(copied.lookup_object_or_null(5), PdfInteger(50))
  @test.assert_eq(
    copied.objects.get_entry(5),
    Some(
      pdf_object_entry(
        ObjectParsedAlreadyDecrypted(PdfInteger(50)),
        generation=2,
      ),
    ),
  )
  @test.assert_eq(copied.objects.object_stream_ids.get(8), Some(5))
  copied.objects.set_entry(5, pdf_object_entry(ObjectParsed(PdfInteger(7))))
  copied.objects.object_stream_ids[8] = 9
  @test.assert_eq(doc.lookup_object_or_null(5), PdfInteger(50))
  @test.assert_eq(doc.objects.object_stream_ids.get(8), Some(5))
}

///|
test "PdfDocument ARC4 crypt preserves parser-private object states" {
  let key = try! pdf_bytes_of_int_array([1, 2, 3, 4, 5])
  let doc = pdf_document_empty()
  doc.objects.set_entry(
    1,
    pdf_object_entry(
      ObjectParsedAlreadyDecrypted(PdfString(@ascii.encode("plain"))),
    ),
  )
  doc.objects.set_entry(2, pdf_object_entry(ObjectToParse))
  doc.objects.set_entry(
    3,
    pdf_object_entry(
      ObjectToParseFromObjectStream({ object_stream_number: 7, index: 0 }),
    ),
  )
  let encrypted = try! doc.arc4_crypt_parsed_objects(key[:], 40)
  @test.assert_eq(encrypted.objects.get_entry(1), doc.objects.get_entry(1))
  @test.assert_eq(encrypted.objects.get_entry(2), doc.objects.get_entry(2))
  @test.assert_eq(encrypted.objects.get_entry(3), doc.objects.get_entry(3))
}

///|
test "writer parses signed integer fragments for scientific reals" {
  @test.assert_eq(
    try! pdf_writer_parse_signed_int(@ascii.encode("+12")[:], 0),
    12,
  )
  @test.assert_eq(
    try! pdf_writer_parse_signed_int(@ascii.encode("-12")[:], 0),
    -12,
  )
  @test.assert_eq(
    try! pdf_writer_parse_signed_int(@ascii.encode("12")[:], 0),
    12,
  )
  let missing : Result[Int, Error] = try? pdf_writer_parse_signed_int(
    @ascii.encode("+")[:],
    0,
  )
  guard missing is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
  let malformed : Result[Int, Error] = try? pdf_writer_parse_signed_int(
    @ascii.encode("12a")[:],
    0,
  )
  guard malformed is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "writer expands scientific real edge forms" {
  @test.assert_eq(pdf_writer_exponent_marker(@ascii.encode("1E2")[:]), 1)

  let plus_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    plus_output,
    @ascii.encode("+1.25e2")[:],
    5,
  )
  @test.assert_eq(Bytes::from_array(plus_output), @ascii.encode("125"))

  let negative_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    negative_output,
    @ascii.encode("-1.25e2")[:],
    5,
  )
  @test.assert_eq(Bytes::from_array(negative_output), @ascii.encode("-125"))

  let padded_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    padded_output,
    @ascii.encode("1.2e3")[:],
    3,
  )
  @test.assert_eq(Bytes::from_array(padded_output), @ascii.encode("1200"))

  let middle_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    middle_output,
    @ascii.encode("1.25e1")[:],
    4,
  )
  @test.assert_eq(Bytes::from_array(middle_output), @ascii.encode("12.5"))

  let negative_exponent_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    negative_exponent_output,
    @ascii.encode("1.25e-3")[:],
    4,
  )
  @test.assert_eq(
    Bytes::from_array(negative_exponent_output),
    @ascii.encode("0.00125"),
  )

  let rounded_exponent_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    rounded_exponent_output,
    @ascii.encode("1.23456789012345e21")[:],
    16,
  )
  @test.assert_eq(
    Bytes::from_array(rounded_exponent_output),
    @ascii.encode("1234567890120000000000"),
  )

  let carry_exponent_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    carry_exponent_output,
    @ascii.encode("9.999999999999e21")[:],
    14,
  )
  @test.assert_eq(
    Bytes::from_array(carry_exponent_output),
    @ascii.encode("10000000000000000000000"),
  )

  let rounded_no_carry_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    rounded_no_carry_output,
    @ascii.encode("1.234567890125e21")[:],
    14,
  )
  @test.assert_eq(
    Bytes::from_array(rounded_no_carry_output),
    @ascii.encode("1234567890130000000000"),
  )

  let trimmed_fraction_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    trimmed_fraction_output,
    @ascii.encode("1.230000000001e-1")[:],
    14,
  )
  @test.assert_eq(
    Bytes::from_array(trimmed_fraction_output),
    @ascii.encode("0.123"),
  )

  let zero_digits_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    zero_digits_output,
    @ascii.encode("0.000e10")[:],
    5,
  )
  @test.assert_eq(Bytes::from_array(zero_digits_output), @ascii.encode("0"))

  let zero_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(zero_output, @ascii.encode(".e1")[:], 1)
  @test.assert_eq(Bytes::from_array(zero_output), @ascii.encode("0"))

  let malformed_output : Array[Byte] = []
  let malformed : Result[Unit, Error] = try? pdf_writer_push_scientific_real(
    malformed_output,
    @ascii.encode("1Ae1")[:],
    2,
  )
  guard malformed is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "writer rounds plain significant real helper edge forms" {
  let plus_output : Array[Byte] = []
  try! pdf_writer_push_plain_significant_real(
    plus_output,
    @ascii.encode("+1.23456789012345")[:],
  )
  @test.assert_eq(
    Bytes::from_array(plus_output),
    @ascii.encode("1.23456789012"),
  )

  let negative_output : Array[Byte] = []
  try! pdf_writer_push_plain_significant_real(
    negative_output,
    @ascii.encode("-1.23456789012345")[:],
  )
  @test.assert_eq(
    Bytes::from_array(negative_output),
    @ascii.encode("-1.23456789012"),
  )

  let leading_decimal_output : Array[Byte] = []
  try! pdf_writer_push_plain_significant_real(
    leading_decimal_output,
    @ascii.encode(".000123456789012345")[:],
  )
  @test.assert_eq(
    Bytes::from_array(leading_decimal_output),
    @ascii.encode("0.000123456789012"),
  )

  let zero_output : Array[Byte] = []
  try! pdf_writer_push_plain_significant_real(
    zero_output,
    @ascii.encode("0.0")[:],
  )
  @test.assert_eq(Bytes::from_array(zero_output), @ascii.encode("0"))

  let double_dot : Result[Unit, Error] = try? pdf_writer_push_plain_significant_real(
    [],
    @ascii.encode("1.2.3")[:],
  )
  guard double_dot is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }

  let bad_digit : Result[Unit, Error] = try? pdf_writer_push_plain_significant_real(
    [],
    @ascii.encode("1a")[:],
  )
  guard bad_digit is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "private xref stream helpers cover malformed and deferred entries" {
  let key_w = pdf_reader_name("/W")
  let key_index = pdf_reader_name("/Index")
  let negative_xrefstm : Result[Int?, Error] = try? pdf_trailer_xref_stream_position(
    PdfDictionary([(pdf_reader_xrefstm_name(), PdfInteger(-1))]),
  )
  guard negative_xrefstm is Err(PdfError::XRefExpected) else {
    fail("expected XRefExpected")
  }

  let malformed_array_value : Result[Array[Int]?, Error] = try? pdf_xref_stream_int_array(
    PdfDictionary([(key_w, PdfArray([PdfNameObject(pdf_reader_name("/Name"))]))]),
    key_w,
  )
  guard malformed_array_value is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let malformed_non_array : Result[Array[Int]?, Error] = try? pdf_xref_stream_int_array(
    PdfDictionary([(key_w, PdfInteger(1))]),
    key_w,
  )
  guard malformed_non_array is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let malformed_widths : Result[(Int, Int, Int), Error] = try? pdf_xref_stream_widths(
    PdfDictionary([(key_w, PdfArray([PdfInteger(1), PdfInteger(2)]))]),
  )
  guard malformed_widths is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let odd_index : Result[Array[(Int, Int)], Error] = try? pdf_xref_stream_index_pairs(
    PdfDictionary([(key_index, PdfArray([PdfInteger(0)]))]),
  )
  guard odd_index is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let negative_index : Result[Array[(Int, Int)], Error] = try? pdf_xref_stream_index_pairs(
    PdfDictionary([(key_index, PdfArray([PdfInteger(0), PdfInteger(-1)]))]),
  )
  guard negative_index is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let missing_size : Result[Array[(Int, Int)], Error] = try? pdf_xref_stream_index_pairs(
    PdfDictionary([]),
  )
  guard missing_size is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  @test.assert_eq(
    try! pdf_xref_stream_read_field(@ascii.encode("ab")[:], 0, 0),
    (0, 0),
  )
  let short_field : Result[(Int, Int), Error] = try? pdf_xref_stream_read_field(
    @ascii.encode("a")[:],
    0,
    2,
  )
  guard short_field is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let default_kind_entries = try! pdf_xref_stream_entries(
    Bytes::from_array([9, 0, 8, 1])[:],
    (0, 1, 1),
    [(5, 2)][:],
  )
  @test.assert_eq(default_kind_entries.length(), 2)
  @test.assert_eq(default_kind_entries[0].object_number, 5)
  @test.assert_eq(default_kind_entries[0].offset, 9)
  @test.assert_eq(default_kind_entries[0].generation, 0)
  @test.assert_eq(default_kind_entries[0].in_use, true)

  let deferred_entries = try! pdf_xref_stream_entries(
    Bytes::from_array([2, 7, 0, 9, 0, 0])[:],
    (1, 1, 1),
    [(3, 2)][:],
  )
  @test.assert_eq(deferred_entries.length(), 1)
  @test.assert_eq(deferred_entries[0].object_number, 3)
  @test.assert_eq(deferred_entries[0].offset, 7)
  @test.assert_eq(deferred_entries[0].generation, 0)
  @test.assert_eq(deferred_entries[0].in_use, true)
  @test.assert_eq(
    deferred_entries[0].object_stream,
    Some({ object_stream_number: 7, index: 0 }),
  )
}

///|
test "private object stream helpers cover malformed object streams" {
  let key_type = pdf_reader_name("/Type")
  let key_n = pdf_reader_name("/N")
  let key_first = pdf_reader_name("/First")
  let key_length = pdf_reader_name("/Length")

  let missing_required : Result[Int, Error] = try? pdf_object_stream_required_int(
    PdfDictionary([]),
    key_n,
  )
  guard missing_required is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let bad_first : Result[Array[(Int, Int)], Error] = try? pdf_object_stream_number_offsets(
    @ascii.encode("1 0")[:],
    4,
    1,
  )
  guard bad_first is Err(PdfError::StreamDataExpected) else {
    fail("expected StreamDataExpected")
  }

  let short_header : Result[Array[(Int, Int)], Error] = try? pdf_object_stream_number_offsets(
    @ascii.encode("2 ")[:],
    2,
    1,
  )
  guard short_header is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let malformed_pair : Result[Array[(Int, Int)], Error] = try? pdf_object_stream_number_offsets(
    @ascii.encode("/Name 0 ")[:],
    8,
    1,
  )
  guard malformed_pair is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let bad_index : Result[Int, Error] = try? pdf_object_stream_next_offset(
    [][:],
    0,
    0,
    0,
  )
  guard bad_index is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  @test.assert_eq(
    try! pdf_object_stream_next_offset([(2, 0), (3, 4)][:], 0, 12, 8),
    4,
  )

  let doc = pdf_document_empty()
  let valid_stream = pdf_stream(
    PdfDictionary([
      (key_type, PdfNameObject(pdf_reader_name("/ObjStm"))),
      (key_n, PdfInteger(2)),
      (key_first, PdfInteger(8)),
      (key_length, PdfInteger(17)),
    ]),
    StreamGot(@ascii.encode("2 0 3 4 truefalse")),
  )
  doc.add_object_given_number(7, valid_stream)
  @test.assert_eq(
    try! doc.read_object_stream_reference({ object_stream_number: 7, index: 0 }),
    (2, PdfBoolean(true)),
  )

  let no_type_doc = pdf_document_empty()
  no_type_doc.add_object_given_number(
    10,
    pdf_stream(
      PdfDictionary([
        (key_n, PdfInteger(1)),
        (key_first, PdfInteger(4)),
        (key_length, PdfInteger(8)),
      ]),
      StreamGot(@ascii.encode("2 0 true")),
    ),
  )
  @test.assert_eq(
    try! no_type_doc.read_object_stream_reference({
      object_stream_number: 10,
      index: 0,
    }),
    (2, PdfBoolean(true)),
  )

  let wrong_type_doc = pdf_document_empty()
  wrong_type_doc.add_object_given_number(
    8,
    pdf_stream(
      PdfDictionary([
        (key_type, PdfNameObject(pdf_reader_name("/Page"))),
        (key_n, PdfInteger(1)),
        (key_first, PdfInteger(4)),
        (key_length, PdfInteger(8)),
      ]),
      StreamGot(@ascii.encode("2 0 true")),
    ),
  )
  let wrong_type : Result[(Int, PdfObject), Error] = try? wrong_type_doc.read_object_stream_reference({
      object_stream_number: 8,
      index: 0,
    },
  )
  guard wrong_type is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let missing_stream : Result[(Int, PdfObject), Error] = try? doc.read_object_stream_reference({
      object_stream_number: 99,
      index: 0,
    },
  )
  guard missing_stream is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let bad_offset_doc = pdf_document_empty()
  bad_offset_doc.add_object_given_number(
    9,
    pdf_stream(
      PdfDictionary([
        (key_type, PdfNameObject(pdf_reader_name("/ObjStm"))),
        (key_n, PdfInteger(1)),
        (key_first, PdfInteger(5)),
        (key_length, PdfInteger(9)),
      ]),
      StreamGot(@ascii.encode("2 99 true")),
    ),
  )
  let bad_offset : Result[(Int, PdfObject), Error] = try? bad_offset_doc.read_object_stream_reference({
      object_stream_number: 9,
      index: 0,
    },
  )
  guard bad_offset is Err(PdfError::StreamDataExpected) else {
    fail("expected StreamDataExpected")
  }
}

///|
test "private stream data materialization reports invalid deferred slices" {
  let cursor = byte_cursor_of_bytes(@ascii.encode("abc"))
  let bad_position : Result[BytesView, Error] = try? pdf_stream_data_view(
    StreamToGet(stream_to_get(cursor, -1, 1)),
  )
  guard bad_position is Err(PdfError::InvalidCursorPosition(-1)) else {
    fail("expected InvalidCursorPosition")
  }

  let bad_length : Result[BytesView, Error] = try? pdf_stream_data_view(
    StreamToGet(stream_to_get(cursor, 0, -1)),
  )
  guard bad_length is Err(PdfError::InvalidReadLength(-1)) else {
    fail("expected InvalidReadLength")
  }

  let too_long : Result[BytesView, Error] = try? pdf_stream_data_view(
    StreamToGet(stream_to_get(cursor, 2, 2)),
  )
  guard too_long is Err(PdfError::EndOfInput) else {
    fail("expected EndOfInput")
  }
}

///|
test "pdf_write_document rejects deferred object states" {
  let doc = pdf_document_empty()
  doc.objects.set_entry(1, pdf_object_entry(ObjectToParse))
  let result : Result[PdfBytes, Error] = try? pdf_write_document(doc)
  guard result is Err(PdfError::ParsedObjectExpected) else {
    fail("expected ParsedObjectExpected")
  }
}

///|
test "private writer stream dictionary uses materialized deferred length" {
  let cursor = byte_cursor_of_bytes(@ascii.encode("abc"))
  let stream = pdf_stream(
    PdfDictionary([]),
    StreamToGet(stream_to_get(cursor, 0, 1)),
  )
  guard stream is PdfStreamObject(stream_value) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    pdf_write_stream_dictionary(
      stream_value,
      pdf_stream_data_view(stream_value.data).length(),
    ),
    PdfDictionary([(pdf_name_of_bytes(@ascii.encode("/Length")), PdfInteger(1))]),
  )
}

///|
test "parser prefix helper reports malformed indirect prefixes" {
  let too_short : Result[PdfParsedIndirectObject, Error] = try? pdf_parse_indirect_object_prefix_lexemes([
      LexInt(1),
      LexInt(0),
    ],
  )
  guard too_short is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }
  let bad_header : Result[PdfParsedIndirectObject, Error] = try? pdf_parse_indirect_object_prefix_lexemes([
      LexInt(1),
      LexInt(0),
      LexNull,
    ],
  )
  guard bad_header is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }
}

///|
test "private reader byte-view helpers cover boundary cases" {
  let cursor = byte_cursor_of_bytes(@ascii.encode("abc"))
  let bad_seek : Result[Unit, Error] = try? cursor.seek_pdf_absolute(-1)
  guard bad_seek is Err(PdfError::InvalidCursorPosition(-1)) else {
    fail("expected InvalidCursorPosition")
  }

  let view = @ascii.encode("abc")[:]
  @test.assert_eq(pdf_view_matches_ascii_at(view, -1, [97]), false)
  @test.assert_eq(pdf_view_matches_ascii_at(view, 2, [98, 99]), false)
  @test.assert_eq(pdf_find_last_ascii(view, []), 3)
  @test.assert_eq(pdf_find_last_ascii(view[:1], [97, 98]), -1)
  @test.assert_eq(pdf_find_last_ascii(view, [120]), -1)

  let empty_number : Result[Int, Error] = try? pdf_parse_ascii_int_view(
    Bytes::new(0)[:],
  )
  guard empty_number is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
  let bad_number : Result[Int, Error] = try? pdf_parse_ascii_int_view(
    @ascii.encode("12a")[:],
  )
  guard bad_number is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "private reader xref helpers report malformed inputs" {
  let empty_token : Result[Bool, Error] = try? pdf_xref_token_in_use(
    Bytes::new(0)[:],
  )
  guard empty_token is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
  let bad_token : Result[Bool, Error] = try? pdf_xref_token_in_use(
    @ascii.encode("q")[:],
  )
  guard bad_token is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let empty_xrefs : Array[PdfClassicXRefEntry] = []
  @test.assert_eq(pdf_classic_xref_lookup(empty_xrefs[:], 1), None)

  let no_object = byte_cursor_of_bytes(@ascii.encode("notobject"))
  let no_object_result : Result[PdfParsedIndirectObject, Error] = try? no_object.read_first_indirect_object_at_current(
    empty_xrefs[:],
  )
  guard no_object_result is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }

  let no_plain_object = byte_cursor_of_bytes(@ascii.encode("notobject"))
  let no_plain_object_result : Result[PdfParsedIndirectObject, Error] = try? no_plain_object.read_plain_indirect_object_at_current()
  guard no_plain_object_result is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }

  let empty_prefix = byte_cursor_of_bytes(Bytes::new(0))
  let empty_prefix_result : Result[PdfParsedIndirectObject, Error] = try? empty_prefix.read_reconstructed_indirect_prefix_at_current()
  guard empty_prefix_result is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }

  let mismatch = byte_cursor_of_bytes(@ascii.encode("abc"))
  let mismatch_result : Result[Unit, Error] = try? mismatch.consume_pdf_ascii(
    [120],
    XRefExpected,
  )
  guard mismatch_result is Err(PdfError::XRefExpected) else {
    fail("expected XRefExpected")
  }
}

///|
test "page-label private helpers preserve non-uppercase bytes and root guards" {
  @test.assert_eq(
    pdf_page_label_lowercase(@ascii.encode("A1Z!")),
    @ascii.encode("a1z!"),
  )
  let doc = pdf_document_empty()
  let result : Result[Bool, Error] = try? doc.pdf_page_label_has_labels()
  guard result is Err(PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
}

///|
test "private date two-digit parser rejects short input" {
  let result : Result[Int, Error] = try? pdf_date_two_digits(
    @ascii.encode("1"),
    0,
  )
  guard result is Err(PdfError::BadDate) else { fail("expected BadDate") }
}

///|
test "private annotation and bookmark guards report malformed roots" {
  let annotation_rest : Result[PdfObject, Error] = try? pdf_annotation_rest(
    PdfInteger(1),
  )
  guard annotation_rest is Err(PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected")
  }
  let doc = pdf_document_empty()
  let outlines : Result[Bool, Error] = try? doc.pdf_bookmark_has_outlines()
  guard outlines is Err(PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
  let output : Array[PdfBookmark] = []
  let recursion : Result[Unit, Error] = try? doc.pdf_bookmark_traverse_siblings(
    0,
    PdfNull,
    false,
    output,
    10001,
  )
  guard recursion is Err(PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected")
  }
}

///|
test "private structure survival helpers cover direct cases" {
  let key_pg = pdf_structure_pg_key()
  let doc = pdf_document_empty()
  doc.add_object_given_number(
    50,
    PdfDictionary([
      (key_pg, PdfIndirect(2)),
      (pdf_structure_k_key(), PdfInteger(0)),
    ]),
  )
  @test.assert_eq(doc.pdf_structure_indirect_survives(50, [2]), false)
  @test.assert_eq(doc.pdf_structure_k_item_survives(PdfInteger(1), [2]), true)
  @test.assert_eq(doc.pdf_structure_filtered_k_value(PdfInteger(1), [2]), None)
}

///|
fn wbtest_content_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn wbtest_assert_known_content_none(
  operator : String,
  operands : ArrayView[PdfObject],
) -> Unit raise Error {
  @test.assert_eq(
    pdf_content_parse_known_section(operands, @ascii.encode(operator)),
    None,
  )
}

///|
test "private content helpers cover malformed operand fallbacks" {
  let name = wbtest_content_name("/N")
  @test.assert_eq(
    pdf_content_op_section(Op_InlineImage(PdfNull, None, [])),
    ([], Bytes::new(0)),
  )
  @test.assert_eq(
    pdf_content_op_section(Op_Unknown(@ascii.encode("ZZ"))),
    ([], @ascii.encode("ZZ")),
  )

  @test.assert_eq(
    pdf_content_read_complex_object(
      byte_cursor_of_bytes(Bytes::new(0)),
      LexInt(7),
    ),
    PdfInteger(7),
  )
  let empty_object : Result[PdfObject, Error] = try? pdf_content_read_object(
    byte_cursor_of_bytes(Bytes::new(0)),
  )
  guard empty_object is Err(PdfError::ParseObjectExpected) else {
    fail("expected ParseObjectExpected")
  }
  @test.assert_eq(
    try! pdf_content_read_inline_image_data(
      byte_cursor_of_bytes(@ascii.encode("EI ")),
    ),
    Bytes::new(0),
  )
  @test.assert_eq(
    pdf_content_inline_image_data_length(
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(1)),
        (
          wbtest_content_name("/CS"),
          PdfNameObject(wbtest_content_name("/CMYK")),
        ),
        (wbtest_content_name("/BPC"), PdfInteger(8)),
      ]),
    ),
    Some(4),
  )
  @test.assert_eq(
    pdf_content_inline_image_data_length(
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(1)),
        (wbtest_content_name("/CS"), PdfNameObject(wbtest_content_name("/G"))),
        (wbtest_content_name("/BPC"), PdfInteger(1)),
      ]),
    ),
    Some(1),
  )
  @test.assert_eq(
    pdf_content_inline_image_data_length(
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(1)),
        (wbtest_content_name("/CS"), PdfNameObject(wbtest_content_name("/G"))),
        (wbtest_content_name("/BPC"), PdfInteger(8)),
        (
          wbtest_content_name("/Filter"),
          PdfNameObject(wbtest_content_name("/ASCIIHexDecode")),
        ),
      ]),
    ),
    None,
  )
  @test.assert_eq(
    try! pdf_content_read_sized_inline_image_data(
      byte_cursor_of_bytes(@ascii.encode("AB EI")),
      2,
    ),
    @ascii.encode("AB"),
  )
  let short_sized_inline : Result[PdfBytes, Error] = try? pdf_content_read_sized_inline_image_data(
    byte_cursor_of_bytes(@ascii.encode("A")),
    2,
  )
  guard short_sized_inline is Err(PdfError::ParseEndStreamExpected) else {
    fail("expected ParseEndStreamExpected")
  }
  let bad_sized_length : Result[PdfBytes, Error] = try? pdf_content_read_sized_inline_image_data(
    byte_cursor_of_bytes(@ascii.encode(" EI")),
    -1,
  )
  guard bad_sized_length is Err(PdfError::InvalidReadLength(-1)) else {
    fail("expected InvalidReadLength")
  }
  let jpeg_data = try! pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9])
  @test.assert_eq(
    try! pdf_content_read_dct_inline_image_data(
      byte_cursor_of_bytes(
        try! pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9, 32, 69, 73]),
      ),
    ),
    jpeg_data,
  )
  @test.assert_eq(pdf_content_filter_is_inline_dct(PdfInteger(1)), false)
  let bad_dct_end : Result[PdfBytes, Error] = try? pdf_content_read_dct_inline_image_data(
    byte_cursor_of_bytes(
      try! pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9, 32, 88, 88]),
    ),
  )
  guard bad_dct_end is Err(PdfError::ParseEndStreamExpected) else {
    fail("expected ParseEndStreamExpected")
  }
  let bad_inline : Result[PdfContentOp, Error] = try? pdf_content_read_inline_image(
    byte_cursor_of_bytes(@ascii.encode("1 ID data EI")),
  )
  guard bad_inline is Err(PdfError::ContentOperandExpected) else {
    fail("expected ContentOperandExpected")
  }

  @test.assert_eq(pdf_content_operand_number([], 0), None)
  @test.assert_eq(pdf_content_operand_int([], 0), None)
  @test.assert_eq(pdf_content_operand_int([PdfReal(1.9)], 0), Some(1))
  @test.assert_eq(pdf_content_operand_name([], 0), None)
  @test.assert_eq(pdf_content_operand_string([], 0), None)
  @test.assert_eq(
    pdf_content_numbers_from_array(PdfArray([PdfReal(1.5), PdfInteger(2)])),
    Some([1.5, 2.0]),
  )
  @test.assert_eq(
    pdf_content_numbers_from_array(PdfArray([PdfNameObject(name)])),
    None,
  )
  @test.assert_eq(pdf_content_numbers_from_array(PdfNull), None)
  @test.assert_eq(
    pdf_content_numbers_from_operands([PdfNameObject(name)]),
    None,
  )
  @test.assert_eq(pdf_content_named_color_operands([]), None)
  @test.assert_eq(
    pdf_content_named_color_operands([PdfInteger(1), PdfNameObject(name)]),
    Some((name, [1.0])),
  )
  @test.assert_eq(pdf_content_matrix_from_operands([PdfInteger(1)]), None)

  let bad_number = [PdfNameObject(name)]
  let bad_name = [PdfInteger(1)]
  wbtest_assert_known_content_none("j", bad_number)
  wbtest_assert_known_content_none("M", bad_number)
  wbtest_assert_known_content_none("d", [PdfNameObject(name), PdfInteger(0)])
  wbtest_assert_known_content_none("i", bad_number)
  wbtest_assert_known_content_none("cm", [
    PdfInteger(1),
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(1),
    PdfInteger(0),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("Tm", [
    PdfInteger(1),
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(1),
    PdfInteger(0),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("m", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("l", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("c", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
    PdfInteger(5),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("v", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("y", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("re", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("Tc", bad_number)
  wbtest_assert_known_content_none("Tw", bad_number)
  wbtest_assert_known_content_none("Tz", bad_number)
  wbtest_assert_known_content_none("TL", bad_number)
  wbtest_assert_known_content_none("Tf", [PdfInteger(1), PdfInteger(12)])
  wbtest_assert_known_content_none("Tr", bad_number)
  wbtest_assert_known_content_none("Ts", bad_number)
  wbtest_assert_known_content_none("Td", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("TD", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("'", bad_name)
  wbtest_assert_known_content_none("\"", [
    PdfInteger(1),
    PdfInteger(2),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("d0", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("d1", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
    PdfInteger(5),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("G", bad_number)
  wbtest_assert_known_content_none("g", bad_number)
  wbtest_assert_known_content_none("RG", [
    PdfInteger(1),
    PdfInteger(2),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("rg", [
    PdfInteger(1),
    PdfInteger(2),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("K", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("k", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("gs", bad_name)
  wbtest_assert_known_content_none("CS", bad_name)
  wbtest_assert_known_content_none("cs", bad_name)
  wbtest_assert_known_content_none("SC", [PdfNameObject(name)])
  wbtest_assert_known_content_none("sc", [PdfNameObject(name)])
  wbtest_assert_known_content_none("SCN", [
    PdfNameObject(name),
    PdfNameObject(wbtest_content_name("/Pattern")),
  ])
  wbtest_assert_known_content_none("scn", [
    PdfNameObject(name),
    PdfNameObject(wbtest_content_name("/Pattern")),
  ])
  wbtest_assert_known_content_none("sh", bad_name)
  wbtest_assert_known_content_none("MP", bad_name)
  wbtest_assert_known_content_none("DP", [PdfInteger(1), PdfDictionary([])])
  wbtest_assert_known_content_none("BMC", bad_name)
  wbtest_assert_known_content_none("BDC", [PdfInteger(1), PdfDictionary([])])
}

///|
test "private codec dictionary and predictor guards report malformed inputs" {
  let empty = PdfDictionary([])
  @test.assert_eq(pdf_remove_first_filter_entry(empty, pdf_filter_key()), empty)
  let bad_filter = PdfDictionary([(pdf_filter_key(), PdfInteger(1))])
  let bad_filter_result : Result[PdfObject, Error] = try? pdf_remove_first_filter_entry(
    bad_filter,
    pdf_filter_key(),
  )
  guard bad_filter_result is Err(PdfError::FilterExpected) else {
    fail("expected FilterExpected")
  }
  let bad_decodeparms = PdfDictionary([(pdf_decodeparms_key(), PdfInteger(1))])
  let bad_decodeparms_result : Result[PdfObject, Error] = try? pdf_remove_first_decodeparms_entry(
    bad_decodeparms,
    pdf_decodeparms_key(),
  )
  guard bad_decodeparms_result is Err(PdfError::FilterExpected) else {
    fail("expected FilterExpected")
  }
  let bad_bpp : Result[Int, Error] = try? pdf_predictor_bytes_per_pixel(0, 8)
  guard bad_bpp is Err(PdfError::PredictorExpected) else {
    fail("expected PredictorExpected")
  }
}

///|
test "private LZW code expansion rejects malformed tables" {
  let bad_next_code : Result[Int?, Error] = try? pdf_lzw_next_code(
    bitstream_of_bytes(Bytes::new(0)),
    32,
  )
  guard bad_next_code is Err(PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }

  let short_prefix = Array::make(4, 0)
  let short_append = Array::make(4, 0)
  let out_of_range : Result[Array[Int], Error] = try? pdf_lzw_decode_code(
    4, short_prefix, short_append, 4,
  )
  guard out_of_range is Err(PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }

  let looping_prefix = Array::make(300, 0)
  let looping_append = Array::make(300, 0)
  looping_prefix[256] = 300
  let bad_chain : Result[Array[Int], Error] = try? pdf_lzw_decode_code(
    256, looping_prefix, looping_append, 300,
  )
  guard bad_chain is Err(PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }

  let negative_prefix = Array::make(300, 0)
  let negative_append = Array::make(300, 0)
  negative_prefix[256] = -1
  let bad_terminal : Result[Array[Int], Error] = try? pdf_lzw_decode_code(
    256, negative_prefix, negative_append, 300,
  )
  guard bad_terminal is Err(PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }
}

///|
test "private tree group count covers threshold branches" {
  @test.assert_eq(pdf_tree_group_count(10), 1)
  @test.assert_eq(pdf_tree_group_count(11), 2)
  @test.assert_eq(pdf_tree_group_count(101), 10)
}

///|
fn wbtest_flate_bits(bits : ArrayView[Int]) -> Bytes {
  let output : Array[Byte] = []
  let mut current = 0
  let mut count = 0
  for bit in bits {
    if bit != 0 {
      current = current | (1 << count)
    }
    count += 1
    if count == 8 {
      output.push(current.to_byte())
      current = 0
      count = 0
    }
  }
  if count > 0 {
    output.push(current.to_byte())
  }
  Bytes::from_array(output)
}

///|
test "private flate bit reader and huffman guards reject malformed inputs" {
  let reader = FlateBitReader::new(Bytes::new(0)[:])
  let negative_bits : Result[UInt, Error] = try? reader.read_bits(-1)
  guard negative_bits is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let exhausted = FlateBitReader::new(Bytes::new(0)[:])
  let missing_byte : Result[UInt, Error] = try? exhausted.read_bits(1)
  guard missing_byte is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let bad_length : Result[FlateHuffmanTable, Error] = try? pdf_flate_build_huffman([
      -1,
    ],
  )
  guard bad_length is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let empty_table : Result[FlateHuffmanTable, Error] = try? pdf_flate_build_huffman([
      0,
    ],
  )
  guard empty_table is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let bad_dynamic_symbol : Result[Unit, Error] = try? pdf_flate_check_dynamic_length_symbol(
    19,
  )
  guard bad_dynamic_symbol is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let repeated_lengths = [0]
  let repeated_overflow : Result[Unit, Error] = try? pdf_flate_push_repeated_lengths(
    repeated_lengths, 1, 1, 0,
  )
  guard repeated_overflow is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }

  let dynamic_repeat_without_previous : Result[
    (FlateHuffmanTable, FlateHuffmanTable),
    Error,
  ] = try? pdf_flate_read_dynamic_tables(
    FlateBitReader::new(
      wbtest_flate_bits([
        0, 0, 0, 0, 0, // HLIT: 257
         0, 0, 0, 0, 0, // HDIST: 1
         0, 0, 0, 0, // HCLEN: 4
         1, 0, 0, // code-length code 16 has bit length 1
         0, 0, 0, // code-length code 17
         0, 0, 0, // code-length code 18
         0, 0, 0, // code-length code 0
         0, // first decoded length symbol is 16
      ])[:],
    ),
  )
  guard dynamic_repeat_without_previous is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }

  let distance_lengths = [1]
  let distance_table = try! pdf_flate_build_huffman(distance_lengths)
  let invalid_length_lengths = Array::make(287, 0)
  invalid_length_lengths[286] = 1
  let invalid_length_table = try! pdf_flate_build_huffman(
    invalid_length_lengths,
  )
  let invalid_length_output : Array[Byte] = []
  let invalid_length : Result[Unit, Error] = try? pdf_flate_decode_huffman_block(
    FlateBitReader::new(wbtest_flate_bits([0])[:]),
    invalid_length_table,
    distance_table,
    invalid_length_output,
  )
  guard invalid_length is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }

  let copy_lengths = Array::make(258, 0)
  copy_lengths[257] = 1
  let copy_table = try! pdf_flate_build_huffman(copy_lengths)
  let invalid_distance_lengths = Array::make(31, 0)
  invalid_distance_lengths[30] = 1
  let invalid_distance_table = try! pdf_flate_build_huffman(
    invalid_distance_lengths,
  )
  let invalid_distance_output : Array[Byte] = [65]
  let invalid_distance : Result[Unit, Error] = try? pdf_flate_decode_huffman_block(
    FlateBitReader::new(wbtest_flate_bits([0, 0])[:]),
    copy_table,
    invalid_distance_table,
    invalid_distance_output,
  )
  guard invalid_distance is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }

  let past_output_output : Array[Byte] = []
  let past_output : Result[Unit, Error] = try? pdf_flate_decode_huffman_block(
    FlateBitReader::new(wbtest_flate_bits([0, 0])[:]),
    copy_table,
    distance_table,
    past_output_output,
  )
  guard past_output is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
}

///|
test "private image decode helpers cover scalar edge behavior" {
  @test.assert_eq(pdf_image_decode_is_identity([]), true)
  let odd_decode : Result[Bool, Error] = try? pdf_image_decode_is_identity([0.0])
  guard odd_decode is Err(PdfError::FilterExpected) else {
    fail("expected malformed decode values")
  }

  @test.assert_eq(pdf_image_decode_interpolate(0.0, 1.0, 1, 1), 1)
  @test.assert_eq(pdf_image_decode_interpolate(0.0, 3.0, 3, 2), 3)
  @test.assert_eq(pdf_image_decode_interpolate(0.0, 15.0, 15, 4), 15)
  @test.assert_eq(pdf_image_decode_interpolate(0.0, 1.0, 65535, 16), 1)
  @test.assert_eq(pdf_image_decode_interpolate(0.0, 2.0, 1, 7), 2)

  let sample = try! pdf_bytes_of_int_array([7])
  @test.assert_eq(
    try! pdf_image_apply_decode(sample, Some(16), Some([1.0, 0.0])),
    sample,
  )
  let missing_bpc : Result[PdfBytes, Error] = try? pdf_image_apply_decode(
    sample,
    None,
    Some([1.0, 0.0]),
  )
  guard missing_bpc is Err(PdfError::FilterExpected) else {
    fail("expected missing bpc for non-identity decode")
  }

  let doc = pdf_document_empty()
  let unsupported_indexed = PdfIndexed(PdfDeviceGray, [(0, [7])])
  let unsupported8 : Result[PdfBytes, Error] = try? doc.pdf_image_raw_colour_space_as_rgb24(
    1,
    1,
    unsupported_indexed,
    Some(8),
    sample[:],
  )
  guard unsupported8 is Err(PdfError::FilterExpected) else {
    fail("expected unsupported indexed 8bpp base")
  }
  let unsupported4 : Result[PdfBytes, Error] = try? doc.pdf_image_raw_colour_space_as_rgb24(
    1,
    1,
    unsupported_indexed,
    Some(4),
    sample[:],
  )
  guard unsupported4 is Err(PdfError::FilterExpected) else {
    fail("expected unsupported indexed 4bpp base")
  }

  let filters : Array[PdfObject] = []
  for _ in 0..<1025 {
    filters.push(PdfNameObject(pdf_name_of_bytes(@ascii.encode("/Crypt"))))
  }
  let too_many_stages = pdf_stream(
    pdf_dictionary([
      (pdf_name_of_bytes(@ascii.encode("/Length")), PdfInteger(sample.length())),
      (pdf_name_of_bytes(@ascii.encode("/Filter")), PdfArray(filters)),
    ]),
    StreamGot(sample),
  )
  let stage_limit : Result[PdfImageDecodedStream, Error] = try? doc.pdf_image_decode_to_image(
    too_many_stages,
  )
  guard stage_limit is Err(PdfError::FilterExpected) else {
    fail("expected image decode stage limit")
  }

  @test.assert_eq(pdf_image_clamp_unit(2.0), 1.0)
  @test.assert_eq(pdf_image_clamp_unit(-1.0), 0.0)
  @test.assert_eq(pdf_image_lab_g(1.0), 1.0)
}

///|
test "private function helpers cover parser and evaluator guards" {
  let doc = pdf_document_empty()

  let bad_number_array : Result[Array[Double], Error] = try? doc.pdf_fun_number_array(
    PdfInteger(1),
  )
  guard bad_number_array is Err(PdfError::NumberExpected) else {
    fail("expected number-array object")
  }
  let missing_int_array : Result[Array[Int], Error] = try? doc.pdf_fun_lookup_required_int_array(
    PdfDictionary([]),
    pdf_fun_size_key(),
  )
  guard missing_int_array is Err(PdfError::DictionaryKeyNotFound(name)) &&
    name == pdf_fun_size_key() else {
    fail("expected missing required int array")
  }
  let missing_int : Result[Int, Error] = try? doc.pdf_fun_lookup_required_int(
    PdfDictionary([]),
    pdf_fun_bits_per_sample_key(),
  )
  guard missing_int is Err(PdfError::DictionaryKeyNotFound(name)) &&
    name == pdf_fun_bits_per_sample_key() else {
    fail("expected missing required int")
  }
  let bad_optional_int : Result[Int, Error] = try? doc.pdf_fun_lookup_int_or(
    PdfDictionary([(pdf_fun_order_key(), PdfNameObject(pdf_fun_name("/Bad")))]),
    pdf_fun_order_key(),
    1,
  )
  guard bad_optional_int is Err(PdfError::NumberExpected) else {
    fail("expected malformed optional int")
  }
  let bad_stream : Result[PdfBytes, Error] = try? doc.pdf_fun_stream_data(
    PdfInteger(1),
  )
  guard bad_stream is Err(PdfError::ParseStreamExpected) else {
    fail("expected function stream")
  }
  let missing_function_type : Result[PdfFunction, Error] = try? doc.parse_function(
    PdfDictionary([(pdf_fun_domain_key(), PdfArray([]))]),
  )
  guard missing_function_type is Err(PdfError::DictionaryKeyNotFound(name)) &&
    name == pdf_fun_function_type_key() else {
    fail("expected missing function type")
  }

  @test.assert_eq(pdf_fun_clamp(-1.0, 0.0, 1.0), 0.0)
  let bad_clamp_range : Result[Array[Double], Error] = try? pdf_fun_clamp_values(
    [1.0],
    [0.0],
  )
  guard bad_clamp_range is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected clamp range arity failure")
  }

  let sampled : PdfSampledFunction = {
    size: [2],
    order: 1,
    encode: [0.0, 1.0],
    decode: [0.0, 1.0],
    bits_per_sample: 1,
    samples: [0, 1],
  }
  let sampled_function : PdfFunction = {
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
    func: PdfFunctionSampled(sampled),
  }
  let bad_sampled_input : Result[Array[Double], Error] = try? sampled.encoded_inputs(
    sampled_function,
    [],
  )
  guard bad_sampled_input is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled input arity failure")
  }
  let bad_table_arity : Result[Array[Double], Error] = try? sampled.read_table(
    [],
    1,
  )
  guard bad_table_arity is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled table arity failure")
  }
  let bad_table_index : Result[Array[Double], Error] = try? sampled.read_table(
    [2],
    1,
  )
  guard bad_table_index is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled table index failure")
  }
  let missing_sampled_range : PdfFunction = {
    domain: [0.0, 1.0],
    range: None,
    func: PdfFunctionSampled(sampled),
  }
  let missing_range : Result[Array[Double], Error] = try? sampled.eval_sampled(
    missing_sampled_range,
    [0.0],
  )
  guard missing_range is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled range")
  }
  let bad_decode_sampled : PdfSampledFunction = {
    size: [2],
    order: 1,
    encode: [0.0, 1.0],
    decode: [0.0, 1.0, 0.0, 1.0],
    bits_per_sample: 1,
    samples: [0, 1, 0, 1],
  }
  let bad_decode : Result[Array[Double], Error] = try? bad_decode_sampled.eval_sampled(
    sampled_function,
    [0.0],
  )
  guard bad_decode is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled output arity failure")
  }

  let interpolation : PdfFunction = {
    domain: [0.0, 1.0],
    range: None,
    func: PdfFunctionInterpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
  }
  let stitching : PdfStitchingFunction = {
    functions: [interpolation],
    bounds: [],
    stitch_encode: [0.0, 1.0],
  }
  let stitching_function : PdfFunction = {
    domain: [0.0, 1.0],
    range: None,
    func: PdfFunctionStitching(stitching),
  }
  let stitching_arity : Result[Array[Double], Error] = try? stitching.eval_stitching(
    stitching_function,
    [],
  )
  guard stitching_arity is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected stitching arity failure")
  }
  let stitching_bounds : Result[Array[Double], Error] = try? stitching.eval_stitching(
    stitching_function,
    [2.0],
  )
  guard stitching_bounds is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected stitching bounds failure")
  }

  let bool_number : Result[Double, Error] = try? pdf_fun_calculator_pop_number([
    PdfCalculatorBoolean(true),
  ])
  guard bool_number is Err(PdfError::BadFunctionEvaluation(_)) else {
    fail("expected calculator number")
  }
  @test.assert_eq(
    pdf_fun_calculator_values_equal(
      PdfCalculatorBoolean(true),
      PdfCalculatorBoolean(true),
    ),
    true,
  )
  @test.assert_eq(
    pdf_fun_calculator_values_equal(
      PdfCalculatorBoolean(true),
      PdfCalculatorInt(1),
    ),
    false,
  )
  @test.assert_eq(pdf_fun_calculator_int_max(), 2147483647)
  let min_abs_stack : Array[PdfCalculatorValue] = []
  try! pdf_fun_calculator_eval_operations(
    [PdfCalculatorInt(pdf_fun_calculator_int_min()), PdfCalculatorAbs],
    min_abs_stack,
  )
  guard min_abs_stack[0] is PdfCalculatorFloat(value) && value == 2147483647.0 else {
    fail("expected min-int abs to promote")
  }
  let min_neg_stack : Array[PdfCalculatorValue] = []
  try! pdf_fun_calculator_eval_operations(
    [PdfCalculatorInt(pdf_fun_calculator_int_min()), PdfCalculatorNeg],
    min_neg_stack,
  )
  guard min_neg_stack[0] is PdfCalculatorFloat(value) && value == 2147483647.0 else {
    fail("expected min-int neg to promote")
  }
}

///|
fn wbtest_text_bytes(values : ArrayView[Int]) -> PdfBytes {
  try! pdf_bytes_of_int_array(values)
}

///|
fn wbtest_text_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn wbtest_text_simple_font(
  encoding : PdfEncoding,
  descriptor : PdfFontDescriptor?,
) -> PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: descriptor,
    fontmetrics: None,
    encoding,
  })
}

///|
test "private text ToUnicode CMap helpers reject malformed ranges" {
  @test.assert_eq(pdf_text_parse_hex_bytes(@ascii.encode("0g")[:], 0, 2), None)
  @test.assert_eq(
    pdf_text_after_ascii(@ascii.encode("abc")[:], "missing"),
    None,
  )
  @test.assert_eq(
    pdf_text_parse_cmap_hex_groups(@ascii.encode("<0g>")[:]),
    None,
  )
  @test.assert_eq(
    pdf_text_parse_cmap_hex_group_at(@ascii.encode("<0g>")[:], 0),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(
      @ascii.encode("<01><02>[<0041>]")[:],
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(
      @ascii.encode("<01><01>[<0g>]")[:],
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(@ascii.encode("<00><01><ff>")[:]),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(
      @ascii.encode("<02><01><0041>")[:],
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(@ascii.encode("<01>")[:]),
    None,
  )
  @test.assert_eq(
    pdf_text_add_to_big_endian_bytes(wbtest_text_bytes([0xff]), 1),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_array_entries(1, 2, [wbtest_text_bytes([0])]),
    None,
  )
  let bfchar_entries : Array[(Int, PdfBytes)] = []
  pdf_text_push_tounicode_bfchar_entry(
    bfchar_entries,
    Bytes::new(0),
    wbtest_text_bytes([0x00, 0x41]),
  )
  @test.assert_eq(bfchar_entries, [])

  guard pdf_text_cmap_bfrange_array_start(@ascii.encode("<02><01>[")[:]) is None else {
    fail("expected invalid bfrange array start")
  }
  guard pdf_text_cmap_bfrange_array_start(@ascii.encode("<01>[")[:]) is None else {
    fail("expected incomplete bfrange array start")
  }
  guard pdf_text_cmap_bfrange_array_header(@ascii.encode("<02><01>")[:]) is None else {
    fail("expected invalid bfrange array header")
  }
  let pending : PdfTextCMapBFRangeArray = { first: 1, last: 2, unicodes: [] }
  let pending_entries : Array[(Int, PdfBytes)] = []
  @test.assert_eq(
    pdf_text_append_pending_bfrange_array(
      pending_entries,
      pending,
      @ascii.encode("<0041>]")[:],
    ),
    true,
  )
  @test.assert_eq(pending_entries, [])
  @test.assert_eq(pdf_text_parse_tounicode(@ascii.encode("plain")[:]), None)
  @test.assert_eq(
    pdf_text_parse_tounicode(
      @ascii.encode("1 beginbfrange <01><02>[<0041>] endbfrange\n")[:],
    ),
    None,
  )
}

///|
test "private text stream helpers treat malformed ToUnicode streams as absent" {
  let key = wbtest_text_name("/Missing")
  @test.assert_eq(pdf_text_dictionary_has_key(PdfInteger(1), key), false)
  @test.assert_eq(pdf_text_find_immediate_indirect(PdfInteger(1), key), None)
  let helper_doc = pdf_document_empty()

  let bad_deferred = pdf_stream(
    PdfDictionary([]),
    StreamToGet(
      stream_to_get(byte_cursor_of_bytes(@ascii.encode("abc")), -1, 1),
    ),
  )
  @test.assert_eq(
    helper_doc.pdf_text_decoded_stream_data_direct(bad_deferred),
    None,
  )
  let bad_filter = pdf_stream(
    PdfDictionary([(wbtest_text_name("/Filter"), PdfInteger(1))]),
    StreamGot(@ascii.encode("x")),
  )
  @test.assert_eq(
    helper_doc.pdf_text_decoded_stream_data_direct(bad_filter),
    None,
  )
  let unsupported_filter = pdf_stream(
    PdfDictionary([
      (wbtest_text_name("/Length"), PdfInteger(1)),
      (
        wbtest_text_name("/Filter"),
        PdfNameObject(wbtest_text_name("/NoSuchFilter")),
      ),
    ]),
    StreamGot(@ascii.encode("x")),
  )
  @test.assert_eq(
    helper_doc.pdf_text_decoded_stream_data_direct(unsupported_filter),
    None,
  )
  @test.assert_eq(
    helper_doc.pdf_text_decoded_stream_data_direct(PdfInteger(1)),
    None,
  )

  let doc = pdf_document_empty()
  let font = PdfDictionary([
    (wbtest_text_name("/ToUnicode"), unsupported_filter),
  ])
  @test.assert_eq(doc.pdf_text_tounicode_of_font(font), None)
}

///|
test "private text glyph helpers cover fallback and CID ToUnicode branches" {
  let implicit : PdfEncoding = PdfImplicitInFontFile
  @test.assert_eq(implicit.pdf_text_glyphname_of_charcode(65), None)
  let filled : PdfEncoding = PdfFillUndefinedWithStandard(PdfImplicitInFontFile)
  @test.assert_eq(
    filled.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  let filled_existing : PdfEncoding = PdfFillUndefinedWithStandard(
    PdfWinAnsiEncoding,
  )
  @test.assert_eq(
    filled_existing.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  let simple = wbtest_text_simple_font(PdfWinAnsiEncoding, None)
  @test.assert_eq(
    simple.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  @test.assert_eq(simple.pdf_text_uses_symbol_codepoints(), false)

  @test.assert_eq(
    pdf_text_codepoint_of_punctuation_glyphname(
      wbtest_text_name("/twosuperior"),
    ),
    Some(0x00B2),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_punctuation_glyphname(
      wbtest_text_name("/threesuperior"),
    ),
    Some(0x00B3),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_punctuation_glyphname(
      wbtest_text_name("/onesuperior"),
    ),
    Some(0x00B9),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_symbol_glyphname(wbtest_text_name("/logicalnot")),
    Some(0x00AC),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_symbol_glyphname(wbtest_text_name("/degree")),
    Some(0x00B0),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_symbol_glyphname(wbtest_text_name("/florin")),
    Some(0x0192),
  )
  @test.assert_eq(
    pdf_text_parse_hex_codepoint(@ascii.encode("D800")[:], 0, 4),
    None,
  )
  @test.assert_eq(
    pdf_text_uni_glyphname_codepoints(@ascii.encode("/uniD800")[:]),
    None,
  )
  @test.assert_eq(
    pdf_text_codepoints_of_glyphname(wbtest_text_name("/twosuperior.alt")),
    Some([0x00B2]),
  )
  @test.assert_eq(
    pdf_text_codepoints_of_glyphname(wbtest_text_name("/!")),
    None,
  )

  let fallback_font = wbtest_text_simple_font(
    PdfCustomEncoding(PdfImplicitInFontFile, [
      { name: wbtest_text_name("/unknown"), code: 65 },
    ]),
    None,
  )
  let fallback_extractor = fallback_font.text_extractor()
  @test.assert_eq(fallback_extractor.pdf_text_encoded_glyph_of_charcode(65), {
    glyphname: wbtest_text_name("/unknown"),
    codepoints: [65],
  })

  let invalid_tounicode = [(65, wbtest_text_bytes([0]))]
  let invalid_font = wbtest_text_simple_font(
    PdfWinAnsiEncoding,
    Some({
      ..pdf_text_empty_font_descriptor(),
      tounicode: Some(invalid_tounicode),
    }),
  )
  let invalid_extractor = invalid_font.text_extractor()
  @test.assert_eq(
    try! invalid_extractor.codepoints_of_text(wbtest_text_bytes([65])[:]),
    [65],
  )
  @test.assert_eq(invalid_extractor.charcode_of_codepoint(65), None)

  let tounicode = [(65, wbtest_text_bytes([0x00, 0x41]))]
  let cid_font : PdfFont = PdfFontCIDKeyed({
    basefont: wbtest_text_name("/Top"),
    composite: {
      cid_system_info: {
        registry: wbtest_text_bytes([82]),
        ordering: wbtest_text_bytes([79]),
        supplement: 0,
      },
      cid_basefont: wbtest_text_name("/Descendant"),
      cid_fontdescriptor: pdf_text_empty_font_descriptor(),
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfPredefinedCMap(wbtest_text_name("/Identity-H")),
  })
  let cid_with_tounicode = cid_font.pdf_text_with_tounicode(Some(tounicode))
  @test.assert_eq(cid_with_tounicode.pdf_text_tounicode(), Some(tounicode))
  let standard_font : PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(
    standard_font.pdf_text_with_tounicode(Some(tounicode)),
    standard_font,
  )
  @test.assert_eq(pdf_text_hex_int_min2(7), "07")
}

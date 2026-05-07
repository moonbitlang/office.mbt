// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "private PDF number set deduplicates membership and additions" {
  let numbers = pdf_number_set([1, 1])
  @test.assert_eq(numbers.contains(1), true)
  @test.assert_eq(numbers.contains(2), false)
  numbers.add(2)
  numbers.add(2)
  @test.assert_eq(numbers.contains(2), true)
  let output : Array[Int] = []
  pdf_push_unique_number(output, numbers, 2)
  pdf_push_unique_number(output, numbers, 3)
  pdf_push_unique_number(output, numbers, 3)
  @test.assert_eq(output, [3])
}

///|
test "private destination page number lookup preserves first page reference" {
  let lookup = pdf_page_number_lookup([10, 10, 20])
  @test.assert_eq(lookup.page_number(10), 1)
  @test.assert_eq(lookup.page_number(20), 3)
  @test.assert_eq(lookup.page_number(30), 0)
  @test.assert_eq(
    pdf_destination_page_number_of_target(lookup, TargetOtherDocPageNumber(1)),
    2,
  )
  @test.assert_eq(
    pdf_destination_page_number_of_target(lookup, TargetPageObject(10)),
    1,
  )
}

///|
test "pdf duplicate stream candidates reject non-stream objects" {
  @test.assert_eq(
    pdf_duplicate_stream_candidate(1, PdfInteger(1)) is None,
    true,
  )
  let stream = pdf_stream(PdfDictionary([]), StreamGot(@ascii.encode("a")))
  guard pdf_duplicate_stream_candidate(2, stream) is Some(candidate) else {
    fail("expected stream candidate")
  }
  @test.assert_eq(candidate.number, 2)
  @test.assert_eq(candidate.equals(candidate), true)
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
test "PdfDocument stream decompression preserves already-decrypted state" {
  let length = pdf_name_of_bytes(@ascii.encode("/Length"))
  let filter = pdf_name_of_bytes(@ascii.encode("/Filter"))
  let encoded = pdf_ascii_hex_encode(@ascii.encode("Hi"))
  let stream = pdf_stream(
    pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(pdf_name_of_bytes(@ascii.encode("/AHx")))),
    ]),
    StreamGot(encoded),
  )
  let doc = pdf_document_empty()
  doc.objects.set_entry(
    6,
    pdf_object_entry(ObjectParsedAlreadyDecrypted(stream), generation=3),
  )
  try! doc.pdf_decode_streams_until_unknown()
  guard doc.objects.get_entry(6)
    is Some(
      {
        data: ObjectParsedAlreadyDecrypted(PdfStreamObject(decoded)),
        generation: 3,
      }
    ) else {
    fail("expected already-decrypted stream")
  }
  @test.assert_eq(decoded.data, StreamGot(@ascii.encode("Hi")))
  @test.assert_eq(
    decoded.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
}

///|
test "PdfDocument renumbering preserves parser object-stream hints" {
  let doc = pdf_document_empty()
  doc.objects.set_entry(8, pdf_object_entry(ObjectParsed(PdfInteger(8))))
  doc.objects.set_entry(9, pdf_object_entry(ObjectParsed(PdfInteger(9))))
  doc.objects.object_stream_ids[8] = 5
  doc.objects.object_stream_ids[99] = 5
  let renumbered = try! doc.renumber_objects([(8, 2), (9, 3)])
  @test.assert_eq(renumbered.objects.object_stream_ids.get(2), Some(5))
  @test.assert_eq(renumbered.objects.object_stream_ids.get(8), None)
  @test.assert_eq(renumbered.objects.object_stream_ids.get(99), None)
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
test "PdfDocument select_object_numbers ignores deferred parser states" {
  let doc = pdf_document_empty()
  doc.add_object_given_number(1, PdfNull)
  doc.objects.set_entry(2, pdf_object_entry(ObjectToParse))
  doc.objects.set_entry(
    3,
    pdf_object_entry(
      ObjectToParseFromObjectStream({ object_stream_number: 7, index: 0 }),
    ),
  )
  @test.assert_eq(doc.select_object_numbers(fn(object) { object == PdfNull }), [
    1,
  ])
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
test "incremental writer rejects changed deferred objects" {
  let original_doc = pdf_document_empty()
  original_doc.set_version(1, 4)
  original_doc.set_root(1)
  original_doc.add_object_given_number(1, PdfDictionary([]))
  let original = try! pdf_write_document(original_doc)

  let changed = try! pdf_read_document_from_bytes(original)
  changed.objects.set_entry(1, pdf_object_entry(ObjectToParse))
  changed.objects.log.push((1, ObjectAltered))
  let result : Result[PdfBytes, Error] = try? pdf_write_document_incremental_update(
    original, changed,
  )
  guard result is Err(PdfError::ParsedObjectExpected) else {
    fail("expected ParsedObjectExpected")
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
  @test.assert_eq(deferred_entries.length(), 2)
  @test.assert_eq(deferred_entries[0].object_number, 3)
  @test.assert_eq(deferred_entries[0].offset, 7)
  @test.assert_eq(deferred_entries[0].generation, 0)
  @test.assert_eq(deferred_entries[0].in_use, true)
  @test.assert_eq(
    deferred_entries[0].object_stream,
    Some({ object_stream_number: 7, index: 0 }),
  )
  @test.assert_eq(deferred_entries[1].object_number, 4)
  @test.assert_eq(deferred_entries[1].offset, 0)
  @test.assert_eq(deferred_entries[1].generation, 0)
  @test.assert_eq(deferred_entries[1].in_use, false)
  @test.assert_eq(deferred_entries[1].object_stream, None)
}

///|
test "private object stream helpers cover malformed object streams" {
  let key_type = pdf_reader_name("/Type")
  let key_n = pdf_reader_name("/N")
  let key_first = pdf_reader_name("/First")
  let key_length = pdf_reader_name("/Length")

  let missing_required : Result[Int, Error] = try? pdf_document_empty().pdf_object_stream_required_int(
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

  @test.assert_eq(
    pdf_object_stream_end_offsets([(2, 4), (3, 0), (4, 4), (5, 8)][:], 20, 8),
    [8, 4, 8, 12],
  )
  @test.assert_eq(pdf_object_stream_end_offsets([(2, 0), (3, 100)][:], 20, 8), [
    12, 12,
  ])

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
  let context = try! doc.read_object_stream_context(7)
  @test.assert_eq(context.end_offsets, [4, 9])
  @test.assert_eq(
    try! context.read_reference({ object_stream_number: 7, index: 0 }),
    (2, PdfBoolean(true)),
  )
  @test.assert_eq(
    try! context.read_reference({ object_stream_number: 7, index: 1 }),
    (3, PdfBoolean(false)),
  )
  let bad_index : Result[(Int, PdfObject), Error] = try? context.read_reference({
      object_stream_number: 7,
      index: 9,
    },
  )
  guard bad_index is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
  let recovered_doc = pdf_document_empty()
  recovered_doc.add_object_given_number(7, valid_stream)
  let recovered_xrefs = [
    {
      object_number: 2,
      offset: 0,
      generation: 0,
      in_use: true,
      object_stream: Some({ object_stream_number: 7, index: 0 }),
    },
    {
      object_number: 3,
      offset: 0,
      generation: 0,
      in_use: true,
      object_stream: Some({ object_stream_number: 7, index: 1 }),
    },
  ]
  let grouped_xrefs = pdf_reader_object_stream_groups(
    [
      {
        object_number: 0,
        offset: 0,
        generation: 0,
        in_use: true,
        object_stream: Some({ object_stream_number: 7, index: 0 }),
      },
      recovered_xrefs[0],
      {
        object_number: 4,
        offset: 0,
        generation: 0,
        in_use: false,
        object_stream: Some({ object_stream_number: 9, index: 0 }),
      },
      recovered_xrefs[1],
      {
        object_number: 5,
        offset: 0,
        generation: 0,
        in_use: true,
        object_stream: Some({ object_stream_number: 9, index: 0 }),
      },
      {
        object_number: 6,
        offset: 0,
        generation: 0,
        in_use: true,
        object_stream: None,
      },
    ][:],
  )
  @test.assert_eq(grouped_xrefs.length(), 2)
  @test.assert_eq(grouped_xrefs[0].0, 7)
  @test.assert_eq(grouped_xrefs[0].1.length(), 2)
  @test.assert_eq(grouped_xrefs[0].1[0].0.object_number, 2)
  @test.assert_eq(grouped_xrefs[0].1[0].1.index, 0)
  @test.assert_eq(grouped_xrefs[0].1[1].0.object_number, 3)
  @test.assert_eq(grouped_xrefs[0].1[1].1.index, 1)
  @test.assert_eq(grouped_xrefs[1].0, 9)
  @test.assert_eq(grouped_xrefs[1].1.length(), 1)
  @test.assert_eq(grouped_xrefs[1].1[0].0.object_number, 5)
  recovered_doc.load_reconstructed_xref_stream_embedded_objects(
    recovered_xrefs[:],
  )
  @test.assert_eq(recovered_doc.lookup_object_or_null(2), PdfBoolean(true))
  @test.assert_eq(recovered_doc.lookup_object_or_null(3), PdfBoolean(false))

  let password_recovered_doc = pdf_document_empty()
  password_recovered_doc.add_object_given_number(7, valid_stream)
  password_recovered_doc.load_reconstructed_xref_stream_embedded_objects_with_passwords(
    recovered_xrefs[:],
    None,
    None,
  )
  @test.assert_eq(
    password_recovered_doc.lookup_object_or_null(2),
    PdfBoolean(true),
  )

  let bad_embedded_xrefs = [
    {
      object_number: 4,
      offset: 0,
      generation: 0,
      in_use: true,
      object_stream: Some({ object_stream_number: 7, index: 9 }),
    },
  ]
  recovered_doc.load_reconstructed_xref_stream_embedded_objects(
    bad_embedded_xrefs[:],
  )
  @test.assert_eq(recovered_doc.lookup_object_or_null(4), PdfNull)
  password_recovered_doc.load_reconstructed_xref_stream_embedded_objects_with_passwords(
    bad_embedded_xrefs[:],
    None,
    None,
  )
  @test.assert_eq(password_recovered_doc.lookup_object_or_null(4), PdfNull)

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
  let no_type_context = try! no_type_doc.read_object_stream_context(10)
  @test.assert_eq(
    try! no_type_context.read_reference({ object_stream_number: 10, index: 0 }),
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
  let wrong_type : Result[PdfObjectStreamContext, Error] = try? wrong_type_doc.read_object_stream_context(
    8,
  )
  guard wrong_type is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let missing_stream : Result[PdfObjectStreamContext, Error] = try? doc.read_object_stream_context(
    99,
  )
  guard missing_stream is Err(PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let missing_encrypted_stream : Result[(PdfObjectStreamContext, Bool), Error] = try? doc.read_object_stream_context_with_passwords(
    99,
    Some(@ascii.encode("user")[:]),
    None,
  )
  guard missing_encrypted_stream is Err(PdfError::XRefEntryExpected) else {
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
  let bad_offset_context = try! bad_offset_doc.read_object_stream_context(9)
  let bad_offset : Result[(Int, PdfObject), Error] = try? bad_offset_context.read_reference({
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
test "private stream data no-crypt decrypt returns bytes" {
  let source = @ascii.encode("abc")
  let copied = PdfStreamDataNoCrypt.decrypt(source[:])
  @test.assert_eq(copied, source)
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
  @test.assert_eq(
    pdf_lexeme_indirect_object_header_at([LexInt(1), LexInt(0), LexObj], 0),
    true,
  )
  @test.assert_eq(
    pdf_lexeme_indirect_object_header_at([LexInt(1), LexInt(0), LexNull], 0),
    false,
  )
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
  @test.assert_eq(
    try! pdf_parse_indirect_object_prefix_lexemes([
      LexInt(2),
      LexInt(0),
      LexObj,
      LexEndObj,
    ]),
    { number: 2, generation: 0, object: PdfNull },
  )
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
  let overflow_number : Result[Int, Error] = try? pdf_parse_ascii_int_view(
    @ascii.encode("2147483648")[:],
  )
  guard overflow_number is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
  @test.assert_eq(
    try! pdf_parse_ascii_int_view(@ascii.encode("2147483647")[:]),
    2147483647,
  )
  @test.assert_eq(pdf_number_view_int(Bytes::new(0)[:]), None)
  @test.assert_eq(pdf_number_view_int(@ascii.encode("+")[:]), None)
  @test.assert_eq(pdf_number_view_int(@ascii.encode("-")[:]), None)
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
  let xref_target : Array[PdfClassicXRefEntry] = [
    {
      object_number: 2,
      offset: 20,
      generation: 0,
      in_use: true,
      object_stream: None,
    },
  ]
  pdf_classic_xrefs_add_newer_first(xref_target, [
    {
      object_number: 2,
      offset: 99,
      generation: 0,
      in_use: true,
      object_stream: None,
    },
    {
      object_number: 3,
      offset: 30,
      generation: 0,
      in_use: false,
      object_stream: None,
    },
  ])
  @test.assert_eq([ for xref in xref_target => xref.object_number ], [2, 3])
  @test.assert_eq([ for xref in xref_target => xref.offset ], [20, 30])
  let xref_stream_ref_set = pdf_reader_xref_stream_ref_set([
    (5, 100),
    (5, 200),
    (7, 100),
  ])
  @test.assert_eq(xref_stream_ref_set.contains(5, 100), true)
  @test.assert_eq(xref_stream_ref_set.contains(5, 300), false)
  @test.assert_eq(xref_stream_ref_set.contains(7, 100), true)
  @test.assert_eq(xref_stream_ref_set.contains(8, 100), false)

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
  @test.assert_eq(
    try! byte_cursor_of_bytes(@ascii.encode("2 0 obj\n42\n")).read_plain_indirect_object_at_current(),
    { number: 2, generation: 0, object: PdfInteger(42) },
  )

  let empty_prefix = byte_cursor_of_bytes(Bytes::new(0))
  let empty_prefix_result : Result[PdfParsedIndirectObject, Error] = try? empty_prefix.read_reconstructed_indirect_prefix_at_current()
  guard empty_prefix_result is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }
  let incomplete_scan = byte_cursor_of_bytes(@ascii.encode("3 0 obj\n42\n"))
  let (incomplete_candidate, incomplete_next) = try! incomplete_scan.read_reconstructed_indirect_scan_candidate_at_current(
    empty_xrefs[:],
  )
  @test.assert_eq(incomplete_candidate, {
    number: 3,
    generation: 0,
    object: PdfInteger(42),
  })
  @test.assert_eq(incomplete_next, None)
  let incomplete_xrefs = try! pdf_read_reconstructed_xrefs(
    @ascii.encode("3 0 obj\n42\n")[:],
  )
  @test.assert_eq(incomplete_xrefs.length(), 1)
  @test.assert_eq(incomplete_xrefs[0].object_number, 3)
  let noisy_digits = @ascii.encode(
    "12345 67 notobj\n90 0 nope\nabc 4 0 obj\n42\nendobj\n",
  )
  let valid_header = pdf_find_ascii_from(noisy_digits[:], 0, [
    52, 32, 48, 32, 111, 98, 106,
  ])
  @test.assert_eq(
    pdf_reader_reconstruction_indirect_header_at(noisy_digits[:], 0),
    false,
  )
  @test.assert_eq(
    pdf_reader_reconstruction_indirect_header_at(noisy_digits[:], valid_header),
    true,
  )
  let noisy_xrefs = try! pdf_read_reconstructed_xrefs(noisy_digits[:])
  @test.assert_eq(noisy_xrefs.length(), 1)
  @test.assert_eq(noisy_xrefs[0].object_number, 4)
  @test.assert_eq(noisy_xrefs[0].offset, valid_header)
  let nested_bad_object = @ascii.encode(
    "1 0 obj\n]\n2 0 obj\n<< /Type /Catalog >>\nendobj\n3 0 obj\n42\nendobj\n",
  )
  let endobj = [101, 110, 100, 111, 98, 106]
  let nested_endobj = pdf_find_ascii_from(nested_bad_object[:], 0, endobj)
  @test.assert_eq(
    pdf_reader_reconstruction_indirect_header_at(nested_bad_object[:], 0),
    true,
  )
  @test.assert_eq(
    pdf_reader_reconstruction_indirect_header_at(
      @ascii.encode("1 0 object")[:],
      0,
    ),
    false,
  )
  @test.assert_eq(
    pdf_reader_reconstruction_skip_malformed_object(nested_bad_object[:], 0),
    Some(nested_endobj + 7),
  )
  @test.assert_eq(
    pdf_reader_reconstruction_skip_malformed_object(nested_bad_object[:], 1),
    None,
  )
  let line_ending_endobj = @ascii.encode("1 0 obj\n]\nabcendobj\r\n4 0 obj\n")
  let trailing_endobj = pdf_find_ascii_from(line_ending_endobj[:], 0, endobj)
  @test.assert_eq(
    pdf_reader_reconstruction_skip_malformed_object(line_ending_endobj[:], 0),
    Some(trailing_endobj + 8),
  )
  let leading_trim_endobj = @ascii.encode("1 0 obj\n]\n  endobj\n")
  @test.assert_eq(
    pdf_reader_reconstruction_skip_malformed_object(leading_trim_endobj[:], 0),
    Some(leading_trim_endobj.length()),
  )
  let no_endobj = @ascii.encode("1 0 obj\n]")
  @test.assert_eq(
    pdf_reader_reconstruction_skip_malformed_object(no_endobj[:], 0),
    Some(no_endobj.length()),
  )
  let bad_resolved_length = @ascii.encode(
    "1 0 obj\n<< /Length 2 0 R >>\nstream\nHi\nendstream\nendobj\n2 0 obj\n999999\nendobj\n",
  )
  let bad_resolved_length_xrefs = try! pdf_read_reconstructed_xrefs(
    bad_resolved_length[:],
  )
  let bad_resolved_length_cursor = byte_cursor_of_view(bad_resolved_length[:])
  let objects_with_bad_resolved_length : Array[PdfParsedIndirectObject] = []
  for xref in bad_resolved_length_xrefs {
    let parsed : Result[PdfParsedIndirectObject, Error] = try? bad_resolved_length_cursor.read_reconstructed_object_at(
      xref.offset,
      bad_resolved_length_xrefs[:],
    )
    match parsed {
      Ok(object) =>
        if object.number == xref.object_number &&
          object.generation == xref.generation {
          objects_with_bad_resolved_length.push(object)
        }
      Err(_) => ()
    }
  }
  @test.assert_eq(objects_with_bad_resolved_length.length(), 1)
  @test.assert_eq(objects_with_bad_resolved_length[0].number, 2)

  @test.assert_eq(
    pdf_reader_stream_data_end_before_marker(
      @ascii.encode("A\r\nendstream")[:],
      3,
    ),
    1,
  )
  @test.assert_eq(
    pdf_reader_stream_data_end_before_marker(
      @ascii.encode("A\rendstream")[:],
      2,
    ),
    1,
  )
  @test.assert_eq(
    pdf_reader_stream_data_end_before_marker(@ascii.encode("Aendstream")[:], 1),
    1,
  )
  let malformed_stream = byte_cursor_of_bytes(@ascii.encode("stream\nabc"))
  let malformed_stream_result : Result[PdfParsedIndirectObject, Error] = try? malformed_stream.finish_pdf_malformed_stream_object({
      number: 1,
      generation: 0,
      object: PdfDictionary([]),
    },
  )
  guard malformed_stream_result is Err(PdfError::ParseEndStreamExpected) else {
    fail("expected ParseEndStreamExpected")
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
fn wbtest_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text)[:] {
    output.push(byte)
  }
}

///|
fn wbtest_cyclic_prev_xref_pdf() -> PdfBytes {
  let output : Array[Byte] = []
  wbtest_push_ascii(output, "%PDF-1.4\n")
  let xref_offset = output.length()
  wbtest_push_ascii(
    output, "xref\n0 1\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 1 /Prev ",
  )
  wbtest_push_ascii(output, xref_offset.to_string())
  wbtest_push_ascii(output, " >>\nstartxref\n")
  wbtest_push_ascii(output, xref_offset.to_string())
  wbtest_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn wbtest_hybrid_xrefstm_pdf() -> PdfBytes {
  let output : Array[Byte] = []
  wbtest_push_ascii(output, "%PDF-1.5\n")
  let xref_stream_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_writer_push_xref_stream_entry(xref_data, 0, 0, 65535)
  wbtest_push_ascii(output, "2 0 obj\n<< /Type /XRef /Length ")
  wbtest_push_ascii(output, xref_data.length().to_string())
  wbtest_push_ascii(output, " /Size 1 /W [1 4 2] >>\nstream\n")
  for byte in xref_data {
    output.push(byte)
  }
  wbtest_push_ascii(output, "\nendstream\nendobj\n")
  let classic_xref_offset = output.length()
  wbtest_push_ascii(
    output, "xref\n0 1\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 1 /XRefStm ",
  )
  wbtest_push_ascii(output, xref_stream_offset.to_string())
  wbtest_push_ascii(output, " >>\nstartxref\n")
  wbtest_push_ascii(output, classic_xref_offset.to_string())
  wbtest_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
test "private password reconstruction xref metadata probe covers repair boundaries" {
  let hybrid = wbtest_hybrid_xrefstm_pdf()
  pdf_reader_validate_xref_metadata_for_reconstruction(hybrid[:])

  let cyclic = try? pdf_reader_validate_xref_metadata_for_reconstruction(
    wbtest_cyclic_prev_xref_pdf()[:],
  )
  guard cyclic is Err(XRefExpected) else { fail("expected cyclic Prev guard") }
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
  let deleted_pages = pdf_number_set([2])
  @test.assert_eq(
    doc.pdf_structure_object_has_deleted_page_in_set(
      PdfIndirect(50),
      deleted_pages,
    ),
    true,
  )
  @test.assert_eq(
    doc.pdf_structure_indirect_survives_in_set(50, deleted_pages),
    false,
  )
  @test.assert_eq(
    doc.pdf_structure_k_item_survives_in_set(PdfInteger(1), deleted_pages),
    true,
  )
  @test.assert_eq(
    doc.pdf_structure_filtered_k_value_in_set(PdfInteger(1), deleted_pages),
    None,
  )
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
fn wbtest_assert_known_content_some(
  operator : String,
  operands : ArrayView[PdfObject],
  expected : PdfContentOp,
) -> Unit raise Error {
  @test.assert_eq(
    pdf_content_parse_known_section(operands, @ascii.encode(operator)),
    Some(expected),
  )
}

///|
fn wbtest_lzw_codes(codes : ArrayView[Int], early_change : Int) -> PdfBytes {
  let writer = bit_writer_new()
  let mut code_length = 9
  let mut next_code = 258
  let mut old_code = 256
  for code in codes {
    try! writer.put_value_int(code_length, code)
    match code {
      256 => {
        code_length = 9
        next_code = 258
        old_code = 256
      }
      257 => ()
      _ =>
        if old_code == 256 {
          old_code = code
        } else {
          next_code += 1
          match next_code + early_change {
            512 | 1024 | 2048 => code_length += 1
            _ => ()
          }
          old_code = code
        }
    }
  }
  writer.to_bytes()
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
    pdf_content_tj_array_from_operand(
      PdfArray([
        PdfString(@ascii.encode("A")),
        PdfInteger(-3),
        PdfArray([PdfInteger(1)]),
        PdfReal(2.5),
      ]),
    ),
    Some(PdfArray([PdfString(@ascii.encode("A")), PdfReal(-3.0), PdfReal(2.5)])),
  )
  @test.assert_eq(pdf_content_tj_array_from_operand(PdfInteger(1)), None)

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
      None,
      PdfDictionary([]),
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
      None,
      PdfDictionary([]),
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
      None,
      PdfDictionary([]),
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
  @test.assert_eq(
    pdf_content_filter_is_inline_dct(
      PdfArray([
        PdfNameObject(wbtest_content_name("/DCTDecode")),
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
      ]),
    ),
    true,
  )
  guard pdf_content_filter_inline_text_filter(PdfInteger(1)) is None else {
    fail("expected no text filter for non-name")
  }
  guard pdf_content_filter_inline_text_filter(
      PdfNameObject(wbtest_content_name("/Unsupported")),
    )
    is None else {
    fail("expected no text filter for unsupported name")
  }
  guard pdf_content_filter_inline_text_filter(
      PdfArray([
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
        PdfNameObject(wbtest_content_name("/FlateDecode")),
      ]),
    )
    is Some(PdfContentInlineAscii85) else {
    fail("expected ASCII85 text filter")
  }
  guard pdf_content_inline_image_text_filter(PdfDictionary([])) is None else {
    fail("expected no inline image text filter")
  }
  guard pdf_content_inline_image_single_text_filter(PdfDictionary([])) is None else {
    fail("expected no single inline image text filter")
  }
  guard pdf_content_filter_single_inline_text_filter(
      PdfNameObject(wbtest_content_name("/AHx")),
    )
    is Some(PdfContentInlineAsciiHex) else {
    fail("expected single ASCIIHex text filter")
  }
  guard pdf_content_filter_single_inline_text_filter(
      PdfArray([PdfNameObject(wbtest_content_name("/ASCII85Decode"))]),
    )
    is Some(PdfContentInlineAscii85) else {
    fail("expected single ASCII85 text filter")
  }
  guard pdf_content_filter_single_inline_text_filter(
      PdfArray([
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
        PdfNameObject(wbtest_content_name("/FlateDecode")),
      ]),
    )
    is None else {
    fail("expected no single text filter for multi-stage array")
  }
  @test.assert_eq(
    try! pdf_content_read_text_encoded_inline_image_data(
      byte_cursor_of_bytes(@ascii.encode("616263> EI")),
      PdfContentInlineAsciiHex,
    ),
    @ascii.encode("616263>"),
  )
  let missing_text_encoded_end : Result[PdfBytes, Error] = try? pdf_content_read_text_encoded_inline_image_data(
    byte_cursor_of_bytes(@ascii.encode("616263 EI")),
    PdfContentInlineAsciiHex,
  )
  guard missing_text_encoded_end is Err(_) else {
    fail("expected missing text inline image end to raise")
  }
  let decoded_hex_cursor = byte_cursor_of_bytes(
    @ascii.encode("616263> EI next"),
  )
  @test.assert_eq(
    try! pdf_content_read_text_encoded_inline_image_decoded(
      decoded_hex_cursor,
      PdfContentInlineAsciiHex,
    ),
    @ascii.encode("abc"),
  )
  @test.assert_eq(
    decoded_hex_cursor.remaining_view(),
    @ascii.encode(" next")[:],
  )
  let ascii85_inline = pdf_ascii85_encode(@ascii.encode("abc"))
  let decoded_ascii85_cursor = byte_cursor_of_bytes(
    pdf_bytes_concat_views([ascii85_inline[:], @ascii.encode(" EI next")[:]]),
  )
  @test.assert_eq(
    try! pdf_content_read_text_encoded_inline_image_decoded(
      decoded_ascii85_cursor,
      PdfContentInlineAscii85,
    ),
    @ascii.encode("abc"),
  )
  @test.assert_eq(
    decoded_ascii85_cursor.remaining_view(),
    @ascii.encode(" next")[:],
  )
  @test.assert_eq(pdf_content_filter_is_inline_run_length(PdfInteger(1)), false)
  @test.assert_eq(
    pdf_content_inline_image_uses_single_run_length(PdfDictionary([])),
    false,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_run_length(
      PdfNameObject(wbtest_content_name("/RL")),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_run_length(
      PdfArray([PdfNameObject(wbtest_content_name("/RunLengthDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_run_length(
      PdfArray([
        PdfNameObject(wbtest_content_name("/RunLengthDecode")),
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
      ]),
    ),
    false,
  )
  @test.assert_eq(pdf_content_filter_is_inline_flate(PdfInteger(1)), false)
  @test.assert_eq(
    pdf_content_inline_image_uses_single_flate(PdfDictionary([])),
    false,
  )
  @test.assert_eq(
    pdf_content_filter_is_inline_flate(
      PdfArray([PdfNameObject(wbtest_content_name("/FlateDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_flate(
      PdfNameObject(wbtest_content_name("/Fl")),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_flate(
      PdfArray([PdfNameObject(wbtest_content_name("/FlateDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_flate(
      PdfArray([
        PdfNameObject(wbtest_content_name("/FlateDecode")),
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
      ]),
    ),
    false,
  )
  @test.assert_eq(pdf_content_filter_is_inline_lzw(PdfInteger(1)), false)
  @test.assert_eq(
    pdf_content_inline_image_uses_single_lzw(PdfDictionary([])),
    false,
  )
  @test.assert_eq(
    pdf_content_filter_is_inline_lzw(
      PdfArray([PdfNameObject(wbtest_content_name("/LZWDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_lzw(
      PdfNameObject(wbtest_content_name("/LZW")),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_lzw(
      PdfArray([PdfNameObject(wbtest_content_name("/LZWDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_lzw(
      PdfArray([
        PdfNameObject(wbtest_content_name("/LZWDecode")),
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
      ]),
    ),
    false,
  )
  let flate_inline = pdf_flate_encode(@ascii.encode("AB"))
  @test.assert_eq(
    try! pdf_content_read_flate_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([flate_inline[:], @ascii.encode(" EI")[:]]),
      ),
    ),
    flate_inline,
  )
  @test.assert_eq(
    pdf_content_read_flate_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([
          @ascii.encode(" ")[:],
          flate_inline[:],
          @ascii.encode(" EI")[:],
        ]),
      ),
    ),
    flate_inline,
  )
  let decoded_flate_cursor = byte_cursor_of_bytes(
    pdf_bytes_concat_views([flate_inline[:], @ascii.encode(" EI next")[:]]),
  )
  @test.assert_eq(
    try! pdf_content_read_flate_inline_image_decoded(decoded_flate_cursor),
    @ascii.encode("AB"),
  )
  @test.assert_eq(
    decoded_flate_cursor.remaining_view(),
    @ascii.encode(" next")[:],
  )
  let lzw_inline = wbtest_lzw_codes([256, 65, 257], 1)
  @test.assert_eq(
    try! pdf_content_read_lzw_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([lzw_inline[:], @ascii.encode(" EI")[:]]),
      ),
      PdfDictionary([]),
      None,
    ),
    lzw_inline,
  )
  @test.assert_eq(
    pdf_content_read_lzw_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([
          @ascii.encode(" ")[:],
          lzw_inline[:],
          @ascii.encode(" EI")[:],
        ]),
      ),
      PdfDictionary([]),
      None,
    ),
    lzw_inline,
  )
  let decoded_lzw_cursor = byte_cursor_of_bytes(
    pdf_bytes_concat_views([lzw_inline[:], @ascii.encode(" EI next")[:]]),
  )
  @test.assert_eq(
    try! pdf_content_read_lzw_inline_image_decoded(decoded_lzw_cursor),
    @ascii.encode("A"),
  )
  @test.assert_eq(
    decoded_lzw_cursor.remaining_view(),
    @ascii.encode(" next")[:],
  )
  @test.assert_eq(
    try! pdf_content_read_lzw_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([lzw_inline[:], @ascii.encode(" EI")[:]]),
      ),
      PdfDictionary([]),
      Some(
        PdfDictionary([(wbtest_content_name("/EarlyChange"), PdfInteger(1))]),
      ),
    ),
    lzw_inline,
  )
  @test.assert_eq(
    try! pdf_content_read_run_length_inline_image_data(
      byte_cursor_of_bytes(
        try! pdf_bytes_of_int_array([253, 90, 128, 32, 69, 73]),
      ),
    ),
    try! pdf_bytes_of_int_array([253, 90, 128]),
  )
  let run_length_encoded = try! pdf_bytes_of_int_array([253, 90, 128])
  let decoded_run_length_cursor = byte_cursor_of_bytes(
    pdf_bytes_concat_views([run_length_encoded[:], @ascii.encode(" EI next")[:]]),
  )
  @test.assert_eq(
    try! pdf_content_read_run_length_inline_image_decoded(
      decoded_run_length_cursor,
    ),
    @ascii.encode("ZZZZ"),
  )
  @test.assert_eq(
    decoded_run_length_cursor.remaining_view(),
    @ascii.encode(" next")[:],
  )
  let missing_run_length_eod : Result[PdfBytes, Error] = try? pdf_content_read_run_length_inline_image_decoded(
    byte_cursor_of_bytes(try! pdf_bytes_of_int_array([253, 90])),
  )
  guard missing_run_length_eod is Err(PdfError::ParseEndStreamExpected) else {
    fail("expected ParseEndStreamExpected")
  }
  let missing_encoded_run_length_eod : Result[PdfBytes, Error] = try? pdf_content_read_run_length_inline_image_data(
    byte_cursor_of_bytes(try! pdf_bytes_of_int_array([253, 90])),
  )
  guard missing_encoded_run_length_eod is Err(_) else {
    fail("expected missing encoded run length EOD to raise")
  }
  let short_run_length_prefix : Result[(PdfBytes, Int), Error] = try? pdf_content_run_length_decode_view_prefix(
    (try! pdf_bytes_of_int_array([253]))[:],
  )
  guard short_run_length_prefix is Err(_) else {
    fail("expected short run length prefix to raise")
  }
  let flate_with_decode_parms = byte_cursor_of_bytes(
    pdf_bytes_concat_views([
      @ascii.encode("/W 1 /H 2 /CS /G /BPC 8 /F /Fl /DP << /Predictor 1 >> ID ")[:],
      flate_inline[:],
      @ascii.encode(" EI")[:],
    ]),
  )
  @test.assert_eq(
    pdf_content_read_inline_image(
      flate_with_decode_parms,
      None,
      PdfDictionary([]),
    ),
    Op_InlineImage(
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(2)),
        (wbtest_content_name("/CS"), PdfNameObject(wbtest_content_name("/G"))),
        (wbtest_content_name("/BPC"), PdfInteger(8)),
      ]),
      None,
      @ascii.encode("AB"),
    ),
  )
  let lzw_with_decode_parms = byte_cursor_of_bytes(
    pdf_bytes_concat_views([
      @ascii.encode(
        "/W 1 /H 1 /CS /G /BPC 8 /F /LZW /DP << /EarlyChange 1 >> ID ",
      )[:],
      lzw_inline[:],
      @ascii.encode(" EI")[:],
    ]),
  )
  @test.assert_eq(
    pdf_content_read_inline_image(
      lzw_with_decode_parms,
      None,
      PdfDictionary([]),
    ),
    Op_InlineImage(
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(1)),
        (wbtest_content_name("/CS"), PdfNameObject(wbtest_content_name("/G"))),
        (wbtest_content_name("/BPC"), PdfInteger(8)),
      ]),
      None,
      @ascii.encode("A"),
    ),
  )
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
    None,
    PdfDictionary([]),
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
  wbtest_assert_known_content_none("d", [PdfInteger(0)])
  wbtest_assert_known_content_none("d", [PdfNameObject(name), PdfInteger(0)])
  let bad_dash : Result[PdfContentOp?, Error] = try? pdf_content_parse_known_section(
    [PdfArray([PdfNameObject(name)]), PdfInteger(0)],
    @ascii.encode("d"),
  )
  guard bad_dash is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
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
  wbtest_assert_known_content_none("TJ", [PdfInteger(1)])
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
  wbtest_assert_known_content_some(
    "SC",
    [PdfNameObject(name)],
    Op_SC([0.0, 0.0, 0.0]),
  )
  wbtest_assert_known_content_some(
    "sc",
    [PdfNameObject(name)],
    Op_sc([0.0, 0.0, 0.0]),
  )
  wbtest_assert_known_content_some(
    "SCN",
    [PdfNameObject(name), PdfNameObject(wbtest_content_name("/Pattern"))],
    Op_SCNName(wbtest_content_name("/Pattern"), [0.0, 0.0, 0.0]),
  )
  wbtest_assert_known_content_some(
    "scn",
    [PdfNameObject(name), PdfNameObject(wbtest_content_name("/Pattern"))],
    Op_scnName(wbtest_content_name("/Pattern"), [0.0, 0.0, 0.0]),
  )
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
  let bad_png_predictor : Result[Int, Error] = try? pdf_encode_png_predictor_value(
    5,
    @ascii.encode("x")[:],
    0,
    0,
    1,
    1,
  )
  guard bad_png_predictor is Err(PdfError::PredictorNotSupported(5)) else {
    fail("expected PredictorNotSupported")
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

  let prefix_encoded = wbtest_lzw_codes([65, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(prefix_encoded[:]),
    (@ascii.encode("A"), prefix_encoded.length()),
  )
  let eod_encoded = wbtest_lzw_codes([257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(eod_encoded[:]),
    (Bytes::new(0), eod_encoded.length()),
  )
  let clear_eod_encoded = wbtest_lzw_codes([256, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(clear_eod_encoded[:]),
    (Bytes::new(0), clear_eod_encoded.length()),
  )
  let exact_byte_encoded = wbtest_lzw_codes(
    [65, 66, 67, 68, 69, 70, 71, 257],
    1,
  )
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(exact_byte_encoded[:]),
    (@ascii.encode("ABCDEFG"), exact_byte_encoded.length()),
  )
  let clear_restart_encoded = wbtest_lzw_codes([65, 256, 66, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(clear_restart_encoded[:]),
    (@ascii.encode("AB"), clear_restart_encoded.length()),
  )
  let clear_then_eod_encoded = wbtest_lzw_codes([65, 256, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(clear_then_eod_encoded[:]),
    (@ascii.encode("A"), clear_then_eod_encoded.length()),
  )
  let clear_then_eof : Result[(PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    wbtest_lzw_codes([65, 256], 1)[:],
  )
  guard clear_then_eof is Err(PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }
  let repeated_previous_encoded = wbtest_lzw_codes([65, 258, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(repeated_previous_encoded[:]),
    (@ascii.encode("AAA"), repeated_previous_encoded.length()),
  )
  let bump_codes : Array[Int] = [256]
  for _ in 0..<255 {
    bump_codes.push(65)
  }
  bump_codes.push(257)
  let bump_encoded = wbtest_lzw_codes(bump_codes[:], 0)
  let bump_result : Result[(PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    bump_encoded[:],
  )
  guard bump_result is Err(PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }
  let bad_forward_code : Result[(PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    wbtest_lzw_codes([65, 300], 1)[:],
  )
  guard bad_forward_code is Err(PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }
  let missing_eod : Result[(PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    wbtest_lzw_codes([65], 1)[:],
  )
  guard missing_eod is Err(PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }
  let empty_prefix : Result[(PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    Bytes::new(0)[:],
  )
  guard empty_prefix is Err(PdfError::InvalidLZWData) else {
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
  let peek_reader = FlateBitReader::new(
    try! pdf_bytes_of_int_array([0xAC, 0x03])[:],
  )
  @test.assert_eq(peek_reader.peek_bits(-1), None)
  @test.assert_eq(peek_reader.peek_bits(4), Some(12))
  @test.assert_eq(peek_reader.peek_bits(12), Some(0x03AC))
  @test.assert_eq(peek_reader.peek_bits(20), None)
  @test.assert_eq(try! peek_reader.read_bits(4), 12)
  @test.assert_eq(pdf_flate_bit_mask(16), 65535)
  @test.assert_eq(pdf_flate_bit_mask(17), 131071)
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
  let (length_code, length_width) = pdf_flate_fixed_literal_code(280)
  let expected_length_code = 192
  @test.assert_eq(length_code, expected_length_code.reinterpret_as_uint())
  @test.assert_eq(length_width, 8)
  let literal_table_a = pdf_flate_fixed_literal_table()
  let literal_table_b = pdf_flate_fixed_literal_table()
  let distance_table_a = pdf_flate_fixed_distance_table()
  let distance_table_b = pdf_flate_fixed_distance_table()
  @test.assert_eq(literal_table_a.max_bits, 9)
  @test.assert_eq(distance_table_a.max_bits, 5)
  @test.assert_eq(
    physical_equal(literal_table_a.sym, literal_table_b.sym),
    true,
  )
  @test.assert_eq(
    physical_equal(distance_table_a.sym, distance_table_b.sym),
    true,
  )
  let bad_flate_length : Result[(Int, Int, Int), Error] = try? pdf_flate_length_code(
    259,
  )
  guard bad_flate_length is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let bad_flate_distance : Result[(Int, Int, Int), Error] = try? pdf_flate_distance_code(
    0,
  )
  guard bad_flate_distance is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let shadowed_match = @ascii.encode("ABCDEFGHIJABCXABCDEFGHIJ")
  let last_by_prefix : Array[Int] = Array::make(65536, -1)
  let previous_by_position : Array[Int] = Array::make(
    shadowed_match.length(),
    -1,
  )
  for index in 0..<14 {
    pdf_flate_remember_match_prefix(
      last_by_prefix,
      previous_by_position,
      shadowed_match[:],
      index,
    )
  }
  let (shadowed_length, shadowed_distance) = pdf_flate_best_previous_match(
    shadowed_match[:],
    last_by_prefix[:],
    previous_by_position[:],
    14,
    64,
  )
  @test.assert_eq(shadowed_length, 10)
  @test.assert_eq(shadowed_distance, 14)
  let deep_phrase = @ascii.encode("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
  let deep_match_data : Array[Byte] = []
  for byte in deep_phrase[:] {
    deep_match_data.push(byte)
  }
  for index in 0..<20 {
    deep_match_data.push(65)
    deep_match_data.push(66)
    deep_match_data.push((33 + index).to_byte())
  }
  let deep_match_position = deep_match_data.length()
  for byte in deep_phrase[:] {
    deep_match_data.push(byte)
  }
  let deep_match_bytes = Bytes::from_array(deep_match_data)
  let deep_last_by_prefix : Array[Int] = Array::make(65536, -1)
  let deep_previous_by_position : Array[Int] = Array::make(
    deep_match_bytes.length(),
    -1,
  )
  for index in 0..<deep_match_position {
    pdf_flate_remember_match_prefix(
      deep_last_by_prefix,
      deep_previous_by_position,
      deep_match_bytes[:],
      index,
    )
  }
  let (shallow_length, _) = pdf_flate_best_previous_match(
    deep_match_bytes[:],
    deep_last_by_prefix[:],
    deep_previous_by_position[:],
    deep_match_position,
    8,
  )
  let (deep_length, deep_distance) = pdf_flate_best_previous_match(
    deep_match_bytes[:],
    deep_last_by_prefix[:],
    deep_previous_by_position[:],
    deep_match_position,
    64,
  )
  @test.assert_eq(shallow_length < 3, true)
  @test.assert_eq(deep_length, deep_phrase.length())
  @test.assert_eq(deep_distance, deep_match_position)
  @test.assert_eq(pdf_flate_max_probes_for_level(1), 8)
  @test.assert_eq(pdf_flate_max_probes_for_level(3), 16)
  @test.assert_eq(pdf_flate_max_probes_for_level(6), 64)
  @test.assert_eq(pdf_flate_max_probes_for_level(8), 128)
  @test.assert_eq(pdf_flate_max_probes_for_level(9), 256)
  @test.assert_eq(
    try! pdf_flate_decode_view_prefix(Bytes::new(0)[:]),
    (Bytes::new(0), 0),
  )
  let short_prefix : Result[(PdfBytes, Int), Error] = try? pdf_flate_decode_view_prefix(
    try! pdf_bytes_of_int_array([0x78])[:],
  )
  guard short_prefix is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let bad_prefix_header : Result[(PdfBytes, Int), Error] = try? pdf_flate_decode_view_prefix(
    try! pdf_bytes_of_int_array([0, 0, 0, 0, 0, 0])[:],
  )
  guard bad_prefix_header is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let truncated_prefix_adler : Result[(PdfBytes, Int), Error] = try? pdf_flate_decode_view_prefix(
    try! pdf_bytes_of_int_array([0x78, 0x01, 0x01, 0, 0, 0xFF, 0xFF])[:],
  )
  guard truncated_prefix_adler is Err(PdfError::InvalidFlateData) else {
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
test "private flate dynamic encoder helpers cover RLE and guards" {
  @test.assert_eq(pdf_flate_huffman_code_lengths([0, 9, 0], 15), [0, 1, 0])
  let no_frequency : Result[Array[Int], Error] = try? pdf_flate_huffman_code_lengths(
    [0, 0],
    15,
  )
  guard no_frequency is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData for empty huffman frequencies")
  }
  let negative_frequency : Result[Array[Int], Error] = try? pdf_flate_huffman_code_lengths(
    [-1],
    15,
  )
  guard negative_frequency is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData for negative huffman frequency")
  }
  let too_deep : Result[Array[Int], Error] = try? pdf_flate_huffman_code_lengths(
    [1, 1, 1],
    1,
  )
  guard too_deep is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData for over-deep huffman tree")
  }
  @test.assert_eq(pdf_flate_canonical_codes([1, 2, 2]), [0, 2, 3])
  @test.assert_eq(pdf_flate_last_nonzero_length([0, 0]), -1)
  @test.assert_eq(pdf_flate_last_nonzero_length([0, 3, 0]), 1)
  @test.assert_eq(pdf_flate_trim_length_count([0, 0, 2, 0], 2), 3)
  @test.assert_eq(pdf_flate_trim_length_count([0, 0], 4), 4)

  let zero_tokens = pdf_flate_code_length_tokens(Array::make(150, 0)[:])
  @test.assert_eq(zero_tokens.length(), 2)
  @test.assert_eq(zero_tokens[0].symbol, 18)
  @test.assert_eq(zero_tokens[0].extra, 127)
  @test.assert_eq(zero_tokens[0].extra_width, 7)
  @test.assert_eq(zero_tokens[1].symbol, 18)
  @test.assert_eq(zero_tokens[1].extra, 1)
  let repeat_tokens = pdf_flate_code_length_tokens([5, 5, 5, 5, 5, 5, 5, 5])
  @test.assert_eq(repeat_tokens.length(), 3)
  @test.assert_eq(repeat_tokens[0].symbol, 5)
  @test.assert_eq(repeat_tokens[1].symbol, 16)
  @test.assert_eq(repeat_tokens[1].extra, 3)
  @test.assert_eq(repeat_tokens[2].symbol, 5)
  @test.assert_eq(pdf_flate_code_length_frequencies(repeat_tokens[:])[16], 1)
  let order = pdf_flate_code_length_order()
  @test.assert_eq(order[0], 16)
  @test.assert_eq(pdf_flate_code_length_order_count(Array::make(19, 0)[:]), 4)
  let order_lengths = Array::make(19, 0)
  order_lengths[15] = 1
  @test.assert_eq(pdf_flate_code_length_order_count(order_lengths[:]), 19)

  let literal_tokens : Array[PdfFlateToken] = [PdfFlateLiteral(65)]
  let (literal_frequencies, distance_frequencies) = try! pdf_flate_count_dynamic_frequencies(
    literal_tokens[:],
  )
  @test.assert_eq(literal_frequencies[65], 1)
  @test.assert_eq(literal_frequencies[256], 1)
  @test.assert_eq(distance_frequencies[0], 1)
  let match_tokens : Array[PdfFlateToken] = [PdfFlateLengthDistance(3, 1)]
  let (match_frequencies, match_distance_frequencies) = try! pdf_flate_count_dynamic_frequencies(
    match_tokens[:],
  )
  @test.assert_eq(match_frequencies[257], 1)
  @test.assert_eq(match_distance_frequencies[0], 1)
  let data = @ascii.encode("ABCDABCDABCD")
  let tokens = pdf_flate_match_tokens(data[:], 64)
  guard tokens[4] is PdfFlateLengthDistance(length, distance) else {
    fail("expected a length-distance token")
  }
  @test.assert_eq(length >= 3, true)
  @test.assert_eq(distance, 4)

  let output : Array[Byte] = []
  let writer = FlateBitWriter::new(output)
  let missing_symbol : Result[Unit, Error] = try? pdf_flate_write_canonical_symbol(
    writer,
    0,
    [0],
    [0],
  )
  guard missing_symbol is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData for missing canonical symbol")
  }
  let empty_dynamic : Result[Unit, Error] = try? pdf_flate_push_dynamic_match_block(
    [],
    Bytes::new(0)[:],
    true,
    64,
  )
  guard empty_dynamic is Err(PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData for empty dynamic block")
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

  let wrapped = try! pdf_bytes_of_int_array([153, 170, 0, 255, 136])
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(
      wrapped[1:2],
      Some(1),
      Some([1.0, 0.0]),
    ),
    try! pdf_bytes_of_int_array([85]),
  )
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(
      wrapped[2:4],
      Some(8),
      Some([1.0, 0.0]),
    ),
    try! pdf_bytes_of_int_array([1, 0]),
  )
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(
      wrapped[2:4],
      Some(2),
      Some([1.0, 0.0]),
    ),
    try! pdf_bytes_of_int_array([0, 255]),
  )
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(wrapped[2:4], Some(8), None),
    try! pdf_bytes_of_int_array([0, 255]),
  )
  @test.assert_eq(
    try! pdf_image_apply_decode_borrowed(
      wrapped[2:4],
      Some(8),
      Some([0.0, 1.0]),
    ),
    try! pdf_bytes_of_int_array([0, 255]),
  )
  let borrowed_missing_bpc : Result[PdfBytes, Error] = try? pdf_image_apply_decode_borrowed(
    wrapped[2:4],
    None,
    Some([1.0, 0.0]),
  )
  guard borrowed_missing_bpc is Err(PdfError::FilterExpected) else {
    fail("expected borrowed missing bpc for non-identity decode")
  }

  let doc = pdf_document_empty()
  let rgb_wrapped = try! pdf_bytes_of_int_array([9, 1, 2, 3, 4, 5, 6, 9])
  @test.assert_eq(
    doc.pdf_image_raw_colour_space_as_rgb24(
      2,
      1,
      PdfDeviceRGB,
      Some(8),
      rgb_wrapped[1:7],
    ),
    try! pdf_bytes_of_int_array([1, 2, 3, 4, 5, 6]),
  )
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
  let unsupported2 : Result[PdfBytes, Error] = try? doc.pdf_image_raw_colour_space_as_rgb24(
    1,
    1,
    unsupported_indexed,
    Some(2),
    sample[:],
  )
  guard unsupported2 is Err(PdfError::FilterExpected) else {
    fail("expected unsupported indexed 2bpp base")
  }
  let unsupported1 : Result[PdfBytes, Error] = try? doc.pdf_image_raw_colour_space_as_rgb24(
    1,
    1,
    unsupported_indexed,
    Some(1),
    sample[:],
  )
  guard unsupported1 is Err(PdfError::FilterExpected) else {
    fail("expected unsupported indexed 1bpp base")
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

  let invalid_bfrange_entries : Array[(Int, PdfBytes)] = []
  guard pdf_text_append_tounicode_bfrange_line(
      invalid_bfrange_entries,
      @ascii.encode("<02><01>[")[:],
    )
    is None else {
    fail("expected invalid bfrange line")
  }
  guard pdf_text_append_tounicode_bfrange_line(
      invalid_bfrange_entries,
      @ascii.encode("<01>[")[:],
    )
    is None else {
    fail("expected incomplete bfrange line")
  }
  guard pdf_text_append_tounicode_bfrange_line(
      invalid_bfrange_entries,
      @ascii.encode("<01><02><FF>")[:],
    )
    is None else {
    fail("expected overflow bfrange line")
  }
  guard pdf_text_append_tounicode_bfrange_line(
      invalid_bfrange_entries,
      @ascii.encode("<01><02>plain")[:],
    )
    is None else {
    fail("expected missing unicode bfrange line")
  }
  @test.assert_eq(invalid_bfrange_entries, [])
  let pending : PdfTextCMapBFRangeArray = { first: 1, last: 2, unicodes: [] }
  let pending_entries : Array[(Int, PdfBytes)] = []
  let append_result = pdf_text_append_pending_bfrange_array(
    pending_entries,
    pending,
    @ascii.encode("<0041>]")[:],
  )
  guard append_result is PdfTextCMapBFRangeArrayClosed(rest) else {
    fail("expected closed bfrange array")
  }
  @test.assert_eq(rest.length(), 0)
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
test "private external CMap helpers cover malformed and compact sections" {
  let empty_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [],
    usecmap: None,
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(PdfExternalCMap(1, empty_parsed).uses_two_byte_codes(), false)
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      empty_parsed,
      wbtest_text_bytes([1, 2])[:],
    ),
    [1, 2],
  )
  let identity_base_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [],
    usecmap: Some(wbtest_text_name("/Identity-H")),
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(
    PdfExternalCMap(4, identity_base_parsed).uses_two_byte_codes(),
    true,
  )
  @test.assert_eq(
    PdfExternalCMap(4, {
      ..identity_base_parsed,
      usecmap: Some(wbtest_text_name("/Identity-V")),
    }).uses_two_byte_codes(),
    true,
  )
  let ucs2_base_parsed : PdfParsedCMap = {
    ..identity_base_parsed,
    usecmap: Some(wbtest_text_name("/Adobe-Japan1-UCS2-H")),
  }
  @test.assert_eq(
    PdfExternalCMap(4, ucs2_base_parsed).uses_two_byte_codes(),
    true,
  )
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      ucs2_base_parsed,
      wbtest_text_bytes([0x12, 0x34])[:],
    ),
    [0x1234],
  )
  let truncated_ucs2 : Result[Array[Int], Error] = try? pdf_text_parsed_cmap_charcodes_of_text(
    ucs2_base_parsed,
    wbtest_text_bytes([0x12])[:],
  )
  guard truncated_ucs2 is Err(_) else {
    fail("expected truncated external UCS2 UseCMap text to raise")
  }
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      identity_base_parsed,
      wbtest_text_bytes([1, 2])[:],
    ),
    [0x0102],
  )
  let odd_identity : Result[Array[Int], Error] = try? pdf_text_parsed_cmap_charcodes_of_text(
    identity_base_parsed,
    wbtest_text_bytes([1])[:],
  )
  guard odd_identity is Err(_) else {
    fail("expected odd identity CMap text to raise")
  }
  let mixed_identity_base_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [{ length: 1, first: 0x00, last: 0x7F }],
    usecmap: Some(wbtest_text_name("/Identity-H")),
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      mixed_identity_base_parsed,
      wbtest_text_bytes([0x00, 0x41])[:],
    ),
    [0x0041],
  )
  let two_byte_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [{ length: 2, first: 0x0000, last: 0xFFFF }],
    usecmap: None,
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(
    PdfExternalCMap(2, two_byte_parsed).uses_two_byte_codes(),
    true,
  )
  let mixed_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [
      { length: 2, first: 0x4100, last: 0x41FF },
      { length: 1, first: 0x00, last: 0x7F },
    ],
    usecmap: None,
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(PdfExternalCMap(3, mixed_parsed).uses_two_byte_codes(), false)
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      mixed_parsed,
      wbtest_text_bytes([0x41, 0x00])[:],
    ),
    [0x4100],
  )
  let composed = pdf_text_compose_parsed_cmap(
    {
      map: [(1, wbtest_text_bytes([0x00, 0x41]))],
      cid_map: [(1, 10)],
      notdef_map: [(1, 20)],
      codespaces: [{ length: 1, first: 1, last: 1 }],
      usecmap: Some(wbtest_text_name("/Identity-V")),
      wmode: Some(1),
      cmap_name: Some(wbtest_text_name("/Derived")),
      cmap_type: Some(2),
      cid_system_info: Some({
        registry: wbtest_text_bytes([69]),
        ordering: wbtest_text_bytes([70]),
        supplement: 5,
      }),
    },
    {
      map: [
        (1, wbtest_text_bytes([0x00, 0x42])),
        (2, wbtest_text_bytes([0x00, 0x43])),
        (2, wbtest_text_bytes([0x00, 0x44])),
      ],
      cid_map: [(1, 11), (2, 12), (2, 13)],
      notdef_map: [(1, 21), (2, 22), (2, 23)],
      codespaces: [{ length: 2, first: 0, last: 0xFFFF }],
      usecmap: Some(wbtest_text_name("/Identity-H")),
      wmode: Some(0),
      cmap_name: Some(wbtest_text_name("/Base")),
      cmap_type: Some(1),
      cid_system_info: Some({
        registry: wbtest_text_bytes([65]),
        ordering: wbtest_text_bytes([66]),
        supplement: 3,
      }),
    },
  )
  @test.assert_eq(composed.map, [
    (1, wbtest_text_bytes([0x00, 0x41])),
    (2, wbtest_text_bytes([0x00, 0x43])),
  ])
  @test.assert_eq(composed.cid_map, [(1, 10), (2, 12)])
  @test.assert_eq(composed.notdef_map, [(1, 20), (2, 22)])
  @test.assert_eq(composed.codespaces, [
    { length: 1, first: 1, last: 1 },
    { length: 2, first: 0, last: 0xFFFF },
  ])
  @test.assert_eq(composed.usecmap, Some(wbtest_text_name("/Identity-V")))
  @test.assert_eq(composed.wmode, Some(1))
  @test.assert_eq(composed.cmap_name, Some(wbtest_text_name("/Derived")))
  @test.assert_eq(composed.cmap_type, Some(2))
  @test.assert_eq(
    composed.cid_system_info,
    Some({
      registry: wbtest_text_bytes([69]),
      ordering: wbtest_text_bytes([70]),
      supplement: 5,
    }),
  )
  let inherited_metadata = pdf_text_compose_parsed_cmap(empty_parsed, {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [],
    usecmap: Some(wbtest_text_name("/Identity-H")),
    wmode: Some(0),
    cmap_name: Some(wbtest_text_name("/Inherited")),
    cmap_type: Some(1),
    cid_system_info: Some({
      registry: wbtest_text_bytes([67]),
      ordering: wbtest_text_bytes([68]),
      supplement: 4,
    }),
  })
  @test.assert_eq(
    inherited_metadata.usecmap,
    Some(wbtest_text_name("/Identity-H")),
  )
  @test.assert_eq(inherited_metadata.wmode, Some(0))
  @test.assert_eq(
    inherited_metadata.cmap_name,
    Some(wbtest_text_name("/Inherited")),
  )
  @test.assert_eq(inherited_metadata.cmap_type, Some(1))
  @test.assert_eq(
    inherited_metadata.cid_system_info,
    Some({
      registry: wbtest_text_bytes([67]),
      ordering: wbtest_text_bytes([68]),
      supplement: 4,
    }),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_ascii_int_at(@ascii.encode(" 7x")[:], 0),
    Some((7, 2)),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_ascii_int_at(@ascii.encode(" +7x")[:], 0),
    None,
  )
  @test.assert_eq(
    pdf_text_parse_cmap_ascii_int_at(@ascii.encode(" +x")[:], 0),
    None,
  )
  let cidchar_entries : Array[(Int, Int)] = []
  pdf_text_push_cmap_cidchar_entries(
    cidchar_entries,
    @ascii.encode("<> 1 <41> 7 <42> +")[:],
  )
  @test.assert_eq(cidchar_entries, [(0x41, 7)])
  pdf_text_push_cmap_cidchar_entries(
    cidchar_entries,
    @ascii.encode("<43> +7")[:],
  )
  @test.assert_eq(cidchar_entries, [(0x41, 7)])

  let cidrange_entries : Array[(Int, Int)] = []
  pdf_text_push_cmap_cidrange_entries(
    cidrange_entries,
    @ascii.encode("<02><01> 5")[:],
  )
  @test.assert_eq(cidrange_entries, [])
  pdf_text_push_cmap_cidrange_entries(
    cidrange_entries,
    @ascii.encode("<10><11>")[:],
  )
  @test.assert_eq(cidrange_entries, [])
  pdf_text_push_cmap_cidrange_entries(
    cidrange_entries,
    @ascii.encode("<12> 8")[:],
  )
  @test.assert_eq(cidrange_entries, [])

  let codespaces : Array[PdfCMapCodeSpace] = []
  pdf_text_push_cmap_codespace_entries(
    codespaces,
    @ascii.encode("<00><FFFF>")[:],
  )
  @test.assert_eq(codespaces, [])
  pdf_text_push_cmap_codespace_entries(codespaces, @ascii.encode("<00>")[:])
  @test.assert_eq(codespaces, [])

  @test.assert_eq(
    pdf_text_parse_cmap_cids(
      @ascii.encode("1 begin\n" + "cidchar\n" + "<41> 7\n" + "endcidchar\n")[:],
    ),
    Some([(0x41, 7)]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_cids(
      @ascii.encode(
        "1 begincidchar <41> 7 endcidchar\n" +
        "1 begin\n" +
        "cidchar\n" +
        "<42> 8\n" +
        "endcidchar\n",
      )[:],
    ),
    Some([(0x41, 7), (0x42, 8)]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_notdefs(
      @ascii.encode(
        "1 beginnotdefchar <20> 0 endnotdefchar\n" +
        "1 begin\n" +
        "notdefrange\n" +
        "<30><31> 5\n" +
        "endnotdefrange\n",
      )[:],
    ),
    Some([(0x20, 0), (0x30, 5), (0x31, 6)]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_notdefs(
      @ascii.encode(
        "1 begin\n" + "notdefchar\n" + "<20> 0\n" + "endnotdefchar\n",
      )[:],
    ),
    Some([(0x20, 0)]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_codespaces(
      @ascii.encode(
        "1 begin\n" + "codespacerange\n" + "<00><7F>\n" + "endcodespacerange\n",
      )[:],
    ),
    Some([{ length: 1, first: 0x00, last: 0x7F }]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_codespaces(
      @ascii.encode(
        "1 begincodespacerange <00><7F> endcodespacerange\n" +
        "1 begin\n" +
        "codespacerange\n" +
        "<8100><81FF>\n" +
        "endcodespacerange\n",
      )[:],
    ),
    Some([
      { length: 1, first: 0x00, last: 0x7F },
      { length: 2, first: 0x8100, last: 0x81FF },
    ]),
  )

  let fallback_doc = pdf_document_empty()
  let descendant = pdf_dictionary([
    (
      wbtest_text_name("/CIDSystemInfo"),
      pdf_dictionary([
        (wbtest_text_name("/Registry"), PdfString(wbtest_text_bytes([82]))),
        (wbtest_text_name("/Ordering"), PdfString(wbtest_text_bytes([79]))),
        (wbtest_text_name("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      wbtest_text_name("/BaseFont"),
      PdfNameObject(wbtest_text_name("/Descendant")),
    ),
    (wbtest_text_name("/FontDescriptor"), pdf_dictionary([])),
  ])
  fallback_doc.add_object_given_number(4, descendant)
  let bad_cmap = pdf_stream(
    pdf_dictionary([
      (
        wbtest_text_name("/Filter"),
        PdfNameObject(wbtest_text_name("/NoSuchFilter")),
      ),
    ]),
    StreamGot(wbtest_text_bytes([1])),
  )
  fallback_doc.add_object_given_number(5, bad_cmap)
  let font = pdf_dictionary([
    (wbtest_text_name("/BaseFont"), PdfNameObject(wbtest_text_name("/Top"))),
    (wbtest_text_name("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (wbtest_text_name("/Encoding"), PdfIndirect(5)),
  ])
  guard (try! fallback_doc.read_cidkeyed_font(font)).encoding is PdfCMap(5) else {
    fail("expected unparsed fallback CMap")
  }
}

///|
test "private direct Unicode predefined CMap helpers cover malformed scalars" {
  let utf8_name = wbtest_text_name("/UniJIS-UTF8-H")
  @test.assert_eq(
    pdf_text_predefined_cmap_charcodes_of_text(
      utf8_name,
      wbtest_text_bytes([0xC2, 0xA2])[:],
    ),
    [0xC2A2],
  )
  @test.assert_eq(pdf_text_predefined_utf8_charcode(0x41), Some(0x41))
  @test.assert_eq(pdf_text_predefined_utf8_charcode(0xA2), Some(0xC2A2))
  @test.assert_eq(pdf_text_predefined_utf8_charcode(0xD800), None)
  let truncated_utf8 : Result[Array[Int], Error] = try? pdf_text_predefined_cmap_charcodes_of_text(
    utf8_name,
    wbtest_text_bytes([0xC2])[:],
  )
  guard truncated_utf8 is Err(_) else {
    fail("expected truncated UTF8 predefined CMap text to raise")
  }
  let invalid_lead_utf8 : Result[Array[Int], Error] = try? pdf_text_predefined_cmap_charcodes_of_text(
    utf8_name,
    wbtest_text_bytes([0xFF])[:],
  )
  guard invalid_lead_utf8 is Err(_) else {
    fail("expected invalid leading UTF8 predefined CMap text to raise")
  }
  let invalid_continuation_utf8 : Result[Array[Int], Error] = try? pdf_text_predefined_cmap_charcodes_of_text(
    utf8_name,
    wbtest_text_bytes([0xC2, 0x41])[:],
  )
  guard invalid_continuation_utf8 is Err(_) else {
    fail("expected invalid UTF8 predefined CMap text to raise")
  }

  @test.assert_eq(pdf_text_predefined_utf16_codepoints(0xD800), None)
  @test.assert_eq(
    pdf_text_predefined_utf16_codepoints(
      pdf_text_pack_four_bytes(0xD8, 0x00, 0x00, 0x41),
    ),
    None,
  )
  @test.assert_eq(pdf_text_predefined_utf16_codepoints(0x123456), None)
  let low_surrogate_utf16 : Result[Array[Int], Error] = try? pdf_text_predefined_cmap_charcodes_of_text(
    wbtest_text_name("/UniJIS-UTF16-H"),
    wbtest_text_bytes([0xDC, 0x00])[:],
  )
  guard low_surrogate_utf16 is Err(_) else {
    fail("expected low-surrogate UTF16 predefined CMap text to raise")
  }

  @test.assert_eq(pdf_text_predefined_utf32_codepoints(0xD800), None)
  @test.assert_eq(pdf_text_predefined_utf32_charcode(0x110000), None)
  @test.assert_eq(
    pdf_text_predefined_direct_unicode_charcode(
      wbtest_text_name("/UniJIS-UCS2-H"),
      0x1D11E,
    ),
    None,
  )

  let composite : PdfCompositeCIDFont = {
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
  }
  let two_byte_font : PdfFont = PdfFontCIDKeyed({
    basefont: wbtest_text_name("/Top"),
    composite,
    encoding: PdfPredefinedCMap(wbtest_text_name("/Identity-H")),
  })
  @test.assert_eq(
    two_byte_font.pdf_text_fixed_or_single_byte_charcodes_of_text(
      wbtest_text_bytes([0x00, 0x41])[:],
    ),
    [0x41],
  )
  let odd_fixed : Result[Array[Int], Error] = try? two_byte_font.pdf_text_fixed_or_single_byte_charcodes_of_text(
    wbtest_text_bytes([0])[:],
  )
  guard odd_fixed is Err(_) else {
    fail("expected odd fixed-width CID text to raise")
  }
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
  let bad_deferred_result : Result[PdfParsedCMap, Error] = try? helper_doc.parse_cmap(
    bad_deferred,
  )
  guard bad_deferred_result is Err(_) else {
    fail("expected malformed deferred stream CMap to raise")
  }
  let bad_filter = pdf_stream(
    PdfDictionary([(wbtest_text_name("/Filter"), PdfInteger(1))]),
    StreamGot(@ascii.encode("x")),
  )
  let bad_filter_result : Result[PdfParsedCMap, Error] = try? helper_doc.parse_cmap(
    bad_filter,
  )
  guard bad_filter_result is Err(_) else {
    fail("expected malformed filter CMap to raise")
  }
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
  let unsupported_filter_result : Result[PdfParsedCMap, Error] = try? helper_doc.parse_cmap(
    unsupported_filter,
  )
  guard unsupported_filter_result is Err(_) else {
    fail("expected unsupported filter CMap to raise")
  }
  let non_stream_result : Result[PdfParsedCMap, Error] = try? helper_doc.parse_cmap(
    PdfInteger(1),
  )
  guard non_stream_result is Err(_) else {
    fail("expected non-stream CMap to raise")
  }

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

  let basic_latin_entries : Array[(String, Int)] = [
    ("/A", 65),
    ("/B", 66),
    ("/C", 67),
    ("/D", 68),
    ("/E", 69),
    ("/F", 70),
    ("/G", 71),
    ("/H", 72),
    ("/I", 73),
    ("/J", 74),
    ("/K", 75),
    ("/L", 76),
    ("/M", 77),
    ("/N", 78),
    ("/O", 79),
    ("/P", 80),
    ("/Q", 81),
    ("/R", 82),
    ("/S", 83),
    ("/T", 84),
    ("/U", 85),
    ("/V", 86),
    ("/W", 87),
    ("/X", 88),
    ("/Y", 89),
    ("/Z", 90),
    ("/a", 97),
    ("/b", 98),
    ("/c", 99),
    ("/controlACK", 6),
    ("/controlBEL", 7),
    ("/controlBS", 8),
    ("/controlCAN", 24),
    ("/controlDC1", 17),
    ("/controlDC2", 18),
    ("/controlDC3", 19),
    ("/controlDC4", 20),
    ("/controlDEL", 127),
    ("/controlDLE", 16),
    ("/controlEM", 25),
    ("/controlENQ", 5),
    ("/controlEOT", 4),
    ("/controlESC", 27),
    ("/controlETB", 23),
    ("/controlETX", 3),
    ("/controlFS", 28),
    ("/controlGS", 29),
    ("/controlNAK", 21),
    ("/controlRS", 30),
    ("/controlSI", 15),
    ("/controlSO", 14),
    ("/controlSOT", 2),
    ("/controlSTX", 1),
    ("/controlSUB", 26),
    ("/controlSYN", 22),
    ("/controlUS", 31),
    ("/controlVT", 11),
    ("/d", 100),
    ("/e", 101),
    ("/f", 102),
    ("/g", 103),
    ("/h", 104),
    ("/i", 105),
    ("/j", 106),
    ("/k", 107),
    ("/l", 108),
    ("/m", 109),
    ("/n", 110),
    ("/o", 111),
    ("/p", 112),
    ("/q", 113),
    ("/r", 114),
    ("/s", 115),
    ("/spacehackarabic", 32),
    ("/t", 116),
    ("/u", 117),
    ("/v", 118),
    ("/verticalbar", 124),
    ("/w", 119),
    ("/x", 120),
    ("/y", 121),
    ("/z", 122),
  ]
  for entry in basic_latin_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_basic_latin_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_basic_latin_glyphname(wbtest_text_name("/not-basic")),
    None,
  )
  let cjk_symbol_entries : Array[(String, Int)] = [
    ("/anglebracketleft", 0x3008),
    ("/anglebracketright", 0x3009),
    ("/blacklenticularbracketleft", 0x3010),
    ("/blacklenticularbracketright", 0x3011),
    ("/circlepostalmark", 0x3036),
    ("/cornerbracketleft", 0x300C),
    ("/cornerbracketright", 0x300D),
    ("/dblanglebracketleft", 0x300A),
    ("/dblanglebracketright", 0x300B),
    ("/dittomark", 0x3003),
    ("/eighthangzhou", 0x3028),
    ("/fivehangzhou", 0x3025),
    ("/fourhangzhou", 0x3024),
    ("/getamark", 0x3013),
    ("/ideographicclose", 0x3006),
    ("/ideographiccomma", 0x3001),
    ("/ideographiciterationmark", 0x3005),
    ("/ideographicperiod", 0x3002),
    ("/ideographicspace", 0x3000),
    ("/ideographiczero", 0x3007),
    ("/jis", 0x3004),
    ("/ninehangzhou", 0x3029),
    ("/onehangzhou", 0x3021),
    ("/postalmark", 0x3012),
    ("/postalmarkface", 0x3020),
    ("/quotedblprime", 0x301E),
    ("/quotedblprimereversed", 0x301D),
    ("/sevenhangzhou", 0x3027),
    ("/sixhangzhou", 0x3026),
    ("/threehangzhou", 0x3023),
    ("/tortoiseshellbracketleft", 0x3014),
    ("/tortoiseshellbracketright", 0x3015),
    ("/twentyhangzhou", 0x5344),
    ("/twohangzhou", 0x3022),
    ("/wavedash", 0x301C),
    ("/whitecornerbracketleft", 0x300E),
    ("/whitecornerbracketright", 0x300F),
    ("/whitelenticularbracketleft", 0x3016),
    ("/whitelenticularbracketright", 0x3017),
    ("/whitetortoiseshellbracketleft", 0x3018),
    ("/whitetortoiseshellbracketright", 0x3019),
  ]
  for entry in cjk_symbol_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_cjk_symbol_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_cjk_symbol_glyphname(
      wbtest_text_name("/not-cjk-symbol"),
    ),
    None,
  )
  let hiragana_entries : Array[(String, Int)] = [
    ("/ahiragana", 0x3042),
    ("/asmallhiragana", 0x3041),
    ("/bahiragana", 0x3070),
    ("/behiragana", 0x3079),
    ("/bihiragana", 0x3073),
    ("/bohiragana", 0x307C),
    ("/buhiragana", 0x3076),
    ("/dahiragana", 0x3060),
    ("/dehiragana", 0x3067),
    ("/dihiragana", 0x3062),
    ("/dohiragana", 0x3069),
    ("/duhiragana", 0x3065),
    ("/ehiragana", 0x3048),
    ("/esmallhiragana", 0x3047),
    ("/gahiragana", 0x304C),
    ("/gehiragana", 0x3052),
    ("/gihiragana", 0x304E),
    ("/gohiragana", 0x3054),
    ("/guhiragana", 0x3050),
    ("/hahiragana", 0x306F),
    ("/hehiragana", 0x3078),
    ("/hihiragana", 0x3072),
    ("/hohiragana", 0x307B),
    ("/huhiragana", 0x3075),
    ("/ihiragana", 0x3044),
    ("/ismallhiragana", 0x3043),
    ("/iterationhiragana", 0x309D),
    ("/kahiragana", 0x304B),
    ("/kehiragana", 0x3051),
    ("/kihiragana", 0x304D),
    ("/kohiragana", 0x3053),
    ("/kuhiragana", 0x304F),
    ("/mahiragana", 0x307E),
    ("/mehiragana", 0x3081),
    ("/mihiragana", 0x307F),
    ("/mohiragana", 0x3082),
    ("/muhiragana", 0x3080),
    ("/nahiragana", 0x306A),
    ("/nehiragana", 0x306D),
    ("/nhiragana", 0x3093),
    ("/nihiragana", 0x306B),
    ("/nohiragana", 0x306E),
    ("/nuhiragana", 0x306C),
    ("/ohiragana", 0x304A),
    ("/osmallhiragana", 0x3049),
    ("/pahiragana", 0x3071),
    ("/pehiragana", 0x307A),
    ("/pihiragana", 0x3074),
    ("/pohiragana", 0x307D),
    ("/puhiragana", 0x3077),
    ("/rahiragana", 0x3089),
    ("/rehiragana", 0x308C),
    ("/rihiragana", 0x308A),
    ("/rohiragana", 0x308D),
    ("/ruhiragana", 0x308B),
    ("/sahiragana", 0x3055),
    ("/sehiragana", 0x305B),
    ("/semivoicedmarkkana", 0x309C),
    ("/sihiragana", 0x3057),
    ("/sohiragana", 0x305D),
    ("/suhiragana", 0x3059),
    ("/tahiragana", 0x305F),
    ("/tehiragana", 0x3066),
    ("/tihiragana", 0x3061),
    ("/tohiragana", 0x3068),
    ("/tuhiragana", 0x3064),
    ("/tusmallhiragana", 0x3063),
    ("/uhiragana", 0x3046),
    ("/usmallhiragana", 0x3045),
    ("/voicediterationhiragana", 0x309E),
    ("/voicedmarkkana", 0x309B),
    ("/vuhiragana", 0x3094),
    ("/wahiragana", 0x308F),
    ("/wasmallhiragana", 0x308E),
    ("/wehiragana", 0x3091),
    ("/wihiragana", 0x3090),
    ("/wohiragana", 0x3092),
    ("/yahiragana", 0x3084),
    ("/yasmallhiragana", 0x3083),
    ("/yohiragana", 0x3088),
    ("/yosmallhiragana", 0x3087),
    ("/yuhiragana", 0x3086),
    ("/yusmallhiragana", 0x3085),
    ("/zahiragana", 0x3056),
    ("/zehiragana", 0x305C),
    ("/zihiragana", 0x3058),
    ("/zohiragana", 0x305E),
    ("/zuhiragana", 0x305A),
  ]
  for entry in hiragana_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_hiragana_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_hiragana_glyphname(wbtest_text_name("/not-hiragana")),
    None,
  )
  let katakana_entries : Array[(String, Int)] = [
    ("/akatakana", 0x30A2),
    ("/asmallkatakana", 0x30A1),
    ("/bakatakana", 0x30D0),
    ("/bekatakana", 0x30D9),
    ("/bikatakana", 0x30D3),
    ("/bokatakana", 0x30DC),
    ("/bukatakana", 0x30D6),
    ("/dakatakana", 0x30C0),
    ("/dekatakana", 0x30C7),
    ("/dikatakana", 0x30C2),
    ("/dokatakana", 0x30C9),
    ("/dotkatakana", 0x30FB),
    ("/dukatakana", 0x30C5),
    ("/ekatakana", 0x30A8),
    ("/esmallkatakana", 0x30A7),
    ("/gakatakana", 0x30AC),
    ("/gekatakana", 0x30B2),
    ("/gikatakana", 0x30AE),
    ("/gokatakana", 0x30B4),
    ("/gukatakana", 0x30B0),
    ("/hakatakana", 0x30CF),
    ("/hekatakana", 0x30D8),
    ("/hikatakana", 0x30D2),
    ("/hokatakana", 0x30DB),
    ("/hukatakana", 0x30D5),
    ("/ikatakana", 0x30A4),
    ("/ismallkatakana", 0x30A3),
    ("/iterationkatakana", 0x30FD),
    ("/kakatakana", 0x30AB),
    ("/kasmallkatakana", 0x30F5),
    ("/kekatakana", 0x30B1),
    ("/kesmallkatakana", 0x30F6),
    ("/kikatakana", 0x30AD),
    ("/kokatakana", 0x30B3),
    ("/kukatakana", 0x30AF),
    ("/makatakana", 0x30DE),
    ("/mekatakana", 0x30E1),
    ("/mikatakana", 0x30DF),
    ("/mokatakana", 0x30E2),
    ("/mukatakana", 0x30E0),
    ("/nakatakana", 0x30CA),
    ("/nekatakana", 0x30CD),
    ("/nikatakana", 0x30CB),
    ("/nkatakana", 0x30F3),
    ("/nokatakana", 0x30CE),
    ("/nukatakana", 0x30CC),
    ("/okatakana", 0x30AA),
    ("/osmallkatakana", 0x30A9),
    ("/pakatakana", 0x30D1),
    ("/pekatakana", 0x30DA),
    ("/pikatakana", 0x30D4),
    ("/pokatakana", 0x30DD),
    ("/prolongedkana", 0x30FC),
    ("/pukatakana", 0x30D7),
    ("/rakatakana", 0x30E9),
    ("/rekatakana", 0x30EC),
    ("/rikatakana", 0x30EA),
    ("/rokatakana", 0x30ED),
    ("/rukatakana", 0x30EB),
    ("/sakatakana", 0x30B5),
    ("/sekatakana", 0x30BB),
    ("/sikatakana", 0x30B7),
    ("/sokatakana", 0x30BD),
    ("/sukatakana", 0x30B9),
    ("/takatakana", 0x30BF),
    ("/tekatakana", 0x30C6),
    ("/tikatakana", 0x30C1),
    ("/tokatakana", 0x30C8),
    ("/tukatakana", 0x30C4),
    ("/tusmallkatakana", 0x30C3),
    ("/ukatakana", 0x30A6),
    ("/usmallkatakana", 0x30A5),
    ("/vakatakana", 0x30F7),
    ("/vekatakana", 0x30F9),
    ("/vikatakana", 0x30F8),
    ("/voicediterationkatakana", 0x30FE),
    ("/vokatakana", 0x30FA),
    ("/vukatakana", 0x30F4),
    ("/wakatakana", 0x30EF),
    ("/wasmallkatakana", 0x30EE),
    ("/wekatakana", 0x30F1),
    ("/wikatakana", 0x30F0),
    ("/wokatakana", 0x30F2),
    ("/yakatakana", 0x30E4),
    ("/yasmallkatakana", 0x30E3),
    ("/yokatakana", 0x30E8),
    ("/yosmallkatakana", 0x30E7),
    ("/yukatakana", 0x30E6),
    ("/yusmallkatakana", 0x30E5),
    ("/zakatakana", 0x30B6),
    ("/zekatakana", 0x30BC),
    ("/zikatakana", 0x30B8),
    ("/zokatakana", 0x30BE),
    ("/zukatakana", 0x30BA),
  ]
  for entry in katakana_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_katakana_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_katakana_glyphname(wbtest_text_name("/not-katakana")),
    None,
  )
  let bopomofo_entries : Array[(String, Int)] = [
    ("/abopomofo", 0x311A),
    ("/aibopomofo", 0x311E),
    ("/anbopomofo", 0x3122),
    ("/angbopomofo", 0x3124),
    ("/aubopomofo", 0x3120),
    ("/bbopomofo", 0x3105),
    ("/cbopomofo", 0x3118),
    ("/chbopomofo", 0x3114),
    ("/dbopomofo", 0x3109),
    ("/ebopomofo", 0x311C),
    ("/ehbopomofo", 0x311D),
    ("/eibopomofo", 0x311F),
    ("/enbopomofo", 0x3123),
    ("/engbopomofo", 0x3125),
    ("/erbopomofo", 0x3126),
    ("/fbopomofo", 0x3108),
    ("/gbopomofo", 0x310D),
    ("/hbopomofo", 0x310F),
    ("/ibopomofo", 0x3127),
    ("/iubopomofo", 0x3129),
    ("/jbopomofo", 0x3110),
    ("/kbopomofo", 0x310E),
    ("/lbopomofo", 0x310C),
    ("/mbopomofo", 0x3107),
    ("/nbopomofo", 0x310B),
    ("/obopomofo", 0x311B),
    ("/oubopomofo", 0x3121),
    ("/pbopomofo", 0x3106),
    ("/qbopomofo", 0x3111),
    ("/rbopomofo", 0x3116),
    ("/sbopomofo", 0x3119),
    ("/shbopomofo", 0x3115),
    ("/tbopomofo", 0x310A),
    ("/ubopomofo", 0x3128),
    ("/xbopomofo", 0x3112),
    ("/zbopomofo", 0x3117),
    ("/zhbopomofo", 0x3113),
  ]
  for entry in bopomofo_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_bopomofo_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_bopomofo_glyphname(wbtest_text_name("/not-bopomofo")),
    None,
  )
  let hangul_compat_jamo_entries : Array[(String, Int)] = [
    ("/aekorean", 0x3150),
    ("/akorean", 0x314F),
    ("/araeaekorean", 0x318E),
    ("/araeakorean", 0x318D),
    ("/chieuchkorean", 0x314A),
    ("/cieuckorean", 0x3148),
    ("/ekorean", 0x3154),
    ("/eokorean", 0x3153),
    ("/eukorean", 0x3161),
    ("/hangulfiller", 0x3164),
    ("/hieuhkorean", 0x314E),
    ("/ieungkorean", 0x3147),
    ("/ikorean", 0x3163),
    ("/kapyeounmieumkorean", 0x3171),
    ("/kapyeounphieuphkorean", 0x3184),
    ("/kapyeounpieupkorean", 0x3178),
    ("/kapyeounssangpieupkorean", 0x3179),
    ("/khieukhkorean", 0x314B),
    ("/kiyeokkorean", 0x3131),
    ("/kiyeoksioskorean", 0x3133),
    ("/mieumkorean", 0x3141),
    ("/mieumpansioskorean", 0x3170),
    ("/mieumpieupkorean", 0x316E),
    ("/mieumsioskorean", 0x316F),
    ("/nieuncieuckorean", 0x3135),
    ("/nieunhieuhkorean", 0x3136),
    ("/nieunkorean", 0x3134),
    ("/nieunpansioskorean", 0x3168),
    ("/nieunsioskorean", 0x3167),
    ("/nieuntikeutkorean", 0x3166),
    ("/oekorean", 0x315A),
    ("/okorean", 0x3157),
    ("/pansioskorean", 0x317F),
    ("/phieuphkorean", 0x314D),
    ("/pieupcieuckorean", 0x3176),
    ("/pieupkiyeokkorean", 0x3172),
    ("/pieupkorean", 0x3142),
    ("/pieupsioskiyeokkorean", 0x3174),
    ("/pieupsioskorean", 0x3144),
    ("/pieupsiostikeutkorean", 0x3175),
    ("/pieupthieuthkorean", 0x3177),
    ("/pieuptikeutkorean", 0x3173),
    ("/rieulhieuhkorean", 0x3140),
    ("/rieulkiyeokkorean", 0x313A),
    ("/rieulkiyeoksioskorean", 0x3169),
    ("/rieulkorean", 0x3139),
    ("/rieulmieumkorean", 0x313B),
    ("/rieulpansioskorean", 0x316C),
    ("/rieulphieuphkorean", 0x313F),
    ("/rieulpieupkorean", 0x313C),
    ("/rieulpieupsioskorean", 0x316B),
    ("/rieulsioskorean", 0x313D),
    ("/rieulthieuthkorean", 0x313E),
    ("/rieultikeutkorean", 0x316A),
    ("/rieulyeorinhieuhkorean", 0x316D),
    ("/sioscieuckorean", 0x317E),
    ("/sioskiyeokkorean", 0x317A),
    ("/sioskorean", 0x3145),
    ("/siosnieunkorean", 0x317B),
    ("/siospieupkorean", 0x317D),
    ("/siostikeutkorean", 0x317C),
    ("/ssangcieuckorean", 0x3149),
    ("/ssanghieuhkorean", 0x3185),
    ("/ssangieungkorean", 0x3180),
    ("/ssangkiyeokkorean", 0x3132),
    ("/ssangnieunkorean", 0x3165),
    ("/ssangpieupkorean", 0x3143),
    ("/ssangsioskorean", 0x3146),
    ("/ssangtikeutkorean", 0x3138),
    ("/thieuthkorean", 0x314C),
    ("/tikeutkorean", 0x3137),
    ("/ukorean", 0x315C),
    ("/waekorean", 0x3159),
    ("/wakorean", 0x3158),
    ("/wekorean", 0x315E),
    ("/weokorean", 0x315D),
    ("/wikorean", 0x315F),
    ("/yaekorean", 0x3152),
    ("/yakorean", 0x3151),
    ("/yekorean", 0x3156),
    ("/yeokorean", 0x3155),
    ("/yeorinhieuhkorean", 0x3186),
    ("/yesieungkorean", 0x3181),
    ("/yesieungpansioskorean", 0x3183),
    ("/yesieungsioskorean", 0x3182),
    ("/yikorean", 0x3162),
    ("/yoikorean", 0x3189),
    ("/yokorean", 0x315B),
    ("/yoyaekorean", 0x3188),
    ("/yoyakorean", 0x3187),
    ("/yuikorean", 0x318C),
    ("/yukorean", 0x3160),
    ("/yuyekorean", 0x318B),
    ("/yuyeokorean", 0x318A),
  ]
  for entry in hangul_compat_jamo_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_hangul_compat_jamo_glyphname(
        wbtest_text_name(entry.0),
      ),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_hangul_compat_jamo_glyphname(
      wbtest_text_name("/not-hangul-compat-jamo"),
    ),
    None,
  )
  let enclosed_cjk_entries : Array[(String, Int)] = [
    ("/chieuchacirclekorean", 0x3277),
    ("/chieuchaparenkorean", 0x3217),
    ("/chieuchcirclekorean", 0x3269),
    ("/chieuchparenkorean", 0x3209),
    ("/cieucacirclekorean", 0x3276),
    ("/cieucaparenkorean", 0x3216),
    ("/cieuccirclekorean", 0x3268),
    ("/cieucparenkorean", 0x3208),
    ("/cieucuparenkorean", 0x321C),
    ("/eightideographicparen", 0x3227),
    ("/fiveideographicparen", 0x3224),
    ("/fourideographicparen", 0x3223),
    ("/hieuhacirclekorean", 0x327B),
    ("/hieuhaparenkorean", 0x321B),
    ("/hieuhcirclekorean", 0x326D),
    ("/hieuhparenkorean", 0x320D),
    ("/ideographearthcircle", 0x328F),
    ("/ideographfirecircle", 0x328B),
    ("/ideographicallianceparen", 0x323F),
    ("/ideographiccallparen", 0x323A),
    ("/ideographiccentrecircle", 0x32A5),
    ("/ideographiccongratulationparen", 0x3237),
    ("/ideographiccorrectcircle", 0x32A3),
    ("/ideographicearthparen", 0x322F),
    ("/ideographicenterpriseparen", 0x323D),
    ("/ideographicexcellentcircle", 0x329D),
    ("/ideographicfestivalparen", 0x3240),
    ("/ideographicfinancialcircle", 0x3296),
    ("/ideographicfinancialparen", 0x3236),
    ("/ideographicfireparen", 0x322B),
    ("/ideographichaveparen", 0x3232),
    ("/ideographichighcircle", 0x32A4),
    ("/ideographiclaborcircle", 0x3298),
    ("/ideographiclaborparen", 0x3238),
    ("/ideographicleftcircle", 0x32A7),
    ("/ideographiclowcircle", 0x32A6),
    ("/ideographicmedicinecircle", 0x32A9),
    ("/ideographicmetalparen", 0x322E),
    ("/ideographicmoonparen", 0x322A),
    ("/ideographicnameparen", 0x3234),
    ("/ideographicprintcircle", 0x329E),
    ("/ideographicreachparen", 0x3243),
    ("/ideographicrepresentparen", 0x3239),
    ("/ideographicresourceparen", 0x323E),
    ("/ideographicrightcircle", 0x32A8),
    ("/ideographicsecretcircle", 0x3299),
    ("/ideographicselfparen", 0x3242),
    ("/ideographicsocietyparen", 0x3233),
    ("/ideographicspecialparen", 0x3235),
    ("/ideographicstockparen", 0x3231),
    ("/ideographicstudyparen", 0x323B),
    ("/ideographicsunparen", 0x3230),
    ("/ideographicsuperviseparen", 0x323C),
    ("/ideographicwaterparen", 0x322C),
    ("/ideographicwoodparen", 0x322D),
    ("/ideographmetalcircle", 0x328E),
    ("/ideographmooncircle", 0x328A),
    ("/ideographnamecircle", 0x3294),
    ("/ideographsuncircle", 0x3290),
    ("/ideographwatercircle", 0x328C),
    ("/ideographwoodcircle", 0x328D),
    ("/ieungacirclekorean", 0x3275),
    ("/ieungaparenkorean", 0x3215),
    ("/ieungcirclekorean", 0x3267),
    ("/ieungparenkorean", 0x3207),
    ("/khieukhacirclekorean", 0x3278),
    ("/khieukhaparenkorean", 0x3218),
    ("/khieukhcirclekorean", 0x326A),
    ("/khieukhparenkorean", 0x320A),
    ("/kiyeokacirclekorean", 0x326E),
    ("/kiyeokaparenkorean", 0x320E),
    ("/kiyeokcirclekorean", 0x3260),
    ("/kiyeokparenkorean", 0x3200),
    ("/koreanstandardsymbol", 0x327F),
    ("/mieumacirclekorean", 0x3272),
    ("/mieumaparenkorean", 0x3212),
    ("/mieumcirclekorean", 0x3264),
    ("/mieumparenkorean", 0x3204),
    ("/nieunacirclekorean", 0x326F),
    ("/nieunaparenkorean", 0x320F),
    ("/nieuncirclekorean", 0x3261),
    ("/nieunparenkorean", 0x3201),
    ("/nineideographicparen", 0x3228),
    ("/oneideographicparen", 0x3220),
    ("/phieuphacirclekorean", 0x327A),
    ("/phieuphaparenkorean", 0x321A),
    ("/phieuphcirclekorean", 0x326C),
    ("/phieuphparenkorean", 0x320C),
    ("/pieupacirclekorean", 0x3273),
    ("/pieupaparenkorean", 0x3213),
    ("/pieupcirclekorean", 0x3265),
    ("/pieupparenkorean", 0x3205),
    ("/rieulacirclekorean", 0x3271),
    ("/rieulaparenkorean", 0x3211),
    ("/rieulcirclekorean", 0x3263),
    ("/rieulparenkorean", 0x3203),
    ("/sevenideographicparen", 0x3226),
    ("/siosacirclekorean", 0x3274),
    ("/siosaparenkorean", 0x3214),
    ("/sioscirclekorean", 0x3266),
    ("/siosparenkorean", 0x3206),
    ("/sixideographicparen", 0x3225),
    ("/tenideographicparen", 0x3229),
    ("/thieuthacirclekorean", 0x3279),
    ("/thieuthaparenkorean", 0x3219),
    ("/thieuthcirclekorean", 0x326B),
    ("/thieuthparenkorean", 0x320B),
    ("/threeideographicparen", 0x3222),
    ("/tikeutacirclekorean", 0x3270),
    ("/tikeutaparenkorean", 0x3210),
    ("/tikeutcirclekorean", 0x3262),
    ("/tikeutparenkorean", 0x3202),
    ("/twoideographicparen", 0x3221),
  ]
  for entry in enclosed_cjk_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_enclosed_cjk_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_enclosed_cjk_glyphname(
      wbtest_text_name("/not-enclosed-cjk"),
    ),
    None,
  )
  let armenian_entries : Array[(String, Int)] = [
    ("/Aybarmenian", 0x0531),
    ("/Benarmenian", 0x0532),
    ("/Caarmenian", 0x053E),
    ("/Chaarmenian", 0x0549),
    ("/Cheharmenian", 0x0543),
    ("/Coarmenian", 0x0551),
    ("/Daarmenian", 0x0534),
    ("/Echarmenian", 0x0535),
    ("/Eharmenian", 0x0537),
    ("/Etarmenian", 0x0538),
    ("/Feharmenian", 0x0556),
    ("/Ghadarmenian", 0x0542),
    ("/Gimarmenian", 0x0533),
    ("/Hoarmenian", 0x0540),
    ("/Iniarmenian", 0x053B),
    ("/Jaarmenian", 0x0541),
    ("/Jheharmenian", 0x054B),
    ("/Keharmenian", 0x0554),
    ("/Kenarmenian", 0x053F),
    ("/Liwnarmenian", 0x053C),
    ("/Menarmenian", 0x0544),
    ("/Nowarmenian", 0x0546),
    ("/Oharmenian", 0x0555),
    ("/Peharmenian", 0x054A),
    ("/Piwrarmenian", 0x0553),
    ("/Raarmenian", 0x054C),
    ("/Reharmenian", 0x0550),
    ("/Seharmenian", 0x054D),
    ("/Shaarmenian", 0x0547),
    ("/Tiwnarmenian", 0x054F),
    ("/Toarmenian", 0x0539),
    ("/Vewarmenian", 0x054E),
    ("/Voarmenian", 0x0548),
    ("/Xeharmenian", 0x053D),
    ("/Yiarmenian", 0x0545),
    ("/Yiwnarmenian", 0x0552),
    ("/Zaarmenian", 0x0536),
    ("/Zhearmenian", 0x053A),
    ("/abbreviationmarkarmenian", 0x055F),
    ("/apostrophearmenian", 0x055A),
    ("/aybarmenian", 0x0561),
    ("/benarmenian", 0x0562),
    ("/caarmenian", 0x056E),
    ("/chaarmenian", 0x0579),
    ("/cheharmenian", 0x0573),
    ("/coarmenian", 0x0581),
    ("/commaarmenian", 0x055D),
    ("/daarmenian", 0x0564),
    ("/echarmenian", 0x0565),
    ("/echyiwnarmenian", 0x0587),
    ("/eharmenian", 0x0567),
    ("/emphasismarkarmenian", 0x055B),
    ("/etarmenian", 0x0568),
    ("/exclamarmenian", 0x055C),
    ("/feharmenian", 0x0586),
    ("/ghadarmenian", 0x0572),
    ("/gimarmenian", 0x0563),
    ("/hoarmenian", 0x0570),
    ("/iniarmenian", 0x056B),
    ("/jaarmenian", 0x0571),
    ("/jheharmenian", 0x057B),
    ("/keharmenian", 0x0584),
    ("/kenarmenian", 0x056F),
    ("/liwnarmenian", 0x056C),
    ("/menarmenian", 0x0574),
    ("/nowarmenian", 0x0576),
    ("/oharmenian", 0x0585),
    ("/peharmenian", 0x057A),
    ("/periodarmenian", 0x0589),
    ("/piwrarmenian", 0x0583),
    ("/questionarmenian", 0x055E),
    ("/raarmenian", 0x057C),
    ("/reharmenian", 0x0580),
    ("/ringhalfleftarmenian", 0x0559),
    ("/seharmenian", 0x057D),
    ("/shaarmenian", 0x0577),
    ("/tiwnarmenian", 0x057F),
    ("/toarmenian", 0x0569),
    ("/vewarmenian", 0x057E),
    ("/voarmenian", 0x0578),
    ("/xeharmenian", 0x056D),
    ("/yiarmenian", 0x0575),
    ("/yiwnarmenian", 0x0582),
    ("/zaarmenian", 0x0566),
    ("/zhearmenian", 0x056A),
  ]
  for entry in armenian_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_armenian_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_armenian_glyphname(wbtest_text_name("/not-armenian")),
    None,
  )
  let devanagari_entries : Array[(String, Int)] = [
    ("/aadeva", 0x0906),
    ("/aavowelsigndeva", 0x093E),
    ("/abbreviationsigndeva", 0x0970),
    ("/acutedeva", 0x0954),
    ("/adeva", 0x0905),
    ("/aideva", 0x0910),
    ("/aivowelsigndeva", 0x0948),
    ("/anudattadeva", 0x0952),
    ("/anusvaradeva", 0x0902),
    ("/audeva", 0x0914),
    ("/auvowelsigndeva", 0x094C),
    ("/avagrahadeva", 0x093D),
    ("/badeva", 0x092C),
    ("/bhadeva", 0x092D),
    ("/cadeva", 0x091A),
    ("/candrabindudeva", 0x0901),
    ("/chadeva", 0x091B),
    ("/dadeva", 0x0926),
    ("/danda", 0x0964),
    ("/dbldanda", 0x0965),
    ("/ddadeva", 0x0921),
    ("/dddhadeva", 0x095C),
    ("/ddhadeva", 0x0922),
    ("/dhadeva", 0x0927),
    ("/ecandradeva", 0x090D),
    ("/ecandravowelsigndeva", 0x0945),
    ("/edeva", 0x090F),
    ("/eightdeva", 0x096E),
    ("/eshortdeva", 0x090E),
    ("/eshortvowelsigndeva", 0x0946),
    ("/evowelsigndeva", 0x0947),
    ("/fadeva", 0x095E),
    ("/fivedeva", 0x096B),
    ("/fourdeva", 0x096A),
    ("/gadeva", 0x0917),
    ("/ghadeva", 0x0918),
    ("/ghhadeva", 0x095A),
    ("/gravedeva", 0x0953),
    ("/hadeva", 0x0939),
    ("/ideva", 0x0907),
    ("/iideva", 0x0908),
    ("/iivowelsigndeva", 0x0940),
    ("/ivowelsigndeva", 0x093F),
    ("/jadeva", 0x091C),
    ("/jhadeva", 0x091D),
    ("/kadeva", 0x0915),
    ("/khadeva", 0x0916),
    ("/khhadeva", 0x0959),
    ("/ladeva", 0x0932),
    ("/lladeva", 0x0933),
    ("/llladeva", 0x0934),
    ("/llvocalicdeva", 0x0961),
    ("/llvocalicvowelsigndeva", 0x0963),
    ("/lvocalicdeva", 0x090C),
    ("/lvocalicvowelsigndeva", 0x0962),
    ("/madeva", 0x092E),
    ("/nadeva", 0x0928),
    ("/ngadeva", 0x0919),
    ("/ninedeva", 0x096F),
    ("/nnadeva", 0x0923),
    ("/nnnadeva", 0x0929),
    ("/nuktadeva", 0x093C),
    ("/nyadeva", 0x091E),
    ("/ocandradeva", 0x0911),
    ("/ocandravowelsigndeva", 0x0949),
    ("/odeva", 0x0913),
    ("/omdeva", 0x0950),
    ("/onedeva", 0x0967),
    ("/oshortdeva", 0x0912),
    ("/oshortvowelsigndeva", 0x094A),
    ("/ovowelsigndeva", 0x094B),
    ("/padeva", 0x092A),
    ("/phadeva", 0x092B),
    ("/qadeva", 0x0958),
    ("/radeva", 0x0930),
    ("/rhadeva", 0x095D),
    ("/rradeva", 0x0931),
    ("/rrvocalicdeva", 0x0960),
    ("/rrvocalicvowelsigndeva", 0x0944),
    ("/rvocalicdeva", 0x090B),
    ("/rvocalicvowelsigndeva", 0x0943),
    ("/sadeva", 0x0938),
    ("/sevendeva", 0x096D),
    ("/shadeva", 0x0936),
    ("/sixdeva", 0x096C),
    ("/ssadeva", 0x0937),
    ("/tadeva", 0x0924),
    ("/thadeva", 0x0925),
    ("/threedeva", 0x0969),
    ("/ttadeva", 0x091F),
    ("/tthadeva", 0x0920),
    ("/twodeva", 0x0968),
    ("/udattadeva", 0x0951),
    ("/udeva", 0x0909),
    ("/uudeva", 0x090A),
    ("/uuvowelsigndeva", 0x0942),
    ("/uvowelsigndeva", 0x0941),
    ("/vadeva", 0x0935),
    ("/viramadeva", 0x094D),
    ("/visargadeva", 0x0903),
    ("/yadeva", 0x092F),
    ("/yyadeva", 0x095F),
    ("/zadeva", 0x095B),
    ("/zerodeva", 0x0966),
  ]
  for entry in devanagari_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_devanagari_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_devanagari_glyphname(wbtest_text_name("/not-deva")),
    None,
  )
  let thai_entries : Array[(String, Int)] = [
    ("/angkhankhuthai", 0x0E5A),
    ("/bahtthai", 0x0E3F),
    ("/bobaimaithai", 0x0E1A),
    ("/chochangthai", 0x0E0A),
    ("/chochanthai", 0x0E08),
    ("/chochingthai", 0x0E09),
    ("/chochoethai", 0x0E0C),
    ("/dochadathai", 0x0E0E),
    ("/dodekthai", 0x0E14),
    ("/eightthai", 0x0E58),
    ("/fivethai", 0x0E55),
    ("/fofanthai", 0x0E1F),
    ("/fofathai", 0x0E1D),
    ("/fongmanthai", 0x0E4F),
    ("/fourthai", 0x0E54),
    ("/hohipthai", 0x0E2B),
    ("/honokhukthai", 0x0E2E),
    ("/khokhaithai", 0x0E02),
    ("/khokhonthai", 0x0E05),
    ("/khokhuatthai", 0x0E03),
    ("/khokhwaithai", 0x0E04),
    ("/khomutthai", 0x0E5B),
    ("/khorakhangthai", 0x0E06),
    ("/kokaithai", 0x0E01),
    ("/lakkhangyaothai", 0x0E45),
    ("/lochulathai", 0x0E2C),
    ("/lolingthai", 0x0E25),
    ("/luthai", 0x0E26),
    ("/maichattawathai", 0x0E4B),
    ("/maiekthai", 0x0E48),
    ("/maihanakatthai", 0x0E31),
    ("/maitaikhuthai", 0x0E47),
    ("/maithothai", 0x0E49),
    ("/maitrithai", 0x0E4A),
    ("/maiyamokthai", 0x0E46),
    ("/momathai", 0x0E21),
    ("/ngonguthai", 0x0E07),
    ("/nikhahitthai", 0x0E4D),
    ("/ninethai", 0x0E59),
    ("/nonenthai", 0x0E13),
    ("/nonuthai", 0x0E19),
    ("/oangthai", 0x0E2D),
    ("/onethai", 0x0E51),
    ("/paiyannoithai", 0x0E2F),
    ("/phinthuthai", 0x0E3A),
    ("/phophanthai", 0x0E1E),
    ("/phophungthai", 0x0E1C),
    ("/phosamphaothai", 0x0E20),
    ("/poplathai", 0x0E1B),
    ("/roruathai", 0x0E23),
    ("/ruthai", 0x0E24),
    ("/saraaathai", 0x0E32),
    ("/saraaethai", 0x0E41),
    ("/saraaimaimalaithai", 0x0E44),
    ("/saraaimaimuanthai", 0x0E43),
    ("/saraamthai", 0x0E33),
    ("/saraathai", 0x0E30),
    ("/saraethai", 0x0E40),
    ("/saraiithai", 0x0E35),
    ("/saraithai", 0x0E34),
    ("/saraothai", 0x0E42),
    ("/saraueethai", 0x0E37),
    ("/sarauethai", 0x0E36),
    ("/sarauthai", 0x0E38),
    ("/sarauuthai", 0x0E39),
    ("/seventhai", 0x0E57),
    ("/sixthai", 0x0E56),
    ("/sorusithai", 0x0E29),
    ("/sosalathai", 0x0E28),
    ("/sosothai", 0x0E0B),
    ("/sosuathai", 0x0E2A),
    ("/thanthakhatthai", 0x0E4C),
    ("/thonangmonthothai", 0x0E11),
    ("/thophuthaothai", 0x0E12),
    ("/thothahanthai", 0x0E17),
    ("/thothanthai", 0x0E10),
    ("/thothongthai", 0x0E18),
    ("/thothungthai", 0x0E16),
    ("/threethai", 0x0E53),
    ("/topatakthai", 0x0E0F),
    ("/totaothai", 0x0E15),
    ("/twothai", 0x0E52),
    ("/wowaenthai", 0x0E27),
    ("/yamakkanthai", 0x0E4E),
    ("/yoyakthai", 0x0E22),
    ("/yoyingthai", 0x0E0D),
    ("/zerothai", 0x0E50),
  ]
  for entry in thai_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_thai_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_thai_glyphname(wbtest_text_name("/not-thai")),
    None,
  )
  let private_use_entries : Array[(String, Int)] = [
    ("/Acute", 0xF6C9),
    ("/Caron", 0xF6CA),
    ("/Dieresis", 0xF6CB),
    ("/DieresisAcute", 0xF6CC),
    ("/DieresisGrave", 0xF6CD),
    ("/Grave", 0xF6CE),
    ("/Hungarumlaut", 0xF6CF),
    ("/LL", 0xF6BF),
    ("/Macron", 0xF6D0),
    ("/afii10063", 0xF6C4),
    ("/afii10064", 0xF6C5),
    ("/afii10192", 0xF6C6),
    ("/afii10831", 0xF6C7),
    ("/afii10832", 0xF6C8),
    ("/apple", 0xF8FF),
    ("/commaaccent", 0xF6C3),
    ("/cyrBreve", 0xF6D1),
    ("/cyrFlex", 0xF6D2),
    ("/cyrbreve", 0xF6D4),
    ("/cyrflex", 0xF6D5),
    ("/dblGrave", 0xF6D3),
    ("/dblgrave", 0xF6D6),
    ("/dieresisacute", 0xF6D7),
    ("/dieresisgrave", 0xF6D8),
    ("/dollarsuperior", 0xF6E4),
    ("/dotlessj", 0xF6BE),
    ("/ll", 0xF6C0),
    ("/maichattawalowleftthai", 0xF895),
    ("/maichattawalowrightthai", 0xF894),
    ("/maichattawaupperleftthai", 0xF893),
    ("/maieklowleftthai", 0xF88C),
    ("/maieklowrightthai", 0xF88B),
    ("/maiekupperleftthai", 0xF88A),
    ("/maihanakatleftthai", 0xF884),
    ("/maitaikhuleftthai", 0xF889),
    ("/maitholowleftthai", 0xF88F),
    ("/maitholowrightthai", 0xF88E),
    ("/maithoupperleftthai", 0xF88D),
    ("/maitrilowleftthai", 0xF892),
    ("/maitrilowrightthai", 0xF891),
    ("/maitriupperleftthai", 0xF890),
    ("/nikhahitleftthai", 0xF899),
    ("/saraiileftthai", 0xF886),
    ("/saraileftthai", 0xF885),
    ("/saraueeleftthai", 0xF888),
    ("/saraueleftthai", 0xF887),
    ("/thanthakhatlowleftthai", 0xF898),
    ("/thanthakhatlowrightthai", 0xF897),
    ("/thanthakhatupperleftthai", 0xF896),
  ]
  for entry in private_use_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_private_use_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_private_use_glyphname(
      wbtest_text_name("/not-private-use"),
    ),
    None,
  )
  let half_fullwidth_entries : Array[(String, Int)] = [
    ("/Amonospace", 0xFF21),
    ("/Bmonospace", 0xFF22),
    ("/Cmonospace", 0xFF23),
    ("/Dmonospace", 0xFF24),
    ("/Emonospace", 0xFF25),
    ("/Fmonospace", 0xFF26),
    ("/Gmonospace", 0xFF27),
    ("/Hmonospace", 0xFF28),
    ("/Imonospace", 0xFF29),
    ("/Jmonospace", 0xFF2A),
    ("/Kmonospace", 0xFF2B),
    ("/Lmonospace", 0xFF2C),
    ("/Mmonospace", 0xFF2D),
    ("/Nmonospace", 0xFF2E),
    ("/Omonospace", 0xFF2F),
    ("/Pmonospace", 0xFF30),
    ("/Qmonospace", 0xFF31),
    ("/Rmonospace", 0xFF32),
    ("/Smonospace", 0xFF33),
    ("/Tmonospace", 0xFF34),
    ("/Umonospace", 0xFF35),
    ("/Vmonospace", 0xFF36),
    ("/Wmonospace", 0xFF37),
    ("/Xmonospace", 0xFF38),
    ("/Ymonospace", 0xFF39),
    ("/Zmonospace", 0xFF3A),
    ("/akatakanahalfwidth", 0xFF71),
    ("/amonospace", 0xFF41),
    ("/ampersandmonospace", 0xFF06),
    ("/asciicircummonospace", 0xFF3E),
    ("/asciitildemonospace", 0xFF5E),
    ("/asmallkatakanahalfwidth", 0xFF67),
    ("/asteriskmonospace", 0xFF0A),
    ("/atmonospace", 0xFF20),
    ("/backslashmonospace", 0xFF3C),
    ("/barmonospace", 0xFF5C),
    ("/bmonospace", 0xFF42),
    ("/braceleftmonospace", 0xFF5B),
    ("/bracerightmonospace", 0xFF5D),
    ("/bracketleftmonospace", 0xFF3B),
    ("/bracketrightmonospace", 0xFF3D),
    ("/centmonospace", 0xFFE0),
    ("/cmonospace", 0xFF43),
    ("/colonmonospace", 0xFF1A),
    ("/commamonospace", 0xFF0C),
    ("/cornerbracketlefthalfwidth", 0xFF62),
    ("/cornerbracketrighthalfwidth", 0xFF63),
    ("/dmonospace", 0xFF44),
    ("/dollarmonospace", 0xFF04),
    ("/eightmonospace", 0xFF18),
    ("/ekatakanahalfwidth", 0xFF74),
    ("/emonospace", 0xFF45),
    ("/equalmonospace", 0xFF1D),
    ("/esmallkatakanahalfwidth", 0xFF6A),
    ("/exclammonospace", 0xFF01),
    ("/fivemonospace", 0xFF15),
    ("/fmonospace", 0xFF46),
    ("/fourmonospace", 0xFF14),
    ("/gmonospace", 0xFF47),
    ("/gravemonospace", 0xFF40),
    ("/greatermonospace", 0xFF1E),
    ("/hakatakanahalfwidth", 0xFF8A),
    ("/hekatakanahalfwidth", 0xFF8D),
    ("/hikatakanahalfwidth", 0xFF8B),
    ("/hmonospace", 0xFF48),
    ("/hokatakanahalfwidth", 0xFF8E),
    ("/hukatakanahalfwidth", 0xFF8C),
    ("/hyphenmonospace", 0xFF0D),
    ("/ideographiccommaleft", 0xFF64),
    ("/ikatakanahalfwidth", 0xFF72),
    ("/imonospace", 0xFF49),
    ("/ismallkatakanahalfwidth", 0xFF68),
    ("/jmonospace", 0xFF4A),
    ("/kakatakanahalfwidth", 0xFF76),
    ("/katahiraprolongmarkhalfwidth", 0xFF70),
    ("/kekatakanahalfwidth", 0xFF79),
    ("/kikatakanahalfwidth", 0xFF77),
    ("/kmonospace", 0xFF4B),
    ("/kokatakanahalfwidth", 0xFF7A),
    ("/kukatakanahalfwidth", 0xFF78),
    ("/lessmonospace", 0xFF1C),
    ("/lmonospace", 0xFF4C),
    ("/macronmonospace", 0xFFE3),
    ("/makatakanahalfwidth", 0xFF8F),
    ("/mekatakanahalfwidth", 0xFF92),
    ("/middledotkatakanahalfwidth", 0xFF65),
    ("/mikatakanahalfwidth", 0xFF90),
    ("/mmonospace", 0xFF4D),
    ("/mokatakanahalfwidth", 0xFF93),
    ("/mukatakanahalfwidth", 0xFF91),
    ("/nakatakanahalfwidth", 0xFF85),
    ("/nekatakanahalfwidth", 0xFF88),
    ("/nikatakanahalfwidth", 0xFF86),
    ("/ninemonospace", 0xFF19),
    ("/nkatakanahalfwidth", 0xFF9D),
    ("/nmonospace", 0xFF4E),
    ("/nokatakanahalfwidth", 0xFF89),
    ("/nukatakanahalfwidth", 0xFF87),
    ("/numbersignmonospace", 0xFF03),
    ("/okatakanahalfwidth", 0xFF75),
    ("/omonospace", 0xFF4F),
    ("/onemonospace", 0xFF11),
    ("/osmallkatakanahalfwidth", 0xFF6B),
    ("/parenleftmonospace", 0xFF08),
    ("/parenrightmonospace", 0xFF09),
    ("/percentmonospace", 0xFF05),
    ("/periodhalfwidth", 0xFF61),
    ("/periodmonospace", 0xFF0E),
    ("/plusmonospace", 0xFF0B),
    ("/pmonospace", 0xFF50),
    ("/qmonospace", 0xFF51),
    ("/questionmonospace", 0xFF1F),
    ("/quotedblmonospace", 0xFF02),
    ("/quotesinglemonospace", 0xFF07),
    ("/rakatakanahalfwidth", 0xFF97),
    ("/rekatakanahalfwidth", 0xFF9A),
    ("/rikatakanahalfwidth", 0xFF98),
    ("/rmonospace", 0xFF52),
    ("/rokatakanahalfwidth", 0xFF9B),
    ("/rukatakanahalfwidth", 0xFF99),
    ("/sakatakanahalfwidth", 0xFF7B),
    ("/sekatakanahalfwidth", 0xFF7E),
    ("/semicolonmonospace", 0xFF1B),
    ("/semivoicedmarkkanahalfwidth", 0xFF9F),
    ("/sevenmonospace", 0xFF17),
    ("/sikatakanahalfwidth", 0xFF7C),
    ("/sixmonospace", 0xFF16),
    ("/slashmonospace", 0xFF0F),
    ("/smonospace", 0xFF53),
    ("/sokatakanahalfwidth", 0xFF7F),
    ("/sterlingmonospace", 0xFFE1),
    ("/sukatakanahalfwidth", 0xFF7D),
    ("/takatakanahalfwidth", 0xFF80),
    ("/tekatakanahalfwidth", 0xFF83),
    ("/threemonospace", 0xFF13),
    ("/tikatakanahalfwidth", 0xFF81),
    ("/tmonospace", 0xFF54),
    ("/tokatakanahalfwidth", 0xFF84),
    ("/tukatakanahalfwidth", 0xFF82),
    ("/tusmallkatakanahalfwidth", 0xFF6F),
    ("/twomonospace", 0xFF12),
    ("/ukatakanahalfwidth", 0xFF73),
    ("/umonospace", 0xFF55),
    ("/underscoremonospace", 0xFF3F),
    ("/usmallkatakanahalfwidth", 0xFF69),
    ("/vmonospace", 0xFF56),
    ("/voicedmarkkanahalfwidth", 0xFF9E),
    ("/wakatakanahalfwidth", 0xFF9C),
    ("/wmonospace", 0xFF57),
    ("/wokatakanahalfwidth", 0xFF66),
    ("/wonmonospace", 0xFFE6),
    ("/xmonospace", 0xFF58),
    ("/yakatakanahalfwidth", 0xFF94),
    ("/yasmallkatakanahalfwidth", 0xFF6C),
    ("/yenmonospace", 0xFFE5),
    ("/ymonospace", 0xFF59),
    ("/yokatakanahalfwidth", 0xFF96),
    ("/yosmallkatakanahalfwidth", 0xFF6E),
    ("/yukatakanahalfwidth", 0xFF95),
    ("/yusmallkatakanahalfwidth", 0xFF6D),
    ("/zeromonospace", 0xFF10),
    ("/zmonospace", 0xFF5A),
  ]
  for entry in half_fullwidth_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_half_fullwidth_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_half_fullwidth_glyphname(
      wbtest_text_name("/not-half-fullwidth"),
    ),
    None,
  )
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
  @test.assert_eq(pdf_text_cns1_codepoint_of_cid(-1), None)
  @test.assert_eq(pdf_text_cns1_codepoint_of_cid(0), None)
  @test.assert_eq(
    pdf_text_cns1_codepoint_of_cid(pdf_text_cns1_unicode_table.length()),
    None,
  )
  @test.assert_eq(pdf_text_gb1_codepoint_of_cid(-1), None)
  @test.assert_eq(pdf_text_gb1_codepoint_of_cid(0), None)
  @test.assert_eq(
    pdf_text_gb1_codepoint_of_cid(pdf_text_gb1_unicode_table.length()),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_charcode_of_cid(
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)][:],
      1,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_lookup_unsigned(
      [(0x20, 0x7E, 10), (0x8EA2EDA1, 0x8EA2EDA2, 20)][:],
      0x8EA2EDA2,
    ),
    Some(21),
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_lookup_unsigned(
      [(0x20, 0x7E, 10), (0x8EA2EDA1, 0x8EA2EDA2, 20)][:],
      0x80,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_lower_optional_packed_charcode(Some(0x0000FE51), Some(0x81308436)),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_lower_optional_packed_charcode(Some(0x0000FE51), None),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_sequence_table_charcode(
      [(3, [0x21]), (1, [0x20]), (2, [0x20, 0xFE00])][:],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)][:],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_sequence_table_charcode(
      [(3, [0x21])][:],
      [(0x0000FE51, 0x0000FE51, 1)][:],
      0x21,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_charcode_of_cid(
      [(0x81308436, 0x81308436, 1)][:],
      2,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_unicode_table_charcode(
      [0, 0x20, 0x20][:],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 2)][:],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_unicode_table_charcode(
      [0, 0x20][:],
      [(0x0000FE51, 0x0000FE51, 1)][:],
      0,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_codepoint_range_charcode(
      [(1, 1, 0x20)][:],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)][:],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_codepoint_range_charcode(
      [(1, 1, 0x20)][:],
      [(0x0000FE51, 0x0000FE51, 1)][:],
      0x21,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_gb1_charcode(
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  let unknown_vertical_cmap = wbtest_text_name("/Unknown-V")
  guard pdf_text_predefined_gb1_vertical_codepoint_table(unknown_vertical_cmap)
    is None else {
    fail("expected no GB1 vertical table")
  }
  guard pdf_text_predefined_gb1_vertical_charcode_table(unknown_vertical_cmap)
    is None else {
    fail("expected no GB1 vertical reverse table")
  }
  guard pdf_text_predefined_korea1_vertical_codepoint_table(
      unknown_vertical_cmap,
    )
    is None else {
    fail("expected no Korea1 vertical table")
  }
  guard pdf_text_predefined_korea1_vertical_charcode_table(
      unknown_vertical_cmap,
    )
    is None else {
    fail("expected no Korea1 vertical reverse table")
  }
  let japan1_cid_cmaps = [
    "/H", "/V", "/78-H", "/78-V", "/78-EUC-H", "/78-EUC-V", "/78-RKSJ-H", "/78-RKSJ-V",
    "/78ms-RKSJ-H", "/78ms-RKSJ-V", "/83pv-RKSJ-H", "/90ms-RKSJ-H", "/90ms-RKSJ-V",
    "/90msp-RKSJ-H", "/90msp-RKSJ-V", "/90pv-RKSJ-H", "/90pv-RKSJ-V", "/Add-H", "/Add-V",
    "/Add-RKSJ-H", "/Add-RKSJ-V", "/EUC-H", "/EUC-V", "/Ext-H", "/Ext-V", "/Ext-RKSJ-H",
    "/Ext-RKSJ-V", "/Hojo-H", "/Hojo-V", "/Hojo-EUC-H", "/Hojo-EUC-V", "/NWP-H",
    "/NWP-V", "/RKSJ-H", "/RKSJ-V",
  ]
  for cmap in japan1_cid_cmaps {
    guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name(cmap))
      is Some(_) else {
      fail("expected Japan1 CID ranges for " + cmap)
    }
  }
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/Unknown"))
    is None else {
    fail("expected no Japan1 CID ranges for non-oriented CMap")
  }
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/Unknown-V"))
    is None else {
    fail("expected no Japan1 CID ranges for unknown vertical CMap")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90ms-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90ms-RKSJ direct table")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90pv-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90pv-RKSJ direct table")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90ms-RKSJ-V"),
    )
    is None else {
    fail("expected no direct table for vertical RKSJ")
  }
  @test.assert_eq(
    pdf_text_predefined_japan1_direct_codepoint_sequence_table(
      wbtest_text_name("/90ms-RKSJ-H"),
    ).length(),
    0,
  )
  @test.assert_eq(
    pdf_text_predefined_japan1_direct_codepoint_sequence_table(
      wbtest_text_name("/90pv-RKSJ-H"),
    ).length() >
    0,
    true,
  )
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90ms-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90ms-RKSJ direct reverse table")
  }
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90pv-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90pv-RKSJ direct reverse table")
  }
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90ms-RKSJ-V"),
    )
    is None else {
    fail("expected no direct reverse table for vertical RKSJ")
  }
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/H"),
    ),
    true,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/90ms-RKSJ-H"),
    ),
    false,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/EUC-H"),
    ),
    false,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_hojo_euc_charcodes(
      wbtest_text_name("/Hojo-EUC-H"),
    ),
    true,
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_codepoint(0xA6),
    Some(0xFF66),
  )
  @test.assert_eq(pdf_text_predefined_rksj_single_byte_codepoint(0x8140), None)
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_charcode(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_charcode(0xFF66),
    Some(0xA6),
  )
  @test.assert_eq(pdf_text_predefined_rksj_single_byte_charcode(0x3000), None)
  @test.assert_eq(pdf_text_japan1_codepoints_of_cid(843), Some([0x3042]))
  @test.assert_eq(pdf_text_japan1_codepoints_of_cid(-1), None)
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/H"))
    is Some(jis_ranges) else {
    fail("expected JIS ranges")
  }
  @test.assert_eq(
    pdf_text_predefined_japan1_codepoints(jis_ranges, 0x2422),
    Some([0x3042]),
  )
  @test.assert_eq(pdf_text_predefined_japan1_codepoints(jis_ranges, 0), None)
  @test.assert_eq(
    pdf_text_predefined_japan1_charcode(jis_ranges, 0x3042),
    Some(0x2422),
  )
  @test.assert_eq(
    pdf_text_predefined_japan1_charcode(jis_ranges, 0x1F600),
    None,
  )
  let unknown_rksj_font : PdfFont = PdfFontCIDKeyed({
    basefont: wbtest_text_name("/UnknownRKSJ"),
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
    encoding: PdfPredefinedCMap(wbtest_text_name("/Unknown-RKSJ-H")),
  })
  let unknown_rksj_extractor = unknown_rksj_font.text_extractor()
  @test.assert_eq(
    unknown_rksj_extractor.codepoints_of_text(
      wbtest_text_bytes([0x41, 0xA6, 0x81, 0x40])[:],
    ),
    [0x41, 0xFF66, 0x8140],
  )
  @test.assert_eq(
    unknown_rksj_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    unknown_rksj_extractor.charcode_of_codepoint(0xFF66),
    Some(0xA6),
  )
  @test.assert_eq(unknown_rksj_extractor.charcode_of_codepoint(0x3000), None)
  @test.assert_eq(pdf_text_hex_int_min2(7), "07")
}

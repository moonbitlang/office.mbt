///|
fn reader_wbtest_bytes(text : String) -> @core.PdfBytes {
  @ascii.encode(text)
}

///|
fn reader_wbtest_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(reader_wbtest_bytes(text))
}

///|
fn reader_wbtest_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn reader_wbtest_xref_stream_without_root() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_wbtest_push_ascii(output, "%PDF-1.5\n")
  let xref_offset = output.length()
  reader_wbtest_push_ascii(
    output, "1 0 obj\n<< /Type /XRef /Size 1 /W [1 4 2] /Length 7 >>\nstream\n",
  )
  for byte in [0, 0, 0, 0, 0, 255, 255] {
    output.push(byte.to_byte())
  }
  reader_wbtest_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_wbtest_push_ascii(output, xref_offset.to_string())
  reader_wbtest_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
test "private object-stream member parser handles direct stream members" {
  let object = try! pdf_parse_object_stream_member_from_view(
    reader_wbtest_bytes("<< /Length 2 >>\nstream\nHi\nendstream"),
  )
  guard object is PdfStreamObject(stream) else {
    fail("expected stream member")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(reader_wbtest_name("/Length")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(stream.data, StreamGot(reader_wbtest_bytes("Hi")))
}

///|
test "private object-stream member parser repairs missing lengths" {
  let object = try! pdf_parse_object_stream_member_from_view(
    reader_wbtest_bytes("<< >>\nstream\nHi\nendstream"),
  )
  guard object is PdfStreamObject(stream) else {
    fail("expected repaired stream member")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(reader_wbtest_name("/Length")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(stream.data, StreamGot(reader_wbtest_bytes("Hi")))
}

///|
test "private object-stream member parser repairs mismatched lengths" {
  let object = try! pdf_parse_object_stream_member_from_view(
    reader_wbtest_bytes("<< /Length 1 >>\nstream\nHi\nendstream"),
  )
  guard object is PdfStreamObject(stream) else {
    fail("expected repaired stream member")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(reader_wbtest_name("/Length")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(stream.data, StreamGot(reader_wbtest_bytes("Hi")))
}

///|
test "private object-stream member parser reports missing endstream markers" {
  let result : Result[@syntax.PdfObject, Error] = try
    pdf_parse_object_stream_member_from_view(
      reader_wbtest_bytes("<< >>\nstream\nHi"),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::ParseEndStreamExpected) else {
    fail("expected @core.PdfError::ParseEndStreamExpected")
  }
}

///|
test "private object-stream member parser rejects non-dictionary streams" {
  let result : Result[@syntax.PdfObject, Error] = try
    pdf_parse_object_stream_member_from_view(
      reader_wbtest_bytes("7\nstream\nHi\nendstream"),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::ParseSingleObjectExpected) else {
    fail("expected @core.PdfError::ParseSingleObjectExpected")
  }
}

///|
test "private object-stream root reconstruction guard rejects missing trailer roots" {
  @test.assert_eq(
    pdf_reader_startxref_root_uses_object_stream(
      reader_wbtest_xref_stream_without_root(),
    ),
    false,
  )
}

///|
test "reconstructed document ignores streams that become invalid after xref recovery" {
  let parsed = try! pdf_read_document_from_bytes(
    reader_wbtest_bytes(
      "%PDF-1.4\n1 0 obj\n<< /Length 2 0 R >>\nstream\nHi\nendstream\nendobj\n2 0 obj\n999999\nendobj\n3 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 3 0 R /Size 4 >>\n",
    ),
  )
  @test.assert_eq(parsed.root(), 3)
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfNull)
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(999999))
}

///|
test "private reconstructed document loads through reader reconstruction plan" {
  let parsed = try! pdf_read_reconstructed_document_from_view(
    reader_wbtest_bytes(
      "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R /Size 2 >>\n",
    ),
    include_xref_stream_trailers=false,
  )
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @core.pdf_name_of_bytes(reader_wbtest_bytes("/Type")),
        PdfNameObject(@core.pdf_name_of_bytes(reader_wbtest_bytes("/Catalog"))),
      ),
    ]),
  )
}

///|
test "private reconstructed classic xref reader rejects xref streams" {
  let cursor = @core.byte_cursor_of_view(
    reader_wbtest_bytes(
      "7 0 obj\n<< /Type /XRef /Size 1 /W [1 4 2] /Length 7 >>\nstream\n\\u{0}\\u{0}\\u{0}\\u{0}\\u{0}\\u{255}\\u{255}\nendstream\nendobj",
    ),
  )
  let result : Result[(@reader.PdfXRefSection, Int), Error] = try
    pdf_cursor_read_reconstructed_classic_xref_section_at(cursor, 0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::XRefExpected) else {
    fail("expected @core.PdfError::XRefExpected")
  }
}

///|
test "private xref stream helpers cover malformed and deferred entries" {
  let key_w = @reader.pdf_reader_name("/W")
  let key_index = @reader.pdf_reader_name("/Index")
  let negative_xrefstm : Result[Int?, Error] = try
    @reader.pdf_trailer_xref_stream_position(
      PdfDictionary([(@reader.pdf_reader_xrefstm_name(), PdfInteger(-1))]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard negative_xrefstm is Err(@core.PdfError::XRefExpected) else {
    fail("expected @core.PdfError::XRefExpected")
  }

  let malformed_array_value : Result[Array[Int]?, Error] = try
    @reader.pdf_xref_stream_int_array(
      PdfDictionary([
        (key_w, PdfArray([PdfNameObject(@reader.pdf_reader_name("/Name"))])),
      ]),
      key_w,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_array_value is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let malformed_non_array : Result[Array[Int]?, Error] = try
    @reader.pdf_xref_stream_int_array(
      PdfDictionary([(key_w, PdfInteger(1))]),
      key_w,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_non_array is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let malformed_widths : Result[(Int, Int, Int), Error] = try
    @reader.pdf_xref_stream_widths(
      PdfDictionary([(key_w, PdfArray([PdfInteger(1), PdfInteger(2)]))]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_widths is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let odd_index : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_xref_stream_index_pairs(
      PdfDictionary([(key_index, PdfArray([PdfInteger(0)]))]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard odd_index is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let negative_index : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_xref_stream_index_pairs(
      PdfDictionary([(key_index, PdfArray([PdfInteger(0), PdfInteger(-1)]))]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard negative_index is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let missing_size : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_xref_stream_index_pairs(PdfDictionary([]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_size is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  @test.assert_eq(
    try! @reader.pdf_xref_stream_read_field(@ascii.encode("ab"), 0, 0),
    (0, 0),
  )
  let short_field : Result[(Int, Int), Error] = try
    @reader.pdf_xref_stream_read_field(@ascii.encode("a"), 0, 2)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard short_field is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let default_kind_entries = try! @reader.pdf_xref_stream_entries(
    Bytes::from_array([9, 0, 8, 1]),
    (0, 1, 1),
    [(5, 2)],
  )
  @test.assert_eq(default_kind_entries.length(), 2)
  @test.assert_eq(default_kind_entries[0].object_number, 5)
  @test.assert_eq(default_kind_entries[0].offset, 9)
  @test.assert_eq(default_kind_entries[0].generation, 0)
  @test.assert_eq(default_kind_entries[0].in_use, true)

  let deferred_entries = try! @reader.pdf_xref_stream_entries(
    Bytes::from_array([2, 7, 0, 9, 0, 0]),
    (1, 1, 1),
    [(3, 2)],
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
  let key_type = @reader.pdf_reader_name("/Type")
  let key_n = @reader.pdf_reader_name("/N")
  let key_first = @reader.pdf_reader_name("/First")
  let key_length = @reader.pdf_reader_name("/Length")

  let missing_required : Result[Int, Error] = try
    pdf_document_empty().pdf_object_stream_required_int(
      PdfDictionary([]),
      key_n,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_required is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let bad_first : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_object_stream_number_offsets(@ascii.encode("1 0"), 4, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_first is Err(@core.PdfError::StreamDataExpected) else {
    fail("expected @core.PdfError::StreamDataExpected")
  }

  let short_header : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_object_stream_number_offsets(@ascii.encode("2 "), 2, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard short_header is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let malformed_pair : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_object_stream_number_offsets(@ascii.encode("/Name 0 "), 8, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_pair is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  @test.assert_eq(
    @reader.pdf_object_stream_end_offsets(
      [(2, 4), (3, 0), (4, 4), (5, 8)],
      20,
      8,
    ),
    [8, 4, 8, 12],
  )
  @test.assert_eq(
    @reader.pdf_object_stream_end_offsets([(2, 0), (3, 100)], 20, 8),
    [12, 12],
  )

  let doc = pdf_document_empty()
  let valid_stream = @syntax.pdf_stream(
    PdfDictionary([
      (key_type, PdfNameObject(@reader.pdf_reader_name("/ObjStm"))),
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
  let bad_index : Result[(Int, @syntax.PdfObject), Error] = try
    context.read_reference({ object_stream_number: 7, index: 9 })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_index is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }
  let recovered_doc = pdf_document_empty()
  recovered_doc.add_object_given_number(7, valid_stream)
  let recovered_xrefs : ReadOnlyArray[@reader.PdfClassicXRefEntry] = [
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
  let grouped_xrefs = @reader.pdf_reader_object_stream_groups([
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
  ])
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
  recovered_doc.load_reconstructed_xref_stream_embedded_objects(recovered_xrefs)
  @test.assert_eq(recovered_doc.lookup_object_or_null(2), PdfBoolean(true))
  @test.assert_eq(recovered_doc.lookup_object_or_null(3), PdfBoolean(false))

  let password_recovered_doc = pdf_document_empty()
  password_recovered_doc.add_object_given_number(7, valid_stream)
  password_recovered_doc.load_reconstructed_xref_stream_embedded_objects_with_passwords(
    recovered_xrefs,
    None,
    None,
  )
  @test.assert_eq(
    password_recovered_doc.lookup_object_or_null(2),
    PdfBoolean(true),
  )

  let bad_embedded_xrefs : ReadOnlyArray[@reader.PdfClassicXRefEntry] = [
    {
      object_number: 4,
      offset: 0,
      generation: 0,
      in_use: true,
      object_stream: Some({ object_stream_number: 7, index: 9 }),
    },
  ]
  recovered_doc.load_reconstructed_xref_stream_embedded_objects(
    bad_embedded_xrefs,
  )
  @test.assert_eq(recovered_doc.lookup_object_or_null(4), PdfNull)
  password_recovered_doc.load_reconstructed_xref_stream_embedded_objects_with_passwords(
    bad_embedded_xrefs,
    None,
    None,
  )
  @test.assert_eq(password_recovered_doc.lookup_object_or_null(4), PdfNull)

  let no_type_doc = pdf_document_empty()
  no_type_doc.add_object_given_number(
    10,
    @syntax.pdf_stream(
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
    @syntax.pdf_stream(
      PdfDictionary([
        (key_type, PdfNameObject(@reader.pdf_reader_name("/Page"))),
        (key_n, PdfInteger(1)),
        (key_first, PdfInteger(4)),
        (key_length, PdfInteger(8)),
      ]),
      StreamGot(@ascii.encode("2 0 true")),
    ),
  )
  let wrong_type : Result[PdfObjectStreamContext, Error] = try
    wrong_type_doc.read_object_stream_context(8)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard wrong_type is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let missing_stream : Result[PdfObjectStreamContext, Error] = try
    doc.read_object_stream_context(99)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_stream is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let missing_encrypted_stream : Result[(PdfObjectStreamContext, Bool), Error] = try
    doc.read_object_stream_context_with_passwords(
      99,
      Some(@ascii.encode("user")),
      None,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_encrypted_stream is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let bad_offset_doc = pdf_document_empty()
  bad_offset_doc.add_object_given_number(
    9,
    @syntax.pdf_stream(
      PdfDictionary([
        (key_type, PdfNameObject(@reader.pdf_reader_name("/ObjStm"))),
        (key_n, PdfInteger(1)),
        (key_first, PdfInteger(5)),
        (key_length, PdfInteger(9)),
      ]),
      StreamGot(@ascii.encode("2 99 true")),
    ),
  )
  let bad_offset_context = try! bad_offset_doc.read_object_stream_context(9)
  let bad_offset : Result[(Int, @syntax.PdfObject), Error] = try
    bad_offset_context.read_reference({ object_stream_number: 9, index: 0 })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_offset is Err(@core.PdfError::StreamDataExpected) else {
    fail("expected @core.PdfError::StreamDataExpected")
  }
}

///|
test "private reader xref helpers report malformed inputs" {
  let empty_token : Result[Bool, Error] = try
    @reader.pdf_xref_token_in_use(Bytes::new(0))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard empty_token is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }
  let bad_token : Result[Bool, Error] = try
    @reader.pdf_xref_token_in_use(@ascii.encode("q"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_token is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected @core.PdfError::XRefEntryExpected")
  }

  let empty_xrefs : Array[@reader.PdfClassicXRefEntry] = []
  @test.assert_eq(@reader.pdf_classic_xref_lookup(empty_xrefs, 1), None)
  let xref_target : Array[@reader.PdfClassicXRefEntry] = [
    {
      object_number: 2,
      offset: 20,
      generation: 0,
      in_use: true,
      object_stream: None,
    },
  ]
  let seen_xrefs = @core.pdf_number_set([2])
  @reader.pdf_classic_xrefs_add_newer_first_with_seen(xref_target, seen_xrefs, [
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
  let xref_stream_ref_set = @reader.pdf_reader_xref_stream_ref_set([
    (5, 100),
    (5, 200),
    (7, 100),
  ])
  @test.assert_eq(xref_stream_ref_set.contains(5, 100), true)
  @test.assert_eq(xref_stream_ref_set.contains(5, 300), false)
  @test.assert_eq(xref_stream_ref_set.contains(7, 100), true)
  @test.assert_eq(xref_stream_ref_set.contains(8, 100), false)

  let no_object = @core.byte_cursor_of_bytes(@ascii.encode("notobject"))
  let no_object_result : Result[@syntax.PdfParsedIndirectObject, Error] = try
    pdf_cursor_read_first_indirect_object_at_current(no_object, empty_xrefs)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard no_object_result is Err(@core.PdfError::ParseIndirectObjectExpected) else {
    fail("expected @core.PdfError::ParseIndirectObjectExpected")
  }

  let no_plain_object = @core.byte_cursor_of_bytes(@ascii.encode("notobject"))
  let no_plain_object_result : Result[@syntax.PdfParsedIndirectObject, Error] = try
    pdf_cursor_read_plain_indirect_object_at_current(no_plain_object)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard no_plain_object_result
    is Err(@core.PdfError::ParseIndirectObjectExpected) else {
    fail("expected @core.PdfError::ParseIndirectObjectExpected")
  }
  @test.assert_eq(
    try! pdf_cursor_read_plain_indirect_object_at_current(
      @core.byte_cursor_of_bytes(@ascii.encode("2 0 obj\n42\n")),
    ),
    { number: 2, generation: 0, object: PdfInteger(42) },
  )
  let adjacent_source = @ascii.encode(
    "2 0 obj\n42\nendobj\n3 0 obj\n99\nendobj\n",
  )
  let adjacent = @core.byte_cursor_of_bytes(adjacent_source)
  @test.assert_eq(
    try! pdf_cursor_read_first_indirect_object_at_current(adjacent, empty_xrefs),
    { number: 2, generation: 0, object: PdfInteger(42) },
  )
  @test.assert_eq(
    adjacent.absolute_position(),
    @ascii.encode("2 0 obj\n42\nendobj").length(),
  )

  let empty_prefix = @core.byte_cursor_of_bytes(Bytes::new(0))
  let empty_prefix_result : Result[@syntax.PdfParsedIndirectObject, Error] = try
    pdf_cursor_read_reconstructed_indirect_prefix_at_current(empty_prefix)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard empty_prefix_result is Err(@core.PdfError::ParseIndirectObjectExpected) else {
    fail("expected @core.PdfError::ParseIndirectObjectExpected")
  }
  let incomplete_scan = @core.byte_cursor_of_bytes(
    @ascii.encode("3 0 obj\n42\n"),
  )
  let (incomplete_candidate, incomplete_next) = try! pdf_cursor_read_reconstructed_indirect_scan_candidate_at_current(
    incomplete_scan, empty_xrefs,
  )
  @test.assert_eq(incomplete_candidate, {
    number: 3,
    generation: 0,
    object: PdfInteger(42),
  })
  @test.assert_eq(incomplete_next, None)
  let incomplete_xrefs = try! @reader.pdf_reader_reconstruction_object_xrefs(
    @ascii.encode("3 0 obj\n42\n"),
    pdf_cursor_read_reconstructed_xref_at_current,
  )
  @test.assert_eq(incomplete_xrefs.length(), 1)
  @test.assert_eq(incomplete_xrefs[0].object_number, 3)
  let noisy_digits = @ascii.encode(
    "12345 67 notobj\n90 0 nope\nabc 4 0 obj\n42\nendobj\n",
  )
  let valid_header = @core.pdf_find_ascii_from(noisy_digits, 0, [
    52, 32, 48, 32, 111, 98, 106,
  ])
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_indirect_header_at(noisy_digits, 0),
    false,
  )
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_indirect_header_at(
      noisy_digits, valid_header,
    ),
    true,
  )
  let noisy_xrefs = try! @reader.pdf_reader_reconstruction_object_xrefs(
    noisy_digits, pdf_cursor_read_reconstructed_xref_at_current,
  )
  @test.assert_eq(noisy_xrefs.length(), 1)
  @test.assert_eq(noisy_xrefs[0].object_number, 4)
  @test.assert_eq(noisy_xrefs[0].offset, valid_header)
  let nested_bad_object = @ascii.encode(
    "1 0 obj\n]\n2 0 obj\n<< /Type /Catalog >>\nendobj\n3 0 obj\n42\nendobj\n",
  )
  let endobj : ReadOnlyArray[Int] = [101, 110, 100, 111, 98, 106]
  let nested_endobj = @core.pdf_find_ascii_from(nested_bad_object, 0, endobj)
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_indirect_header_at(nested_bad_object, 0),
    true,
  )
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_indirect_header_at(
      @ascii.encode("1 0 object"),
      0,
    ),
    false,
  )
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(
      nested_bad_object, 0,
    ),
    Some(nested_endobj + 7),
  )
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(
      nested_bad_object, 1,
    ),
    None,
  )
  let line_ending_endobj = @ascii.encode("1 0 obj\n]\nabcendobj\r\n4 0 obj\n")
  let trailing_endobj = @core.pdf_find_ascii_from(line_ending_endobj, 0, endobj)
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(
      line_ending_endobj, 0,
    ),
    Some(trailing_endobj + 8),
  )
  let leading_trim_endobj = @ascii.encode("1 0 obj\n]\n  endobj\n")
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(
      leading_trim_endobj, 0,
    ),
    Some(leading_trim_endobj.length()),
  )
  let no_endobj = @ascii.encode("1 0 obj\n]")
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(no_endobj, 0),
    Some(no_endobj.length()),
  )
  let bad_resolved_length = @ascii.encode(
    "1 0 obj\n<< /Length 2 0 R >>\nstream\nHi\nendstream\nendobj\n2 0 obj\n999999\nendobj\n",
  )
  let bad_resolved_length_xrefs = try! @reader.pdf_reader_reconstruction_object_xrefs(
    bad_resolved_length, pdf_cursor_read_reconstructed_xref_at_current,
  )
  let bad_resolved_length_cursor = @core.byte_cursor_of_view(
    bad_resolved_length,
  )
  let objects_with_bad_resolved_length : Array[@syntax.PdfParsedIndirectObject] = []
  for xref in bad_resolved_length_xrefs {
    let parsed : Result[@syntax.PdfParsedIndirectObject, Error] = try
      pdf_cursor_read_reconstructed_object_at(
        bad_resolved_length_cursor,
        xref.offset,
        bad_resolved_length_xrefs,
      )
    catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
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
    pdf_reader_stream_data_end_before_marker(@ascii.encode("A\r\nendstream"), 3),
    1,
  )
  @test.assert_eq(
    pdf_reader_stream_data_end_before_marker(@ascii.encode("A\rendstream"), 2),
    1,
  )
  @test.assert_eq(
    pdf_reader_stream_data_end_before_marker(@ascii.encode("Aendstream"), 1),
    1,
  )
  let malformed_stream = @core.byte_cursor_of_bytes(
    @ascii.encode("stream\nabc"),
  )
  let malformed_stream_result : Result[@syntax.PdfParsedIndirectObject, Error] = try
    pdf_cursor_finish_malformed_stream_object(malformed_stream, {
      number: 1,
      generation: 0,
      object: PdfDictionary([]),
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_stream_result is Err(@core.PdfError::ParseEndStreamExpected) else {
    fail("expected @core.PdfError::ParseEndStreamExpected")
  }

  let mismatch = @core.byte_cursor_of_bytes(@ascii.encode("abc"))
  let mismatch_result : Result[Unit, Error] = try
    @reader.pdf_cursor_consume_ascii(mismatch, [120], XRefExpected)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard mismatch_result is Err(@core.PdfError::XRefExpected) else {
    fail("expected @core.PdfError::XRefExpected")
  }
}

///|
fn wbtest_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text)[:] {
    output.push(byte)
  }
}

///|
fn wbtest_cyclic_prev_xref_pdf() -> @core.PdfBytes {
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
fn wbtest_hybrid_xrefstm_pdf() -> @core.PdfBytes {
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
  pdf_reader_validate_xref_metadata_for_reconstruction(hybrid)

  let cyclic = try
    pdf_reader_validate_xref_metadata_for_reconstruction(
      wbtest_cyclic_prev_xref_pdf(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard cyclic is Err(XRefExpected) else { fail("expected cyclic Prev guard") }
}

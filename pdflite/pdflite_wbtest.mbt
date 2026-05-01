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
test "writer parses signed integer fragments for scientific reals" {
  @test.assert_eq(
    try! pdf_writer_parse_signed_int(@ascii.encode("+12")[:], 0),
    12,
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
      pdf_writer_stream_data_view(stream_value.data).length(),
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

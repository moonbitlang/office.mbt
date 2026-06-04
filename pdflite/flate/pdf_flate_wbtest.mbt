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
  let reader = FlateBitReader::new(Bytes::new(0))
  let negative_bits : Result[UInt, Error] = try reader.read_bits(-1) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard negative_bits is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let peek_reader = FlateBitReader::new(
    try! @core.pdf_bytes_of_int_array([0xAC, 0x03])[:],
  )
  @test.assert_eq(peek_reader.peek_bits(-1), None)
  @test.assert_eq(peek_reader.peek_bits(4), Some(12))
  @test.assert_eq(peek_reader.peek_bits(12), Some(0x03AC))
  @test.assert_eq(peek_reader.peek_bits(20), None)
  @test.assert_eq(try! peek_reader.read_bits(4), 12)
  @test.assert_eq(pdf_flate_bit_mask(16), 65535)
  @test.assert_eq(pdf_flate_bit_mask(17), 131071)
  let exhausted = FlateBitReader::new(Bytes::new(0))
  let missing_byte : Result[UInt, Error] = try exhausted.read_bits(1) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_byte is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let bad_length : Result[FlateHuffmanTable, Error] = try
    pdf_flate_build_huffman([-1])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_length is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let empty_table : Result[FlateHuffmanTable, Error] = try
    pdf_flate_build_huffman([0])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard empty_table is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let bad_dynamic_symbol : Result[Unit, Error] = try
    pdf_flate_check_dynamic_length_symbol(19)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_dynamic_symbol is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let repeated_lengths = [0]
  let repeated_overflow : Result[Unit, Error] = try
    pdf_flate_push_repeated_lengths(repeated_lengths, 1, 1, 0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard repeated_overflow is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
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
  let bad_flate_length : Result[(Int, Int, Int), Error] = try
    pdf_flate_length_code(259)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_flate_length is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let bad_flate_distance : Result[(Int, Int, Int), Error] = try
    pdf_flate_distance_code(0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_flate_distance is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let shadowed_match = @ascii.encode("ABCDEFGHIJABCXABCDEFGHIJ")
  let last_by_prefix : Array[Int] = Array::make(65536, -1)
  let previous_by_position : Array[Int] = Array::make(
    shadowed_match.length(),
    -1,
  )
  for index in 0..<14 {
    pdf_flate_remember_match_prefix(
      last_by_prefix, previous_by_position, shadowed_match, index,
    )
  }
  let (shadowed_length, shadowed_distance) = pdf_flate_best_previous_match(
    shadowed_match, last_by_prefix, previous_by_position, 14, 64,
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
      deep_last_by_prefix, deep_previous_by_position, deep_match_bytes, index,
    )
  }
  let (shallow_length, _) = pdf_flate_best_previous_match(
    deep_match_bytes, deep_last_by_prefix, deep_previous_by_position, deep_match_position,
    8,
  )
  let (deep_length, deep_distance) = pdf_flate_best_previous_match(
    deep_match_bytes, deep_last_by_prefix, deep_previous_by_position, deep_match_position,
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
    try! pdf_flate_decode_view_prefix(Bytes::new(0)),
    (Bytes::new(0), 0),
  )
  let short_prefix : Result[(Bytes, Int), Error] = try
    pdf_flate_decode_view_prefix(try! @core.pdf_bytes_of_int_array([0x78])[:])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard short_prefix is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let bad_prefix_header : Result[(Bytes, Int), Error] = try
    pdf_flate_decode_view_prefix(
      try! @core.pdf_bytes_of_int_array([0, 0, 0, 0, 0, 0])[:],
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_prefix_header is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
  let truncated_prefix_adler : Result[(Bytes, Int), Error] = try
    pdf_flate_decode_view_prefix(
      try! @core.pdf_bytes_of_int_array([0x78, 0x01, 0x01, 0, 0, 0xFF, 0xFF])[:],
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard truncated_prefix_adler is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }

  let dynamic_repeat_without_previous : Result[
    (FlateHuffmanTable, FlateHuffmanTable),
    Error,
  ] = try
    pdf_flate_read_dynamic_tables(
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
        ]),
      ),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard dynamic_repeat_without_previous is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }

  let distance_lengths : ReadOnlyArray[Int] = [1]
  let distance_table = try! pdf_flate_build_huffman(distance_lengths)
  let invalid_length_lengths = Array::make(287, 0)
  invalid_length_lengths[286] = 1
  let invalid_length_table = try! pdf_flate_build_huffman(
    invalid_length_lengths,
  )
  let invalid_length_output : Array[Byte] = []
  let invalid_length : Result[Unit, Error] = try
    pdf_flate_decode_huffman_block(
      FlateBitReader::new(wbtest_flate_bits([0])),
      invalid_length_table,
      distance_table,
      invalid_length_output,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard invalid_length is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
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
  let invalid_distance : Result[Unit, Error] = try
    pdf_flate_decode_huffman_block(
      FlateBitReader::new(wbtest_flate_bits([0, 0])),
      copy_table,
      invalid_distance_table,
      invalid_distance_output,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard invalid_distance is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }

  let past_output_output : Array[Byte] = []
  let past_output : Result[Unit, Error] = try
    pdf_flate_decode_huffman_block(
      FlateBitReader::new(wbtest_flate_bits([0, 0])),
      copy_table,
      distance_table,
      past_output_output,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard past_output is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData")
  }
}

///|
test "private flate dynamic encoder helpers cover RLE and guards" {
  @test.assert_eq(pdf_flate_huffman_code_lengths([0, 9, 0], 15), [0, 1, 0])
  let no_frequency : Result[Array[Int], Error] = try
    pdf_flate_huffman_code_lengths([0, 0], 15)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard no_frequency is Err(@core.PdfError::InvalidFlateData) else {
    fail(
      "expected @core.PdfError::InvalidFlateData for empty huffman frequencies",
    )
  }
  let negative_frequency : Result[Array[Int], Error] = try
    pdf_flate_huffman_code_lengths([-1], 15)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard negative_frequency is Err(@core.PdfError::InvalidFlateData) else {
    fail(
      "expected @core.PdfError::InvalidFlateData for negative huffman frequency",
    )
  }
  let too_deep : Result[Array[Int], Error] = try
    pdf_flate_huffman_code_lengths([1, 1, 1], 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard too_deep is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData for over-deep huffman tree")
  }
  @test.assert_eq(pdf_flate_canonical_codes([1, 2, 2]), [0, 2, 3])
  @test.assert_eq(pdf_flate_last_nonzero_length([0, 0]), -1)
  @test.assert_eq(pdf_flate_last_nonzero_length([0, 3, 0]), 1)
  @test.assert_eq(pdf_flate_trim_length_count([0, 0, 2, 0], 2), 3)
  @test.assert_eq(pdf_flate_trim_length_count([0, 0], 4), 4)

  let zero_tokens = pdf_flate_code_length_tokens(Array::make(150, 0))
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
  @test.assert_eq(pdf_flate_code_length_frequencies(repeat_tokens)[16], 1)
  let order = pdf_flate_code_length_order()
  @test.assert_eq(order[0], 16)
  @test.assert_eq(pdf_flate_code_length_order_count(Array::make(19, 0)), 4)
  let order_lengths = Array::make(19, 0)
  order_lengths[15] = 1
  @test.assert_eq(pdf_flate_code_length_order_count(order_lengths), 19)

  let literal_tokens : Array[PdfFlateToken] = [PdfFlateLiteral(65)]
  let (literal_frequencies, distance_frequencies) = try! pdf_flate_count_dynamic_frequencies(
    literal_tokens,
  )
  @test.assert_eq(literal_frequencies[65], 1)
  @test.assert_eq(literal_frequencies[256], 1)
  @test.assert_eq(distance_frequencies[0], 1)
  let match_tokens : Array[PdfFlateToken] = [PdfFlateLengthDistance(3, 1)]
  let (match_frequencies, match_distance_frequencies) = try! pdf_flate_count_dynamic_frequencies(
    match_tokens,
  )
  @test.assert_eq(match_frequencies[257], 1)
  @test.assert_eq(match_distance_frequencies[0], 1)
  let data = @ascii.encode("ABCDABCDABCD")
  let tokens = pdf_flate_match_tokens(data, 64)
  guard tokens[4] is PdfFlateLengthDistance(length, distance) else {
    fail("expected a length-distance token")
  }
  @test.assert_eq(length >= 3, true)
  @test.assert_eq(distance, 4)

  let output : Array[Byte] = []
  let writer = FlateBitWriter::new(output)
  let missing_symbol : Result[Unit, Error] = try
    pdf_flate_write_canonical_symbol(writer, 0, [0], [0])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_symbol is Err(@core.PdfError::InvalidFlateData) else {
    fail(
      "expected @core.PdfError::InvalidFlateData for missing canonical symbol",
    )
  }
  let empty_dynamic : Result[Unit, Error] = try
    pdf_flate_push_dynamic_match_block([], Bytes::new(0), true, 64)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard empty_dynamic is Err(@core.PdfError::InvalidFlateData) else {
    fail("expected @core.PdfError::InvalidFlateData for empty dynamic block")
  }
}

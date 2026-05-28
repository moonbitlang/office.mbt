///|
priv struct PdfFlateCodeLengthToken {
  symbol : Int
  extra : Int
  extra_width : Int
}

///|
fn pdf_flate_last_nonzero_length(lengths : ArrayView[Int]) -> Int {
  let mut index = lengths.length() - 1
  while index >= 0 {
    if lengths[index] != 0 {
      return index
    }
    index -= 1
  }
  -1
}

///|
fn pdf_flate_push_code_length_token(
  output : Array[PdfFlateCodeLengthToken],
  symbol : Int,
  extra? : Int = 0,
  extra_width? : Int = 0,
) -> Unit {
  output.push({ symbol, extra, extra_width })
}

///|
fn pdf_flate_code_length_tokens(
  lengths : ArrayView[Int],
) -> Array[PdfFlateCodeLengthToken] {
  let tokens : Array[PdfFlateCodeLengthToken] = Array::new(
    capacity=lengths.length(),
  )
  let mut index = 0
  while index < lengths.length() {
    let value = lengths[index]
    let mut run = 1
    while index + run < lengths.length() && lengths[index + run] == value {
      run += 1
    }
    if value == 0 {
      let mut remaining = run
      while remaining >= 11 {
        let count = if remaining > 138 { 138 } else { remaining }
        pdf_flate_push_code_length_token(
          tokens,
          18,
          extra=count - 11,
          extra_width=7,
        )
        remaining -= count
      }
      if remaining >= 3 {
        pdf_flate_push_code_length_token(
          tokens,
          17,
          extra=remaining - 3,
          extra_width=3,
        )
      } else {
        for _ in 0..<remaining {
          pdf_flate_push_code_length_token(tokens, 0)
        }
      }
    } else {
      pdf_flate_push_code_length_token(tokens, value)
      let mut remaining = run - 1
      while remaining >= 3 {
        let count = if remaining > 6 { 6 } else { remaining }
        pdf_flate_push_code_length_token(
          tokens,
          16,
          extra=count - 3,
          extra_width=2,
        )
        remaining -= count
      }
      for _ in 0..<remaining {
        pdf_flate_push_code_length_token(tokens, value)
      }
    }
    index += run
  }
  tokens
}

///|
fn pdf_flate_code_length_frequencies(
  tokens : ArrayView[PdfFlateCodeLengthToken],
) -> Array[Int] {
  let frequencies : Array[Int] = Array::make(19, 0)
  for token in tokens {
    frequencies[token.symbol] += 1
  }
  frequencies
}

///|
fn pdf_flate_code_length_order() -> Array[Int] {
  [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
}

///|
fn pdf_flate_code_length_order_count(
  code_length_lengths : ArrayView[Int],
) -> Int {
  let order = pdf_flate_code_length_order()
  let mut count = order.length()
  while count > 4 && code_length_lengths[order[count - 1]] == 0 {
    count -= 1
  }
  count
}

///|
fn pdf_flate_count_dynamic_frequencies(
  tokens : ArrayView[PdfFlateToken],
) -> (Array[Int], Array[Int]) raise @core.PdfError {
  let literal_frequencies : Array[Int] = Array::make(286, 0)
  let distance_frequencies : Array[Int] = Array::make(30, 0)
  literal_frequencies[256] = 1
  let mut has_distance = false
  for token in tokens {
    match token {
      PdfFlateLiteral(byte) => literal_frequencies[byte] += 1
      PdfFlateLengthDistance(length, distance) => {
        let (length_symbol, _, _) = pdf_flate_length_code(length)
        let (distance_symbol, _, _) = pdf_flate_distance_code(distance)
        literal_frequencies[length_symbol] += 1
        distance_frequencies[distance_symbol] += 1
        has_distance = true
      }
    }
  }
  if !has_distance {
    distance_frequencies[0] = 1
  }
  (literal_frequencies, distance_frequencies)
}

///|
fn pdf_flate_trim_length_count(lengths : ArrayView[Int], minimum : Int) -> Int {
  let last = pdf_flate_last_nonzero_length(lengths)
  let count = last + 1
  if count < minimum {
    minimum
  } else {
    count
  }
}

///|
fn pdf_flate_write_code_length_tokens(
  writer : FlateBitWriter,
  tokens : ArrayView[PdfFlateCodeLengthToken],
  codes : ArrayView[Int],
  lengths : ArrayView[Int],
) -> Unit raise @core.PdfError {
  for token in tokens {
    pdf_flate_write_canonical_symbol(writer, token.symbol, codes, lengths)
    writer.write_bits(token.extra.reinterpret_as_uint(), token.extra_width)
  }
}

///|
fn pdf_flate_write_dynamic_tokens(
  writer : FlateBitWriter,
  tokens : ArrayView[PdfFlateToken],
  literal_codes : ArrayView[Int],
  literal_lengths : ArrayView[Int],
  distance_codes : ArrayView[Int],
  distance_lengths : ArrayView[Int],
) -> Unit raise @core.PdfError {
  for token in tokens {
    match token {
      PdfFlateLiteral(byte) =>
        pdf_flate_write_canonical_symbol(
          writer, byte, literal_codes, literal_lengths,
        )
      PdfFlateLengthDistance(length, distance) => {
        let (length_symbol, length_extra, length_extra_width) = pdf_flate_length_code(
          length,
        )
        pdf_flate_write_canonical_symbol(
          writer, length_symbol, literal_codes, literal_lengths,
        )
        writer.write_bits(
          length_extra.reinterpret_as_uint(),
          length_extra_width,
        )
        let (distance_symbol, distance_extra, distance_extra_width) = pdf_flate_distance_code(
          distance,
        )
        pdf_flate_write_canonical_symbol(
          writer, distance_symbol, distance_codes, distance_lengths,
        )
        writer.write_bits(
          distance_extra.reinterpret_as_uint(),
          distance_extra_width,
        )
      }
    }
  }
  pdf_flate_write_canonical_symbol(writer, 256, literal_codes, literal_lengths)
}

///|
fn pdf_flate_push_dynamic_match_block(
  output : Array[Byte],
  data : BytesView,
  final_block : Bool,
  max_probes : Int,
) -> Unit raise @core.PdfError {
  guard data.length() > 0 else { raise InvalidFlateData }
  let tokens = pdf_flate_match_tokens(data, max_probes)
  let (literal_frequencies, distance_frequencies) = pdf_flate_count_dynamic_frequencies(
    tokens,
  )
  let literal_lengths = pdf_flate_huffman_code_lengths(literal_frequencies, 15)
  let distance_lengths = pdf_flate_huffman_code_lengths(
    distance_frequencies, 15,
  )
  let literal_count = pdf_flate_trim_length_count(literal_lengths, 257)
  let distance_count = pdf_flate_trim_length_count(distance_lengths, 1)
  let header_lengths : Array[Int] = Array::new(
    capacity=literal_count + distance_count,
  )
  for length in literal_lengths[:literal_count] {
    header_lengths.push(length)
  }
  for length in distance_lengths[:distance_count] {
    header_lengths.push(length)
  }
  let code_length_tokens = pdf_flate_code_length_tokens(header_lengths)
  let code_length_frequencies = pdf_flate_code_length_frequencies(
    code_length_tokens,
  )
  let code_length_lengths = pdf_flate_huffman_code_lengths(
    code_length_frequencies, 7,
  )
  let code_length_codes = pdf_flate_canonical_codes(code_length_lengths)
  let literal_codes = pdf_flate_canonical_codes(literal_lengths)
  let distance_codes = pdf_flate_canonical_codes(distance_lengths)
  let writer = FlateBitWriter::new(output)
  writer.write_bits(if final_block { 1 } else { 0 }, 1)
  writer.write_bits(2, 2)
  writer.write_bits((literal_count - 257).reinterpret_as_uint(), 5)
  writer.write_bits((distance_count - 1).reinterpret_as_uint(), 5)
  let code_length_count = pdf_flate_code_length_order_count(code_length_lengths)
  writer.write_bits((code_length_count - 4).reinterpret_as_uint(), 4)
  let order = pdf_flate_code_length_order()
  for index in 0..<code_length_count {
    writer.write_bits(
      code_length_lengths[order[index]].reinterpret_as_uint(),
      3,
    )
  }
  pdf_flate_write_code_length_tokens(
    writer, code_length_tokens, code_length_codes, code_length_lengths,
  )
  pdf_flate_write_dynamic_tokens(
    writer, tokens, literal_codes, literal_lengths, distance_codes, distance_lengths,
  )
  writer.finish()
}

///|
fn pdf_flate_encode_dynamic_match_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
  max_probes : Int,
) -> @core.PdfBytes raise @core.PdfError {
  let output = pdf_flate_output_with_header(header, data.length() + 8)
  pdf_flate_push_dynamic_match_block(output, data, true, max_probes)
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

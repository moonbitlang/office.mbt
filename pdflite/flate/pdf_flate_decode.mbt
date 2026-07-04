///|
fn pdf_flate_check_dynamic_length_symbol(
  symbol : Int,
) -> Unit raise @core.PdfError {
  if symbol < 0 || symbol > 18 {
    raise InvalidFlateData
  }
}

///|
fn pdf_flate_push_repeated_lengths(
  lengths : Array[Int],
  total : Int,
  repeat : Int,
  value : Int,
) -> Unit raise @core.PdfError {
  for _ in 0..<repeat {
    if lengths.length() >= total {
      raise InvalidFlateData
    }
    lengths.push(value)
  }
}

///|
fn pdf_flate_read_dynamic_tables(
  reader : FlateBitReader,
) -> (FlateHuffmanTable, FlateHuffmanTable) raise @core.PdfError {
  let hlit = reader.read_bits(5).reinterpret_as_int() + 257
  let hdist = reader.read_bits(5).reinterpret_as_int() + 1
  let hclen = reader.read_bits(4).reinterpret_as_int() + 4
  let order : ReadOnlyArray[Int] = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  let code_lengths : Array[Int] = Array::make(19, 0)
  for i in 0..<hclen {
    code_lengths[order[i]] = reader.read_bits(3).reinterpret_as_int()
  }
  let code_table = pdf_flate_build_huffman(code_lengths)
  let total = hlit + hdist
  let lengths : Array[Int] = []
  while lengths.length() < total {
    let symbol = pdf_flate_decode_symbol(reader, code_table)
    pdf_flate_check_dynamic_length_symbol(symbol)
    if symbol <= 15 {
      lengths.push(symbol)
    } else if symbol == 16 {
      if lengths.length() == 0 {
        raise InvalidFlateData
      }
      let repeat = reader.read_bits(2).reinterpret_as_int() + 3
      let previous = lengths[lengths.length() - 1]
      pdf_flate_push_repeated_lengths(lengths, total, repeat, previous)
    } else if symbol == 17 {
      let repeat = reader.read_bits(3).reinterpret_as_int() + 3
      pdf_flate_push_repeated_lengths(lengths, total, repeat, 0)
    } else {
      let repeat = reader.read_bits(7).reinterpret_as_int() + 11
      pdf_flate_push_repeated_lengths(lengths, total, repeat, 0)
    }
  }
  let literal_lengths = lengths[:hlit]
  let distance_lengths = lengths[hlit:hlit + hdist]
  (
    pdf_flate_build_huffman(literal_lengths),
    pdf_flate_build_huffman(distance_lengths),
  )
}

///|
/// Default cap for decompressed output, guarding against decompression bombs.
let pdf_flate_max_output_default : Int = 1 << 30

///|
fn pdf_flate_decode_huffman_block(
  reader : FlateBitReader,
  literal_table : FlateHuffmanTable,
  distance_table : FlateHuffmanTable,
  output : Array[Byte],
  max_output? : Int = pdf_flate_max_output_default,
) -> Unit raise @core.PdfError {
  let mut done = false
  while !done {
    let symbol = pdf_flate_decode_symbol(reader, literal_table)
    if symbol < 256 {
      if output.length() >= max_output {
        raise FlateOutputLimitExceeded(max_output)
      }
      output.push(symbol.to_byte())
    } else if symbol == 256 {
      done = true
    } else {
      let length_index = symbol - 257
      if length_index < 0 || length_index >= pdf_flate_length_base.length() {
        raise InvalidFlateData
      }
      let extra_length = pdf_flate_length_extra[length_index]
      let length = pdf_flate_length_base[length_index] +
        reader.read_bits(extra_length).reinterpret_as_int()
      let distance_symbol = pdf_flate_decode_symbol(reader, distance_table)
      if distance_symbol < 0 ||
        distance_symbol >= pdf_flate_distance_base.length() {
        raise InvalidFlateData
      }
      let distance = pdf_flate_distance_base[distance_symbol] +
        reader
        .read_bits(pdf_flate_distance_extra[distance_symbol])
        .reinterpret_as_int()
      if distance <= 0 || distance > output.length() {
        raise InvalidFlateData
      }
      if length > max_output - output.length() {
        raise FlateOutputLimitExceeded(max_output)
      }
      for _ in 0..<length {
        let value = output[output.length() - distance]
        output.push(value)
      }
    }
  }
}

///|
fn pdf_deflate_decode_raw_prefix(
  bytes : BytesView,
  max_output? : Int = pdf_flate_max_output_default,
) -> (@core.PdfBytes, Int) raise @core.PdfError {
  let reader = FlateBitReader::new(bytes)
  let output : Array[Byte] = Array::new(capacity=bytes.length())
  let mut finished = false
  while !finished {
    let final_block = reader.read_bits(1)
    let block_type = reader.read_bits(2)
    match block_type {
      0 => {
        reader.align_byte()
        let length = reader.read_bits(16).reinterpret_as_int()
        let nlength = reader.read_bits(16)
        if (length.reinterpret_as_uint() ^ nlength) != 0xFFFF {
          raise InvalidFlateData
        }
        if length > max_output - output.length() {
          raise FlateOutputLimitExceeded(max_output)
        }
        for _ in 0..<length {
          output.push(reader.read_byte())
        }
      }
      1 => {
        let literal = pdf_flate_fixed_literal_table()
        let distance = pdf_flate_fixed_distance_table()
        pdf_flate_decode_huffman_block(
          reader,
          literal,
          distance,
          output,
          max_output~,
        )
      }
      2 => {
        let (literal, distance) = pdf_flate_read_dynamic_tables(reader)
        pdf_flate_decode_huffman_block(
          reader,
          literal,
          distance,
          output,
          max_output~,
        )
      }
      _ => raise InvalidFlateData
    }
    finished = final_block == 1
  }
  (Bytes::from_array(output), reader.byte_pos)
}

///|
fn pdf_deflate_decode_raw(
  bytes : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let (decoded, _) = pdf_deflate_decode_raw_prefix(bytes)
  decoded
}

///|
fn pdf_flate_decode_view_pure(
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  if data.length() == 0 {
    Bytes::new(0)
  } else {
    if data.length() < 6 {
      raise InvalidFlateData
    }
    let cmf = data[0].to_int()
    let flg = data[1].to_int()
    if (cmf & 0x0F) != 8 || ((cmf << 8) + flg) % 31 != 0 || (flg & 0x20) != 0 {
      raise InvalidFlateData
    }
    let decoded = pdf_deflate_decode_raw(data[2:data.length() - 4])
    pdf_flate_check_adler32(data, decoded)
    decoded
  }
}

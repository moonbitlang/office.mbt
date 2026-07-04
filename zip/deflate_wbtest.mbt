///|
test "deflate stored block" {
  let stream : Bytes = [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x68, 0x69]
  inspect(
    deflate_decode(stream),
    content=(
      #|b"hi"
    ),
  )
}

///|
test "deflate fixed huffman" {
  let stream : Bytes = [0xCB, 0x48, 0xCD, 0xC9, 0xC9, 0x07, 0x00]
  inspect(
    deflate_decode(stream),
    content=(
      #|b"hello"
    ),
  )
}

///|
test "deflate dynamic huffman" {
  let stream : Bytes = [
    0xED, 0xCA, 0xC9, 0x01, 0x82, 0x40, 0x10, 0x00, 0xB0, 0x56, 0xA6, 0xA8, 0x6D,
    0xC0, 0x03, 0xF0, 0x40, 0x06, 0x56, 0x17, 0xD4, 0xEA, 0xB1, 0x04, 0x0B, 0xC8,
    0x3B, 0x29, 0x97, 0x2E, 0x96, 0x76, 0x3D, 0xDD, 0xE3, 0x58, 0x73, 0x9B, 0xA2,
    0xCF, 0x77, 0xDC, 0xDA, 0x63, 0x7E, 0x46, 0xAE, 0x5D, 0x8D, 0xD7, 0x8F, 0xC7,
    0xC3, 0xF7, 0x13, 0xE7, 0x1C, 0x8A, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
    0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
    0xAA, 0xAA, 0xAA, 0xAA, 0xFA, 0x7F, 0xDD, 0x01,
  ]
  let phrase : Bytes = b"The quick brown fox jumps over the lazy dog"
  let expected_array : Array[Byte] = []
  for _ in 0..<200 {
    for b in phrase {
      expected_array.push(b)
    }
  }
  let expected = Bytes::from_array(expected_array)
  inspect(deflate_decode(stream) == expected, content="true")
}

///|
test "deflate encode fixed literals" {
  let data : Bytes = b"MoonBit deflate"
  let compressed = deflate_encode(data)
  inspect(deflate_decode(compressed) == data, content="true")
}

///|
test "deflate encode lz77 matches" {
  let data_array : Array[Byte] = []
  for _ in 0..<1024 {
    data_array.push(b'A')
  }
  let data = Bytes::from_array(data_array)
  let compressed = deflate_encode(data)
  inspect(deflate_decode(compressed) == data, content="true")
  inspect(compressed.length() < data.length(), content="true")
}

///|
fn wb_single_symbol_table(symbol : Int) -> HuffmanTable {
  { max_bits: 1, sym: [symbol, symbol], len: [1, 1] }
}

///|
test "deflate wb: direct guard error branches" {
  let reader = BitReader::new(b"")
  try reader.ensure_bits(-1) catch {
    e => inspect(e is ZipError::OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected ensure_bits to raise")
  }
  try length_to_symbol(2) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected length_to_symbol to raise")
  }
  try distance_to_symbol(0) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected distance_to_symbol to raise")
  }
  try build_huffman([16]) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected build_huffman to raise")
  }
  let writer = BitWriter::new()
  try writer.write_bits(1, -1) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected write_bits to raise")
  }
  try fixed_literal_code(288) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected fixed_literal_code to raise")
  }
}

///|
test "deflate wb: find_match distance cap branch" {
  let raw : Array[Byte] = Array::make(33010, (0x00).to_byte())
  let bytes = Bytes::from_array(raw)
  let head : Array[Int] = Array::make(1 << 15, -1)
  let prev : Array[Int] = Array::make(bytes.length(), -1)
  let pos = 33000
  let h = hash3(bytes, pos)
  head[h] = 0
  debug_inspect(find_match(bytes, pos, head, prev), content="(0, 0)")
}

///|
test "deflate wb: dynamic table repeat-without-previous branch" {
  let writer = BitWriter::new()
  // hlit=257, hdist=1, hclen=4
  ignore(writer.write_bits(0, 5))
  ignore(writer.write_bits(0, 5))
  ignore(writer.write_bits(0, 4))
  // code-length alphabet lengths for [16, 17, 18, 0]
  ignore(writer.write_bits(1, 3))
  ignore(writer.write_bits(0, 3))
  ignore(writer.write_bits(0, 3))
  ignore(writer.write_bits(0, 3))
  // first decoded symbol from code-length table: 16
  ignore(writer.write_bits(0, 1))
  let reader = BitReader::new(writer.finish())
  try read_dynamic_tables(reader) catch {
    ZipError::UnsupportedFeature(msg~) =>
      inspect(msg, content="repeat with no previous length")
    _ => fail("expected repeat-with-no-previous-length error")
  } noraise {
    _ => fail("expected repeat-with-no-previous-length error")
  }
}

///|
test "deflate wb: decode_huffman_block validation branches" {
  let zero_reader = BitReader::new(b"\x00")

  try
    decode_huffman_block(
      zero_reader,
      wb_single_symbol_table(286),
      wb_single_symbol_table(0),
      [],
    )
  catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected decode_huffman_block to raise")
  }
  try
    decode_huffman_block(
      BitReader::new(b"\x00"),
      wb_single_symbol_table(257),
      wb_single_symbol_table(30),
      [],
    )
  catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected decode_huffman_block to raise")
  }
  try
    decode_huffman_block(
      BitReader::new(b"\x00"),
      wb_single_symbol_table(257),
      wb_single_symbol_table(0),
      [],
    )
  catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected decode_huffman_block to raise")
  }
}

///|
test "deflate decode enforces max_output for stored blocks" {
  // Stored block declaring 2 bytes ("hi") against a cap of 1.
  let stream : Bytes = [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x68, 0x69]
  try deflate_decode(stream, max_output=1) catch {
    ZipError::OutputLimitExceeded(limit~) => inspect(limit, content="1")
    _ => fail("expected OutputLimitExceeded")
  } noraise {
    _ => fail("expected deflate_decode to raise")
  }
}

///|
test "deflate decode enforces max_output for huffman literals" {
  // Fixed-Huffman block decoding to "hello" against a cap of 4.
  let stream : Bytes = [0xCB, 0x48, 0xCD, 0xC9, 0xC9, 0x07, 0x00]
  try deflate_decode(stream, max_output=4) catch {
    ZipError::OutputLimitExceeded(limit~) => inspect(limit, content="4")
    _ => fail("expected OutputLimitExceeded")
  } noraise {
    _ => fail("expected deflate_decode to raise")
  }
}

///|
test "deflate decode enforces max_output for back-references" {
  let data : Array[Byte] = []
  for _ in 0..<400 {
    data.push(b'a')
  }
  let compressed = deflate_encode(Bytes::from_array(data))
  try deflate_decode(compressed, max_output=100) catch {
    ZipError::OutputLimitExceeded(limit~) => inspect(limit, content="100")
    _ => fail("expected OutputLimitExceeded")
  } noraise {
    _ => fail("expected deflate_decode to raise")
  }
}

///|
test "deflate wb: build_huffman rejects oversubscribed length sets" {
  // Lengths [1, 2, 1] violate the Kraft inequality (two 1-bit codes leave no
  // room for a 2-bit code). The flat lookup table would let the colliding
  // canonical codes overwrite one another and decode bit pattern `10` as
  // symbol 0, where a strict decoder rejects the table outright.
  try build_huffman([1, 2, 1]) catch {
    ZipError::UnsupportedFeature(msg~) =>
      inspect(msg, content="oversubscribed huffman table")
    _ => fail("expected UnsupportedFeature")
  } noraise {
    _ => fail("expected build_huffman to raise")
  }
  // Incomplete sets (Kraft sum < 1) remain accepted, as before: a lone
  // 2-bit code builds fine.
  let table = try! build_huffman([2])
  inspect(table.max_bits, content="2")
}

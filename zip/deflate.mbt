///|
priv struct BitReader {
  bytes : BytesView
  mut byte_pos : Int
  mut bit_buf : UInt
  mut bit_count : Int
}

///|
fn BitReader::new(bytes : BytesView) -> BitReader {
  { bytes, byte_pos: 0, bit_buf: 0, bit_count: 0 }
}

///|
fn BitReader::ensure_bits(self : BitReader, count : Int) -> Unit raise ZipError {
  if count < 0 {
    raise ZipError::OutOfBounds(offset=self.byte_pos)
  }
  while self.bit_count < count {
    if self.byte_pos >= self.bytes.length() || self.byte_pos < 0 {
      raise ZipError::OutOfBounds(offset=self.byte_pos)
    }
    let byte = self.bytes[self.byte_pos].to_uint()
    self.bit_buf = self.bit_buf | (byte << self.bit_count)
    self.bit_count = self.bit_count + 8
    self.byte_pos = self.byte_pos + 1
  }
}

///|
fn BitReader::read_bits(self : BitReader, count : Int) -> UInt raise ZipError {
  self.ensure_bits(count)
  let mask = bit_mask(count)
  let value = self.bit_buf & mask
  self.bit_buf = self.bit_buf >> count
  self.bit_count = self.bit_count - count
  value
}

///|
fn BitReader::drop_bits(self : BitReader, count : Int) -> Unit raise ZipError {
  self.ensure_bits(count)
  self.bit_buf = self.bit_buf >> count
  self.bit_count = self.bit_count - count
}

///|
fn BitReader::align_byte(self : BitReader) -> Unit raise ZipError {
  let drop = self.bit_count % 8
  if drop != 0 {
    self.drop_bits(drop)
  }
}

///|
fn BitReader::read_byte(self : BitReader) -> Byte raise ZipError {
  self.read_bits(8).to_byte()
}

///|
fn bit_mask(count : Int) -> UInt {
  let mut mask : UInt = 0
  for _ in 0..<count {
    mask = (mask << 1) | 1
  }
  mask
}

///|
fn reverse_bits(value : UInt, bits : Int) -> UInt {
  let mut v = value
  let mut result : UInt = 0
  for _ in 0..<bits {
    result = (result << 1) | (v & 1)
    v = v >> 1
  }
  result
}

///|
priv struct HuffmanTable {
  max_bits : Int
  sym : Array[Int]
  len : Array[Int]
}

///|
fn build_huffman(lengths : ArrayView[Int]) -> HuffmanTable raise ZipError {
  let mut max_bits = 0
  for len in lengths {
    if len < 0 || len > 15 {
      raise ZipError::UnsupportedFeature(msg="invalid huffman length")
    }
    if len > max_bits {
      max_bits = len
    }
  }
  if max_bits == 0 {
    raise ZipError::UnsupportedFeature(msg="empty huffman table")
  }
  let counts : Array[Int] = Array::make(max_bits + 1, 0)
  for len in lengths {
    if len > 0 {
      counts[len] = counts[len] + 1
    }
  }
  let next_code : Array[Int] = Array::make(max_bits + 1, 0)
  let mut code = 0
  for bits in 1..<=max_bits {
    code = (code + counts[bits - 1]) << 1
    next_code[bits] = code
  }
  let size = 1 << max_bits
  let sym : Array[Int] = Array::make(size, -1)
  let len_table : Array[Int] = Array::make(size, 0)
  for symbol, length in lengths {
    if length == 0 {
      continue
    }
    let curr = next_code[length]
    next_code[length] = curr + 1
    let rev = reverse_bits(curr.reinterpret_as_uint(), length).reinterpret_as_int()
    let fill = 1 << (max_bits - length)
    for i in 0..<fill {
      let idx = rev | (i << length)
      sym[idx] = symbol
      len_table[idx] = length
    }
  }
  { max_bits, sym, len: len_table }
}

///|
fn decode_symbol(
  reader : BitReader,
  table : HuffmanTable,
) -> Int raise ZipError {
  let mut code : UInt = 0
  for len in 1..<=table.max_bits {
    let bit = reader.read_bits(1)
    code = code | (bit << (len - 1))
    let idx = code.reinterpret_as_int()
    if table.len[idx] == len {
      return table.sym[idx]
    }
  }
  raise ZipError::UnsupportedFeature(msg="invalid huffman code")
}

///|
fn fixed_literal_table() -> HuffmanTable raise ZipError {
  let lengths : Array[Int] = []
  for i in 0..<=287 {
    if i <= 143 {
      lengths.push(8)
    } else if i <= 255 {
      lengths.push(9)
    } else if i <= 279 {
      lengths.push(7)
    } else {
      lengths.push(8)
    }
  }
  build_huffman(lengths)
}

///|
fn fixed_distance_table() -> HuffmanTable raise ZipError {
  let lengths : Array[Int] = []
  for _ in 0..<=31 {
    lengths.push(5)
  }
  build_huffman(lengths)
}

///|
fn read_dynamic_tables(
  reader : BitReader,
) -> (HuffmanTable, HuffmanTable) raise ZipError {
  let hlit = reader.read_bits(5).reinterpret_as_int() + 257
  let hdist = reader.read_bits(5).reinterpret_as_int() + 1
  let hclen = reader.read_bits(4).reinterpret_as_int() + 4
  let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
  let code_lengths : Array[Int] = Array::make(19, 0)
  for i in 0..<hclen {
    code_lengths[order[i]] = reader.read_bits(3).reinterpret_as_int()
  }
  let code_table = build_huffman(code_lengths)
  let total = hlit + hdist
  let lengths : Array[Int] = []
  while lengths.length() < total {
    let symbol = decode_symbol(reader, code_table)
    if symbol <= 15 {
      lengths.push(symbol)
    } else if symbol == 16 {
      if lengths.length() == 0 {
        raise ZipError::UnsupportedFeature(msg="repeat with no previous length")
      }
      let repeat = reader.read_bits(2).reinterpret_as_int() + 3
      let prev = lengths[lengths.length() - 1]
      for _ in 0..<repeat {
        lengths.push(prev)
      }
    } else if symbol == 17 {
      let repeat = reader.read_bits(3).reinterpret_as_int() + 3
      for _ in 0..<repeat {
        lengths.push(0)
      }
    } else if symbol == 18 {
      let repeat = reader.read_bits(7).reinterpret_as_int() + 11
      for _ in 0..<repeat {
        lengths.push(0)
      }
    } else {
      raise ZipError::UnsupportedFeature(msg="invalid code length symbol")
    }
  }
  let lit_lengths = lengths[:hlit]
  let dist_lengths = lengths[hlit:hlit + hdist]
  (build_huffman(lit_lengths), build_huffman(dist_lengths))
}

///|
fn decode_huffman_block(
  reader : BitReader,
  lit_table : HuffmanTable,
  dist_table : HuffmanTable,
  out : Array[Byte],
) -> Unit raise ZipError {
  let length_base = [
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67,
    83, 99, 115, 131, 163, 195, 227, 258,
  ]
  let length_extra = [
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5,
    5, 5, 0,
  ]
  let dist_base = [
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
    1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
  ]
  let dist_extra = [
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11,
    11, 12, 12, 13, 13,
  ]
  loop true {
    false => ()
    true => {
      let symbol = decode_symbol(reader, lit_table)
      if symbol < 256 {
        out.push(symbol.to_byte())
        continue true
      }
      if symbol == 256 {
        continue false
      }
      let length_idx = symbol - 257
      if length_idx < 0 || length_idx >= length_base.length() {
        raise ZipError::UnsupportedFeature(msg="invalid length symbol")
      }
      let extra_len = length_extra[length_idx]
      let length = length_base[length_idx] +
        reader.read_bits(extra_len).reinterpret_as_int()
      let dist_symbol = decode_symbol(reader, dist_table)
      if dist_symbol < 0 || dist_symbol >= dist_base.length() {
        raise ZipError::UnsupportedFeature(msg="invalid distance symbol")
      }
      let dist = dist_base[dist_symbol] +
        reader.read_bits(dist_extra[dist_symbol]).reinterpret_as_int()
      if dist <= 0 || dist > out.length() {
        raise ZipError::UnsupportedFeature(
          msg="invalid back-reference distance",
        )
      }
      for _ in 0..<length {
        let value = out[out.length() - dist]
        out.push(value)
      }
      continue true
    }
  }
}

///|
priv struct BitWriter {
  mut bit_buf : UInt
  mut bit_count : Int
  out : Array[Byte]
}

///|
fn BitWriter::new() -> BitWriter {
  { bit_buf: 0, bit_count: 0, out: [] }
}

///|
fn BitWriter::write_bits(
  self : BitWriter,
  value : Int,
  count : Int,
) -> Unit raise ZipError {
  if count < 0 {
    raise ZipError::UnsupportedFeature(msg="negative bit count")
  }
  for i in 0..<count {
    let bit = (value >> i) & 1
    self.bit_buf = self.bit_buf | (bit.reinterpret_as_uint() << self.bit_count)
    self.bit_count = self.bit_count + 1
    if self.bit_count == 8 {
      self.out.push(self.bit_buf.to_byte())
      self.bit_buf = 0
      self.bit_count = 0
    }
  }
}

///|
fn BitWriter::finish(self : BitWriter) -> Bytes {
  if self.bit_count > 0 {
    self.out.push(self.bit_buf.to_byte())
  }
  Bytes::from_array(self.out)
}

///|
fn fixed_literal_code(symbol : Int) -> (Int, Int) raise ZipError {
  if symbol < 0 || symbol > 287 {
    raise ZipError::UnsupportedFeature(msg="invalid fixed literal symbol")
  }
  if symbol <= 143 {
    (symbol + 0x30, 8)
  } else if symbol <= 255 {
    (symbol - 144 + 0x190, 9)
  } else if symbol <= 279 {
    (symbol - 256, 7)
  } else {
    (symbol - 280 + 0xC0, 8)
  }
}

///|
fn deflate_encode(bytes : BytesView) -> Bytes raise ZipError {
  let writer = BitWriter::new()
  writer.write_bits(1, 1)
  writer.write_bits(1, 2)
  for b in bytes {
    let (code, len) = fixed_literal_code(b.to_int())
    let rev = reverse_bits(code.reinterpret_as_uint(), len).reinterpret_as_int()
    writer.write_bits(rev, len)
  }
  let (end_code, end_len) = fixed_literal_code(256)
  let end_rev = reverse_bits(end_code.reinterpret_as_uint(), end_len).reinterpret_as_int()
  writer.write_bits(end_rev, end_len)
  writer.finish()
}

///|
fn deflate_decode(bytes : BytesView) -> Bytes raise ZipError {
  let reader = BitReader::new(bytes)
  let out : Array[Byte] = []
  loop false {
    true => ()
    false => {
      let bfinal = reader.read_bits(1)
      let btype = reader.read_bits(2)
      match btype {
        0 => {
          reader.align_byte()
          let len = reader.read_bits(16).reinterpret_as_int()
          let nlen = reader.read_bits(16)
          if (len.reinterpret_as_uint() ^ nlen) != 0xFFFF {
            raise ZipError::UnsupportedFeature(
              msg="invalid stored block length",
            )
          }
          for _ in 0..<len {
            out.push(reader.read_byte())
          }
        }
        1 => {
          let lit = fixed_literal_table()
          let dist = fixed_distance_table()
          decode_huffman_block(reader, lit, dist, out)
        }
        2 => {
          let (lit, dist) = read_dynamic_tables(reader)
          decode_huffman_block(reader, lit, dist, out)
        }
        _ =>
          raise ZipError::UnsupportedFeature(msg="invalid deflate block type")
      }
      continue bfinal == 1
    }
  }
  Bytes::from_array(out)
}

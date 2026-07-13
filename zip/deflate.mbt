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
    raise OutOfBounds(offset=self.byte_pos)
  }
  while self.bit_count < count {
    if self.byte_pos >= self.bytes.length() || self.byte_pos < 0 {
      raise OutOfBounds(offset=self.byte_pos)
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
/// Fill the bit buffer with up to `count` bits and return them without
/// consuming any. Near the end of input fewer bits may remain; missing high
/// bits are zero-padded, and `self.bit_count` reflects how many bits are
/// actually available. `count` must be in `0..=15`.
fn BitReader::peek_bits(self : BitReader, count : Int) -> UInt {
  while self.bit_count < count && self.byte_pos < self.bytes.length() {
    let byte = self.bytes[self.byte_pos].to_uint()
    self.bit_buf = self.bit_buf | (byte << self.bit_count)
    self.bit_count = self.bit_count + 8
    self.byte_pos = self.byte_pos + 1
  }
  self.bit_buf & bit_mask(count)
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
fn BitReader::consumed_bytes(self : BitReader) -> Int {
  // Huffman lookup may prefetch complete trailing bytes into `bit_buf`.
  // Subtract those unread full bytes without multiplying positions by eight,
  // which also keeps this safe for inputs near the Int size ceiling.
  self.byte_pos - self.bit_count / 8
}

///|
/// Mask of the low `count` bits. `count` must be in `0..=31`; callers only
/// ever pass at most 16 (stored-block lengths) and `max_bits <= 15` for
/// huffman codes.
fn bit_mask(count : Int) -> UInt {
  (1U << count) - 1
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
let length_base : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let length_extra : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let dist_base : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let dist_extra : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
fn length_to_symbol(length : Int) -> (Int, Int, Int) raise ZipError {
  if length < 3 || length > 258 {
    raise UnsupportedFeature(msg="invalid match length")
  }
  for idx in 0..<length_base.length() {
    let base = length_base[idx]
    let extra = length_extra[idx]
    let max_len = base + ((1 << extra) - 1)
    if length <= max_len {
      return (idx + 257, extra, length - base)
    }
  }
  raise UnsupportedFeature(msg="length not encodable")
}

///|
fn distance_to_symbol(distance : Int) -> (Int, Int, Int) raise ZipError {
  if distance <= 0 || distance > 32768 {
    raise UnsupportedFeature(msg="invalid match distance")
  }
  for idx in 0..<dist_base.length() {
    let base = dist_base[idx]
    let extra = dist_extra[idx]
    let max_dist = base + ((1 << extra) - 1)
    if distance <= max_dist {
      return (idx, extra, distance - base)
    }
  }
  raise UnsupportedFeature(msg="distance not encodable")
}

///|
fn hash3(bytes : BytesView, pos : Int) -> Int {
  let b0 = bytes[pos].to_int()
  let b1 = bytes[pos + 1].to_int()
  let b2 = bytes[pos + 2].to_int()
  let hash = (b0 << 10) ^ (b1 << 5) ^ b2
  hash & ((1 << 15) - 1)
}

///|
let deflate_window_size : Int = 32768

///|
fn insert_position(
  bytes : BytesView,
  pos : Int,
  head : Array[Int],
  prev : Array[Int],
) -> Unit {
  if pos + 2 >= bytes.length() {
    return
  }
  let h = hash3(bytes, pos)
  prev[pos % deflate_window_size] = head[h]
  head[h] = pos
}

///|
fn find_match(
  bytes : BytesView,
  pos : Int,
  head : Array[Int],
  prev : Array[Int],
) -> (Int, Int) {
  let len = bytes.length()
  if pos + 3 > len {
    return (0, 0)
  }
  let max_len = if len - pos < 258 { len - pos } else { 258 }
  let h = hash3(bytes, pos)
  let mut candidate = head[h]
  let mut best_len = 0
  let mut best_dist = 0
  let mut chain_count = 0
  for state = true {
    if !state {
      break
    }
    if candidate < 0 || chain_count >= 128 {
      continue false
    }
    let dist = pos - candidate
    if dist > deflate_window_size {
      continue false
    }
    let mut l = 0
    while l < max_len && bytes[candidate + l] == bytes[pos + l] {
      l = l + 1
    }
    if l >= 3 && l > best_len {
      best_len = l
      best_dist = dist
      if l == max_len {
        continue false
      }
    }
    candidate = prev[candidate % deflate_window_size]
    chain_count = chain_count + 1
    continue true
  }
  (best_len, best_dist)
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
      raise UnsupportedFeature(msg="invalid huffman length")
    }
    if len > max_bits {
      max_bits = len
    }
  }
  if max_bits == 0 {
    raise UnsupportedFeature(msg="empty huffman table")
  }
  let counts : Array[Int] = Array::make(max_bits + 1, 0)
  for len in lengths {
    if len > 0 {
      counts[len] = counts[len] + 1
    }
  }
  // Reject oversubscribed length sets (Kraft inequality violated). The flat
  // lookup table would otherwise let colliding canonical codes overwrite one
  // another and silently "decode" malformed input that a strict decoder
  // rejects; zlib performs the same validation. Incomplete sets stay
  // accepted, matching the historical decoder.
  let mut remaining = 1
  for bits in 1..<=max_bits {
    remaining = (remaining << 1) - counts[bits]
    if remaining < 0 {
      raise UnsupportedFeature(msg="oversubscribed huffman table")
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
/// Decode one huffman symbol with a single flat-table lookup: peek up to
/// `max_bits` bits (zero-padded near end of input), index the table built by
/// `build_huffman` (which maps every reversed bit-prefix to its unique
/// `(sym, len)`), then drop only the bits the resolved code actually uses.
fn decode_symbol(
  reader : BitReader,
  table : HuffmanTable,
) -> Int raise ZipError {
  let idx = reader.peek_bits(table.max_bits).reinterpret_as_int()
  let len = table.len[idx]
  if len == 0 || len > reader.bit_count {
    if reader.bit_count < table.max_bits {
      // Input ended mid-code: the bit-serial decoder would have failed to
      // read the next bit here.
      raise OutOfBounds(offset=reader.byte_pos)
    }
    raise UnsupportedFeature(msg="invalid huffman code")
  }
  reader.drop_bits(len)
  table.sym[idx]
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
fn append_repeated_code_lengths(
  lengths : Array[Int],
  value : Int,
  repeat : Int,
  total : Int,
) -> Unit raise ZipError {
  if repeat > total - lengths.length() {
    raise UnsupportedFeature(msg="dynamic code-length repeat exceeds table")
  }
  for _ in 0..<repeat {
    lengths.push(value)
  }
}

///|
fn read_dynamic_tables(
  reader : BitReader,
) -> (HuffmanTable, HuffmanTable) raise ZipError {
  let hlit = reader.read_bits(5).reinterpret_as_int() + 257
  if hlit > 286 {
    raise UnsupportedFeature(msg="invalid dynamic literal/length count")
  }
  let hdist = reader.read_bits(5).reinterpret_as_int() + 1
  let hclen = reader.read_bits(4).reinterpret_as_int() + 4
  let order : ReadOnlyArray[Int] = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
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
        raise UnsupportedFeature(msg="repeat with no previous length")
      }
      let repeat = reader.read_bits(2).reinterpret_as_int() + 3
      let prev = lengths[lengths.length() - 1]
      append_repeated_code_lengths(lengths, prev, repeat, total)
    } else if symbol == 17 {
      let repeat = reader.read_bits(3).reinterpret_as_int() + 3
      append_repeated_code_lengths(lengths, 0, repeat, total)
    } else if symbol == 18 {
      let repeat = reader.read_bits(7).reinterpret_as_int() + 11
      append_repeated_code_lengths(lengths, 0, repeat, total)
    }
  }
  let lit_lengths = lengths[:hlit]
  let dist_lengths = lengths[hlit:hlit + hdist]
  (build_huffman(lit_lengths), build_huffman(dist_lengths))
}

///|
/// Default cap for decompressed output, guarding against decompression bombs.
let deflate_max_output_default : Int = 1 << 30

///|
fn decode_huffman_block(
  reader : BitReader,
  lit_table : HuffmanTable,
  dist_table : HuffmanTable,
  out : Array[Byte],
  max_output? : Int = deflate_max_output_default,
) -> Unit raise ZipError {
  for state = true {
    if !state {
      break
    }
    let symbol = decode_symbol(reader, lit_table)
    if symbol < 256 {
      if out.length() >= max_output {
        raise OutputLimitExceeded(limit=max_output)
      }
      out.push(symbol.to_byte())
      continue true
    }
    if symbol == 256 {
      continue false
    }
    let length_idx = symbol - 257
    if length_idx < 0 || length_idx >= length_base.length() {
      raise UnsupportedFeature(msg="invalid length symbol")
    }
    let extra_len = length_extra[length_idx]
    let length = length_base[length_idx] +
      reader.read_bits(extra_len).reinterpret_as_int()
    let dist_symbol = decode_symbol(reader, dist_table)
    if dist_symbol < 0 || dist_symbol >= dist_base.length() {
      raise UnsupportedFeature(msg="invalid distance symbol")
    }
    let dist = dist_base[dist_symbol] +
      reader.read_bits(dist_extra[dist_symbol]).reinterpret_as_int()
    if dist <= 0 || dist > out.length() {
      raise UnsupportedFeature(msg="invalid back-reference distance")
    }
    if length > max_output - out.length() {
      raise OutputLimitExceeded(limit=max_output)
    }
    for _ in 0..<length {
      let value = out[out.length() - dist]
      out.push(value)
    }
    continue true
  }
}

///|
priv struct BitWriter {
  mut bit_buf : UInt
  mut bit_count : Int
  out : Array[Byte]
  max_output : Int?
}

///|
fn BitWriter::new_with_limit(max_output : Int?) -> BitWriter raise ZipError {
  match max_output {
    Some(limit) if limit < 0 =>
      raise UnsupportedFeature(msg="deflate output limit must be non-negative")
    _ => ()
  }
  { bit_buf: 0, bit_count: 0, out: [], max_output }
}

///|
fn BitWriter::new() -> BitWriter {
  { bit_buf: 0, bit_count: 0, out: [], max_output: None }
}

///|
fn BitWriter::push_byte(self : BitWriter, value : Byte) -> Unit raise ZipError {
  match self.max_output {
    Some(limit) if self.out.length() >= limit =>
      raise OutputLimitExceeded(limit~)
    _ => self.out.push(value)
  }
}

///|
fn BitWriter::write_bits(
  self : BitWriter,
  value : Int,
  count : Int,
) -> Unit raise ZipError {
  if count < 0 {
    raise UnsupportedFeature(msg="negative bit count")
  }
  for i in 0..<count {
    let bit = (value >> i) & 1
    self.bit_buf = self.bit_buf | (bit.reinterpret_as_uint() << self.bit_count)
    self.bit_count = self.bit_count + 1
    if self.bit_count == 8 {
      self.push_byte(self.bit_buf.to_byte())
      self.bit_buf = 0
      self.bit_count = 0
    }
  }
}

///|
fn BitWriter::finish(self : BitWriter) -> Bytes raise ZipError {
  if self.bit_count > 0 {
    self.push_byte(self.bit_buf.to_byte())
  }
  Bytes::from_array(self.out)
}

///|
fn fixed_literal_code(symbol : Int) -> (Int, Int) raise ZipError {
  if symbol < 0 || symbol > 287 {
    raise UnsupportedFeature(msg="invalid fixed literal symbol")
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
fn deflate_encode_with_limit(
  bytes : BytesView,
  max_output : Int?,
) -> Bytes raise ZipError {
  let writer = BitWriter::new_with_limit(max_output)
  writer.write_bits(1, 1)
  writer.write_bits(1, 2)
  let len = bytes.length()
  let head : Array[Int] = Array::make(1 << 15, -1)
  // DEFLATE distances cannot exceed 32 KiB. A ring retains exactly the
  // predecessor links that can still be reached, rather than allocating one
  // integer for every byte in a potentially large Office XML part.
  let prev : Array[Int] = Array::make(deflate_window_size, -1)
  let mut i = 0
  for state = true {
    if !state {
      break
    }
    if i >= len {
      continue false
    }
    let (match_len, match_dist) = find_match(bytes, i, head, prev)
    if match_len >= 3 {
      let (len_sym, len_extra, len_value) = length_to_symbol(match_len)
      let (len_code, len_bits) = fixed_literal_code(len_sym)
      let len_rev = reverse_bits(len_code.reinterpret_as_uint(), len_bits).reinterpret_as_int()
      writer.write_bits(len_rev, len_bits)
      if len_extra > 0 {
        writer.write_bits(len_value, len_extra)
      }
      let (dist_sym, dist_extra, dist_value) = distance_to_symbol(match_dist)
      let dist_rev = reverse_bits(dist_sym.reinterpret_as_uint(), 5).reinterpret_as_int()
      writer.write_bits(dist_rev, 5)
      if dist_extra > 0 {
        writer.write_bits(dist_value, dist_extra)
      }
      for j in 0..<match_len {
        insert_position(bytes, i + j, head, prev)
      }
      i = i + match_len
      continue true
    }
    let (code, bits) = fixed_literal_code(bytes[i].to_int())
    let rev = reverse_bits(code.reinterpret_as_uint(), bits).reinterpret_as_int()
    writer.write_bits(rev, bits)
    insert_position(bytes, i, head, prev)
    i = i + 1
    continue true
  }
  let (end_code, end_len) = fixed_literal_code(256)
  let end_rev = reverse_bits(end_code.reinterpret_as_uint(), end_len).reinterpret_as_int()
  writer.write_bits(end_rev, end_len)
  writer.finish()
}

///|
fn deflate_encode(bytes : BytesView) -> Bytes raise ZipError {
  deflate_encode_with_limit(bytes, None)
}

///|
fn deflate_encode_limited(
  bytes : BytesView,
  max_output : Int,
) -> Bytes raise ZipError {
  deflate_encode_with_limit(bytes, Some(max_output))
}

///|
fn deflate_decode(
  bytes : BytesView,
  max_output? : Int = deflate_max_output_default,
) -> Bytes raise ZipError {
  let reader = BitReader::new(bytes)
  let out : Array[Byte] = []
  for state = false {
    if state {
      break
    }
    let bfinal = reader.read_bits(1)
    let btype = reader.read_bits(2)
    match btype {
      0 => {
        reader.align_byte()
        let len = reader.read_bits(16).reinterpret_as_int()
        let nlen = reader.read_bits(16)
        if (len.reinterpret_as_uint() ^ nlen) != 0xFFFF {
          raise UnsupportedFeature(msg="invalid stored block length")
        }
        if len > max_output - out.length() {
          raise OutputLimitExceeded(limit=max_output)
        }
        for _ in 0..<len {
          out.push(reader.read_byte())
        }
      }
      1 => {
        let lit = fixed_literal_table()
        let dist = fixed_distance_table()
        decode_huffman_block(reader, lit, dist, out, max_output~)
      }
      2 => {
        let (lit, dist) = read_dynamic_tables(reader)
        decode_huffman_block(reader, lit, dist, out, max_output~)
      }
      _ => raise UnsupportedFeature(msg="invalid deflate block type")
    }
    continue bfinal == 1
  }
  if reader.consumed_bytes() != bytes.length() {
    raise UnsupportedFeature(msg="trailing bytes after deflate stream")
  }
  Bytes::from_array(out)
}

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
test "deflate rejects complete bytes after the final block" {
  let stream : Bytes = [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x68, 0x69, 0x00]
  try deflate_decode(stream) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="trailing bytes after deflate stream")
    _ => fail("expected trailing deflate bytes to be rejected")
  } noraise {
    _ => fail("expected trailing deflate bytes to be rejected")
  }
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
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected ensure_bits to raise")
  }
  try length_to_symbol(2) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected length_to_symbol to raise")
  }
  try distance_to_symbol(0) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected distance_to_symbol to raise")
  }
  try build_huffman([16]) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected build_huffman to raise")
  }
  let writer = BitWriter::new()
  try writer.write_bits(1, -1) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected write_bits to raise")
  }
  try fixed_literal_code(288) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
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
    UnsupportedFeature(msg~) =>
      inspect(msg, content="repeat with no previous length")
    _ => fail("expected repeat-with-no-previous-length error")
  } noraise {
    _ => fail("expected repeat-with-no-previous-length error")
  }
}

///|
test "deflate wb: dynamic table rejects reserved HLIT" {
  let writer = BitWriter::new()
  // HLIT encodings 30 and 31 are reserved: at most 286 literal/length codes
  // may be declared.
  ignore(writer.write_bits(30, 5))
  let reader = BitReader::new(writer.finish())
  try read_dynamic_tables(reader) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="invalid dynamic literal/length count")
    _ => fail("expected reserved-HLIT error")
  } noraise {
    _ => fail("expected reserved-HLIT error")
  }
}

///|
test "deflate wb: dynamic table rejects repeat overshoot" {
  let writer = BitWriter::new()
  // hlit=257, hdist=1, hclen=4
  ignore(writer.write_bits(0, 5))
  ignore(writer.write_bits(0, 5))
  ignore(writer.write_bits(0, 4))
  // Code-length alphabet lengths for [16, 17, 18, 0]. Symbol 18 is the
  // sole one-bit code, so each zero bit below selects it.
  ignore(writer.write_bits(0, 3))
  ignore(writer.write_bits(0, 3))
  ignore(writer.write_bits(1, 3))
  ignore(writer.write_bits(0, 3))
  // Two maximum symbol-18 repeats request 276 lengths for a 258-slot table.
  ignore(writer.write_bits(0, 1))
  ignore(writer.write_bits(127, 7))
  ignore(writer.write_bits(0, 1))
  ignore(writer.write_bits(127, 7))
  let reader = BitReader::new(writer.finish())
  try read_dynamic_tables(reader) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="dynamic code-length repeat exceeds table")
    _ => fail("expected code-length repeat overshoot error")
  } noraise {
    _ => fail("expected code-length repeat overshoot error")
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
    e => inspect(e is UnsupportedFeature(_), content="true")
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
    e => inspect(e is UnsupportedFeature(_), content="true")
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
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected decode_huffman_block to raise")
  }
}

///|
test "deflate decode enforces max_output for stored blocks" {
  // Stored block declaring 2 bytes ("hi") against a cap of 1.
  let stream : Bytes = [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x68, 0x69]
  try deflate_decode(stream, max_output=1) catch {
    OutputLimitExceeded(limit~) => inspect(limit, content="1")
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
    OutputLimitExceeded(limit~) => inspect(limit, content="4")
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
    OutputLimitExceeded(limit~) => inspect(limit, content="100")
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
    UnsupportedFeature(msg~) =>
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

///|
priv struct FlateBitReader {
  bytes : BytesView
  mut byte_pos : Int
  mut bit_buf : UInt
  mut bit_count : Int
}

///|
fn FlateBitReader::new(bytes : BytesView) -> FlateBitReader {
  { bytes, byte_pos: 0, bit_buf: 0, bit_count: 0 }
}

///|
fn FlateBitReader::ensure_bits(
  self : FlateBitReader,
  count : Int,
) -> Unit raise PdfError {
  if count < 0 {
    raise InvalidFlateData
  }
  while self.bit_count < count {
    if self.byte_pos >= self.bytes.length() || self.byte_pos < 0 {
      raise InvalidFlateData
    }
    let byte = self.bytes[self.byte_pos].to_uint()
    self.bit_buf = self.bit_buf | (byte << self.bit_count)
    self.bit_count += 8
    self.byte_pos += 1
  }
}

///|
fn FlateBitReader::read_bits(
  self : FlateBitReader,
  count : Int,
) -> UInt raise PdfError {
  self.ensure_bits(count)
  let mask = pdf_flate_bit_mask(count)
  let value = self.bit_buf & mask
  self.bit_buf = self.bit_buf >> count
  self.bit_count -= count
  value
}

///|
fn FlateBitReader::drop_bits(
  self : FlateBitReader,
  count : Int,
) -> Unit raise PdfError {
  self.ensure_bits(count)
  self.bit_buf = self.bit_buf >> count
  self.bit_count -= count
}

///|
fn FlateBitReader::align_byte(self : FlateBitReader) -> Unit raise PdfError {
  let drop = self.bit_count % 8
  if drop != 0 {
    self.drop_bits(drop)
  }
}

///|
fn FlateBitReader::read_byte(self : FlateBitReader) -> Byte raise PdfError {
  self.read_bits(8).to_byte()
}

///|
fn pdf_flate_bit_mask(count : Int) -> UInt {
  let mut mask : UInt = 0
  for _ in 0..<count {
    mask = (mask << 1) | 1
  }
  mask
}

///|
fn pdf_flate_reverse_bits(value : UInt, bits : Int) -> UInt {
  let mut current = value
  let mut result : UInt = 0
  for _ in 0..<bits {
    result = (result << 1) | (current & 1)
    current = current >> 1
  }
  result
}

///|
let pdf_flate_length_base : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let pdf_flate_length_extra : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let pdf_flate_distance_base : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let pdf_flate_distance_extra : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
priv struct FlateHuffmanTable {
  max_bits : Int
  sym : Array[Int]
  len : Array[Int]
}

///|
fn pdf_flate_build_huffman(
  lengths : ArrayView[Int],
) -> FlateHuffmanTable raise PdfError {
  let mut max_bits = 0
  for length in lengths {
    if length < 0 || length > 15 {
      raise InvalidFlateData
    }
    if length > max_bits {
      max_bits = length
    }
  }
  if max_bits == 0 {
    raise InvalidFlateData
  }
  let counts : Array[Int] = Array::make(max_bits + 1, 0)
  for length in lengths {
    if length > 0 {
      counts[length] += 1
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
    let current = next_code[length]
    next_code[length] = current + 1
    let reversed = pdf_flate_reverse_bits(current.reinterpret_as_uint(), length).reinterpret_as_int()
    let fill = 1 << (max_bits - length)
    for i in 0..<fill {
      let index = reversed | (i << length)
      sym[index] = symbol
      len_table[index] = length
    }
  }
  { max_bits, sym, len: len_table }
}

///|
fn pdf_flate_decode_symbol(
  reader : FlateBitReader,
  table : FlateHuffmanTable,
) -> Int raise PdfError {
  let mut code : UInt = 0
  for length in 1..<=table.max_bits {
    let bit = reader.read_bits(1)
    code = code | (bit << (length - 1))
    let index = code.reinterpret_as_int()
    if table.len[index] == length {
      return table.sym[index]
    }
  }
  raise InvalidFlateData
}

///|
fn pdf_flate_fixed_literal_table() -> FlateHuffmanTable raise PdfError {
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
  pdf_flate_build_huffman(lengths)
}

///|
fn pdf_flate_fixed_distance_table() -> FlateHuffmanTable raise PdfError {
  let lengths : Array[Int] = []
  for _ in 0..<=31 {
    lengths.push(5)
  }
  pdf_flate_build_huffman(lengths)
}

///|
fn pdf_flate_check_dynamic_length_symbol(symbol : Int) -> Unit raise PdfError {
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
) -> Unit raise PdfError {
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
) -> (FlateHuffmanTable, FlateHuffmanTable) raise PdfError {
  let hlit = reader.read_bits(5).reinterpret_as_int() + 257
  let hdist = reader.read_bits(5).reinterpret_as_int() + 1
  let hclen = reader.read_bits(4).reinterpret_as_int() + 4
  let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
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
fn pdf_flate_decode_huffman_block(
  reader : FlateBitReader,
  literal_table : FlateHuffmanTable,
  distance_table : FlateHuffmanTable,
  output : Array[Byte],
) -> Unit raise PdfError {
  let mut done = false
  while !done {
    let symbol = pdf_flate_decode_symbol(reader, literal_table)
    if symbol < 256 {
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
) -> (PdfBytes, Int) raise PdfError {
  let reader = FlateBitReader::new(bytes)
  let output : Array[Byte] = []
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
        for _ in 0..<length {
          output.push(reader.read_byte())
        }
      }
      1 => {
        let literal = pdf_flate_fixed_literal_table()
        let distance = pdf_flate_fixed_distance_table()
        pdf_flate_decode_huffman_block(reader, literal, distance, output)
      }
      2 => {
        let (literal, distance) = pdf_flate_read_dynamic_tables(reader)
        pdf_flate_decode_huffman_block(reader, literal, distance, output)
      }
      _ => raise InvalidFlateData
    }
    finished = final_block == 1
  }
  (Bytes::from_array(output), reader.byte_pos)
}

///|
fn pdf_deflate_decode_raw(bytes : BytesView) -> PdfBytes raise PdfError {
  let (decoded, _) = pdf_deflate_decode_raw_prefix(bytes)
  decoded
}

///|
fn pdf_flate_adler32(data : BytesView) -> (Int, Int) {
  let mod_adler = 65521
  let mut s1 = 1
  let mut s2 = 0
  for byte in data {
    s1 = (s1 + byte.to_int()) % mod_adler
    s2 = (s2 + s1) % mod_adler
  }
  (s1, s2)
}

///|
fn pdf_flate_check_adler32(
  compressed : BytesView,
  decoded : BytesView,
) -> Unit raise PdfError {
  let offset = compressed.length() - 4
  let (s1, s2) = pdf_flate_adler32(decoded)
  if compressed[offset].to_int() != ((s2 >> 8) & 0xFF) ||
    compressed[offset + 1].to_int() != (s2 & 0xFF) ||
    compressed[offset + 2].to_int() != ((s1 >> 8) & 0xFF) ||
    compressed[offset + 3].to_int() != (s1 & 0xFF) {
    raise InvalidFlateData
  }
}

///|
fn pdf_flate_push_u16_le(output : Array[Byte], value : Int) -> Unit {
  output.push((value & 0xFF).to_byte())
  output.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn pdf_flate_push_stored_block(
  output : Array[Byte],
  data : BytesView,
  offset : Int,
  length : Int,
  final_block : Bool,
) -> Unit {
  output.push(if final_block { 1 } else { 0 })
  pdf_flate_push_u16_le(output, length)
  pdf_flate_push_u16_le(output, 0xFFFF - length)
  for i in 0..<length {
    output.push(data[offset + i])
  }
}

///|
priv struct FlateBitWriter {
  output : Array[Byte]
  mut current_byte : Int
  mut bit_count : Int
}

///|
fn FlateBitWriter::new(output : Array[Byte]) -> FlateBitWriter {
  { output, current_byte: 0, bit_count: 0 }
}

///|
fn FlateBitWriter::write_bits(
  self : FlateBitWriter,
  value : UInt,
  width : Int,
) -> Unit {
  for bit_index in 0..<width {
    if ((value >> bit_index) & 1) == 1 {
      self.current_byte = self.current_byte | (1 << self.bit_count)
    }
    self.bit_count += 1
    if self.bit_count == 8 {
      self.output.push(self.current_byte.to_byte())
      self.current_byte = 0
      self.bit_count = 0
    }
  }
}

///|
fn FlateBitWriter::finish(self : FlateBitWriter) -> Unit {
  if self.bit_count > 0 {
    self.output.push(self.current_byte.to_byte())
    self.current_byte = 0
    self.bit_count = 0
  }
}

///|
fn pdf_flate_fixed_literal_code(symbol : Int) -> (UInt, Int) {
  if symbol <= 143 {
    ((0x30 + symbol).reinterpret_as_uint(), 8)
  } else if symbol <= 255 {
    ((0x190 + symbol - 144).reinterpret_as_uint(), 9)
  } else if symbol <= 279 {
    ((symbol - 256).reinterpret_as_uint(), 7)
  } else {
    ((0xC0 + symbol - 280).reinterpret_as_uint(), 8)
  }
}

///|
fn pdf_flate_write_fixed_literal(writer : FlateBitWriter, symbol : Int) -> Unit {
  let (code, width) = pdf_flate_fixed_literal_code(symbol)
  writer.write_bits(pdf_flate_reverse_bits(code, width), width)
}

///|
fn pdf_flate_length_code(length : Int) -> (Int, Int, Int) raise PdfError {
  for index, base in pdf_flate_length_base {
    let extra_width = pdf_flate_length_extra[index]
    let max = base + ((1 << extra_width) - 1)
    if length >= base && length <= max {
      break (257 + index, length - base, extra_width)
    }
  } nobreak {
    raise InvalidFlateData
  }
}

///|
fn pdf_flate_distance_code(distance : Int) -> (Int, Int, Int) raise PdfError {
  for index, base in pdf_flate_distance_base {
    let extra_width = pdf_flate_distance_extra[index]
    let max = base + ((1 << extra_width) - 1)
    if distance >= base && distance <= max {
      break (index, distance - base, extra_width)
    }
  } nobreak {
    raise InvalidFlateData
  }
}

///|
fn pdf_flate_write_fixed_distance(
  writer : FlateBitWriter,
  distance : Int,
) -> Unit raise PdfError {
  let (symbol, extra, extra_width) = pdf_flate_distance_code(distance)
  writer.write_bits(pdf_flate_reverse_bits(symbol.reinterpret_as_uint(), 5), 5)
  writer.write_bits(extra.reinterpret_as_uint(), extra_width)
}

///|
fn pdf_flate_write_fixed_length_distance(
  writer : FlateBitWriter,
  length : Int,
  distance : Int,
) -> Unit raise PdfError {
  let (symbol, extra, extra_width) = pdf_flate_length_code(length)
  pdf_flate_write_fixed_literal(writer, symbol)
  writer.write_bits(extra.reinterpret_as_uint(), extra_width)
  pdf_flate_write_fixed_distance(writer, distance)
}

///|
fn pdf_flate_push_fixed_literal_block(
  output : Array[Byte],
  data : BytesView,
  final_block : Bool,
) -> Unit {
  let writer = FlateBitWriter::new(output)
  writer.write_bits(if final_block { 1 } else { 0 }, 1)
  writer.write_bits(1, 2)
  for byte in data {
    pdf_flate_write_fixed_literal(writer, byte.to_int())
  }
  pdf_flate_write_fixed_literal(writer, 256)
  writer.finish()
}

///|
fn pdf_flate_repeated_previous_length(data : BytesView, position : Int) -> Int {
  if position <= 0 || position >= data.length() {
    0
  } else {
    let previous = data[position - 1]
    let mut length = 0
    while position + length < data.length() &&
          data[position + length] == previous &&
          length < 258 {
      length += 1
    }
    length
  }
}

///|
fn pdf_flate_push_fixed_repeat_block(
  output : Array[Byte],
  data : BytesView,
  final_block : Bool,
) -> Unit raise PdfError {
  let writer = FlateBitWriter::new(output)
  writer.write_bits(if final_block { 1 } else { 0 }, 1)
  writer.write_bits(1, 2)
  let mut index = 0
  while index < data.length() {
    let repeated = pdf_flate_repeated_previous_length(data, index)
    if repeated >= 3 {
      pdf_flate_write_fixed_length_distance(writer, repeated, 1)
      index += repeated
    } else {
      pdf_flate_write_fixed_literal(writer, data[index].to_int())
      index += 1
    }
  }
  pdf_flate_write_fixed_literal(writer, 256)
  writer.finish()
}

///|
fn pdf_flate_match_key(data : BytesView, position : Int) -> Int {
  (data[position].to_int() << 8) | data[position + 1].to_int()
}

///|
fn pdf_flate_remember_match_prefix(
  table : Array[Int],
  data : BytesView,
  position : Int,
) -> Unit {
  if position + 1 < data.length() {
    table[pdf_flate_match_key(data, position)] = position
  }
}

///|
fn pdf_flate_previous_match_length(
  data : BytesView,
  source : Int,
  position : Int,
) -> Int {
  let mut length = 0
  while position + length < data.length() &&
        length < 258 &&
        data[source + length] == data[position + length] {
    length += 1
  }
  length
}

///|
fn pdf_flate_push_fixed_match_block(
  output : Array[Byte],
  data : BytesView,
  final_block : Bool,
) -> Unit raise PdfError {
  let writer = FlateBitWriter::new(output)
  writer.write_bits(if final_block { 1 } else { 0 }, 1)
  writer.write_bits(1, 2)
  let last_by_prefix : Array[Int] = Array::make(65536, -1)
  let mut index = 0
  while index < data.length() {
    let mut match_length = 0
    let mut match_distance = 0
    if index + 2 < data.length() {
      let candidate = last_by_prefix[pdf_flate_match_key(data, index)]
      if candidate >= 0 {
        let distance = index - candidate
        if distance > 0 && distance <= 32768 {
          let length = pdf_flate_previous_match_length(data, candidate, index)
          if length >= 3 {
            match_length = length
            match_distance = distance
          }
        }
      }
    }
    if match_length >= 3 {
      pdf_flate_write_fixed_length_distance(
        writer, match_length, match_distance,
      )
      let next_index = index + match_length
      while index < next_index {
        pdf_flate_remember_match_prefix(last_by_prefix, data, index)
        index += 1
      }
    } else {
      pdf_flate_write_fixed_literal(writer, data[index].to_int())
      pdf_flate_remember_match_prefix(last_by_prefix, data, index)
      index += 1
    }
  }
  pdf_flate_write_fixed_literal(writer, 256)
  writer.finish()
}

///|
fn pdf_flate_push_adler32(output : Array[Byte], data : BytesView) -> Unit {
  let (s1, s2) = pdf_flate_adler32(data)
  output.push(((s2 >> 8) & 0xFF).to_byte())
  output.push((s2 & 0xFF).to_byte())
  output.push(((s1 >> 8) & 0xFF).to_byte())
  output.push((s1 & 0xFF).to_byte())
}

///|
fn pdf_flate_encode_stored_view(data : BytesView) -> PdfBytes {
  let output : Array[Byte] = [0x78, 0x01]
  if data.length() == 0 {
    pdf_flate_push_stored_block(output, data, 0, 0, true)
  } else {
    let mut offset = 0
    while offset < data.length() {
      let remaining = data.length() - offset
      let length = if remaining > 65535 { 65535 } else { remaining }
      pdf_flate_push_stored_block(
        output,
        data,
        offset,
        length,
        offset + length == data.length(),
      )
      offset += length
    }
  }
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

///|
fn pdf_flate_encode_fixed_literal_view(data : BytesView) -> PdfBytes {
  let output : Array[Byte] = [0x78, 0x01]
  pdf_flate_push_fixed_literal_block(output, data, true)
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

///|
fn pdf_flate_encode_fixed_repeat_view(
  data : BytesView,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = [0x78, 0x01]
  pdf_flate_push_fixed_repeat_block(output, data, true)
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

///|
fn pdf_flate_encode_fixed_match_view(
  data : BytesView,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = [0x78, 0x01]
  pdf_flate_push_fixed_match_block(output, data, true)
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

///|
pub fn pdf_flate_encode_view(data : BytesView) -> PdfBytes {
  let stored = pdf_flate_encode_stored_view(data)
  let fixed = pdf_flate_encode_fixed_literal_view(data)
  let repeat = try! pdf_flate_encode_fixed_repeat_view(data)
  let matched = try! pdf_flate_encode_fixed_match_view(data)
  if matched.length() < repeat.length() &&
    matched.length() < fixed.length() &&
    matched.length() < stored.length() {
    matched
  } else if repeat.length() < fixed.length() &&
    repeat.length() < stored.length() {
    repeat
  } else if fixed.length() < stored.length() {
    fixed
  } else {
    stored
  }
}

///|
pub fn pdf_flate_encode(data : PdfBytes) -> PdfBytes {
  pdf_flate_encode_view(data[:])
}

///|
pub fn pdf_flate_decode_view(data : BytesView) -> PdfBytes raise PdfError {
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
    pdf_flate_check_adler32(data, decoded[:])
    decoded
  }
}

///|
pub fn pdf_flate_decode(data : PdfBytes) -> PdfBytes raise PdfError {
  pdf_flate_decode_view(data[:])
}

///|
fn pdf_flate_decode_view_prefix(
  data : BytesView,
) -> (PdfBytes, Int) raise PdfError {
  if data.length() == 0 {
    (Bytes::new(0), 0)
  } else {
    if data.length() < 6 {
      raise InvalidFlateData
    }
    let cmf = data[0].to_int()
    let flg = data[1].to_int()
    if (cmf & 0x0F) != 8 || ((cmf << 8) + flg) % 31 != 0 || (flg & 0x20) != 0 {
      raise InvalidFlateData
    }
    let (decoded, deflate_length) = pdf_deflate_decode_raw_prefix(data[2:])
    let encoded_length = 2 + deflate_length + 4
    if encoded_length > data.length() {
      raise InvalidFlateData
    }
    pdf_flate_check_adler32(data[:encoded_length], decoded[:])
    (decoded, encoded_length)
  }
}

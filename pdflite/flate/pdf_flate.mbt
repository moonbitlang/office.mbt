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
) -> Unit raise @core.PdfError {
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
) -> UInt raise @core.PdfError {
  self.ensure_bits(count)
  let mask = pdf_flate_bit_mask(count)
  let value = self.bit_buf & mask
  self.bit_buf = self.bit_buf >> count
  self.bit_count -= count
  value
}

///|
fn FlateBitReader::peek_bits(self : FlateBitReader, count : Int) -> UInt? {
  if count < 0 {
    return None
  }
  let mut bit_buf = self.bit_buf
  let mut bit_count = self.bit_count
  let mut byte_pos = self.byte_pos
  while bit_count < count {
    if byte_pos >= self.bytes.length() || byte_pos < 0 {
      return None
    }
    let byte = self.bytes[byte_pos].to_uint()
    bit_buf = bit_buf | (byte << bit_count)
    bit_count += 8
    byte_pos += 1
  }
  Some(bit_buf & pdf_flate_bit_mask(count))
}

///|
fn FlateBitReader::drop_bits(
  self : FlateBitReader,
  count : Int,
) -> Unit raise @core.PdfError {
  self.ensure_bits(count)
  self.bit_buf = self.bit_buf >> count
  self.bit_count -= count
}

///|
fn FlateBitReader::align_byte(
  self : FlateBitReader,
) -> Unit raise @core.PdfError {
  let drop = self.bit_count % 8
  if drop != 0 {
    self.drop_bits(drop)
  }
}

///|
fn FlateBitReader::read_byte(
  self : FlateBitReader,
) -> Byte raise @core.PdfError {
  self.read_bits(8).to_byte()
}

///|
let pdf_flate_bit_mask_table : Array[UInt] = [
  0, 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047, 4095, 8191, 16383, 32767, 65535,
]

///|
fn pdf_flate_bit_mask(count : Int) -> UInt {
  if count >= 0 && count < pdf_flate_bit_mask_table.length() {
    pdf_flate_bit_mask_table[count]
  } else {
    let mut mask : UInt = 0
    for _ in 0..<count {
      mask = (mask << 1) | 1
    }
    mask
  }
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
priv struct FlateHuffmanTreeNode {
  weight : Int
  symbol : Int
  left : Int
  right : Int
  mut active : Bool
}

///|
fn pdf_flate_pick_huffman_node(nodes : Array[FlateHuffmanTreeNode]) -> Int {
  let mut picked = -1
  for index, node in nodes {
    if node.active &&
      (
        picked < 0 ||
        node.weight < nodes[picked].weight ||
        (
          node.weight == nodes[picked].weight &&
          node.symbol < nodes[picked].symbol
        )
      ) {
      picked = index
    }
  }
  picked
}

///|
fn pdf_flate_huffman_code_lengths(
  frequencies : ArrayView[Int],
  max_bits : Int,
) -> Array[Int] raise @core.PdfError {
  let lengths : Array[Int] = Array::make(frequencies.length(), 0)
  let nodes : Array[FlateHuffmanTreeNode] = []
  for symbol, frequency in frequencies {
    if frequency < 0 {
      raise InvalidFlateData
    }
    if frequency > 0 {
      nodes.push({
        weight: frequency,
        symbol,
        left: -1,
        right: -1,
        active: true,
      })
    }
  }
  if nodes.length() == 0 {
    raise InvalidFlateData
  }
  if nodes.length() == 1 {
    lengths[nodes[0].symbol] = 1
    return lengths
  }
  let mut active = nodes.length()
  while active > 1 {
    let first = pdf_flate_pick_huffman_node(nodes)
    nodes[first].active = false
    let second = pdf_flate_pick_huffman_node(nodes)
    nodes[second].active = false
    nodes.push({
      weight: nodes[first].weight + nodes[second].weight,
      symbol: if nodes[first].symbol < nodes[second].symbol {
        nodes[first].symbol
      } else {
        nodes[second].symbol
      },
      left: first,
      right: second,
      active: true,
    })
    active -= 1
  }
  let root = pdf_flate_pick_huffman_node(nodes)
  let stack : Array[(Int, Int)] = [(root, 0)]
  while stack.length() > 0 {
    let (node_index, depth) = stack.pop().unwrap()
    let node = nodes[node_index]
    if node.left < 0 && node.right < 0 {
      guard depth <= max_bits else { raise InvalidFlateData }
      lengths[node.symbol] = if depth == 0 { 1 } else { depth }
    } else {
      let child_depth = depth + 1
      guard child_depth <= max_bits else { raise InvalidFlateData }
      if node.left >= 0 {
        stack.push((node.left, child_depth))
      }
      if node.right >= 0 {
        stack.push((node.right, child_depth))
      }
    }
  }
  lengths
}

///|
fn pdf_flate_canonical_codes(lengths : ArrayView[Int]) -> Array[Int] {
  let mut max_bits = 0
  for length in lengths {
    if length > max_bits {
      max_bits = length
    }
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
  let codes : Array[Int] = Array::make(lengths.length(), 0)
  for symbol, length in lengths {
    if length > 0 {
      codes[symbol] = next_code[length]
      next_code[length] += 1
    }
  }
  codes
}

///|
fn pdf_flate_build_huffman(
  lengths : ArrayView[Int],
) -> FlateHuffmanTable raise @core.PdfError {
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
) -> Int raise @core.PdfError {
  match reader.peek_bits(table.max_bits) {
    Some(bits) => {
      let index = bits.reinterpret_as_int()
      let length = table.len[index]
      if length > 0 {
        reader.drop_bits(length)
        return table.sym[index]
      }
    }
    None => ()
  }
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
fn pdf_flate_fixed_literal_lengths() -> Array[Int] {
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
  lengths
}

///|
fn pdf_flate_fixed_distance_lengths() -> Array[Int] {
  let lengths : Array[Int] = []
  for _ in 0..<=31 {
    lengths.push(5)
  }
  lengths
}

///|
let pdf_flate_fixed_literal_table_value : FlateHuffmanTable = try! pdf_flate_build_huffman(
  pdf_flate_fixed_literal_lengths(),
)

///|
let pdf_flate_fixed_distance_table_value : FlateHuffmanTable = try! pdf_flate_build_huffman(
  pdf_flate_fixed_distance_lengths(),
)

///|
fn pdf_flate_fixed_literal_table() -> FlateHuffmanTable {
  pdf_flate_fixed_literal_table_value
}

///|
fn pdf_flate_fixed_distance_table() -> FlateHuffmanTable {
  pdf_flate_fixed_distance_table_value
}

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
fn pdf_flate_decode_huffman_block(
  reader : FlateBitReader,
  literal_table : FlateHuffmanTable,
  distance_table : FlateHuffmanTable,
  output : Array[Byte],
) -> Unit raise @core.PdfError {
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
) -> (@core.PdfBytes, Int) raise @core.PdfError {
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
fn pdf_deflate_decode_raw(
  bytes : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
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
) -> Unit raise @core.PdfError {
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
fn pdf_flate_length_code(length : Int) -> (Int, Int, Int) raise @core.PdfError {
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
fn pdf_flate_distance_code(
  distance : Int,
) -> (Int, Int, Int) raise @core.PdfError {
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
) -> Unit raise @core.PdfError {
  let (symbol, extra, extra_width) = pdf_flate_distance_code(distance)
  writer.write_bits(pdf_flate_reverse_bits(symbol.reinterpret_as_uint(), 5), 5)
  writer.write_bits(extra.reinterpret_as_uint(), extra_width)
}

///|
fn pdf_flate_write_fixed_length_distance(
  writer : FlateBitWriter,
  length : Int,
  distance : Int,
) -> Unit raise @core.PdfError {
  let (symbol, extra, extra_width) = pdf_flate_length_code(length)
  pdf_flate_write_fixed_literal(writer, symbol)
  writer.write_bits(extra.reinterpret_as_uint(), extra_width)
  pdf_flate_write_fixed_distance(writer, distance)
}

///|
fn pdf_flate_write_canonical_symbol(
  writer : FlateBitWriter,
  symbol : Int,
  codes : ArrayView[Int],
  lengths : ArrayView[Int],
) -> Unit raise @core.PdfError {
  guard symbol >= 0 && symbol < lengths.length() && lengths[symbol] > 0 else {
    raise InvalidFlateData
  }
  let width = lengths[symbol]
  writer.write_bits(
    pdf_flate_reverse_bits(codes[symbol].reinterpret_as_uint(), width),
    width,
  )
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
) -> Unit raise @core.PdfError {
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
  previous : Array[Int],
  data : BytesView,
  position : Int,
) -> Unit {
  if position + 1 < data.length() {
    let key = pdf_flate_match_key(data, position)
    previous[position] = table[key]
    table[key] = position
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
fn pdf_flate_best_previous_match(
  data : BytesView,
  last_by_prefix : ArrayView[Int],
  previous_by_position : ArrayView[Int],
  position : Int,
  max_probes : Int,
) -> (Int, Int) {
  let mut match_length = 0
  let mut match_distance = 0
  if position + 2 < data.length() {
    let mut candidate = last_by_prefix[pdf_flate_match_key(data, position)]
    let mut probes = 0
    while candidate >= 0 && probes < max_probes {
      let distance = position - candidate
      if distance > 0 && distance <= 32768 {
        let length = pdf_flate_previous_match_length(data, candidate, position)
        if length > match_length {
          match_length = length
          match_distance = distance
          if length == 258 {
            break
          }
        }
      }
      candidate = previous_by_position[candidate]
      probes += 1
    }
  }
  (match_length, match_distance)
}

///|
priv enum PdfFlateToken {
  PdfFlateLiteral(Int)
  PdfFlateLengthDistance(Int, Int)
}

///|
fn pdf_flate_match_tokens(
  data : BytesView,
  max_probes : Int,
) -> Array[PdfFlateToken] {
  let tokens : Array[PdfFlateToken] = []
  let last_by_prefix : Array[Int] = Array::make(65536, -1)
  let previous_by_position : Array[Int] = Array::make(data.length(), -1)
  let mut index = 0
  while index < data.length() {
    let (match_length, match_distance) = pdf_flate_best_previous_match(
      data, last_by_prefix, previous_by_position, index, max_probes,
    )
    if match_length >= 3 {
      tokens.push(PdfFlateLengthDistance(match_length, match_distance))
      let next_index = index + match_length
      while index < next_index {
        pdf_flate_remember_match_prefix(
          last_by_prefix, previous_by_position, data, index,
        )
        index += 1
      }
    } else {
      tokens.push(PdfFlateLiteral(data[index].to_int()))
      pdf_flate_remember_match_prefix(
        last_by_prefix, previous_by_position, data, index,
      )
      index += 1
    }
  }
  tokens
}

///|
fn pdf_flate_push_fixed_match_block(
  output : Array[Byte],
  data : BytesView,
  final_block : Bool,
  max_probes : Int,
) -> Unit raise @core.PdfError {
  let writer = FlateBitWriter::new(output)
  writer.write_bits(if final_block { 1 } else { 0 }, 1)
  writer.write_bits(1, 2)
  let last_by_prefix : Array[Int] = Array::make(65536, -1)
  let previous_by_position : Array[Int] = Array::make(data.length(), -1)
  let mut index = 0
  while index < data.length() {
    let (match_length, match_distance) = pdf_flate_best_previous_match(
      data, last_by_prefix, previous_by_position, index, max_probes,
    )
    if match_length >= 3 {
      pdf_flate_write_fixed_length_distance(
        writer, match_length, match_distance,
      )
      let next_index = index + match_length
      while index < next_index {
        pdf_flate_remember_match_prefix(
          last_by_prefix, previous_by_position, data, index,
        )
        index += 1
      }
    } else {
      pdf_flate_write_fixed_literal(writer, data[index].to_int())
      pdf_flate_remember_match_prefix(
        last_by_prefix, previous_by_position, data, index,
      )
      index += 1
    }
  }
  pdf_flate_write_fixed_literal(writer, 256)
  writer.finish()
}

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
  let tokens : Array[PdfFlateCodeLengthToken] = []
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
  let header_lengths : Array[Int] = []
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
fn pdf_flate_push_adler32(output : Array[Byte], data : BytesView) -> Unit {
  let (s1, s2) = pdf_flate_adler32(data)
  output.push(((s2 >> 8) & 0xFF).to_byte())
  output.push((s2 & 0xFF).to_byte())
  output.push(((s1 >> 8) & 0xFF).to_byte())
  output.push((s1 & 0xFF).to_byte())
}

///|
fn pdf_flate_default_header() -> Array[Byte] {
  [0x78, 0x01]
}

///|
fn pdf_flate_header_for_level(level : Int) -> Array[Byte] raise @core.PdfError {
  guard level >= 0 && level <= 9 else { raise InvalidFlateData }
  let compression_hint = if level <= 1 {
    0
  } else if level <= 5 {
    1
  } else if level == 6 {
    2
  } else {
    3
  }
  let cmf = 0x78
  let flg_without_check = compression_hint << 6
  let remainder = ((cmf << 8) + flg_without_check) % 31
  let fcheck = if remainder == 0 { 0 } else { 31 - remainder }
  [cmf.to_byte(), (flg_without_check + fcheck).to_byte()]
}

///|
fn pdf_flate_output_with_header(header : ArrayView[Byte]) -> Array[Byte] {
  let output : Array[Byte] = []
  for byte in header {
    output.push(byte)
  }
  output
}

///|
fn pdf_flate_encode_stored_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
) -> @core.PdfBytes {
  let output = pdf_flate_output_with_header(header)
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
fn pdf_flate_encode_fixed_literal_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
) -> @core.PdfBytes {
  let output = pdf_flate_output_with_header(header)
  pdf_flate_push_fixed_literal_block(output, data, true)
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

///|
fn pdf_flate_encode_fixed_repeat_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
) -> @core.PdfBytes raise @core.PdfError {
  let output = pdf_flate_output_with_header(header)
  pdf_flate_push_fixed_repeat_block(output, data, true)
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

///|
fn pdf_flate_encode_fixed_match_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
  max_probes : Int,
) -> @core.PdfBytes raise @core.PdfError {
  let output = pdf_flate_output_with_header(header)
  pdf_flate_push_fixed_match_block(output, data, true, max_probes)
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

///|
fn pdf_flate_encode_dynamic_match_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
  max_probes : Int,
) -> @core.PdfBytes raise @core.PdfError {
  let output = pdf_flate_output_with_header(header)
  pdf_flate_push_dynamic_match_block(output, data, true, max_probes)
  pdf_flate_push_adler32(output, data)
  Bytes::from_array(output)
}

///|
fn pdf_flate_shortest(a : @core.PdfBytes, b : @core.PdfBytes) -> @core.PdfBytes {
  if b.length() < a.length() {
    b
  } else {
    a
  }
}

///|
fn pdf_flate_shortest_result(
  current : @core.PdfBytes,
  candidate : Result[@core.PdfBytes, Error],
) -> @core.PdfBytes {
  match candidate {
    Ok(bytes) => pdf_flate_shortest(current, bytes)
    Err(_) => current
  }
}

///|
fn pdf_flate_encode_shortest_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
  max_probes : Int,
) -> @core.PdfBytes {
  let stored = pdf_flate_encode_stored_view_with_header(data, header)
  let fixed = pdf_flate_encode_fixed_literal_view_with_header(data, header)
  let mut shortest = pdf_flate_shortest(stored, fixed)
  let repeat : Result[@core.PdfBytes, Error] = try? pdf_flate_encode_fixed_repeat_view_with_header(
    data, header,
  )
  shortest = pdf_flate_shortest_result(shortest, repeat)
  let matched : Result[@core.PdfBytes, Error] = try? pdf_flate_encode_fixed_match_view_with_header(
    data, header, max_probes,
  )
  shortest = pdf_flate_shortest_result(shortest, matched)
  let dynamic : Result[@core.PdfBytes, Error] = try? pdf_flate_encode_dynamic_match_view_with_header(
    data, header, max_probes,
  )
  pdf_flate_shortest_result(shortest, dynamic)
}

///|
fn pdf_flate_encode_fast_view_with_header(
  data : BytesView,
  header : ArrayView[Byte],
  max_probes : Int,
) -> @core.PdfBytes {
  let stored = pdf_flate_encode_stored_view_with_header(data, header)
  let matched : Result[@core.PdfBytes, Error] = try? pdf_flate_encode_fixed_match_view_with_header(
    data, header, max_probes,
  )
  pdf_flate_shortest_result(stored, matched)
}

///|
fn pdf_flate_max_probes_for_level(level : Int) -> Int {
  if level <= 1 {
    8
  } else if level <= 3 {
    16
  } else if level <= 5 {
    32
  } else if level == 6 {
    64
  } else if level <= 8 {
    128
  } else {
    256
  }
}

///|
fn pdf_flate_encode_view_with_level_pure(
  data : BytesView,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  let header = pdf_flate_header_for_level(level)
  if level == 0 {
    pdf_flate_encode_stored_view_with_header(data, header)
  } else if level <= 3 {
    pdf_flate_encode_fast_view_with_header(
      data,
      header,
      pdf_flate_max_probes_for_level(level),
    )
  } else {
    pdf_flate_encode_shortest_view_with_header(
      data,
      header,
      pdf_flate_max_probes_for_level(level),
    )
  }
}

///|
fn pdf_flate_encode_view_pure(data : BytesView) -> @core.PdfBytes {
  pdf_flate_encode_shortest_view_with_header(
    data,
    pdf_flate_default_header(),
    64,
  )
}

///|
#cfg(target="native")
#borrow(data, status)
extern "C" fn pdf_flate_zlib_encode_ffi(
  data : @core.PdfBytes,
  level : Int,
  status : Ref[Int],
) -> @core.PdfBytes = "pdflite_zlib_compress"

///|
#cfg(target="native")
#borrow(data, status)
extern "C" fn pdf_flate_zlib_decode_ffi(
  data : @core.PdfBytes,
  status : Ref[Int],
) -> @core.PdfBytes = "pdflite_zlib_decompress"

///|
#cfg(target="native")
#coverage.skip
fn pdf_flate_native_payload(
  result : @core.PdfBytes,
  status : Ref[Int],
) -> @core.PdfBytes raise @core.PdfError {
  if status.val != 1 {
    raise InvalidFlateData
  }
  result
}

///|
#cfg(target="native")
#coverage.skip
fn pdf_flate_encode_bytes_native(
  data : @core.PdfBytes,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  let _ = pdf_flate_header_for_level(level)
  let status = Ref::{ val: 0 }
  try
    pdf_flate_native_payload(
      pdf_flate_zlib_encode_ffi(data, level, status),
      status,
    )
  catch {
    _ => pdf_flate_encode_view_with_level_pure(data, level)
  } noraise {
    bytes => bytes
  }
}

///|
/// Encode borrowed bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`. On non-native targets this uses the pure MoonBit encoder.
#cfg(not(target="native"))
pub fn pdf_flate_encode_view_with_level(
  data : BytesView,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_view_with_level_pure(data, level)
}

///|
/// Encode borrowed bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`. On the native target this tries the zlib FFI first and
/// falls back to the pure MoonBit encoder if the native call fails.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_encode_view_with_level(
  data : BytesView,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_bytes_native(data.to_owned(), level)
}

///|
/// Encode borrowed bytes with the default compression level.
///
/// This non-native implementation uses the pure MoonBit encoder.
#cfg(not(target="native"))
pub fn pdf_flate_encode_view(data : BytesView) -> @core.PdfBytes {
  pdf_flate_encode_view_pure(data)
}

///|
/// Encode borrowed bytes with the default compression level.
///
/// On the native target this tries zlib at level `6` and falls back to the pure
/// MoonBit encoder if the native call fails.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_encode_view(data : BytesView) -> @core.PdfBytes {
  try pdf_flate_encode_bytes_native(data.to_owned(), 6) catch {
    _ => pdf_flate_encode_view_pure(data)
  } noraise {
    bytes => bytes
  }
}

///|
/// Encode owned bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`. This non-native implementation uses the pure MoonBit
/// encoder.
#cfg(not(target="native"))
pub fn pdf_flate_encode_with_level(
  data : @core.PdfBytes,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_view_with_level_pure(data, level)
}

///|
/// Encode owned bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`. On the native target this uses zlib FFI with a pure
/// MoonBit fallback.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_encode_with_level(
  data : @core.PdfBytes,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_bytes_native(data, level)
}

///|
/// Encode owned bytes with the default compression level.
///
/// This non-native implementation uses the pure MoonBit encoder.
#cfg(not(target="native"))
pub fn pdf_flate_encode(data : @core.PdfBytes) -> @core.PdfBytes {
  pdf_flate_encode_view_pure(data)
}

///|
/// Encode owned bytes with the default compression level.
///
/// On the native target this tries zlib at level `6` and falls back to the pure
/// MoonBit encoder if the native call fails.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_encode(data : @core.PdfBytes) -> @core.PdfBytes {
  try pdf_flate_encode_bytes_native(data, 6) catch {
    _ => pdf_flate_encode_view_pure(data)
  } noraise {
    bytes => bytes
  }
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

///|
#cfg(target="native")
#coverage.skip
fn pdf_flate_decode_bytes_native(
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  if data.length() == 0 {
    Bytes::new(0)
  } else {
    let status = Ref::{ val: 0 }
    try
      pdf_flate_native_payload(pdf_flate_zlib_decode_ffi(data, status), status)
    catch {
      _ => pdf_flate_decode_view_pure(data)
    } noraise {
      bytes => bytes
    }
  }
}

///|
/// Decode a zlib-wrapped Flate stream from a borrowed byte view.
///
/// Empty input decodes to empty output. Malformed headers, unsupported preset
/// dictionaries, invalid Deflate data, and Adler-32 mismatches raise
/// `@core.PdfError::InvalidFlateData`.
#cfg(not(target="native"))
pub fn pdf_flate_decode_view(
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_decode_view_pure(data)
}

///|
/// Decode a zlib-wrapped Flate stream from a borrowed byte view.
///
/// On the native target this tries zlib FFI first and falls back to the pure
/// MoonBit decoder if the native call fails. Invalid compressed data raises
/// `@core.PdfError::InvalidFlateData`.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_decode_view(
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  if data.length() == 0 {
    Bytes::new(0)
  } else {
    let status = Ref::{ val: 0 }
    try
      pdf_flate_native_payload(
        pdf_flate_zlib_decode_ffi(data.to_owned(), status),
        status,
      )
    catch {
      _ => pdf_flate_decode_view_pure(data)
    } noraise {
      bytes => bytes
    }
  }
}

///|
/// Decode a zlib-wrapped Flate stream from owned bytes.
///
/// Empty input decodes to empty output. Malformed compressed data raises
/// `@core.PdfError::InvalidFlateData`.
#cfg(not(target="native"))
pub fn pdf_flate_decode(
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_decode_view_pure(data)
}

///|
/// Decode a zlib-wrapped Flate stream from owned bytes.
///
/// On the native target this uses zlib FFI with a pure MoonBit fallback.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_decode(
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_decode_bytes_native(data)
}

///|
/// Decode the first zlib-wrapped Flate stream from a byte view.
///
/// Returns the decoded bytes and the number of encoded bytes consumed, which
/// lets callers continue parsing data that follows the compressed stream.
pub fn pdf_flate_decode_view_prefix(
  data : BytesView,
) -> (@core.PdfBytes, Int) raise @core.PdfError {
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
    pdf_flate_check_adler32(data[:encoded_length], decoded)
    (decoded, encoded_length)
  }
}

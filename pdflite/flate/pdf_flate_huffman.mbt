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
  let nodes : Array[FlateHuffmanTreeNode] = Array::new(
    capacity=frequencies.length() * 2,
  )
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
  let stack : Array[(Int, Int)] = Array::new(capacity=nodes.length())
  stack.push((root, 0))
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
  let lengths : Array[Int] = Array::new(capacity=288)
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
  let lengths : Array[Int] = Array::new(capacity=32)
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

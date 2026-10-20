// SPDX-License-Identifier: MPL-2.0
// Adapted from mtx-decompressor 1.8.0, ChristopherVR; see NOTICE.

///|
priv struct Node {
  mut up : Int32
  left : Int32
  right : Int32
  code : Int32
  mut weight : Int32
}

///|
priv struct Huff {
  input : Stream
  tree : Array[Node]
  symbols : Array[Int32]
}

///|
fn Huff::swap(self : Huff, a : Int32, b : Int32) -> Unit {
  let up_a = self.tree[a].up
  let up_b = self.tree[b].up
  let saved = self.tree[a]
  self.tree[a] = self.tree[b]
  self.tree[b] = saved
  self.tree[a].up = up_a
  self.tree[b].up = up_b
  for position in [a, b] {
    let node = self.tree[position]
    if node.code < 0 {
      self.tree[node.left].up = position
      self.tree[node.right].up = position
    } else {
      self.symbols[node.code] = position
    }
  }
}

///|
fn Huff::update(self : Huff, initial : Int32) -> Unit {
  let mut a = initial
  while a != 1 {
    let weight = self.tree[a].weight
    let mut b = a - 1
    if self.tree[b].weight == weight {
      while b > 0 && self.tree[b].weight == weight {
        b -= 1
      }
      b += 1
      if b > 1 {
        self.swap(a, b)
        a = b
      }
    }
    self.tree[a].weight = weight + 1
    a = self.tree[a].up
  }
  self.tree[1].weight += 1
}

///|
fn Huff::new(input : Stream, range : Int32) -> Huff {
  let tree = Array::makei(range * 2, index => {
    if index < range {
      Node::{
        up: index >> 1,
        left: index * 2,
        right: index * 2 + 1,
        code: -1,
        weight: 0,
      }
    } else {
      { up: index >> 1, left: -1, right: -1, code: index - range, weight: 1, }
    }
  })
  for index = range - 1; index >= 1; index = index - 1 {
    tree[index].weight = tree[index * 2].weight + tree[index * 2 + 1].weight
  }
  let result = Huff::{
    input,
    tree,
    symbols: Array::makei(range, index => range + index),
  }
  if range > 256 && range < 512 {
    result.update(result.symbols[256])
    result.update(result.symbols[257])
    for _ in 0..<12 {
      result.update(result.symbols[range - 3])
    }
    for _ in 0..<6 {
      result.update(result.symbols[range - 2])
    }
  } else {
    for _ in 0..<2 {
      for symbol in 0..<range {
        result.update(result.symbols[symbol])
      }
    }
  }
  result
}

///|
fn Huff::read(self : Huff) -> Int32 raise {
  let mut a = 1
  while self.tree[a].code < 0 {
    a = if self.input.bits(1) == 1 {
      self.tree[a].right
    } else {
      self.tree[a].left
    }
  }
  let code = self.tree[a].code
  self.update(a)
  code
}

///|
fn lz(data : Bytes, version : Int32) -> Bytes raise {
  let input = Stream::new(data~)
  let rle = if version == 1 { false } else { input.bits(1) != 0 }
  let distance_tree = Huff::new(input, 8)
  let length_tree = Huff::new(input, 8)
  let length = input.bits(24)
  let mut ranges = 1
  while (1 << (3 * ranges)) - 1 < length {
    ranges += 1
  }
  let dup2 = 256 + 8 * ranges
  let symbols = Huff::new(input, dup2 + 3)
  let preload = 7168
  let window : Array[Byte] = Array::make(preload + length, 0)
  let mut index = 0
  for k in 0..<32 {
    for j in 0..<96 {
      window[index] = k.to_byte()
      window[index + 1] = j.to_byte()
      index += 2
    }
  }
  for j in 0..<256 {
    for _ in 0..<4 {
      window[index] = j.to_byte()
      index += 1
    }
  }
  let output = Stream::new()
  let mut state = 0
  let mut escape = 0
  let mut repeats = 0
  fn emit(byte : Int32) -> Unit raise {
    if !rle {
      output.put(byte)
      return
    }
    match state {
      0 => {
        escape = byte
        state = 1
      }
      1 => if byte == escape { state = 2 } else { output.put(byte) }
      2 => {
        repeats = byte
        if repeats == 0 {
          output.put(escape)
          state = 1
        } else {
          state = 3
        }
      }
      _ => {
        for _ in 0..<repeats {
          output.put(byte)
        }
        state = 1
      }
    }
  }
  let mut pos = 0
  while pos < length {
    let symbol = symbols.read()
    if symbol >= 256 && symbol < dup2 {
      let mut value = symbol - 256
      let count = value / 8 + 1
      guard count <= ranges else {
        bad("invalid MTX distance range")
        return b""
      }
      let mut bits = value % 8
      value = bits & 3
      let mut iterations = 0
      while (bits & 4) != 0 {
        guard iterations < 16 && value <= budget >> 2 else {
          bad("MTX match length overflow")
          return b""
        }
        bits = length_tree.read()
        value = (value << 2) | (bits & 3)
        iterations += 1
      }
      let mut match_length = value + 2
      let mut distance = 0
      for _ in 0..<count {
        distance = (distance << 3) | distance_tree.read()
      }
      distance += 1
      if distance >= 512 {
        match_length += 1
      }
      let start = preload + pos - distance - match_length + 1
      guard start >= 0 && match_length <= length - pos else {
        bad("MTX match outside window")
        return b""
      }
      for i in 0..<match_length {
        let byte = window[start + i]
        window[preload + pos] = byte
        pos += 1
        emit(byte.to_int())
      }
    } else {
      let value = if symbol < 256 {
        symbol
      } else {
        let distance = (symbol - dup2 + 1) * 2
        window[preload + pos - distance].to_int()
      }
      window[preload + pos] = value.to_byte()
      pos += 1
      emit(value)
    }
  }
  guard !rle || state == 1 || (length == 0 && state == 0) else {
    bad("unfinished MTX run length escape")
    return b""
  }
  output.bytes()
}

// Port of subsetter 0.2.6 `src/cff/dict/mod.rs`, `src/cff/operator.rs` and
// `src/cff/argstack.rs` (the `DictionaryParser` was taken from ttf-parser).

///|
const TWO_BYTE_OPERATOR_MARK : Int = 12

///|
/// An operator: one byte, or `12` followed by a second byte (encoded as
/// `12 << 8 | b`).
priv struct Operator(Int) derive(Eq)

///|
fn Operator::from_one_byte(b : Int) -> Operator {
  Operator(b)
}

///|
fn Operator::from_two_byte(b : Int) -> Operator {
  Operator((TWO_BYTE_OPERATOR_MARK << 8) | b)
}

///|
fn Operator::write(self : Operator, w : Writer) -> Unit {
  let Operator(v) = self
  if v > 0xFF {
    w.write_u8(v >> 8)
    w.write_u8(v & 0xFF)
  } else {
    w.write_u8(v)
  }
}

// TOP DICT OPERATORS

///|
let op_notice : Operator = Operator::from_one_byte(1)

///|
let op_font_bbox : Operator = Operator::from_one_byte(5)

///|
let op_copyright : Operator = Operator::from_two_byte(0)

///|
let op_font_matrix : Operator = Operator::from_two_byte(7)

///|
let op_charset : Operator = Operator::from_one_byte(15)

///|
let op_encoding : Operator = Operator::from_one_byte(16)

///|
let op_char_strings : Operator = Operator::from_one_byte(17)

///|
let op_private : Operator = Operator::from_one_byte(18)

// TOP DICT OPERATORS (CID FONTS)

///|
let op_ros : Operator = Operator::from_two_byte(30)

///|
let op_cid_count : Operator = Operator::from_two_byte(34)

///|
let op_fd_array : Operator = Operator::from_two_byte(36)

///|
let op_fd_select : Operator = Operator::from_two_byte(37)

///|
let op_font_name : Operator = Operator::from_two_byte(38)

// PRIVATE DICT OPERATORS

///|
let op_subrs : Operator = Operator::from_one_byte(19)

///|
const MAX_OPERANDS_LEN : Int = 48

///|
priv struct DictionaryParser {
  data : BytesView
  mut offset : Int
  mut operands_offset : Int
  operands : Array[Number]
}

///|
fn DictionaryParser::new(data : BytesView) -> DictionaryParser {
  { data, offset: 0, operands_offset: 0, operands: [], }
}

///|
fn DictionaryParser::parse_next(self : DictionaryParser) -> Operator? {
  let r = Reader::new_at(self.data, self.offset)
  self.operands_offset = self.offset
  while !r.at_end() {
    // 0..=21 bytes are operators.
    guard r.peak_u8() is Some(b) else { return None }
    if is_dict_one_byte_op(b) {
      guard r.read_u8() is Some(b) else { return None }
      let mut operator = Operator::from_one_byte(b)
      if b == TWO_BYTE_OPERATOR_MARK {
        guard r.read_u8() is Some(b2) else { return None }
        operator = Operator::from_two_byte(b2)
      }
      self.offset = r.offset()
      return Some(operator)
    } else {
      guard Number::parse_cff_number(r) is Some(_) else { return None }
    }
  }
  None
}

///|
fn DictionaryParser::parse_operands(self : DictionaryParser) -> Unit? {
  let r = Reader::new_at(self.data, self.operands_offset)
  self.operands.clear()
  while !r.at_end() {
    guard r.peak_u8() is Some(b) else { return None }
    // 0..=21 bytes are operators.
    if is_dict_one_byte_op(b) {
      guard r.read_u8() is Some(_) else { return None }
      break
    } else {
      guard Number::parse_cff_number(r) is Some(op) else { return None }
      self.operands.push(op)
      if self.operands.length() >= MAX_OPERANDS_LEN {
        break
      }
    }
  }
  Some(())
}

///|
fn DictionaryParser::parse_sid(self : DictionaryParser) -> Int? {
  guard self.parse_operands() is Some(_) else { return None }
  let operands = self.operands
  if operands.length() == 1 {
    guard operands[0].as_i32() is Some(v) else { return None }
    if v >= 0 && v <= 0xFFFF {
      Some(v)
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn DictionaryParser::parse_offset(self : DictionaryParser) -> Int? {
  guard self.parse_operands() is Some(_) else { return None }
  let operands = self.operands
  if operands.length() == 1 {
    operands[0].as_u32()
  } else {
    None
  }
}

///|
fn DictionaryParser::parse_font_bbox(self : DictionaryParser) -> Array[Number]? {
  guard self.parse_operands() is Some(_) else { return None }
  if self.operands.length() == 4 {
    Some(self.operands.copy())
  } else {
    None
  }
}

///|
fn DictionaryParser::parse_font_matrix(
  self : DictionaryParser,
) -> Array[Number]? {
  guard self.parse_operands() is Some(_) else { return None }
  if self.operands.length() == 6 {
    Some(self.operands.copy())
  } else {
    None
  }
}

///|
/// A `(start, end)` range.
fn DictionaryParser::parse_range(self : DictionaryParser) -> (Int, Int)? {
  guard self.parse_operands() is Some(_) else { return None }
  let operands = self.operands
  if operands.length() == 2 {
    guard operands[0].as_u32() is Some(len) else { return None }
    guard operands[1].as_u32() is Some(start) else { return None }
    // (`usize` addition doesn't overflow on 64-bit targets.)
    let end = start.to_int64() + len.to_int64()
    Some((start, if end > 0x7FFFFFFFL { 0x7FFFFFFF } else { end.to_int() }))
  } else {
    None
  }
}

///|
fn is_dict_one_byte_op(b : Int) -> Bool {
  match b {
    0..=27 => true
    28..=30 => false // numbers
    31 => true // Reserved
    32..=254 => false // numbers
    _ => true // Reserved
  }
}

///|
/// Write the operands of a DICT entry.
fn write_numbers(w : Writer, numbers : ArrayView[Number]) -> Unit {
  for n in numbers {
    n.write(w)
  }
}

///|
/// The arguments stack (taken from ttf-parser).
priv struct ArgumentsStack {
  data : Array[Number]
}

///|
fn ArgumentsStack::new() -> ArgumentsStack {
  { data: [], }
}

///|
fn ArgumentsStack::len(self : ArgumentsStack) -> Int {
  self.data.length()
}

///|
fn ArgumentsStack::push(
  self : ArgumentsStack,
  n : Number,
) -> Unit raise SubsetError {
  if self.len() == MAX_OPERANDS_LEN {
    raise CFFError
  }
  self.data.push(n)
}

///|
fn ArgumentsStack::pop(self : ArgumentsStack) -> Number? {
  self.data.pop()
}

///|
fn ArgumentsStack::pop_all(self : ArgumentsStack) -> Int {
  let n = self.data.length()
  self.data.clear()
  n
}

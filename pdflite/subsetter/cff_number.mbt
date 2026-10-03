// Port of subsetter 0.2.6 `src/cff/number.rs`.

///|
const FLOAT_STACK_LEN : Int = 64

///|
const END_OF_FLOAT_FLAG : Int = 0xf

///|
/// A number in a CFF DICT or charstring.
priv enum Number {
  /// A real number (`RealNumber`, an `f32`).
  Real(Float)
  /// An integer (`IntegerNumber`).
  Integer(Int)
  /// A 16.16 fixed-point number (`FixedNumber`, charstrings only).
  Fixed(Int)
}

///|
fn Number::from_i32(num : Int) -> Number {
  Integer(num)
}

///|
fn Number::from_f32(num : Float) -> Number {
  Real(num)
}

///|
fn Number::zero() -> Number {
  Integer(0)
}

///|
fn Number::one() -> Number {
  Integer(1)
}

///|
fn Number::parse_cff_number(r : Reader) -> Number? {
  parse_number(r, false)
}

///|
fn Number::parse_char_string_number(r : Reader) -> Number? {
  parse_number(r, true)
}

///|
fn parse_number(r : Reader, charstring_num : Bool) -> Number? {
  guard r.peak_u8() is Some(b) else { return None }
  match b {
    30 =>
      match parse_real(r) {
        Some(n) => Some(Real(n))
        None => None
      }
    // FIXED only exists in charstrings.
    255 => {
      if charstring_num {
        return match parse_fixed(r) {
          Some(n) => Some(Fixed(n))
          None => None
        }
      }
      None
    }
    _ =>
      match parse_integer(r) {
        Some(n) => Some(Integer(n))
        None => None
      }
  }
}

///|
fn parse_fixed(r : Reader) -> Int? {
  guard r.read_u8() is Some(b0) else { return None }
  if b0 != 255 {
    return None
  }
  r.read_i32()
}

///|
fn parse_integer(r : Reader) -> Int? {
  guard r.read_u8() is Some(b0) else { return None }
  match b0 {
    28 => r.read_i16()
    29 => r.read_i32()
    32..=246 => Some(b0 - 139)
    247..=250 => {
      guard r.read_u8() is Some(b1) else { return None }
      Some((b0 - 247) * 256 + b1 + 108)
    }
    251..=254 => {
      guard r.read_u8() is Some(b1) else { return None }
      Some(-(b0 - 251) * 256 - b1 - 108)
    }
    _ => None
  }
}

///|
/// The parsing logic was taken from ttf-parser.
fn parse_real(r : Reader) -> Float? {
  let data = FixedArray::make(FLOAT_STACK_LEN, b'0')
  let mut idx = 0
  guard r.read_u8() is Some(b0) else { return None }
  if b0 != 30 {
    return None
  }
  for ;; {
    guard r.read_u8() is Some(b1) else { return None }
    let nibble1 = b1 >> 4
    let nibble2 = b1 & 15
    if nibble1 == END_OF_FLOAT_FLAG {
      break
    }
    guard parse_float_nibble(nibble1, idx, data) is Some(i) else { return None }
    idx = i
    if nibble2 == END_OF_FLOAT_FLAG {
      break
    }
    guard parse_float_nibble(nibble2, idx, data) is Some(i) else { return None }
    idx = i
  }
  let sb = StringBuilder()
  for i in 0..<idx {
    sb.write_char(data[i].to_int().unsafe_to_char())
  }
  parse_f32(sb.to_string())
}

///|
fn parse_float_nibble(nibble : Int, idx : Int, data : FixedArray[Byte]) -> Int? {
  let mut idx = idx
  if idx == FLOAT_STACK_LEN {
    return None
  }
  match nibble {
    0..=9 => data[idx] = (48 + nibble).to_byte()
    10 => data[idx] = b'.'
    11 => data[idx] = b'E'
    12 => {
      if idx + 1 == FLOAT_STACK_LEN {
        return None
      }
      data[idx] = b'E'
      idx += 1
      data[idx] = b'-'
    }
    13 => return None
    14 => data[idx] = b'-'
    _ => return None
  }
  idx += 1
  Some(idx)
}

///|
/// Write a number (upstream `Writeable for Number`).
fn Number::write(self : Number, w : Writer) -> Unit {
  match self {
    Real(n) => write_real(n, w)
    Integer(n) => write_integer(n, w)
    Fixed(n) => {
      w.write_u8(255)
      w.write_i32(n)
    }
  }
}

///|
/// Not the fastest implementation, but floats don't appear that often
/// anyway, so it's good enough.
fn write_real(n : Float, w : Writer) -> Unit {
  let nibbles = []
  let string_form = rust_display_f32(n)
  for c in string_form {
    match c {
      '0'..='9' => nibbles.push(c.to_int() - 48)
      '.' => nibbles.push(0xA)
      '-' => nibbles.push(0xE)
      // (Upstream panics: `inf` or `NaN`.)
      _ => {
        w.failed = true
        return
      }
    }
  }
  nibbles.push(0xF)
  if nibbles.length() % 2 != 0 {
    nibbles.push(0xF)
  }

  // Prefix of fixed number.
  w.write_u8(30)
  let mut i = 0
  while i < nibbles.length() {
    w.write_u8((nibbles[i] << 4) | nibbles[i + 1])
    i += 2
  }
}

///|
fn write_integer(n : Int, w : Writer) -> Unit {
  if n >= -107 && n <= 107 {
    w.write_u8(n + 139)
  } else if n >= 108 && n <= 1131 {
    let temp = n - 108
    w.write_u8(temp / 256 + 247)
    w.write_u8(temp % 256)
  } else if n >= -1131 && n <= -108 {
    let temp = -n - 108
    w.write_u8(temp / 256 + 251)
    w.write_u8(temp % 256)
  } else if n >= -32768 && n <= 32767 {
    w.write_u8(28)
    w.write_u16(n)
  } else {
    write_integer_5_bytes(n, w)
  }
}

///|
/// Write the number as a 5 byte sequence. This is necessary when writing
/// offsets, because we need to the length of the number to stay stable,
/// since it would otherwise shift everything.
fn write_integer_5_bytes(n : Int, w : Writer) -> Unit {
  w.write_u8(29)
  w.write_i32(n)
}

///|
fn fixed_as_f32(n : Int) -> Float {
  Float::from_int(n) / 65536.0
}

///|
fn Number::as_f64(self : Number) -> Double {
  match self {
    Integer(n) => n.to_double()
    Real(n) => n.to_double()
    Fixed(n) => fixed_as_f32(n).to_double()
  }
}

///|
/// Rust's `f32::fract() == 0.0` followed by a saturating `as i32`.
fn f32_as_i32_if_integral(n : Float) -> Int? {
  let d = n.to_double()
  if d - d.trunc() == 0.0 {
    Some(saturating_i32(d))
  } else {
    None
  }
}

///|
/// Rust's saturating `as i32` cast of a float (NaN is 0).
fn saturating_i32(d : Double) -> Int {
  if d.is_nan() {
    0
  } else if d >= 2147483647.0 {
    2147483647
  } else if d <= -2147483648.0 {
    -2147483648
  } else {
    d.to_int()
  }
}

///|
fn Number::as_i32(self : Number) -> Int? {
  match self {
    Integer(n) => Some(n)
    Real(n) => f32_as_i32_if_integral(n)
    Fixed(n) => f32_as_i32_if_integral(fixed_as_f32(n))
  }
}

///|
fn Number::as_u32(self : Number) -> Int? {
  guard self.as_i32() is Some(n) else { return None }
  if n < 0 {
    None
  } else {
    Some(n)
  }
}

///|
/// Adapted from ttf_parser's Transform::combine.
fn Number::combine(t1 : Array[Number], t2 : Array[Number]) -> Array[Number] {
  let a = (i : Int) => t1[i].as_f64()
  let b = (i : Int) => t2[i].as_f64()
  [
    Real(Float::from_double(a(0) * b(0) + a(2) * b(1))),
    Real(Float::from_double(a(1) * b(0) + a(3) * b(1))),
    Real(Float::from_double(a(0) * b(2) + a(2) * b(3))),
    Real(Float::from_double(a(1) * b(2) + a(3) * b(3))),
    Real(Float::from_double(a(0) * b(4) + a(2) * b(5) + a(4))),
    Real(Float::from_double(a(1) * b(4) + a(3) * b(5) + a(5))),
  ]
}

///|
/// A CFF string ID.
const STANDARD_STRING_LEN : Int = 391

///|
fn is_standard_string(sid : Int) -> Bool {
  sid < STANDARD_STRING_LEN
}

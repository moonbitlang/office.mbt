// Port of read-fonts 0.39.2 `src/font_data.rs` and `src/read.rs` (subset).

///|
/// An error that occurs when reading font data.
pub(all) suberror ReadError {
  OutOfBounds
  InvalidFormat(Int64)
  InvalidSfnt(UInt)
  InvalidTtc(@font_types.Tag)
  InvalidCollectionIndex(UInt)
  InvalidArrayLen
  ValidationError
  NullOffset
  TableIsMissing(@font_types.Tag)
  MetricIsMissing(@font_types.Tag)
  MalformedData(String)
}

///|
pub impl Show for ReadError with fn output(self, logger) {
  match self {
    OutOfBounds => logger.write_string("An offset was out of bounds")
    InvalidFormat(x) => logger.write_string("Invalid format '\{x}'")
    InvalidSfnt(ver) =>
      logger.write_string("Invalid sfnt version 0x\{hex_upper8(ver)}")
    InvalidTtc(tag) => logger.write_string("Invalid ttc tag \{tag}")
    InvalidCollectionIndex(ix) =>
      logger.write_string("Invalid index \{ix} for font collection")
    InvalidArrayLen =>
      logger.write_string("Specified array length not a multiple of item size")
    ValidationError => logger.write_string("A validation error occurred")
    NullOffset => logger.write_string("An offset was unexpectedly null")
    TableIsMissing(tag) => logger.write_string("the \{tag} table is missing")
    MetricIsMissing(tag) => logger.write_string("the \{tag} metric is missing")
    MalformedData(msg) => logger.write_string("Malformed data: '\{msg}'")
  }
}

///|
fn hex_upper8(v : UInt) -> String {
  let digits = "0123456789ABCDEF"
  let sb = StringBuilder()
  for i in 0..<8 {
    let d = ((v >> ((7 - i) * 4)) & 0xFU).reinterpret_as_int()
    sb.write_char(digits.get_char(d).unwrap())
  }
  sb.to_string()
}

///|
/// A reference to raw binary font data.
pub(all) struct FontData {
  bytes : BytesView
}

///|
pub fn FontData::new(bytes : BytesView) -> FontData {
  { bytes, }
}

///|
pub fn FontData::empty() -> FontData {
  { bytes: b"", }
}

///|
/// The length of the data, in bytes.
pub fn FontData::len(self : FontData) -> Int {
  self.bytes.length()
}

///|
pub fn FontData::is_empty(self : FontData) -> Bool {
  self.bytes.length() == 0
}

///|
/// Returns the data as a byte view.
pub fn FontData::as_bytes(self : FontData) -> BytesView {
  self.bytes
}

///|
/// Returns `self[pos..]`.
pub fn FontData::split_off(self : FontData, pos : Int) -> FontData? {
  if pos < 0 || pos > self.bytes.length() {
    None
  } else {
    Some({ bytes: self.bytes[pos:], })
  }
}

///|
/// Returns `self[start..end]`.
pub fn FontData::slice(self : FontData, start : Int, end : Int) -> FontData? {
  if start < 0 || start > end || end > self.bytes.length() {
    None
  } else {
    Some({ bytes: self.bytes[start:end], })
  }
}

///|
/// Returns the bytes `start..end` (Rust `bytes.get(range)`).
pub fn FontData::get(self : FontData, start : Int, end : Int) -> BytesView? {
  if start < 0 || start > end || end > self.bytes.length() {
    None
  } else {
    Some(self.bytes[start:end])
  }
}

///|
fn FontData::check(
  self : FontData,
  offset : Int,
  len : Int,
) -> Unit raise ReadError {
  if offset < 0 || len > self.bytes.length() - offset {
    raise OutOfBounds
  }
}

///|
pub fn FontData::read_u8(self : FontData, offset : Int) -> Int raise ReadError {
  self.check(offset, 1)
  self.bytes[offset].to_int()
}

///|
pub fn FontData::read_i8(self : FontData, offset : Int) -> Int raise ReadError {
  self.check(offset, 1)
  self.bytes[offset].to_int() << 24 >> 24
}

///|
pub fn FontData::read_u16(self : FontData, offset : Int) -> Int raise ReadError {
  self.check(offset, 2)
  (self.bytes[offset].to_int() << 8) | self.bytes[offset + 1].to_int()
}

///|
pub fn FontData::read_i16(self : FontData, offset : Int) -> Int raise ReadError {
  self.check(offset, 2)
  (self.bytes[offset].to_int() << 24 >> 16) | self.bytes[offset + 1].to_int()
}

///|
pub fn FontData::read_u24(self : FontData, offset : Int) -> Int raise ReadError {
  self.check(offset, 3)
  (self.bytes[offset].to_int() << 16) |
  (self.bytes[offset + 1].to_int() << 8) |
  self.bytes[offset + 2].to_int()
}

///|
/// Reads a big-endian 32-bit value (as raw bits).
pub fn FontData::read_i32(self : FontData, offset : Int) -> Int raise ReadError {
  self.check(offset, 4)
  (self.bytes[offset].to_int() << 24) |
  (self.bytes[offset + 1].to_int() << 16) |
  (self.bytes[offset + 2].to_int() << 8) |
  self.bytes[offset + 3].to_int()
}

///|
pub fn FontData::read_u32(
  self : FontData,
  offset : Int,
) -> UInt raise ReadError {
  self.read_i32(offset).reinterpret_as_uint()
}

///|
/// Reads a 16.16 fixed point value.
pub fn FontData::read_fixed(
  self : FontData,
  offset : Int,
) -> @font_types.Fixed raise ReadError {
  @font_types.Fixed::from_bits(self.read_i32(offset))
}

///|
/// Reads a 2.14 fixed point value.
pub fn FontData::read_f2dot14(
  self : FontData,
  offset : Int,
) -> @font_types.F2Dot14 raise ReadError {
  @font_types.F2Dot14::from_bits(self.read_i16(offset))
}

///|
/// Returns the bytes for an array of `n` elements of `size` bytes each at
/// `offset` (Rust `read_array`).
pub fn FontData::read_array(
  self : FontData,
  offset : Int,
  n : Int,
  size : Int,
) -> FontData raise ReadError {
  let len = n.to_int64() * size.to_int64()
  if offset < 0 ||
    n < 0 ||
    offset > self.bytes.length() ||
    len > (self.bytes.length() - offset).to_int64() {
    raise OutOfBounds
  }
  { bytes: self.bytes[offset:offset + len.to_int()], }
}

///|
pub fn FontData::cursor(self : FontData) -> Cursor {
  { data: self, pos: 0, }
}

///|
/// A cursor for sequential reads.
pub(all) struct Cursor {
  data : FontData
  mut pos : Int
}

///|
fn sat_add(a : Int, b : Int) -> Int {
  let r = a.to_int64() + b.to_int64()
  if r > 2147483647L {
    2147483647
  } else {
    r.to_int()
  }
}

///|
pub fn Cursor::advance_by(self : Cursor, n : Int) -> Unit {
  self.pos = sat_add(self.pos, n)
}

///|
pub fn Cursor::read_u8(self : Cursor) -> Int raise ReadError {
  let p = self.pos
  self.advance_by(1)
  self.data.read_u8(p)
}

///|
pub fn Cursor::read_i8(self : Cursor) -> Int raise ReadError {
  let p = self.pos
  self.advance_by(1)
  self.data.read_i8(p)
}

///|
pub fn Cursor::read_u16(self : Cursor) -> Int raise ReadError {
  let p = self.pos
  self.advance_by(2)
  self.data.read_u16(p)
}

///|
pub fn Cursor::read_i16(self : Cursor) -> Int raise ReadError {
  let p = self.pos
  self.advance_by(2)
  self.data.read_i16(p)
}

///|
pub fn Cursor::read_u24(self : Cursor) -> Int raise ReadError {
  let p = self.pos
  self.advance_by(3)
  self.data.read_u24(p)
}

///|
pub fn Cursor::read_i32(self : Cursor) -> Int raise ReadError {
  let p = self.pos
  self.advance_by(4)
  self.data.read_i32(p)
}

///|
pub fn Cursor::read_u32(self : Cursor) -> UInt raise ReadError {
  self.read_i32().reinterpret_as_uint()
}

///|
/// Reads an array of `n` elements of `size` bytes and advances the cursor.
pub fn Cursor::read_array(
  self : Cursor,
  n : Int,
  size : Int,
) -> FontData raise ReadError {
  let len = n.to_int64() * size.to_int64()
  if len > 2147483647L {
    raise OutOfBounds
  }
  let p = self.pos
  self.advance_by(len.to_int())
  self.data.read_array(p, n, size)
}

///|
/// Returns the current position, or an error if we are out of bounds.
pub fn Cursor::position(self : Cursor) -> Int raise ReadError {
  if self.pos > self.data.len() {
    raise OutOfBounds
  }
  self.pos
}

///|
pub fn Cursor::remaining_bytes(self : Cursor) -> Int {
  let r = self.data.len() - self.pos
  if r < 0 {
    0
  } else {
    r
  }
}

///|
pub fn Cursor::remaining(self : Cursor) -> FontData? {
  self.data.split_off(self.pos)
}

///|
pub fn Cursor::is_empty(self : Cursor) -> Bool {
  self.pos >= self.data.len()
}

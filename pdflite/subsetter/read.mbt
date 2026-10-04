// Port of subsetter 0.2.6 `src/read.rs`: a readable stream of binary data.

///|
/// A readable stream of binary data.
priv struct Reader {
  /// The underlying data of the reader.
  data : BytesView
  /// The current offset in bytes. Is not guaranteed to be in range.
  mut offset : Int
}

///|
/// Create a new readable stream of binary data.
fn Reader::new(data : BytesView) -> Reader {
  { data, offset: 0, }
}

///|
/// Create a new readable stream of binary data at a specific position.
fn Reader::new_at(data : BytesView, offset : Int) -> Reader {
  { data, offset, }
}

///|
/// The remaining data from the current offset.
fn Reader::tail(self : Reader) -> BytesView? {
  if self.offset >= 0 && self.offset <= self.data.length() {
    Some(self.data[self.offset:])
  } else {
    None
  }
}

///|
/// Returns the current offset.
fn Reader::offset(self : Reader) -> Int {
  self.offset
}

///|
/// Read a certain number of bytes.
fn Reader::read_bytes(self : Reader, len : Int) -> BytesView? {
  // (`checked_add` on `usize`: lengths and offsets are non-negative and
  // below 2^31, so the sum fits into an `Int64`.)
  let end = self.offset.to_int64() + len.to_int64()
  if len < 0 ||
    self.offset < 0 ||
    self.offset > self.data.length() ||
    end > self.data.length().to_int64() {
    return None
  }
  let v = self.data[self.offset:end.to_int()]
  self.offset = end.to_int()
  Some(v)
}

///|
fn Reader::read_u8(self : Reader) -> Int? {
  guard self.read_bytes(1) is Some(b) else { return None }
  Some(b[0].to_int())
}

///|
/// Peek a byte without advancing (upstream `peak::<u8>`).
fn Reader::peak_u8(self : Reader) -> Int? {
  let offset = self.offset
  let r = self.read_u8()
  self.offset = offset
  r
}

///|
fn Reader::read_u16(self : Reader) -> Int? {
  guard self.read_bytes(2) is Some(b) else { return None }
  Some((b[0].to_int() << 8) | b[1].to_int())
}

///|
fn Reader::read_i16(self : Reader) -> Int? {
  guard self.read_u16() is Some(v) else { return None }
  Some(if v >= 0x8000 { v - 0x10000 } else { v })
}

///|
fn Reader::read_u24(self : Reader) -> Int? {
  guard self.read_bytes(3) is Some(b) else { return None }
  Some((b[0].to_int() << 16) | (b[1].to_int() << 8) | b[2].to_int())
}

///|
fn Reader::read_u32(self : Reader) -> UInt? {
  guard self.read_bytes(4) is Some(b) else { return None }
  Some(
    (b[0].to_uint() << 24) |
    (b[1].to_uint() << 16) |
    (b[2].to_uint() << 8) |
    b[3].to_uint(),
  )
}

///|
fn Reader::read_i32(self : Reader) -> Int? {
  guard self.read_u32() is Some(v) else { return None }
  Some(v.reinterpret_as_int())
}

///|
/// Reads the next `count` elements of `size` bytes each as a lazy array.
fn Reader::read_array16(self : Reader, count : Int, size : Int) -> LazyArray16? {
  guard self.read_bytes(count * size) is Some(data) else { return None }
  Some({ data, size, })
}

///|
/// Check whether the reader is at the end of the buffer.
fn Reader::at_end(self : Reader) -> Bool {
  self.offset >= self.data.length()
}

///|
/// Jump to a specific location.
fn Reader::jump(self : Reader, offset : Int) -> Unit {
  self.offset = offset
}

///|
/// Skip the next `n` bytes from the stream.
fn Reader::skip_bytes(self : Reader, n : Int) -> Unit {
  self.read_bytes(n) |> ignore
}

///|
/// A slice-like container that converts internal binary data only on access
/// (elements are big-endian unsigned integers of `size` bytes).
priv struct LazyArray16 {
  data : BytesView
  size : Int
}

///|
/// Returns array's length.
fn LazyArray16::len(self : LazyArray16) -> Int {
  (self.data.length() / self.size) & 0xFFFF
}

///|
/// Returns a value at `index`.
fn LazyArray16::get(self : LazyArray16, index : Int) -> Int? {
  if index < self.len() {
    let start = index * self.size
    let r = Reader::new(self.data[start:start + self.size])
    match self.size {
      1 => r.read_u8()
      2 => r.read_u16()
      _ => None
    }
  } else {
    None
  }
}

///|
/// Convert a `u32` offset to an `Int` offset (offsets beyond `Int` are out of
/// range of any data anyway).
fn u32_offset(v : UInt) -> Int {
  if v > 0x7FFFFFFFU {
    0x7FFFFFFF
  } else {
    v.reinterpret_as_int()
  }
}

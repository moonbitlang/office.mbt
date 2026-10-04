// Byte cursor used by the PostScript parsers (mirrors read-fonts `Cursor`
// but raises `PsError::Read(OutOfBounds)`).

///|
priv struct Cursor {
  data : BytesView
  mut pos : Int
}

///|
fn Cursor::new(data : BytesView) -> Cursor {
  { data, pos: 0, }
}

///|
fn Cursor::advance_by(self : Cursor, n : Int) -> Unit {
  let r = self.pos.to_int64() + n.to_int64()
  self.pos = if r > 2147483647L { 2147483647 } else { r.to_int() }
}

///|
fn Cursor::check(self : Cursor, p : Int, len : Int) -> Unit raise PsError {
  if p < 0 || len > self.data.length() - p {
    raise oob()
  }
}

///|
fn Cursor::read_u8(self : Cursor) -> Int raise PsError {
  let p = self.pos
  self.advance_by(1)
  self.check(p, 1)
  self.data[p].to_int()
}

///|
fn Cursor::read_i16(self : Cursor) -> Int raise PsError {
  let p = self.pos
  self.advance_by(2)
  self.check(p, 2)
  (self.data[p].to_int() << 24 >> 16) | self.data[p + 1].to_int()
}

///|
fn Cursor::read_i32(self : Cursor) -> Int raise PsError {
  let p = self.pos
  self.advance_by(4)
  self.check(p, 4)
  (self.data[p].to_int() << 24) |
  (self.data[p + 1].to_int() << 16) |
  (self.data[p + 2].to_int() << 8) |
  self.data[p + 3].to_int()
}

///|
/// Reads `n` elements of `size` bytes and advances.
fn Cursor::read_array(
  self : Cursor,
  n : Int,
  size : Int,
) -> BytesView raise PsError {
  let len = n.to_int64() * size.to_int64()
  if len > 2147483647L {
    raise oob()
  }
  let p = self.pos
  self.advance_by(len.to_int())
  self.check(p, len.to_int())
  self.data[p:p + len.to_int()]
}

///|
fn Cursor::position(self : Cursor) -> Int raise PsError {
  if self.pos > self.data.length() {
    raise oob()
  }
  self.pos
}

///|
fn Cursor::remaining_bytes(self : Cursor) -> Int {
  let r = self.data.length() - self.pos
  if r < 0 {
    0
  } else {
    r
  }
}

// Big-endian helpers on byte views (bounds checked).

///|
fn read_u8_at(data : BytesView, p : Int) -> Int raise PsError {
  if p < 0 || p + 1 > data.length() {
    raise oob()
  }
  data[p].to_int()
}

///|
fn read_u16_at(data : BytesView, p : Int) -> Int raise PsError {
  if p < 0 || p + 2 > data.length() {
    raise oob()
  }
  (data[p].to_int() << 8) | data[p + 1].to_int()
}

///|
fn read_u24_at(data : BytesView, p : Int) -> Int raise PsError {
  if p < 0 || p + 3 > data.length() {
    raise oob()
  }
  (data[p].to_int() << 16) | (data[p + 1].to_int() << 8) | data[p + 2].to_int()
}

///|
fn read_u32_at(data : BytesView, p : Int) -> Int raise PsError {
  if p < 0 || p + 4 > data.length() {
    raise oob()
  }
  (data[p].to_int() << 24) |
  (data[p + 1].to_int() << 16) |
  (data[p + 2].to_int() << 8) |
  data[p + 3].to_int()
}

///|
/// `data.get(start..)` in Rust.
fn get_from(data : BytesView, start : Int) -> BytesView? {
  if start < 0 || start > data.length() {
    None
  } else {
    Some(data[start:])
  }
}

///|
/// `data.get(start..end)` in Rust.
fn get_range(data : BytesView, start : Int, end : Int) -> BytesView? {
  if start < 0 || start > end || end > data.length() {
    None
  } else {
    Some(data[start:end])
  }
}

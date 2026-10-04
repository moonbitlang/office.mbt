// Port of subsetter 0.2.6 `src/write.rs`: a writable stream of binary data.

///|
/// A writable stream of binary data.
priv struct Writer {
  buf : @buffer.Buffer
  /// Set when a value could not be written (upstream panics: a non-finite
  /// real number in a CFF DICT).
  mut failed : Bool
}

///|
/// Create a new writable stream of binary data.
fn Writer::new() -> Writer {
  { buf: Buffer(size_hint=1024), failed: false, }
}

///|
fn Writer::write_u8(self : Writer, v : Int) -> Unit {
  self.buf.write_byte((v & 0xFF).to_byte())
}

///|
fn Writer::write_u16(self : Writer, v : Int) -> Unit {
  self.buf.write_byte(((v >> 8) & 0xFF).to_byte())
  self.buf.write_byte((v & 0xFF).to_byte())
}

///|
fn Writer::write_i16(self : Writer, v : Int) -> Unit {
  self.write_u16(v)
}

///|
fn Writer::write_u24(self : Writer, v : Int) -> Unit {
  self.buf.write_byte(((v >> 16) & 0xFF).to_byte())
  self.buf.write_byte(((v >> 8) & 0xFF).to_byte())
  self.buf.write_byte((v & 0xFF).to_byte())
}

///|
fn Writer::write_u32(self : Writer, v : UInt) -> Unit {
  self.buf.write_byte(((v >> 24) & 0xFF).to_byte())
  self.buf.write_byte(((v >> 16) & 0xFF).to_byte())
  self.buf.write_byte(((v >> 8) & 0xFF).to_byte())
  self.buf.write_byte((v & 0xFF).to_byte())
}

///|
fn Writer::write_i32(self : Writer, v : Int) -> Unit {
  self.write_u32(v.reinterpret_as_uint())
}

///|
/// Give bytes into the writer.
fn Writer::write_bytes(self : Writer, bytes : BytesView) -> Unit {
  self.buf.write_bytesview(bytes)
}

///|
/// Align the contents to a byte boundary.
fn Writer::align(self : Writer, to : Int) -> Unit {
  while self.buf.length() % to != 0 {
    self.buf.write_byte(0)
  }
}

///|
/// The number of written bytes.
fn Writer::len(self : Writer) -> Int {
  self.buf.length()
}

///|
/// Return the written bytes.
fn Writer::finish(self : Writer) -> Bytes {
  self.buf.to_bytes()
}

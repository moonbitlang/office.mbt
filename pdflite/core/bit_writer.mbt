///|
/// A big-endian bit writer that accumulates PDF bytes.
///
/// Bits are packed most-significant first in each output byte. The final byte
/// is zero-padded when `align` or `to_bytes` flushes a partially filled byte.
pub struct BitWriter {
  mut current_byte : Int
  mut bit_index : Int
  bytes : Array[Byte]
} derive(Debug, Eq, ToJson)

///|
/// Creates an empty bit writer.
pub fn bit_writer_new() -> BitWriter {
  { current_byte: 0, bit_index: 0, bytes: [] }
}

///|
fn BitWriter::copy(self : BitWriter) -> BitWriter {
  {
    current_byte: self.current_byte,
    bit_index: self.bit_index,
    bytes: self.bytes.copy(),
  }
}

///|
fn BitWriter::put_bit_unchecked(self : BitWriter, bit : Int) -> Unit {
  if bit == 1 {
    self.current_byte = self.current_byte | (1 << (7 - self.bit_index))
  }
  self.bit_index += 1
  if self.bit_index == 8 {
    self.bytes.push(self.current_byte.to_byte())
    self.current_byte = 0
    self.bit_index = 0
  }
}

///|
/// Writes one bit, accepting only integer values `0` and `1`.
///
/// Raises `PdfError::InvalidBit` for any other value.
pub fn BitWriter::put_bit(self : BitWriter, bit : Int) -> Unit raise PdfError {
  if bit != 0 && bit != 1 {
    raise InvalidBit(bit)
  }
  self.put_bit_unchecked(bit)
}

///|
/// Writes the low `width` bits of an `Int` in big-endian bit order.
///
/// Raises `PdfError::InvalidBitCount` for widths outside `0..=31`.
pub fn BitWriter::put_value_int(
  self : BitWriter,
  width : Int,
  value : Int,
) -> Unit raise PdfError {
  if width < 0 || width > 31 {
    raise InvalidBitCount(width)
  }
  for offset in 0..<width {
    let shift = width - 1 - offset
    self.put_bit((value >> shift) & 1)
  }
}

///|
/// Writes the low `width` bits of an `Int64` in big-endian bit order.
///
/// Raises `PdfError::InvalidBitCount` for widths outside `0..=32`.
pub fn BitWriter::put_value_int64(
  self : BitWriter,
  width : Int,
  value : Int64,
) -> Unit raise PdfError {
  if width < 0 || width > 32 {
    raise InvalidBitCount(width)
  }
  for offset in 0..<width {
    let shift = width - 1 - offset
    self.put_bit_unchecked(((value >> shift) & 1).to_int())
  }
}

///|
/// Flushes any partial output byte, padding its unread low bits with zero.
pub fn BitWriter::align(self : BitWriter) -> Unit {
  if self.bit_index > 0 {
    self.bytes.push(self.current_byte.to_byte())
    self.current_byte = 0
    self.bit_index = 0
  }
}

///|
/// Returns the accumulated bytes, flushing a partial final byte if needed.
pub fn BitWriter::to_bytes(self : BitWriter) -> PdfBytes {
  self.align()
  Bytes::from_array(self.bytes)
}

///|
/// Appends another writer's bits after aligning this writer to a byte boundary.
///
/// The returned writer is a copy; neither input writer is mutated.
pub fn BitWriter::append_aligned(
  self : BitWriter,
  other : BitWriter,
) -> BitWriter {
  let output = self.copy()
  output.align()
  for byte in other.bytes {
    output.bytes.push(byte)
  }
  for bit_index in 0..<other.bit_index {
    output.put_bit_unchecked((other.current_byte >> (7 - bit_index)) & 1)
  }
  output
}

///|
/// Returns the number of bits currently written, including an unflushed partial
/// byte.
pub fn BitWriter::bit_length(self : BitWriter) -> Int {
  self.bytes.length() * 8 + self.bit_index
}

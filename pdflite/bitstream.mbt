///|
/// A big-endian bit reader over a `ByteCursor`.
///
/// The stream reads the most-significant bit of each byte first, matching the
/// bit order used by PDF filters such as CCITT and Flate Huffman tables.
/// `align` discards any unread bits in the current byte and resumes at the next
/// byte boundary.
pub struct BitStream {
  input : ByteCursor
  mut current_byte : Int
  mut bit_mask : Int
  mut bits_read : Int
} derive(Debug, Eq, ToJson)

///|
/// A restorable snapshot of a `BitStream` position.
///
/// The snapshot captures both the underlying byte cursor position and the
/// partially consumed current byte, so seeking back to it is safe even in the
/// middle of a byte.
pub struct BitStreamPosition {
  input_position : Int
  current_byte : Int
  bit_mask : Int
  bits_read : Int
} derive(Debug, Eq, ToJson)

///|
/// Creates a bit stream that reads from an existing byte cursor.
pub fn bitstream_of_cursor(input : ByteCursor) -> BitStream {
  { input, current_byte: 0, bit_mask: 0, bits_read: 0 }
}

///|
/// Creates a bit stream over owned PDF bytes.
///
/// The optional `source` label is forwarded to the underlying cursor and is
/// used in parse error messages.
pub fn bitstream_of_bytes(
  data : PdfBytes,
  source? : String = "bytes",
) -> BitStream {
  bitstream_of_view(data, source~)
}

///|
/// Creates a bit stream over a read-only byte view.
///
/// The returned reader does not copy `data`; callers that need ownership should
/// pass owned bytes explicitly.
pub fn bitstream_of_view(
  data : BytesView,
  source? : String = "bytes",
) -> BitStream {
  bitstream_of_cursor(byte_cursor_of_view(data, source~))
}

///|
/// Returns a restorable snapshot of the current bit position.
pub fn BitStream::position(self : BitStream) -> BitStreamPosition {
  {
    input_position: self.input.position(),
    current_byte: self.current_byte,
    bit_mask: self.bit_mask,
    bits_read: self.bits_read,
  }
}

///|
/// Restores this bit stream to a previously captured position.
///
/// Raises `PdfError::InvalidCursorPosition` if the saved byte position is not
/// valid for the underlying cursor.
pub fn BitStream::seek(self : BitStream, position : BitStreamPosition) -> Unit {
  try! self.input.seek(position.input_position)
  self.current_byte = position.current_byte
  self.bit_mask = position.bit_mask
  self.bits_read = position.bits_read
}

///|
/// Reads one bit and returns it as a boolean.
///
/// The return value is `true` for bit `1` and `false` for bit `0`. Raises
/// `PdfError::EndOfInput` if there is no byte available for the next bit.
pub fn BitStream::get_bit(self : BitStream) -> Bool raise PdfError {
  if self.bit_mask == 0 {
    let value = self.input.input_byte()
    if value == pdf_no_more {
      raise EndOfInput
    }
    self.current_byte = value
    self.bit_mask = 0x80
  }
  let bit = (self.current_byte & self.bit_mask) != 0
  self.bits_read += 1
  self.bit_mask = self.bit_mask >> 1
  bit
}

///|
/// Reads one bit and returns it as integer `0` or `1`.
///
/// Raises `PdfError::EndOfInput` if there is no byte available for the next
/// bit.
pub fn BitStream::get_bit_int(self : BitStream) -> Int raise PdfError {
  if self.get_bit() {
    1
  } else {
    0
  }
}

///|
/// Discards unread bits in the current byte and moves to the next byte
/// boundary.
pub fn BitStream::align(self : BitStream) -> Unit {
  if self.bit_mask > 0 {
    self.bits_read = (self.bits_read / 8 + 1) * 8
  }
  self.bit_mask = 0
}

///|
/// Reads up to 31 bits as a big-endian signed `Int` payload.
///
/// This function only assembles the bit pattern; it does not sign-extend the
/// result. Raises `PdfError::InvalidBitCount` for widths outside `0..=31` and
/// `PdfError::EndOfInput` if the stream ends early.
pub fn BitStream::get_value_int(
  self : BitStream,
  width : Int,
) -> Int raise PdfError {
  if width < 0 || width > 31 {
    raise InvalidBitCount(width)
  }
  let mut value = 0
  for _ in 0..<width {
    value = (value << 1) | self.get_bit_int()
  }
  value
}

///|
/// Reads up to 32 bits as a big-endian `Int64` payload.
///
/// This is useful for PDF filter fields whose packed value may not fit the
/// positive range of `Int`. Raises `PdfError::InvalidBitCount` for widths
/// outside `0..=32` and `PdfError::EndOfInput` if the stream ends early.
pub fn BitStream::get_value_int64(
  self : BitStream,
  width : Int,
) -> Int64 raise PdfError {
  if width < 0 || width > 32 {
    raise InvalidBitCount(width)
  }
  let mut value : Int64 = 0
  for _ in 0..<width {
    value = (value << 1) | self.get_bit_int().to_int64()
  }
  value
}

///|
/// Returns the number of bits consumed from this stream.
///
/// The count includes bits skipped by `align`.
pub fn BitStream::bits_read(self : BitStream) -> Int {
  self.bits_read
}

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

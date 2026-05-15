///|
/// A growable byte sink with seekable overwrite support.
///
/// `ByteOutput` tracks the current write position separately from the highest
/// position written, so callers may seek backward to patch bytes and then
/// obtain only the initialized prefix with `to_bytes`.
pub struct ByteOutput {
  data : Array[Byte]
  mut position : Int
  mut written_length : Int
} derive(Debug, Eq, ToJson)

///|
/// Creates an empty output buffer.
///
/// `initial_size` preallocates zero-filled capacity but does not count as
/// written output. Raises `PdfError::InvalidReadLength` for negative sizes.
pub fn byte_output_new(initial_size? : Int = 0) -> ByteOutput raise PdfError {
  if initial_size < 0 {
    raise PdfError::InvalidReadLength(initial_size)
  }
  let data : Array[Byte] = [ for _ in 0..<initial_size => 0 ]
  { data, position: 0, written_length: 0 }
}

///|
/// Returns the current write position.
pub fn ByteOutput::position(self : ByteOutput) -> Int {
  self.position
}

///|
/// Returns the highest written byte position.
///
/// This is the length of the byte sequence returned by `to_bytes`.
pub fn ByteOutput::length(self : ByteOutput) -> Int {
  self.written_length
}

///|
/// Moves the write position.
///
/// Seeking beyond the current length is allowed; unwritten gaps are filled with
/// zero when data is later written. Negative positions raise
/// `PdfError::InvalidCursorPosition`.
pub fn ByteOutput::seek(
  self : ByteOutput,
  position : Int,
) -> Unit raise PdfError {
  if position < 0 {
    raise PdfError::InvalidCursorPosition(position)
  }
  self.position = position
}

///|
fn ByteOutput::ensure_capacity(self : ByteOutput, length : Int) -> Unit {
  while self.data.length() < length {
    self.data.push(0)
  }
}

///|
/// Writes one byte at the current position and advances by one.
///
/// Raises `PdfError::InvalidByte` if `value` is outside the byte range
/// `0..=255`.
pub fn ByteOutput::write_byte(
  self : ByteOutput,
  value : Int,
) -> Unit raise PdfError {
  let byte = pdf_byte_of_int(value)
  self.ensure_capacity(self.position + 1)
  self.data[self.position] = byte
  self.position += 1
  if self.position > self.written_length {
    self.written_length = self.position
  }
}

///|
/// Seeks to `position`, writes one byte, and advances by one.
///
/// Raises the same errors as `seek` and `write_byte`.
pub fn ByteOutput::write_byte_at(
  self : ByteOutput,
  position : Int,
  value : Int,
) -> Unit raise PdfError {
  self.seek(position)
  self.write_byte(value)
}

///|
/// Writes a byte view at the current position and advances past it.
///
/// Raises `PdfError::InvalidReadLength` if the computed end position overflows.
pub fn ByteOutput::write_view(
  self : ByteOutput,
  bytes : BytesView,
) -> Unit raise PdfError {
  let end = self.position + bytes.length()
  if end < self.position {
    raise PdfError::InvalidReadLength(bytes.length())
  }
  self.ensure_capacity(end)
  for byte in bytes {
    self.data[self.position] = byte
    self.position += 1
  }
  if self.position > self.written_length {
    self.written_length = self.position
  }
}

///|
/// Seeks to `position`, writes a byte view, and advances past it.
///
/// Raises the same errors as `seek` and `write_view`.
pub fn ByteOutput::write_view_at(
  self : ByteOutput,
  position : Int,
  bytes : BytesView,
) -> Unit raise PdfError {
  self.seek(position)
  self.write_view(bytes)
}

///|
/// Writes a slice of a byte view at the current position.
///
/// Raises `PdfError::InvalidCursorPosition` for a negative offset,
/// `PdfError::InvalidReadLength` for a negative or overflowing length, and
/// `PdfError::EndOfInput` if the requested slice exceeds the input view.
pub fn ByteOutput::write_view_slice(
  self : ByteOutput,
  bytes : BytesView,
  offset : Int,
  length : Int,
) -> Unit raise PdfError {
  if offset < 0 {
    raise PdfError::InvalidCursorPosition(offset)
  }
  if length < 0 {
    raise PdfError::InvalidReadLength(length)
  }
  let end = offset + length
  if end < offset {
    raise PdfError::InvalidReadLength(length)
  }
  if end > bytes.length() {
    raise PdfError::EndOfInput
  }
  self.write_view(bytes[offset:end])
}

///|
/// Writes `length` copies of `value` and advances past them.
///
/// The default value is zero. Raises `PdfError::InvalidReadLength` for invalid
/// lengths and `PdfError::InvalidByte` for values outside `0..=255`.
pub fn ByteOutput::write_repeated_byte(
  self : ByteOutput,
  length : Int,
  value? : Int = 0,
) -> Unit raise PdfError {
  if length < 0 {
    raise PdfError::InvalidReadLength(length)
  }
  let byte = pdf_byte_of_int(value)
  let end = self.position + length
  if end < self.position {
    raise PdfError::InvalidReadLength(length)
  }
  self.ensure_capacity(end)
  for index in self.position..<end {
    self.data[index] = byte
  }
  self.position = end
  if self.position > self.written_length {
    self.written_length = self.position
  }
}

///|
/// Encodes an ASCII string and writes the resulting bytes.
///
/// The underlying `@ascii.encode` function is used intentionally; callers
/// should pass bytes directly for non-ASCII PDF payloads.
pub fn ByteOutput::write_ascii(
  self : ByteOutput,
  text : String,
) -> Unit raise PdfError {
  self.write_view(@ascii.encode(text))
}

///|
/// Returns the written prefix as owned PDF bytes.
///
/// Bytes beyond `length` that were only preallocated are not included.
pub fn ByteOutput::to_bytes(self : ByteOutput) -> PdfBytes {
  Bytes::from_array(self.data[:self.written_length])
}

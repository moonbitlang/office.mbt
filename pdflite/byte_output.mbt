///|
pub struct ByteOutput {
  data : Array[Byte]
  mut position : Int
  mut written_length : Int
} derive(Debug, Eq, ToJson)

///|
pub fn byte_output_new(initial_size? : Int = 0) -> ByteOutput raise PdfError {
  if initial_size < 0 {
    raise InvalidReadLength(initial_size)
  }
  let data : Array[Byte] = [ for _ in 0..<initial_size => 0 ]
  { data, position: 0, written_length: 0 }
}

///|
pub fn ByteOutput::position(self : ByteOutput) -> Int {
  self.position
}

///|
pub fn ByteOutput::length(self : ByteOutput) -> Int {
  self.written_length
}

///|
pub fn ByteOutput::seek(
  self : ByteOutput,
  position : Int,
) -> Unit raise PdfError {
  if position < 0 {
    raise InvalidCursorPosition(position)
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
pub fn ByteOutput::write_view(
  self : ByteOutput,
  bytes : BytesView,
) -> Unit raise PdfError {
  let end = self.position + bytes.length()
  if end < self.position {
    raise InvalidReadLength(bytes.length())
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
pub fn ByteOutput::write_view_slice(
  self : ByteOutput,
  bytes : BytesView,
  offset : Int,
  length : Int,
) -> Unit raise PdfError {
  if offset < 0 {
    raise InvalidCursorPosition(offset)
  }
  if length < 0 {
    raise InvalidReadLength(length)
  }
  let end = offset + length
  if end < offset {
    raise InvalidReadLength(length)
  }
  if end > bytes.length() {
    raise EndOfInput
  }
  self.write_view(bytes[offset:end])
}

///|
pub fn ByteOutput::write_ascii(
  self : ByteOutput,
  text : String,
) -> Unit raise PdfError {
  self.write_view(@ascii.encode(text)[:])
}

///|
pub fn ByteOutput::to_bytes(self : ByteOutput) -> PdfBytes {
  Bytes::from_array(self.data[:self.written_length])
}

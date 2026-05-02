///|
pub struct BitStream {
  input : ByteCursor
  mut current_byte : Int
  mut bit_mask : Int
  mut bits_read : Int
} derive(Debug, Eq, ToJson)

///|
pub struct BitStreamPosition {
  input_position : Int
  current_byte : Int
  bit_mask : Int
  bits_read : Int
} derive(Debug, Eq, ToJson)

///|
pub fn bitstream_of_cursor(input : ByteCursor) -> BitStream {
  { input, current_byte: 0, bit_mask: 0, bits_read: 0 }
}

///|
pub fn bitstream_of_bytes(
  data : PdfBytes,
  source? : String = "bytes",
) -> BitStream {
  bitstream_of_cursor(byte_cursor_of_bytes(data, source~))
}

///|
pub fn BitStream::position(self : BitStream) -> BitStreamPosition {
  {
    input_position: self.input.position(),
    current_byte: self.current_byte,
    bit_mask: self.bit_mask,
    bits_read: self.bits_read,
  }
}

///|
pub fn BitStream::seek(self : BitStream, position : BitStreamPosition) -> Unit {
  try! self.input.seek(position.input_position)
  self.current_byte = position.current_byte
  self.bit_mask = position.bit_mask
  self.bits_read = position.bits_read
}

///|
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
pub fn BitStream::get_bit_int(self : BitStream) -> Int raise PdfError {
  if self.get_bit() {
    1
  } else {
    0
  }
}

///|
pub fn BitStream::align(self : BitStream) -> Unit {
  if self.bit_mask > 0 {
    self.bits_read = (self.bits_read / 8 + 1) * 8
  }
  self.bit_mask = 0
}

///|
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
pub fn BitStream::bits_read(self : BitStream) -> Int {
  self.bits_read
}

///|
pub struct BitWriter {
  mut current_byte : Int
  mut bit_index : Int
  bytes : Array[Byte]
} derive(Debug, Eq, ToJson)

///|
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
pub fn BitWriter::put_bit(self : BitWriter, bit : Int) -> Unit raise PdfError {
  if bit != 0 && bit != 1 {
    raise InvalidBit(bit)
  }
  self.put_bit_unchecked(bit)
}

///|
pub fn BitWriter::put_value_int(
  self : BitWriter,
  width : Int,
  value : Int,
) -> Unit raise PdfError {
  if width < 0 || width > 31 {
    raise InvalidBitCount(width)
  }
  for shift = width - 1; shift >= 0; shift = shift - 1 {
    self.put_bit((value >> shift) & 1)
  }
}

///|
pub fn BitWriter::align(self : BitWriter) -> Unit {
  if self.bit_index > 0 {
    self.bytes.push(self.current_byte.to_byte())
    self.current_byte = 0
    self.bit_index = 0
  }
}

///|
pub fn BitWriter::to_bytes(self : BitWriter) -> PdfBytes {
  self.align()
  Bytes::from_array(self.bytes)
}

///|
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
pub fn BitWriter::bit_length(self : BitWriter) -> Int {
  self.bytes.length() * 8 + self.bit_index
}

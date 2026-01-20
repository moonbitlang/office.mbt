///|
priv struct BitReader {
  bytes : BytesView
  mut byte_pos : Int
  mut bit_pos : Int
}

///|
fn BitReader::new(bytes : BytesView) -> BitReader {
  { bytes, byte_pos: 0, bit_pos: 0 }
}

///|
fn BitReader::read_bits(self : BitReader, count : Int) -> UInt raise ZipError {
  if count < 0 {
    raise ZipError::OutOfBounds(offset=self.byte_pos)
  }
  let mut result : UInt = 0
  for i in 0..<count {
    if self.byte_pos >= self.bytes.length() || self.byte_pos < 0 {
      raise ZipError::OutOfBounds(offset=self.byte_pos)
    }
    let byte = self.bytes[self.byte_pos].to_uint()
    let bit = (byte >> self.bit_pos) & 1
    result = result | (bit << i)
    self.bit_pos = self.bit_pos + 1
    if self.bit_pos == 8 {
      self.bit_pos = 0
      self.byte_pos = self.byte_pos + 1
    }
  }
  result
}

///|
fn BitReader::align_byte(self : BitReader) -> Unit {
  if self.bit_pos != 0 {
    self.bit_pos = 0
    self.byte_pos = self.byte_pos + 1
  }
}

///|
fn BitReader::read_bytes(
  self : BitReader,
  len : Int,
) -> BytesView raise ZipError {
  if self.bit_pos != 0 {
    raise ZipError::UnsupportedFeature(msg="bit reader not byte-aligned")
  }
  if len < 0 {
    raise ZipError::OutOfBounds(offset=self.byte_pos)
  }
  let end = self.byte_pos + len
  if end > self.bytes.length() {
    raise ZipError::OutOfBounds(offset=self.byte_pos)
  }
  let view = self.bytes[self.byte_pos:end]
  self.byte_pos = end
  view
}

///|
fn deflate_decode(bytes : BytesView) -> Bytes raise ZipError {
  let reader = BitReader::new(bytes)
  let out : Array[Byte] = []
  loop false {
    true => ()
    false => {
      let bfinal = reader.read_bits(1)
      let btype = reader.read_bits(2)
      match btype {
        0 => {
          reader.align_byte()
          let len = reader.read_bits(16)
          let nlen = reader.read_bits(16)
          if (len ^ nlen) != 0xFFFF {
            raise ZipError::UnsupportedFeature(
              msg="invalid stored block length",
            )
          }
          let data = reader.read_bytes(len.reinterpret_as_int())
          for b in data {
            out.push(b)
          }
        }
        _ =>
          raise ZipError::UnsupportedFeature(
            msg="deflate block type not supported",
          )
      }
      continue bfinal == 1
    }
  }
  Bytes::from_array(out)
}

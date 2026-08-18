///|
pub fn push_u16_le(output : Array[Byte], value : Int) -> Unit {
  let u = (value & 0xFFFF).reinterpret_as_uint()
  output.push((u & 0xFF).to_byte())
  output.push(((u >> 8) & 0xFF).to_byte())
}

///|
pub fn push_u16_be(output : Array[Byte], value : Int) -> Unit {
  let u = (value & 0xFFFF).reinterpret_as_uint()
  output.push(((u >> 8) & 0xFF).to_byte())
  output.push((u & 0xFF).to_byte())
}

///|
pub fn push_u32_le(output : Array[Byte], value : UInt) -> Unit {
  output.push((value & 0xFF).to_byte())
  output.push(((value >> 8) & 0xFF).to_byte())
  output.push(((value >> 16) & 0xFF).to_byte())
  output.push(((value >> 24) & 0xFF).to_byte())
}

///|
pub fn push_u32_be(output : Array[Byte], value : UInt) -> Unit {
  output.push(((value >> 24) & 0xFF).to_byte())
  output.push(((value >> 16) & 0xFF).to_byte())
  output.push(((value >> 8) & 0xFF).to_byte())
  output.push((value & 0xFF).to_byte())
}

///|
pub fn push_u64_le(output : Array[Byte], value : UInt64) -> Unit {
  for index in 0..<8 {
    output.push(((value >> (8 * index)) & 0xff).to_byte())
  }
}

///|
pub fn push_bytes(output : Array[Byte], bytes : BytesView) -> Unit {
  for byte in bytes {
    output.push(byte)
  }
}

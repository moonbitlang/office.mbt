///|
let mask_u32 : UInt = 0xffff_ffff

///|
fn rotl32(value : UInt, bits : Int) -> UInt {
  let masked = value & mask_u32
  ((masked << bits) | (masked >> (32 - bits))) & mask_u32
}

///|
fn rotr32(value : UInt, bits : Int) -> UInt {
  let masked = value & mask_u32
  ((masked >> bits) | (masked << (32 - bits))) & mask_u32
}

///|
fn rotr64(value : UInt64, bits : Int) -> UInt64 {
  (value >> bits) | (value << (64 - bits))
}

///|
pub fn u32_from_le(bytes : BytesView, offset : Int) -> UInt {
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  let b2 = bytes[offset + 2].to_uint()
  let b3 = bytes[offset + 3].to_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
pub fn u32_from_be(bytes : BytesView, offset : Int) -> UInt {
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  let b2 = bytes[offset + 2].to_uint()
  let b3 = bytes[offset + 3].to_uint()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
pub fn u64_from_le(bytes : BytesView, offset : Int) -> UInt64 {
  let mut value : UInt64 = 0
  for i in 0..<=7 {
    value = value | (bytes[offset + i].to_uint64() << (8 * i))
  }
  value
}

///|
pub fn u64_from_be(bytes : BytesView, offset : Int) -> UInt64 {
  let mut value : UInt64 = 0
  for i in 0..<=7 {
    value = (value << 8) | bytes[offset + i].to_uint64()
  }
  value
}

///|
pub fn push_u32_le(output : Array[Byte], value : UInt) -> Unit {
  output.push((value & 0xff).to_uint64().to_byte())
  output.push(((value >> 8) & 0xff).to_uint64().to_byte())
  output.push(((value >> 16) & 0xff).to_uint64().to_byte())
  output.push(((value >> 24) & 0xff).to_uint64().to_byte())
}

///|
pub fn push_u32_be(output : Array[Byte], value : UInt) -> Unit {
  output.push(((value >> 24) & 0xff).to_uint64().to_byte())
  output.push(((value >> 16) & 0xff).to_uint64().to_byte())
  output.push(((value >> 8) & 0xff).to_uint64().to_byte())
  output.push((value & 0xff).to_uint64().to_byte())
}

///|
fn push_u64_be(output : Array[Byte], value : UInt64) -> Unit {
  output.push(((value >> 56) & 0xff).to_byte())
  output.push(((value >> 48) & 0xff).to_byte())
  output.push(((value >> 40) & 0xff).to_byte())
  output.push(((value >> 32) & 0xff).to_byte())
  output.push(((value >> 24) & 0xff).to_byte())
  output.push(((value >> 16) & 0xff).to_byte())
  output.push(((value >> 8) & 0xff).to_byte())
  output.push((value & 0xff).to_byte())
}

///|
fn pad_message_32(input : BytesView, little_endian_len : Bool) -> Bytes {
  let out : Array[Byte] = input.to_array()
  let bit_len = input.length().to_uint64() * 8
  out.push(0x80)
  while out.length() % 64 != 56 {
    out.push(0)
  }
  if little_endian_len {
    let mut value = bit_len
    for _ in 0..<=7 {
      out.push((value & 0xff).to_byte())
      value = value >> 8
    }
  } else {
    let mut value = bit_len
    let len_bytes : Array[Byte] = []
    for _ in 0..<=7 {
      len_bytes.push((value & 0xff).to_byte())
      value = value >> 8
    }
    let len = len_bytes.length()
    for i in 0..<len {
      out.push(len_bytes[len - 1 - i])
    }
  }
  Bytes::from_array(out)
}

///|
fn pad_message_64(input : BytesView) -> Bytes {
  let out : Array[Byte] = input.to_array()
  let bit_len = input.length().to_uint64() * 8
  out.push(0x80)
  while out.length() % 128 != 112 {
    out.push(0)
  }
  for _ in 0..<=7 {
    out.push(0)
  }
  push_u64_be(out, bit_len)
  Bytes::from_array(out)
}

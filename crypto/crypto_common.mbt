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
fn pad_message_32(input : BytesView, little_endian_len : Bool) -> Bytes {
  let input_len = input.length()
  let final_len = (input_len + 1 + 8 + 63) / 64 * 64
  let out = @buffer.Buffer(size_hint=final_len)
  out.write_bytes(input)
  let bit_len = input_len.to_uint64() * 8
  out.write_byte(0x80)
  while out.length() % 64 != 56 {
    out.write_byte(0)
  }
  if little_endian_len {
    out.write_uint64_le(bit_len)
  } else {
    out.write_uint64_be(bit_len)
  }
  out.to_bytes()
}

///|
fn pad_message_64(input : BytesView) -> Bytes {
  let input_len = input.length()
  let final_len = (input_len + 1 + 16 + 127) / 128 * 128
  let out = @buffer.Buffer(size_hint=final_len)
  out.write_bytes(input)
  let bit_len = input_len.to_uint64() * 8
  out.write_byte(0x80)
  while out.length() % 128 != 112 {
    out.write_byte(0)
  }
  out.write_uint64_be((0 : UInt64))
  out.write_uint64_be(bit_len)
  out.to_bytes()
}

// Deprecated byte-serialization helpers, kept as forwarding shims for
// mooncake compatibility. Use core `Buffer` for appends and byte patterns /
// `unsafe_read_*` for reads instead. Remove once a deprecation cycle has
// passed.

///|
#deprecated("use Bytes::unsafe_read_uint32_le instead")
pub fn u32_from_le(bytes : BytesView, offset : Int) -> UInt {
  bytes.unsafe_read_uint32_le(offset)
}

///|
#deprecated("use Bytes::unsafe_read_uint64_le instead")
pub fn u64_from_le(bytes : BytesView, offset : Int) -> UInt64 {
  bytes.unsafe_read_uint64_le(offset)
}

///|
#deprecated("use Buffer::write_uint_le instead")
pub fn push_u32_le(output : Array[Byte], value : UInt) -> Unit {
  let buf = @buffer.Buffer(size_hint=4)
  buf.write_uint_le(value)
  let bytes = buf.to_bytes()
  for i in 0..<4 {
    output.push(bytes[i])
  }
}

///|
test "deprecated le helpers still work" {
  let bytes : Bytes = b"\x01\x02\x03\x04"
  inspect(u32_from_le(bytes, 0), content="67305985")

  let bytes64 : Bytes = b"\x01\x02\x03\x04\x05\x06\x07\x08"
  inspect(u64_from_le(bytes64, 0), content="578437695752307201")

  let out : Array[Byte] = []
  push_u32_le(out, 0x04030201U)
  inspect(Bytes::from_array(out), content="b\"\\x01\\x02\\x03\\x04\"")
}

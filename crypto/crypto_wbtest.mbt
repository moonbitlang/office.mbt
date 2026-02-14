///|
test "crypto internal big-endian helpers" {
  let bytes32 : Bytes = b"\x01\x02\x03\x04"
  inspect(u32_from_be(bytes32, 0), content="16909060")

  let bytes64 : Bytes = b"\x01\x02\x03\x04\x05\x06\x07\x08"
  inspect(u64_from_be(bytes64, 0), content="72623859790382856")

  let out : Array[Byte] = []
  push_u32_be(out, 0x01020304U)
  inspect(Bytes::from_array(out), content="b\"\\x01\\x02\\x03\\x04\"")
}

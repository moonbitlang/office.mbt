///|
test "gzip wb: helper read bounds guards" {
  let bad_u16 : Result[UInt, Error] = try? read_u16_le(b"\x00", 0)
  inspect(bad_u16 is Err(ZipError::OutOfBounds(_)), content="true")

  let bad_u32 : Result[UInt, Error] = try? read_u32_le(b"\x00\x01", 0)
  inspect(bad_u32 is Err(ZipError::OutOfBounds(_)), content="true")
}

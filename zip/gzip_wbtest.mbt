///|
test "gzip wb: helper read bounds guards" {
  try read_u16_le(b"\x00", 0) catch {
    e => inspect(e is ZipError::OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_u16_le to raise")
  }
  try read_u32_le(b"\x00\x01", 0) catch {
    e => inspect(e is ZipError::OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_u32_le to raise")
  }
}

///|
fn crc32(bytes : BytesView) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for b in bytes {
    crc = crc ^ b.to_uint()
    for _ in 0..<=7 {
      if (crc & 1) != 0 {
        crc = (crc >> 1) ^ 0xEDB88320
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xFFFFFFFF
}

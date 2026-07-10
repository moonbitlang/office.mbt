///|
/// Precomputed 256-entry table for the reflected IEEE CRC-32 polynomial
/// (0xEDB88320): entry `n` is the CRC of the single byte `n`.
let crc32_table : FixedArray[UInt] = crc32_make_table()

///|
fn crc32_make_table() -> FixedArray[UInt] {
  let table : FixedArray[UInt] = FixedArray::make(256, 0)
  for n in 0..<256 {
    let mut c = n.reinterpret_as_uint()
    for _ in 0..<=7 {
      if (c & 1) != 0 {
        c = (c >> 1) ^ 0xEDB88320
      } else {
        c = c >> 1
      }
    }
    table[n] = c
  }
  table
}

///|
/// Computes the CRC-32 (IEEE, as used by ZIP) of a byte view.
pub fn crc32(bytes : BytesView) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for b in bytes {
    crc = crc32_table[((crc ^ b.to_uint()) & 0xFF).reinterpret_as_int()] ^
      (crc >> 8)
  }
  crc ^ 0xFFFFFFFF
}

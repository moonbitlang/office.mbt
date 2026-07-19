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

///|
/// Computes ZIP CRC-32 while polling `cancelled` at bounded byte intervals.
/// This is intended for archive verification on untrusted, size-bounded input;
/// callers that do not need cooperative cancellation can use `crc32`.
pub fn crc32_cancellable(
  bytes : BytesView,
  cancelled? : () -> Bool = () => false,
) -> UInt raise ZipError {
  check_zip_cancelled(cancelled)
  let mut crc : UInt = 0xFFFFFFFF
  let mut index = 0
  while index < bytes.length() {
    if (index & 4095) == 0 {
      check_zip_cancelled(cancelled)
    }
    let byte = bytes[index]
    crc = crc32_table[((crc ^ byte.to_uint()) & 0xFF).reinterpret_as_int()] ^
      (crc >> 8)
    index += 1
  }
  check_zip_cancelled(cancelled)
  crc ^ 0xFFFFFFFF
}

///|
test "cancellable CRC matches CRC-32 and polls inside long input" {
  let bytes = Bytes::make(16 * 1024, b'x')
  assert_eq(crc32_cancellable(bytes), crc32(bytes))
  let checks = [0]
  try
    crc32_cancellable(bytes, cancelled=() => {
      checks[0] += 1
      checks[0] >= 4
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 4)
    _ => fail("expected CRC cancellation")
  } noraise {
    _ => fail("expected CRC cancellation")
  }
}

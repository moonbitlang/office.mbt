///|
test "synthetic font is reconstructed with valid SFNT directory and checksum" {
  let bytes = decompress(compressed_probe())
  inspect(checksum(bytes), content="2981146554")
  let header = Stream::new(data=bytes)
  inspect(header.uint(4), content="65536")
  let count = header.uint(2)
  assert_true(count > 0)
  header.seek(12)
  let mut previous = 0
  for _ in 0..<count {
    let tag = header.uint(4)
    let expected = header.uint(4).reinterpret_as_uint()
    let offset = header.uint(4)
    let length = header.uint(4)
    assert_true(tag > previous)
    assert_true(
      offset >= 12 + count * 16 &&
      length >= 0 &&
      offset + length <= bytes.length(),
    )
    let program = bytes[offset:offset + length].to_owned().to_array()
    if tag == 0x68656164 {
      for i in 8..<12 {
        program[i] = 0
      }
    }
    assert_eq(checksum(Bytes::from_array(program)), expected)
    previous = tag
  }
}

///|
test "truncated blocks and corrupt offsets are errors" {
  let source = compressed_probe()
  for count in [0, 1, 9, 10, source.length() - 1] {
    try decompress(source[:count].to_owned()) catch {
      _ => ()
    } noraise {
      _ => fail("truncated MTX was accepted")
    }
  }
  let corrupt = source.to_array()
  corrupt[4] = 255
  try decompress(Bytes::from_array(corrupt)) catch {
    _ => ()
  } noraise {
    _ => fail("out-of-range MTX offset was accepted")
  }
}

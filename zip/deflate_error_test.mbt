///|
fn gzip_bytes_with_deflate_payload(payload : Array[Byte]) -> Bytes {
  let out : Array[Byte] = []
  // ID1 ID2 CM FLG MTIME(4) XFL OS
  out.push((0x1F).to_byte())
  out.push((0x8B).to_byte())
  out.push((0x08).to_byte())
  out.push((0x00).to_byte())
  out.push((0x00).to_byte())
  out.push((0x00).to_byte())
  out.push((0x00).to_byte())
  out.push((0x00).to_byte())
  out.push((0x00).to_byte())
  out.push((0xFF).to_byte())
  out.append(payload)
  // Trailer (CRC32 + ISIZE). Not validated if deflate decode fails.
  for _ in 0..<=7 {
    out.push((0x00).to_byte())
  }
  Bytes::from_array(out)
}

///|
test "gunzip invalid deflate: empty payload hits OutOfBounds" {
  let gz = gzip_bytes_with_deflate_payload([])
  let result : Result[Bytes, Error] = try? gunzip(gz)
  inspect(result is Err(ZipError::OutOfBounds(_)), content="true")
}

///|
test "gunzip invalid deflate: invalid block type" {
  // BFINAL=1, BTYPE=3 (invalid): bits 1,1,1 => 0x07
  let gz = gzip_bytes_with_deflate_payload([(0x07).to_byte()])
  let result : Result[Bytes, Error] = try? gunzip(gz)
  inspect(result is Err(ZipError::UnsupportedFeature(_)), content="true")
}

///|
test "gunzip invalid deflate: invalid stored block length" {
  // BFINAL=1, BTYPE=0 (stored): 0x01, then LEN=1, NLEN=0 (invalid)
  let payload = [
    (0x01).to_byte(),
    (0x01).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x41).to_byte(),
  ]
  let gz = gzip_bytes_with_deflate_payload(payload)
  let result : Result[Bytes, Error] = try? gunzip(gz)
  inspect(result is Err(ZipError::UnsupportedFeature(_)), content="true")
}

///|
test "gunzip invalid deflate: empty dynamic huffman table" {
  // Dynamic Huffman block with all code-length code lengths set to 0
  // -> hits `empty huffman table`.
  let payload = [
    (0x05).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
    (0x00).to_byte(),
  ]
  let gz = gzip_bytes_with_deflate_payload(payload)
  let result : Result[Bytes, Error] = try? gunzip(gz)
  match result {
    Err(ZipError::UnsupportedFeature(msg~)) =>
      inspect(msg, content="empty huffman table")
    _ => fail("expected UnsupportedFeature(empty huffman table)")
  }
}

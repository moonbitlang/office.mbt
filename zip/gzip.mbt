///|
fn read_u16_le(bytes : BytesView, offset : Int) -> UInt raise ZipError {
  if offset < 0 || offset + 2 > bytes.length() {
    raise OutOfBounds(offset~)
  }
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  b0 | (b1 << 8)
}

///|
fn read_u32_le(bytes : BytesView, offset : Int) -> UInt raise ZipError {
  if offset < 0 || offset + 4 > bytes.length() {
    raise OutOfBounds(offset~)
  }
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  let b2 = bytes[offset + 2].to_uint()
  let b3 = bytes[offset + 3].to_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn gzip_push_u32_le(out : Array[Byte], value : UInt) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn skip_cstring(bytes : BytesView, start : Int) -> Int? {
  for i in start..<bytes.length() {
    if bytes[i] == 0 {
      return Some(i + 1)
    }
  }
  None
}

///|
pub fn gunzip(bytes : BytesView) -> Bytes raise ZipError {
  // RFC 1952
  if bytes.length() < 18 {
    raise UnsupportedFeature(msg="invalid gzip data")
  }
  if bytes[0] != 0x1F || bytes[1] != 0x8B {
    raise UnsupportedFeature(msg="invalid gzip header")
  }
  let compression_method = bytes[2].to_int()
  if compression_method != 8 {
    raise UnsupportedFeature(msg="unsupported gzip method")
  }
  let flags = bytes[3].to_int()
  let mut idx = 10
  if (flags & 0x04) != 0 {
    let xlen = read_u16_le(bytes, idx).reinterpret_as_int()
    idx = idx + 2 + xlen
  }
  if (flags & 0x08) != 0 {
    idx = match skip_cstring(bytes, idx) {
      Some(v) => v
      None => raise UnsupportedFeature(msg="invalid gzip name")
    }
  }
  if (flags & 0x10) != 0 {
    idx = match skip_cstring(bytes, idx) {
      Some(v) => v
      None => raise UnsupportedFeature(msg="invalid gzip comment")
    }
  }
  if (flags & 0x02) != 0 {
    idx = idx + 2
  }
  if idx < 0 || idx > bytes.length() - 8 {
    raise UnsupportedFeature(msg="invalid gzip data")
  }
  let trailer_crc = read_u32_le(bytes, bytes.length() - 8)
  let trailer_isize = read_u32_le(bytes, bytes.length() - 4)
  let compressed = bytes[idx:bytes.length() - 8]
  let decoded = deflate_decode(compressed)
  let expected_isize = (decoded.length() & 0xFFFFFFFF).reinterpret_as_uint()
  if trailer_isize != expected_isize {
    raise UnsupportedFeature(msg="gzip size mismatch")
  }
  let actual_crc = crc32(decoded[:])
  if trailer_crc != actual_crc {
    raise UnsupportedFeature(msg="gzip crc mismatch")
  }
  decoded
}

///|
pub fn gzip(bytes : BytesView) -> Bytes raise ZipError {
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
  let compressed = deflate_encode(bytes)
  for b in compressed {
    out.push(b)
  }
  let crc = crc32(bytes)
  gzip_push_u32_le(out, crc)
  gzip_push_u32_le(out, (bytes.length() & 0xFFFFFFFF).reinterpret_as_uint())
  Bytes::from_array(out)
}

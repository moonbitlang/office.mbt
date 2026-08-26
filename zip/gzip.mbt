///|
fn skip_cstring(bytes : BytesView, start : Int) -> Int? {
  guard bytes.get_view(start~) is Some(view) else { return None }
  guard view.find(b"\x00") is Some(offset) else { return None }
  Some(start + offset + 1)
}

///|
pub fn gunzip(bytes : BytesView) -> Bytes raise ZipError {
  // RFC 1952
  if bytes.length() < 18 {
    raise UnsupportedFeature(msg="invalid gzip data")
  }
  if !bytes.has_prefix(b"\x1F\x8B") {
    raise UnsupportedFeature(msg="invalid gzip header")
  }
  let compression_method = bytes[2].to_int()
  if compression_method != 8 {
    raise UnsupportedFeature(msg="unsupported gzip method")
  }
  let flags = bytes[3].to_int()
  let mut idx = 10
  if (flags & 0x04) != 0 {
    let xlen = read_u16_le_at(bytes, idx)
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
  let trailer_crc = read_u32_le_at_raw(bytes, bytes.length() - 8)
  let trailer_isize = read_u32_le_at_raw(bytes, bytes.length() - 4)
  let compressed = bytes[idx:bytes.length() - 8]
  // Allow a legitimately large declared size, but keep a hard ceiling so a
  // lying tiny stream cannot expand without bound (decompression bomb).
  let declared_isize = trailer_isize.min(0x7FFFFFFF).reinterpret_as_int()
  let max_output = declared_isize.max(deflate_max_output_default)
  let decoded = deflate_decode(compressed, max_output~)
  let expected_isize = (decoded.length() & 0xFFFFFFFF).reinterpret_as_uint()
  if trailer_isize != expected_isize {
    raise UnsupportedFeature(msg="gzip size mismatch")
  }
  let actual_crc = crc32(decoded)
  if trailer_crc != actual_crc {
    raise UnsupportedFeature(msg="gzip crc mismatch")
  }
  decoded
}

///|
pub fn gzip(bytes : BytesView) -> Bytes raise ZipError {
  let compressed_size = deflate_encoded_size(bytes)
  if compressed_size > 0x7fffffff - 18 {
    raise UnsupportedFeature(msg="gzip output size exceeds the Int range")
  }
  let out = FixedByteOutput::allocated(10 + compressed_size + 8)
  // ID1 ID2 CM FLG MTIME(4) XFL OS
  out.write_bytes(b"\x1F\x8B\x08\x00\x00\x00\x00\x00\x00\xFF")
  let actual_size = deflate_encode_to_output(bytes, out)
  if actual_size != compressed_size {
    raise UnsupportedFeature(msg="DEFLATE sizing and gzip emission disagreed")
  }
  let crc = crc32(bytes)
  write_u32_le_bounded(out, crc, None)
  write_u32_le_bounded(
    out,
    (bytes.length() & 0xFFFFFFFF).reinterpret_as_uint(),
    None,
  )
  out.finish()
}

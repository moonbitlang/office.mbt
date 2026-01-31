///|
fn u16_to_le_bytes(value : Int) -> Array[Byte] {
  let u = (value & 0xFFFF).reinterpret_as_uint()
  [(u & 0xFF).to_byte(), ((u >> 8) & 0xFF).to_byte()]
}

///|
fn gzip_overwrite_u32_le(
  bytes : Array[Byte],
  offset : Int,
  value : UInt,
) -> Unit {
  bytes[offset] = (value & 0xFF).to_byte()
  bytes[offset + 1] = ((value >> 8) & 0xFF).to_byte()
  bytes[offset + 2] = ((value >> 16) & 0xFF).to_byte()
  bytes[offset + 3] = ((value >> 24) & 0xFF).to_byte()
}

///|
test "gzip/gunzip roundtrip with optional header fields" {
  let raw = b"hello gzip"
  let gz = gzip(raw).to_array()
  let header = gz[:10]
  let compressed = gz[10:gz.length() - 8]
  let trailer = gz[gz.length() - 8:]
  let out : Array[Byte] = []
  for i in 0..<10 {
    if i == 3 {
      out.push((0x1E).to_byte()) // FEXTRA|FNAME|FCOMMENT|FHCRC
    } else {
      out.push(header[i])
    }
  }
  // FEXTRA
  out.append(u16_to_le_bytes(3)[:])
  out.append([(1).to_byte(), (2).to_byte(), (3).to_byte()])
  // FNAME
  for b in @encoding/utf8.encode("name") {
    out.push(b)
  }
  out.push((0).to_byte())
  // FCOMMENT
  for b in @encoding/utf8.encode("comment") {
    out.push(b)
  }
  out.push((0).to_byte())
  // FHCRC (ignored)
  out.push((0).to_byte())
  out.push((0).to_byte())
  out.append(compressed[:])
  out.append(trailer[:])
  let roundtrip = gunzip(Bytes::from_array(out))
  inspect(roundtrip, content="b\"hello gzip\"")
}

///|
test "gunzip invalid and mismatch cases" {
  let raw = b"hello gzip"
  let gz = gzip(raw).to_array()
  let too_short : Result[Bytes, Error] = try? gunzip(b"short")
  inspect(too_short is Err(_), content="true")
  let bad_header = gz.copy()
  bad_header[0] = (0).to_byte()
  let invalid_header : Result[Bytes, Error] = try? gunzip(
    Bytes::from_array(bad_header),
  )
  inspect(invalid_header is Err(_), content="true")
  let bad_method = gz.copy()
  bad_method[2] = (0).to_byte()
  let unsupported_method : Result[Bytes, Error] = try? gunzip(
    Bytes::from_array(bad_method),
  )
  inspect(unsupported_method is Err(_), content="true")
  let bad_size = gz.copy()
  gzip_overwrite_u32_le(bad_size, bad_size.length() - 4, (0 : UInt))
  let size_mismatch : Result[Bytes, Error] = try? gunzip(
    Bytes::from_array(bad_size),
  )
  inspect(size_mismatch is Err(_), content="true")
  let bad_crc = gz.copy()
  gzip_overwrite_u32_le(bad_crc, bad_crc.length() - 8, (0 : UInt))
  let crc_mismatch : Result[Bytes, Error] = try? gunzip(
    Bytes::from_array(bad_crc),
  )
  inspect(crc_mismatch is Err(_), content="true")
}

///|
test "gunzip invalid name/comment and invalid data offset" {
  let invalid_name : Array[Byte] = Array::make(18, (1).to_byte())
  invalid_name[0] = (0x1F).to_byte()
  invalid_name[1] = (0x8B).to_byte()
  invalid_name[2] = (0x08).to_byte()
  invalid_name[3] = (0x08).to_byte()
  invalid_name[9] = (0xFF).to_byte()
  let name_err : Result[Bytes, Error] = try? gunzip(
    Bytes::from_array(invalid_name),
  )
  inspect(name_err is Err(_), content="true")
  let invalid_comment : Array[Byte] = Array::make(18, (1).to_byte())
  invalid_comment[0] = (0x1F).to_byte()
  invalid_comment[1] = (0x8B).to_byte()
  invalid_comment[2] = (0x08).to_byte()
  invalid_comment[3] = (0x10).to_byte()
  invalid_comment[9] = (0xFF).to_byte()
  let comment_err : Result[Bytes, Error] = try? gunzip(
    Bytes::from_array(invalid_comment),
  )
  inspect(comment_err is Err(_), content="true")
  let invalid_data : Array[Byte] = Array::make(18, (0).to_byte())
  invalid_data[0] = (0x1F).to_byte()
  invalid_data[1] = (0x8B).to_byte()
  invalid_data[2] = (0x08).to_byte()
  invalid_data[3] = (0x04).to_byte()
  invalid_data[9] = (0xFF).to_byte()
  // XLEN = 200 (push idx beyond end)
  invalid_data[10] = (200).to_byte()
  invalid_data[11] = (0).to_byte()
  let data_err : Result[Bytes, Error] = try? gunzip(
    Bytes::from_array(invalid_data),
  )
  inspect(data_err is Err(_), content="true")
}

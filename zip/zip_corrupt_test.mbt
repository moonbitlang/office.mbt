///|
fn read_u16_le(bytes : Array[Byte], offset : Int) -> Int {
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  (b0 | (b1 << 8)).reinterpret_as_int()
}

///|
fn read_u32_le(bytes : Array[Byte], offset : Int) -> UInt {
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  let b2 = bytes[offset + 2].to_uint()
  let b3 = bytes[offset + 3].to_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn overwrite_u16_le(bytes : Array[Byte], offset : Int, value : Int) -> Unit {
  let u = (value & 0xFFFF).reinterpret_as_uint()
  bytes[offset] = (u & 0xFF).to_byte()
  bytes[offset + 1] = ((u >> 8) & 0xFF).to_byte()
}

///|
fn zip_overwrite_u32_le(
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
fn find_eocd_offset(bytes : Array[Byte]) -> Int? {
  let sig = [
    (0x50).to_byte(),
    (0x4B).to_byte(),
    (0x05).to_byte(),
    (0x06).to_byte(),
  ]
  let mut pos = bytes.length() - 22
  while pos >= 0 {
    if bytes[pos] == sig[0] &&
      bytes[pos + 1] == sig[1] &&
      bytes[pos + 2] == sig[2] &&
      bytes[pos + 3] == sig[3] {
      return Some(pos)
    }
    pos = pos - 1
  }
  None
}

///|
fn push_u16_le(out : Array[Byte], value : Int) -> Unit {
  let u = (value & 0xFFFF).reinterpret_as_uint()
  out.push((u & 0xFF).to_byte())
  out.push(((u >> 8) & 0xFF).to_byte())
}

///|
fn push_u32_le(out : Array[Byte], value : UInt) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn push_u64_le(out : Array[Byte], value : UInt64) -> Unit {
  for i in 0..<8 {
    out.push(((value >> (8 * i)) & 0xff).to_byte())
  }
}

///|
test "zip read: corrupted structures hit error variants" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let central_size = read_u32_le(raw_bytes, eocd + 12).reinterpret_as_int()
  let central_offset = read_u32_le(raw_bytes, eocd + 16).reinterpret_as_int()
  let local_offset = read_u32_le(raw_bytes, central_offset + 42).reinterpret_as_int()
  let name_len = read_u16_le(raw_bytes, central_offset + 28)
  let bad_eocd_sig = raw_bytes.copy()
  bad_eocd_sig[eocd] = (0).to_byte()
  try read(Bytes::from_array(bad_eocd_sig)) catch {
    e => inspect(e is ZipError::MissingEndOfCentral, content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let out_of_bounds = raw_bytes.copy()
  zip_overwrite_u32_le(
    out_of_bounds,
    eocd + 16,
    (out_of_bounds.length() + central_size).reinterpret_as_uint(),
  )
  try read(Bytes::from_array(out_of_bounds)) catch {
    e => inspect(e is ZipError::OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let bad_cd_sig = raw_bytes.copy()
  bad_cd_sig[central_offset] = (0).to_byte()
  try read(Bytes::from_array(bad_cd_sig)) catch {
    e => inspect(e is ZipError::InvalidSignature(..), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let bad_name = raw_bytes.copy()
  if name_len > 0 {
    bad_name[central_offset + 46] = (0xFF).to_byte()
  }
  try read(Bytes::from_array(bad_name)) catch {
    e => inspect(e is ZipError::InvalidUtf8(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let bad_method = raw_bytes.copy()
  overwrite_u16_le(bad_method, central_offset + 10, 99)
  try read(Bytes::from_array(bad_method)) catch {
    e => inspect(e is ZipError::UnsupportedCompression(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let bad_local_sig = raw_bytes.copy()
  bad_local_sig[local_offset] = (0).to_byte()
  try read(Bytes::from_array(bad_local_sig)) catch {
    e => inspect(e is ZipError::InvalidSignature(..), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let multi_disk = raw_bytes.copy()
  overwrite_u16_le(multi_disk, eocd + 4, 1)
  try read(Bytes::from_array(multi_disk)) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let zip64_locator_missing = raw_bytes.copy()
  overwrite_u16_le(zip64_locator_missing, eocd + 8, 0xFFFF)
  overwrite_u16_le(zip64_locator_missing, eocd + 10, 0xFFFF)
  zip_overwrite_u32_le(zip64_locator_missing, eocd + 12, (0xFFFFFFFF : UInt))
  zip_overwrite_u32_le(zip64_locator_missing, eocd + 16, (0xFFFFFFFF : UInt))
  try read(Bytes::from_array(zip64_locator_missing)) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let mismatched_comp_size = raw_bytes.copy()
  zip_overwrite_u32_le(mismatched_comp_size, local_offset + 18, (1 : UInt))
  try read(Bytes::from_array(mismatched_comp_size)) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let zip64_size_missing = raw_bytes.copy()
  zip_overwrite_u32_le(
    zip64_size_missing,
    central_offset + 20,
    (0xFFFFFFFF : UInt),
  )
  try read(Bytes::from_array(zip64_size_missing)) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let zip64_offset_missing = raw_bytes.copy()
  zip_overwrite_u32_le(
    zip64_offset_missing,
    central_offset + 42,
    (0xFFFFFFFF : UInt),
  )
  try read(Bytes::from_array(zip64_offset_missing)) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let encrypted_flag = raw_bytes.copy()
  overwrite_u16_le(encrypted_flag, central_offset + 8, 0x0801)
  try read(Bytes::from_array(encrypted_flag)) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read: EOCD comment length hits Reader::skip OutOfBounds" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let bad_comment = raw_bytes.copy()
  overwrite_u16_le(bad_comment, eocd + 20, 1)
  try read(Bytes::from_array(bad_comment)) catch {
    e => inspect(e is ZipError::OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read: central name_len hits Reader::read_bytes OutOfBounds" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let central_offset = read_u32_le(raw_bytes, eocd + 16).reinterpret_as_int()
  let bad_name_len = raw_bytes.copy()
  overwrite_u16_le(bad_name_len, central_offset + 28, 0xFFFF)
  try read(Bytes::from_array(bad_name_len)) catch {
    e => inspect(e is ZipError::OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read: central offset near EOF hits Reader::read_u8 OutOfBounds" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let bad_central = raw_bytes.copy()
  zip_overwrite_u32_le(bad_central, eocd + 12, (2 : UInt))
  zip_overwrite_u32_le(
    bad_central,
    eocd + 16,
    (bad_central.length() - 2).reinterpret_as_uint(),
  )
  try read(Bytes::from_array(bad_central)) catch {
    e => inspect(e is ZipError::OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read: unsupported flags hits ensure_flags_supported branch" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let central_offset = read_u32_le(raw_bytes, eocd + 16).reinterpret_as_int()
  let bad_flags = raw_bytes.copy()
  // UTF-8 (0x0800) + unsupported bit 0x0020.
  overwrite_u16_le(bad_flags, central_offset + 8, 0x0820)
  try read(Bytes::from_array(bad_flags)) catch {
    ZipError::UnsupportedFeature(msg~) =>
      inspect(msg, content="unsupported zip flags: 0x20")
    _ => fail("expected UnsupportedFeature for unsupported flags")
  } noraise {
    _ => fail("expected UnsupportedFeature for unsupported flags")
  }
}

///|
test "zip read: u32_to_int overflow hits UnsupportedFeature" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let bad = raw_bytes.copy()
  zip_overwrite_u32_le(bad, eocd + 16, (0x80000000 : UInt))
  try read(Bytes::from_array(bad)) catch {
    ZipError::UnsupportedFeature(msg~) =>
      inspect(msg, content="u32 exceeds Int range")
    _ => fail("expected UnsupportedFeature for u32 exceeds Int range")
  } noraise {
    _ => fail("expected UnsupportedFeature for u32 exceeds Int range")
  }
}

///|
fn make_zip_zip64_locator_offset_negative() -> Bytes {
  let out : Array[Byte] = []
  // EOCD at offset 0 (len=22). Mark as zip64-needed, but no space for locator.
  push_u32_le(out, (0x06054b50 : UInt))
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, 0xFFFF)
  push_u16_le(out, 0xFFFF)
  push_u32_le(out, (0xFFFFFFFF : UInt))
  push_u32_le(out, (0xFFFFFFFF : UInt))
  push_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
test "zip read: zip64 locator offset negative hits locator-missing branch" {
  let bytes = make_zip_zip64_locator_offset_negative()
  try read(bytes) catch {
    ZipError::UnsupportedFeature(msg~) =>
      inspect(msg, content="zip64 locator missing")
    _ => fail("expected zip64 locator missing")
  } noraise {
    _ => fail("expected zip64 locator missing")
  }
}

///|
fn make_zip_zip64_extra_declared_too_large() -> Bytes {
  let out : Array[Byte] = []
  // Central directory @ offset 0, one entry with a malformed zip64 extra field.
  // Central header signature: 0x02014b50
  push_u32_le(out, (0x02014b50 : UInt))
  push_u16_le(out, 20) // version made
  push_u16_le(out, 20) // version needed
  push_u16_le(out, 0x0800) // UTF-8
  push_u16_le(out, 0) // method
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u32_le(out, (0 : UInt)) // crc32
  push_u32_le(out, (0 : UInt)) // comp size
  push_u32_le(out, (0xFFFFFFFF : UInt)) // uncomp size -> needs zip64
  push_u16_le(out, 0) // name_len
  push_u16_le(out, 4) // extra_len
  push_u16_le(out, 0) // comment_len
  push_u16_le(out, 0) // disk
  push_u16_le(out, 0) // internal attrs
  push_u32_le(out, (0 : UInt)) // external attrs
  push_u32_le(out, (0 : UInt)) // local offset
  // extra field: header_id=0x0001, data_size=10 (but only 0 bytes remain)
  push_u16_le(out, 0x0001)
  push_u16_le(out, 10)
  let central_size = out.length()
  // EOCD @ end.
  push_u32_le(out, (0x06054b50 : UInt))
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, 1)
  push_u16_le(out, 1)
  push_u32_le(out, central_size.reinterpret_as_uint())
  push_u32_le(out, (0 : UInt))
  push_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
test "zip read: parse_zip64_extra hits OutOfBounds branch" {
  let bytes = make_zip_zip64_extra_declared_too_large()
  try read(bytes) catch {
    e => inspect(e is ZipError::OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
fn make_zip_zip64_invalid_eocd_signature() -> Bytes {
  let out : Array[Byte] = []
  // Fake zip64 EOCD at offset 0 with invalid signature.
  push_u32_le(out, (0 : UInt))
  // Zip64 locator at offset 4 (20 bytes).
  push_u32_le(out, (0x07064b50 : UInt))
  push_u32_le(out, (0 : UInt))
  // zip64_eocd_offset = 0
  for _ in 0..<=7 {
    out.push((0).to_byte())
  }
  push_u32_le(out, (1 : UInt))
  // Regular EOCD at offset 24.
  push_u32_le(out, (0x06054b50 : UInt))
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, 0xFFFF)
  push_u16_le(out, 0xFFFF)
  push_u32_le(out, (0xFFFFFFFF : UInt))
  push_u32_le(out, (0xFFFFFFFF : UInt))
  push_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
test "zip read: zip64 EOCD invalid signature hits InvalidSignature branch" {
  let bytes = make_zip_zip64_invalid_eocd_signature()
  try read(bytes) catch {
    e => inspect(e is ZipError::InvalidSignature(..), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
fn make_zip_zip64_multidisk_eocd() -> Bytes {
  let out : Array[Byte] = []
  // Zip64 EOCD at offset 0.
  push_u32_le(out, (0x06064b50 : UInt))
  push_u64_le(out, (44 : UInt64))
  push_u16_le(out, 45)
  push_u16_le(out, 45)
  // disk_no != 0 triggers the multi-disk check in read_zip64_eocd.
  push_u32_le(out, (1 : UInt))
  push_u32_le(out, (0 : UInt))
  push_u64_le(out, (1 : UInt64))
  push_u64_le(out, (1 : UInt64))
  push_u64_le(out, (0 : UInt64))
  push_u64_le(out, (0 : UInt64))
  // Zip64 locator at offset 56.
  push_u32_le(out, (0x07064b50 : UInt))
  push_u32_le(out, (0 : UInt))
  push_u64_le(out, (0 : UInt64))
  push_u32_le(out, (1 : UInt))
  // Regular EOCD at offset 76 (marks zip64-needed).
  push_u32_le(out, (0x06054b50 : UInt))
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, 0xFFFF)
  push_u16_le(out, 0xFFFF)
  push_u32_le(out, (0xFFFFFFFF : UInt))
  push_u32_le(out, (0xFFFFFFFF : UInt))
  push_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
test "zip read: zip64 EOCD multi-disk fields hit UnsupportedFeature" {
  let bytes = make_zip_zip64_multidisk_eocd()
  try read(bytes) catch {
    ZipError::UnsupportedFeature(msg~) =>
      inspect(msg, content="multi-disk zip not supported")
    _ => fail("expected multi-disk zip not supported")
  } noraise {
    _ => fail("expected multi-disk zip not supported")
  }
}

///|
test "zip read: zip64 uncompressed size missing hits zip64 size missing" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let central_offset = read_u32_le(raw_bytes, eocd + 16).reinterpret_as_int()
  let bad = raw_bytes.copy()
  // Uncompressed size -> needs zip64, but no zip64 extra field present.
  zip_overwrite_u32_le(bad, central_offset + 24, (0xFFFFFFFF : UInt))
  try read(Bytes::from_array(bad)) catch {
    ZipError::UnsupportedFeature(msg~) =>
      inspect(msg, content="zip64 size missing")
    _ => fail("expected zip64 size missing")
  } noraise {
    _ => fail("expected zip64 size missing")
  }
}

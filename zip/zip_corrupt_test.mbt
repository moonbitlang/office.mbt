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
  let sig : ReadOnlyArray[Byte] = [
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
fn push_zip_test_bytes(out : Array[Byte], bytes : BytesView) -> Unit {
  for byte in bytes {
    out.push(byte)
  }
}

///|
fn append_zip_test_local(
  out : Array[Byte],
  name : Bytes,
  data : Bytes,
  extra? : Bytes = b"",
) -> Int {
  let offset = out.length()
  let crc = @zip.crc32(data)
  push_u32_le(out, (0x04034B50 : UInt))
  push_u16_le(out, 20)
  push_u16_le(out, 0x0800)
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u32_le(out, crc)
  push_u32_le(out, data.length().reinterpret_as_uint())
  push_u32_le(out, data.length().reinterpret_as_uint())
  push_u16_le(out, name.length())
  push_u16_le(out, extra.length())
  push_zip_test_bytes(out, name)
  push_zip_test_bytes(out, extra)
  push_zip_test_bytes(out, data)
  offset
}

///|
fn append_zip_test_central(
  out : Array[Byte],
  name : Bytes,
  data : Bytes,
  local_offset : Int,
  extra? : Bytes = b"",
) -> Unit {
  let crc = @zip.crc32(data)
  push_u32_le(out, (0x02014B50 : UInt))
  push_u16_le(out, 20)
  push_u16_le(out, 20)
  push_u16_le(out, 0x0800)
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u32_le(out, crc)
  push_u32_le(out, data.length().reinterpret_as_uint())
  push_u32_le(out, data.length().reinterpret_as_uint())
  push_u16_le(out, name.length())
  push_u16_le(out, extra.length())
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u32_le(out, (0 : UInt))
  push_u32_le(out, local_offset.reinterpret_as_uint())
  push_zip_test_bytes(out, name)
  push_zip_test_bytes(out, extra)
}

///|
fn zip_test_unicode_path_extra(
  original_name : Bytes,
  unicode_name : Bytes,
) -> Bytes {
  let out : Array[Byte] = []
  push_u16_le(out, 0x7075)
  push_u16_le(out, 5 + unicode_name.length())
  out.push((1).to_byte())
  push_u32_le(out, @zip.crc32(original_name))
  push_zip_test_bytes(out, unicode_name)
  Bytes::from_array(out)
}

///|
fn append_zip_test_eocd(
  out : Array[Byte],
  entry_count : Int,
  central_offset : Int,
) -> Unit {
  let central_size = out.length() - central_offset
  push_u32_le(out, (0x06054B50 : UInt))
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, entry_count)
  push_u16_le(out, entry_count)
  push_u32_le(out, central_size.reinterpret_as_uint())
  push_u32_le(out, central_offset.reinterpret_as_uint())
  push_u16_le(out, 0)
}

///|
fn expect_zip_rejected(bytes : Array[Byte]) -> Unit raise {
  try @zip.read(Bytes::from_array(bytes)) catch {
    _ => ()
  } noraise {
    _ => fail("expected strict ZIP read to reject archive")
  }
}

///|
test "zip read: corrupted structures hit error variants" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = @zip.write(archive).to_array()
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
  try @zip.read(Bytes::from_array(bad_eocd_sig)) catch {
    e => inspect(e is MissingEndOfCentral, content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let out_of_bounds = raw_bytes.copy()
  zip_overwrite_u32_le(
    out_of_bounds,
    eocd + 16,
    (out_of_bounds.length() + central_size).reinterpret_as_uint(),
  )
  try @zip.read(Bytes::from_array(out_of_bounds)) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let bad_cd_sig = raw_bytes.copy()
  bad_cd_sig[central_offset] = (0).to_byte()
  try @zip.read(Bytes::from_array(bad_cd_sig)) catch {
    e => inspect(e is InvalidSignature(..), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let bad_name = raw_bytes.copy()
  if name_len > 0 {
    bad_name[central_offset + 46] = (0xFF).to_byte()
  }
  try @zip.read(Bytes::from_array(bad_name)) catch {
    e => inspect(e is InvalidUtf8(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let bad_method = raw_bytes.copy()
  overwrite_u16_le(bad_method, central_offset + 10, 99)
  try @zip.read(Bytes::from_array(bad_method)) catch {
    e => inspect(e is UnsupportedCompression(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let bad_local_sig = raw_bytes.copy()
  bad_local_sig[local_offset] = (0).to_byte()
  try @zip.read(Bytes::from_array(bad_local_sig)) catch {
    e => inspect(e is InvalidSignature(..), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let multi_disk = raw_bytes.copy()
  overwrite_u16_le(multi_disk, eocd + 4, 1)
  try @zip.read(Bytes::from_array(multi_disk)) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let zip64_locator_missing = raw_bytes.copy()
  overwrite_u16_le(zip64_locator_missing, eocd + 8, 0xFFFF)
  overwrite_u16_le(zip64_locator_missing, eocd + 10, 0xFFFF)
  zip_overwrite_u32_le(zip64_locator_missing, eocd + 12, (0xFFFFFFFF : UInt))
  zip_overwrite_u32_le(zip64_locator_missing, eocd + 16, (0xFFFFFFFF : UInt))
  try @zip.read(Bytes::from_array(zip64_locator_missing)) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let mismatched_comp_size = raw_bytes.copy()
  zip_overwrite_u32_le(mismatched_comp_size, local_offset + 18, (1 : UInt))
  try @zip.read(Bytes::from_array(mismatched_comp_size)) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let zip64_size_missing = raw_bytes.copy()
  zip_overwrite_u32_le(
    zip64_size_missing,
    central_offset + 20,
    (0xFFFFFFFF : UInt),
  )
  try @zip.read(Bytes::from_array(zip64_size_missing)) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let zip64_offset_missing = raw_bytes.copy()
  zip_overwrite_u32_le(
    zip64_offset_missing,
    central_offset + 42,
    (0xFFFFFFFF : UInt),
  )
  try @zip.read(Bytes::from_array(zip64_offset_missing)) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
  let encrypted_flag = raw_bytes.copy()
  overwrite_u16_le(encrypted_flag, central_offset + 8, 0x0801)
  try @zip.read(Bytes::from_array(encrypted_flag)) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read: EOCD and central directory have one exact interpretation" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw) {
    Some(value) => value
    None => fail("missing EOCD")
  }
  let central_size = read_u32_le(raw, eocd + 12).reinterpret_as_int()

  // A complete fake EOCD in the real EOCD's comment used to be selected as
  // an empty archive. It is EOF-anchored, but its central span cannot also be
  // exact, so the archive must be rejected instead of split-view parsed.
  let decoy = raw.copy()
  overwrite_u16_le(decoy, eocd + 20, 22)
  push_u32_le(decoy, (0x06054b50 : UInt))
  for _ in 0..<8 {
    push_u16_le(decoy, 0)
  }
  push_u16_le(decoy, 0)
  expect_zip_rejected(decoy)

  let bad_size = raw.copy()
  zip_overwrite_u32_le(
    bad_size,
    eocd + 12,
    (central_size - 1).reinterpret_as_uint(),
  )
  expect_zip_rejected(bad_size)

  let bad_count = raw.copy()
  overwrite_u16_le(bad_count, eocd + 8, 0)
  overwrite_u16_le(bad_count, eocd + 10, 0)
  expect_zip_rejected(bad_count)
}

///|
fn wrap_classic_archive_with_zip64_eocd(
  raw : Array[Byte],
  classic_entries : Int,
  classic_size : UInt,
  classic_offset : UInt,
) -> Bytes raise {
  let eocd = match find_eocd_offset(raw) {
    Some(value) => value
    None => fail("missing EOCD")
  }
  let central_size = read_u32_le(raw, eocd + 12)
  let central_offset = read_u32_le(raw, eocd + 16)
  let out : Array[Byte] = []
  for index in 0..<eocd {
    out.push(raw[index])
  }
  let zip64_offset = out.length()
  push_u32_le(out, (0x06064B50 : UInt))
  push_u64_le(out, (44 : UInt64))
  push_u16_le(out, 45)
  push_u16_le(out, 45)
  push_u32_le(out, (0 : UInt))
  push_u32_le(out, (0 : UInt))
  push_u64_le(out, (1 : UInt64))
  push_u64_le(out, (1 : UInt64))
  push_u64_le(out, UInt64::extend_uint(central_size))
  push_u64_le(out, UInt64::extend_uint(central_offset))
  push_u32_le(out, (0x07064B50 : UInt))
  push_u32_le(out, (0 : UInt))
  push_u64_le(out, zip64_offset.to_uint64())
  push_u32_le(out, (1 : UInt))
  push_u32_le(out, (0x06054B50 : UInt))
  push_u16_le(out, 0)
  push_u16_le(out, 0)
  push_u16_le(out, classic_entries)
  push_u16_le(out, classic_entries)
  push_u32_le(out, classic_size)
  push_u32_le(out, classic_offset)
  push_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
test "zip read: classic and ZIP64 EOCD fields cannot disagree" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw) {
    Some(value) => value
    None => fail("missing EOCD")
  }
  let central_size = read_u32_le(raw, eocd + 12)
  let central_offset = read_u32_le(raw, eocd + 16)
  for
    case in [
      (
        wrap_classic_archive_with_zip64_eocd(
          raw,
          0,
          (0xFFFFFFFF : UInt),
          central_offset,
        ),
        "classic and zip64 entry count mismatch",
      ),
      (
        wrap_classic_archive_with_zip64_eocd(
          raw,
          1,
          central_size - 1,
          (0xFFFFFFFF : UInt),
        ),
        "classic and zip64 central size mismatch",
      ),
      (
        wrap_classic_archive_with_zip64_eocd(
          raw,
          1,
          (0xFFFFFFFF : UInt),
          central_offset + 1,
        ),
        "classic and zip64 central offset mismatch",
      ),
    ] {
    let (bytes, expected) = case
    try @zip.read(bytes) catch {
      UnsupportedFeature(msg~) => assert_eq(msg, expected)
      _ => fail("expected mixed EOCD view to be rejected")
    } noraise {
      _ => fail("expected mixed EOCD view to be rejected")
    }
  }
}

///|
test "zip read: local record intervals cannot overlap" {
  let inner_name : Bytes = b"inner"
  let inner_data : Bytes = b"x"
  let embedded : Array[Byte] = []
  ignore(append_zip_test_local(embedded, inner_name, inner_data))
  let outer_name : Bytes = b"outer"
  let outer_data = Bytes::from_array(embedded)
  let out : Array[Byte] = []
  let outer_offset = append_zip_test_local(out, outer_name, outer_data)
  let inner_offset = outer_offset + 30 + outer_name.length()
  let central_offset = out.length()
  append_zip_test_central(out, outer_name, outer_data, outer_offset)
  append_zip_test_central(out, inner_name, inner_data, inner_offset)
  append_zip_test_eocd(out, 2, central_offset)
  try @zip.read(Bytes::from_array(out)) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="overlapping zip local records")
    _ => fail("expected overlapping local records to be rejected")
  } noraise {
    _ => fail("expected overlapping local records to be rejected")
  }
}

///|
test "zip read: every local record is referenced exactly once" {
  let out : Array[Byte] = []
  ignore(append_zip_test_local(out, b"orphan", b"hidden"))
  let visible_offset = append_zip_test_local(out, b"visible", b"shown")
  let central_offset = out.length()
  append_zip_test_central(out, b"visible", b"shown", visible_offset)
  append_zip_test_eocd(out, 1, central_offset)
  try @zip.read(Bytes::from_array(out)) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="unreferenced data before zip central directory")
    _ => fail("expected orphan local record to be rejected")
  } noraise {
    _ => fail("expected orphan local record to be rejected")
  }
}

///|
test "zip read: Unicode Path extras cannot create alternate names" {
  let name : Bytes = b"safe.xml"
  let data : Bytes = b"payload"
  let extra = zip_test_unicode_path_extra(name, b"word/document.xml")
  let local_only : Array[Byte] = []
  let local_offset = append_zip_test_local(local_only, name, data, extra~)
  let central_offset = local_only.length()
  append_zip_test_central(local_only, name, data, local_offset)
  append_zip_test_eocd(local_only, 1, central_offset)
  let central_only : Array[Byte] = []
  let local_offset = append_zip_test_local(central_only, name, data)
  let central_offset = central_only.length()
  append_zip_test_central(central_only, name, data, local_offset, extra~)
  append_zip_test_eocd(central_only, 1, central_offset)
  for archive in [local_only, central_only] {
    try @zip.read(Bytes::from_array(archive)) catch {
      UnsupportedFeature(msg~) =>
        inspect(msg, content="unicode path extra field name mismatch")
      _ => fail("expected Unicode Path extra field to be rejected")
    } noraise {
      _ => fail("expected Unicode Path extra field to be rejected")
    }
  }
  let matching_extra = zip_test_unicode_path_extra(name, name)
  let matching : Array[Byte] = []
  let local_offset = append_zip_test_local(
    matching,
    name,
    data,
    extra=matching_extra,
  )
  let central_offset = matching.length()
  append_zip_test_central(
    matching,
    name,
    data,
    local_offset,
    extra=matching_extra,
  )
  append_zip_test_eocd(matching, 1, central_offset)
  let parsed = @zip.read(Bytes::from_array(matching))
  inspect(parsed.get("safe.xml") == Some(data), content="true")
}

///|
test "zip read: DEFLATE payload must consume its declared span" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello", compression=Deflate)
  let raw = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw) {
    Some(value) => value
    None => fail("missing EOCD")
  }
  let central = read_u32_le(raw, eocd + 16).reinterpret_as_int()
  let local_offset = read_u32_le(raw, central + 42).reinterpret_as_int()
  let compressed_size = read_u32_le(raw, central + 20).reinterpret_as_int()
  let with_trailing : Array[Byte] = []
  for index in 0..<central {
    with_trailing.push(raw[index])
  }
  with_trailing.push((0).to_byte())
  for index in central..<raw.length() {
    with_trailing.push(raw[index])
  }
  let shifted_central = central + 1
  let shifted_eocd = eocd + 1
  zip_overwrite_u32_le(
    with_trailing,
    local_offset + 18,
    (compressed_size + 1).reinterpret_as_uint(),
  )
  zip_overwrite_u32_le(
    with_trailing,
    shifted_central + 20,
    (compressed_size + 1).reinterpret_as_uint(),
  )
  zip_overwrite_u32_le(
    with_trailing,
    shifted_eocd + 16,
    shifted_central.reinterpret_as_uint(),
  )
  try @zip.read(Bytes::from_array(with_trailing)) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="trailing bytes after deflate stream")
    _ => fail("expected trailing DEFLATE bytes to be rejected")
  } noraise {
    _ => fail("expected trailing DEFLATE bytes to be rejected")
  }
}

///|
test "zip read: local headers are bound to their central records" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw) {
    Some(value) => value
    None => fail("missing EOCD")
  }
  let central = read_u32_le(raw, eocd + 16).reinterpret_as_int()
  let local_offset = read_u32_le(raw, central + 42).reinterpret_as_int()

  let bad_method = raw.copy()
  overwrite_u16_le(bad_method, local_offset + 8, 8)
  expect_zip_rejected(bad_method)

  let bad_name = raw.copy()
  bad_name[local_offset + 30] = b'b'
  expect_zip_rejected(bad_name)

  let bad_crc = raw.copy()
  bad_crc[local_offset + 14] = (bad_crc[local_offset + 14].to_uint() ^ 1).to_byte()
  expect_zip_rejected(bad_crc)

  let bad_size = raw.copy()
  zip_overwrite_u32_le(bad_size, local_offset + 22, (4 : UInt))
  expect_zip_rejected(bad_size)

  // Even mutually consistent local/central declarations must equal the
  // materialized length.
  let bad_decoded_size = raw.copy()
  zip_overwrite_u32_le(bad_decoded_size, local_offset + 22, (4 : UInt))
  zip_overwrite_u32_le(bad_decoded_size, central + 24, (4 : UInt))
  expect_zip_rejected(bad_decoded_size)
}

///|
test "zip read: data descriptors are bound to central CRC and sizes" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello", data_descriptor=true)
  let raw = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw) {
    Some(value) => value
    None => fail("missing EOCD")
  }
  let central = read_u32_le(raw, eocd + 16).reinterpret_as_int()
  let local_offset = read_u32_le(raw, central + 42).reinterpret_as_int()
  let name_len = read_u16_le(raw, local_offset + 26)
  let extra_len = read_u16_le(raw, local_offset + 28)
  let compressed_size = read_u32_le(raw, central + 20).reinterpret_as_int()
  let descriptor = local_offset + 30 + name_len + extra_len + compressed_size
  let bad = raw.copy()
  bad[descriptor + 4] = (bad[descriptor + 4].to_uint() ^ 1).to_byte()
  expect_zip_rejected(bad)
}

///|
test "zip read_limited caps inflation by the remaining aggregate budget" {
  let archive = @zip.Archive::new()
  archive.add("a", b"123456789012345678901234")
  archive.add("b", b"1234567890123456")
  let raw = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw) {
    Some(value) => value
    None => fail("missing EOCD")
  }
  let central = read_u32_le(raw, eocd + 16).reinterpret_as_int()
  let first_name = read_u16_le(raw, central + 28)
  let first_extra = read_u16_le(raw, central + 30)
  let first_comment = read_u16_le(raw, central + 32)
  let second_central = central + 46 + first_name + first_extra + first_comment
  let second_local = read_u32_le(raw, second_central + 42).reinterpret_as_int()
  // The second entry claims one expanded byte in both views, keeping declared
  // aggregate usage below 32. Its stored payload is 16 bytes, so extraction
  // must stop at the eight bytes remaining after the first entry.
  zip_overwrite_u32_le(raw, second_local + 22, (1 : UInt))
  zip_overwrite_u32_le(raw, second_central + 24, (1 : UInt))
  try
    @zip.read_limited(
      Bytes::from_array(raw),
      max_entries=2,
      max_entry_uncompressed_bytes=64,
      max_total_uncompressed_bytes=32,
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="total_uncompressed_bytes")
      inspect(limit, content="32")
      inspect(actual, content="40")
    }
    _ => fail("expected aggregate materialization limit")
  } noraise {
    _ => fail("expected aggregate materialization limit")
  }
}

///|
test "zip read_limited reports large ZIP32 declarations as resource limits" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw) {
    Some(value) => value
    None => fail("missing EOCD")
  }
  let central = read_u32_le(raw, eocd + 16).reinterpret_as_int()
  zip_overwrite_u32_le(raw, central + 24, (0x80000000 : UInt))
  try
    @zip.read_limited(
      Bytes::from_array(raw),
      max_entries=1,
      max_entry_uncompressed_bytes=64,
      max_total_uncompressed_bytes=64,
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="entry_uncompressed_bytes")
      inspect(limit, content="64")
      inspect(actual, content="2147483647")
    }
    _ => fail("expected ZIP32 resource limit")
  } noraise {
    _ => fail("expected ZIP32 resource limit")
  }
}

///|
test "zip read: EOCD must be anchored to the declared comment at EOF" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let bad_comment = raw_bytes.copy()
  overwrite_u16_le(bad_comment, eocd + 20, 1)
  try @zip.read(Bytes::from_array(bad_comment)) catch {
    e => inspect(e is MissingEndOfCentral, content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read: central name_len hits Reader::read_bytes OutOfBounds" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let central_offset = read_u32_le(raw_bytes, eocd + 16).reinterpret_as_int()
  let bad_name_len = raw_bytes.copy()
  overwrite_u16_le(bad_name_len, central_offset + 28, 0xFFFF)
  try @zip.read(Bytes::from_array(bad_name_len)) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read: central offset near EOF hits Reader::read_u8 OutOfBounds" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = @zip.write(archive).to_array()
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
  try @zip.read(Bytes::from_array(bad_central)) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read: unsupported flags hits ensure_flags_supported branch" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let central_offset = read_u32_le(raw_bytes, eocd + 16).reinterpret_as_int()
  let bad_flags = raw_bytes.copy()
  // UTF-8 (0x0800) + unsupported bit 0x0020.
  overwrite_u16_le(bad_flags, central_offset + 8, 0x0820)
  try @zip.read(Bytes::from_array(bad_flags)) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="unsupported zip flags: 0x20")
    _ => fail("expected UnsupportedFeature for unsupported flags")
  } noraise {
    _ => fail("expected UnsupportedFeature for unsupported flags")
  }
}

///|
test "zip read: u32_to_int overflow hits UnsupportedFeature" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let bad = raw_bytes.copy()
  zip_overwrite_u32_le(bad, eocd + 16, (0x80000000 : UInt))
  try @zip.read(Bytes::from_array(bad)) catch {
    UnsupportedFeature(msg~) => inspect(msg, content="u32 exceeds Int range")
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
  try @zip.read(bytes) catch {
    UnsupportedFeature(msg~) => inspect(msg, content="zip64 locator missing")
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
  try @zip.read(bytes) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
fn make_zip_zip64_invalid_eocd_signature() -> Bytes {
  let out : Array[Byte] = []
  // Full-size fake zip64 EOCD at offset 0 with an invalid signature.
  push_u32_le(out, (0 : UInt))
  for _ in 0..<52 {
    out.push((0).to_byte())
  }
  // Zip64 locator at offset 56 (20 bytes).
  push_u32_le(out, (0x07064b50 : UInt))
  push_u32_le(out, (0 : UInt))
  // zip64_eocd_offset = 0
  for _ in 0..<=7 {
    out.push((0).to_byte())
  }
  push_u32_le(out, (1 : UInt))
  // Regular EOCD at offset 76.
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
  try @zip.read(bytes) catch {
    e => inspect(e is InvalidSignature(..), content="true")
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
  try @zip.read(bytes) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="multi-disk zip not supported")
    _ => fail("expected multi-disk zip not supported")
  } noraise {
    _ => fail("expected multi-disk zip not supported")
  }
}

///|
test "zip read: zip64 uncompressed size missing hits zip64 size missing" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  let raw_bytes = @zip.write(archive).to_array()
  let eocd = match find_eocd_offset(raw_bytes) {
    Some(v) => v
    None => fail("missing EOCD")
  }
  let central_offset = read_u32_le(raw_bytes, eocd + 16).reinterpret_as_int()
  let bad = raw_bytes.copy()
  // Uncompressed size -> needs zip64, but no zip64 extra field present.
  zip_overwrite_u32_le(bad, central_offset + 24, (0xFFFFFFFF : UInt))
  try @zip.read(Bytes::from_array(bad)) catch {
    UnsupportedFeature(msg~) => inspect(msg, content="zip64 size missing")
    _ => fail("expected zip64 size missing")
  } noraise {
    _ => fail("expected zip64 size missing")
  }
}

///|
fn make_zip_zip64_huge_declared_entry_count() -> Bytes {
  let out : Array[Byte] = []
  // Zip64 EOCD at offset 0 declaring 2^30 entries in a tiny archive.
  push_u32_le(out, (0x06064b50 : UInt))
  push_u64_le(out, (44 : UInt64))
  push_u16_le(out, 45)
  push_u16_le(out, 45)
  push_u32_le(out, (0 : UInt))
  push_u32_le(out, (0 : UInt))
  push_u64_le(out, (0x40000000 : UInt64)) // entries on disk
  push_u64_le(out, (0x40000000 : UInt64)) // total entries
  push_u64_le(out, (0 : UInt64)) // central size
  push_u64_le(out, (0 : UInt64)) // central offset
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
test "zip read: zip64 EOCD huge declared entry count fails cleanly" {
  // Declares 2^30 entries; must fail on the first bogus central header
  // instead of preallocating gigabytes of entry metadata.
  let bytes = make_zip_zip64_huge_declared_entry_count()
  try @zip.read(bytes) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip read data descriptor" {
  let name : Bytes = b"a.txt"
  let data : Bytes = b"hi"
  let crc = crc32(data)
  let buf : Array[Byte] = []
  // local header
  @testutil.push_u32_le(buf, 0x04034B50)
  @testutil.push_u16_le(buf, 20)
  @testutil.push_u16_le(buf, 0x0808)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_u16_le(buf, name.length())
  @testutil.push_u16_le(buf, 0)
  @testutil.push_bytes(buf, name)
  @testutil.push_bytes(buf, data)
  // data descriptor
  @testutil.push_u32_le(buf, 0x08074B50)
  @testutil.push_u32_le(buf, crc)
  @testutil.push_u32_le(buf, data.length().reinterpret_as_uint())
  @testutil.push_u32_le(buf, data.length().reinterpret_as_uint())
  // central directory
  let central_offset = buf.length()
  @testutil.push_u32_le(buf, 0x02014B50)
  @testutil.push_u16_le(buf, 20)
  @testutil.push_u16_le(buf, 20)
  @testutil.push_u16_le(buf, 0x0808)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, crc)
  @testutil.push_u32_le(buf, data.length().reinterpret_as_uint())
  @testutil.push_u32_le(buf, data.length().reinterpret_as_uint())
  @testutil.push_u16_le(buf, name.length())
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_bytes(buf, name)
  // end of central directory
  let central_size = buf.length() - central_offset
  @testutil.push_u32_le(buf, 0x06054B50)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 1)
  @testutil.push_u16_le(buf, 1)
  @testutil.push_u32_le(buf, central_size.reinterpret_as_uint())
  @testutil.push_u32_le(buf, central_offset.reinterpret_as_uint())
  @testutil.push_u16_le(buf, 0)
  let archive = read(Bytes::from_array(buf))
  inspect(archive.get("a.txt") == Some(b"hi"), content="true")
}

///|
fn make_streamed_zip64_descriptor_archive(
  local_size : UInt,
  zip64_placeholder : UInt64,
) -> Bytes {
  let name : Bytes = b"streamed.txt"
  let data : Bytes = b"zip64-stream"
  let crc = crc32(data)
  let buf : Array[Byte] = []
  // Streamed local header: ZIP64 is selected before the final sizes are
  // known, while the central directory can later use its 32-bit fields.
  @testutil.push_u32_le(buf, 0x04034B50)
  @testutil.push_u16_le(buf, 45)
  @testutil.push_u16_le(buf, 0x0808)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_u32_le(buf, local_size)
  @testutil.push_u32_le(buf, local_size)
  @testutil.push_u16_le(buf, name.length())
  @testutil.push_u16_le(buf, 20)
  @testutil.push_bytes(buf, name)
  @testutil.push_u16_le(buf, 0x0001)
  @testutil.push_u16_le(buf, 16)
  @testutil.push_u64_le(buf, zip64_placeholder)
  @testutil.push_u64_le(buf, zip64_placeholder)
  @testutil.push_bytes(buf, data)
  // ZIP64 data descriptor selected by the local ZIP64 extra field.
  @testutil.push_u32_le(buf, 0x08074B50)
  @testutil.push_u32_le(buf, crc)
  @testutil.push_u64_le(buf, data.length().to_uint64())
  @testutil.push_u64_le(buf, data.length().to_uint64())
  let central_offset = buf.length()
  @testutil.push_u32_le(buf, 0x02014B50)
  @testutil.push_u16_le(buf, 45)
  @testutil.push_u16_le(buf, 45)
  @testutil.push_u16_le(buf, 0x0808)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, crc)
  @testutil.push_u32_le(buf, data.length().reinterpret_as_uint())
  @testutil.push_u32_le(buf, data.length().reinterpret_as_uint())
  @testutil.push_u16_le(buf, name.length())
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_bytes(buf, name)
  let central_size = buf.length() - central_offset
  @testutil.push_u32_le(buf, 0x06054B50)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 1)
  @testutil.push_u16_le(buf, 1)
  @testutil.push_u32_le(buf, central_size.reinterpret_as_uint())
  @testutil.push_u32_le(buf, central_offset.reinterpret_as_uint())
  @testutil.push_u16_le(buf, 0)
  Bytes::from_array(buf)
}

///|
test "zip read streamed ZIP64 descriptors with ZIP32 central sizes" {
  for local_size in [(0xFFFFFFFF : UInt), (0 : UInt)] {
    let archive = read(make_streamed_zip64_descriptor_archive(local_size, 0))
    inspect(
      archive.get("streamed.txt") == Some(b"zip64-stream"),
      content="true",
    )
  }
}

///|
test "zip read rejects mismatched streamed ZIP64 placeholders" {
  try read(make_streamed_zip64_descriptor_archive(0xFFFFFFFF, 1)) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="mismatched local and central compressed size")
    _ => fail("expected mismatched ZIP64 placeholder")
  } noraise {
    _ => fail("expected mismatched ZIP64 placeholder")
  }
}

///|
test "zip read zip64 extra sizes" {
  let name : Bytes = b"b.txt"
  let data : Bytes = b"zip64"
  let crc = crc32(data)
  let buf : Array[Byte] = []
  // local header with zip64 extra
  @testutil.push_u32_le(buf, 0x04034B50)
  @testutil.push_u16_le(buf, 45)
  @testutil.push_u16_le(buf, 0x0800)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, crc)
  @testutil.push_u32_le(buf, 0xFFFFFFFF)
  @testutil.push_u32_le(buf, 0xFFFFFFFF)
  @testutil.push_u16_le(buf, name.length())
  @testutil.push_u16_le(buf, 20)
  @testutil.push_bytes(buf, name)
  // zip64 extra (uncomp, comp)
  @testutil.push_u16_le(buf, 0x0001)
  @testutil.push_u16_le(buf, 16)
  @testutil.push_u64_le(
    buf,
    UInt64::extend_uint(data.length().reinterpret_as_uint()),
  )
  @testutil.push_u64_le(
    buf,
    UInt64::extend_uint(data.length().reinterpret_as_uint()),
  )
  @testutil.push_bytes(buf, data)
  // central directory with zip64 extra (uncomp, comp, offset)
  let central_offset = buf.length()
  @testutil.push_u32_le(buf, 0x02014B50)
  @testutil.push_u16_le(buf, 45)
  @testutil.push_u16_le(buf, 45)
  @testutil.push_u16_le(buf, 0x0800)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, crc)
  @testutil.push_u32_le(buf, 0xFFFFFFFF)
  @testutil.push_u32_le(buf, 0xFFFFFFFF)
  @testutil.push_u16_le(buf, name.length())
  @testutil.push_u16_le(buf, 28)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u32_le(buf, 0)
  @testutil.push_u32_le(buf, 0xFFFFFFFF)
  @testutil.push_bytes(buf, name)
  @testutil.push_u16_le(buf, 0x0001)
  @testutil.push_u16_le(buf, 24)
  let central_uncompressed_offset = buf.length()
  @testutil.push_u64_le(
    buf,
    UInt64::extend_uint(data.length().reinterpret_as_uint()),
  )
  @testutil.push_u64_le(
    buf,
    UInt64::extend_uint(data.length().reinterpret_as_uint()),
  )
  @testutil.push_u64_le(buf, UInt64::extend_uint(0))
  // end of central directory
  let central_size = buf.length() - central_offset
  @testutil.push_u32_le(buf, 0x06054B50)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 0)
  @testutil.push_u16_le(buf, 1)
  @testutil.push_u16_le(buf, 1)
  @testutil.push_u32_le(buf, central_size.reinterpret_as_uint())
  @testutil.push_u32_le(buf, central_offset.reinterpret_as_uint())
  @testutil.push_u16_le(buf, 0)
  let encoded = Bytes::from_array(buf)
  let archive = read(encoded)
  inspect(archive.get("b.txt") == Some(b"zip64"), content="true")
  let oversized = encoded.to_array()
  for index in 0..<8 {
    oversized[central_uncompressed_offset + index] = (0).to_byte()
  }
  oversized[central_uncompressed_offset + 4] = (1).to_byte()
  try
    read_limited(
      Bytes::from_array(oversized),
      max_package_bytes=oversized.length(),
      max_entries=1,
      max_entry_uncompressed_bytes=64,
      max_total_uncompressed_bytes=64,
      max_total_preserved_source_bytes=oversized.length(),
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="entry_uncompressed_bytes")
      inspect(limit, content="64")
      inspect(actual, content="2147483647")
    }
    _ => fail("expected ZIP64 resource limit")
  } noraise {
    _ => fail("expected oversized ZIP64 declaration to raise")
  }
}

///|
test "zip64 extra values cannot escape their declared field" {
  let followed_by_other_field : Bytes = [
    // Empty ZIP64 field.
    0x01, 0x00, 0x00, 0x00,
    // Unrelated eight-byte field that must not supply the ZIP64 value.
     0xFE, 0xCA, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]
  try
    parse_zip64_extra(
      followed_by_other_field, b"", "", true, false, false, false,
    )
  catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="zip64 extra field size mismatch")
    _ => fail("expected bounded ZIP64 field failure")
  } noraise {
    _ => fail("expected bounded ZIP64 field failure")
  }
  let trailing_partial_header : Bytes = [0xFE, 0xCA, 0x00, 0x00, 0x01]
  try
    parse_zip64_extra(
      trailing_partial_header, b"", "", false, false, false, false,
    )
  catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="truncated zip extra field header")
    _ => fail("expected truncated extra-field failure")
  } noraise {
    _ => fail("expected truncated extra-field failure")
  }
}

///|
test "zip reader wb: direct guard error branches" {
  let reader = Reader::new(b"", 0)
  try reader.read_bytes(-1) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_bytes to raise")
  }
  try reader.skip(-1) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected skip to raise")
  }
  try (0x1_0000_0000 : UInt64).to_int_checked() catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected UInt64::to_int_checked to raise")
  }
  try read_u16_le_at(b"\x00", 0) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_u16_le_at to raise")
  }
  try read_u32_le_at_raw(b"\x00\x01", 0) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_u32_le_at_raw to raise")
  }
  try read_u64_le_at(b"\x00\x01\x02", 0) catch {
    e => inspect(e is OutOfBounds(_), content="true")
  } noraise {
    _ => fail("expected read_u64_le_at to raise")
  }
}

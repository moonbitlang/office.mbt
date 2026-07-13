///|
fn preservation_local_record(
  output : Array[Byte],
  name : Bytes,
  data : Bytes,
  deflated : Bool,
  descriptor : Bool,
  extra : Bytes,
  time : Int,
  date : Int,
) -> Int raise ZipError {
  let offset = output.length()
  let payload = if deflated { deflate_encode(data) } else { data }
  let flags = flag_utf8 | (if descriptor { flag_data_descriptor } else { 0 })
  let method_id = if deflated { 8 } else { 0 }
  let crc = crc32(data)
  write_u32_le(output, local_header_sig.reinterpret_as_uint())
  write_u16_le(output, 20)
  write_u16_le(output, flags)
  write_u16_le(output, method_id)
  write_u16_le(output, time)
  write_u16_le(output, date)
  write_u32_le(output, if descriptor { 0 } else { crc })
  write_u32_le(
    output,
    if descriptor {
      0
    } else {
      payload.length().reinterpret_as_uint()
    },
  )
  write_u32_le(
    output,
    if descriptor {
      0
    } else {
      data.length().reinterpret_as_uint()
    },
  )
  write_u16_le(output, name.length())
  write_u16_le(output, extra.length())
  write_bytes(output, name)
  write_bytes(output, extra)
  write_bytes(output, payload)
  if descriptor {
    write_data_descriptor(output, crc, payload.length(), data.length(), false)
  }
  offset
}

///|
fn preservation_central_record(
  output : Array[Byte],
  name : Bytes,
  data : Bytes,
  deflated : Bool,
  descriptor : Bool,
  extra : Bytes,
  comment : Bytes,
  time : Int,
  date : Int,
  internal_attributes : Int,
  external_attributes : UInt,
  local_offset : Int,
) -> Unit raise ZipError {
  let payload = if deflated { deflate_encode(data) } else { data }
  let flags = flag_utf8 | (if descriptor { flag_data_descriptor } else { 0 })
  write_u32_le(output, central_header_sig.reinterpret_as_uint())
  write_u16_le(output, 63)
  write_u16_le(output, 20)
  write_u16_le(output, flags)
  write_u16_le(output, if deflated { 8 } else { 0 })
  write_u16_le(output, time)
  write_u16_le(output, date)
  write_u32_le(output, crc32(data))
  write_u32_le(output, payload.length().reinterpret_as_uint())
  write_u32_le(output, data.length().reinterpret_as_uint())
  write_u16_le(output, name.length())
  write_u16_le(output, extra.length())
  write_u16_le(output, comment.length())
  write_u16_le(output, 0)
  write_u16_le(output, internal_attributes)
  write_u32_le(output, external_attributes)
  write_u32_le(output, local_offset.reinterpret_as_uint())
  write_bytes(output, name)
  write_bytes(output, extra)
  write_bytes(output, comment)
}

///|
fn preservation_fixture() -> Bytes raise ZipError {
  let output : Array[Byte] = []
  let target_name = b"target.xml"
  let target_data = b"old"
  let untouched_name = b"untouched.bin"
  let untouched_data = b"compressible-compressible-compressible"
  let target_offset = preservation_local_record(
    output, target_name, target_data, false, false, b"", 0x1001, 0x2002,
  )
  let custom_extra = b"\xfe\xca\x02\x00\xab\xcd"
  let untouched_offset = preservation_local_record(
    output, untouched_name, untouched_data, true, true, custom_extra, 0x3456, 0x4567,
  )
  let central_offset = output.length()
  // Central order intentionally differs from local-record order.
  preservation_central_record(
    output,
    untouched_name,
    untouched_data,
    true,
    true,
    custom_extra,
    b"entry-comment",
    0x3456,
    0x4567,
    0x1234,
    (0x89abcdef : UInt),
    untouched_offset,
  )
  preservation_central_record(
    output,
    target_name,
    target_data,
    false,
    false,
    b"",
    b"",
    0x1001,
    0x2002,
    0,
    (0 : UInt),
    target_offset,
  )
  let central_size = output.length() - central_offset
  let archive_comment = b"archive-comment"
  write_u32_le(output, end_of_central_sig.reinterpret_as_uint())
  write_u16_le(output, 0)
  write_u16_le(output, 0)
  write_u16_le(output, 2)
  write_u16_le(output, 2)
  write_u32_le(output, central_size.reinterpret_as_uint())
  write_u32_le(output, central_offset.reinterpret_as_uint())
  write_u16_le(output, archive_comment.length())
  write_bytes(output, archive_comment)
  Bytes::from_array(output)
}

///|
fn preserved_entry(archive : Archive, name : String) -> Entry raise {
  for entry in archive.entries {
    if entry.name == name {
      return entry
    }
  }
  fail("missing preserved test entry {name}")
}

///|
test "zip replace preserves untouched source records and archive metadata" {
  let source = preservation_fixture()
  let archive = read(source)
  assert_true(archive.replace("target.xml", b"a much longer replacement"))
  let candidate = write(archive)
  let before = read(source)
  let after = read(candidate)
  let original = preserved_entry(before, "untouched.bin")
  let untouched = preserved_entry(after, "untouched.bin")
  assert_true(untouched.compression is Deflate)
  assert_true(untouched.data_descriptor)
  assert_eq(untouched.data, original.data)
  guard original.preserved is Some(original_source) else {
    fail("expected original source records")
  }
  guard untouched.preserved is Some(candidate_source) else {
    fail("expected candidate source records")
  }
  assert_eq(candidate_source.local_record, original_source.local_record)
  // The required local-header offset is the sole changing central field.
  assert_eq(
    candidate_source.central_record[:42],
    original_source.central_record[:42],
  )
  assert_eq(
    candidate_source.central_record[46:],
    original_source.central_record[46:],
  )
  assert_eq(after.comment, b"archive-comment")
  let target = preserved_entry(after, "target.xml")
  assert_eq(target.data, b"a much longer replacement")
  assert_true(
    target.source_local_offset.unwrap() < untouched.source_local_offset.unwrap(),
  )
  assert_eq(after.entries[0].name, "untouched.bin")
  assert_eq(after.entries[1].name, "target.xml")
}

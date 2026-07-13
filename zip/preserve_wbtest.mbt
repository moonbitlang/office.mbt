///|
fn write_bytes(buffer : Array[Byte], bytes : BytesView) -> Unit {
  for byte in bytes {
    buffer.push(byte)
  }
}

///|
fn write_u16_le(buffer : Array[Byte], value : Int) -> Unit raise ZipError {
  if value < 0 || value > 0xffff {
    raise UnsupportedFeature(msg="u16 overflow")
  }
  let raw = value.reinterpret_as_uint()
  buffer.push((raw & 0xff).to_byte())
  buffer.push(((raw >> 8) & 0xff).to_byte())
}

///|
fn write_u32_le(buffer : Array[Byte], value : UInt) -> Unit {
  buffer.push((value & 0xff).to_byte())
  buffer.push(((value >> 8) & 0xff).to_byte())
  buffer.push(((value >> 16) & 0xff).to_byte())
  buffer.push(((value >> 24) & 0xff).to_byte())
}

///|
fn write_u64_le(buffer : Array[Byte], value : UInt64) -> Unit {
  for index in 0..<8 {
    buffer.push(((value >> (8 * index)) & 0xff).to_byte())
  }
}

///|
fn write_data_descriptor(
  buffer : Array[Byte],
  crc : UInt,
  compressed_size : Int,
  uncompressed_size : Int,
  zip64_sizes : Bool,
) -> Unit raise ZipError {
  write_u32_le(buffer, data_descriptor_sig.reinterpret_as_uint())
  write_u32_le(buffer, crc)
  if zip64_sizes {
    write_u64_le(buffer, to_u64(compressed_size))
    write_u64_le(buffer, to_u64(uncompressed_size))
  } else {
    write_u32_le(buffer, to_u32(compressed_size))
    write_u32_le(buffer, to_u32(uncompressed_size))
  }
}

///|
fn patch_u32_le(
  buffer : Array[Byte],
  offset : Int,
  value : UInt,
) -> Unit raise ZipError {
  if offset < 0 || offset > buffer.length() || 4 > buffer.length() - offset {
    raise UnsupportedFeature(
      msg="central-directory offset patch is out of bounds",
    )
  }
  buffer[offset] = (value & 0xff).to_byte()
  buffer[offset + 1] = ((value >> 8) & 0xff).to_byte()
  buffer[offset + 2] = ((value >> 16) & 0xff).to_byte()
  buffer[offset + 3] = ((value >> 24) & 0xff).to_byte()
}

///|
fn patch_u64_le(
  buffer : Array[Byte],
  offset : Int,
  value : UInt64,
) -> Unit raise ZipError {
  if offset < 0 || offset > buffer.length() || 8 > buffer.length() - offset {
    raise UnsupportedFeature(msg="ZIP64 offset patch is out of bounds")
  }
  for index in 0..<8 {
    buffer[offset + index] = ((value >> (8 * index)) & 0xff).to_byte()
  }
}

///|
fn patch_u16_le(
  buffer : Array[Byte],
  offset : Int,
  value : Int,
) -> Unit raise ZipError {
  if value < 0 ||
    value > 0xffff ||
    offset < 0 ||
    offset > buffer.length() ||
    2 > buffer.length() - offset {
    raise UnsupportedFeature(msg="ZIP u16 patch is out of bounds")
  }
  let raw = value.reinterpret_as_uint()
  buffer[offset] = (raw & 0xff).to_byte()
  buffer[offset + 1] = ((raw >> 8) & 0xff).to_byte()
}

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
  let target_extra = b"\xef\xbe\x02\x00\x11\x22"
  let untouched_name = b"untouched.bin"
  let untouched_data = b"compressible-compressible-compressible"
  let target_offset = preservation_local_record(
    output, target_name, target_data, false, false, target_extra, 0x1001, 0x2002,
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
    target_extra,
    b"target-comment",
    0x1001,
    0x2002,
    0x5678,
    (0x76543210 : UInt),
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
fn write_central_heavy_preservation_fixture(
  output : FixedByteOutput,
  entry_count : Int,
  comment : Bytes,
) -> Unit raise ZipError {
  let local_offsets : Array[Int] = []
  for index in 0..<entry_count {
    let name = @encoding/utf8.encode("entry-\{index}.xml")
    local_offsets.push(output.length())
    write_u32_le_bounded(output, local_header_sig.reinterpret_as_uint(), None)
    write_u16_le_bounded(output, 20, None)
    write_u16_le_bounded(output, flag_utf8, None)
    write_u16_le_bounded(output, 0, None)
    write_u16_le_bounded(output, 0x1001, None)
    write_u16_le_bounded(output, 0x2002, None)
    write_u32_le_bounded(output, 0, None)
    write_u32_le_bounded(output, 0, None)
    write_u32_le_bounded(output, 0, None)
    write_u16_le_bounded(output, name.length(), None)
    write_u16_le_bounded(output, 0, None)
    write_bytes_bounded(output, name, None)
  }
  let central_offset = output.length()
  for index in 0..<entry_count {
    let name = @encoding/utf8.encode("entry-\{index}.xml")
    write_u32_le_bounded(output, central_header_sig.reinterpret_as_uint(), None)
    write_u16_le_bounded(output, 63, None)
    write_u16_le_bounded(output, 20, None)
    write_u16_le_bounded(output, flag_utf8, None)
    write_u16_le_bounded(output, 0, None)
    write_u16_le_bounded(output, 0x1001, None)
    write_u16_le_bounded(output, 0x2002, None)
    write_u32_le_bounded(output, 0, None)
    write_u32_le_bounded(output, 0, None)
    write_u32_le_bounded(output, 0, None)
    write_u16_le_bounded(output, name.length(), None)
    write_u16_le_bounded(output, 0, None)
    write_u16_le_bounded(output, comment.length(), None)
    write_u16_le_bounded(output, 0, None)
    write_u16_le_bounded(output, 0, None)
    write_u32_le_bounded(output, 0, None)
    write_u32_le_bounded(
      output,
      local_offsets[index].reinterpret_as_uint(),
      None,
    )
    write_bytes_bounded(output, name, None)
    write_bytes_bounded(output, comment, None)
  }
  let central_size = output.length() - central_offset
  write_u32_le_bounded(output, end_of_central_sig.reinterpret_as_uint(), None)
  write_u16_le_bounded(output, 0, None)
  write_u16_le_bounded(output, 0, None)
  write_u16_le_bounded(output, entry_count, None)
  write_u16_le_bounded(output, entry_count, None)
  write_u32_le_bounded(output, central_size.reinterpret_as_uint(), None)
  write_u32_le_bounded(output, central_offset.reinterpret_as_uint(), None)
  write_u16_le_bounded(output, 0, None)
}

///|
fn central_heavy_preservation_fixture(
  entry_count : Int,
  comment_bytes : Int,
) -> Bytes raise ZipError {
  let comment = Bytes::makei(comment_bytes, _ => (0x63).to_byte())
  let sizing = FixedByteOutput::counting()
  write_central_heavy_preservation_fixture(sizing, entry_count, comment)
  let output = FixedByteOutput::allocated(sizing.length())
  write_central_heavy_preservation_fixture(output, entry_count, comment)
  output.finish()
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
  assert_true(preserved_entry(archive, "untouched.bin").source_unchanged)
  assert_false(preserved_entry(archive, "target.xml").source_unchanged)
  let candidate = write(archive)
  let before = read(source)
  let after = read(candidate)
  let original = preserved_entry(before, "untouched.bin")
  let untouched = preserved_entry(after, "untouched.bin")
  assert_true(untouched.compression is Deflate)
  assert_true(untouched.data_descriptor)
  assert_eq(untouched.data, original.data)
  guard original.source is Some(original_source) else {
    fail("expected original source records")
  }
  guard untouched.source is Some(candidate_source) else {
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
  let original_target = preserved_entry(before, "target.xml")
  guard original_target.source is Some(original_target_source) else {
    fail("expected original target records")
  }
  guard target.source is Some(candidate_target_source) else {
    fail("expected candidate target records")
  }
  // Payload-dependent CRC/size fields may change. All producer metadata around
  // those fields remains byte-identical on the rewritten member itself.
  assert_eq(
    candidate_target_source.local_record[:14],
    original_target_source.local_record[:14],
  )
  let target_header_end = 30 +
    b"target.xml".length() +
    b"\xef\xbe\x02\x00\x11\x22".length()
  assert_eq(
    candidate_target_source.local_record[26:target_header_end],
    original_target_source.local_record[26:target_header_end],
  )
  assert_eq(
    candidate_target_source.central_record[4:16],
    original_target_source.central_record[4:16],
  )
  assert_eq(
    candidate_target_source.central_record[28:42],
    original_target_source.central_record[28:42],
  )
  assert_eq(
    candidate_target_source.central_record[46:],
    original_target_source.central_record[46:],
  )
  assert_true(
    target.source_local_offset.unwrap() < untouched.source_local_offset.unwrap(),
  )
  assert_eq(after.entries[0].name, "untouched.bin")
  assert_eq(after.entries[1].name, "target.xml")
}

///|
test "zip write_limited streams preserved central-heavy records" {
  let source = central_heavy_preservation_fixture(256, 4096)
  let archive = read_limited(
    source,
    max_entries=256,
    max_entry_uncompressed_bytes=0,
    max_total_uncompressed_bytes=0,
  )
  assert_true(archive.replace("entry-0.xml", b"replacement"))
  let exact = write(archive)
  let parsed = read_limited(
    exact,
    max_entries=256,
    max_entry_uncompressed_bytes=16,
    max_total_uncompressed_bytes=16,
  )
  assert_eq(parsed.entries().length(), 256)
  assert_eq(parsed.get("entry-0.xml"), Some(b"replacement"))
  guard find_end_of_central(exact) is Some(eocd_offset) else {
    fail("missing preserved central-heavy end record")
  }
  let central_size = u32_to_int(read_u32_le_at_raw(exact, eocd_offset + 12))
  let central_offset = u32_to_int(read_u32_le_at_raw(exact, eocd_offset + 16))
  assert_true(central_size > 1024 * 1024)
  assert_eq(write_limited(archive, max_output_bytes=exact.length()), exact)
  let central_prefix_limit = central_offset + central_size / 2
  try write_limited(archive, max_output_bytes=central_prefix_limit) catch {
    OutputLimitExceeded(limit~) => assert_eq(limit, central_prefix_limit)
    _ => fail("expected preserved central-directory output limit")
  } noraise {
    _ => fail("expected preserved central-heavy archive to exceed its limit")
  }
}

///|
#cfg(target="native")
test "zip sizing rejects near-envelope preserved records before allocation" {
  let source = central_heavy_preservation_fixture(1536, 65_500)
  let archive = read_limited(
    source,
    max_entries=1536,
    max_entry_uncompressed_bytes=0,
    max_total_uncompressed_bytes=0,
  )
  assert_true(archive.replace("entry-0.xml", b"replacement"))
  let expected_limit = 96 * 1024 * 1024
  // The source retains about 100 MiB of central records. The counting plan has
  // no output storage, so this rejection precedes a second package allocation.
  try plan_archive_write(archive, false, Some(expected_limit)) catch {
    OutputLimitExceeded(limit~) => assert_eq(limit, expected_limit)
    _ => fail("expected preserved near-envelope planning rejection")
  } noraise {
    _ => fail("expected preserved near-envelope archive to exceed its limit")
  }
}

///|
test "archive forks share immutable storage but isolate entry mutation" {
  let source = preservation_fixture()
  let original = read(source)
  let original_estimate = original.retained_size_estimate()
  let working = original.fork()
  assert_eq(working.retained_size_estimate(), original_estimate)
  assert_true(working.replace("target.xml", b"fork-only replacement"))
  working.add("new.xml", b"new")
  assert_eq(original.get("target.xml"), Some(b"old"))
  assert_eq(original.get("new.xml"), None)
  assert_eq(working.get("target.xml"), Some(b"fork-only replacement"))
  assert_eq(working.get("new.xml"), Some(b"new"))
  assert_eq(write(original), source)
}

///|
test "zip identical replacement retains every source byte" {
  let source = preservation_fixture()
  let archive = read(source)
  assert_true(archive.replace("target.xml", b"old"))
  assert_eq(write(archive), source)
}

///|
test "zip replacement preserves descriptor style and member metadata" {
  let source = preservation_fixture()
  let before = read(source)
  let archive = read(source)
  assert_true(archive.replace("untouched.bin", b"new descriptor payload"))
  assert_false(preserved_entry(archive, "untouched.bin").source_unchanged)
  let after = read(write(archive))
  let original = preserved_entry(before, "untouched.bin")
  let replacement = preserved_entry(after, "untouched.bin")
  assert_true(replacement.compression is Deflate)
  assert_true(replacement.data_descriptor)
  guard original.source is Some(original_source) else {
    fail("expected original descriptor records")
  }
  guard replacement.source is Some(replacement_source) else {
    fail("expected replacement descriptor records")
  }
  assert_eq(
    replacement_source.local_record[:14],
    original_source.local_record[:14],
  )
  assert_eq(
    replacement_source.central_record[4:16],
    original_source.central_record[4:16],
  )
  assert_eq(
    replacement_source.central_record[28:42],
    original_source.central_record[28:42],
  )
  assert_eq(
    replacement_source.central_record[46:],
    original_source.central_record[46:],
  )
}

///|
test "zip64 replacement preserves header layout and descriptor width" {
  let generated = Archive::new()
  generated.add("target.xml", b"old", compression=Deflate, data_descriptor=true)
  let source = write_with_options(generated, force_zip64=true)
  let before = read(source)
  let archive = read(source)
  assert_true(archive.replace("target.xml", b"new zip64 payload"))
  assert_false(preserved_entry(archive, "target.xml").source_unchanged)
  let candidate = write(archive)
  assert_eq(
    write_limited(archive, max_output_bytes=candidate.length()),
    candidate,
  )
  try write_limited(archive, max_output_bytes=candidate.length() - 1) catch {
    OutputLimitExceeded(limit~) => assert_eq(limit, candidate.length() - 1)
    _ => fail("expected bounded ZIP64 output limit")
  } noraise {
    _ => fail("expected ZIP64 candidate to exceed its output limit")
  }
  let after = read(candidate)
  let original = preserved_entry(before, "target.xml")
  let replacement = preserved_entry(after, "target.xml")
  guard original.source is Some(original_template) else {
    fail("expected original ZIP64 replacement template")
  }
  guard replacement.source is Some(replacement_template) else {
    fail("expected replacement ZIP64 template")
  }
  assert_true(original_template.descriptor_signed)
  assert_true(original_template.descriptor_zip64)
  assert_true(replacement_template.descriptor_signed)
  assert_true(replacement_template.descriptor_zip64)
  assert_eq(
    replacement_template.local_record[:14],
    original_template.local_record[:14],
  )
  assert_true(
    original_template.local_header_length <
    original_template.local_record.length(),
  )
  assert_eq(
    replacement_template.local_header_length,
    original_template.local_header_length,
  )
  assert_eq(
    replacement_template.central_record[4:16],
    original_template.central_record[4:16],
  )
  assert_eq(
    replacement_template.central_record[28:42],
    original_template.central_record[28:42],
  )
  assert_eq(
    replacement_template.central_record[46:60],
    original_template.central_record[46:60],
  )
  assert_eq(
    replacement_template.central_record.length(),
    original_template.central_record.length(),
  )
  assert_eq(
    replacement_template.central_zip64_uncompressed_position,
    original_template.central_zip64_uncompressed_position,
  )
  assert_eq(
    replacement_template.central_zip64_compressed_position,
    original_template.central_zip64_compressed_position,
  )
  assert_eq(
    replacement_template.central_zip64_offset_position,
    original_template.central_zip64_offset_position,
  )
}

///|
fn entry_zip64_classic_eocd_fixture() -> Bytes raise ZipError {
  let archive = Archive::new()
  archive.add("target.xml", b"old", compression=Deflate, data_descriptor=true)
  let generated = write_with_options(archive, force_zip64=true)
  guard find_end_of_central(generated) is Some(eocd_offset) else {
    raise UnsupportedFeature(msg="expected generated ZIP64 end record")
  }
  let locator_offset = eocd_offset - 20
  let zip64_offset = u64_to_int(read_u64_le_at(generated, locator_offset + 8))
  let total_entries = u64_to_int(read_u64_le_at(generated, zip64_offset + 32))
  let central_size = u64_to_int(read_u64_le_at(generated, zip64_offset + 40))
  let central_offset = u64_to_int(read_u64_le_at(generated, zip64_offset + 48))
  let comment = b"entry-zip64-classic-eocd"
  let output : Array[Byte] = []
  write_bytes(output, generated[:zip64_offset])
  write_u32_le(output, end_of_central_sig.reinterpret_as_uint())
  write_u16_le(output, 0)
  write_u16_le(output, 0)
  write_u16_le(output, total_entries)
  write_u16_le(output, total_entries)
  write_u32_le(output, to_u32(central_size))
  write_u32_le(output, to_u32(central_offset))
  write_u16_le(output, comment.length())
  write_bytes(output, comment)
  Bytes::from_array(output)
}

///|
test "entry ZIP64 replacement preserves a classic archive trailer" {
  let source = entry_zip64_classic_eocd_fixture()
  let before = read(source)
  assert_true(before.zip64_trailer is None)
  assert_eq(before.comment, b"entry-zip64-classic-eocd")
  assert_eq(write(before), source)
  guard preserved_entry(before, "target.xml").source is Some(original) else {
    fail("expected source entry template")
  }
  assert_true(original.descriptor_zip64)

  let archive = read(source)
  assert_true(archive.replace("target.xml", b"replacement payload"))
  let candidate = write(archive)
  let after = read(candidate)
  assert_true(after.zip64_trailer is None)
  assert_eq(after.comment, b"entry-zip64-classic-eocd")
  assert_eq(after.get("target.xml"), Some(b"replacement payload"))
  guard preserved_entry(after, "target.xml").source is Some(replacement) else {
    fail("expected replacement entry template")
  }
  assert_true(replacement.descriptor_zip64)
  assert_eq(
    replacement.local_zip64_uncompressed_position,
    original.local_zip64_uncompressed_position,
  )
  assert_eq(
    replacement.local_zip64_compressed_position,
    original.local_zip64_compressed_position,
  )
  assert_eq(
    replacement.central_zip64_uncompressed_position,
    original.central_zip64_uncompressed_position,
  )
  assert_eq(
    replacement.central_zip64_compressed_position,
    original.central_zip64_compressed_position,
  )
  guard find_end_of_central(candidate) is Some(candidate_eocd) else {
    fail("replacement lost the classic end record")
  }
  assert_eq(read_u16_le_at(candidate, candidate_eocd + 10), 1)
  assert_true(
    read_u32_le_at_raw(candidate, candidate_eocd + 12) != (0xffffffff : UInt),
  )
  assert_true(
    read_u32_le_at_raw(candidate, candidate_eocd + 16) != (0xffffffff : UInt),
  )
}

///|
fn customized_zip64_fixture() -> Bytes raise ZipError {
  let archive = Archive::new()
  archive.add("target.xml", b"old", compression=Deflate, data_descriptor=true)
  let generated = write_with_options(archive, force_zip64=true)
  guard find_end_of_central(generated) is Some(eocd_offset) else {
    raise UnsupportedFeature(msg="expected generated ZIP64 end record")
  }
  let locator_offset = eocd_offset - 20
  let zip64_offset = u64_to_int(read_u64_le_at(generated, locator_offset + 8))
  let extensible_sector = b"\xde\xad\xbe\xef\x10\x20\x30"
  let comment = b"custom-zip64-comment"
  let output : Array[Byte] = []
  write_bytes(output, generated[:zip64_offset])

  let end_record = generated[zip64_offset:locator_offset].to_array()
  patch_u64_le(end_record, 4, to_u64(44 + extensible_sector.length()))
  // Deliberately retain producer-specific version values.
  patch_u16_le(end_record, 12, 63)
  patch_u16_le(end_record, 14, 46)
  write_bytes(output, Bytes::from_array(end_record))
  write_bytes(output, extensible_sector)
  write_bytes(output, generated[locator_offset:eocd_offset])

  let classic = generated[eocd_offset:eocd_offset + 22].to_array()
  let central_size = u64_to_int(read_u64_le_at(generated, zip64_offset + 40))
  // Exercise a mixed ZIP32/ZIP64 sentinel policy: one concrete and one
  // sentinel count field, plus one concrete and one sentinel central field.
  patch_u16_le(classic, 8, 1)
  patch_u32_le(classic, 12, to_u32(central_size))
  patch_u16_le(classic, 20, comment.length())
  write_bytes(output, Bytes::from_array(classic))
  write_bytes(output, comment)
  Bytes::from_array(output)
}

///|
test "zip64 trailer preserves versions extensible data and mixed sentinels" {
  let source = customized_zip64_fixture()
  let source_archive = read(source)
  assert_eq(write(source_archive), source)
  assert_eq(source_archive.comment, b"custom-zip64-comment")
  guard source_archive.zip64_trailer is Some(source_trailer) else {
    fail("expected source ZIP64 trailer")
  }
  assert_eq(read_u16_le_at(source_trailer.end_record, 12), 63)
  assert_eq(read_u16_le_at(source_trailer.end_record, 14), 46)
  assert_eq(source_trailer.end_record[56:], b"\xde\xad\xbe\xef\x10\x20\x30")
  assert_eq(read_u16_le_at(source_trailer.classic_end_record, 8), 1)
  assert_eq(read_u16_le_at(source_trailer.classic_end_record, 10), 0xffff)
  assert_true(
    read_u32_le_at_raw(source_trailer.classic_end_record, 12) !=
    (0xffffffff : UInt),
  )
  assert_eq(
    read_u32_le_at_raw(source_trailer.classic_end_record, 16),
    (0xffffffff : UInt),
  )

  assert_true(
    source_archive.replace("target.xml", b"longer replacement payload"),
  )
  let candidate = write(source_archive)
  let candidate_archive = read(candidate)
  assert_eq(
    candidate_archive.get("target.xml"),
    Some(b"longer replacement payload"),
  )
  assert_eq(candidate_archive.comment, b"custom-zip64-comment")
  guard candidate_archive.zip64_trailer is Some(candidate_trailer) else {
    fail("expected candidate ZIP64 trailer")
  }
  assert_eq(
    candidate_trailer.end_record[12:24],
    source_trailer.end_record[12:24],
  )
  assert_eq(candidate_trailer.end_record[56:], source_trailer.end_record[56:])
  assert_eq(candidate_trailer.locator[4:8], source_trailer.locator[4:8])
  assert_eq(candidate_trailer.locator[16:20], source_trailer.locator[16:20])
  assert_eq(read_u16_le_at(candidate_trailer.classic_end_record, 8), 1)
  assert_eq(read_u16_le_at(candidate_trailer.classic_end_record, 10), 0xffff)
  assert_true(
    read_u32_le_at_raw(candidate_trailer.classic_end_record, 12) !=
    (0xffffffff : UInt),
  )
  assert_eq(
    read_u32_le_at_raw(candidate_trailer.classic_end_record, 16),
    (0xffffffff : UInt),
  )
  assert_eq(candidate_trailer.classic_end_record[22:], b"custom-zip64-comment")
}

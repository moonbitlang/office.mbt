///|
test "zip write data descriptor" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello", data_descriptor=true)
  let bytes = write(archive)
  let flags = read_u16_le_at(bytes, 6)
  inspect((flags & flag_data_descriptor) != 0, content="true")
  let crc_local = read_u32_le_at_raw(bytes, 14)
  let comp_local = read_u32_le_at_raw(bytes, 18)
  let uncomp_local = read_u32_le_at_raw(bytes, 22)
  let zero_u32 : UInt = 0
  inspect(crc_local == zero_u32, content="true")
  inspect(comp_local == zero_u32, content="true")
  inspect(uncomp_local == zero_u32, content="true")
  let name_len = read_u16_le_at(bytes, 26)
  let extra_len = read_u16_le_at(bytes, 28)
  let data_offset = 30 + name_len + extra_len
  let data_len = b"hello".length()
  let descriptor_offset = data_offset + data_len
  let sig = read_u32_le_at_raw(bytes, descriptor_offset)
  inspect(sig == data_descriptor_sig.reinterpret_as_uint(), content="true")
  let crc_value = read_u32_le_at_raw(bytes, descriptor_offset + 4)
  let expected_crc = crc32(b"hello")
  inspect(crc_value == expected_crc, content="true")
  let comp_size = read_u32_le_at_raw(bytes, descriptor_offset + 8)
  let uncomp_size = read_u32_le_at_raw(bytes, descriptor_offset + 12)
  let len_u32 : UInt = data_len.reinterpret_as_uint()
  inspect(comp_size == len_u32, content="true")
  inspect(uncomp_size == len_u32, content="true")
  let parsed = read(bytes)
  inspect(parsed.get("a.txt"), content="Some(b\"hello\")")
}

///|
test "zip write zip64 structures" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let bytes = write_with_options(archive, force_zip64=true)
  let parsed = read(bytes)
  inspect(parsed.get("a.txt"), content="Some(b\"hello\")")
  let name_len = read_u16_le_at(bytes, 26)
  let extra_len = read_u16_le_at(bytes, 28)
  let extra_offset = 30 + name_len
  let zip64_id = read_u16_le_at(bytes, extra_offset)
  let zip64_size = read_u16_le_at(bytes, extra_offset + 2)
  inspect(zip64_id == 0x0001, content="true")
  inspect(extra_len == 20, content="true")
  inspect(zip64_size == 16, content="true")
  let max_u32 : UInt = 0xFFFFFFFF
  let comp_local = read_u32_le_at_raw(bytes, 18)
  let uncomp_local = read_u32_le_at_raw(bytes, 22)
  inspect(comp_local == max_u32, content="true")
  inspect(uncomp_local == max_u32, content="true")
  let eocd_offset = match find_end_of_central(bytes) {
    Some(offset) => offset
    None => fail("missing end of central directory")
  }
  let locator_offset = eocd_offset - 20
  let locator_sig = read_u32_le_at_raw(bytes, locator_offset)
  inspect(
    locator_sig == zip64_locator_sig.reinterpret_as_uint(),
    content="true",
  )
  let zip64_offset = read_u64_le_at(bytes, locator_offset + 8)
  let zip64_sig = read_u32_le_at_raw(bytes, zip64_offset.to_int())
  inspect(zip64_sig == zip64_eocd_sig.reinterpret_as_uint(), content="true")
}

///|
test "zip writer wb: helper guard and zip64 descriptor branches" {
  let out : Array[Byte] = []
  try write_u16_le(out, -1) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected write_u16_le to raise")
  }
  try to_u32(-1) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected to_u32 to raise")
  }
  try to_u64(-1) catch {
    e => inspect(e is ZipError::UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected to_u64 to raise")
  }

  let offset_only = build_zip64_extra(uncomp=None, comp=None, offset=Some(7))
  inspect(offset_only.length(), content="12")

  let descriptor : Array[Byte] = []
  write_data_descriptor(
    descriptor,
    (0x01020304).reinterpret_as_uint(),
    5,
    6,
    true,
  )
  let desc_bytes = Bytes::from_array(descriptor)
  inspect(desc_bytes.length(), content="24")
  inspect(
    read_u32_le_at_raw(desc_bytes, 0) ==
    data_descriptor_sig.reinterpret_as_uint(),
    content="true",
  )
  inspect(read_u64_le_at(desc_bytes, 8), content="5")
  inspect(read_u64_le_at(desc_bytes, 16), content="6")
}

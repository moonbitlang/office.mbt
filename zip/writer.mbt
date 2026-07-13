///|
fn write_u16_le(buf : Array[Byte], value : Int) -> Unit raise ZipError {
  if value < 0 || value > 0xFFFF {
    raise UnsupportedFeature(msg="u16 overflow")
  }
  let v = value.reinterpret_as_uint()
  buf.push((v & 0xFF).to_byte())
  buf.push(((v >> 8) & 0xFF).to_byte())
}

///|
fn write_u32_le(buf : Array[Byte], value : UInt) -> Unit {
  let v = value
  buf.push((v & 0xFF).to_byte())
  buf.push(((v >> 8) & 0xFF).to_byte())
  buf.push(((v >> 16) & 0xFF).to_byte())
  buf.push(((v >> 24) & 0xFF).to_byte())
}

///|
fn write_bytes(buf : Array[Byte], bytes : BytesView) -> Unit {
  for b in bytes {
    buf.push(b)
  }
}

///|
fn write_u64_le(buf : Array[Byte], value : UInt64) -> Unit {
  for i in 0..<8 {
    buf.push(((value >> (8 * i)) & 0xff).to_byte())
  }
}

///|
fn to_u32(value : Int) -> UInt raise ZipError {
  if value < 0 {
    raise UnsupportedFeature(msg="u32 exceeds Int range")
  }
  value.reinterpret_as_uint()
}

///|
fn to_u64(value : Int) -> UInt64 raise ZipError {
  if value < 0 {
    raise UnsupportedFeature(msg="u64 exceeds Int range")
  }
  UInt64::extend_uint(value.reinterpret_as_uint())
}

///|
fn build_zip64_extra(
  uncomp~ : Int?,
  comp~ : Int?,
  offset~ : Int?,
) -> Bytes raise ZipError {
  let mut field_count = 0
  if uncomp is Some(_) {
    field_count = field_count + 1
  }
  if comp is Some(_) {
    field_count = field_count + 1
  }
  if offset is Some(_) {
    field_count = field_count + 1
  }
  if field_count == 0 {
    return b""
  }
  let data_len = 8 * field_count
  let extra : Array[Byte] = Array::new(capacity=4 + data_len)
  write_u16_le(extra, 0x0001)
  write_u16_le(extra, data_len)
  match uncomp {
    Some(value) => write_u64_le(extra, to_u64(value))
    None => ()
  }
  match comp {
    Some(value) => write_u64_le(extra, to_u64(value))
    None => ()
  }
  match offset {
    Some(value) => write_u64_le(extra, to_u64(value))
    None => ()
  }
  Bytes::from_array(extra)
}

///|
fn write_data_descriptor(
  buf : Array[Byte],
  crc : UInt,
  comp_size : Int,
  uncomp_size : Int,
  zip64_sizes : Bool,
) -> Unit raise ZipError {
  write_u32_le(buf, data_descriptor_sig.reinterpret_as_uint())
  write_u32_le(buf, crc)
  if zip64_sizes {
    write_u64_le(buf, to_u64(comp_size))
    write_u64_le(buf, to_u64(uncomp_size))
  } else {
    write_u32_le(buf, to_u32(comp_size))
    write_u32_le(buf, to_u32(uncomp_size))
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
fn generated_entry_records(
  out : Array[Byte],
  entry : Entry,
  local_offset : Int,
  force_zip64 : Bool,
) -> (Bytes, Bool) raise ZipError {
  let (method_id, payload) = match entry.compression() {
    Store => (0, entry.data())
    Deflate => (8, deflate_encode(entry.data()))
  }
  let name_bytes = @encoding/utf8.encode(entry.name())
  let name_len = name_bytes.length()
  let data_len = entry.data().length()
  let payload_len = payload.length()
  if name_len > 0xFFFF {
    raise UnsupportedFeature(msg="file name too long")
  }
  let crc = crc32(entry.data())
  let use_descriptor = entry.data_descriptor()
  let max_u32 : UInt = 0xFFFFFFFF
  let needs_zip64_sizes = force_zip64 ||
    data_len.reinterpret_as_uint() > max_u32 ||
    payload_len.reinterpret_as_uint() > max_u32
  let needs_zip64_offset = force_zip64 ||
    local_offset.reinterpret_as_uint() > max_u32
  let needs_zip64_entry = needs_zip64_sizes || needs_zip64_offset
  let version = if needs_zip64_entry { 45 } else { 20 }
  let flags = if use_descriptor {
    flag_utf8 | flag_data_descriptor
  } else {
    flag_utf8
  }
  let local_extra = build_zip64_extra(
    uncomp=if needs_zip64_sizes { Some(data_len) } else { None },
    comp=if needs_zip64_sizes { Some(payload_len) } else { None },
    offset=None,
  )
  write_u32_le(out, local_header_sig.reinterpret_as_uint())
  write_u16_le(out, version)
  write_u16_le(out, flags)
  write_u16_le(out, method_id)
  write_u16_le(out, 0)
  write_u16_le(out, 0)
  if use_descriptor {
    write_u32_le(out, 0)
    let size_field = if needs_zip64_sizes { max_u32 } else { 0 }
    write_u32_le(out, size_field)
    write_u32_le(out, size_field)
  } else {
    write_u32_le(out, crc)
    let comp_field = if needs_zip64_sizes {
      max_u32
    } else {
      to_u32(payload_len)
    }
    let uncomp_field = if needs_zip64_sizes {
      max_u32
    } else {
      to_u32(data_len)
    }
    write_u32_le(out, comp_field)
    write_u32_le(out, uncomp_field)
  }
  write_u16_le(out, name_len)
  write_u16_le(out, local_extra.length())
  write_bytes(out, name_bytes)
  write_bytes(out, local_extra)
  write_bytes(out, payload)
  if use_descriptor {
    write_data_descriptor(out, crc, payload_len, data_len, needs_zip64_sizes)
  }
  let central_extra = build_zip64_extra(
    uncomp=if needs_zip64_sizes { Some(data_len) } else { None },
    comp=if needs_zip64_sizes { Some(payload_len) } else { None },
    offset=if needs_zip64_offset { Some(local_offset) } else { None },
  )
  let central : Array[Byte] = []
  write_u32_le(central, central_header_sig.reinterpret_as_uint())
  write_u16_le(central, version)
  write_u16_le(central, version)
  write_u16_le(central, flags)
  write_u16_le(central, method_id)
  write_u16_le(central, 0)
  write_u16_le(central, 0)
  write_u32_le(central, crc)
  let central_comp = if needs_zip64_sizes {
    max_u32
  } else {
    to_u32(payload_len)
  }
  let central_uncomp = if needs_zip64_sizes {
    max_u32
  } else {
    to_u32(data_len)
  }
  write_u32_le(central, central_comp)
  write_u32_le(central, central_uncomp)
  write_u16_le(central, name_len)
  write_u16_le(central, central_extra.length())
  write_u16_le(central, 0)
  write_u16_le(central, 0)
  write_u16_le(central, 0)
  write_u32_le(central, 0)
  let offset_field = if needs_zip64_offset {
    max_u32
  } else {
    to_u32(local_offset)
  }
  write_u32_le(central, offset_field)
  write_bytes(central, name_bytes)
  write_bytes(central, central_extra)
  (Bytes::from_array(central), needs_zip64_entry)
}

///|
fn archive_local_order(archive : Archive) -> Array[Int] {
  let order = []
  for index in 0..<archive.entries.length() {
    order.push(index)
  }
  order.sort_by(fn(left, right) {
    match
      (
        archive.entries[left].source_local_offset,
        archive.entries[right].source_local_offset,
      ) {
      (Some(left_offset), Some(right_offset)) =>
        left_offset.compare(right_offset)
      (Some(_), None) => -1
      (None, Some(_)) => 1
      (None, None) => left.compare(right)
    }
  })
  order
}

///|
fn write_with_options(
  archive : Archive,
  force_zip64? : Bool = false,
) -> Bytes raise ZipError {
  let entry_count = archive.entries().length()
  let out : Array[Byte] = Array::new(capacity=entry_count * 64)
  let central : Array[Byte] = Array::new(capacity=entry_count * 64)
  let local_offsets : Array[Int] = []
  let generated_central : Array[Bytes?] = []
  for _ in 0..<entry_count {
    local_offsets.push(0)
    generated_central.push(None)
  }
  let mut needs_zip64 = force_zip64 || archive.preserve_zip64
  let max_u32 : UInt = 0xFFFFFFFF
  for index in archive_local_order(archive) {
    let entry = archive.entries[index]
    let local_offset = out.length()
    local_offsets[index] = local_offset
    match entry.preserved {
      Some(source) => write_bytes(out, source.local_record)
      None => {
        let (record, entry_needs_zip64) = generated_entry_records(
          out, entry, local_offset, force_zip64,
        )
        generated_central[index] = Some(record)
        if entry_needs_zip64 {
          needs_zip64 = true
        }
      }
    }
  }
  for index in 0..<entry_count {
    let entry = archive.entries[index]
    match entry.preserved {
      Some(source) => {
        let record = source.central_record.to_array()
        match source.zip64_offset_position {
          Some(position) =>
            patch_u64_le(record, position, to_u64(local_offsets[index]))
          None => patch_u32_le(record, 42, to_u32(local_offsets[index]))
        }
        write_bytes(central, Bytes::from_array(record))
      }
      None =>
        match generated_central[index] {
          Some(record) => write_bytes(central, record)
          None =>
            raise UnsupportedFeature(
              msg="generated central-directory record is missing",
            )
        }
    }
  }
  let central_offset = out.length()
  for b in central {
    out.push(b)
  }
  let central_size = central.length()
  let total_entries = entry_count
  if force_zip64 ||
    central_offset.reinterpret_as_uint() > max_u32 ||
    central_size.reinterpret_as_uint() > max_u32 ||
    total_entries > 0xFFFF {
    needs_zip64 = true
  }
  if needs_zip64 {
    let zip64_offset = out.length()
    write_u32_le(out, zip64_eocd_sig.reinterpret_as_uint())
    write_u64_le(out, to_u64(44))
    write_u16_le(out, 45)
    write_u16_le(out, 45)
    write_u32_le(out, 0)
    write_u32_le(out, 0)
    let entry_count = to_u64(total_entries)
    write_u64_le(out, entry_count)
    write_u64_le(out, entry_count)
    write_u64_le(out, to_u64(central_size))
    write_u64_le(out, to_u64(central_offset))
    write_u32_le(out, zip64_locator_sig.reinterpret_as_uint())
    write_u32_le(out, 0)
    write_u64_le(out, to_u64(zip64_offset))
    write_u32_le(out, 1)
  }
  write_u32_le(out, end_of_central_sig.reinterpret_as_uint())
  write_u16_le(out, 0)
  write_u16_le(out, 0)
  if needs_zip64 {
    write_u16_le(out, 0xFFFF)
    write_u16_le(out, 0xFFFF)
    write_u32_le(out, max_u32)
    write_u32_le(out, max_u32)
  } else {
    write_u16_le(out, total_entries)
    write_u16_le(out, total_entries)
    write_u32_le(out, to_u32(central_size))
    write_u32_le(out, to_u32(central_offset))
  }
  if archive.comment.length() > 0xffff {
    raise UnsupportedFeature(msg="archive comment too long")
  }
  write_u16_le(out, archive.comment.length())
  write_bytes(out, archive.comment)
  Bytes::from_array(out)
}

///|
pub fn write(archive : Archive) -> Bytes raise ZipError {
  write_with_options(archive)
}

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
  inspect(parsed.get("a.txt") == Some(b"hello"), content="true")
}

///|
test "zip write zip64 structures" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  let bytes = write_with_options(archive, force_zip64=true)
  let parsed = read(bytes)
  inspect(parsed.get("a.txt") == Some(b"hello"), content="true")
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
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected write_u16_le to raise")
  }
  try to_u32(-1) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected to_u32 to raise")
  }
  try to_u64(-1) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
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

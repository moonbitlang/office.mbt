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
fn patch_classic_u16_preserving_sentinel(
  record : Array[Byte],
  template : BytesView,
  offset : Int,
  value : Int,
) -> Unit raise ZipError {
  let original = read_u16_le_at(template, offset)
  if original != 0xffff {
    patch_u16_le(record, offset, if value > 0xffff { 0xffff } else { value })
  }
}

///|
fn patch_classic_u32_preserving_sentinel(
  record : Array[Byte],
  template : BytesView,
  offset : Int,
  value : Int,
) -> Unit raise ZipError {
  let max_u32 : UInt = 0xffffffff
  if read_u32_le_at_raw(template, offset) != max_u32 {
    let patched = if value < 0 || value.reinterpret_as_uint() > max_u32 {
      max_u32
    } else {
      to_u32(value)
    }
    patch_u32_le(record, offset, patched)
  }
}

///|
fn patch_template_size(
  record : Array[Byte],
  classic_position : Int,
  zip64_position : Int?,
  value : Int,
  preserve_zero_placeholder : Bool,
) -> Unit raise ZipError {
  let raw = read_u32_le_at_raw(Bytes::from_array(record), classic_position)
  let max_u32 : UInt = 0xFFFFFFFF
  match zip64_position {
    Some(position) => patch_u64_le(record, position, to_u64(value))
    None if raw == max_u32 =>
      raise UnsupportedFeature(
        msg="ZIP64 size field is missing from replacement template",
      )
    None => ()
  }
  if raw == max_u32 {
    return
  }
  let zero : UInt = 0
  if preserve_zero_placeholder && raw == zero {
    return
  }
  patch_u32_le(record, classic_position, to_u32(value))
}

///|
fn replacement_entry_records(
  out : Array[Byte],
  entry : Entry,
  local_offset : Int,
  template : SourceEntryTemplate,
) -> Bytes raise ZipError {
  let (method_id, payload) = match entry.compression() {
    Store => (0, entry.data())
    Deflate => (8, deflate_encode(entry.data()))
  }
  if template.local_header_length < 30 ||
    template.local_header_length > template.local_record.length() ||
    template.central_record.length() < 46 ||
    read_u32_le_at_raw(template.local_record, 0) !=
    local_header_sig.reinterpret_as_uint() ||
    read_u32_le_at_raw(template.central_record, 0) !=
    central_header_sig.reinterpret_as_uint() {
    raise UnsupportedFeature(msg="replacement ZIP header template is malformed")
  }
  let local_header = template.local_record[:template.local_header_length]
  let local_method = read_u16_le_at(local_header, 8)
  let central_method = read_u16_le_at(template.central_record, 10)
  let local_flags = read_u16_le_at(local_header, 6)
  let central_flags = read_u16_le_at(template.central_record, 8)
  let uses_descriptor = (local_flags & flag_data_descriptor) != 0
  if local_method != method_id ||
    central_method != method_id ||
    local_flags != central_flags ||
    uses_descriptor != entry.data_descriptor() {
    raise UnsupportedFeature(
      msg="replacement ZIP header policy changed unexpectedly",
    )
  }
  let crc = crc32(entry.data())
  let data_len = entry.data().length()
  let payload_len = payload.length()
  let local_record = local_header.to_array()
  let local_crc = read_u32_le_at_raw(local_header, 14)
  let zero : UInt = 0
  if !uses_descriptor || local_crc != zero {
    patch_u32_le(local_record, 14, crc)
  }
  patch_template_size(
    local_record,
    18,
    template.local_zip64_compressed_position,
    payload_len,
    uses_descriptor,
  )
  patch_template_size(
    local_record,
    22,
    template.local_zip64_uncompressed_position,
    data_len,
    uses_descriptor,
  )
  write_bytes(out, Bytes::from_array(local_record))
  write_bytes(out, payload)
  if uses_descriptor {
    if template.descriptor_signed {
      write_u32_le(out, data_descriptor_sig.reinterpret_as_uint())
    }
    write_u32_le(out, crc)
    if template.descriptor_zip64 {
      write_u64_le(out, to_u64(payload_len))
      write_u64_le(out, to_u64(data_len))
    } else {
      write_u32_le(out, to_u32(payload_len))
      write_u32_le(out, to_u32(data_len))
    }
  }
  let central = template.central_record.to_array()
  patch_u32_le(central, 16, crc)
  patch_template_size(
    central,
    20,
    template.central_zip64_compressed_position,
    payload_len,
    false,
  )
  patch_template_size(
    central,
    24,
    template.central_zip64_uncompressed_position,
    data_len,
    false,
  )
  match template.central_zip64_offset_position {
    Some(position) => patch_u64_le(central, position, to_u64(local_offset))
    None => patch_u32_le(central, 42, to_u32(local_offset))
  }
  Bytes::from_array(central)
}

///|
fn generated_entry_records(
  out : Array[Byte],
  entry : Entry,
  local_offset : Int,
  force_zip64 : Bool,
) -> Bytes raise ZipError {
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
  Bytes::from_array(central)
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
fn write_preserved_zip64_trailer(
  out : Array[Byte],
  template : Zip64TrailerTemplate,
  total_entries : Int,
  central_size : Int,
  central_offset : Int,
) -> Unit raise ZipError {
  if template.end_record.length() < 56 ||
    template.locator.length() != 20 ||
    template.classic_end_record.length() < 22 ||
    read_u32_le_at_raw(template.end_record, 0) !=
    zip64_eocd_sig.reinterpret_as_uint() ||
    read_u32_le_at_raw(template.locator, 0) !=
    zip64_locator_sig.reinterpret_as_uint() ||
    read_u32_le_at_raw(template.classic_end_record, 0) !=
    end_of_central_sig.reinterpret_as_uint() ||
    read_u16_le_at(template.classic_end_record, 20) !=
    template.classic_end_record.length() - 22 {
    raise UnsupportedFeature(
      msg="preserved ZIP64 trailer template is malformed",
    )
  }
  let zip64_offset = out.length()
  let end_record = template.end_record.to_array()
  let count = to_u64(total_entries)
  patch_u64_le(end_record, 24, count)
  patch_u64_le(end_record, 32, count)
  patch_u64_le(end_record, 40, to_u64(central_size))
  patch_u64_le(end_record, 48, to_u64(central_offset))
  write_bytes(out, Bytes::from_array(end_record))

  let locator = template.locator.to_array()
  patch_u64_le(locator, 8, to_u64(zip64_offset))
  write_bytes(out, Bytes::from_array(locator))

  let classic = template.classic_end_record.to_array()
  patch_classic_u16_preserving_sentinel(
    classic,
    template.classic_end_record,
    8,
    total_entries,
  )
  patch_classic_u16_preserving_sentinel(
    classic,
    template.classic_end_record,
    10,
    total_entries,
  )
  patch_classic_u32_preserving_sentinel(
    classic,
    template.classic_end_record,
    12,
    central_size,
  )
  patch_classic_u32_preserving_sentinel(
    classic,
    template.classic_end_record,
    16,
    central_offset,
  )
  write_bytes(out, Bytes::from_array(classic))
}

///|
fn write_generated_zip64_records(
  out : Array[Byte],
  total_entries : Int,
  central_size : Int,
  central_offset : Int,
) -> Unit raise ZipError {
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

///|
fn write_generated_classic_end_record(
  out : Array[Byte],
  zip64 : Bool,
  total_entries : Int,
  central_size : Int,
  central_offset : Int,
  comment : Bytes,
) -> Unit raise ZipError {
  let max_u32 : UInt = 0xffffffff
  write_u32_le(out, end_of_central_sig.reinterpret_as_uint())
  write_u16_le(out, 0)
  write_u16_le(out, 0)
  if zip64 {
    write_u16_le(out, 0xffff)
    write_u16_le(out, 0xffff)
    write_u32_le(out, max_u32)
    write_u32_le(out, max_u32)
  } else {
    write_u16_le(out, total_entries)
    write_u16_le(out, total_entries)
    write_u32_le(out, to_u32(central_size))
    write_u32_le(out, to_u32(central_offset))
  }
  if comment.length() > 0xffff {
    raise UnsupportedFeature(msg="archive comment too long")
  }
  write_u16_le(out, comment.length())
  write_bytes(out, comment)
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
  // Per-entry ZIP64 fields do not require an archive-wide ZIP64 trailer when
  // the classic EOCD's own counts, central size, and central offset all fit.
  // Preserve a source trailer when present, and generate one only for those
  // archive-wide fields (or an explicit force request).
  let mut needs_zip64_trailer = force_zip64 || archive.zip64_trailer is Some(_)
  let max_u32 : UInt = 0xFFFFFFFF
  for index in archive_local_order(archive) {
    let entry = archive.entries[index]
    let local_offset = out.length()
    local_offsets[index] = local_offset
    match (entry.source, entry.source_unchanged) {
      (Some(source), true) => write_bytes(out, source.local_record)
      (source, _) => {
        let record = match source {
          Some(template) =>
            replacement_entry_records(out, entry, local_offset, template)
          None => generated_entry_records(out, entry, local_offset, force_zip64)
        }
        generated_central[index] = Some(record)
      }
    }
  }
  for index in 0..<entry_count {
    let entry = archive.entries[index]
    match (entry.source, entry.source_unchanged) {
      (Some(source), true) => {
        let record = source.central_record.to_array()
        match source.central_zip64_offset_position {
          Some(position) =>
            patch_u64_le(record, position, to_u64(local_offsets[index]))
          None => patch_u32_le(record, 42, to_u32(local_offsets[index]))
        }
        write_bytes(central, Bytes::from_array(record))
      }
      _ =>
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
    needs_zip64_trailer = true
  }
  match (needs_zip64_trailer, archive.zip64_trailer) {
    (true, Some(template)) =>
      write_preserved_zip64_trailer(
        out, template, total_entries, central_size, central_offset,
      )
    (true, None) => {
      write_generated_zip64_records(
        out, total_entries, central_size, central_offset,
      )
      write_generated_classic_end_record(
        out,
        true,
        total_entries,
        central_size,
        central_offset,
        archive.comment,
      )
    }
    (false, _) =>
      write_generated_classic_end_record(
        out,
        false,
        total_entries,
        central_size,
        central_offset,
        archive.comment,
      )
  }
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

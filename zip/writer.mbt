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
fn write_with_options(
  archive : Archive,
  force_zip64? : Bool = false,
) -> Bytes raise ZipError {
  let entry_count = archive.entries().length()
  let out : Array[Byte] = Array::new(capacity=entry_count * 64)
  let central : Array[Byte] = Array::new(capacity=entry_count * 64)
  let mut needs_zip64 = force_zip64
  let max_u32 : UInt = 0xFFFFFFFF
  for entry in archive.entries() {
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
    let local_offset = out.length()
    let crc = crc32(entry.data())
    let use_descriptor = entry.data_descriptor()
    let needs_zip64_sizes = force_zip64 ||
      data_len.reinterpret_as_uint() > max_u32 ||
      payload_len.reinterpret_as_uint() > max_u32
    let needs_zip64_offset = force_zip64 ||
      local_offset.reinterpret_as_uint() > max_u32
    let needs_zip64_entry = needs_zip64_sizes || needs_zip64_offset
    if needs_zip64_entry {
      needs_zip64 = true
    }
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
  write_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
pub fn write(archive : Archive) -> Bytes raise ZipError {
  write_with_options(archive)
}

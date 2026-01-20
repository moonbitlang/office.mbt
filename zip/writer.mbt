///|
fn write_u16_le(buf : Array[Byte], value : Int) -> Unit raise ZipError {
  if value < 0 || value > 0xFFFF {
    raise ZipError::UnsupportedFeature(msg="u16 overflow")
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
fn to_u32(value : Int) -> UInt raise ZipError {
  if value < 0 {
    raise ZipError::UnsupportedFeature(msg="u32 exceeds Int range")
  }
  value.reinterpret_as_uint()
}

///|
pub fn write(archive : Archive) -> Bytes raise ZipError {
  let out : Array[Byte] = []
  let central : Array[Byte] = []
  for entry in archive.entries() {
    let (method_id, payload) = match entry.compression {
      Store => (0, entry.data)
      Deflate => (8, deflate_encode(entry.data))
    }
    let name_bytes = @encoding/utf8.encode(entry.name)
    let name_len = name_bytes.length()
    let data_len = entry.data.length()
    let payload_len = payload.length()
    if name_len > 0xFFFF {
      raise ZipError::UnsupportedFeature(msg="file name too long")
    }
    let local_offset = out.length()
    let crc = crc32(entry.data)
    write_u32_le(out, local_header_sig.reinterpret_as_uint())
    write_u16_le(out, 20)
    write_u16_le(out, flag_utf8)
    write_u16_le(out, method_id)
    write_u16_le(out, 0)
    write_u16_le(out, 0)
    write_u32_le(out, crc)
    write_u32_le(out, to_u32(payload_len))
    write_u32_le(out, to_u32(data_len))
    write_u16_le(out, name_len)
    write_u16_le(out, 0)
    write_bytes(out, name_bytes)
    write_bytes(out, payload)
    write_u32_le(central, central_header_sig.reinterpret_as_uint())
    write_u16_le(central, 20)
    write_u16_le(central, 20)
    write_u16_le(central, flag_utf8)
    write_u16_le(central, method_id)
    write_u16_le(central, 0)
    write_u16_le(central, 0)
    write_u32_le(central, crc)
    write_u32_le(central, to_u32(payload_len))
    write_u32_le(central, to_u32(data_len))
    write_u16_le(central, name_len)
    write_u16_le(central, 0)
    write_u16_le(central, 0)
    write_u16_le(central, 0)
    write_u16_le(central, 0)
    write_u32_le(central, 0)
    write_u32_le(central, to_u32(local_offset))
    write_bytes(central, name_bytes)
  }
  let central_offset = out.length()
  for b in central {
    out.push(b)
  }
  let central_size = central.length()
  let total_entries = archive.entries().length()
  write_u32_le(out, end_of_central_sig.reinterpret_as_uint())
  write_u16_le(out, 0)
  write_u16_le(out, 0)
  write_u16_le(out, total_entries)
  write_u16_le(out, total_entries)
  write_u32_le(out, to_u32(central_size))
  write_u32_le(out, to_u32(central_offset))
  write_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
fn push_u16_le(buf : Array[Byte], value : Int) -> Unit {
  let v = value.reinterpret_as_uint()
  buf.push((v & 0xFF).to_byte())
  buf.push(((v >> 8) & 0xFF).to_byte())
}

///|
fn push_u32_le(buf : Array[Byte], value : UInt) -> Unit {
  buf.push((value & 0xFF).to_byte())
  buf.push(((value >> 8) & 0xFF).to_byte())
  buf.push(((value >> 16) & 0xFF).to_byte())
  buf.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn push_u64_le(buf : Array[Byte], value : UInt64) -> Unit {
  for shift in [0, 8, 16, 24, 32, 40, 48, 56] {
    buf.push(((value >> shift).to_uint() & 0xFF).to_byte())
  }
}

///|
fn push_bytes(buf : Array[Byte], bytes : BytesView) -> Unit {
  for b in bytes {
    buf.push(b)
  }
}

///|
test "zip read data descriptor" {
  let name : Bytes = b"a.txt"
  let data : Bytes = b"hi"
  let crc = crc32(data)
  let buf : Array[Byte] = []
  // local header
  push_u32_le(buf, 0x04034B50)
  push_u16_le(buf, 20)
  push_u16_le(buf, 0x0808)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, 0)
  push_u16_le(buf, name.length())
  push_u16_le(buf, 0)
  push_bytes(buf, name)
  push_bytes(buf, data)
  // data descriptor
  push_u32_le(buf, 0x08074B50)
  push_u32_le(buf, crc)
  push_u32_le(buf, data.length().reinterpret_as_uint())
  push_u32_le(buf, data.length().reinterpret_as_uint())
  // central directory
  let central_offset = buf.length()
  push_u32_le(buf, 0x02014B50)
  push_u16_le(buf, 20)
  push_u16_le(buf, 20)
  push_u16_le(buf, 0x0808)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, crc)
  push_u32_le(buf, data.length().reinterpret_as_uint())
  push_u32_le(buf, data.length().reinterpret_as_uint())
  push_u16_le(buf, name.length())
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, 0)
  push_bytes(buf, name)
  // end of central directory
  let central_size = buf.length() - central_offset
  push_u32_le(buf, 0x06054B50)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 1)
  push_u16_le(buf, 1)
  push_u32_le(buf, central_size.reinterpret_as_uint())
  push_u32_le(buf, central_offset.reinterpret_as_uint())
  push_u16_le(buf, 0)
  let archive = read(Bytes::from_array(buf))
  inspect(archive.get("a.txt") == Some(b"hi"), content="true")
}

///|
test "zip read zip64 extra sizes" {
  let name : Bytes = b"b.txt"
  let data : Bytes = b"zip64"
  let crc = crc32(data)
  let buf : Array[Byte] = []
  // local header with zip64 extra
  push_u32_le(buf, 0x04034B50)
  push_u16_le(buf, 45)
  push_u16_le(buf, 0x0800)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, crc)
  push_u32_le(buf, 0xFFFFFFFF)
  push_u32_le(buf, 0xFFFFFFFF)
  push_u16_le(buf, name.length())
  push_u16_le(buf, 20)
  push_bytes(buf, name)
  // zip64 extra (uncomp, comp)
  push_u16_le(buf, 0x0001)
  push_u16_le(buf, 16)
  push_u64_le(buf, UInt64::extend_uint(data.length().reinterpret_as_uint()))
  push_u64_le(buf, UInt64::extend_uint(data.length().reinterpret_as_uint()))
  push_bytes(buf, data)
  // central directory with zip64 extra (uncomp, comp, offset)
  let central_offset = buf.length()
  push_u32_le(buf, 0x02014B50)
  push_u16_le(buf, 45)
  push_u16_le(buf, 45)
  push_u16_le(buf, 0x0800)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, crc)
  push_u32_le(buf, 0xFFFFFFFF)
  push_u32_le(buf, 0xFFFFFFFF)
  push_u16_le(buf, name.length())
  push_u16_le(buf, 28)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u32_le(buf, 0)
  push_u32_le(buf, 0xFFFFFFFF)
  push_bytes(buf, name)
  push_u16_le(buf, 0x0001)
  push_u16_le(buf, 24)
  push_u64_le(buf, UInt64::extend_uint(data.length().reinterpret_as_uint()))
  push_u64_le(buf, UInt64::extend_uint(data.length().reinterpret_as_uint()))
  push_u64_le(buf, UInt64::extend_uint(0))
  // end of central directory
  let central_size = buf.length() - central_offset
  push_u32_le(buf, 0x06054B50)
  push_u16_le(buf, 0)
  push_u16_le(buf, 0)
  push_u16_le(buf, 1)
  push_u16_le(buf, 1)
  push_u32_le(buf, central_size.reinterpret_as_uint())
  push_u32_le(buf, central_offset.reinterpret_as_uint())
  push_u16_le(buf, 0)
  let archive = read(Bytes::from_array(buf))
  inspect(archive.get("b.txt") == Some(b"zip64"), content="true")
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
  try u64_to_int(0x1_0000_0000) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected u64_to_int to raise")
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

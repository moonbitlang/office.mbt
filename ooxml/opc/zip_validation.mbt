///|
// These field readers are used only after their enclosing fixed-size header
// has been checked against the input bounds.
fn zip_header_u16(data : BytesView, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn zip_header_u32(data : BytesView, offset : Int) -> UInt {
  data[offset].to_uint() |
  (data[offset + 1].to_uint() << 8) |
  (data[offset + 2].to_uint() << 16) |
  (data[offset + 3].to_uint() << 24)
}

///|
fn zip_header_index(value : UInt) -> Int raise OpcError {
  guard value <= 0x7fffffffU else {
    raise MalformedPackage("ZIP directory value exceeds the supported range")
  }
  value.reinterpret_as_int()
}

///|
fn zip_header_u64_index(data : BytesView, offset : Int) -> Int raise OpcError {
  guard zip_header_u32(data, offset + 4) == 0U else {
    raise MalformedPackage("ZIP64 directory value exceeds the supported range")
  }
  zip_header_index(zip_header_u32(data, offset))
}

///|
fn zip_header_end(data : BytesView) -> Int raise OpcError {
  guard data.length() >= 22 else {
    raise MalformedPackage("ZIP end of central directory is missing")
  }
  let lower = if data.length() > 65557 { data.length() - 65557 } else { 0 }
  for offset in (data.length() - 22)>=..lower {
    if zip_header_u32(data, offset) == 0x06054b50U &&
      zip_header_u16(data, offset + 20) == data.length() - offset - 22 {
      return offset
    }
  }
  raise MalformedPackage("ZIP end of central directory is missing")
}

///|
// Return (entry count, directory size, directory offset, directory end).
fn zip_header_directory(
  data : BytesView,
) -> (Int, Int, Int, Int) raise OpcError {
  let end = zip_header_end(data)
  guard zip_header_u16(data, end + 4) == 0 && zip_header_u16(data, end + 6) == 0 else {
    raise MalformedPackage("multi-disk ZIP packages are not supported")
  }
  let disk_entries = zip_header_u16(data, end + 8)
  let entries = zip_header_u16(data, end + 10)
  let size = zip_header_u32(data, end + 12)
  let offset = zip_header_u32(data, end + 16)
  let zip64 = disk_entries == 65535 ||
    entries == 65535 ||
    size == 0xffffffffU ||
    offset == 0xffffffffU
  guard zip64 else {
    guard disk_entries == entries else {
      raise MalformedPackage("ZIP directory entry counts disagree")
    }
    return (entries, zip_header_index(size), zip_header_index(offset), end)
  }
  guard end >= 20 else {
    raise MalformedPackage("ZIP64 directory locator is missing")
  }
  let locator = end - 20
  guard zip_header_u32(data, locator) == 0x07064b50U else {
    raise MalformedPackage("ZIP64 directory locator is missing")
  }
  guard zip_header_u32(data, locator + 4) == 0U &&
    zip_header_u32(data, locator + 16) == 1U else {
    raise MalformedPackage("multi-disk ZIP64 packages are not supported")
  }
  let record = zip_header_u64_index(data, locator + 8)
  guard record <= locator && locator - record >= 56 else {
    raise MalformedPackage("ZIP64 directory end record is out of bounds")
  }
  guard zip_header_u32(data, record) == 0x06064b50U else {
    raise MalformedPackage(
      "ZIP64 directory end record has an invalid signature",
    )
  }
  let record_size = zip_header_u64_index(data, record + 4)
  guard record_size >= 44 && record_size == locator - record - 12 else {
    raise MalformedPackage("ZIP64 directory end record has an invalid size")
  }
  guard zip_header_u32(data, record + 16) == 0U &&
    zip_header_u32(data, record + 20) == 0U else {
    raise MalformedPackage("multi-disk ZIP64 packages are not supported")
  }
  let zip_disk_entries = zip_header_u64_index(data, record + 24)
  let zip_entries = zip_header_u64_index(data, record + 32)
  let zip_size = zip_header_u64_index(data, record + 40)
  let zip_offset = zip_header_u64_index(data, record + 48)
  guard zip_disk_entries == zip_entries &&
    (disk_entries == 65535 || disk_entries == zip_entries) &&
    (entries == 65535 || entries == zip_entries) else {
    raise MalformedPackage("ZIP64 directory entry counts disagree")
  }
  guard (size == 0xffffffffU || size == zip_size.reinterpret_as_uint()) &&
    (offset == 0xffffffffU || offset == zip_offset.reinterpret_as_uint()) else {
    raise MalformedPackage("classic and ZIP64 directory bounds disagree")
  }
  (zip_entries, zip_size, zip_offset, record)
}

///|
/// Check the OPC size limit for central-directory file headers in original
/// ZIP bytes. Each header, excluding its four-byte signature, may occupy at
/// most 65535 bytes, including its name, extra fields and comment.
///
/// Use after ZIP decoding: this checks directory framing and header lengths,
/// without decompressing payloads, verifying CRCs or retaining source records.
/// ZIP64 single-disk directories are supported. `checkpoint` runs before the
/// scan, for every entry, and after the scan; its errors propagate unchanged.
pub fn validate_zip_headers(
  data : BytesView,
  checkpoint? : () -> Unit raise = () => (),
) -> Unit raise {
  checkpoint()
  let (entries, size, offset, boundary) = zip_header_directory(data)
  guard offset <= boundary && size <= boundary - offset && entries <= size / 46 else {
    raise MalformedPackage("ZIP central directory is out of bounds")
  }
  let end = offset + size
  let mut position = offset
  for _ in 0..<entries {
    checkpoint()
    guard end - position >= 46 else {
      raise MalformedPackage("ZIP central-directory file header is truncated")
    }
    guard zip_header_u32(data, position) == 0x02014b50U else {
      raise MalformedPackage(
        "ZIP central-directory file header has an invalid signature",
      )
    }
    guard zip_header_u16(data, position + 34) == 0 else {
      raise MalformedPackage("multi-disk ZIP packages are not supported")
    }
    let header_size = 42 +
      zip_header_u16(data, position + 28) +
      zip_header_u16(data, position + 30) +
      zip_header_u16(data, position + 32)
    guard header_size <= 65535 else {
      raise MalformedPackage(
        "central-directory file header exceeds the OPC 65535-byte limit",
      )
    }
    guard header_size + 4 <= end - position else {
      raise MalformedPackage("ZIP central-directory file header is truncated")
    }
    position += header_size + 4
  }
  guard position == end else {
    raise MalformedPackage(
      "ZIP central-directory size and entry count disagree",
    )
  }
  checkpoint()
}

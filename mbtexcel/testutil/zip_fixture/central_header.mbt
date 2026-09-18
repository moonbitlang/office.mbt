///|
fn read_u16(bytes : Array[Byte], offset : Int) -> Int {
  bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
}

///|
fn read_u32(bytes : Array[Byte], offset : Int) -> UInt {
  bytes[offset].to_uint() |
  (bytes[offset + 1].to_uint() << 8) |
  (bytes[offset + 2].to_uint() << 16) |
  (bytes[offset + 3].to_uint() << 24)
}

///|
fn write_u16(bytes : Array[Byte], offset : Int, value : Int) -> Unit {
  let raw = value.reinterpret_as_uint()
  bytes[offset] = (raw & 0xFF).to_byte()
  bytes[offset + 1] = ((raw >> 8) & 0xFF).to_byte()
}

///|
fn write_u32(bytes : Array[Byte], offset : Int, value : UInt) -> Unit {
  bytes[offset] = (value & 0xFF).to_byte()
  bytes[offset + 1] = ((value >> 8) & 0xFF).to_byte()
  bytes[offset + 2] = ((value >> 16) & 0xFF).to_byte()
  bytes[offset + 3] = ((value >> 24) & 0xFF).to_byte()
}

///|
fn find_classic_eocd(bytes : Array[Byte]) -> Int raise {
  if bytes.length() < 22 {
    fail("ZIP fixture is too short to contain EOCD")
  }
  for offset in (bytes.length() - 22)>=..0 {
    if read_u32(bytes, offset) == (0x06054B50 : UInt) &&
      offset + 22 + read_u16(bytes, offset + 20) == bytes.length() {
      return offset
    }
  }
  fail("ZIP fixture is missing an EOCD record anchored at EOF")
}

///|
/// Returns the byte offset of a classic, single-disk ZIP central directory.
/// This is intentionally a narrow test-fixture accessor, not a ZIP parser.
pub fn classic_central_directory_offset(data : BytesView) -> Int raise {
  let bytes = data.to_owned().to_array()
  let eocd = find_classic_eocd(bytes)
  let central_offset = read_u32(bytes, eocd + 16).reinterpret_as_int()
  let central_size = read_u32(bytes, eocd + 12).reinterpret_as_int()
  if central_offset < 0 ||
    central_size < 0 ||
    central_offset + central_size != eocd {
    fail("ZIP fixture does not have one classic central directory")
  }
  central_offset
}

///|
fn name_matches(
  bytes : Array[Byte],
  offset : Int,
  length : Int,
  expected : BytesView,
) -> Bool {
  if length != expected.length() {
    return false
  }
  for index in 0..<length {
    if bytes[offset + index] != expected[index] {
      return false
    }
  }
  true
}

///|
/// Replaces one classic ZIP entry's Central File Comment so that its complete
/// Central Directory File Header has `desired_size` bytes excluding the
/// four-byte signature. This intentionally exercises header dimensions that
/// the archive builder does not expose, while leaving local-file data intact.
///
/// Test fixtures must have a classic, single-disk central directory and one
/// exact UTF-8 entry-name match. The requested comment must fit ZIP's UInt16
/// field.
pub fn with_central_header_size(
  data : BytesView,
  target_name : String,
  desired_size : Int,
) -> Bytes raise {
  let source = data.to_owned().to_array()
  let eocd = find_classic_eocd(source)
  let central_offset = read_u32(source, eocd + 16).reinterpret_as_int()
  let central_size = read_u32(source, eocd + 12).reinterpret_as_int()
  if central_offset < 0 ||
    central_size < 0 ||
    central_offset + central_size != eocd {
    fail("ZIP fixture does not have one classic central directory")
  }
  let target = @utf8.encode(target_name)
  let mut cursor = central_offset
  let mut match_offset = -1
  let mut match_name_length = 0
  let mut match_extra_length = 0
  let mut match_comment_length = 0
  while cursor < eocd {
    if cursor + 46 > eocd || read_u32(source, cursor) != (0x02014B50 : UInt) {
      fail("ZIP fixture has a malformed central directory")
    }
    let name_length = read_u16(source, cursor + 28)
    let extra_length = read_u16(source, cursor + 30)
    let comment_length = read_u16(source, cursor + 32)
    let next = cursor + 46 + name_length + extra_length + comment_length
    if next > eocd {
      fail("ZIP fixture central record extends beyond EOCD")
    }
    if name_matches(source, cursor + 46, name_length, target) {
      if match_offset >= 0 {
        fail("ZIP fixture contains duplicate target entry '\{target_name}'")
      }
      match_offset = cursor
      match_name_length = name_length
      match_extra_length = extra_length
      match_comment_length = comment_length
    }
    cursor = next
  }
  if cursor != eocd {
    fail("ZIP fixture central directory does not end at EOCD")
  }
  if match_offset < 0 {
    fail("ZIP fixture is missing target entry '\{target_name}'")
  }
  let fixed_size = 42 + match_name_length + match_extra_length
  let new_comment_length = desired_size - fixed_size
  if new_comment_length < 0 || new_comment_length > 65_535 {
    fail(
      "requested central header size \{desired_size} cannot fit the target entry's ZIP comment field",
    )
  }
  let comment_offset = match_offset +
    46 +
    match_name_length +
    match_extra_length
  let old_record_end = comment_offset + match_comment_length
  let delta = new_comment_length - match_comment_length
  let output : Array[Byte] = []
  for index in 0..<comment_offset {
    output.push(source[index])
  }
  for _ in 0..<new_comment_length {
    output.push(b'x')
  }
  for index in old_record_end..<source.length() {
    output.push(source[index])
  }
  write_u16(output, match_offset + 32, new_comment_length)
  let new_eocd = eocd + delta
  write_u32(output, new_eocd + 12, (central_size + delta).reinterpret_as_uint())
  Bytes::from_array(output)
}

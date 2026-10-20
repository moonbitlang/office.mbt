// SPDX-License-Identifier: MPL-2.0
// Adapted from mtx-decompressor 1.8.0, ChristopherVR; see NOTICE.

///|
priv struct Table {
  tag : Int32
  mut offset : Int32
  mut data : Bytes
  mut checksum : UInt32
}

///|
fn require_table(tables : Array[Table], tag : Int32) -> Table raise {
  guard tables.iter().find_first(table => table.tag == tag) is Some(table) else {
    bad("required MTX font table missing")
    return { tag, offset: 0, data: b"", checksum: 0, }
  }
  table
}

///|
fn cvt(input : Stream) -> Bytes raise {
  let count = input.uint(2)
  let output = Stream::new()
  let mut value = 0
  for _ in 0..<count {
    let code = input.u8()
    let delta = if code >= 248 {
      238 * (code - 247) + input.u8()
    } else if code >= 239 {
      -(238 * (code - 239) + input.u8())
    } else if code == 238 {
      input.s16()
    } else {
      code
    }
    value = signed16(value + delta)
    output.put(value, count=2)
  }
  output.bytes()
}

///|
fn decode_ctf(streams : Array[Stream]) -> Array[Table] raise {
  let input = streams[0]
  guard input.uint(4) == 65536 else {
    bad("unsupported MTX font flavor")
    return []
  }
  let count = input.uint(2)
  guard count > 0 && count <= 4096 else {
    bad("invalid MTX table count")
    return []
  }
  input.uint(2) |> ignore
  input.uint(2) |> ignore
  input.uint(2) |> ignore
  let tables : Array[Table] = []
  for _ in 0..<count {
    let tag = input.uint(4)
    input.uint(4) |> ignore
    let offset = input.uint(4)
    let size = input.uint(4)
    guard offset >= 0 &&
      size >= 0 &&
      size <= budget &&
      !tables.any(table => table.tag == tag) else {
      bad("invalid MTX table directory")
      return []
    }
    tables.push({ tag, offset, data: b"", checksum: 0, })
    // Preserve the encoded size until the second pass has copied its bytes.
    tables[tables.length() - 1].checksum = size.reinterpret_as_uint()
  }
  for table in tables {
    if table.tag == 0x676c7966 || table.tag == 0x6c6f6361 {
      continue
    }
    input.seek(table.offset)
    table.data = if table.tag == 0x63767420 {
      cvt(input)
    } else {
      let out = Stream::new()
      input.copy(out, table.checksum.reinterpret_as_int())
      out.bytes()
    }
    table.checksum = 0
  }
  let head = require_table(tables, 0x68656164)
  let maxp = require_table(tables, 0x6d617870)
  require_table(tables, 0x686d7478) |> ignore
  let head_input = Stream::new(data=head.data)
  head_input.seek(50)
  let loca_format = head_input.uint(2)
  guard loca_format == 0 || loca_format == 1 else {
    bad("invalid MTX loca format")
    return []
  }
  let maxp_input = Stream::new(data=maxp.data)
  maxp_input.seek(4)
  let num_glyphs = maxp_input.uint(2)
  for table in tables {
    if table.tag == 0x56444d58 {
      table.data = vdmx(table.data)
    } else if table.tag == 0x68646d78 {
      table.data = hdmx(table.data, tables, num_glyphs)
    }
  }
  if tables.iter().find_first(table => table.tag == 0x676c7966) is Some(glyf) {
    input.seek(glyf.offset)
    let out = Stream::new()
    let loca = Stream::new()
    let offsets = [0]
    for _ in 0..<num_glyphs {
      glyph(streams, out)
      if (out.pos & 1) != 0 {
        out.put(0)
      }
      offsets.push(out.pos)
    }
    let long = loca_format == 1 || out.pos > 131070
    if long && loca_format == 0 {
      let bytes = head.data.to_array()
      bytes[50] = 0
      bytes[51] = 1
      head.data = Bytes::from_array(bytes)
    }
    for offset in offsets {
      loca.put(
        if long {
          offset
        } else {
          offset / 2
        },
        count=if long { 4 } else { 2 },
      )
    }
    glyf.data = out.bytes()
    match tables.iter().find_first(table => table.tag == 0x6c6f6361) {
      Some(table) => table.data = loca.bytes()
      None =>
        tables.push({
          tag: 0x6c6f6361,
          offset: 0,
          data: loca.bytes(),
          checksum: 0,
        })
    }
  }
  guard head.data.length() >= 54 else {
    bad("truncated MTX head table")
    return []
  }
  let bytes = head.data.to_array()
  for i in 8..<12 {
    bytes[i] = 0
  }
  head.data = Bytes::from_array(bytes)
  tables
}

///|
fn checksum(bytes : Bytes) -> UInt32 {
  let mut sum : UInt32 = 0
  let mut at = 0
  while at < bytes.length() {
    let mut word : UInt32 = 0
    for i in 0..<4 {
      word = (word << 8) | bytes.get(at + i).unwrap_or(0).to_uint()
    }
    sum += word
    at += 4
  }
  sum
}

///|
fn sfnt(tables : Array[Table]) -> Bytes raise {
  let out = Stream::new()
  let count = tables.length()
  let mut power = 1
  let mut selector = 0
  while power * 2 <= count {
    power *= 2
    selector += 1
  }
  out.put(65536, count=4)
  out.put(count, count=2)
  out.put(power * 16, count=2)
  out.put(selector, count=2)
  out.put(count * 16 - power * 16, count=2)
  for _ in 0..<(count * 16) {
    out.put(0)
  }
  for table in tables {
    table.offset = out.pos
    table.checksum = checksum(table.data)
    for byte in table.data {
      out.put(byte.to_int())
    }
    while out.pos % 4 != 0 {
      out.put(0)
    }
  }
  out.seek(12)
  let sorted = tables.copy()
  sorted.sort_by((left, right) => left.tag.compare(right.tag))
  for table in sorted {
    out.put(table.tag, count=4)
    out.put(table.checksum.reinterpret_as_int(), count=4)
    out.put(table.offset, count=4)
    out.put(table.data.length(), count=4)
  }
  let total = checksum(out.bytes())
  let head = require_table(tables, 0x68656164)
  out.seek(head.offset + 8)
  out.put((0xb1b0afbaU - total).reinterpret_as_int(), count=4)
  out.bytes()
}

///|
/// Decode a MicroType Express font program into a checksummed TrueType SFNT.
/// Input, decompressed blocks and output are bounded; malformed streams raise
/// DecodeError before a table or glyph can read outside its own input buffer.
pub fn decompress(data : Bytes) -> Bytes raise {
  guard data.length() >= 10 && data.length() <= budget else {
    bad("invalid MTX input length")
    return b""
  }
  let header = Stream::new(data~)
  let version = header.u8()
  guard version >= 1 && version <= 3 else {
    bad("unsupported MTX compression version")
    return b""
  }
  header.uint(3) |> ignore
  let second = header.uint(3)
  let third = header.uint(3)
  guard second >= 10 && third >= second && third <= data.length() else {
    bad("invalid MTX block offsets")
    return b""
  }
  let offsets : ReadOnlyArray[Int32] = [10, second, third, data.length()]
  let streams = []
  let mut total = 0
  for i in 0..<3 {
    let bytes = lz(data[offsets[i]:offsets[i + 1]].to_owned(), version)
    total += bytes.length()
    guard total <= budget else {
      bad("MTX decompressed block budget exceeded")
      return b""
    }
    streams.push(Stream::new(data=bytes))
  }
  sfnt(decode_ctf(streams))
}

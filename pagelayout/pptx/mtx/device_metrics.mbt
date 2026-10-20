// SPDX-License-Identifier: MPL-2.0
// Adapted from mtx-decompressor 1.8.0, ChristopherVR; see NOTICE.

///|
fn hdmx(data : Bytes, tables : Array[Table], glyphs : Int32) -> Bytes raise {
  let input = Stream::new(data~)
  let version = input.uint(2)
  let records = input.uint(2)
  let size = input.uint(4)
  guard size >= 2 &&
    size % 4 == 0 &&
    size <= budget &&
    records <= (budget - 8) / size else {
    bad("invalid MTX hdmx record size")
    return b""
  }
  let length = 8 + records * size
  if version == 65535 {
    guard length <= data.length() else {
      bad("truncated raw MTX hdmx")
      return b""
    }
    let out = data.to_array()
    out[0] = 0
    out[1] = 0
    return Bytes::from_array(out)
  }
  guard version == 0 && size == ((glyphs + 5) & -4) else {
    bad("invalid compressed MTX hdmx header")
    return b""
  }
  let head = Stream::new(data=require_table(tables, 0x68656164).data)
  head.seek(18)
  let units = head.uint(2)
  let hhea = Stream::new(data=require_table(tables, 0x68686561).data)
  hhea.seek(34)
  let metrics = hhea.uint(2)
  guard units > 0 && metrics > 0 && metrics <= glyphs else {
    bad("invalid MTX hdmx metrics")
    return b""
  }
  let hmtx = Stream::new(data=require_table(tables, 0x686d7478).data)
  let advances = []
  let mut last = 0
  for i in 0..<glyphs {
    if i < metrics {
      last = hmtx.uint(2)
      hmtx.uint(2) |> ignore
    } else {
      hmtx.uint(2) |> ignore
    }
    advances.push(last)
  }
  let header_end = 8 + records * 2
  guard header_end <= data.length() else {
    bad("truncated MTX hdmx headers")
    return b""
  }
  let bits = Stream::new(data=data[header_end:].to_owned())
  let out = Stream::new()
  out.put(0, count=2)
  out.put(records, count=2)
  out.put(size, count=4)
  for _ in 0..<records {
    let start = out.pos
    let ppem = input.u8()
    out.put(ppem)
    out.put(input.u8())
    for advance in advances {
      let predicted = ((64 * ppem * advance + units / 2) / units + 32) / 64
      let width = predicted + bits.magnitude()
      guard width >= 0 && width <= 255 else {
        bad("decoded MTX hdmx width overflow")
        return b""
      }
      out.put(width)
    }
    while out.pos < start + size {
      out.put(0)
    }
  }
  out.bytes()
}

///|
fn vdmx_groups(data : Bytes) -> Array[Int32] raise {
  let input = Stream::new(data~)
  let version = input.uint(2)
  let records = input.uint(2)
  let ratios = input.uint(2)
  guard version <= 1 && records > 0 && ratios > 0 else {
    bad("invalid MTX VDMX header")
    return []
  }
  input.seek(6 + ratios * 4)
  let groups : Array[Int32] = []
  let mut first = -1
  for _ in 0..<ratios {
    let offset = input.uint(2)
    if first < 0 {
      first = offset
    }
    guard offset >= 6 + ratios * 6 else {
      bad("MTX VDMX group overlaps header")
      return []
    }
    if !groups.contains(offset) {
      groups.push(offset)
    }
  }
  groups.sort()
  guard groups.length() == records && groups[0] == first else {
    bad("invalid MTX VDMX ratio groups")
    return []
  }
  groups
}

///|
fn validate_vdmx(data : Bytes) -> Unit raise {
  let groups = vdmx_groups(data)
  let input = Stream::new(data~)
  for i, start in groups {
    input.seek(start)
    let count = input.uint(2)
    input.u8() |> ignore
    input.u8() |> ignore
    let limit = groups.get(i + 1).unwrap_or(data.length())
    guard count > 0 && count <= (limit - start - 4) / 6 else {
      bad("MTX VDMX records outside group")
      return
    }
    let mut previous = -1
    for _ in 0..<count {
      let ppem = input.uint(2)
      input.s16() |> ignore
      input.s16() |> ignore
      guard ppem > previous else {
        bad("unordered MTX VDMX sizes")
        return
      }
      previous = ppem
    }
  }
}

///|
fn vdmx(data : Bytes) -> Bytes raise {
  let input = Stream::new(data~)
  let version = input.uint(2)
  if version > 1 {
    let original = 65535 - version
    guard original <= 1 else {
      bad("invalid raw MTX VDMX version")
      return b""
    }
    let bytes = data.to_array()
    bytes[0] = 0
    bytes[1] = original.to_byte()
    let result = Bytes::from_array(bytes)
    validate_vdmx(result)
    return result
  }
  let groups = vdmx_groups(data)
  input.seek(groups[0])
  let output = Stream::new(data~)
  for i, start in groups {
    let count = input.uint(2)
    let max_multiplier = input.s16()
    let min_multiplier = input.s16()
    guard count > 0 else {
      bad("empty compressed MTX VDMX group")
      return b""
    }
    let limit = groups.get(i + 1).unwrap_or(budget)
    guard count <= (limit - start - 4) / 6 else {
      bad("expanded MTX VDMX group overlaps next group")
      return b""
    }
    let records = Stream::new()
    let mut predicted = 8
    let mut first = 0
    let mut last = -1
    for record in 0..<count {
      let ppem = predicted + input.magnitude()
      let max_y = (ppem * max_multiplier + 1024) / 2048 + input.magnitude()
      let min_y = -(ppem * min_multiplier + 1024) / 2048 + input.magnitude()
      guard ppem >= 0 &&
        ppem <= 65535 &&
        ppem > last &&
        max_y >= -32768 &&
        max_y <= 32767 &&
        min_y >= -32768 &&
        min_y <= 32767 else {
        bad("MTX VDMX predicted metric overflow")
        return b""
      }
      if record == 0 {
        first = ppem
      }
      last = ppem
      predicted = ppem + 1
      records.put(ppem, count=2)
      records.put(max_y, count=2)
      records.put(min_y, count=2)
    }
    if input.bit != 0 {
      input.bit = 0
      input.pos += 1
    }
    output.pos = start
    output.put(count, count=2)
    output.put(first & 255)
    output.put(last & 255)
    let source = Stream::new(data=records.bytes())
    source.copy(output, source.data.length())
  }
  let result = output.bytes()
  validate_vdmx(result)
  result
}

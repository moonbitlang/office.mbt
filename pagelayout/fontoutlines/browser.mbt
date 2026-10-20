///|
priv struct BrowserTable {
  tag : UInt32
  data : Bytes
  offset : Int32
}

///|
fn browser_checksum(data : Bytes) -> UInt32 {
  let mut sum : UInt32 = 0
  for at = 0; at < data.length(); at = at + 4 {
    let mut word : UInt32 = 0
    for i in 0..<4 {
      word = (word << 8) | data.get(at + i).unwrap_or(0).to_uint()
    }
    sum += word
  }
  sum
}

///|
/// Bundled PDF programs omit the name table. Browsers require it even when
/// CSS assigns the family, so supply the original bundled family and style.
fn browser_name(family : String, bold : Bool, italic : Bool) -> Bytes {
  let style = match (bold, italic) {
    (true, true) => "Bold Italic"
    (true, false) => "Bold"
    (false, true) => "Italic"
    _ => "Regular"
  }
  let full = family + " " + style
  let postscript = full.replace(old=" ", new="")
  let records : Array[(Int32, String)] = [
    (1, family),
    (2, style),
    (3, full),
    (4, full),
    (5, "Version 1.0"),
    (6, postscript),
    (16, family),
    (17, style),
  ]
  let out = Buffer()
  let strings = Buffer()
  out.write_uint16_be(0)
  out.write_uint16_be(records.length().to_uint16())
  out.write_uint16_be((6 + records.length() * 12).to_uint16())
  for (id, value) in records {
    out.write_uint16_be(3)
    out.write_uint16_be(1)
    out.write_uint16_be(0x409)
    out.write_uint16_be(id.to_uint16())
    out.write_uint16_be((value.length() * 2).to_uint16())
    out.write_uint16_be(strings.length().to_uint16())
    strings.write_string_utf16be(value)
  }
  out.write_bytes(strings.contents())
  out.contents()
}

///|
/// The bundled outline program with the naming table required by OpenType
/// browser sanitizers. PDF consumers may continue using `outline_sfnt`.
/// Family and style resolution match `outline_sfnt`. Supplying `codepoints`
/// retains only their outlines (including composite dependencies), preserving
/// original glyph IDs, metrics, cmap, hinting and browser-required tables.
pub fn browser_sfnt(
  family : String,
  bold~ : Bool = false,
  italic~ : Bool = false,
  codepoints? : Array[Int32],
) -> Bytes? raise {
  guard outline_sfnt(family, bold~, italic~) is Some(program) else {
    return None
  }
  let glyf = codepoints.map(points => {
    @pdflite.pdf_truetype_subset_glyf_table(program, points)
  })
  let loca = codepoints.map(points => {
    @pdflite.pdf_truetype_subset_loca_table(program, points)
  })
  let count = program.unsafe_read_uint16_be(4).to_int()
  let tables : Array[BrowserTable] = []
  for i in 0..<count {
    let at = 12 + i * 16
    let tag = program.unsafe_read_uint32_be(at)
    let offset = program.unsafe_read_uint32_be(at + 8).reinterpret_as_int()
    let size = program.unsafe_read_uint32_be(at + 12).reinterpret_as_int()
    if tag == 0x6e616d65U {
      return Some(program)
    }
    let data = if tag == 0x676c7966U && glyf is Some(glyf) {
      glyf.bytes[:glyf.length].to_owned()
    } else if tag == 0x6c6f6361U && loca is Some(loca) {
      loca[:size].to_owned()
    } else if tag == 0x68656164U {
      let bytes = program[offset:offset + size].to_owned().to_array()
      for j in 8..<12 {
        bytes[j] = 0
      }
      Bytes::from_array(bytes)
    } else {
      program[offset:offset + size].to_owned()
    }
    tables.push({ tag, data, offset: 0, })
  }
  tables.push({
    tag: 0x6e616d65U,
    data: browser_name(family, bold, italic),
    offset: 0,
  })
  tables.sort_by((left, right) => left.tag.compare(right.tag))
  let count = tables.length()
  let mut offset = 12 + count * 16
  let placed = tables.map(table => {
    let placed = { ..table, offset, }
    offset += (table.data.length() + 3) / 4 * 4
    placed
  })
  let mut power = 1
  let mut selector = 0
  while power * 2 <= count {
    power *= 2
    selector += 1
  }
  let out = Buffer()
  out.write_uint_be(0x10000)
  out.write_uint16_be(count.to_uint16())
  out.write_uint16_be((power * 16).to_uint16())
  out.write_uint16_be(selector.to_uint16())
  out.write_uint16_be((count * 16 - power * 16).to_uint16())
  for table in placed {
    out.write_uint_be(table.tag)
    out.write_uint_be(browser_checksum(table.data))
    out.write_uint_be(table.offset.reinterpret_as_uint())
    out.write_uint_be(table.data.length().reinterpret_as_uint())
  }
  for table in placed {
    out.write_bytes(table.data)
    while out.length() % 4 != 0 {
      out.write_byte(0)
    }
  }
  let adjustment = 0xb1b0afbaU - browser_checksum(out.contents())
  let bytes = out.contents().to_array()
  for table in placed {
    if table.tag == 0x68656164U {
      for i in 0..<4 {
        bytes[table.offset + 8 + i] = ((adjustment >> ((3 - i) * 8)) & 255).to_byte()
      }
    }
  }
  Some(Bytes::from_array(bytes))
}

///|
/// A minimal sfnt holding only a `name` table with the given (platform,
/// raw string bytes) records for name ID 6.
fn sfnt_with_names(records : Array[(Int, Bytes)]) -> Bytes {
  let out : Array[Byte] = []
  let u16 = fn(v : Int) {
    out.push((v >> 8).to_byte())
    out.push((v & 0xFF).to_byte())
  }
  let u32 = fn(v : Int) {
    u16(v >> 16)
    u16(v & 0xFFFF)
  }
  // offset table: version, numTables = 1, search fields
  u32(0x00010000)
  u16(1)
  u16(16)
  u16(0)
  u16(0)
  // the one table record: 'name' at offset 28
  let table = 12 + 16
  let strings = 6 + records.length() * 12
  let mut length = strings
  for record in records {
    length += record.1.length()
  }
  u32(0x6E616D65)
  u32(0)
  u32(table)
  u32(length)
  // name table header and records
  u16(0)
  u16(records.length())
  u16(strings)
  let mut offset = 0
  for record in records {
    let (platform, text) = record
    u16(platform)
    u16(if platform == 3 { 1 } else { 0 })
    u16(if platform == 3 { 0x409 } else { 0 })
    u16(6)
    u16(text.length())
    u16(offset)
    offset += text.length()
  }
  for record in records {
    for byte in record.1 {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}

///|
fn utf16be_of(text : String) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<text.length() {
    let unit = text[i].to_int()
    out.push((unit >> 8).to_byte())
    out.push((unit & 0xFF).to_byte())
  }
  Bytes::from_array(out)
}

///|
test "postscript_name reads name ID 6, preferring the Windows record" {
  inspect(
    postscript_name(
      sfnt_with_names([(1, b"MacName"), (3, utf16be_of("NotoSerif-Bold"))]),
    ).unwrap_or("-"),
    content="NotoSerif-Bold",
  )
  inspect(
    postscript_name(sfnt_with_names([(1, b"mplus1mn-regular")])).unwrap_or("-"),
    content="mplus1mn-regular",
  )
  // delimiters and spaces cannot appear in a PDF name
  inspect(
    postscript_name(sfnt_with_names([(3, utf16be_of("Odd (Name)/X"))])).unwrap_or(
      "-",
    ),
    content="OddNameX",
  )
  inspect(postscript_name(sfnt_with_names([])).unwrap_or("-"), content="-")
  inspect(postscript_name(b"\x00\x01").unwrap_or("-"), content="-")
}

///|
test "lexical_compare orders bytes, not lengths" {
  assert_true(lexical_compare(b"ab", b"b") < 0)
  assert_true(lexical_compare(b"a", b"ab") < 0)
  assert_true(lexical_compare(b"ab", b"ab") == 0)
  assert_true(lexical_compare(b"b", b"a_long_name") > 0)
}

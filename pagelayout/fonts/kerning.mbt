///|
/// Horizontal, format-0 TrueType kerning. Glyph-pair keys keep the table compact
/// and avoid expanding it through every Unicode alias in the cmap.
fn parse_legacy_kerning(data : Bytes) -> Map[(Int32, Int32), Int32] raise {
  let pairs : Map[(Int32, Int32), Int32] = Map([])
  guard @pdflite.pdf_truetype_table(data, "kern") is Some(table) else {
    return pairs
  }
  let start = table.offset
  let limit = start + table.length
  fn u16(at : Int32) -> Int32 raise {
    guard at >= start && at + 2 <= limit else {
      fail("truncated TrueType kern table")
    }
    (data[at].to_int() << 8) | data[at + 1].to_int()
  }
  // Apple's version-1 table has a different header and subtable formats.
  guard u16(start) == 0 else { return pairs }
  let count = u16(start + 2)
  let mut at = start + 4
  for index in 0..<count {
    let length = u16(at + 2)
    let coverage = u16(at + 4)
    guard length >= 6 && at + length <= limit else {
      fail("invalid TrueType kern subtable length")
    }
    let mut consumed = length
    if coverage >> 8 == 0 && (coverage & 7) == 1 {
      let pair_count = u16(at + 6)
      let required = 14 + pair_count * 6
      // Some released Microsoft fonts wrap the 16-bit length of their one
      // large format-0 subtable. The pair count and enclosing SFNT table still
      // give an unambiguous, bounded extent.
      if required > length {
        guard count == 1 &&
          index == 0 &&
          (required & 0xffff) == length &&
          at + required <= limit else {
          fail("truncated TrueType kerning pairs")
        }
        consumed = required
      }
      for pair_index in 0..<pair_count {
        let record = at + 14 + pair_index * 6
        let key = (u16(record), u16(record + 2))
        let raw = u16(record + 4)
        let value = if raw >= 0x8000 { raw - 0x10000 } else { raw }
        pairs[key] = if (coverage & 8) != 0 {
          value
        } else {
          pairs.get(key).unwrap_or(0) + value
        }
      }
    }
    at += consumed
  }
  pairs
}

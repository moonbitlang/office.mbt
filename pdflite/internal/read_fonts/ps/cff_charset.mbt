// Port of read-fonts 0.39.2 `src/ps/cff/charset.rs` and the charset tables
// from `generated/generated_cff.rs`.

///|
/// A custom charset (formats 0, 1 and 2). The payload is the data following
/// the format byte.
pub enum CustomCharset {
  /// Array of SIDs (one per glyph, excluding notdef).
  Format0(BytesView)
  /// Ranges with 8-bit `n_left`.
  Format1(BytesView)
  /// Ranges with 16-bit `n_left`.
  Format2(BytesView)
}

///|
fn CustomCharset::read(data : BytesView) -> CustomCharset raise PsError {
  if data.length() < 1 {
    raise oob()
  }
  let format = data[0].to_int()
  let rest = data[1:]
  match format {
    0 => Format0(rest[0:rest.length() / 2 * 2])
    1 => Format1(rest[0:rest.length() / 3 * 3])
    2 => Format2(rest[0:rest.length() / 4 * 4])
    other => raise Read(@read_fonts.ReadError::InvalidFormat(other.to_int64()))
  }
}

///|
/// Predefined and custom character sets.
pub enum CharsetKind {
  IsoAdobe
  Expert
  ExpertSubset
  Custom(CustomCharset)
}

///|
/// Character set for mapping from glyph to string identifiers.
pub struct Charset {
  kind : CharsetKind
  num_glyphs : Int
}

///|
pub fn Charset::new(
  cff_data : BytesView,
  charset_offset : Int,
  num_glyphs : Int,
) -> Charset raise PsError {
  let kind = match charset_offset {
    0 => IsoAdobe
    1 => Expert
    2 => ExpertSubset
    _ => {
      guard get_from(cff_data, charset_offset) is Some(data) else {
        raise oob()
      }
      Custom(CustomCharset::read(data))
    }
  }
  { kind, num_glyphs, }
}

///|
pub fn Charset::kind(self : Charset) -> CharsetKind {
  self.kind
}

///|
pub fn Charset::num_glyphs(self : Charset) -> Int {
  self.num_glyphs
}

///|
/// Returns the string identifier for the given glyph identifier.
pub fn Charset::string_id(
  self : Charset,
  glyph_id : GlyphId,
) -> Sid raise PsError {
  let gid = glyph_id.to_u32()
  if gid >= self.num_glyphs.reinterpret_as_uint() {
    raise oob()
  }
  let gid = gid.reinterpret_as_int()
  match self.kind {
    IsoAdobe =>
      // The ISOAdobe charset is an identity mapping of gid->sid up
      // to 228 entries
      if gid <= 228 {
        Sid::new(gid)
      } else {
        raise oob()
      }
    Expert =>
      if gid < expert_charset.length() {
        Sid::new(expert_charset[gid])
      } else {
        raise oob()
      }
    ExpertSubset =>
      if gid < expert_subset_charset.length() {
        Sid::new(expert_subset_charset[gid])
      } else {
        raise oob()
      }
    Custom(Format0(glyphs)) =>
      if gid == 0 {
        Sid::new(0)
      } else if gid - 1 < glyphs.length() / 2 {
        Sid::new(read_u16_at(glyphs, (gid - 1) * 2))
      } else {
        raise oob()
      }
    Custom(Format1(ranges)) => string_id_from_ranges(ranges, 3, glyph_id)
    Custom(Format2(ranges)) => string_id_from_ranges(ranges, 4, glyph_id)
  }
}

///|
/// Returns the glyph identifier for the given string identifier.
pub fn Charset::glyph_id(
  self : Charset,
  string_id : Sid,
) -> GlyphId raise PsError {
  let sid = string_id.to_u16()
  match self.kind {
    IsoAdobe =>
      // The ISOAdobe charset is an identity mapping of gid->sid up
      // to 228 entries
      if sid <= 228 {
        GlyphId::from_int(sid)
      } else {
        raise oob()
      }
    Expert =>
      match expert_charset.search(sid) {
        Some(pos) => GlyphId::from_int(pos)
        None => raise oob()
      }
    ExpertSubset =>
      match expert_subset_charset.search(sid) {
        Some(pos) => GlyphId::from_int(pos)
        None => raise oob()
      }
    Custom(Format0(glyphs)) => {
      if sid == 0 {
        return GlyphId::notdef()
      }
      for n in 0..<(glyphs.length() / 2) {
        if read_u16_at(glyphs, n * 2) == sid {
          // `(n as u16).saturating_add(1)`
          let n16 = n & 0xFFFF
          return GlyphId::from_int(if n16 == 0xFFFF { 0xFFFF } else { n16 + 1 })
        }
      }
      raise oob()
    }
    Custom(Format1(ranges)) => glyph_id_from_ranges(ranges, 3, string_id)
    Custom(Format2(ranges)) => glyph_id_from_ranges(ranges, 4, string_id)
  }
}

///|
/// Reads range `i` (first, n_left) from a format 1 (size 3) or format 2
/// (size 4) range array.
fn charset_range(ranges : BytesView, size : Int, i : Int) -> (UInt, UInt) {
  let p = i * size
  let first = ((ranges[p].to_int() << 8) | ranges[p + 1].to_int()).reinterpret_as_uint()
  let n_left = if size == 3 {
    ranges[p + 2].to_int()
  } else {
    (ranges[p + 2].to_int() << 8) | ranges[p + 3].to_int()
  }
  (first, n_left.reinterpret_as_uint())
}

///|
fn string_id_from_ranges(
  ranges : BytesView,
  size : Int,
  glyph_id : GlyphId,
) -> Sid raise PsError {
  let mut gid = glyph_id.to_u32()
  // The notdef glyph isn't explicitly mapped so we need to special case
  // it and add -1 and +1 at a few places when processing ranges
  if gid == 0 {
    return Sid::new(0)
  }
  gid -= 1
  let mut end = 0U
  // Each range provides the string ids for `n_left + 1` glyphs with
  // the sequence of string ids starting at `first`. Since the counts
  // are cumulative, we must scan them all in order until we find
  // the range that contains our requested glyph.
  for i in 0..<(ranges.length() / size) {
    let (first, n_left) = charset_range(ranges, size, i)
    let next_end = end + n_left + 1
    if next_end < end {
      raise oob()
    }
    if gid < next_end {
      let sid = (gid - end).to_uint64() + first.to_uint64()
      if sid > 0xFFFFUL {
        raise oob()
      }
      return Sid::new(sid.to_int())
    }
    end = next_end
  }
  raise oob()
}

///|
fn glyph_id_from_ranges(
  ranges : BytesView,
  size : Int,
  string_id : Sid,
) -> GlyphId raise PsError {
  let sid = string_id.to_u16().reinterpret_as_uint()
  // notdef glyph is not explicitly mapped
  if sid == 0 {
    return GlyphId::notdef()
  }
  let mut gid = 1U
  for i in 0..<(ranges.length() / size) {
    let (first, n_left) = charset_range(ranges, size, i)
    if first <= sid && sid <= first + n_left {
      gid += sid - first
      return GlyphId::new(gid)
    }
    gid += n_left + 1
  }
  raise oob()
}

///|
/// Returns all of the glyph and string identifier mappings.
pub fn Charset::iter(self : Charset) -> Iter[(GlyphId, Sid)] {
  self.to_array().iter()
}

///|
/// Returns all of the glyph and string identifier mappings as an array.
pub fn Charset::to_array(self : Charset) -> Array[(GlyphId, Sid)] {
  let result = []
  match self.kind {
    Custom(Format1(ranges)) => range_iter(ranges, 3, self.num_glyphs, result)
    Custom(Format2(ranges)) => range_iter(ranges, 4, self.num_glyphs, result)
    _ => {
      // Predefined sets and custom format 0 are just array lookups so we
      // use the builtin mapping function.
      let mut cur = 0U
      while true {
        let gid = GlyphId::new(cur)
        let sid = self.string_id(gid) catch { _ => break }
        if cur == 0xFFFFFFFFU {
          break
        }
        cur = cur + 1
        result.push((gid, sid))
      }
    }
  }
  result
}

///|
/// Custom iterator for range based formats.
fn range_iter(
  ranges : BytesView,
  size : Int,
  num_glyphs : Int,
  result : Array[(GlyphId, Sid)],
) -> Unit {
  let num_ranges = ranges.length() / size
  let mut next_ix = 0
  let next_range = fn() -> (UInt, UInt)? {
    if next_ix < num_ranges {
      let (first, n_left) = charset_range(ranges, size, next_ix)
      next_ix += 1
      Some((first, n_left + 1))
    } else {
      None
    }
  }
  let (first0, end0) = match next_range() {
    Some(r) => r
    None => (0U, 0U)
  }
  let mut first = first0
  let mut end = end0
  let num_glyphs = num_glyphs.reinterpret_as_uint()
  let mut gid_state = 0U
  let mut prev_end = 0U
  while true {
    if gid_state >= num_glyphs {
      break
    }
    // The notdef glyph isn't explicitly mapped so we need to special case
    // it and add -1 and +1 at a few places when processing ranges
    if gid_state == 0 {
      gid_state += 1
      result.push((GlyphId::new(0), Sid::new(0)))
      continue
    }
    let gid = gid_state - 1
    if gid_state == 0xFFFFFFFFU {
      break
    }
    gid_state += 1
    let mut done = false
    while gid >= end {
      guard next_range() is Some((f, e)) else {
        done = true
        break
      }
      prev_end = end
      first = f
      let ne = prev_end.to_uint64() + e.to_uint64()
      if ne > 0xFFFFFFFFUL {
        done = true
        break
      }
      end = ne.to_uint()
    }
    if done {
      break
    }
    if gid < prev_end {
      break
    }
    let sid = first.to_uint64() + (gid - prev_end).to_uint64()
    if sid > 0xFFFFUL {
      break
    }
    result.push((GlyphId::new(gid + 1), Sid::new(sid.to_int())))
  }
}

///|
/// See "Expert" charset at <https://adobe-type-tools.github.io/font-tech-notes/pdfs/5176.CFF.pdf#page=47>
let expert_charset : FixedArray[Int] = [
  0, 1, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 13, 14, 15, 99, 239, 240,
  241, 242, 243, 244, 245, 246, 247, 248, 27, 28, 249, 250, 251, 252, 253, 254, 255,
  256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 109, 110, 267, 268, 269,
  270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285,
  286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301,
  302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317,
  318, 158, 155, 163, 319, 320, 321, 322, 323, 324, 325, 326, 150, 164, 169, 327,
  328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343,
  344, 345, 346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359,
  360, 361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375,
  376, 377, 378,
]

///|
/// See "Expert Subset" charset at <https://adobe-type-tools.github.io/font-tech-notes/pdfs/5176.CFF.pdf#page=49>
let expert_subset_charset : FixedArray[Int] = [
  0, 1, 231, 232, 235, 236, 237, 238, 13, 14, 15, 99, 239, 240, 241, 242, 243, 244,
  245, 246, 247, 248, 27, 28, 249, 250, 251, 253, 254, 255, 256, 257, 258, 259, 260,
  261, 262, 263, 264, 265, 266, 109, 110, 267, 268, 269, 270, 272, 300, 301, 302,
  305, 314, 315, 158, 155, 163, 320, 321, 322, 323, 324, 325, 326, 150, 164, 169,
  327, 328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342,
  343, 344, 345, 346,
]

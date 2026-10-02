// A minimal OpenType (sfnt) reader: the metrics needed to embed a font and
// glyph-ID based subsetting of `glyf` fonts.

///|
fn rd_u16(data : Bytes, at : Int) -> Int {
  if at < 0 || at + 2 > data.length() {
    return 0
  }
  (data[at].to_int() << 8) | data[at + 1].to_int()
}

///|
fn rd_i16(data : Bytes, at : Int) -> Int {
  let v = rd_u16(data, at)
  if v >= 0x8000 {
    v - 0x10000
  } else {
    v
  }
}

///|
fn rd_u32(data : Bytes, at : Int) -> Int {
  if at < 0 || at + 4 > data.length() {
    return 0
  }
  (data[at].to_int() << 24) |
  (data[at + 1].to_int() << 16) |
  (data[at + 2].to_int() << 8) |
  data[at + 3].to_int()
}

///|
fn rd_tag(data : Bytes, at : Int) -> String {
  let sb = StringBuilder()
  for i in 0..<4 {
    if at + i < data.length() {
      sb.write_char(data[at + i].to_int().unsafe_to_char())
    }
  }
  sb.to_string()
}

///|
/// The outline format of a font.
pub(all) enum OutlineKind {
  Glyf
  Cff
  Cff2
  NoOutlines
} derive(Eq, Debug)

///|
/// An OpenType font face to embed.
pub struct Font {
  /// The font file (possibly a collection).
  data : Bytes
  /// The index of the face in a collection.
  index : Int
  priv tables : Map[String, (Int, Int)]
  /// The number of font units per em.
  units_per_em : Double
  /// The number of glyphs.
  num_glyphs : Int
  priv advances : Array[Int]
  /// The ascender in font units.
  ascent : Double
  /// The descender in font units (negative below the baseline).
  descent : Double
  /// The cap height in font units, if known.
  cap_height : Double?
  /// The italic angle in degrees.
  italic_angle : Double
  /// The weight class.
  weight : Double
  /// Whether the font is monospaced.
  is_monospaced : Bool
  /// The PostScript name.
  postscript_name : String?
  /// The global bounding box `(x_min, y_min, x_max, y_max)` in font units.
  bbox : (Double, Double, Double, Double)
  /// The OS/2 `fsType` embedding permissions.
  fs_type : Int
  /// The outline format.
  kind : OutlineKind
  /// An identifier used to derive subset tags.
  key : String
  /// The color glyph hook.
  priv mut color : ColorGlyphs?
  /// The CID of each glyph of a CID-keyed CFF font.
  priv cids : Array[Int]?
  /// The structure of the `CFF ` table.
  priv cff : CffTable?
}

///|
/// Parse a font face from a font file and a collection index.
pub fn Font::new(data : Bytes, index : Int, key? : String = "") -> Font? {
  // Offsets and lengths are validated up front, so that all later reads and
  // slices stay in bounds (reads past the end of a table only see bytes of
  // the file, never panic).
  let mut base = 0
  if data.length() >= 12 && rd_tag(data, 0) == "ttcf" {
    let count = rd_u32(data, 8)
    if index < 0 ||
      count < 0 ||
      index >= count ||
      16 + 4 * index > data.length() {
      return None
    }
    base = rd_u32(data, 12 + 4 * index)
  } else if index != 0 {
    return None
  }
  if base < 0 || base > data.length() - 12 {
    return None
  }
  let num_tables = rd_u16(data, base + 4)
  if base + 12 + 16 * num_tables > data.length() {
    return None
  }
  let tables : Map[String, (Int, Int)] = Map([])
  for i in 0..<num_tables {
    let rec = base + 12 + 16 * i
    let tag = rd_tag(data, rec)
    // `rd_u32` returns negative values for offsets and lengths >= 2^31.
    let offset = rd_u32(data, rec + 8)
    let length = rd_u32(data, rec + 12)
    if offset < 0 || length < 0 || offset > data.length() - length {
      return None
    }
    tables[tag] = (offset, length)
  }
  // The tables that are read without further length checks.
  // (`head`, `hhea` and `maxp` are required, like in ttf-parser.)
  for entry in [("head", 54), ("hhea", 36), ("maxp", 6)] {
    match tables.get(entry.0) {
      Some((_, len)) => if len < entry.1 { return None }
      None => return None
    }
  }
  guard tables.get("head") is Some((head, _)) else { return None }
  // Like ttf-parser, which rejects other values.
  let units_per_em = rd_u16(data, head + 18)
  if units_per_em < 16 || units_per_em > 16384 {
    return None
  }
  let units_per_em = units_per_em.to_double()
  let bbox = (
    rd_i16(data, head + 36).to_double(),
    rd_i16(data, head + 38).to_double(),
    rd_i16(data, head + 40).to_double(),
    rd_i16(data, head + 42).to_double(),
  )
  let num_glyphs = match tables.get("maxp") {
    Some((maxp, _)) => rd_u16(data, maxp + 4)
    None => 0
  }
  if num_glyphs == 0 {
    return None
  }
  // Horizontal metrics.
  let advances = []
  let mut hhea_ascent = 0
  let mut hhea_descent = 0
  if tables.get("hhea") is Some((hhea, _)) {
    hhea_ascent = rd_i16(data, hhea + 4)
    hhea_descent = rd_i16(data, hhea + 6)
    let n = rd_u16(data, hhea + 34)
    if tables.get("hmtx") is Some((hmtx, len)) {
      let mut last = 0
      for g in 0..<num_glyphs {
        if g < n && 4 * g + 2 <= len {
          last = rd_u16(data, hmtx + 4 * g)
        }
        advances.push(last)
      }
    }
  }
  let mut ascent = hhea_ascent.to_double()
  let mut descent = hhea_descent.to_double()
  let mut cap_height = None
  let mut weight = 400.0
  let mut fs_type = 0
  // (Shorter tables than the fields read are ignored.)
  if tables.get("OS/2") is Some((os2, len)) && len >= 72 {
    let version = rd_u16(data, os2)
    weight = rd_u16(data, os2 + 4).to_double()
    fs_type = rd_u16(data, os2 + 8)
    let fs_selection = rd_u16(data, os2 + 62)
    let typo_ascent = rd_i16(data, os2 + 68)
    let typo_descent = rd_i16(data, os2 + 70)
    // USE_TYPO_METRICS, or no usable hhea metrics.
    if (fs_selection & 0x80) != 0 || (hhea_ascent == 0 && hhea_descent == 0) {
      ascent = typo_ascent.to_double()
      descent = typo_descent.to_double()
    }
    if version >= 2 && len >= 90 {
      cap_height = Some(rd_i16(data, os2 + 88).to_double())
    }
  }
  let mut italic_angle = 0.0
  let mut is_monospaced = false
  if tables.get("post") is Some((post, len)) && len >= 16 {
    // rd_u32 returns the bits as a (possibly negative) Int, i.e. the
    // signed 16.16 fixed value.
    let fixed = rd_u32(data, post + 4)
    italic_angle = fixed.to_double() / 65536.0
    is_monospaced = rd_u32(data, post + 12) != 0
  }
  let kind = if tables.contains("glyf") {
    Glyf
  } else if tables.contains("CFF ") {
    Cff
  } else if tables.contains("CFF2") {
    Cff2
  } else {
    NoOutlines
  }
  let mut cids = None
  let mut cff = None
  if kind == Cff {
    guard tables.get("CFF ") is Some((off, len)) else { return None }
    guard cff_table(data, off, len) is Some(table) else { return None }
    if table.is_cid_keyed() {
      guard table.cids(data) is Some(c) else { return None }
      cids = Some(c)
    }
    cff = Some(table)
  }
  Some({
    data,
    index,
    tables,
    units_per_em,
    num_glyphs,
    advances,
    ascent,
    descent,
    cap_height,
    italic_angle,
    weight,
    is_monospaced,
    postscript_name: read_postscript_name(data, tables),
    bbox,
    fs_type,
    kind,
    key,
    color: None,
    cids,
    cff,
  })
}

///|
/// The CID of a glyph in the embedded font program: for CID-keyed CFF fonts
/// from the charset, else the glyph ID.
fn Font::cid(self : Font, glyph : Int) -> Int {
  match self.cids {
    Some(cids) if glyph >= 0 && glyph < cids.length() => cids[glyph]
    _ => glyph
  }
}

///|
/// Whether the font is a CID-keyed CFF font.
fn Font::is_cid_keyed(self : Font) -> Bool {
  self.cids is Some(_)
}

///|
/// Why the glyphs of a name-keyed CFF font can't be embedded, if one uses
/// `seac` or is malformed (subsetter's error messages).
fn Font::cff_uses_seac(self : Font, glyphs : Array[Int]) -> String? {
  guard self.cff is Some(table) && !table.is_cid_keyed() else { return None }
  guard table.programs(self.data) is Some(programs) else {
    return Some("malformed font")
  }
  for g in glyphs {
    match programs.uses_seac(self.data, g) {
      Some(false) => ()
      Some(true) => return Some("unsupported feature in font")
      None => return Some("malformed font")
    }
  }
  None
}

///|
/// The CID-keyed CFF program to embed: the `CFF ` table of CID-keyed fonts,
/// a converted table for name-keyed ones (`None` if the conversion fails).
fn Font::cid_keyed_cff(self : Font) -> Bytes? {
  guard self.cff is Some(table) else { return None }
  if table.is_cid_keyed() {
    Some(self.data[table.start:table.end].to_owned())
  } else {
    table.to_cid_keyed(self.data)
  }
}

///|
/// The advance width of a glyph in font units.
pub fn Font::advance_width(self : Font, glyph : Int) -> Double? {
  if glyph >= 0 && glyph < self.advances.length() {
    Some(self.advances[glyph].to_double())
  } else {
    None
  }
}

///|
/// Whether the font has a table.
pub fn Font::has_table(self : Font, tag : String) -> Bool {
  self.tables.contains(tag)
}

///|
fn read_postscript_name(
  data : Bytes,
  tables : Map[String, (Int, Int)],
) -> String? {
  guard tables.get("name") is Some((name, _)) else { return None }
  let count = rd_u16(data, name + 2)
  let storage = name + rd_u16(data, name + 4)
  let mut fallback = None
  for i in 0..<count {
    let rec = name + 6 + 12 * i
    let platform = rd_u16(data, rec)
    let name_id = rd_u16(data, rec + 6)
    if name_id != 6 {
      continue
    }
    let len = rd_u16(data, rec + 8)
    let off = storage + rd_u16(data, rec + 10)
    if off + len > data.length() {
      continue
    }
    if platform == 3 || platform == 0 {
      let sb = StringBuilder()
      for k in 0..<(len / 2) {
        sb.write_char(rd_u16(data, off + 2 * k).unsafe_to_char())
      }
      return Some(sb.to_string())
    } else if platform == 1 && fallback is None {
      let sb = StringBuilder()
      for k in 0..<len {
        sb.write_char(data[off + k].to_int().unsafe_to_char())
      }
      fallback = Some(sb.to_string())
    }
  }
  fallback
}

///|
/// The byte range of a glyph in the `glyf` table.
fn Font::glyph_range(self : Font, glyph : Int) -> (Int, Int)? {
  guard self.tables.get("head") is Some((head, _)) else { return None }
  guard self.tables.get("loca") is Some((loca, loca_len)) else { return None }
  guard self.tables.get("glyf") is Some((glyf, glyf_len)) else { return None }
  if glyph < 0 || glyph >= self.num_glyphs {
    return None
  }
  let long = rd_i16(self.data, head + 50) != 0
  if (if long { 4 } else { 2 }) * (glyph + 2) > loca_len {
    return None
  }
  let (start, end) = if long {
    (
      rd_u32(self.data, loca + 4 * glyph),
      rd_u32(self.data, loca + 4 * glyph + 4),
    )
  } else {
    (
      2 * rd_u16(self.data, loca + 2 * glyph),
      2 * rd_u16(self.data, loca + 2 * glyph + 2),
    )
  }
  if start < 0 || start > end || end > glyf_len {
    return None
  }
  Some((glyf + start, glyf + end))
}

///|
/// The component glyphs of a composite glyph.
fn Font::glyph_components(self : Font, glyph : Int) -> Array[Int] {
  let out = []
  guard self.glyph_range(glyph) is Some((start, end)) else { return out }
  if end - start < 10 || rd_i16(self.data, start) >= 0 {
    return out
  }
  let mut at = start + 10
  while at + 4 <= end {
    let flags = rd_u16(self.data, at)
    out.push(rd_u16(self.data, at + 2))
    at += 4
    at += if (flags & 0x0001) != 0 { 4 } else { 2 }
    if (flags & 0x0008) != 0 {
      at += 2
    } else if (flags & 0x0040) != 0 {
      at += 4
    } else if (flags & 0x0080) != 0 {
      at += 8
    }
    if (flags & 0x0020) == 0 {
      break
    }
  }
  out
}

///|
/// The bounding box stored in the header of a `glyf` glyph.
fn Font::glyph_bbox(
  self : Font,
  glyph : Int,
) -> (Double, Double, Double, Double)? {
  guard self.glyph_range(glyph) is Some((start, end)) else { return None }
  if end - start < 10 {
    return None
  }
  Some(
    (
      rd_i16(self.data, start + 2).to_double(),
      rd_i16(self.data, start + 4).to_double(),
      rd_i16(self.data, start + 6).to_double(),
      rd_i16(self.data, start + 8).to_double(),
    ),
  )
}

///|
/// The closure of a glyph set under composite glyph references (always
/// including `.notdef`).
fn Font::glyph_closure(self : Font, glyphs : Array[Int]) -> Map[Int, Unit] {
  let set : Map[Int, Unit] = { 0: () }
  let stack = glyphs.copy()
  while stack.pop() is Some(g) {
    if set.contains(g) && g != 0 {
      continue
    }
    set[g] = ()
    if self.kind == Glyf {
      for c in self.glyph_components(g) {
        if !set.contains(c) {
          stack.push(c)
        }
      }
    }
  }
  set
}

///|
fn checksum(data : Bytes) -> Int {
  let mut sum = 0L
  let mut i = 0
  while i < data.length() {
    let mut word = 0L
    for k in 0..<4 {
      word = (word << 8) |
        (if i + k < data.length() { data[i + k].to_int64() } else { 0L })
    }
    sum = (sum + word) & 0xFFFFFFFFL
    i += 4
  }
  sum.to_int()
}

///|
fn push_u16(buf : @buffer.Buffer, v : Int) -> Unit {
  buf.write_byte(((v >> 8) & 0xFF).to_byte())
  buf.write_byte((v & 0xFF).to_byte())
}

///|
fn push_u32(buf : @buffer.Buffer, v : Int) -> Unit {
  buf.write_byte(((v >> 24) & 0xFF).to_byte())
  buf.write_byte(((v >> 16) & 0xFF).to_byte())
  buf.write_byte(((v >> 8) & 0xFF).to_byte())
  buf.write_byte((v & 0xFF).to_byte())
}

///|
/// Subset a `glyf` font to the given glyphs (and their components),
/// keeping glyph IDs: glyphs outside the subset become empty.
fn Font::subset_glyf(self : Font, keep : Map[Int, Unit]) -> Bytes {
  // Rebuild glyf and loca (long format).
  let glyf = Buffer()
  let loca = Buffer()
  for g in 0..<self.num_glyphs {
    push_u32(loca, glyf.length())
    if keep.contains(g) && self.glyph_range(g) is Some((start, end)) {
      glyf.write_bytes(self.data[start:end].to_owned())
      while glyf.length() % 4 != 0 {
        glyf.write_byte(b'\x00')
      }
    }
  }
  push_u32(loca, glyf.length())
  let tables : Array[(String, Bytes)] = []
  for
    tag in [
      "OS/2", "cvt ", "fpgm", "glyf", "head", "hhea", "hmtx", "loca", "maxp", "prep",
    ] {
    match tag {
      "glyf" => tables.push((tag, glyf.to_bytes()))
      "loca" => tables.push((tag, loca.to_bytes()))
      _ =>
        if self.tables.get(tag) is Some((off, len)) {
          let bytes = self.data[off:off + len].to_owned()
          if tag == "head" {
            // Long loca format, zero checksum adjustment.
            let arr = bytes.to_array()
            if arr.length() >= 54 {
              arr[50] = b'\x00'
              arr[51] = b'\x01'
              arr[8] = b'\x00'
              arr[9] = b'\x00'
              arr[10] = b'\x00'
              arr[11] = b'\x00'
            }
            tables.push((tag, Bytes::from_array(arr)))
          } else {
            tables.push((tag, bytes))
          }
        }
    }
  }
  let n = tables.length()
  let mut entry_selector = 0
  while 1 << (entry_selector + 1) <= n {
    entry_selector += 1
  }
  let search_range = (1 << entry_selector) * 16
  let out = Buffer()
  push_u32(out, 0x00010000)
  push_u16(out, n)
  push_u16(out, search_range)
  push_u16(out, entry_selector)
  push_u16(out, n * 16 - search_range)
  let mut offset = 12 + 16 * n
  for t in tables {
    let (tag, bytes) = t
    for c in tag {
      out.write_byte(c.to_int().to_byte())
    }
    push_u32(out, checksum(bytes))
    push_u32(out, offset)
    push_u32(out, bytes.length())
    offset += (bytes.length() + 3) / 4 * 4
  }
  let mut head_at = -1
  for t in tables {
    if t.0 == "head" {
      head_at = out.length()
    }
    out.write_bytes(t.1)
    while out.length() % 4 != 0 {
      out.write_byte(b'\x00')
    }
  }
  let font = out.to_bytes()
  if head_at >= 0 {
    let adjust = (0xB1B0AFBAL - checksum(font).to_int64()) & 0xFFFFFFFFL
    let arr = font.to_array()
    let adjust = adjust.to_int()
    arr[head_at + 8] = ((adjust >> 24) & 0xFF).to_byte()
    arr[head_at + 9] = ((adjust >> 16) & 0xFF).to_byte()
    arr[head_at + 10] = ((adjust >> 8) & 0xFF).to_byte()
    arr[head_at + 11] = (adjust & 0xFF).to_byte()
    return Bytes::from_array(arr)
  }
  font
}

///|
/// The face's own sfnt data (extracted from a collection if necessary).
fn Font::face_data(self : Font) -> Bytes {
  if self.index == 0 &&
    !(self.data.length() >= 4 && rd_tag(self.data, 0) == "ttcf") {
    return self.data
  }
  let tags = self.tables.keys().collect()
  tags.sort()
  let n = tags.length()
  let mut entry_selector = 0
  while 1 << (entry_selector + 1) <= n {
    entry_selector += 1
  }
  let search_range = (1 << entry_selector) * 16
  let out = Buffer()
  let version = if self.kind == Cff || self.kind == Cff2 {
    0x4F54544F
  } else {
    0x00010000
  }
  push_u32(out, version)
  push_u16(out, n)
  push_u16(out, search_range)
  push_u16(out, entry_selector)
  push_u16(out, n * 16 - search_range)
  let mut offset = 12 + 16 * n
  for tag in tags {
    let (off, len) = self.tables.get(tag).unwrap()
    for c in tag {
      out.write_byte(c.to_int().to_byte())
    }
    push_u32(out, checksum(self.data[off:off + len].to_owned()))
    push_u32(out, offset)
    push_u32(out, len)
    offset += (len + 3) / 4 * 4
  }
  for tag in tags {
    let (off, len) = self.tables.get(tag).unwrap()
    out.write_bytes(self.data[off:off + len].to_owned())
    while out.length() % 4 != 0 {
      out.write_byte(b'\x00')
    }
  }
  out.to_bytes()
}

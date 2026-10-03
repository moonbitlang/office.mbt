// Port of subsetter 0.2.6 `src/lib.rs`.
//
// Reduces the size and coverage of OpenType fonts with TrueType or CFF
// outlines for embedding in PDFs. **Note that the resulting font subsets will
// most likely be unusable in any other contexts than PDF writing**, since a
// lot of information is removed from the font which is not necessary in PDFs.
//
// - You must write your fonts as a CID font: the `cmap` table is removed
//   from the font, so you must provide your own cmap table in the PDF.
// - Copyright information in the font is retained.
// - The subsetter converts SID-keyed CFF fonts to CID-keyed ones with an
//   identity mapping from GID to CID, so you can always use the remapped GID
//   as the CID of a glyph.

///|
/// Parsing failed because the font face is malformed.
pub(all) suberror SubsetError {
  /// The file contains an unknown kind of font.
  UnknownKind
  /// The font is malformed (or there is a bug in the font parsing logic).
  MalformedFont
  /// The font relies on an unimplemented feature, and thus the subsetting
  /// process couldn't be completed.
  Unimplemented
  /// An unexpected error occurred when subsetting the font. Indicates that
  /// there is a logical bug in the subsetter.
  SubsetError
  /// An overflow occurred during the computation. Could be either an issue
  /// with the font itself, or a bug in the subsetter logic.
  OverflowError
  /// An error occurred while processing the CFF table.
  CFFError
} derive(Eq)

///|
/// Upstream's `Display` messages.
pub impl Show for SubsetError with fn output(self, logger) {
  logger.write_string(
    match self {
      UnknownKind => "unknown font kind"
      MalformedFont => "malformed font"
      Unimplemented => "unsupported feature in font"
      SubsetError => "subsetting of font failed"
      OverflowError => "overflow occurred"
      CFFError => "processing CFF table failed"
    },
  )
}

///|
/// Subset the font face to include only the necessary glyphs and tables.
///
/// - The `data` must be in the OpenType font format.
/// - The `index` is only relevant if the data contains a font collection
///   (`.ttc` or `.otc` file). Otherwise, it should be 0.
///
/// CFF2 fonts are not supported.
pub fn subset(
  data : Bytes,
  index : Int,
  mapper : GlyphRemapper,
) -> Bytes raise SubsetError {
  subset_inner(data, index, [], false, mapper)
}

///|
/// Subset the font face to include only the necessary glyphs and tables,
/// instantiated to the given variation coordinates (axis tag and user-space
/// value).
///
/// This does the same as [subset], but allows you to specify variation
/// coordinates. If you pass a CFF2 font, it will be converted to a TrueType
/// font.
pub fn subset_with_variations(
  data : Bytes,
  index : Int,
  variation_coordinates : ArrayView[(Tag, Float)],
  mapper : GlyphRemapper,
) -> Bytes raise SubsetError {
  subset_inner(data, index, variation_coordinates, true, mapper)
}

///|
fn subset_inner(
  data : Bytes,
  index : Int,
  variation_coordinates : ArrayView[(Tag, Float)],
  allow_cff2 : Bool,
  mapper : GlyphRemapper,
) -> Bytes raise SubsetError {
  let mapper = mapper.copy()
  let context = prepare_context(
    data, index, variation_coordinates, allow_cff2, mapper,
  )
  subset_context(context)
}

///|
fn prepare_context(
  data : Bytes,
  index : Int,
  variation_coordinates : ArrayView[(Tag, Float)],
  allow_cff2 : Bool,
  gid_remapper : GlyphRemapper,
) -> Context raise SubsetError {
  let face = parse(data, index)
  let flavor = if face.table(Tag::glyf()) is Some(_) {
    TrueType
  } else if face.table(Tag::cff()) is Some(_) {
    Cff
  } else if face.table(Tag::cff2()) is Some(_) {
    // Only works if `variable-fonts` feature is enabled, as we need skrifa
    // so we can convert CFF2 into TrueType.
    if allow_cff2 {
      Cff2
    } else {
      raise Unimplemented
    }
  } else {
    raise UnknownKind
  }
  if flavor == TrueType {
    glyf_closure(face, gid_remapper)
  }
  // For CFF, we _always_ want to do normal subsetting, since CFF cannot have
  // variations. For TrueType, we prefer normal subsetting in case the
  // requested variation coordinates resolve to the default location. If we
  // do have variations, we use `skrifa` to instance. For CFF2, we _always_
  // use `skrifa` to instance.
  let interjector = if flavor == Cff {
    Dummy
  } else {
    guard SkrifaInterjector::new(data, index, variation_coordinates)
      is Some(interjector) else {
      raise MalformedFont
    }
    if flavor == TrueType && interjector.is_default_location() {
      Dummy
    } else {
      Skrifa(interjector)
    }
  }
  {
    face,
    mapper: gid_remapper,
    interjector,
    custom_maxp_data: None,
    custom_hmtx_data: None,
    flavor,
    tables: [],
    long_loca: false,
  }
}

///|
fn subset_context(ctx : Context) -> Bytes raise SubsetError {
  // See here for the required tables:
  // https://learn.microsoft.com/en-us/typography/opentype/spec/otff#required-tables
  // but some of those are not strictly needed according to the PDF
  // specification.

  // Of the above tables, we are not including the following ones:
  // - CFF2: Since we don't support CFF2
  // - VORG: PDF doesn't use that table.
  // - CMAP: CID fonts in PDF define their own cmaps, so we don't need to
  //   include them in the font.
  // - GASP: Not mandated by PDF specification, and ghostscript also seems to
  //   exclude them.
  // - OS2: Not mandated by PDF specification, and ghostscript also seems to
  //   exclude them.
  if ctx.flavor == TrueType {
    // LOCA will be handled by GLYF
    ctx.process(Tag::glyf())

    // Only copy hinting tables if we don't interject because skrifa will
    // discard hinting information.
    if !ctx.interjector.is_skrifa() {
      ctx.process(Tag::cvt()) // won't be subsetted.
      ctx.process(Tag::fpgm()) // won't be subsetted.
      ctx.process(Tag::prep()) // won't be subsetted.
    }
  } else if ctx.flavor == Cff {
    ctx.process(Tag::cff())
  } else if ctx.flavor == Cff2 {
    ctx.process(Tag::cff2())
  }

  // Required tables.
  ctx.process(Tag::head())
  ctx.process(Tag::hmtx())
  ctx.process(Tag::maxp())
  // NAME is also not strictly needed, and ghostscript removes it when
  // subsetting. However, it contains copyright information which probably
  // should not be removed... Even though it can free up a lot of space for
  // some fonts.
  ctx.process(Tag::name())
  ctx.process(Tag::post())
  construct(ctx)
}

///|
/// Parse a font face from OpenType data.
fn parse(data : Bytes, index : Int) -> Face raise SubsetError {
  let mut r = Reader::new(data)
  guard read_font_kind(r) is Some(kind) else { raise UnknownKind }
  let mut kind = kind
  // Parse font collection header if necessary.
  if kind == Collection {
    // (`12 + 4 * (index as usize)` with `index: u32`, in 64 bits.)
    let pos = 12UL + 4UL * index.reinterpret_as_uint().to_uint64()
    guard pos + 4UL <= data.length().to_uint64() else { raise MalformedFont }
    r = Reader::new_at(data, pos.to_int())
    guard r.read_u32() is Some(offset) else { raise MalformedFont }
    let offset = u32_offset(offset)
    guard offset <= data.length() else { raise MalformedFont }
    r = Reader::new(data[offset:])
    guard read_font_kind(r) is Some(k) else { raise MalformedFont }
    kind = k
    // Cannot have nested collection
    if kind == Collection {
      raise MalformedFont
    }
  }

  // Read number of table records.
  guard r.read_u16() is Some(count) else { raise MalformedFont }
  guard r.read_u16() is Some(_) else { raise MalformedFont }
  guard r.read_u16() is Some(_) else { raise MalformedFont }
  guard r.read_u16() is Some(_) else { raise MalformedFont }

  // Read table records.
  let records = []
  for _ in 0..<count {
    guard read_table_record(r) is Some(record) else { raise MalformedFont }
    records.push(record)
  }
  { data, records, }
}

///|
/// Construct a brand-new font.
fn construct(ctx : Context) -> Bytes {
  // (Tags are unique, so the stable sort by tag is a plain sort.)
  ctx.tables.sort_by((a, b) => Compare::compare(a.0, b.0))
  let w = Writer::new()
  w.write_u32(ctx.flavor.magic())

  // Write table directory.
  let count = ctx.tables.length()
  let entry_selector = if count == 0 {
    0
  } else {
    let mut e = 0
    while 1 << (e + 1) <= count {
      e += 1
    }
    e
  }
  let search_range = (1 << entry_selector) * 16
  let range_shift = (count * 16 - search_range) & 0xFFFF
  w.write_u16(count)
  w.write_u16(search_range)
  w.write_u16(entry_selector)
  w.write_u16(range_shift)

  // This variable will hold the offset to the checksum adjustment field in
  // the head table, which we'll have to write in the end (after checksumming
  // the whole font).
  let mut checksum_adjustment_offset = None

  // Write table records.
  let mut offset = 12 + ctx.tables.length() * 16
  for i, entry in ctx.tables {
    let (tag, data) = entry
    let data = if tag == Tag::head() {
      // Zero out checksum field in head table. The head table has already
      // been subset and is guaranteed to have the necessary minimum size.
      let arr = data.to_array()
      for k in 8..<12 {
        arr[k] = 0
      }
      checksum_adjustment_offset = Some(offset + 8)
      let zeroed = Bytes::from_array(arr)
      ctx.tables[i] = (tag, zeroed)
      zeroed[:]
    } else {
      data
    }
    let len = data.length()
    w.write_bytes(tag.bytes)
    w.write_u32(checksum(data))
    w.write_u32(offset.reinterpret_as_uint())
    w.write_u32(len.reinterpret_as_uint())

    // Increase offset, plus padding zeros to align to 4 bytes.
    offset += len
    while offset % 4 != 0 {
      offset += 1
    }
  }

  // Write tables.
  for entry in ctx.tables {
    // Write data plus padding zeros to align to 4 bytes.
    w.write_bytes(entry.1)
    w.align(4)
  }

  // Write checksum adjustment field in head table.
  let data = w.finish()
  match checksum_adjustment_offset {
    Some(i) => {
      let sum = checksum(data)
      let val = 0xB1B0AFBAU - sum
      let arr = data.to_array()
      arr[i] = (val >> 24).to_byte()
      arr[i + 1] = ((val >> 16) & 0xFF).to_byte()
      arr[i + 2] = ((val >> 8) & 0xFF).to_byte()
      arr[i + 3] = (val & 0xFF).to_byte()
      Bytes::from_array(arr)
    }
    None => data
  }
}

///|
/// Calculate a checksum over the sliced data as a sum of u32s. If the data
/// length is not a multiple of four, it is treated as if padded with zero to
/// a length that is a multiple of four.
fn checksum(data : BytesView) -> UInt {
  let mut sum = 0U
  let n = data.length()
  let mut i = 0
  while i + 4 <= n {
    sum = sum +
      (
        (data[i].to_uint() << 24) |
        (data[i + 1].to_uint() << 16) |
        (data[i + 2].to_uint() << 8) |
        data[i + 3].to_uint()
      )
    i += 4
  }
  if i < n {
    let mut word = 0U
    for k in 0..<4 {
      word = (word << 8) | (if i + k < n { data[i + k].to_uint() } else { 0U })
    }
    sum = sum + word
  }
  sum
}

///|
/// The flavor of outlines used by the font.
priv enum FontFlavor {
  /// TrueType fonts using the `glyf` table.
  TrueType
  /// CFF fonts using the `CFF` table.
  Cff
  /// CFF2 fonts using the `CFF2` table.
  Cff2
} derive(Eq)

///|
fn FontFlavor::magic(self : FontFlavor) -> UInt {
  match self {
    // Important note: This is the magic for TrueType and not CFF2. However,
    // CFF2 fonts will be converted to TrueType as part of the subsetting
    // process, hence we write the same magic.
    TrueType | Cff2 => 0x00010000
    Cff => 0x4F54544F
  }
}

///|
/// Subsetting context.
priv struct Context {
  /// Original face.
  face : Face
  /// A map from old gids to new gids, and the reverse.
  mapper : GlyphRemapper
  /// The font flavor.
  flavor : FontFlavor
  /// Subsetted tables.
  tables : Array[(Tag, BytesView)]
  /// An object that can _interject_ data during the subsetting process.
  /// Normally, when subsetting CFF/TrueType fonts, we will simply read the
  /// corresponding data from the old font and rewrite it to the new font,
  /// for example when writing the `hmtx` table.
  ///
  /// However, in case we are subsetting with variation coordinates, we
  /// instead rely on skrifa to apply the variation coordinates and interject
  /// that data during the subsetting process instead of using the data from
  /// the old font.
  interjector : Interjector
  /// Custom data that should be used for writing the `maxp` table. Only
  /// needed for CFF2, where we need to synthesize a V1 table after
  /// converting.
  mut custom_maxp_data : MaxpData?
  mut custom_hmtx_data : Array[(Int, Int)]?
  /// Whether the long loca format was chosen.
  mut long_loca : Bool
}

///|
/// Expect a table.
fn Context::expect_table(self : Context, tag : Tag) -> BytesView? {
  self.face.table(tag)
}

///|
/// Process a table.
fn Context::process(self : Context, tag : Tag) -> Unit raise SubsetError {
  guard self.face.table(tag) is Some(data) else { return }
  if tag == Tag::glyf() {
    glyf_subset(self)
  } else if tag == Tag::cff() {
    cff_subset(self)
  } else if tag == Tag::cff2() {
    cff2_subset(self)
  } else if tag == Tag::head() {
    head_subset(self)
  } else if tag == Tag::hmtx() {
    hmtx_subset(self)
  } else if tag == Tag::post() {
    post_subset(self)
  } else if tag == Tag::maxp() {
    maxp_subset(self)
  } else if tag == Tag::name() {
    name_subset(self)
  } else {
    self.push(tag, data)
  }
}

///|
/// Push a subsetted table.
fn Context::push(self : Context, tag : Tag, table : BytesView) -> Unit {
  self.tables.push((tag, table))
}

///|
/// A font face with OpenType tables.
priv struct Face {
  data : Bytes
  records : Array[TableRecord]
}

///|
fn Face::table(self : Face, tag : Tag) -> BytesView? {
  guard binary_search_by(self.records, record => {
      Compare::compare(record.tag, tag)
    })
    is Ok(i) else {
    return None
  }
  let record = self.records[i]
  let start = record.offset.to_uint64()
  let end = start + record.length.to_uint64()
  if end <= self.data.length().to_uint64() {
    Some(self.data[start.to_int():end.to_int()])
  } else {
    None
  }
}

///|
/// Rust's `slice::binary_search_by` (std 1.89): the probed indices depend
/// only on the length of the slice, which matters for unsorted or duplicate
/// entries.
fn[T] binary_search_by(xs : Array[T], f : (T) -> Int) -> Result[Int, Int] {
  let mut size = xs.length()
  if size == 0 {
    return Err(0)
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    let cmp = f(xs[mid])
    base = if cmp > 0 { base } else { mid }
    size -= half
  }
  let cmp = f(xs[base])
  if cmp == 0 {
    Ok(base)
  } else {
    Err(base + (if cmp < 0 { 1 } else { 0 }))
  }
}

///|
/// Whether the font is a font collection or a single font.
priv enum FontKind {
  /// A font collection.
  Collection
  /// A single font.
  Single
} derive(Eq)

///|
fn read_font_kind(r : Reader) -> FontKind? {
  guard r.read_u32() is Some(v) else { return None }
  match v {
    // TrueType
    0x00010000 | 0x74727565 => Some(Single)
    // CFF
    0x4F54544F => Some(Single)
    0x74746366 => Some(Collection)
    _ => None
  }
}

///|
/// A 4-byte OpenType tag.
pub struct Tag {
  priv bytes : Bytes
} derive(Eq, Hash)

///|
/// Create a tag from its four bytes (`None` for another length).
pub fn Tag::from_bytes(tag : BytesView) -> Tag? {
  if tag.length() == 4 {
    Some({ bytes: tag.to_owned(), })
  } else {
    None
  }
}

///|
/// Tries to create a new tag from a string. Returns `None` if the string is
/// not 4 bytes in size.
pub fn Tag::from_str(s : StringView) -> Tag? {
  let bytes = []
  for c in s {
    let cp = c.to_int()
    if cp >= 0x80 {
      // (Rust: the UTF-8 length of the string must be 4.)
      return None
    }
    bytes.push(cp.to_byte())
  }
  if bytes.length() == 4 {
    Some({ bytes: Bytes::from_array(bytes), })
  } else {
    None
  }
}

///|
/// Return the value of the tag.
pub fn Tag::get(self : Tag) -> Bytes {
  self.bytes
}

///|
pub impl Compare for Tag with fn compare(self, other) {
  for i in 0..<4 {
    let c = self.bytes[i].compare(other.bytes[i])
    if c != 0 {
      return c
    }
  }
  0
}

///|
pub impl Show for Tag with fn output(self, logger) {
  for b in self.bytes {
    logger.write_char(b.to_int().unsafe_to_char())
  }
}

///|
fn Tag::of(s : String) -> Tag {
  Tag::from_str(s).unwrap()
}

// General tables.

///|
fn Tag::head() -> Tag {
  tag_head
}

///|
let tag_head : Tag = Tag::of("head")

///|
let tag_hhea : Tag = Tag::of("hhea")

///|
let tag_hmtx : Tag = Tag::of("hmtx")

///|
let tag_maxp : Tag = Tag::of("maxp")

///|
let tag_name : Tag = Tag::of("name")

///|
let tag_post : Tag = Tag::of("post")

///|
let tag_glyf : Tag = Tag::of("glyf")

///|
let tag_loca : Tag = Tag::of("loca")

///|
let tag_prep : Tag = Tag::of("prep")

///|
let tag_fpgm : Tag = Tag::of("fpgm")

///|
let tag_cvt : Tag = Tag::of("cvt ")

///|
let tag_cff : Tag = Tag::of("CFF ")

///|
let tag_cff2 : Tag = Tag::of("CFF2")

///|
fn Tag::hhea() -> Tag {
  tag_hhea
}

///|
fn Tag::hmtx() -> Tag {
  tag_hmtx
}

///|
fn Tag::maxp() -> Tag {
  tag_maxp
}

///|
fn Tag::name() -> Tag {
  tag_name
}

///|
fn Tag::post() -> Tag {
  tag_post
}

///|
fn Tag::glyf() -> Tag {
  tag_glyf
}

///|
fn Tag::loca() -> Tag {
  tag_loca
}

///|
fn Tag::prep() -> Tag {
  tag_prep
}

///|
fn Tag::fpgm() -> Tag {
  tag_fpgm
}

///|
fn Tag::cvt() -> Tag {
  tag_cvt
}

///|
fn Tag::cff() -> Tag {
  tag_cff
}

///|
fn Tag::cff2() -> Tag {
  tag_cff2
}

///|
/// Locates a table in the font file.
priv struct TableRecord {
  tag : Tag
  offset : UInt
  length : UInt
}

///|
fn read_table_record(r : Reader) -> TableRecord? {
  guard r.read_bytes(4) is Some(tag) else { return None }
  // (The checksum is not checked.)
  guard r.read_u32() is Some(_) else { return None }
  guard r.read_u32() is Some(offset) else { return None }
  guard r.read_u32() is Some(length) else { return None }
  Some({ tag: { bytes: tag.to_owned(), }, offset, length, })
}

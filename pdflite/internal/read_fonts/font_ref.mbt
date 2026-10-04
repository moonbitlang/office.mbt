// Port of read-fonts 0.39.2 `src/lib.rs` (FileRef, CollectionRef, FontRef),
// `src/table_provider.rs` and the table directory from `generated/font.rs`.

///|
using @font_types {type GlyphId, type Tag, type Fixed, type F2Dot14}

///|
/// The sfnt version of TrueType fonts (0x00010000).
pub const TT_SFNT_VERSION : UInt = 0x00010000

///|
/// The sfnt version of CFF fonts ('OTTO').
pub const CFF_SFNT_VERSION : UInt = 0x4F54544F

///|
/// The sfnt version of Apple TrueType fonts ('true').
pub const TRUE_SFNT_VERSION : UInt = 0x74727565

///|
/// The TTC header tag ('ttcf').
pub const TTC_HEADER_TAG : UInt = 0x74746366

///|
/// The OpenType table directory.
pub struct TableDirectory {
  data : FontData
}

///|
fn TableDirectory::read(data : FontData) -> TableDirectory raise ReadError {
  if data.len() < 12 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn TableDirectory::sfnt_version(self : TableDirectory) -> UInt {
  self.data.read_u32(0) catch {
    _ => 0
  }
}

///|
pub fn TableDirectory::num_tables(self : TableDirectory) -> Int {
  self.data.read_u16(4) catch {
    _ => 0
  }
}

///|
/// The raw table records (16 bytes each); empty if out of bounds.
fn TableDirectory::records(self : TableDirectory) -> FontData {
  self.data.read_array(12, self.num_tables(), 16) catch {
    _ => FontData::empty()
  }
}

///|
/// A table record: (tag, checksum, offset, length).
pub(all) struct TableRecord {
  tag : Tag
  checksum : UInt
  offset : UInt
  length : UInt
} derive(Debug)

///|
pub fn TableDirectory::table_records(
  self : TableDirectory,
) -> Array[TableRecord] {
  let recs = self.records()
  let n = recs.len() / 16
  let result = []
  for i in 0..<n {
    let p = i * 16
    result.push({
      tag: Tag::from_u32(u32_at(recs, p)),
      checksum: u32_at(recs, p + 4),
      offset: u32_at(recs, p + 8),
      length: u32_at(recs, p + 12),
    })
  }
  result
}

///|
fn TableDirectory::is_sorted(self : TableDirectory) -> Bool {
  let mut last_tag = 0U
  for rec in self.table_records() {
    let tag = rec.tag.to_u32()
    if tag <= last_tag {
      return false
    }
    last_tag = tag
  }
  true
}

///|
/// Reference to an in-memory font.
pub struct FontRef {
  data : FontData
  table_directory : TableDirectory
  priv records : Array[TableRecord]
  /// The index of this font in a TrueType collection
  ttc_index : Int
  /// Whether this font is a member of a TrueType collection.
  in_ttc : Bool
  priv table_directory_sorted : Bool
}

///|
/// Creates a new reference to an in-memory font backed by the given data.
///
/// The data must be a single font (not a font collection).
pub fn FontRef::new(data : BytesView) -> FontRef raise ReadError {
  let data = FontData::new(data)
  FontRef::with_table_directory(data, TableDirectory::read(data), None)
}

///|
/// Creates a new reference to an in-memory font at the specified index
/// backed by the given data.
///
/// This accepts either font collection (ttc) or single font (ttf/otf)
/// files. If a single font file is provided, the index parameter must be 0.
pub fn FontRef::from_index(
  data : BytesView,
  index : Int,
) -> FontRef raise ReadError {
  // FileRef::new
  match collection_new(data) {
    Some(collection) => collection_get(collection, index)
    None => {
      let font = FontRef::new(data)
      if index == 0 {
        font
      } else {
        raise InvalidCollectionIndex(index.reinterpret_as_uint())
      }
    }
  }
}

///|
/// Returns `Some(data)` if the data starts with a valid TTC header.
fn collection_new(data : BytesView) -> FontData? {
  let data = FontData::new(data)
  // TTCHeader MIN_SIZE: tag + version + num_fonts
  if data.len() < 12 {
    return None
  }
  let tag = data.read_u32(0) catch { _ => return None }
  if tag != TTC_HEADER_TAG {
    None
  } else {
    Some(data)
  }
}

///|
fn collection_get(data : FontData, index : Int) -> FontRef raise ReadError {
  let num_fonts = data.read_u32(8)
  let offsets = data.read_array(12, num_fonts.reinterpret_as_int(), 4) catch {
    _ => FontData::empty()
  }
  let count = offsets.len() / 4
  if index < 0 || index >= count {
    raise InvalidCollectionIndex(index.reinterpret_as_uint())
  }
  let offset = offsets.read_u32(index * 4)
  if offset > data.len().reinterpret_as_uint() {
    raise OutOfBounds
  }
  let table_dir_data = data.split_off(offset.reinterpret_as_int()).unwrap()
  FontRef::with_table_directory(
    data,
    TableDirectory::read(table_dir_data),
    Some(index),
  )
}

///|
fn FontRef::with_table_directory(
  data : FontData,
  table_directory : TableDirectory,
  ttc_index : Int?,
) -> FontRef raise ReadError {
  let v = table_directory.sfnt_version()
  if v == TT_SFNT_VERSION || v == CFF_SFNT_VERSION || v == TRUE_SFNT_VERSION {
    {
      data,
      table_directory,
      records: table_directory.table_records(),
      ttc_index: ttc_index.unwrap_or(0),
      in_ttc: ttc_index is Some(_),
      table_directory_sorted: table_directory.is_sorted(),
    }
  } else {
    raise InvalidSfnt(v)
  }
}

///|
/// Returns the underlying font data.
pub fn FontRef::data(self : FontRef) -> FontData {
  self.data
}

///|
/// If the font is in a TrueType collection (ttc) file, returns the index
/// of the font in that collection.
pub fn FontRef::ttc_index(self : FontRef) -> Int? {
  if self.in_ttc {
    Some(self.ttc_index)
  } else {
    None
  }
}

///|
pub fn FontRef::table_directory(self : FontRef) -> TableDirectory {
  self.table_directory
}

///|
/// Returns the data for the table with the specified tag, if present.
pub fn FontRef::table_data(self : FontRef, tag : Tag) -> FontData? {
  let tag = tag.to_u32()
  let recs = self.records
  let entry = if self.table_directory_sorted {
    // binary search
    let mut lo = 0
    let mut hi = recs.length()
    let mut found : Int? = None
    while lo < hi {
      let mid = lo + (hi - lo) / 2
      let t = recs[mid].tag.to_u32()
      if t < tag {
        lo = mid + 1
      } else if t > tag {
        hi = mid
      } else {
        found = Some(mid)
        break
      }
    }
    found
  } else {
    let mut found : Int? = None
    for i, rec in recs {
      if rec.tag.to_u32() == tag {
        found = Some(i)
        break
      }
    }
    found
  }
  guard entry is Some(idx) else { return None }
  let record = recs[idx]
  if record.offset == 0U {
    return None
  }
  let start = record.offset.to_uint64()
  let end = start + record.length.to_uint64()
  if end > self.data.len().to_uint64() {
    return None
  }
  self.data.slice(start.to_int(), end.to_int())
}

///|
/// Returns the data for the table with the given 4-character tag.
pub fn FontRef::data_for_tag(self : FontRef, tag : String) -> FontData? {
  self.table_data(Tag::new(tag))
}

///|
fn FontRef::expect_data_for_tag(
  self : FontRef,
  tag : String,
) -> FontData raise ReadError {
  match self.table_data(Tag::new(tag)) {
    Some(d) => d
    None => raise TableIsMissing(Tag::new(tag))
  }
}

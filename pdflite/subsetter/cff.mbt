// Port of subsetter 0.2.6 `src/cff/mod.rs`, `src/cff/dict/top_dict.rs`,
// `src/cff/dict/font_dict.rs`, `src/cff/dict/private_dict.rs`,
// `src/cff/cid_font.rs`, `src/cff/sid_font.rs`, `src/cff/charset.rs` and
// `src/cff/remapper.rs` (the parsing logic was taken from ttf-parser).
//
// The charstrings are desubroutinized and the font is always written as a
// CID-keyed font whose CIDs are the new glyph IDs.

///|
priv enum CffFontKind {
  Sid(SIDMetadata)
  Cid(CIDMetadata)
}

///|
priv struct CffTable {
  names : BytesView
  top_dict_data : TopDictData
  strings : Index
  global_subrs : Index
  char_strings : Index
  font_kind : CffFontKind
}

///|
/// An offset that needs to be written after the whole font has been
/// written. `location` indicates where in the buffer the offset needs to be
/// written to and `value` indicates the value of the offset.
priv struct DeferredOffset {
  mut location : Int
  mut value : Int
}

///|
/// This represents a not-existing offset.
fn DeferredOffset::dummy() -> DeferredOffset {
  { location: 0, value: 0, }
}

///|
fn DeferredOffset::is_dummy(self : DeferredOffset) -> Bool {
  self.location == 0 && self.value == 0
}

///|
fn DeferredOffset::update_value(
  self : DeferredOffset,
  value : Int,
) -> Unit raise SubsetError {
  // (`i32::try_from(usize)`: buffer lengths are below 2^31.)
  if value < 0 {
    raise OverflowError
  }
  self.value = value
}

///|
/// Adjust the location of an offset, if it has been set (i.e. it's not a
/// dummy offset).
fn DeferredOffset::adjust_location(self : DeferredOffset, delta : Int) -> Unit {
  if !self.is_dummy() {
    self.location += delta
  }
}

///|
fn DeferredOffset::update_location(
  self : DeferredOffset,
  location : Int,
) -> Unit {
  self.location = location
}

///|
/// Write the deferred offset into a buffer (always using 5 bytes, to
/// prevent its size from changing).
fn DeferredOffset::write_into(
  self : DeferredOffset,
  buffer : FixedArray[Byte],
) -> Unit raise SubsetError {
  if self.location < 0 || self.location + 5 > buffer.length() {
    raise SubsetError
  }
  let v = self.value
  buffer[self.location] = 29
  buffer[self.location + 1] = ((v >> 24) & 0xFF).to_byte()
  buffer[self.location + 2] = ((v >> 16) & 0xFF).to_byte()
  buffer[self.location + 3] = ((v >> 8) & 0xFF).to_byte()
  buffer[self.location + 4] = (v & 0xFF).to_byte()
}

///|
/// Keeps track of the offsets that need to be written in the font.
priv struct Offsets {
  /// Offset of the charset data.
  charset_offset : DeferredOffset
  /// Offset of the charstrings data.
  char_strings_offset : DeferredOffset
  /// Lengths of the private dicts (not strictly an offset, but we still use
  /// it for simplicity).
  private_dicts_lens : Array[DeferredOffset]
  /// Offset of the private dicts.
  private_dicts_offsets : Array[DeferredOffset]
  /// Offset of the fd array.
  fd_array_offset : DeferredOffset
  /// Offset of the fd select.
  fd_select_offset : DeferredOffset
}

///|
fn Offsets::new_cid(num_font_dicts : Int) -> Offsets {
  {
    char_strings_offset: DeferredOffset::dummy(),
    charset_offset: DeferredOffset::dummy(),
    private_dicts_lens: Array::makei(num_font_dicts, _ => {
      DeferredOffset::dummy()
    }),
    private_dicts_offsets: Array::makei(num_font_dicts, _ => {
      DeferredOffset::dummy()
    }),
    fd_select_offset: DeferredOffset::dummy(),
    fd_array_offset: DeferredOffset::dummy(),
  }
}

///|
fn Offsets::new_sid() -> Offsets {
  Offsets::new_cid(1)
}

///|
fn cff_subset(ctx : Context) -> Unit raise SubsetError {
  let table = CffTable::parse(ctx)

  // Note: The charstrings are already in the new order that they need be
  // written in.
  let (char_strings, fd_remapper) = subset_charstrings(table, ctx.mapper)
  guard get_sid_remapper(table, fd_remapper) is Some(sid_remapper) else {
    raise SubsetError
  }
  let offsets = match table.font_kind {
    Sid(_) => Offsets::new_sid()
    Cid(_) => Offsets::new_cid(fd_remapper.len())
  }
  let w = Writer::new()
  // HEADER
  // We always use OffSize 4 (but as far as I can tell this field is unused
  // anyway).
  w.write_u8(1)
  w.write_u8(0)
  w.write_u8(4)
  w.write_u8(4)
  // Name INDEX
  w.write_bytes(table.names)
  // Top DICT INDEX
  rewrite_top_dict_index(table.top_dict_data, offsets, sid_remapper, w)
  // String INDEX
  let index = create_index(sid_remapper.sorted_strings())
  w.write_bytes(index.data)
  // Global Subr INDEX
  // We desubroutinized, so no global subroutines and thus empty index.
  w.write_bytes(OwnedIndex::default().data)

  // Charsets
  offsets.charset_offset.update_value(w.len())
  rewrite_charset(ctx.mapper, w)

  // Private dicts.
  match table.font_kind {
    // Since we convert SID-keyed to CID-keyed, we write one private dict
    // with index 0.
    Sid(sid) => rewrite_private_dict(offsets, sid.private_dict_data, w, 0)
    Cid(cid) => rewrite_cid_private_dicts(fd_remapper, offsets, cid, w)
  }

  // FDSelect
  offsets.fd_select_offset.update_value(w.len())
  match table.font_kind {
    Sid(_) => generate_fd_index(ctx.mapper, w)
    Cid(cid_metadata) =>
      rewrite_fd_index(ctx.mapper, cid_metadata.fd_select, fd_remapper, w)
  }

  // FDArray
  offsets.fd_array_offset.update_value(w.len())
  match table.font_kind {
    Sid(_) => generate_font_dict_index(offsets, w)
    Cid(cid_metadata) =>
      rewrite_font_dict_index(
        fd_remapper,
        sid_remapper,
        offsets,
        cid_metadata,
        w,
        table.top_dict_data.font_matrix is None,
      )
  }

  // Charstrings INDEX
  offsets.char_strings_offset.update_value(w.len())
  w.write_bytes(create_index(char_strings.map(b => b)).data)
  if w.failed {
    // (Upstream panics when writing a non-finite real number.)
    raise SubsetError
  }
  let subsetted_font = FixedArray::from_iter(w.finish().iter())

  // Rewrite the dummy offsets.
  update_offsets(offsets, subsetted_font)
  ctx.push(Tag::cff(), Bytes::from_iter(subsetted_font.iter()))
}

///|
fn update_offsets(
  offsets : Offsets,
  buffer : FixedArray[Byte],
) -> Unit raise SubsetError {
  let write = (offset : DeferredOffset) => {
    if !offset.is_dummy() {
      offset.write_into(buffer)
    }
  }

  // Private dicts offset have already been written correctly, so no need to
  // write them here.
  write(offsets.charset_offset)
  write(offsets.char_strings_offset)
  write(offsets.fd_select_offset)
  write(offsets.fd_array_offset)
}

///|
/// Create the list of bytes that constitute the programs of the charstrings,
/// sorted in the new glyph order.
fn subset_charstrings(
  table : CffTable,
  remapper : GlyphRemapper,
) -> (Array[Bytes], Remapper) raise SubsetError {
  let gsubrs = SubroutineHandler::new(table.global_subrs.items())
  let lsubrs = match table.font_kind {
    Cid(cid) =>
      cid.font_dicts.map(font_dict => {
        SubroutineHandler::new(font_dict.local_subrs.items())
      })
    Sid(sid) => [SubroutineHandler::new(sid.local_subrs.items())]
  }
  let used_fds : Map[Int, Unit] = Map([])
  let char_strings = []
  for old_gid in remapper.remapped_gids() {
    let fd_index = match table.font_kind {
      Cid(cid) => {
        guard cid.fd_select.font_dict_index(old_gid) is Some(fd_index) else {
          raise MalformedFont
        }
        used_fds[fd_index] = ()
        fd_index
      }
      Sid(_) => 0
    }
    guard fd_index < lsubrs.length() else { raise MalformedFont }
    let decompiler = Decompiler::new(gsubrs, lsubrs[fd_index])
    guard table.char_strings.get(old_gid) is Some(charstring) else {
      raise MalformedFont
    }
    char_strings.push(decompiler.decompile(charstring))
  }
  let fd_remapper = Remapper::new(0x100)
  let sorted = used_fds.keys().collect()
  sorted.sort()
  for fd in sorted {
    fd_remapper.remap(fd) |> ignore
  }
  (char_strings.map(compile_program), fd_remapper)
}

///|
fn get_sid_remapper(table : CffTable, fd_remapper : Remapper) -> SidRemapper? {
  let sid_remapper = SidRemapper::new()
  sid_remapper.remap(b"Adobe") |> ignore
  sid_remapper.remap(b"Identity") |> ignore
  let remap_sid = (sid : Int) => {
    if is_standard_string(sid) {
      Some(())
    } else {
      match table.strings.get(sid - STANDARD_STRING_LEN) {
        Some(string) => {
          sid_remapper.remap_with_old_sid(sid, string.to_owned()) |> ignore
          Some(())
        }
        None => None
      }
    }
  }
  if table.top_dict_data.copyright is Some(copyright) {
    guard remap_sid(copyright) is Some(_) else { return None }
  }
  if table.top_dict_data.font_name is Some(font_name) {
    guard remap_sid(font_name) is Some(_) else { return None }
  }
  if table.top_dict_data.notice is Some(notice) {
    guard remap_sid(notice) is Some(_) else { return None }
  }
  if table.font_kind is Cid(cid) {
    for font_dict in fd_remapper.sorted_iter() {
      guard font_dict < cid.font_dicts.length() else { return None }
      if cid.font_dicts[font_dict].font_name is Some(font_name) {
        guard remap_sid(font_name) is Some(_) else { return None }
      }
    }
  }
  Some(sid_remapper)
}

///|
fn CffTable::parse(ctx : Context) -> CffTable raise SubsetError {
  guard ctx.expect_table(Tag::cff()) is Some(cff) else { raise MalformedFont }
  let r = Reader::new(cff)
  guard r.read_u8() is Some(major) else { raise MalformedFont }
  if major != 1 {
    raise CFFError
  }
  r.skip_bytes(1) // minor
  guard r.read_u8() is Some(header_size) else { raise MalformedFont }
  r.jump(header_size)
  let names_start = r.offset()
  guard skip_index(r) is Some(_) else { raise MalformedFont }
  guard names_start <= r.offset() && r.offset() <= cff.length() else {
    raise MalformedFont
  }
  let names = cff[names_start:r.offset()]
  guard parse_top_dict_index(r) is Some(top_dict_data) else {
    raise MalformedFont
  }
  guard parse_index(r) is Some(strings) else { raise MalformedFont }
  guard parse_index(r) is Some(global_subrs) else { raise MalformedFont }
  guard top_dict_data.char_strings is Some(char_strings_offset) else {
    raise MalformedFont
  }
  let char_strings = {
    let r = Reader::new_at(cff, char_strings_offset)
    guard parse_index(r) is Some(index) else { raise MalformedFont }
    index
  }
  let number_of_glyphs = char_strings.len()
  if number_of_glyphs == 0 || number_of_glyphs > 0xFFFF {
    raise MalformedFont
  }
  let font_kind = if top_dict_data.has_ros {
    guard parse_cid_metadata(cff, top_dict_data, number_of_glyphs) is Some(cid) else {
      raise MalformedFont
    }
    Cid(cid)
  } else {
    Sid(parse_sid_metadata(cff, top_dict_data))
  }
  { names, top_dict_data, strings, global_subrs, char_strings, font_kind, }
}

// --- remapper ---

///|
/// Remap old SIDs to new SIDs, and also allow the insertion of new strings.
priv struct SidRemapper {
  /// Next SID to be assigned.
  mut counter : Int
  /// The strings, ordered by their SID.
  strings : Array[Bytes]
  /// A map from strings to their corresponding SID.
  string_to_sid : Map[Bytes, Int]
  /// A map from old SIDs to new SIDs.
  old_sid_to_new_sid : Map[Int, Int]
}

///|
fn SidRemapper::new() -> SidRemapper {
  {
    counter: STANDARD_STRING_LEN,
    strings: [],
    string_to_sid: {},
    old_sid_to_new_sid: {},
  }
}

///|
fn SidRemapper::get(self : SidRemapper, string : Bytes) -> Int? {
  self.string_to_sid.get(string)
}

///|
/// Get the new SID to a corresponding old SID.
fn SidRemapper::get_new_sid(self : SidRemapper, sid : Int) -> Int? {
  self.old_sid_to_new_sid.get(sid)
}

///|
/// Remap a string.
fn SidRemapper::remap(self : SidRemapper, string : Bytes) -> Int {
  match self.string_to_sid.get(string) {
    Some(sid) => sid
    None => {
      let value = self.counter
      self.strings.push(string)
      if self.counter + 1 > 0xFFFF {
        abort("sid remapper overflowed")
      }
      self.counter += 1
      self.string_to_sid[string] = value
      value
    }
  }
}

///|
/// Remap an old SID and its corresponding string.
fn SidRemapper::remap_with_old_sid(
  self : SidRemapper,
  sid : Int,
  string : Bytes,
) -> Int {
  match self.old_sid_to_new_sid.get(sid) {
    Some(new_sid) => new_sid
    None => {
      let new_sid = self.remap(string)
      self.old_sid_to_new_sid[sid] = new_sid
      new_sid
    }
  }
}

///|
/// The strings, ordered by their new SID.
fn SidRemapper::sorted_strings(self : SidRemapper) -> Array[BytesView] {
  self.strings.map(s => s)
}

// --- charset ---

///|
/// Rewrite the charset of the font. We do not preserve the CID's from the
/// original font. Instead, we assign each glyph its new glyph ID as the CID.
/// This makes it easier to reference them from the PDF, since we know the
/// CID a glyph will have before it's subsetted.
fn rewrite_charset(gid_mapper : GlyphRemapper, w : Writer) -> Unit {
  if gid_mapper.num_gids() == 1 {
    // We only have .notdef, so use format 0.
    w.write_u8(0)
  } else {
    // Use format 2.
    w.write_u8(2)
    w.write_u16(1)
    // -2 because -1 for not including .notdef and -1 since the first glyph
    // in the range is not counted.
    w.write_u16(gid_mapper.num_gids() - 2)
  }
}

// --- top dict ---

///|
priv struct TopDictData {
  mut char_strings : Int?
  mut private : (Int, Int)?
  mut fd_array : Int?
  mut fd_select : Int?
  mut notice : Int?
  mut copyright : Int?
  mut font_name : Int?
  mut has_ros : Bool
  mut font_matrix : Array[Number]?
  mut font_bbox : Array[Number]?
}

///|
fn parse_top_dict_index(r : Reader) -> TopDictData? {
  let top_dict = TopDictData::{
    char_strings: None,
    private: None,
    fd_array: None,
    fd_select: None,
    notice: None,
    copyright: None,
    font_name: None,
    has_ros: false,
    font_matrix: None,
    font_bbox: None,
  }
  guard parse_index(r) is Some(index) else { return None }

  // The Top DICT INDEX should have only one dictionary in CFF fonts.
  guard index.get(0) is Some(data) else { return None }
  let dict_parser = DictionaryParser::new(data)
  while dict_parser.parse_next() is Some(operator) {
    // We only need to preserve the copyrights and font name.
    if operator == op_notice {
      guard dict_parser.parse_sid() is Some(v) else { return None }
      top_dict.notice = Some(v)
    } else if operator == op_copyright {
      guard dict_parser.parse_sid() is Some(v) else { return None }
      top_dict.copyright = Some(v)
    } else if operator == op_font_name {
      guard dict_parser.parse_sid() is Some(v) else { return None }
      top_dict.font_name = Some(v)
    } else if operator == op_charset {
      // (Only validated: the charset is rewritten.)
      guard dict_parser.parse_offset() is Some(_) else { return None }
    } else if operator == op_encoding {
      // We don't care about encoding since we convert to CID-keyed font
      // anyway.
      ()
    } else if operator == op_char_strings {
      guard dict_parser.parse_offset() is Some(v) else { return None }
      top_dict.char_strings = Some(v)
    } else if operator == op_private {
      guard dict_parser.parse_range() is Some(v) else { return None }
      top_dict.private = Some(v)
    } else if operator == op_ros {
      // We will rewrite the ROS, so no need to grab it from here. But we
      // need to register it, so we know we are dealing with a CID-keyed
      // font.
      top_dict.has_ros = true
    } else if operator == op_fd_array {
      guard dict_parser.parse_offset() is Some(v) else { return None }
      top_dict.fd_array = Some(v)
    } else if operator == op_fd_select {
      guard dict_parser.parse_offset() is Some(v) else { return None }
      top_dict.fd_select = Some(v)
    } else if operator == op_font_matrix {
      guard dict_parser.parse_font_matrix() is Some(v) else { return None }
      top_dict.font_matrix = Some(v)
    } else if operator == op_font_bbox {
      guard dict_parser.parse_font_bbox() is Some(v) else { return None }
      top_dict.font_bbox = Some(v)
    }
  }
  Some(top_dict)
}

///|
/// Rewrite the top dict. Implementation is based on what ghostscript seems
/// to keep when rewriting a font subset.
fn rewrite_top_dict_index(
  top_dict_data : TopDictData,
  offsets : Offsets,
  sid_remapper : SidRemapper,
  w : Writer,
) -> Unit raise SubsetError {
  let sub_w = Writer::new()

  // ROS.
  guard sid_remapper.get(b"Adobe") is Some(adobe) else { raise SubsetError }
  Number::from_i32(adobe).write(sub_w)
  guard sid_remapper.get(b"Identity") is Some(identity) else {
    raise SubsetError
  }
  Number::from_i32(identity).write(sub_w)
  Number::zero().write(sub_w)
  op_ros.write(sub_w)

  // Copyright notices.
  if top_dict_data.copyright is Some(s) &&
    sid_remapper.get_new_sid(s) is Some(copyright) {
    Number::from_i32(copyright).write(sub_w)
    op_copyright.write(sub_w)
  }
  if top_dict_data.notice is Some(s) &&
    sid_remapper.get_new_sid(s) is Some(notice) {
    Number::from_i32(notice).write(sub_w)
    op_notice.write(sub_w)
  }

  // Font name.
  if top_dict_data.font_name is Some(s) &&
    sid_remapper.get_new_sid(s) is Some(font_name) {
    Number::from_i32(font_name).write(sub_w)
    op_font_name.write(sub_w)
  }

  // See https://bugs.ghostscript.com/show_bug.cgi?id=690724#c12 and
  // https://leahneukirchen.org/blog/archive/2022/10/50-blank-pages-or-black-box-debugging-of-pdf-rendering-in-printers.html
  // We assume that if at least one font dict has a matrix, all of them do.
  // Case 1: Top DICT MATRIX is some, FONT DICT MATRIX is some -> supplied, supplied
  // Case 2: Top DICT MATRIX is none, FONT DICT MATRIX is some -> (0.001, 0, 0, 0.001, 0, 0), supplied * 1000
  // Case 3: Top DICT MATRIX is some, FONT DICT MATRIX is none -> supplied, (1, 0, 0, 1, 0, 0)
  // Case 4: Top DICT MATRIX is none, FONT DICT MATRIX is none -> (0.001, 0, 0, 0.001, 0 0), (1, 0, 0, 1, 0, 0)
  write_numbers(
    sub_w,
    top_dict_data.font_matrix.unwrap_or([
      Number::from_f32(0.001),
      Number::zero(),
      Number::zero(),
      Number::from_f32(0.001),
      Number::zero(),
      Number::zero(),
    ]),
  )
  op_font_matrix.write(sub_w)

  // Write a default font bbox, if it does not exist.
  write_numbers(
    sub_w,
    top_dict_data.font_bbox.unwrap_or([
      Number::zero(),
      Number::zero(),
      Number::zero(),
      Number::zero(),
    ]),
  )
  op_font_bbox.write(sub_w)

  // Note: When writing the offsets, we need to add the current length of w
  // AND sub_w.
  // Charset
  offsets.charset_offset.update_location(sub_w.len() + w.len())
  write_integer_5_bytes(0, sub_w)
  op_charset.write(sub_w)

  // Charstrings
  offsets.char_strings_offset.update_location(sub_w.len() + w.len())
  write_integer_5_bytes(0, sub_w)
  op_char_strings.write(sub_w)
  Number::from_i32(0xFFFF).write(sub_w)
  op_cid_count.write(sub_w)

  // Note: Previously, we wrote those two entries directly after ROS.
  // However, for some reason not known to me, Apple Preview does not like
  // show the CFF font at all if that's the case. This is why we now write
  // the offsets in the very end.

  // FD array.
  offsets.fd_array_offset.update_location(sub_w.len() + w.len())
  write_integer_5_bytes(0, sub_w)
  op_fd_array.write(sub_w)

  // FD select.
  offsets.fd_select_offset.update_location(sub_w.len() + w.len())
  write_integer_5_bytes(0, sub_w)
  op_fd_select.write(sub_w)
  if sub_w.failed {
    w.failed = true
  }
  let finished = sub_w.finish()

  // TOP DICT INDEX always has size 1 in CFF.
  let index = create_index([finished])

  // The offsets we calculated before were calculated under the assumption
  // that the contents of sub_w will be appended directly to w. However, when
  // we create an index, the INDEX header data will be appended in the
  // beginning, meaning that we need to adjust the offsets to account for
  // that.
  offsets.charset_offset.adjust_location(index.header_size)
  offsets.char_strings_offset.adjust_location(index.header_size)
  offsets.fd_array_offset.adjust_location(index.header_size)
  offsets.fd_select_offset.adjust_location(index.header_size)
  w.write_bytes(index.data)
}

// --- font dict ---

///|
/// A font DICT.
priv struct FontDict {
  /// The local subroutines that are linked in the font DICT.
  mut local_subrs : Index
  /// The underlying data of the private dict.
  mut private_dict : BytesView
  /// The StringID of the font name in this font DICT.
  mut font_name : Int?
  /// The font matrix.
  mut font_matrix : Array[Number]?
}

///|
fn parse_font_dict(
  font_data : BytesView,
  font_dict_data : BytesView,
) -> FontDict? {
  let font_dict = FontDict::{
    local_subrs: Index::default(),
    private_dict: b"",
    font_name: None,
    font_matrix: None,
  }
  let dict_parser = DictionaryParser::new(font_dict_data)
  while dict_parser.parse_next() is Some(operator) {
    if operator == op_private {
      guard dict_parser.parse_range() is Some((start, end)) else { return None }
      guard start <= end && end <= font_data.length() else { return None }
      let private_dict_data = font_data[start:end]
      font_dict.private_dict = private_dict_data
      font_dict.local_subrs = match parse_subr_offset(private_dict_data) {
        Some(subrs_offset) => {
          let s = start.to_int64() + subrs_offset.to_int64()
          guard s <= font_data.length().to_int64() else { return None }
          let r = Reader::new(font_data[s.to_int():])
          guard parse_index(r) is Some(index) else { return None }
          index
        }
        None => Index::default()
      }
    } else if operator == op_font_name {
      guard dict_parser.parse_sid() is Some(v) else { return None }
      font_dict.font_name = Some(v)
    } else if operator == op_font_matrix {
      guard dict_parser.parse_font_matrix() is Some(v) else { return None }
      font_dict.font_matrix = Some(v)
    }
  }
  Some(font_dict)
}

///|
/// Rewrite the font DICT INDEX for CID-keyed fonts.
fn rewrite_font_dict_index(
  fd_remapper : Remapper,
  sid_remapper : SidRemapper,
  offsets : Offsets,
  metadata : CIDMetadata,
  w : Writer,
  top_dict_is_missing_font_matrix : Bool,
) -> Unit raise SubsetError {
  let dicts = []
  for new_df, old_df in fd_remapper.sorted_iter() {
    guard old_df < metadata.font_dicts.length() else { raise SubsetError }
    let dict = metadata.font_dicts[old_df]
    let w = Writer::new()

    // See comment in `rewrite_top_dict_index`.
    let matrix = match dict.font_matrix {
      Some(m) =>
        if top_dict_is_missing_font_matrix {
          let scale = [
            Number::from_f32(1000.0),
            Number::zero(),
            Number::zero(),
            Number::from_f32(1000.0),
            Number::zero(),
            Number::zero(),
          ]
          Number::combine(m, scale)
        } else {
          m
        }
      None =>
        [
          Number::one(),
          Number::zero(),
          Number::zero(),
          Number::one(),
          Number::zero(),
          Number::zero(),
        ]
    }
    write_numbers(w, matrix)
    op_font_matrix.write(w)

    // Write the length and offset of the private dict.
    // Private dicts have already been written, so the offsets are already
    // correct. This means that these two offsets are a bit special compared
    // to the others, since we never use the `location` field of the offset
    // and we don't overwrite it like we do for the others.
    guard new_df < offsets.private_dicts_lens.length() else {
      raise SubsetError
    }
    write_integer_5_bytes(offsets.private_dicts_lens[new_df].value, w)
    write_integer_5_bytes(offsets.private_dicts_offsets[new_df].value, w)
    op_private.write(w)
    if dict.font_name is Some(s) &&
      sid_remapper.get_new_sid(s) is Some(font_name) {
      Number::from_i32(font_name).write(w)
      op_font_name.write(w)
    }
    if w.failed {
      raise SubsetError
    }
    dicts.push(w.finish()[:])
  }
  w.write_bytes(create_index(dicts).data)
}

///|
/// Generate a new font DICT INDEX for SID-keyed fonts.
fn generate_font_dict_index(
  offsets : Offsets,
  w : Writer,
) -> Unit raise SubsetError {
  let sub_w = Writer::new()

  // See comment in `rewrite_top_dict_index`
  write_numbers(sub_w, [
    Number::one(),
    Number::zero(),
    Number::zero(),
    Number::one(),
    Number::zero(),
    Number::zero(),
  ])
  op_font_matrix.write(sub_w)

  // Write the length and offset of the private dict.
  guard offsets.private_dicts_lens.length() > 0 else { raise SubsetError }
  write_integer_5_bytes(offsets.private_dicts_lens[0].value, sub_w)
  write_integer_5_bytes(offsets.private_dicts_offsets[0].value, sub_w)
  op_private.write(sub_w)
  w.write_bytes(create_index([sub_w.finish()]).data)
}

// --- private dict ---

///|
/// Parse the subroutine offset from a private dict.
fn parse_subr_offset(data : BytesView) -> Int? {
  let dict_parser = DictionaryParser::new(data)
  while dict_parser.parse_next() is Some(operator) {
    if operator == op_subrs {
      return dict_parser.parse_offset()
    }
  }
  None
}

///|
/// Write the private dicts of a CID font for each font dict.
fn rewrite_cid_private_dicts(
  fd_remapper : Remapper,
  offsets : Offsets,
  metadata : CIDMetadata,
  w : Writer,
) -> Unit raise SubsetError {
  for new_df, old_df in fd_remapper.sorted_iter() {
    guard old_df < metadata.font_dicts.length() else { raise SubsetError }
    let font_dict = metadata.font_dicts[old_df]
    rewrite_private_dict(offsets, font_dict.private_dict, w, new_df)
  }
}

///|
fn rewrite_private_dict(
  offsets : Offsets,
  private_dict_data : BytesView,
  w : Writer,
  dict_index : Int,
) -> Unit raise SubsetError {
  let private_dict_offset = w.len()
  let private_dict_data = {
    let dict_parser = DictionaryParser::new(private_dict_data)
    let sub_w = Writer::new()

    // We just make sure that no subroutine offset gets written, all other
    // operators stay the same.
    while dict_parser.parse_next() is Some(operator) {
      if operator == op_subrs {
        // We don't have any subroutines, so don't rewrite this DICT entry.
        ()
      } else {
        guard dict_parser.parse_operands() is Some(_) else {
          raise MalformedFont
        }
        write_numbers(sub_w, dict_parser.operands)
        operator.write(sub_w)
      }
    }
    if sub_w.failed {
      w.failed = true
    }
    sub_w.finish()
  }
  let private_dict_len = private_dict_data.length()
  guard dict_index < offsets.private_dicts_lens.length() else {
    raise SubsetError
  }
  offsets.private_dicts_lens[dict_index].update_value(private_dict_len)
  offsets.private_dicts_offsets[dict_index].update_value(private_dict_offset)
  w.write_bytes(private_dict_data)
}

// --- CID fonts ---

///|
/// Metadata necessary for processing CID-keyed fonts.
priv struct CIDMetadata {
  font_dicts : Array[FontDict]
  fd_select : FDSelect
}

///|
/// Parse CID metadata from a font.
fn parse_cid_metadata(
  data : BytesView,
  top_dict : TopDictData,
  number_of_glyphs : Int,
) -> CIDMetadata? {
  guard top_dict.fd_array is Some(fd_array_offset) &&
    top_dict.fd_select is Some(fd_select_offset) else {
    return None
  }
  let fd_array = {
    let r = Reader::new_at(data, fd_array_offset)
    guard parse_index(r) is Some(index) else { return None }
    index
  }
  let fd_select = {
    let s = Reader::new_at(data, fd_select_offset)
    guard parse_fd_select(number_of_glyphs, s) is Some(fd_select) else {
      return None
    }
    fd_select
  }
  let font_dicts = []
  for font_dict_data in fd_array.items() {
    guard parse_font_dict(data, font_dict_data) is Some(font_dict) else {
      return None
    }
    font_dicts.push(font_dict)
  }
  Some({ font_dicts, fd_select, })
}

///|
fn parse_fd_select(number_of_glyphs : Int, r : Reader) -> FDSelect? {
  guard r.read_u8() is Some(format) else { return None }
  match format {
    0 =>
      match r.read_array16(number_of_glyphs, 1) {
        Some(array) => Some(Format0(array))
        None => None
      }
    3 =>
      match r.tail() {
        Some(tail) => Some(Format3(tail))
        None => None
      }
    _ => None
  }
}

///|
priv enum FDSelect {
  Format0(LazyArray16)
  Format3(BytesView)
}

///|
/// Get the font dict index for a glyph.
fn FDSelect::font_dict_index(self : FDSelect, glyph_id : Int) -> Int? {
  match self {
    Format0(array) => array.get(glyph_id)
    Format3(data) => {
      let r = Reader::new(data)
      guard r.read_u16() is Some(number_of_ranges) else { return None }
      if number_of_ranges == 0 || number_of_ranges == 0xFFFF {
        return None
      }
      let number_of_ranges = number_of_ranges + 1
      guard r.read_u16() is Some(first) else { return None }
      guard r.read_u8() is Some(index) else { return None }
      let mut prev_first_glyph = first
      let mut prev_index = index
      for _ in 1..<number_of_ranges {
        guard r.read_u16() is Some(curr_first_glyph) else { return None }
        if prev_first_glyph <= glyph_id && glyph_id < curr_first_glyph {
          return Some(prev_index)
        } else {
          guard r.read_u8() is Some(index) else { return None }
          prev_index = index
        }
        prev_first_glyph = curr_first_glyph
      }
      None
    }
  }
}

///|
/// Rewrite the FD INDEX for CID-keyed font.
fn rewrite_fd_index(
  gid_remapper : GlyphRemapper,
  fd_select : FDSelect,
  fd_remapper : Remapper,
  w : Writer,
) -> Unit raise SubsetError {
  // We always use format 0, since it's the simplest.
  w.write_u8(0)
  for gid in gid_remapper.remapped_gids() {
    guard fd_select.font_dict_index(gid) is Some(old_fd) else {
      raise MalformedFont
    }
    guard fd_remapper.get(old_fd) is Some(new_fd) else { raise SubsetError }
    w.write_u8(new_fd)
  }
}

// --- SID fonts ---

///|
/// Metadata required for handling SID-keyed fonts.
priv struct SIDMetadata {
  local_subrs : Index
  private_dict_data : BytesView
}

///|
fn parse_sid_metadata(data : BytesView, top_dict : TopDictData) -> SIDMetadata {
  let default = SIDMetadata::{
    local_subrs: Index::default(),
    private_dict_data: b"",
  }
  guard top_dict.private is Some((start, end)) else { return default }
  guard start <= end && end <= data.length() else { return default }
  let private_dict_data = data[start:end]
  let local_subrs = match parse_subr_offset(private_dict_data) {
    Some(subrs_offset) => {
      let s = start.to_int64() + subrs_offset.to_int64()
      guard s <= data.length().to_int64() else { return default }
      let r = Reader::new(data[s.to_int():])
      guard parse_index(r) is Some(index) else { return default }
      index
    }
    None => Index::default()
  }
  { local_subrs, private_dict_data, }
}

///|
/// Write the FD INDEX for SID-keyed fonts. They all get mapped to the font
/// DICT 0.
fn generate_fd_index(gid_remapper : GlyphRemapper, w : Writer) -> Unit {
  // Format
  w.write_u8(3)
  // nRanges
  w.write_u16(1)
  // first
  w.write_u16(0)
  // fd index
  w.write_u8(0)
  // sentinel
  w.write_u16(gid_remapper.num_gids())
}

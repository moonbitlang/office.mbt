// Ports of subsetter 0.2.6 `src/head.rs`, `src/hmtx.rs`, `src/maxp.rs`,
// `src/name.rs` and `src/post.rs`.

// --- head ---
//
// The `head` table mostly contains information that can be reused from the
// old table, except for the `loca` format, which depends on the size of the
// glyph data. The checksum will be recalculated in the very end.

///|
fn head_subset(ctx : Context) -> Unit raise SubsetError {
  guard ctx.expect_table(Tag::head()) is Some(head) else { raise MalformedFont }
  if head.length() < 52 {
    raise MalformedFont
  }
  let head = head.to_bytes().to_array()
  head[50] = 0
  head[51] = if ctx.long_loca { 1 } else { 0 }
  ctx.push(Tag::head(), Bytes::from_array(head)[:])
}

// --- hmtx ---
//
// The `hmtx` table contains the horizontal metrics for each glyph. All we
// need to do is to rewrite the table so that it matches the sequence of the
// new glyphs. A minor pain point is that the table allows omitting the
// advance width for the last few glyphs if it is the same. In order to keep
// the code simple, we do not keep this optimization when rewriting the
// table. While doing so, we also rewrite the `hhea` table, which contains
// the number of glyphs that contain both, advance width and left side
// bearing metrics.

///|
fn hmtx_subset(ctx : Context) -> Unit raise SubsetError {
  guard ctx.expect_table(Tag::hmtx()) is Some(hmtx) else { raise MalformedFont }
  let new_metrics = match ctx.interjector {
    Dummy => extract_metrics(hmtx, ctx)
    Skrifa(_) => {
      guard ctx.custom_hmtx_data is Some(data) else { raise SubsetError }
      ctx.custom_hmtx_data = None
      data
    }
  }

  // Find out the last index we need to include the advance width for.
  if new_metrics.length() > 0x10000 || new_metrics.length() == 0 {
    raise OverflowError
  }
  let mut last_advance_width_index = new_metrics.length() - 1
  let last_advance_width = new_metrics[last_advance_width_index].0
  for i = new_metrics.length() - 2; i >= 0; i = i - 1 {
    if new_metrics[i].0 == last_advance_width {
      last_advance_width_index -= 1
    } else {
      break
    }
  }
  let sub_hmtx = Writer::new()
  for index, metric in new_metrics {
    if index <= last_advance_width_index {
      sub_hmtx.write_u16(metric.0)
    }
    sub_hmtx.write_i16(metric.1)
  }
  ctx.push(Tag::hmtx(), sub_hmtx.finish()[:])
  guard ctx.expect_table(Tag::hhea()) is Some(hhea) else { raise MalformedFont }
  if hhea.length() < 2 {
    raise MalformedFont
  }
  let sub_hhea = Writer::new()
  sub_hhea.extend(hhea[:hhea.length() - 2])
  sub_hhea.write_u16(last_advance_width_index + 1)
  ctx.push(Tag::hhea(), sub_hhea.finish()[:])
}

///|
fn extract_metrics(
  hmtx : BytesView,
  ctx : Context,
) -> Array[(Int, Int)] raise SubsetError {
  // Extract the number of horizontal metrics from the `hhea` table.
  let num_h_metrics = {
    guard ctx.expect_table(Tag::hhea()) is Some(hhea) else {
      raise MalformedFont
    }
    let r = Reader::new(hhea)
    r.skip_bytes(34)
    guard r.read_u16() is Some(n) else { raise MalformedFont }
    n
  }
  let last_advance_width = {
    if num_h_metrics == 0 {
      raise OverflowError
    }
    let index = 4 * (num_h_metrics - 1)
    if index > hmtx.length() {
      raise MalformedFont
    }
    let r = Reader::new(hmtx[index:])
    guard r.read_u16() is Some(v) else { raise MalformedFont }
    v
  }
  let new_metrics = []
  for old_gid in ctx.mapper.remapped_gids() {
    let has_advance_width = old_gid < num_h_metrics
    let offset = if has_advance_width {
      old_gid * 4
    } else {
      num_h_metrics * 4 + (old_gid - num_h_metrics) * 2
    }
    if offset > hmtx.length() {
      raise MalformedFont
    }
    let r = Reader::new(hmtx[offset:])
    if has_advance_width {
      guard r.read_u16() is Some(adv) else { raise MalformedFont }
      guard r.read_i16() is Some(lsb) else { raise MalformedFont }
      new_metrics.push((adv, lsb))
    } else {
      guard r.read_i16() is Some(lsb) else { raise MalformedFont }
      new_metrics.push((last_advance_width, lsb))
    }
  }
  new_metrics
}

// --- maxp ---
//
// The `maxp` table contains the number of glyphs (and some additional
// information depending on the version). All we need to do is rewrite the
// number of glyphs, the rest can be copied from the old table.

///|
fn maxp_subset(ctx : Context) -> Unit raise SubsetError {
  let post_truetype_version = 0x00010000U
  let post_cff_version = 0x00005000U
  guard ctx.expect_table(Tag::maxp()) is Some(maxp) else { raise MalformedFont }
  let r = Reader::new(maxp)
  // Version
  guard r.read_u32() is Some(_) else { raise MalformedFont }
  // number of glyphs
  guard r.read_u16() is Some(_) else { raise MalformedFont }
  let version = match ctx.flavor {
    TrueType => post_truetype_version
    Cff => post_cff_version
    // Since we convert to TrueType.
    Cff2 => post_truetype_version
  }
  let sub_maxp = Writer::new()
  sub_maxp.write_u32(version)
  sub_maxp.write_u16(ctx.mapper.num_gids())
  if version == post_truetype_version {
    match ctx.custom_maxp_data {
      Some(custom_data) => {
        sub_maxp.write_u16(custom_data.max_points)
        sub_maxp.write_u16(custom_data.max_contours)
        sub_maxp.write_u16(custom_data.max_composite_points)
        sub_maxp.write_u16(custom_data.max_composite_contours)
        sub_maxp.write_u16(custom_data.max_zones)
        sub_maxp.write_u16(custom_data.max_twilight_points)
        sub_maxp.write_u16(custom_data.max_storage)
        sub_maxp.write_u16(custom_data.max_function_defs)
        sub_maxp.write_u16(custom_data.max_instruction_defs)
        sub_maxp.write_u16(custom_data.max_stack_elements)
        sub_maxp.write_u16(custom_data.max_size_of_instructions)
        sub_maxp.write_u16(custom_data.max_component_elements)
        sub_maxp.write_u16(custom_data.max_component_depth)
      }
      None => {
        guard r.tail() is Some(tail) else { raise MalformedFont }
        sub_maxp.extend(tail)
      }
    }
  }
  ctx.push(Tag::maxp(), sub_maxp.finish()[:])
}

///|
/// When converting CFF2 to TTF, we need to write a version 1.0 MAXP table.
priv struct MaxpData {
  mut max_points : Int
  mut max_contours : Int
  max_composite_points : Int
  max_composite_contours : Int
  max_zones : Int
  max_twilight_points : Int
  max_storage : Int
  max_function_defs : Int
  max_instruction_defs : Int
  max_stack_elements : Int
  max_size_of_instructions : Int
  max_component_elements : Int
  max_component_depth : Int
}

///|
fn MaxpData::default() -> MaxpData {
  {
    max_points: 0,
    max_contours: 0,
    max_composite_points: 0,
    max_composite_contours: 0,
    max_zones: 1,
    max_twilight_points: 0,
    max_storage: 0,
    max_function_defs: 0,
    max_instruction_defs: 0,
    max_stack_elements: 0,
    max_size_of_instructions: 0,
    max_component_elements: 0,
    // Could probably be 0 too since we only use simple glyphs when
    // converting?
    max_component_depth: 1,
  }
}

// --- name ---

///|
fn name_subset(ctx : Context) -> Unit raise SubsetError {
  guard ctx.expect_table(Tag::name()) is Some(name) else { raise MalformedFont }
  let r = Reader::new(name)
  guard r.read_u16() is Some(version) else { raise MalformedFont }

  // From my personal experiments, version 1 isn't used at all, so we don't
  // bother subsetting it.
  if version != 0 {
    ctx.push(Tag::name(), name)
    return
  }
  guard NameTable::parse(name) is Some(table) else { raise MalformedFont }
  guard name_subset_table(table) is Some(subsetted_table) else {
    raise SubsetError
  }
  let w = Writer::new()
  subsetted_table.write(w)
  ctx.push(Tag::name(), w.finish()[:])
}

///|
fn name_subset_table(table : NameTable) -> NameTable? {
  let names = table.names.filter(record => {
    record.is_unicode() &&
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14].contains(record.name_id)
  })
  let storage = Writer::new()
  // (Release-mode `u16` arithmetic wraps.)
  let mut cur_storage_offset = 0
  let name_deduplicator : Map[Bytes, Int] = {}
  for i, record in names {
    let start = record.string_offset
    let end = (record.string_offset + record.length) & 0xFFFF
    if start > end || end > table.storage.length() {
      return None
    }
    let name = table.storage[start:end].to_bytes()
    let offset = match name_deduplicator.get(name) {
      Some(o) => o
      None => {
        storage.extend(name[:])
        let offset = cur_storage_offset
        cur_storage_offset = (cur_storage_offset + record.length) & 0xFFFF
        name_deduplicator[name] = offset
        offset
      }
    }
    names[i] = { ..record, string_offset: offset, }
  }
  Some({ names, storage: storage.finish()[:], })
}

///|
priv struct NameTable {
  names : Array[NameRecord]
  storage : BytesView
}

///|
fn NameTable::write(self : NameTable, w : Writer) -> Unit {
  let count = self.names.length()
  // version
  w.write_u16(0)
  // count
  w.write_u16(count)
  // storage offset
  w.write_u16((2 * 3 + count * 12) & 0xFFFF)
  for name in self.names {
    w.write_u16(name.platform_id)
    w.write_u16(name.encoding_id)
    w.write_u16(name.language_id)
    w.write_u16(name.name_id)
    w.write_u16(name.length)
    w.write_u16(name.string_offset)
  }
  w.extend(self.storage)
}

///|
/// The parsing logic was adapted from ttf-parser.
fn NameTable::parse(data : BytesView) -> NameTable? {
  let r = Reader::new(data)
  guard r.read_u16() is Some(version) else { return None }
  if version != 0 {
    return None
  }
  guard r.read_u16() is Some(count) else { return None }
  guard r.read_u16() is Some(storage_offset) else { return None }
  let names = []
  for _ in 0..<count {
    guard r.read_u16() is Some(platform_id) else { return None }
    guard r.read_u16() is Some(encoding_id) else { return None }
    guard r.read_u16() is Some(language_id) else { return None }
    guard r.read_u16() is Some(name_id) else { return None }
    guard r.read_u16() is Some(length) else { return None }
    guard r.read_u16() is Some(string_offset) else { return None }
    names.push({
      platform_id,
      encoding_id,
      language_id,
      name_id,
      length,
      string_offset,
    })
  }
  if storage_offset > data.length() {
    return None
  }
  Some({ names, storage: data[storage_offset:], })
}

///|
priv struct NameRecord {
  platform_id : Int
  encoding_id : Int
  language_id : Int
  name_id : Int
  length : Int
  string_offset : Int
}

///|
fn NameRecord::is_unicode(self : NameRecord) -> Bool {
  self.platform_id == 0 ||
  (self.platform_id == 3 && [0, 1, 10].contains(self.encoding_id))
}

// --- post ---
//
// Subset the `post` table. The `post` table contains name information for
// glyphs needed for some PostScript printers. Only version 2 table contains
// actual custom names, so this is the only version that we need to subset.
// All we need to do is to extract the strings for all requested glyphs and
// write them into a new `post` table in the given order.

///|
fn post_subset(ctx : Context) -> Unit raise SubsetError {
  guard ctx.expect_table(Tag::post()) is Some(post) else { raise MalformedFont }
  let r = Reader::new(post)
  guard r.read_u32() is Some(version) else { raise MalformedFont }
  if version != 0x00020000U {
    ctx.push(Tag::post(), post)
    return
  }
  guard PostTable::parse(post) is Some(table) else { raise MalformedFont }
  let names = table.names()
  let sub_post = Writer::new()
  sub_post.extend(table.header)
  sub_post.write_u16(ctx.mapper.num_gids())
  let string_storage = Writer::new()
  let mut string_index = 0
  for old_gid in ctx.mapper.remapped_gids() {
    guard table.glyph_indexes.get(old_gid) is Some(index) else {
      raise MalformedFont
    }

    // IDs smaller than 258 refer to the names in the Macintosh TrueType file.
    if index <= 257 {
      sub_post.write_u16(index)
    } else {
      let index = index - 258
      // Phetsarath-Regular.ttf from Google Fonts seems to have a wrong name
      // table. If name cannot be fetched, use empty name instead.
      let name = if index < names.length() { names[index] } else { b""[:] }
      let name_len = name.length()
      let index = string_index + 258
      if index > 0xFFFF {
        raise OverflowError
      }
      sub_post.write_u16(index)
      string_storage.write_u8(name_len)
      string_storage.extend(name)
      string_index += 1
    }
  }
  sub_post.extend(string_storage.finish()[:])
  ctx.push(Tag::post(), sub_post.finish()[:])
}

///|
/// A version 2 `post` table.
priv struct PostTable {
  header : BytesView
  glyph_indexes : LazyArray16
  names_data : BytesView
}

///|
/// Parse a version 2 table.
fn PostTable::parse(data : BytesView) -> PostTable? {
  // Do not check the exact length, because some fonts include padding in
  // table's length in table records, which is incorrect.
  if data.length() < 32 || Reader::new(data).read_u32() != Some(0x00020000U) {
    return None
  }
  let r = Reader::new(data)
  guard r.read_bytes(32) is Some(header) else { return None }
  guard r.read_u16() is Some(indexes_count) else { return None }
  guard r.read_array16(indexes_count, 2) is Some(glyph_indexes) else {
    return None
  }
  guard r.tail() is Some(names_data) else { return None }
  Some({ header, glyph_indexes, names_data, })
}

///|
/// The glyph names (default/predefined names are not included, just the ones
/// in the font file). An empty name or a truncated one ends the list.
fn PostTable::names(self : PostTable) -> Array[BytesView] {
  let data = self.names_data
  let out = []
  let mut offset = 0
  while offset < data.length() {
    let len = data[offset].to_int()
    offset += 1
    // An empty name is an error.
    if len == 0 || offset + len > data.length() {
      break
    }
    out.push(data[offset:offset + len])
    offset += len
  }
  out
}

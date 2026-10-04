///|
fn pdf_truetype_is_cmap_tag(data : BytesView, offset : Int) -> Bool {
  offset >= 0 &&
  offset <= data.length() - 4 &&
  data[offset].to_int() == 0x63 &&
  data[offset + 1].to_int() == 0x6D &&
  data[offset + 2].to_int() == 0x61 &&
  data[offset + 3].to_int() == 0x70
}

///|
fn pdf_truetype_collect_cmap_records(
  data : BytesView,
  cmap_offset : Int,
  records : Array[(Int, Int)],
) -> Unit {
  match pdf_truetype_read_u16(data, cmap_offset + 2) {
    Some(record_count) => {
      let mut index = 0
      let mut done = false
      while !done && index < record_count {
        let record_offset = cmap_offset + 4 + index * 8
        match
          (
            pdf_truetype_read_u16(data, record_offset),
            pdf_truetype_read_u16(data, record_offset + 2),
            pdf_truetype_read_u32_as_int(data, record_offset + 4),
          ) {
          (Some(platform_id), Some(encoding_id), Some(_)) => {
            records.insert(0, (platform_id, encoding_id))
            index += 1
          }
          _ => done = true
        }
      }
    }
    None => ()
  }
}

///|
fn pdf_truetype_cmap_glyph_from_entries(
  entries : ArrayView[@truetype.PdfTrueTypeCMapGlyph],
  codepoint : Int,
) -> Int? {
  for entry in entries {
    if entry.codepoint == codepoint {
      break Some(entry.glyph_index)
    }
  } nobreak {
    None
  }
}

///|
/// Merged cmap mappings being read, in the order their codepoints first
/// appear, with where each codepoint's mapping is. A font's cmap maps
/// thousands of codepoints (tens of thousands for CJK), which a scan of
/// the mappings so far for each one made quadratic.
priv struct PdfTrueTypeCMapBuilder {
  entries : Array[@truetype.PdfTrueTypeCMapGlyph]
  positions : Map[Int, Int]
  /// The mappings still to be read. A cmap's tables overlap, and map a
  /// codepoint a few times over; a hostile one (its tables, segments or
  /// records all the same range again and again) would map without end.
  mut budget : Int
}

///|
/// The mappings a cmap is read for: every codepoint eight times over.
let pdf_truetype_cmap_budget : Int = 8 * 0x110000

///|
/// Map `codepoint` to `glyph_index`, replacing an earlier mapping of it in
/// place. False once the reading's budget is spent, when nothing more is
/// mapped.
fn pdf_truetype_push_cmap_glyph(
  entries : PdfTrueTypeCMapBuilder,
  codepoint : Int,
  glyph_index : Int,
) -> Bool {
  if entries.budget <= 0 {
    return false
  }
  entries.budget -= 1
  let normalized = pdf_truetype_normalize_u16(glyph_index)
  match entries.positions.get(codepoint) {
    Some(index) =>
      entries.entries[index] = { codepoint, glyph_index: normalized, }
    None => {
      entries.positions[codepoint] = entries.entries.length()
      entries.entries.push({ codepoint, glyph_index: normalized, })
    }
  }
  true
}

///|
fn pdf_truetype_cmap_format0_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : PdfTrueTypeCMapBuilder,
) -> Unit {
  for codepoint in 0..<256 {
    let offset = subtable_offset + 6 + codepoint
    if offset >= data.length() {
      break
    }
    if !pdf_truetype_push_cmap_glyph(entries, codepoint, data[offset].to_int()) {
      break
    }
  }
}

///|
fn pdf_truetype_cmap_format6_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : PdfTrueTypeCMapBuilder,
) -> Unit {
  match
    (
      pdf_truetype_read_u16(data, subtable_offset + 6),
      pdf_truetype_read_u16(data, subtable_offset + 8),
    ) {
    (Some(first_code), Some(entry_count)) =>
      for index in 0..<entry_count {
        match pdf_truetype_read_u16(data, subtable_offset + 10 + index * 2) {
          Some(glyph_index) =>
            if !pdf_truetype_push_cmap_glyph(
                entries,
                first_code + index,
                glyph_index,
              ) {
              break
            }
          None => break
        }
      }
    _ => ()
  }
}

///|
fn pdf_truetype_cmap_format4_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : PdfTrueTypeCMapBuilder,
) -> Unit {
  match pdf_truetype_read_u16(data, subtable_offset + 6) {
    Some(seg_count_x2) => {
      let seg_count = seg_count_x2 / 2
      let end_codes_offset = subtable_offset + 14
      let start_codes_offset = end_codes_offset + seg_count * 2 + 2
      let id_delta_offset = start_codes_offset + seg_count * 2
      let id_range_offset_offset = id_delta_offset + seg_count * 2
      let glyph_index_array_start = id_range_offset_offset + seg_count * 2
      for segment in 0..<seg_count {
        match
          (
            pdf_truetype_read_u16(data, end_codes_offset + segment * 2),
            pdf_truetype_read_u16(data, start_codes_offset + segment * 2),
            pdf_truetype_read_u16(data, id_delta_offset + segment * 2),
            pdf_truetype_read_u16(data, id_range_offset_offset + segment * 2),
          ) {
          (Some(end_code), Some(start_code), Some(delta), Some(range_offset)) =>
            if start_code <= end_code {
              for codepoint in start_code..<=end_code {
                if codepoint == 0xFFFF {
                  continue
                }
                if range_offset == 0 {
                  if !pdf_truetype_push_cmap_glyph(
                      entries,
                      codepoint,
                      codepoint + delta,
                    ) {
                    break
                  }
                } else {
                  let glyph_offset = glyph_index_array_start +
                    (
                      segment -
                      seg_count +
                      range_offset / 2 +
                      (codepoint - start_code)
                    ) *
                    2
                  match pdf_truetype_read_i16(data, glyph_offset) {
                    Some(value) => {
                      let base = if value == 0 { codepoint } else { value }
                      if !pdf_truetype_push_cmap_glyph(
                          entries,
                          codepoint,
                          base + delta,
                        ) {
                        break
                      }
                    }
                    None => break
                  }
                }
              }
            }
          _ => break
        }
      }
    }
    None => ()
  }
}

///|
/// The entries of `size` bytes a 32-bit subtable (formats 10, 12 and 13:
/// a `length` at byte 4) has room for after its `header` bytes, at most
/// `declared`: within the length it gives itself, and within the data.
fn pdf_truetype_cmap32_entries(
  data : BytesView,
  subtable_offset : Int,
  header : Int,
  size : Int,
  declared : Int,
) -> Int {
  guard pdf_truetype_read_u32_as_int(data, subtable_offset + 4) is Some(length) else {
    return 0
  }
  // (an offset near 2^31 would wrap)
  guard subtable_offset >= 0 && subtable_offset <= data.length() - header else {
    return 0
  }
  let room = length.min(data.length() - subtable_offset) - header
  if room <= 0 {
    0
  } else {
    declared.min(room / size)
  }
}

///|
/// Formats 12 (segmented coverage) and 13 (many-to-one): groups of
/// consecutive codepoints, each mapped to consecutive glyphs (format 12)
/// or all to one glyph (format 13, `many_to_one`), which reach the
/// codepoints beyond the BMP. The formats have their groups in order and
/// apart; one that is not (or that ends past U+10FFFF, or maps past glyph
/// 0xFFFF) is passed over.
fn pdf_truetype_cmap_groups_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : PdfTrueTypeCMapBuilder,
  many_to_one~ : Bool,
) -> Unit {
  guard pdf_truetype_read_u32_as_int(data, subtable_offset + 12)
    is Some(declared) else {
    return
  }
  let group_count = pdf_truetype_cmap32_entries(
    data, subtable_offset, 16, 12, declared,
  )
  // the lowest codepoint the next group may start at
  let mut next = 0
  for group in 0..<group_count {
    let at = subtable_offset + 16 + group * 12
    guard (
        pdf_truetype_read_u32_as_int(data, at),
        pdf_truetype_read_u32_as_int(data, at + 4),
        pdf_truetype_read_u32_as_int(data, at + 8),
      )
      is (Some(start), Some(end), Some(glyph)) else {
      continue
    }
    let last_glyph = if many_to_one { glyph } else { glyph + (end - start) }
    if start < next ||
      end < start ||
      end > 0x10FFFF ||
      glyph > 0xFFFF ||
      last_glyph > 0xFFFF {
      continue
    }
    for codepoint in start..<=end {
      let glyph_index = if many_to_one {
        glyph
      } else {
        glyph + codepoint - start
      }
      if !pdf_truetype_push_cmap_glyph(entries, codepoint, glyph_index) {
        return
      }
    }
    next = end + 1
  }
}

///|
/// Format 10 (trimmed array): the glyphs of a run of codepoints from a
/// first one, which may be beyond the BMP.
fn pdf_truetype_cmap_format10_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : PdfTrueTypeCMapBuilder,
) -> Unit {
  guard (
      pdf_truetype_read_u32_as_int(data, subtable_offset + 12),
      pdf_truetype_read_u32_as_int(data, subtable_offset + 16),
    )
    is (Some(first_code), Some(declared)) else {
    return
  }
  let count = pdf_truetype_cmap32_entries(
    data, subtable_offset, 20, 2, declared,
  )
  for index in 0..<count {
    // (no codepoint past the last)
    if first_code > 0x10FFFF - index {
      break
    }
    match pdf_truetype_read_u16(data, subtable_offset + 20 + index * 2) {
      Some(glyph_index) =>
        if !pdf_truetype_push_cmap_glyph(
            entries,
            first_code + index,
            glyph_index,
          ) {
          break
        }
      None => break
    }
  }
}

///|
fn pdf_truetype_cmap_subtable_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : PdfTrueTypeCMapBuilder,
) -> Unit {
  match pdf_truetype_read_u16(data, subtable_offset) {
    Some(0) => pdf_truetype_cmap_format0_glyphs(data, subtable_offset, entries)
    Some(4) => pdf_truetype_cmap_format4_glyphs(data, subtable_offset, entries)
    Some(6) => pdf_truetype_cmap_format6_glyphs(data, subtable_offset, entries)
    Some(10) =>
      pdf_truetype_cmap_format10_glyphs(data, subtable_offset, entries)
    Some(12) =>
      pdf_truetype_cmap_groups_glyphs(
        data,
        subtable_offset,
        entries,
        many_to_one=false,
      )
    Some(13) =>
      pdf_truetype_cmap_groups_glyphs(
        data,
        subtable_offset,
        entries,
        many_to_one=true,
      )
    _ => ()
  }
}

///|
fn pdf_truetype_identity_cmap_glyphs() -> Array[@truetype.PdfTrueTypeCMapGlyph] {
  [
    for codepoint in 0..<256 => { codepoint, glyph_index: codepoint, }
  ]
}

///|
/// Return merged TrueType cmap Unicode-to-glyph mappings.
///
/// This ports the cmap-table reader used by `Cpdftruetype.parse` before the
/// later width/subset writer stages. Source-supported cmap formats 0, 4, and 6
/// are decoded, and the 32-bit formats 10, 12 and 13 (which reach the
/// codepoints beyond the BMP) besides; later encoding subtables replace earlier mappings for the same
/// codepoint, matching the source `Hashtbl.add`/`find` behavior. A font with no
/// cmap table follows the source fallback of mapping byte codes `0..255` to the
/// same glyph index.
pub fn pdf_truetype_cmap_glyphs(
  data : BytesView,
) -> Array[@truetype.PdfTrueTypeCMapGlyph] {
  let entries = PdfTrueTypeCMapBuilder::{
    entries: [],
    positions: {},
    budget: pdf_truetype_cmap_budget,
  }
  match pdf_truetype_read_u16(data, 4) {
    Some(table_count) => {
      let mut cmap_offset = -1
      let mut table_index = 0
      while cmap_offset < 0 && table_index < table_count {
        let table_offset = 12 + table_index * 16
        if table_offset > data.length() - 16 {
          table_index = table_count
        } else {
          if pdf_truetype_is_cmap_tag(data, table_offset) {
            match pdf_truetype_read_u32_as_int(data, table_offset + 8) {
              Some(offset) => cmap_offset = offset
              None => ()
            }
          }
          table_index += 1
        }
      }
      if cmap_offset < 0 {
        pdf_truetype_identity_cmap_glyphs()
      } else {
        match pdf_truetype_read_u16(data, cmap_offset + 2) {
          Some(record_count) => {
            for record_index in 0..<record_count {
              if entries.budget <= 0 {
                break
              }
              let record_offset = cmap_offset + 4 + record_index * 8
              match pdf_truetype_read_u32_as_int(data, record_offset + 4) {
                Some(subtable_offset) =>
                  pdf_truetype_cmap_subtable_glyphs(
                    data,
                    cmap_offset + subtable_offset,
                    entries,
                  )
                None => break
              }
            }
            entries.entries
          }
          None => []
        }
      }
    }
    None => []
  }
}

///|
/// Look up one Unicode codepoint in the merged TrueType cmap mappings.
pub fn pdf_truetype_cmap_glyph(data : BytesView, codepoint : Int) -> Int? {
  let entries = pdf_truetype_cmap_glyphs(data)
  for entry in entries {
    if entry.codepoint == codepoint {
      break Some(entry.glyph_index)
    }
  } nobreak {
    None
  }
}

///|
/// Return the TrueType cmap platform and encoding IDs.
///
/// This ports `Cpdftruetype.cmaps`, which is used as a PDF/UA verification
/// helper. The source function catches parse failures and returns the records
/// collected before the failure; this function likewise ignores malformed or
/// incomplete parts of the font after complete cmap records have been read.
pub fn pdf_truetype_cmaps(data : BytesView) -> Array[(Int, Int)] {
  let records : Array[(Int, Int)] = []
  match pdf_truetype_read_u16(data, 4) {
    Some(table_count) => {
      let mut index = 0
      let mut done = false
      while !done && index < table_count {
        let table_offset = 12 + index * 16
        if table_offset > data.length() - 16 {
          done = true
        } else {
          if pdf_truetype_is_cmap_tag(data, table_offset) {
            match pdf_truetype_read_u32_as_int(data, table_offset + 8) {
              Some(cmap_offset) =>
                pdf_truetype_collect_cmap_records(data, cmap_offset, records)
              None => ()
            }
            done = true
          }
          index += 1
        }
      }
    }
    None => ()
  }
  records
}

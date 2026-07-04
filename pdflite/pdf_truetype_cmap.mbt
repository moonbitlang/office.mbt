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
fn pdf_truetype_push_cmap_glyph(
  entries : Array[@truetype.PdfTrueTypeCMapGlyph],
  codepoint : Int,
  glyph_index : Int,
) -> Unit {
  let normalized = pdf_truetype_normalize_u16(glyph_index)
  let mut replaced = false
  for index in 0..<entries.length() {
    if entries[index].codepoint == codepoint {
      entries[index] = { codepoint, glyph_index: normalized }
      replaced = true
      break
    }
  }
  if !replaced {
    entries.push({ codepoint, glyph_index: normalized })
  }
}

///|
fn pdf_truetype_cmap_format0_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : Array[@truetype.PdfTrueTypeCMapGlyph],
) -> Unit {
  for codepoint in 0..<256 {
    let offset = subtable_offset + 6 + codepoint
    if offset >= data.length() {
      break
    }
    pdf_truetype_push_cmap_glyph(entries, codepoint, data[offset].to_int())
  }
}

///|
fn pdf_truetype_cmap_format6_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : Array[@truetype.PdfTrueTypeCMapGlyph],
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
            pdf_truetype_push_cmap_glyph(
              entries,
              first_code + index,
              glyph_index,
            )
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
  entries : Array[@truetype.PdfTrueTypeCMapGlyph],
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
                  pdf_truetype_push_cmap_glyph(
                    entries,
                    codepoint,
                    codepoint + delta,
                  )
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
                      pdf_truetype_push_cmap_glyph(
                        entries,
                        codepoint,
                        base + delta,
                      )
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
fn pdf_truetype_cmap_subtable_glyphs(
  data : BytesView,
  subtable_offset : Int,
  entries : Array[@truetype.PdfTrueTypeCMapGlyph],
) -> Unit {
  match pdf_truetype_read_u16(data, subtable_offset) {
    Some(0) => pdf_truetype_cmap_format0_glyphs(data, subtable_offset, entries)
    Some(4) => pdf_truetype_cmap_format4_glyphs(data, subtable_offset, entries)
    Some(6) => pdf_truetype_cmap_format6_glyphs(data, subtable_offset, entries)
    _ => ()
  }
}

///|
fn pdf_truetype_identity_cmap_glyphs() -> Array[@truetype.PdfTrueTypeCMapGlyph] {
  [
    for codepoint in 0..<256 => { codepoint, glyph_index: codepoint }
  ]
}

///|
/// Return merged TrueType cmap Unicode-to-glyph mappings.
///
/// This ports the cmap-table reader used by `Cpdftruetype.parse` before the
/// later width/subset writer stages. Source-supported cmap formats 0, 4, and 6
/// are decoded; later encoding subtables replace earlier mappings for the same
/// codepoint, matching the source `Hashtbl.add`/`find` behavior. A font with no
/// cmap table follows the source fallback of mapping byte codes `0..255` to the
/// same glyph index.
pub fn pdf_truetype_cmap_glyphs(
  data : BytesView,
) -> Array[@truetype.PdfTrueTypeCMapGlyph] {
  let entries : Array[@truetype.PdfTrueTypeCMapGlyph] = []
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
            entries
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

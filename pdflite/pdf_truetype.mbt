///|
fn pdf_truetype_read_u16(data : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset > data.length() - 2 {
    None
  } else {
    Some(data[offset].to_int() * 256 + data[offset + 1].to_int())
  }
}

///|
fn pdf_truetype_read_i16(data : BytesView, offset : Int) -> Int? {
  match pdf_truetype_read_u16(data, offset) {
    Some(value) if value >= 0x8000 => Some(value - 0x10000)
    other => other
  }
}

///|
fn pdf_truetype_read_tag(data : BytesView, offset : Int) -> String? {
  if offset < 0 || offset > data.length() - 4 {
    None
  } else {
    Some(@ascii.decode_lossy(data[offset:offset + 4]))
  }
}

///|
fn pdf_truetype_read_u32(data : BytesView, offset : Int) -> UInt? {
  if offset < 0 || offset > data.length() - 4 {
    None
  } else {
    let a = data[offset].to_uint()
    let b = data[offset + 1].to_uint()
    let c = data[offset + 2].to_uint()
    let d = data[offset + 3].to_uint()
    Some((a << 24) | (b << 16) | (c << 8) | d)
  }
}

///|
fn pdf_truetype_read_u32_as_int(data : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset > data.length() - 4 {
    None
  } else {
    let value = data[offset].to_int().to_int64() * 16777216L +
      data[offset + 1].to_int().to_int64() * 65536L +
      data[offset + 2].to_int().to_int64() * 256L +
      data[offset + 3].to_int().to_int64()
    if value > 2147483647L {
      None
    } else {
      Some(value.to_int())
    }
  }
}

///|
fn pdf_truetype_normalize_u16(value : Int) -> Int {
  let mut result = value % 0x10000
  if result < 0 {
    result += 0x10000
  }
  result
}

///|
fn pdf_truetype_pdf_unit(units_per_em : Int, value : Int) -> Int {
  if units_per_em == 0 {
    0
  } else {
    (value.to_double() * 1000.0 / units_per_em.to_double()).round().to_int()
  }
}

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
pub(all) struct PdfTrueTypeTableRecord {
  tag : String
  checksum : UInt
  offset : Int
  length : Int
} derive(Debug, Eq, ToJson)

///|
/// Return complete table-directory records from a TrueType font.
///
/// This is the first structural pass in `Cpdftruetype.parse`: it reads
/// `numTables`, then each `(tag, checksum, offset, length)` table record.
pub fn pdf_truetype_tables(data : BytesView) -> Array[PdfTrueTypeTableRecord] {
  let records : Array[PdfTrueTypeTableRecord] = []
  match pdf_truetype_read_u16(data, 4) {
    Some(table_count) =>
      for index in 0..<table_count {
        let table_offset = 12 + index * 16
        match
          (
            pdf_truetype_read_tag(data, table_offset),
            pdf_truetype_read_u32(data, table_offset + 4),
            pdf_truetype_read_u32_as_int(data, table_offset + 8),
            pdf_truetype_read_u32_as_int(data, table_offset + 12),
          ) {
          (Some(tag), Some(checksum), Some(offset), Some(length)) =>
            records.push({ tag, checksum, offset, length })
          _ => break
        }
      }
    None => ()
  }
  records
}

///|
/// Return one table-directory record by tag.
pub fn pdf_truetype_table(
  data : BytesView,
  tag : String,
) -> PdfTrueTypeTableRecord? {
  for record in pdf_truetype_tables(data) {
    if record.tag == tag {
      break Some(record)
    }
  } nobreak {
    None
  }
}

///|
pub(all) struct PdfTrueTypeMetrics {
  units_per_em : Int
  minx : Int
  miny : Int
  maxx : Int
  maxy : Int
  index_to_loc_format : Int
  num_glyphs : Int
  num_of_long_hor_metrics : Int
  advance_widths : Array[Int]
  max_width : Int
} derive(Debug, Eq, ToJson)

///|
fn pdf_truetype_required_table(
  data : BytesView,
  tag : String,
) -> PdfTrueTypeTableRecord raise PdfError {
  match pdf_truetype_table(data, tag) {
    Some(record) => record
    None => raise SoftError("No " + tag + " table found in TrueType font")
  }
}

///|
fn pdf_truetype_required_u16(
  data : BytesView,
  offset : Int,
  label : String,
) -> Int raise PdfError {
  match pdf_truetype_read_u16(data, offset) {
    Some(value) => value
    None => raise SoftError("Truncated TrueType " + label)
  }
}

///|
fn pdf_truetype_required_i16(
  data : BytesView,
  offset : Int,
  label : String,
) -> Int raise PdfError {
  match pdf_truetype_read_i16(data, offset) {
    Some(value) => value
    None => raise SoftError("Truncated TrueType " + label)
  }
}

///|
fn pdf_truetype_required_u32_as_int(
  data : BytesView,
  offset : Int,
  label : String,
) -> Int raise PdfError {
  match pdf_truetype_read_u32_as_int(data, offset) {
    Some(value) => value
    None => raise SoftError("Truncated TrueType " + label)
  }
}

///|
fn pdf_truetype_hmtx_widths(
  data : BytesView,
  hmtx : PdfTrueTypeTableRecord,
  count : Int,
) -> Array[Int] raise PdfError {
  let widths : Array[Int] = []
  for index in 0..<count {
    let offset = hmtx.offset + index * 4
    widths.push(pdf_truetype_required_u16(data, offset, "hmtx table"))
  }
  widths
}

///|
fn pdf_truetype_max_pdf_width(
  units_per_em : Int,
  widths : ArrayView[Int],
) -> Int {
  let mut max_width = 0
  for width in widths {
    if width > max_width {
      max_width = width
    }
  }
  pdf_truetype_pdf_unit(units_per_em, max_width)
}

///|
fn pdf_truetype_flags(symbolic : Bool, italic_angle : Int) -> Int {
  let italic = if italic_angle != 0 { 1 } else { 0 }
  let symbolic_bit = if symbolic { 1 } else { 0 }
  let nonsymbolic_bit = if symbolic { 0 } else { 1 }
  (italic << 6) | (symbolic_bit << 2) | (nonsymbolic_bit << 5)
}

///|
pub(all) struct PdfTrueTypeDescriptorMetrics {
  ascent : Int
  descent : Int
  capheight : Int
  xheight : Int
  avgwidth : Int
  italicangle : Int
  nonsymbolic_flags : Int
  symbolic_flags : Int
} derive(Debug, Eq, ToJson)

///|
/// Return the descriptor metrics read from the TrueType `OS/2` and `post`
/// tables by `Cpdftruetype.parse`.
///
/// The source parser requires `OS/2` for normal embedding, scales its signed
/// metrics to PDF units, reads the high word of the `post` italic-angle fixed
/// value when available, and derives both symbolic and non-symbolic font flags.
pub fn pdf_truetype_descriptor_metrics(
  data : BytesView,
) -> PdfTrueTypeDescriptorMetrics raise PdfError {
  let head = pdf_truetype_required_table(data, "head")
  let units_per_em = pdf_truetype_required_u16(
    data,
    head.offset + 18,
    "head table",
  )
  let os2 = match pdf_truetype_table(data, "OS/2") {
    Some(record) => record
    None => raise SoftError("No os/2 table found in truetype font")
  }
  let version = pdf_truetype_required_u16(data, os2.offset, "OS/2 table")
  let avgwidth = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, os2.offset + 2, "OS/2 table"),
  )
  let (ascent, descent) = if os2.length > 68 {
    (
      pdf_truetype_pdf_unit(
        units_per_em,
        pdf_truetype_required_i16(data, os2.offset + 68, "OS/2 table"),
      ),
      pdf_truetype_pdf_unit(
        units_per_em,
        pdf_truetype_required_i16(data, os2.offset + 70, "OS/2 table"),
      ),
    )
  } else {
    (0, 0)
  }
  let (xheight, capheight) = if version < 2 {
    (0, 0)
  } else {
    (
      pdf_truetype_pdf_unit(
        units_per_em,
        pdf_truetype_required_i16(data, os2.offset + 86, "OS/2 table"),
      ),
      pdf_truetype_pdf_unit(
        units_per_em,
        pdf_truetype_required_i16(data, os2.offset + 88, "OS/2 table"),
      ),
    )
  }
  let italicangle = match pdf_truetype_table(data, "post") {
    Some(post) => pdf_truetype_required_u16(data, post.offset + 4, "post table")
    None => 0
  }
  {
    ascent,
    descent,
    capheight,
    xheight,
    avgwidth,
    italicangle,
    nonsymbolic_flags: pdf_truetype_flags(false, italicangle),
    symbolic_flags: pdf_truetype_flags(true, italicangle),
  }
}

///|
/// Return decoded `loca` offsets from a TrueType font.
///
/// This ports `read_loca_table`: short offsets are doubled, long offsets are
/// read directly, and unknown `indexToLocFormat` values raise the source error.
pub fn pdf_truetype_loca_offsets(data : BytesView) -> Array[Int] raise PdfError {
  let head = pdf_truetype_required_table(data, "head")
  let maxp = pdf_truetype_required_table(data, "maxp")
  let loca = pdf_truetype_required_table(data, "loca")
  let index_to_loc_format = pdf_truetype_required_i16(
    data,
    head.offset + 50,
    "head table",
  )
  let num_glyphs = pdf_truetype_required_u16(
    data,
    maxp.offset + 4,
    "maxp table",
  )
  let offsets : Array[Int] = []
  match index_to_loc_format {
    0 =>
      for index in 0..<(num_glyphs + 1) {
        offsets.push(
          pdf_truetype_required_u16(data, loca.offset + index * 2, "loca table") *
          2,
        )
      }
    1 =>
      for index in 0..<(num_glyphs + 1) {
        offsets.push(
          pdf_truetype_required_u32_as_int(
            data,
            loca.offset + index * 4,
            "loca table",
          ),
        )
      }
    _ => raise SoftError("Unknown indexToLocFormat in read_loca_table")
  }
  offsets
}

///|
/// Return the TrueType metrics needed by `Cpdftruetype.parse`.
///
/// This ports the table reads used before font subsetting proper: `/head`
/// provides units, PDF-unit bounding box, and `indexToLocFormat`; `/maxp`
/// provides `numGlyphs`; optional `/hhea` provides `numOfLongHorMetrics`; and
/// `/hmtx` provides the raw advance widths used for cpdf's width calculations.
pub fn pdf_truetype_metrics(
  data : BytesView,
) -> PdfTrueTypeMetrics raise PdfError {
  let head = pdf_truetype_required_table(data, "head")
  let maxp = pdf_truetype_required_table(data, "maxp")
  let hmtx = pdf_truetype_required_table(data, "hmtx")
  let units_per_em = pdf_truetype_required_u16(
    data,
    head.offset + 18,
    "head table",
  )
  let minx = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, head.offset + 36, "head table"),
  )
  let miny = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, head.offset + 38, "head table"),
  )
  let maxx = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, head.offset + 40, "head table"),
  )
  let maxy = pdf_truetype_pdf_unit(
    units_per_em,
    pdf_truetype_required_i16(data, head.offset + 42, "head table"),
  )
  let index_to_loc_format = pdf_truetype_required_i16(
    data,
    head.offset + 50,
    "head table",
  )
  let num_glyphs = pdf_truetype_required_u16(
    data,
    maxp.offset + 4,
    "maxp table",
  )
  let num_of_long_hor_metrics = match pdf_truetype_table(data, "hhea") {
    Some(hhea) =>
      pdf_truetype_required_u16(data, hhea.offset + 34, "hhea table")
    None => 0
  }
  let advance_widths = pdf_truetype_hmtx_widths(
    data, hmtx, num_of_long_hor_metrics,
  )
  {
    units_per_em,
    minx,
    miny,
    maxx,
    maxy,
    index_to_loc_format,
    num_glyphs,
    num_of_long_hor_metrics,
    advance_widths,
    max_width: pdf_truetype_max_pdf_width(units_per_em, advance_widths),
  }
}

///|
pub(all) struct PdfTrueTypeCMapGlyph {
  codepoint : Int
  glyph_index : Int
} derive(Debug, Eq, ToJson)

///|
fn pdf_truetype_push_cmap_glyph(
  entries : Array[PdfTrueTypeCMapGlyph],
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
  entries : Array[PdfTrueTypeCMapGlyph],
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
  entries : Array[PdfTrueTypeCMapGlyph],
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
  entries : Array[PdfTrueTypeCMapGlyph],
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
  entries : Array[PdfTrueTypeCMapGlyph],
) -> Unit {
  match pdf_truetype_read_u16(data, subtable_offset) {
    Some(0) => pdf_truetype_cmap_format0_glyphs(data, subtable_offset, entries)
    Some(4) => pdf_truetype_cmap_format4_glyphs(data, subtable_offset, entries)
    Some(6) => pdf_truetype_cmap_format6_glyphs(data, subtable_offset, entries)
    _ => ()
  }
}

///|
fn pdf_truetype_identity_cmap_glyphs() -> Array[PdfTrueTypeCMapGlyph] {
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
) -> Array[PdfTrueTypeCMapGlyph] {
  let entries : Array[PdfTrueTypeCMapGlyph] = []
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

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
fn pdf_truetype_sorted_unique(values : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = []
  for value in values {
    output.push(value)
  }
  output.sort()
  let unique : Array[Int] = []
  for value in output {
    if unique.length() == 0 || unique[unique.length() - 1] != value {
      unique.push(value)
    }
  }
  unique
}

///|
fn pdf_truetype_table_padding(length : Int) -> Int {
  if length % 4 == 0 {
    0
  } else {
    4 - length % 4
  }
}

///|
fn pdf_truetype_push_u16(
  output : Array[Byte],
  value : Int,
) -> Unit raise PdfError {
  if value < 0 || value > 0xFFFF {
    raise SoftError("TrueType unsigned 16-bit value out of range")
  }
  output.push(pdf_byte_of_int((value >> 8) & 0xFF))
  output.push(pdf_byte_of_int(value & 0xFF))
}

///|
fn pdf_truetype_push_u32(
  output : Array[Byte],
  value : Int,
) -> Unit raise PdfError {
  if value < 0 {
    raise SoftError("TrueType unsigned 32-bit value out of range")
  }
  output.push(pdf_byte_of_int((value >> 24) & 0xFF))
  output.push(pdf_byte_of_int((value >> 16) & 0xFF))
  output.push(pdf_byte_of_int((value >> 8) & 0xFF))
  output.push(pdf_byte_of_int(value & 0xFF))
}

///|
fn pdf_truetype_push_u32_uint(
  output : Array[Byte],
  value : UInt,
) -> Unit raise PdfError {
  output.push(pdf_byte_of_int((value >> 24).reinterpret_as_int()))
  output.push(pdf_byte_of_int(((value >> 16) & 0xFFU).reinterpret_as_int()))
  output.push(pdf_byte_of_int(((value >> 8) & 0xFFU).reinterpret_as_int()))
  output.push(pdf_byte_of_int((value & 0xFFU).reinterpret_as_int()))
}

///|
fn pdf_truetype_push_tag(
  output : Array[Byte],
  tag : String,
) -> Unit raise PdfError {
  let bytes = @ascii.encode(tag)
  for index in 0..<4 {
    output.push(
      pdf_byte_of_int(
        if index < bytes.length() {
          bytes[index].to_int()
        } else {
          32
        },
      ),
    )
  }
}

///|
fn pdf_truetype_push_padding(
  output : Array[Byte],
  length : Int,
) -> Unit raise PdfError {
  for _ in 0..<pdf_truetype_table_padding(length) {
    output.push(pdf_byte_of_int(0))
  }
}

///|
fn pdf_truetype_index_to_loc_format(data : BytesView) -> Int raise PdfError {
  let head = pdf_truetype_required_table(data, "head")
  pdf_truetype_required_i16(data, head.offset + 50, "head table")
}

///|
fn pdf_truetype_required_subset_table(tag : String) -> Bool {
  tag == "head" ||
  tag == "hhea" ||
  tag == "loca" ||
  tag == "cmap" ||
  tag == "maxp" ||
  tag == "cvt " ||
  tag == "glyf" ||
  tag == "prep" ||
  tag == "hmtx" ||
  tag == "fpgm"
}

///|
fn pdf_truetype_power_two_leq(value : Int) -> Int {
  let mut current = 1
  while current * 2 <= value {
    current *= 2
  }
  current
}

///|
fn pdf_truetype_source_entry_selector(power_two : Int) -> Int {
  @math.ln(power_two.to_double()).to_int()
}

///|
fn pdf_truetype_validate_glyph_index(
  loca_offsets : ArrayView[Int],
  glyph_index : Int,
) -> Unit raise PdfError {
  if glyph_index < 0 || glyph_index + 1 >= loca_offsets.length() {
    raise SoftError("Invalid TrueType glyph index")
  }
}

///|
fn pdf_truetype_validate_loca_range(
  loca_offsets : ArrayView[Int],
  glyph_index : Int,
) -> Unit raise PdfError {
  pdf_truetype_validate_glyph_index(loca_offsets, glyph_index)
  if loca_offsets[glyph_index + 1] < loca_offsets[glyph_index] {
    raise SoftError("Invalid TrueType loca offsets")
  }
}

///|
fn pdf_truetype_composite_component_glyphs(
  data : BytesView,
  component_offset : Int,
) -> Array[Int] raise PdfError {
  let components : Array[Int] = []
  let mut offset = component_offset
  let mut more_components = true
  while more_components {
    let flags = pdf_truetype_required_u16(data, offset, "glyf table")
    let glyph_index = pdf_truetype_required_u16(data, offset + 2, "glyf table")
    components.push(glyph_index)
    offset += 4
    offset += if (flags & 0x0001) > 0 { 4 } else { 2 }
    if (flags & 0x0008) > 0 {
      offset += 2
    } else if (flags & 0x0040) > 0 {
      offset += 4
    } else if (flags & 0x0080) > 0 {
      offset += 8
    }
    more_components = (flags & 0x0020) > 0
  }
  components
}

///|
fn pdf_truetype_expand_composite_glyphs_one(
  data : BytesView,
  glyf : PdfTrueTypeTableRecord,
  loca_offsets : ArrayView[Int],
  glyph_indices : ArrayView[Int],
) -> Array[Int] raise PdfError {
  let expanded : Array[Int] = []
  for glyph_index in glyph_indices {
    pdf_truetype_validate_glyph_index(loca_offsets, glyph_index)
    expanded.push(glyph_index)
    let glyph_offset = glyf.offset + loca_offsets[glyph_index]
    let number_of_contours = pdf_truetype_required_i16(
      data, glyph_offset, "glyf table",
    )
    if number_of_contours < 0 {
      for
        component in pdf_truetype_composite_component_glyphs(
          data,
          glyph_offset + 10,
        ) {
        expanded.push(component)
      }
    }
  }
  pdf_truetype_sorted_unique(expanded)
}

///|
/// Expand glyph indices to include nested TrueType composite glyph components.
///
/// This ports the `expand_composites` helper used by `Cpdftruetype` before
/// writing subset `loca` and `glyf` tables. Returned indices are sorted and
/// deduplicated, matching the source `setify`/`sort` behavior.
pub fn pdf_truetype_expand_composite_glyphs(
  data : BytesView,
  glyph_indices : ArrayView[Int],
) -> Array[Int] raise PdfError {
  let glyf = pdf_truetype_required_table(data, "glyf")
  let loca_offsets = pdf_truetype_loca_offsets(data)
  let mut current = pdf_truetype_sorted_unique(glyph_indices)
  let mut done = false
  while !done {
    let expanded = pdf_truetype_expand_composite_glyphs_one(
      data, glyf, loca_offsets, current,
    )
    if expanded == current {
      done = true
    } else {
      current = expanded
    }
  }
  current
}

///|
pub(all) struct PdfTrueTypeGlyphByteRange {
  glyph_index : Int
  start_offset : Int
  end_offset : Int
} derive(Debug, Eq, ToJson)

///|
/// Return `glyf` byte ranges for glyphs after composite expansion.
///
/// Ranges are relative to the start of the `glyf` table, matching the source
/// byterange calculation immediately before subset `glyf` table writing.
pub fn pdf_truetype_glyph_byte_ranges(
  data : BytesView,
  glyph_indices : ArrayView[Int],
) -> Array[PdfTrueTypeGlyphByteRange] raise PdfError {
  let loca_offsets = pdf_truetype_loca_offsets(data)
  let expanded = pdf_truetype_expand_composite_glyphs(data, glyph_indices)
  let ranges : Array[PdfTrueTypeGlyphByteRange] = []
  for glyph_index in expanded {
    pdf_truetype_validate_loca_range(loca_offsets, glyph_index)
    ranges.push({
      glyph_index,
      start_offset: loca_offsets[glyph_index],
      end_offset: loca_offsets[glyph_index + 1],
    })
  }
  ranges
}

///|
pub(all) struct PdfTrueTypeSubsetTable {
  length : Int
  bytes : PdfBytes
} derive(Debug, Eq)

///|
fn pdf_truetype_cmap_glyph_from_entries(
  entries : ArrayView[PdfTrueTypeCMapGlyph],
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
fn pdf_truetype_subset_contains(
  subset_codepoints : ArrayView[Int],
  codepoint : Int,
) -> Bool {
  for subset_codepoint in subset_codepoints {
    if subset_codepoint == codepoint {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_truetype_first_glyph_codepoint(name : PdfName) -> Int {
  match pdf_text_codepoints_of_glyphname(name) {
    Some(codepoints) if codepoints.length() > 0 => codepoints[0]
    _ => 0
  }
}

///|
fn pdf_truetype_codepoint_of_pdf_code(
  encoding_table : ArrayView[(Int, PdfName)],
  pdf_code : Int,
) -> Int {
  for entry in encoding_table {
    if entry.0 == pdf_code {
      break pdf_truetype_first_glyph_codepoint(entry.1)
    }
  } nobreak {
    0
  }
}

///|
fn pdf_truetype_encoding_code_defined(
  encoding_table : ArrayView[(Int, PdfName)],
  codepoint : Int,
) -> Bool {
  for entry in encoding_table {
    if entry.0 == codepoint {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_truetype_first_hmtx_width(widths : ArrayView[Int]) -> Int {
  if widths.length() == 0 {
    0
  } else {
    widths[0]
  }
}

///|
fn pdf_truetype_pdf_width_for_glyph(
  units_per_em : Int,
  widths : ArrayView[Int],
  glyph_index : Int,
) -> Int {
  if widths.length() == 0 {
    0
  } else {
    pdf_truetype_pdf_unit(
      units_per_em,
      if glyph_index >= 0 && glyph_index < widths.length() {
        widths[glyph_index]
      } else {
        widths[widths.length() - 1]
      },
    )
  }
}

///|
fn pdf_truetype_split_subsets(
  subset_codepoints : ArrayView[Int],
  chunk_size : Int,
) -> Array[Array[Int]] {
  let chunks : Array[Array[Int]] = []
  if chunk_size > 0 {
    let mut chunk : Array[Int] = []
    for codepoint in subset_codepoints {
      chunk.push(codepoint)
      if chunk.length() == chunk_size {
        chunks.push(chunk)
        chunk = []
      }
    }
    if chunk.length() > 0 {
      chunks.push(chunk)
    }
  }
  chunks
}

///|
/// Result of splitting a TrueType Unicode subset into cpdf's main and higher
/// subset groups.
pub(all) struct PdfTrueTypeSubsetPartition {
  main_subset : Array[Int]
  higher_subsets : Array[Array[Int]]
} derive(Debug, Eq, ToJson)

///|
/// Split a Unicode subset into the main simple-font subset and higher
/// implicit-font-file subsets.
///
/// This mirrors `Cpdftruetype.find_main`: codepoints whose numeric value is a
/// defined one-byte code in the selected encoding stay in the main subset, and
/// all remaining codepoints are split into chunks of 224 for higher subsets.
pub fn pdf_truetype_partition_subsets(
  encoding : PdfEncoding,
  subset_codepoints : ArrayView[Int],
) -> PdfTrueTypeSubsetPartition {
  let encoding_table = encoding.table()
  let main_subset : Array[Int] = []
  let rest : Array[Int] = []
  for codepoint in subset_codepoints {
    if pdf_truetype_encoding_code_defined(encoding_table, codepoint) {
      main_subset.push(codepoint)
    } else {
      rest.push(codepoint)
    }
  }
  { main_subset, higher_subsets: pdf_truetype_split_subsets(rest, 224) }
}

///|
/// Calculate the `/Widths` array for the main TrueType subset.
///
/// Width lookup follows `Cpdftruetype.calculate_widths`: PDF character codes
/// are first mapped through the selected simple encoding to Unicode, characters
/// outside the subset get width `0`, glyph indexes outside `/hmtx` use the last
/// advance width, and missing cmap mappings fall back to the first raw hmtx
/// width as in the source.
pub fn pdf_truetype_widths(
  data : BytesView,
  encoding : PdfEncoding,
  firstchar : Int,
  lastchar : Int,
  subset_codepoints : ArrayView[Int],
) -> Array[Int] raise PdfError {
  if lastchar < firstchar {
    raise SoftError("lastchar < firstchar")
  }
  let metrics = pdf_truetype_metrics(data)
  let cmap_entries = pdf_truetype_cmap_glyphs(data)
  let encoding_table = encoding.table()
  let widths : Array[Int] = []
  for position in 0..<(lastchar - firstchar + 1) {
    let codepoint = pdf_truetype_codepoint_of_pdf_code(
      encoding_table,
      firstchar + position,
    )
    if !pdf_truetype_subset_contains(subset_codepoints, codepoint) {
      widths.push(0)
    } else {
      match pdf_truetype_cmap_glyph_from_entries(cmap_entries, codepoint) {
        Some(glyph_index) =>
          widths.push(
            pdf_truetype_pdf_width_for_glyph(
              metrics.units_per_em,
              metrics.advance_widths,
              glyph_index,
            ),
          )
        None =>
          widths.push(pdf_truetype_first_hmtx_width(metrics.advance_widths))
      }
    }
  }
  widths
}

///|
/// Calculate the `/Widths` array for an implicit higher TrueType subset.
///
/// Character codes are positional starting at `firstchar`, so each position is
/// looked up directly in `subset_codepoints`, matching
/// `Cpdftruetype.calculate_width_higher`.
pub fn pdf_truetype_widths_higher(
  data : BytesView,
  firstchar : Int,
  lastchar : Int,
  subset_codepoints : ArrayView[Int],
) -> Array[Int] raise PdfError {
  if lastchar < firstchar {
    raise SoftError("lastchar < firstchar")
  }
  let metrics = pdf_truetype_metrics(data)
  let cmap_entries = pdf_truetype_cmap_glyphs(data)
  let widths : Array[Int] = []
  for position in 0..<(lastchar - firstchar + 1) {
    if position >= subset_codepoints.length() {
      raise SoftError("TrueType higher subset width index out of range")
    }
    match
      pdf_truetype_cmap_glyph_from_entries(
        cmap_entries,
        subset_codepoints[position],
      ) {
      Some(glyph_index) =>
        widths.push(
          pdf_truetype_pdf_width_for_glyph(
            metrics.units_per_em,
            metrics.advance_widths,
            glyph_index,
          ),
        )
      None => widths.push(pdf_truetype_first_hmtx_width(metrics.advance_widths))
    }
  }
  widths
}

///|
fn pdf_truetype_base_subset_glyph_indices(
  data : BytesView,
  subset_codepoints : ArrayView[Int],
) -> Array[Int] {
  let cmap_entries = pdf_truetype_cmap_glyphs(data)
  let glyph_indices : Array[Int] = [0]
  for codepoint in subset_codepoints {
    match pdf_truetype_cmap_glyph_from_entries(cmap_entries, codepoint) {
      Some(glyph_index) => glyph_indices.push(glyph_index)
      None => ()
    }
  }
  pdf_truetype_sorted_unique(glyph_indices)
}

///|
/// Return the glyph indices used by a TrueType Unicode subset.
///
/// This mirrors the glyph collection inside the source `write_loca_table` and
/// `write_glyf_table` helpers: `.notdef` glyph `0` is always included, missing
/// Unicode mappings are ignored, and composite glyph components are expanded
/// recursively before the sorted/deduplicated glyph-index set is returned.
pub fn pdf_truetype_subset_glyph_indices(
  data : BytesView,
  subset_codepoints : ArrayView[Int],
) -> Array[Int] raise PdfError {
  pdf_truetype_expand_composite_glyphs(
    data,
    pdf_truetype_base_subset_glyph_indices(data, subset_codepoints),
  )
}

///|
fn pdf_truetype_subset_loca_write_entry(
  output : Array[Byte],
  index_to_loc_format : Int,
  position : Int,
) -> Unit raise PdfError {
  match index_to_loc_format {
    0 => pdf_truetype_push_u16(output, position / 2)
    1 => pdf_truetype_push_u32(output, position)
    _ => raise SoftError("Unknown indexToLocFormat in write_loca_table")
  }
}

///|
/// Write a padded subset `loca` table for the given Unicode subset.
///
/// The original glyph indices are preserved: entries for skipped glyph IDs are
/// written as zero-length ranges pointing at the next selected glyph offset,
/// matching `Cpdftruetype.write_loca_table`.
pub fn pdf_truetype_subset_loca_table(
  data : BytesView,
  subset_codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let index_to_loc_format = pdf_truetype_index_to_loc_format(data)
  let loca_offsets = pdf_truetype_loca_offsets(data)
  let glyph_indices = pdf_truetype_subset_glyph_indices(data, subset_codepoints)
  let pairs : Array[(Int, Int)] = []
  let mut position = 0
  for glyph_index in glyph_indices {
    pdf_truetype_validate_loca_range(loca_offsets, glyph_index)
    pairs.push((glyph_index, position))
    position += loca_offsets[glyph_index + 1] - loca_offsets[glyph_index]
  }
  pairs.push((loca_offsets.length() - 1, position))
  let output : Array[Byte] = []
  for index in 0..<pairs.length() {
    let (glyph_index, offset) = pairs[index]
    if index != pairs.length() - 1 {
      pdf_truetype_subset_loca_write_entry(output, index_to_loc_format, offset)
      let (next_glyph_index, next_offset) = pairs[index + 1]
      for _ in 0..<(next_glyph_index - glyph_index - 1) {
        pdf_truetype_subset_loca_write_entry(
          output, index_to_loc_format, next_offset,
        )
      }
    } else {
      pdf_truetype_subset_loca_write_entry(output, index_to_loc_format, offset)
    }
  }
  pdf_truetype_push_padding(output, output.length())
  Bytes::from_array(output)
}

///|
/// Write a padded subset `glyf` table for the given Unicode subset.
///
/// The returned `length` is the unpadded table length for the TrueType table
/// directory; `bytes` contains the padded table payload actually written to the
/// font file.
pub fn pdf_truetype_subset_glyf_table(
  data : BytesView,
  subset_codepoints : ArrayView[Int],
) -> PdfTrueTypeSubsetTable raise PdfError {
  let glyf = pdf_truetype_required_table(data, "glyf")
  let ranges = pdf_truetype_glyph_byte_ranges(
    data,
    pdf_truetype_base_subset_glyph_indices(data, subset_codepoints),
  )
  let output : Array[Byte] = []
  let mut length = 0
  for range in ranges {
    if glyf.offset + range.end_offset > data.length() {
      raise SoftError("Truncated TrueType glyf table")
    }
    for offset in range.start_offset..<range.end_offset {
      output.push(data[glyf.offset + offset])
    }
    length += range.end_offset - range.start_offset
  }
  pdf_truetype_push_padding(output, length)
  { length, bytes: Bytes::from_array(output) }
}

///|
/// Write the format-6 cmap table used by cpdf for implicit-font-file subsets.
///
/// Character codes start at `33`; each Unicode value in `subset_codepoints`
/// contributes its original glyph index, or `0` if the original cmap has no
/// mapping. The returned bytes are padded, while `length` is the unpadded table
/// length for directory metadata.
pub fn pdf_truetype_subset_cmap_table(
  data : BytesView,
  subset_codepoints : ArrayView[Int],
) -> PdfTrueTypeSubsetTable raise PdfError {
  let cmap_entries = pdf_truetype_cmap_glyphs(data)
  let glyph_indices : Array[Int] = []
  for codepoint in subset_codepoints {
    glyph_indices.push(
      match pdf_truetype_cmap_glyph_from_entries(cmap_entries, codepoint) {
        Some(glyph_index) => glyph_index
        None => 0
      },
    )
  }
  let output : Array[Byte] = []
  pdf_truetype_push_u16(output, 0)
  pdf_truetype_push_u16(output, 1)
  pdf_truetype_push_u16(output, 1)
  pdf_truetype_push_u16(output, 0)
  pdf_truetype_push_u32(output, 12)
  pdf_truetype_push_u16(output, 6)
  pdf_truetype_push_u16(output, 10 + glyph_indices.length() * 2)
  pdf_truetype_push_u16(output, 0)
  pdf_truetype_push_u16(output, 33)
  pdf_truetype_push_u16(output, glyph_indices.length())
  for glyph_index in glyph_indices {
    pdf_truetype_push_u16(output, pdf_truetype_normalize_u16(glyph_index))
  }
  let length = 22 + glyph_indices.length() * 2
  pdf_truetype_push_padding(output, length)
  { length, bytes: Bytes::from_array(output) }
}

///|
fn pdf_truetype_sorted_tables(
  tables : ArrayView[PdfTrueTypeTableRecord],
) -> Array[PdfTrueTypeTableRecord] {
  let sorted : Array[PdfTrueTypeTableRecord] = []
  for table in tables {
    sorted.push(table)
  }
  sorted.sort_by(fn(left, right) { left.offset.compare(right.offset) })
  sorted
}

///|
fn pdf_truetype_subset_font_kept_tables(
  sorted_tables : ArrayView[PdfTrueTypeTableRecord],
) -> Array[PdfTrueTypeTableRecord] {
  let kept : Array[PdfTrueTypeTableRecord] = []
  let mut removed_data_before = 0
  for index in 0..<sorted_tables.length() {
    let table = sorted_tables[index]
    if pdf_truetype_required_subset_table(table.tag) {
      kept.push({
        tag: table.tag,
        checksum: table.checksum,
        offset: table.offset - removed_data_before,
        length: table.length,
      })
    } else if index < sorted_tables.length() - 1 {
      removed_data_before += sorted_tables[index + 1].offset - table.offset
    }
  }
  kept
}

///|
fn pdf_truetype_table_padded_length(length : Int) -> Int {
  length + pdf_truetype_table_padding(length)
}

///|
fn pdf_truetype_subset_original_table_span(
  data : BytesView,
  sorted_tables : ArrayView[PdfTrueTypeTableRecord],
  tag : String,
) -> (Int, Int) raise PdfError {
  for index in 0..<sorted_tables.length() {
    let table = sorted_tables[index]
    if table.tag == tag {
      let length = if index < sorted_tables.length() - 1 {
        sorted_tables[index + 1].offset - table.offset
      } else {
        data.length() - table.offset
      }
      if table.offset < 0 || length < 0 || table.offset + length > data.length() {
        raise SoftError("Truncated TrueType " + tag + " table")
      }
      break (table.offset, length)
    }
  } nobreak {
    raise SoftError("No " + tag + " table found in TrueType font")
  }
}

///|
fn pdf_truetype_subset_original_table(
  data : BytesView,
  sorted_tables : ArrayView[PdfTrueTypeTableRecord],
  tag : String,
  directory_length : Int,
) -> PdfTrueTypeSubsetTable raise PdfError {
  let (offset, length) = pdf_truetype_subset_original_table_span(
    data, sorted_tables, tag,
  )
  { length: directory_length, bytes: data[offset:offset + length].to_owned() }
}

///|
fn pdf_truetype_subset_font_table_payload(
  data : BytesView,
  sorted_tables : ArrayView[PdfTrueTypeTableRecord],
  record : PdfTrueTypeTableRecord,
  subset_codepoints : ArrayView[Int],
  rewrite_cmap : Bool,
) -> PdfTrueTypeSubsetTable raise PdfError {
  if record.tag == "loca" {
    {
      length: record.length,
      bytes: pdf_truetype_subset_loca_table(data, subset_codepoints),
    }
  } else if record.tag == "glyf" {
    pdf_truetype_subset_glyf_table(data, subset_codepoints)
  } else if record.tag == "cmap" && rewrite_cmap {
    pdf_truetype_subset_cmap_table(data, subset_codepoints)
  } else {
    pdf_truetype_subset_original_table(
      data,
      sorted_tables,
      record.tag,
      record.length,
    )
  }
}

///|
fn pdf_truetype_subset_font_directory(
  data : BytesView,
  sorted_tables : ArrayView[PdfTrueTypeTableRecord],
  subset_codepoints : ArrayView[Int],
  rewrite_cmap : Bool,
) -> (Array[PdfTrueTypeTableRecord], Array[PdfTrueTypeSubsetTable]) raise PdfError {
  let kept = pdf_truetype_subset_font_kept_tables(sorted_tables)
  let header_size_reduction = 16 * (sorted_tables.length() - kept.length())
  let records : Array[PdfTrueTypeTableRecord] = []
  let payloads : Array[PdfTrueTypeSubsetTable] = []
  let mut glyf_table_size_reduction = 0
  let mut cmap_table_size_reduction = 0
  for kept_record in kept {
    let payload = pdf_truetype_subset_font_table_payload(
      data, sorted_tables, kept_record, subset_codepoints, rewrite_cmap,
    )
    let mut table_length = kept_record.length
    if kept_record.tag == "glyf" {
      table_length = payload.length
      glyf_table_size_reduction = pdf_truetype_table_padded_length(
          kept_record.length,
        ) -
        payload.bytes.length()
    } else if kept_record.tag == "cmap" && rewrite_cmap {
      table_length = payload.length
      cmap_table_size_reduction = pdf_truetype_table_padded_length(
          kept_record.length,
        ) -
        payload.bytes.length()
    }
    let prior_table_reduction = if kept_record.tag == "glyf" {
      cmap_table_size_reduction
    } else if kept_record.tag == "cmap" {
      glyf_table_size_reduction
    } else {
      glyf_table_size_reduction + cmap_table_size_reduction
    }
    records.push({
      tag: kept_record.tag,
      checksum: kept_record.checksum,
      offset: kept_record.offset - header_size_reduction - prior_table_reduction,
      length: table_length,
    })
    payloads.push(payload)
  }
  (records, payloads)
}

///|
/// Build a cpdf-style subset TrueType font file.
///
/// This ports the `subset_font` table-directory assembly around the already
/// ported `loca`, `glyf`, and format-6 `cmap` writers. Non-required TrueType
/// tables are removed, source checksums are preserved, table offsets are
/// adjusted by removed header/data spans and rewritten table sizes, and table
/// payloads are written in source table-order. Set `rewrite_cmap=true` for the
/// source `ImplicitInFontFile` higher-subset path; the default preserves the
/// original cmap table like the main subset path.
pub fn pdf_truetype_subset_font(
  data : BytesView,
  subset_codepoints : ArrayView[Int],
  rewrite_cmap? : Bool = false,
) -> PdfBytes raise PdfError {
  let major = pdf_truetype_required_u16(data, 0, "font header")
  let minor = pdf_truetype_required_u16(data, 2, "font header")
  let sorted_tables = pdf_truetype_sorted_tables(pdf_truetype_tables(data))
  let (records, payloads) = pdf_truetype_subset_font_directory(
    data, sorted_tables, subset_codepoints, rewrite_cmap,
  )
  let output : Array[Byte] = []
  let table_count = records.length()
  let search_power = pdf_truetype_power_two_leq(table_count)
  pdf_truetype_push_u16(output, major)
  pdf_truetype_push_u16(output, minor)
  pdf_truetype_push_u16(output, table_count)
  pdf_truetype_push_u16(output, 16 * search_power)
  pdf_truetype_push_u16(
    output,
    pdf_truetype_source_entry_selector(search_power),
  )
  pdf_truetype_push_u16(output, table_count * 16)
  for record in records {
    pdf_truetype_push_tag(output, record.tag)
    pdf_truetype_push_u32_uint(output, record.checksum)
    pdf_truetype_push_u32(output, record.offset)
    pdf_truetype_push_u32(output, record.length)
  }
  for payload in payloads {
    for byte in payload.bytes {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
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

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
/// Byte range for one glyph inside the TrueType `glyf` table.
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
/// Rebuilt subset-table bytes and their unpadded logical length.
pub(all) struct PdfTrueTypeSubsetTable {
  length : Int
  bytes : PdfBytes
} derive(Debug, Eq)

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
fn pdf_truetype_utf16be_without_bom(codepoint : Int) -> PdfBytes raise PdfError {
  let bytes = pdf_utf16be_of_codepoints([codepoint])
  bytes[2:].to_owned()
}

///|
/// Build the ToUnicode entries used by cpdf's implicit higher TrueType subsets.
///
/// Source character codes start at `33` and each maps positionally to the
/// matching Unicode scalar from `subset_codepoints`. The stored bytes are
/// UTF-16BE without the PDF Unicode string BOM, matching
/// `Cpdftruetype.seconds_tounicodes`.
pub fn pdf_truetype_higher_tounicode(
  subset_codepoints : ArrayView[Int],
) -> Array[(Int, PdfBytes)]? raise PdfError {
  if subset_codepoints.length() == 0 {
    None
  } else {
    let entries : Array[(Int, PdfBytes)] = []
    for index in 0..<subset_codepoints.length() {
      entries.push(
        (33 + index, pdf_truetype_utf16be_without_bom(subset_codepoints[index])),
      )
    }
    Some(entries)
  }
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
  output_position : Int,
  index_to_loc_format : Int,
  position : Int,
) -> Int raise PdfError {
  match index_to_loc_format {
    0 => pdf_truetype_write_u16_at(output, output_position, position / 2)
    1 => pdf_truetype_write_u32_at(output, output_position, position)
    _ => raise SoftError("Unknown indexToLocFormat in write_loca_table")
  }
}

///|
fn pdf_truetype_subset_loca_entry_width(
  index_to_loc_format : Int,
) -> Int raise PdfError {
  match index_to_loc_format {
    0 => 2
    1 => 4
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
  let unpadded_length = loca_offsets.length() *
    pdf_truetype_subset_loca_entry_width(index_to_loc_format)
  let output = Array::make(
    unpadded_length + pdf_truetype_table_padding(unpadded_length),
    b'\x00',
  )
  let mut output_position = 0
  for index in 0..<pairs.length() {
    let (glyph_index, offset) = pairs[index]
    if index != pairs.length() - 1 {
      output_position = pdf_truetype_subset_loca_write_entry(
        output, output_position, index_to_loc_format, offset,
      )
      let (next_glyph_index, next_offset) = pairs[index + 1]
      for _ in 0..<(next_glyph_index - glyph_index - 1) {
        output_position = pdf_truetype_subset_loca_write_entry(
          output, output_position, index_to_loc_format, next_offset,
        )
      }
    } else {
      output_position = pdf_truetype_subset_loca_write_entry(
        output, output_position, index_to_loc_format, offset,
      )
    }
  }
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
  let mut length = 0
  for range in ranges {
    if glyf.offset + range.end_offset > data.length() {
      raise SoftError("Truncated TrueType glyf table")
    }
    length += range.end_offset - range.start_offset
  }
  let output = Array::make(length + pdf_truetype_table_padding(length), b'\x00')
  let mut position = 0
  for range in ranges {
    for offset in range.start_offset..<range.end_offset {
      output[position] = data[glyf.offset + offset]
      position += 1
    }
  }
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
  let length = 22 + glyph_indices.length() * 2
  let output = Array::make(length + pdf_truetype_table_padding(length), b'\x00')
  let mut position = pdf_truetype_write_u16_at(output, 0, 0)
  position = pdf_truetype_write_u16_at(output, position, 1)
  position = pdf_truetype_write_u16_at(output, position, 1)
  position = pdf_truetype_write_u16_at(output, position, 0)
  position = pdf_truetype_write_u32_at(output, position, 12)
  position = pdf_truetype_write_u16_at(output, position, 6)
  position = pdf_truetype_write_u16_at(
    output,
    position,
    10 + glyph_indices.length() * 2,
  )
  position = pdf_truetype_write_u16_at(output, position, 0)
  position = pdf_truetype_write_u16_at(output, position, 33)
  position = pdf_truetype_write_u16_at(output, position, glyph_indices.length())
  for glyph_index in glyph_indices {
    position = pdf_truetype_write_u16_at(
      output,
      position,
      pdf_truetype_normalize_u16(glyph_index),
    )
  }
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
  let table_count = records.length()
  let search_power = pdf_truetype_power_two_leq(table_count)
  let mut output_length = 12 + table_count * 16
  for payload in payloads {
    output_length += payload.bytes.length()
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = pdf_truetype_write_u16_at(output, 0, major)
  position = pdf_truetype_write_u16_at(output, position, minor)
  position = pdf_truetype_write_u16_at(output, position, table_count)
  position = pdf_truetype_write_u16_at(output, position, 16 * search_power)
  position = pdf_truetype_write_u16_at(
    output,
    position,
    pdf_truetype_source_entry_selector(search_power),
  )
  position = pdf_truetype_write_u16_at(output, position, table_count * 16)
  for record in records {
    position = pdf_truetype_write_tag_at(output, position, record.tag)
    position = pdf_truetype_write_u32_uint_at(output, position, record.checksum)
    position = pdf_truetype_write_u32_at(output, position, record.offset)
    position = pdf_truetype_write_u32_at(output, position, record.length)
  }
  for payload in payloads {
    position = pdf_truetype_write_view_at(output, position, payload.bytes)
  }
  Bytes::from_array(output)
}

///|
/// One subset record returned by cpdf-style TrueType parsing.
pub(all) struct PdfTrueTypeParsedSubset {
  flags : Int
  minx : Int
  miny : Int
  maxx : Int
  maxy : Int
  italicangle : Int
  ascent : Int
  descent : Int
  capheight : Int
  stemv : Int
  xheight : Int
  avgwidth : Int
  maxwidth : Int
  firstchar : Int
  lastchar : Int
  widths : Array[Int]
  subset_fontfile : PdfBytes
  subset : Array[Int]
  tounicode : Array[(Int, PdfBytes)]?
} derive(Debug, Eq)

///|
fn pdf_truetype_subset_extremes(
  subset_codepoints : ArrayView[Int],
) -> (Int, Int) raise PdfError {
  if subset_codepoints.length() == 0 {
    raise SoftError("Cpdftruetype: Refusing to create font with no characters")
  }
  let mut first = subset_codepoints[0]
  let mut last = subset_codepoints[0]
  for codepoint in subset_codepoints {
    if codepoint < first {
      first = codepoint
    }
    if codepoint > last {
      last = codepoint
    }
  }
  (first, last)
}

///|
fn pdf_truetype_parsed_subset(
  flags : Int,
  metrics : PdfTrueTypeMetrics,
  descriptor : PdfTrueTypeDescriptorMetrics,
  firstchar : Int,
  lastchar : Int,
  widths : Array[Int],
  subset_fontfile : PdfBytes,
  subset : Array[Int],
  tounicode : Array[(Int, PdfBytes)]?,
) -> PdfTrueTypeParsedSubset {
  {
    flags,
    minx: metrics.minx,
    miny: metrics.miny,
    maxx: metrics.maxx,
    maxy: metrics.maxy,
    italicangle: descriptor.italicangle,
    ascent: descriptor.ascent,
    descent: descriptor.descent,
    capheight: descriptor.capheight,
    stemv: 0,
    xheight: descriptor.xheight,
    avgwidth: descriptor.avgwidth,
    maxwidth: metrics.max_width,
    firstchar,
    lastchar,
    widths,
    subset_fontfile,
    subset,
    tounicode,
  }
}

///|
/// Parse and subset a TrueType font using cpdf's simple-font split strategy.
///
/// The returned array contains the main non-symbolic subset first, followed by
/// any higher implicit-font-file subsets. This wires together the ported
/// `Cpdftruetype.parse` prerequisites: subset partitioning, width calculation,
/// subset font-file generation, descriptor metrics, and higher-subset
/// ToUnicode mappings.
pub fn pdf_truetype_parse(
  data : BytesView,
  encoding : PdfEncoding,
  subset_codepoints : ArrayView[Int],
) -> Array[PdfTrueTypeParsedSubset] raise PdfError {
  let partition = pdf_truetype_partition_subsets(encoding, subset_codepoints)
  let (firstchar, lastchar) = pdf_truetype_subset_extremes(
    partition.main_subset,
  )
  let metrics = pdf_truetype_metrics(data)
  let descriptor = pdf_truetype_descriptor_metrics(data)
  let parsed : Array[PdfTrueTypeParsedSubset] = [
    pdf_truetype_parsed_subset(
      descriptor.nonsymbolic_flags,
      metrics,
      descriptor,
      firstchar,
      lastchar,
      pdf_truetype_widths(
        data,
        encoding,
        firstchar,
        lastchar,
        partition.main_subset,
      ),
      pdf_truetype_subset_font(data, partition.main_subset),
      partition.main_subset,
      None,
    ),
  ]
  for subset in partition.higher_subsets {
    if subset.length() > 0 {
      parsed.push(
        pdf_truetype_parsed_subset(
          descriptor.symbolic_flags,
          metrics,
          descriptor,
          33,
          subset.length() + 32,
          pdf_truetype_widths_higher(data, 33, subset.length() + 32, subset),
          pdf_truetype_subset_font(data, subset, rewrite_cmap=true),
          subset,
          pdf_truetype_higher_tounicode(subset),
        ),
      )
    }
  }
  parsed
}

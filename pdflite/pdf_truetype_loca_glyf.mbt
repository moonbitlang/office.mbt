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

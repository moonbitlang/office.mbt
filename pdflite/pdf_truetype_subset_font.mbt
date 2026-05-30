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
/// Write the format-6 cmap table used by cpdf for implicit-font-file subsets.
///
/// Character codes start at `33`; each Unicode value in `subset_codepoints`
/// contributes its original glyph index, or `0` if the original cmap has no
/// mapping. The returned bytes are padded, while `length` is the unpadded table
/// length for directory metadata.
pub fn pdf_truetype_subset_cmap_table(
  data : BytesView,
  subset_codepoints : ArrayView[Int],
) -> @truetype.PdfTrueTypeSubsetTable raise PdfError {
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
  tables : ArrayView[@truetype.PdfTrueTypeTableRecord],
) -> Array[@truetype.PdfTrueTypeTableRecord] {
  let sorted : Array[@truetype.PdfTrueTypeTableRecord] = []
  for table in tables {
    sorted.push(table)
  }
  sorted.sort_by(fn(left, right) { left.offset.compare(right.offset) })
  sorted
}

///|
fn pdf_truetype_subset_font_kept_tables(
  sorted_tables : ArrayView[@truetype.PdfTrueTypeTableRecord],
) -> Array[@truetype.PdfTrueTypeTableRecord] {
  let kept : Array[@truetype.PdfTrueTypeTableRecord] = []
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
  sorted_tables : ArrayView[@truetype.PdfTrueTypeTableRecord],
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
  sorted_tables : ArrayView[@truetype.PdfTrueTypeTableRecord],
  tag : String,
  directory_length : Int,
) -> @truetype.PdfTrueTypeSubsetTable raise PdfError {
  let (offset, length) = pdf_truetype_subset_original_table_span(
    data, sorted_tables, tag,
  )
  { length: directory_length, bytes: data[offset:offset + length].to_owned() }
}

///|
fn pdf_truetype_subset_font_table_payload(
  data : BytesView,
  sorted_tables : ArrayView[@truetype.PdfTrueTypeTableRecord],
  record : @truetype.PdfTrueTypeTableRecord,
  subset_codepoints : ArrayView[Int],
  rewrite_cmap : Bool,
) -> @truetype.PdfTrueTypeSubsetTable raise PdfError {
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
  sorted_tables : ArrayView[@truetype.PdfTrueTypeTableRecord],
  subset_codepoints : ArrayView[Int],
  rewrite_cmap : Bool,
) -> (
  Array[@truetype.PdfTrueTypeTableRecord],
  Array[@truetype.PdfTrueTypeSubsetTable],
) raise PdfError {
  let kept = pdf_truetype_subset_font_kept_tables(sorted_tables)
  let header_size_reduction = 16 * (sorted_tables.length() - kept.length())
  let records : Array[@truetype.PdfTrueTypeTableRecord] = []
  let payloads : Array[@truetype.PdfTrueTypeSubsetTable] = []
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

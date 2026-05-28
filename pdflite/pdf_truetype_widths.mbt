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

///|
/// One codepoint-to-font mapping in a cpdf-style font pack.
pub(all) struct PdfFontPackEntry {
  codepoint : Int
  font_index : Int
  charcode : Int
} derive(Debug, Eq, ToJson)

///|
/// A cpdf-style font pack.
///
/// The pack stores the fonts that can be selected while typesetting text and a
/// Unicode codepoint lookup table returning the font index and one-byte
/// character code. This ports the source-level `cpdfembed.ml` abstraction
/// without committing the public API to a hash-table representation.
pub(all) struct PdfFontPack {
  fonts : Array[PdfFont]
  entries : Array[PdfFontPackEntry]
} derive(Debug, Eq, ToJson)

///|
fn pdf_fontpack_empty() -> PdfFontPack {
  { fonts: [], entries: [] }
}

///|
/// Build a font pack for an already parsed standard font.
///
/// Duplicate Unicode mappings follow OCaml `Hashtbl.add`/`find` behavior by
/// resolving to the last character code inserted by the 0..255 scan.
pub fn pdf_fontpack_of_standard_font(
  font : PdfFont,
) -> PdfFontPack raise @core.PdfError {
  let extractor = font.text_extractor()
  let entries : Array[PdfFontPackEntry] = Array::new(capacity=256)
  for code in 0..<256 {
    let bytes : FixedArray[Byte] = [code.to_byte()]
    let codepoints = extractor.codepoints_of_text(Bytes::from_array(bytes))
    guard codepoints.length() > 0 else { raise BadText }
    entries.push({ codepoint: codepoints[0], font_index: 0, charcode: code })
  }
  { fonts: [font], entries }
}

///|
/// Compatibility wrapper matching cpdfembed's `fontpack_of_standardfont`.
pub fn pdf_fontpack_of_standardfont(
  font : PdfFont,
) -> PdfFontPack raise @core.PdfError {
  pdf_fontpack_of_standard_font(font)
}

///|
/// Look up one Unicode codepoint in a font pack.
///
/// Returns `(charcode, font_index, font)` when the codepoint can be represented.
pub fn PdfFontPack::get_char(
  self : PdfFontPack,
  codepoint : Int,
) -> (Int, Int, PdfFont)? {
  let mut found = None
  for entry in self.entries {
    if entry.codepoint == codepoint &&
      entry.font_index >= 0 &&
      entry.font_index < self.fonts.length() {
      found = Some(
        (entry.charcode, entry.font_index, self.fonts[entry.font_index]),
      )
    }
  }
  found
}

///|
/// Compatibility wrapper for `PdfFontPack::get_char`.
pub fn pdf_fontpack_get_char(
  pack : PdfFontPack,
  codepoint : Int,
) -> (Int, Int, PdfFont)? {
  pack.get_char(codepoint)
}

///|
/// Compatibility wrapper matching cpdfembed's `get_char`.
pub fn pdf_embed_get_char(
  pack : PdfFontPack,
  codepoint : Int,
) -> (Int, Int, PdfFont)? {
  pack.get_char(codepoint)
}

///|
/// Collate consecutive triples by their middle value.
///
/// This is the generic cpdfembed `collate_runs` behavior. The fontpack-specific
/// wrapper below keeps the older concrete API for existing callers.
pub fn[A, B : Eq, C] pdf_embed_collate_runs(
  runs : ArrayView[(A, B, C)],
) -> Array[Array[(A, B, C)]] {
  let output : Array[Array[(A, B, C)]] = Array::new(capacity=runs.length())
  for run in runs {
    if output.length() == 0 {
      output.push([run])
    } else {
      let current = output[output.length() - 1]
      if current[0].1 == run.1 {
        current.push(run)
      } else {
        output.push([run])
      }
    }
  }
  output
}

///|
/// Source-spelled compatibility wrapper for cpdfembed's `collate_runs`.
pub fn[A, B : Eq, C] pdf_collate_runs(
  runs : ArrayView[(A, B, C)],
) -> Array[Array[(A, B, C)]] {
  pdf_embed_collate_runs(runs)
}

///|
/// Collate consecutive `(charcode, font_index, font)` runs by font index.
pub fn pdf_fontpack_collate_runs(
  runs : ArrayView[(Int, Int, PdfFont)],
) -> Array[Array[(Int, Int, PdfFont)]] {
  pdf_embed_collate_runs(runs)
}

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
/// Build a font pack for an already parsed standard font.
///
/// Duplicate Unicode mappings follow OCaml `Hashtbl.add`/`find` behavior by
/// resolving to the last character code inserted by the 0..255 scan.
pub fn pdf_fontpack_of_standard_font(
  font : PdfFont,
) -> PdfFontPack raise PdfError {
  let extractor = font.text_extractor()
  let entries : Array[PdfFontPackEntry] = []
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
) -> PdfFontPack raise PdfError {
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
/// Collate consecutive `(charcode, font_index, font)` runs by font index.
pub fn pdf_fontpack_collate_runs(
  runs : ArrayView[(Int, Int, PdfFont)],
) -> Array[Array[(Int, Int, PdfFont)]] {
  let output : Array[Array[(Int, Int, PdfFont)]] = []
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
/// Return cpdf's substitute font file candidates for a Standard 14 font.
///
/// This is the pure table from `cpdfembed.ml`'s `load_substitute`; callers that
/// need bytes can resolve these filenames relative to their own filesystem
/// boundary.
pub fn pdf_standard_font_substitute_filenames(
  font : PdfStandardFont,
) -> Array[String] {
  match font {
    PdfTimesRoman => ["NimbusRoman-Regular.ttf"]
    PdfTimesBold => ["NimbusRoman-Bold.ttf"]
    PdfTimesItalic => ["NimbusRoman-Italic.ttf"]
    PdfTimesBoldItalic => ["NimbusRoman-BoldItalic.ttf"]
    PdfHelvetica => ["NimbusSans-Regular.ttf"]
    PdfHelveticaBold => ["NimbusSans-Bold.ttf"]
    PdfHelveticaOblique => ["NimbusSans-Italic.ttf"]
    PdfHelveticaBoldOblique => ["NimbusSans-BoldItalic.ttf"]
    PdfCourier => ["NimbusMonoPS-Regular.ttf"]
    PdfCourierBold => ["NimbusMonoPS-Bold.ttf"]
    PdfCourierOblique => ["NimbusMonoPS-Italic.ttf"]
    PdfCourierBoldOblique => ["NimbusMonoPS-BoldItalic.ttf"]
    PdfSymbol => ["StandardSymbolsPS.ttf"]
    PdfZapfDingbats => ["D050000L.ttf"]
  }
}

///|
fn pdf_embed_strip_ttf_extension(filename : String) -> String {
  if filename.has_suffix(".ttf") {
    filename[0:filename.length() - 4].to_owned()
  } else {
    filename
  }
}

///|
/// Return cpdf's substitute font name for a Standard 14 font.
pub fn pdf_standard_font_substitute_font_name(font : PdfStandardFont) -> String {
  let filenames = pdf_standard_font_substitute_filenames(font)
  if filenames.length() == 0 {
    ""
  } else {
    pdf_embed_strip_ttf_extension(filenames[0])
  }
}

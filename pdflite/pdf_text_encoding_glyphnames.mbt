///|
fn pdf_text_difference_glyphname(
  differences : ArrayView[PdfEncodingDifference],
  code : Int,
) -> PdfName? {
  let mut found : PdfName? = None
  for difference in differences {
    if difference.code == code {
      found = Some(difference.name)
    }
  }
  found
}

///|
fn PdfEncoding::pdf_text_glyphname_of_charcode(
  self : PdfEncoding,
  code : Int,
) -> PdfName? {
  match self {
    PdfImplicitInFontFile => None
    PdfStandardEncoding => pdf_text_standard_glyphname(code)
    PdfMacRomanEncoding => pdf_text_macroman_glyphname(code)
    PdfWinAnsiEncoding => pdf_text_winansi_glyphname(code)
    PdfMacExpertEncoding => pdf_text_macexpert_glyphname(code)
    PdfCustomEncoding(base, differences) =>
      match pdf_text_difference_glyphname(differences, code) {
        Some(name) => Some(name)
        None => base.pdf_text_glyphname_of_charcode(code)
      }
    PdfFillUndefinedWithStandard(base) =>
      match base.pdf_text_glyphname_of_charcode(code) {
        Some(name) => Some(name)
        None => PdfStandardEncoding.pdf_text_glyphname_of_charcode(code)
      }
  }
}

///|
/// Expand this encoding to a table of defined character-code to glyph-name entries.
///
/// Only codes with a known glyph name are emitted. The table is ordered by
/// increasing one-byte character code.
pub fn PdfEncoding::table(self : PdfEncoding) -> Array[(Int, PdfName)] {
  let output : Array[(Int, PdfName)] = Array::new(capacity=256)
  for code in 0..<256 {
    match self.pdf_text_glyphname_of_charcode(code) {
      Some(name) => output.push((code, name))
      None => ()
    }
  }
  output
}

///|
/// Expand this encoding to glyph-name to character-code entries.
///
/// The order follows `table`; duplicate glyph names are preserved rather than
/// collapsed.
pub fn PdfEncoding::reverse_table(self : PdfEncoding) -> Array[(PdfName, Int)] {
  [
    for entry in self.table() => (entry.1, entry.0)
  ]
}

///|
/// Compatibility wrapper for `PdfEncoding::table`.
pub fn pdf_table_of_encoding(encoding : PdfEncoding) -> Array[(Int, PdfName)] {
  encoding.table()
}

///|
/// Compatibility wrapper for `PdfEncoding::reverse_table`.
pub fn pdf_reverse_table_of_encoding(
  encoding : PdfEncoding,
) -> Array[(PdfName, Int)] {
  encoding.reverse_table()
}

///|
fn PdfStandardFontData::pdf_text_glyphname_of_charcode(
  self : PdfStandardFontData,
  code : Int,
) -> PdfName? {
  match self.encoding {
    PdfImplicitInFontFile =>
      match self.font {
        PdfSymbol => pdf_text_symbol_glyphname(code)
        PdfZapfDingbats => pdf_text_zapfdingbats_glyphname(code)
        _ => PdfStandardEncoding.pdf_text_glyphname_of_charcode(code)
      }
    _ => self.encoding.pdf_text_glyphname_of_charcode(code)
  }
}

///|
fn PdfFont::pdf_text_glyphname_of_charcode(
  self : PdfFont,
  code : Int,
) -> PdfName? {
  match self {
    PdfFontStandard(data) => data.pdf_text_glyphname_of_charcode(code)
    PdfFontSimple(font) => font.encoding.pdf_text_glyphname_of_charcode(code)
    PdfFontCIDKeyed(_) => None
  }
}

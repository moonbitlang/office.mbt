///|
/// Returns the Adobe Font Metrics data for this standard font.
pub fn PdfStandardFont::afm_data(self : PdfStandardFont) -> PdfAfmData {
  @standard14.pdf_standard14_afm_data(self.to_standard14_data_font())
}

///|
fn PdfStandardFont::to_standard14_data_font(
  self : PdfStandardFont,
) -> @standard14.PdfStandardFont {
  match self {
    PdfTimesRoman => PdfTimesRoman
    PdfTimesBold => PdfTimesBold
    PdfTimesItalic => PdfTimesItalic
    PdfTimesBoldItalic => PdfTimesBoldItalic
    PdfHelvetica => PdfHelvetica
    PdfHelveticaBold => PdfHelveticaBold
    PdfHelveticaOblique => PdfHelveticaOblique
    PdfHelveticaBoldOblique => PdfHelveticaBoldOblique
    PdfCourier => PdfCourier
    PdfCourierBold => PdfCourierBold
    PdfCourierOblique => PdfCourierOblique
    PdfCourierBoldOblique => PdfCourierBoldOblique
    PdfSymbol => PdfSymbol
    PdfZapfDingbats => PdfZapfDingbats
  }
}

///|
fn pdf_standard_font_from_standard14_data_font(
  font : @standard14.PdfStandardFont,
) -> PdfStandardFont {
  match font {
    PdfTimesRoman => PdfTimesRoman
    PdfTimesBold => PdfTimesBold
    PdfTimesItalic => PdfTimesItalic
    PdfTimesBoldItalic => PdfTimesBoldItalic
    PdfHelvetica => PdfHelvetica
    PdfHelveticaBold => PdfHelveticaBold
    PdfHelveticaOblique => PdfHelveticaOblique
    PdfHelveticaBoldOblique => PdfHelveticaBoldOblique
    PdfCourier => PdfCourier
    PdfCourierBold => PdfCourierBold
    PdfCourierOblique => PdfCourierOblique
    PdfCourierBoldOblique => PdfCourierBoldOblique
    PdfSymbol => PdfSymbol
    PdfZapfDingbats => PdfZapfDingbats
  }
}

///|
/// Returns the Adobe Font Metrics data for a standard font.
pub fn pdf_standard14_afm_data(font : PdfStandardFont) -> PdfAfmData {
  font.afm_data()
}

///|
/// Returns the baseline adjustment used by CamlPDF for this standard font.
pub fn pdf_standard14_baseline_adjustment(font : PdfStandardFont) -> Int {
  font.baseline_adjustment()
}

///|
/// Returns the `/StemV` value used when writing this standard font.
pub fn pdf_standard14_stemv_of_standard_font(font : PdfStandardFont) -> Int {
  font.stemv()
}

///|
/// Returns the PDF font descriptor flags for this standard font.
pub fn pdf_standard14_flags_of_standard_font(font : PdfStandardFont) -> Int {
  font.flags()
}

///|
fn pdf_standard14_width_of_code(
  data : PdfAfmData,
  encoding : PdfEncoding,
  code : Int,
) -> Int {
  match encoding {
    PdfImplicitInFontFile =>
      @standard14.pdf_standard14_width_of_charcode(data, code)
    _ => {
      let glyphname = match encoding.pdf_text_glyphname_of_charcode(code) {
        Some(name) => name
        None => pdf_text_glyph_space_name
      }
      @standard14.pdf_standard14_width_of_glyphname(data, glyphname.bytes())
    }
  }
}

///|
/// Computes the width of byte-encoded text in standard-font glyph units.
///
/// When `kern` is true, AFM kerning pairs are included between adjacent
/// character codes.
pub fn pdf_standard14_text_width(
  font : PdfStandardFont,
  encoding : PdfEncoding,
  text : BytesView,
  kern? : Bool = false,
) -> Int {
  let data = font.afm_data()
  let mut width = 0
  for index in 0..<text.length() {
    let code = text[index].to_int()
    width += pdf_standard14_width_of_code(data, encoding, code)
    if kern && index + 1 < text.length() {
      width += @standard14.pdf_standard14_kern(
        data,
        code,
        text[index + 1].to_int(),
      )
    }
  }
  width
}

///|
/// CamlPDF-shaped wrapper for standard-14 text width calculation.
pub fn pdf_standard14_textwidth(
  kern : Bool,
  encoding : PdfEncoding,
  font : PdfStandardFont,
  text : BytesView,
) -> Int {
  pdf_standard14_text_width(font, encoding, text, kern~)
}

///|
/// Computes the width of byte-encoded text for this standard font.
pub fn PdfStandardFont::text_width(
  self : PdfStandardFont,
  encoding : PdfEncoding,
  text : BytesView,
  kern? : Bool = false,
) -> Int {
  pdf_standard14_text_width(self, encoding, text, kern~)
}

///|
/// Computes the width of byte-encoded text using this standard-font data and
/// its encoding.
pub fn PdfStandardFontData::text_width(
  self : PdfStandardFontData,
  text : BytesView,
  kern? : Bool = false,
) -> Int {
  pdf_standard14_text_width(self.font, self.encoding, text, kern~)
}

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
/// Return cpdf's substitute font file candidates for a Standard 14 font.
///
/// This is the pure table from `cpdfembed.ml`'s `load_substitute`; callers that
/// need bytes can resolve these filenames relative to their own filesystem
/// boundary.
pub fn pdf_standard_font_substitute_filenames(
  font : PdfStandardFont,
) -> Array[String] {
  @standard14.pdf_standard_font_substitute_filenames(
    font.to_standard14_data_font(),
  )
}

///|
/// Return cpdf's substitute font name for a Standard 14 font.
pub fn pdf_standard_font_substitute_font_name(font : PdfStandardFont) -> String {
  @standard14.pdf_standard_font_substitute_font_name(
    font.to_standard14_data_font(),
  )
}

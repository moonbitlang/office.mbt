///|
/// The built-in PDF standard 14 font faces.
///
/// These values name the base fonts that a conforming PDF reader is expected
/// to know without an embedded font program. The variants match the canonical
/// PDF names used in `/BaseFont` entries.
pub(all) enum PdfStandardFont {
  PdfTimesRoman
  PdfTimesBold
  PdfTimesItalic
  PdfTimesBoldItalic
  PdfHelvetica
  PdfHelveticaBold
  PdfHelveticaOblique
  PdfHelveticaBoldOblique
  PdfCourier
  PdfCourierBold
  PdfCourierOblique
  PdfCourierBoldOblique
  PdfSymbol
  PdfZapfDingbats
} derive(Debug, Eq, ToJson)

///|
/// Return the canonical standard-font name without the leading PDF slash.
pub fn PdfStandardFont::name(self : PdfStandardFont) -> String {
  self.to_standard14_data_font().name()
}

///|
/// Compatibility wrapper for `PdfStandardFont::name`.
pub fn pdf_string_of_standard_font(font : PdfStandardFont) -> String {
  font.name()
}

///|
/// Return the canonical PDF name object for this standard font.
///
/// The returned name includes the leading slash in the underlying `PdfName`
/// bytes and is suitable for `/BaseFont` dictionary entries.
pub fn PdfStandardFont::pdf_name(self : PdfStandardFont) -> PdfName {
  match self {
    PdfTimesRoman => pdf_text_times_roman_name
    PdfTimesBold => pdf_text_times_bold_name
    PdfTimesItalic => pdf_text_times_italic_name
    PdfTimesBoldItalic => pdf_text_times_bold_italic_name
    PdfHelvetica => pdf_text_helvetica_name
    PdfHelveticaBold => pdf_text_helvetica_bold_name
    PdfHelveticaOblique => pdf_text_helvetica_oblique_name
    PdfHelveticaBoldOblique => pdf_text_helvetica_bold_oblique_name
    PdfCourier => pdf_text_courier_name
    PdfCourierBold => pdf_text_courier_bold_name
    PdfCourierOblique => pdf_text_courier_oblique_name
    PdfCourierBoldOblique => pdf_text_courier_bold_oblique_name
    PdfSymbol => pdf_text_symbol_name
    PdfZapfDingbats => pdf_text_zapf_dingbats_name
  }
}

///|
/// Recognize a standard 14 font from an ASCII PDF font name.
///
/// `name` is expected to include the leading slash, for example
/// `"/Helvetica"`. Common Microsoft aliases such as `/Arial` and
/// `/TimesNewRoman` are accepted for CamlPDF compatibility.
pub fn pdf_standard_font_of_name(name : String) -> PdfStandardFont? {
  match @standard14.pdf_standard_font_of_name(name) {
    Some(font) => Some(pdf_standard_font_from_standard14_data_font(font))
    None => None
  }
}

///|
/// Recognize a standard 14 font from a byte-oriented PDF name.
///
/// This is the allocation-light variant used while parsing font dictionaries.
/// It accepts the canonical PDF names and the same common aliases as
/// `pdf_standard_font_of_name`.
pub fn pdf_standard_font_of_pdf_name(name : PdfName) -> PdfStandardFont? {
  match name {
    name if name == pdf_text_times_roman_name ||
      name == pdf_text_times_new_roman_name => Some(PdfTimesRoman)
    name if name == pdf_text_times_bold_name ||
      name == pdf_text_times_new_roman_bold_name => Some(PdfTimesBold)
    name if name == pdf_text_times_italic_name ||
      name == pdf_text_times_new_roman_italic_name => Some(PdfTimesItalic)
    name if name == pdf_text_times_bold_italic_name ||
      name == pdf_text_times_new_roman_bold_italic_name =>
      Some(PdfTimesBoldItalic)
    name if name == pdf_text_helvetica_name || name == pdf_text_arial_name =>
      Some(PdfHelvetica)
    name if name == pdf_text_helvetica_bold_name ||
      name == pdf_text_arial_bold_name => Some(PdfHelveticaBold)
    name if name == pdf_text_helvetica_oblique_name ||
      name == pdf_text_arial_italic_name => Some(PdfHelveticaOblique)
    name if name == pdf_text_helvetica_bold_oblique_name ||
      name == pdf_text_arial_bold_italic_name => Some(PdfHelveticaBoldOblique)
    name if name == pdf_text_courier_name || name == pdf_text_courier_new_name =>
      Some(PdfCourier)
    name if name == pdf_text_courier_bold_name ||
      name == pdf_text_courier_new_bold_name => Some(PdfCourierBold)
    name if name == pdf_text_courier_oblique_name ||
      name == pdf_text_courier_new_italic_name => Some(PdfCourierOblique)
    name if name == pdf_text_courier_bold_oblique_name ||
      name == pdf_text_courier_new_bold_italic_name =>
      Some(PdfCourierBoldOblique)
    name if name == pdf_text_symbol_name => Some(PdfSymbol)
    name if name == pdf_text_zapf_dingbats_name => Some(PdfZapfDingbats)
    _ => None
  }
}

///|
/// Return a synthetic baseline adjustment for simple standard-font placement.
///
/// The value is derived from the font ascent-like metrics used by the original
/// CamlPDF helpers and is expressed in glyph-space units.
pub fn PdfStandardFont::baseline_adjustment(self : PdfStandardFont) -> Int {
  self.to_standard14_data_font().baseline_adjustment()
}

///|
/// Return the standard-font `StemV` descriptor value used when writing fonts.
pub fn PdfStandardFont::stemv(self : PdfStandardFont) -> Int {
  self.to_standard14_data_font().stemv()
}

///|
/// Return PDF font descriptor flags for this standard font.
///
/// The flags distinguish symbolic fonts, fixed-pitch Courier faces, and the
/// nonsymbolic roman faces according to the PDF font descriptor bit layout.
pub fn PdfStandardFont::flags(self : PdfStandardFont) -> Int {
  self.to_standard14_data_font().flags()
}

///|
pub using @afm {type PdfAfmData, type PdfBytes}

///|
/// The built-in PDF standard 14 font faces.
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
  match self {
    PdfTimesRoman => "Times-Roman"
    PdfTimesBold => "Times-Bold"
    PdfTimesItalic => "Times-Italic"
    PdfTimesBoldItalic => "Times-BoldItalic"
    PdfHelvetica => "Helvetica"
    PdfHelveticaBold => "Helvetica-Bold"
    PdfHelveticaOblique => "Helvetica-Oblique"
    PdfHelveticaBoldOblique => "Helvetica-BoldOblique"
    PdfCourier => "Courier"
    PdfCourierBold => "Courier-Bold"
    PdfCourierOblique => "Courier-Oblique"
    PdfCourierBoldOblique => "Courier-BoldOblique"
    PdfSymbol => "Symbol"
    PdfZapfDingbats => "ZapfDingbats"
  }
}

///|
/// Compatibility wrapper for `PdfStandardFont::name`.
pub fn pdf_string_of_standard_font(font : PdfStandardFont) -> String {
  font.name()
}

///|
/// Recognize a standard 14 font from an ASCII PDF font name.
///
/// `name` is expected to include the leading slash, for example
/// `"/Helvetica"`. Common Microsoft aliases such as `/Arial` and
/// `/TimesNewRoman` are accepted for CamlPDF compatibility.
pub fn pdf_standard_font_of_name(name : String) -> PdfStandardFont? {
  match name {
    "/Times-Roman" | "/TimesNewRoman" => Some(PdfTimesRoman)
    "/Times-Bold" | "/TimesNewRoman,Bold" => Some(PdfTimesBold)
    "/Times-Italic" | "/TimesNewRoman,Italic" => Some(PdfTimesItalic)
    "/Times-BoldItalic" | "/TimesNewRoman,BoldItalic" =>
      Some(PdfTimesBoldItalic)
    "/Helvetica" | "/Arial" => Some(PdfHelvetica)
    "/Helvetica-Bold" | "/Arial,Bold" => Some(PdfHelveticaBold)
    "/Helvetica-Oblique" | "/Arial,Italic" => Some(PdfHelveticaOblique)
    "/Helvetica-BoldOblique" | "/Arial,BoldItalic" =>
      Some(PdfHelveticaBoldOblique)
    "/Courier" | "/CourierNew" => Some(PdfCourier)
    "/Courier-Bold" | "/CourierNew,Bold" => Some(PdfCourierBold)
    "/Courier-Oblique" | "/CourierNew,Italic" => Some(PdfCourierOblique)
    "/Courier-BoldOblique" | "/CourierNew,BoldItalic" =>
      Some(PdfCourierBoldOblique)
    "/Symbol" => Some(PdfSymbol)
    "/ZapfDingbats" => Some(PdfZapfDingbats)
    _ => None
  }
}

///|
/// Return a synthetic baseline adjustment for simple standard-font placement.
pub fn PdfStandardFont::baseline_adjustment(self : PdfStandardFont) -> Int {
  match self {
    PdfTimesRoman => 662 / 2
    PdfTimesBold => 676 / 2
    PdfTimesItalic => 653 / 2
    PdfTimesBoldItalic => 669 / 2
    PdfHelvetica
    | PdfHelveticaBold
    | PdfHelveticaOblique
    | PdfHelveticaBoldOblique => 718 / 2
    PdfCourier | PdfCourierBold | PdfCourierOblique | PdfCourierBoldOblique =>
      562 / 2
    PdfSymbol => 673 / 2
    PdfZapfDingbats => 705 / 2
  }
}

///|
/// Return the standard-font `StemV` descriptor value used when writing fonts.
pub fn PdfStandardFont::stemv(self : PdfStandardFont) -> Int {
  match self {
    PdfTimesRoman => 116
    PdfTimesBold => 122
    PdfTimesItalic => 105
    PdfTimesBoldItalic => 108
    PdfHelvetica => 114
    PdfHelveticaBold => 123
    PdfHelveticaOblique => 127
    PdfHelveticaBoldOblique => 136
    PdfCourier => 88
    PdfCourierBold => 93
    PdfCourierOblique => 100
    PdfCourierBoldOblique => 104
    PdfSymbol => 0
    PdfZapfDingbats => 125
  }
}

///|
/// Return PDF font descriptor flags for this standard font.
///
/// The flags distinguish symbolic fonts, fixed-pitch Courier faces, and the
/// nonsymbolic roman faces according to the PDF font descriptor bit layout.
pub fn PdfStandardFont::flags(self : PdfStandardFont) -> Int {
  match self {
    PdfSymbol => 65541
    PdfZapfDingbats => 4
    PdfCourier | PdfCourierBold | PdfCourierOblique | PdfCourierBoldOblique =>
      33
    _ => 32
  }
}

///|
/// Returns the Adobe Font Metrics data for this standard font.
pub fn PdfStandardFont::afm_data(self : PdfStandardFont) -> PdfAfmData {
  pdf_standard14_afm_data_of_font(self)
}

///|
/// Returns the Adobe Font Metrics data for a standard font.
pub fn pdf_standard14_afm_data(font : PdfStandardFont) -> PdfAfmData {
  font.afm_data()
}

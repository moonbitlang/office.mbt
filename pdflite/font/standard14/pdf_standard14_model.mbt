///|
/// Byte sequence used by generated AFM table data.
pub type PdfBytes = Bytes

///|
/// Adobe Font Metrics data for a built-in Standard 14 font face.
pub(all) struct PdfAfmData {
  headers : Array[(PdfBytes, PdfBytes)]
  char_metrics : Array[(Int, Int)]
  kerns : Array[(Int, Int, Int)]
  char_name_widths : Array[(PdfBytes, Int)]
} derive(Debug, Eq, ToJson)

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
/// Returns the Adobe Font Metrics data for this standard font.
pub fn PdfStandardFont::afm_data(self : PdfStandardFont) -> PdfAfmData {
  pdf_standard14_afm_data_of_font(self)
}

///|
/// Returns the Adobe Font Metrics data for a standard font.
pub fn pdf_standard14_afm_data(font : PdfStandardFont) -> PdfAfmData {
  font.afm_data()
}

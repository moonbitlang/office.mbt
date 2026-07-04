///|
/// Return cpdf's substitute font file candidates for a Standard 14 font.
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
fn pdf_standard14_strip_ttf_extension(filename : String) -> String {
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
    pdf_standard14_strip_ttf_extension(filenames[0])
  }
}

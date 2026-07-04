///|
/// Colour value used by cpdf-style content colour rewrite operations.
pub(all) enum PdfContentColour {
  PdfContentGrey(Double)
  PdfContentRGB(Double, Double, Double)
  PdfContentCMYK(Double, Double, Double, Double)
} derive(Debug, Eq, ToJson)

///|
/// The default black content colour.
pub let pdf_content_black : PdfContentColour = PdfContentGrey(0.0)

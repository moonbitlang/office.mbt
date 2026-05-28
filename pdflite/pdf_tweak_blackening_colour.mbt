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

///|
fn PdfContentColour::pdf_tweak_fill_op(self : PdfContentColour) -> PdfContentOp {
  match self {
    PdfContentGrey(grey) => Op_g(grey)
    PdfContentRGB(red, green, blue) => Op_rg(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      Op_k(cyan, magenta, yellow, black)
  }
}

///|
fn PdfContentColour::pdf_tweak_stroke_op(
  self : PdfContentColour,
) -> PdfContentOp {
  match self {
    PdfContentGrey(grey) => Op_G(grey)
    PdfContentRGB(red, green, blue) => Op_RG(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      Op_K(cyan, magenta, yellow, black)
  }
}

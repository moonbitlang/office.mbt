///|
/// Source-facing cpdf font source descriptor.
///
/// This mirrors `Cpdfembed.cpdffont`: callers may supply a prebuilt font pack,
/// request TrueType embedding from bytes and an encoding, or reuse an existing
/// named font resource.
pub(all) enum PdfEmbedFontSource {
  PdfEmbedPreMadeFontPack(PdfFontPack)
  PdfEmbedInfo(@core.PdfBytes, String, PdfEncoding)
  PdfEmbedExistingNamedFont
} derive(Debug, Eq, ToJson)

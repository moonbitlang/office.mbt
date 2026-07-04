///|
/// Font source options for cpdf add-text.
///
/// This ports the source-level non-embedding `Cpdfembed.cpdffont` variants.
/// TrueType `EmbedInfo` remains a separate embedding slice.
pub(all) enum PdfAddTextFontSource {
  PdfAddTextPreMadeFontPack(PdfFontPack)
  PdfAddTextExistingNamedFont
} derive(Debug, Eq, ToJson)

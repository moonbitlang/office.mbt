///|
/// Text rotation values used by cpdf's add-text positioning helpers.
pub(all) enum PdfAddTextRotation {
  PdfAddTextRot0
  PdfAddTextRot90
  PdfAddTextRot180
  PdfAddTextRot270
} derive(Debug, Eq, ToJson)

///|
/// Text justification values used by cpdf's add-text positioning helpers.
pub(all) enum PdfAddTextJustification {
  PdfAddTextLeftJustify
  PdfAddTextCentreJustify
  PdfAddTextRightJustify
} derive(Debug, Eq, ToJson)

///|
/// Font source options for cpdf add-text.
///
/// This ports the source-level non-embedding `Cpdfembed.cpdffont` variants.
/// TrueType `EmbedInfo` remains a separate embedding slice.
pub(all) enum PdfAddTextFontSource {
  PdfAddTextPreMadeFontPack(PdfFontPack)
  PdfAddTextExistingNamedFont
} derive(Debug, Eq, ToJson)

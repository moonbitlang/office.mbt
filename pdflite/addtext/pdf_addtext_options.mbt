///|
/// Text rotation values used by cpdf's add-text positioning helpers.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfAddTextRotation {
  PdfAddTextRot0
  PdfAddTextRot90
  PdfAddTextRot180
  PdfAddTextRot270
}

///|
/// Text justification values used by cpdf's add-text positioning helpers.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfAddTextJustification {
  PdfAddTextLeftJustify
  PdfAddTextCentreJustify
  PdfAddTextRightJustify
}

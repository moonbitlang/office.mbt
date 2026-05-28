///|
/// Size contribution for a named document component in cpdfcomposition-style
/// reports.
pub(all) struct PdfCompositionEntry {
  label : String
  bytes : Int
  percent : Double
} derive(Debug, Eq, ToJson)

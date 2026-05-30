///|
/// Size contribution for a named document component in cpdfcomposition-style
/// reports.
pub(all) struct PdfCompositionEntry {
  label : String
  bytes : Int
  percent : Double
} derive(Debug, Eq, ToJson)

///|
/// Build a composition row and compute its percentage of the full file size.
pub fn pdf_composition_entry(
  label : String,
  bytes : Int,
  file_size : Int,
) -> PdfCompositionEntry {
  { label, bytes, percent: bytes.to_double() / file_size.to_double() * 100.0 }
}

///|
fn pdf_composition_json_number(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
/// Convert a composition entry to the cpdf JSON row shape:
/// `[label, byte_count, percent]`.
pub fn PdfCompositionEntry::to_json(self : PdfCompositionEntry) -> Json {
  Json::array([
    Json::string(self.label),
    pdf_composition_json_number(self.bytes),
    Json::number(self.percent),
  ])
}

///|
/// PDF/UA subformat selector used by CamlPDF-facing creation helpers.
pub(all) enum PdfUASubformat {
  PdfUA1
  PdfUA2
} derive(Debug, Eq, ToJson)

///|
/// Parse CamlPDF's PDF/UA subformat spelling.
pub fn pdf_ua_subformat_of_string(
  text : String,
) -> PdfUASubformat raise PdfError {
  match text {
    "PDF/UA-1" => PdfUA1
    "PDF/UA-2" => PdfUA2
    _ => raise BadText
  }
}

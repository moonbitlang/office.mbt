///|
/// Compatibility wrapper for `PdfDocument::page_info_json`.
pub fn pdf_page_info_json(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : @geometry.PdfUnit = PdfPoint,
) -> Json raise PdfError {
  document.page_info_json(page_numbers, unit~)
}

///|
/// Compatibility wrapper matching cpdfpage's `json_page_info`.
pub fn pdf_json_page_info(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  unit : @geometry.PdfUnit,
) -> Json raise PdfError {
  document.page_info_json(page_numbers, unit~)
}

///|
/// Compatibility wrapper for `PdfDocument::page_info_json_blob`.
pub fn pdf_output_page_info_json_blob(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : @geometry.PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  document.page_info_json_blob(page_numbers, unit~)
}

///|
/// Return the bytes cpdfpage's `output_page_info` would print.
///
/// `raisejson` is accepted for source-shape compatibility with cpdf's internal
/// JSON exception path; this MoonBit wrapper returns JSON bytes directly when
/// `json=true`.
pub fn PdfDocument::output_page_info(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : @geometry.PdfUnit = PdfPoint,
  json? : Bool = false,
  raisejson? : Bool = false,
) -> PdfBytes raise PdfError {
  ignore(raisejson)
  if json {
    self.page_info_json_blob(page_numbers, unit~)
  } else {
    self.page_info_text(page_numbers, unit~)
  }
}

///|
/// Compatibility wrapper matching cpdfpage's `output_page_info` argument order.
pub fn pdf_output_page_info(
  unit : @geometry.PdfUnit,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  json? : Bool = false,
  raisejson? : Bool = false,
) -> PdfBytes raise PdfError {
  document.output_page_info(page_numbers, unit~, json~, raisejson~)
}

///|
/// Compatibility wrapper for `PdfDocument::page_info_text`.
pub fn pdf_output_page_info_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : @geometry.PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  document.page_info_text(page_numbers, unit~)
}

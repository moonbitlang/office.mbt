///|
/// Compatibility wrapper for `PdfDocument::stamp_pages`.
pub fn pdf_stamp(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  overlay : PdfDocument,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  position? : PdfPosition = PdfPositionBottomLeft(0.0, 0.0),
  topline? : Bool = false,
  midline? : Bool = false,
  fast? : Bool = false,
  scale_to_fit? : Bool = false,
  is_over? : Bool = true,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  document.stamp_pages(
    page_numbers,
    overlay,
    relative_to_box~,
    position~,
    topline~,
    midline~,
    fast~,
    scale_to_fit~,
    is_over~,
    process_struct_tree~,
  )
}

///|
/// Stamp using cpdfpage's string page-box names.
pub fn PdfDocument::stamp_pages_string(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  overlay : PdfDocument,
  relative_to_box : String,
  position? : PdfPosition = PdfPositionBottomLeft(0.0, 0.0),
  topline? : Bool = false,
  midline? : Bool = false,
  fast? : Bool = false,
  scale_to_fit? : Bool = false,
  is_over? : Bool = true,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  self.stamp_pages(
    page_numbers,
    overlay,
    relative_to_box=pdf_page_box_name_of_string(relative_to_box),
    position~,
    topline~,
    midline~,
    fast~,
    scale_to_fit~,
    is_over~,
    process_struct_tree~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `stamp` argument order.
pub fn pdf_stamp_cpdf_order(
  process_struct_tree : Bool,
  relative_to_box : String,
  position : PdfPosition,
  topline : Bool,
  midline : Bool,
  fast : Bool,
  scale_to_fit : Bool,
  is_over : Bool,
  page_numbers : ArrayView[Int],
  overlay : PdfDocument,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.stamp_pages_string(
    page_numbers,
    overlay,
    relative_to_box,
    position~,
    topline~,
    midline~,
    fast~,
    scale_to_fit~,
    is_over~,
    process_struct_tree~,
  )
}

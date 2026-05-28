///|
/// Hard-clip selected pages to a page box by prepending a clipping rectangle.
///
/// `page_numbers` are 1-based. `box_name` is usually `/MediaBox`, `/CropBox`,
/// `/TrimBox`, `/ArtBox`, or `/BleedBox`. Missing non-media boxes raise unless
/// `mediabox_if_missing` is true. In `fast` mode the clip stream is prepended
/// without parsing existing content.
pub fn PdfDocument::hard_box(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : PdfName,
  mediabox_if_missing? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "hard_box", (_, _, page) => {
    self.pdf_page_hard_box_page(page, box_name, mediabox_if_missing, fast)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::hard_box`.
pub fn pdf_hard_box(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : PdfName,
  mediabox_if_missing? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.hard_box(page_numbers, box_name, mediabox_if_missing~, fast~)
}

///|
/// Compatibility wrapper using cpdfpage's string page-box names.
pub fn PdfDocument::hard_box_string(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : String,
  mediabox_if_missing? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.hard_box(
    page_numbers,
    pdf_page_box_name_of_string(box_name),
    mediabox_if_missing~,
    fast~,
  )
}

///|
/// Compatibility wrapper using cpdfpage's string page-box names.
pub fn pdf_hard_box_string(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : String,
  mediabox_if_missing? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.hard_box_string(page_numbers, box_name, mediabox_if_missing~, fast~)
}

///|
/// Return whether a 1-based page has a named non-media page box.
///
/// This mirrors cpdf's `hasbox`: invalid page numbers raise, and the check is
/// performed against the page's explicit dictionary entries rather than treating
/// `/MediaBox` as always present.
pub fn PdfDocument::has_page_box(
  self : PdfDocument,
  page_number : Int,
  box_name : PdfName,
) -> Bool raise PdfError {
  let pages = self.pages_of_pagetree()
  if page_number < 1 || page_number > pages.length() {
    raise BadPageSpecification("hasbox: bad page")
  }
  match self.lookup_direct(box_name, pages[page_number - 1].rest) {
    Some(_) => true
    None => false
  }
}

///|
/// Compatibility wrapper for `PdfDocument::has_page_box`.
pub fn pdf_hasbox(
  document : PdfDocument,
  page_number : Int,
  box_name : PdfName,
) -> Bool raise PdfError {
  document.has_page_box(page_number, box_name)
}

///|
/// Compatibility wrapper using cpdfpage's string page-box names.
pub fn PdfDocument::hasbox_string(
  self : PdfDocument,
  page_number : Int,
  box_name : String,
) -> Bool raise PdfError {
  self.has_page_box(page_number, pdf_page_box_name_of_string(box_name))
}

///|
/// Compatibility wrapper using cpdfpage's string page-box names.
pub fn pdf_hasbox_string(
  document : PdfDocument,
  page_number : Int,
  box_name : String,
) -> Bool raise PdfError {
  document.hasbox_string(page_number, box_name)
}

///|
/// Copy one page-box value to another on selected pages.
///
/// Missing source boxes leave the page unchanged unless `mediabox_if_missing`
/// is true, in which case the page `/MediaBox` is copied.
pub fn PdfDocument::copy_page_box(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  from_box : PdfName,
  to_box : PdfName,
  mediabox_if_missing? : Bool = false,
) -> PdfDocument raise PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "copy_page_box", (_, _, page) => {
    self.pdf_page_copy_box_page(page, from_box, to_box, mediabox_if_missing)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::copy_page_box`.
pub fn pdf_copy_page_box(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  from_box : PdfName,
  to_box : PdfName,
  mediabox_if_missing? : Bool = false,
) -> PdfDocument raise PdfError {
  document.copy_page_box(page_numbers, from_box, to_box, mediabox_if_missing~)
}

///|
/// Compatibility wrapper using cpdfpage's string page-box names.
pub fn PdfDocument::copy_box(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  from_box : String,
  to_box : String,
  mediabox_if_missing? : Bool = false,
) -> PdfDocument raise PdfError {
  self.copy_page_box(
    page_numbers,
    pdf_page_box_name_of_string(from_box),
    pdf_page_box_name_of_string(to_box),
    mediabox_if_missing~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `copy_box` argument order.
pub fn pdf_copy_box(
  from_box : String,
  to_box : String,
  mediabox_if_missing : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.copy_box(page_numbers, from_box, to_box, mediabox_if_missing~)
}

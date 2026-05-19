///|
fn pdf_content_page_contains(
  page_numbers : ArrayView[Int],
  page_number : Int,
) -> Bool {
  for selected in page_numbers {
    if selected == page_number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_content_page_number_json(page_number : Int) -> Json {
  Json::number(page_number.to_double(), repr=page_number.to_string())
}

///|
/// Collect recursive cpdfcontent JSON entries for one page.
pub fn PdfDocument::content_entries_of_page(
  self : PdfDocument,
  page : PdfPage,
) -> Array[PdfContentJsonEntry] raise PdfError {
  let mediabox = self.parse_rectangle(page.mediabox)
  let ops = self.parse_content_ops_with_resources(page.resources, page.content)
  self.content_entries_of_ops_recursive(mediabox, page.resources, ops)
}

///|
/// Compatibility wrapper for `PdfDocument::content_entries_of_page`.
pub fn pdf_content_entries_of_page(
  document : PdfDocument,
  page : PdfPage,
) -> Array[PdfContentJsonEntry] raise PdfError {
  document.content_entries_of_page(page)
}

///|
/// Serialize recursive cpdfcontent entries for one already-parsed operator list.
pub fn PdfDocument::content_json_of_ops(
  self : PdfDocument,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> Json raise PdfError {
  pdf_content_json_entries_content_json(
    self.content_entries_of_ops_recursive(mediabox, resources, ops),
  )
}

///|
/// Compatibility wrapper for `PdfDocument::content_json_of_ops`.
pub fn pdf_content_json_of_ops(
  document : PdfDocument,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> Json raise PdfError {
  document.content_json_of_ops(mediabox, resources, ops)
}

///|
/// Serialize recursive cpdfcontent entries for one page.
pub fn PdfDocument::content_json_of_page(
  self : PdfDocument,
  page : PdfPage,
) -> Json raise PdfError {
  pdf_content_json_entries_content_json(self.content_entries_of_page(page))
}

///|
/// Compatibility wrapper for `PdfDocument::content_json_of_page`.
pub fn pdf_content_json_of_page(
  document : PdfDocument,
  page : PdfPage,
) -> Json raise PdfError {
  document.content_json_of_page(page)
}

///|
/// Return cpdf's page-content JSON array for selected 1-based page numbers.
pub fn PdfDocument::page_content_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "page_content_json",
  )
  let output : Array[Json] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    if pdf_content_page_contains(page_numbers, page_number) {
      output.push(
        Json::object(
          Map::of([
            ("page", pdf_content_page_number_json(page_number)),
            ("contents", self.content_json_of_page(pages[index])),
          ]),
        ),
      )
    }
  }
  Json::array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::page_content_json`.
pub fn pdf_page_content_json(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise PdfError {
  document.page_content_json(page_numbers)
}

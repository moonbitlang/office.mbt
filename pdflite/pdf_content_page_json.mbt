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
/// Source-spelled compatibility wrapper for cpdfcontent's `to_json`.
pub fn pdf_content_to_json(
  document : PdfDocument,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> Json raise PdfError {
  document.content_json_of_ops(mediabox, resources, ops)
}

///|
/// Walk content entries, call `predicate` for each one, and return the original ops.
pub fn PdfDocument::content_filter(
  self : PdfDocument,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
  predicate : (PdfContentJsonEntry) -> Bool,
) -> Array[PdfContentOp] raise PdfError {
  let entries = self.content_entries_of_ops_recursive(mediabox, resources, ops)
  for entry in entries {
    ignore(predicate(entry))
  }
  [
    for op in ops => op
  ]
}

///|
/// Compatibility wrapper for `PdfDocument::content_filter`.
pub fn pdf_content_filter(
  document : PdfDocument,
  predicate : (PdfContentJsonEntry) -> Bool,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] raise PdfError {
  document.content_filter(mediabox, resources, ops, predicate)
}

///|
fn pdf_content_push_extracted_text(
  output : Array[Byte],
  entry : PdfContentJsonEntry,
) -> Unit {
  match entry.object {
    PdfContentGlyphObject(_, _, extracted_text) =>
      pdf_content_push_view(output, @utf8.encode(extracted_text))
    _ => ()
  }
}

///|
/// Return cpdf's simple test text extraction bytes for selected 1-based pages.
pub fn PdfDocument::test_extract_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "test_extract_text",
  )
  let output : Array[Byte] = []
  for index in 0..<pages.length() {
    output.push(10)
    let page_number = index + 1
    if pdf_content_page_contains(page_numbers, page_number) {
      for entry in self.content_entries_of_page(pages[index]) {
        pdf_content_push_extracted_text(output, entry)
      }
    }
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::test_extract_text`.
pub fn pdf_test_extract_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  document.test_extract_text(page_numbers)
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
          Map([
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

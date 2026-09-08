///|
/// Report image resolutions for selected pages.
///
/// Results match cpdf's tuple order: page number, XObject name, image width,
/// image height, horizontal DPI, vertical DPI, and object number. Entries are
/// kept when either axis is below `dpi`.
pub fn PdfDocument::image_resolution(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> Array[(Int, String, Int, Int, Double, Double, Int)] raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "images")
  let results : Array[PdfImageResolutionEntry] = Array::new(
    capacity=page_numbers.length(),
  )
  for page_number in page_numbers {
    let page = pages[page_number - 1]
    let candidates = self.pdf_image_resolution_candidates(page.resources)
    if inline || candidates.length() > 0 {
      self.pdf_image_resolution_process_content(
        page.resources,
        page.content,
        candidates,
        page_number,
        inline,
        @geometry.transform_identity_matrix,
        0,
        results,
      )
    }
  }
  let filtered : Array[PdfImageResolutionEntry] = Array::new(
    capacity=results.length(),
  )
  for entry in results {
    if entry.xdpi < dpi || entry.ydpi < dpi {
      filtered.push(entry)
    }
  }
  filtered.sort_by(pdf_image_resolution_entry_compare)
  [
    for entry in filtered => {
      (
        entry.page_number,
        entry.xobject,
        entry.width,
        entry.height,
        entry.xdpi,
        entry.ydpi,
        entry.object_number,
      )
    }
  ]
}

///|
fn pdf_image_resolution_entry_json(
  entry : (Int, String, Int, Int, Double, Double, Int),
) -> Json {
  Json::object(
    Map([
      ("Object", pdf_image_json_int(entry.6)),
      ("Page", pdf_image_json_int(entry.0)),
      ("XObject", Json::string(entry.1)),
      ("W", pdf_image_json_int(entry.2)),
      ("H", pdf_image_json_int(entry.3)),
      ("Xdpi", Json::number(entry.4)),
      ("Ydpi", Json::number(entry.5)),
    ]),
  )
}

///|
/// Report image resolution data as cpdf-style JSON rows.
pub fn PdfDocument::image_resolution_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> Json raise @core.PdfError {
  Json::array(
    [
      for entry in self.image_resolution(page_numbers, dpi, inline~) => {
        pdf_image_resolution_entry_json(entry)
      }
    ],
  )
}

///|
/// Report image resolution data as UTF-8 JSON bytes.
pub fn PdfDocument::image_resolution_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  @utf8.encode(
    self.image_resolution_json(page_numbers, dpi, inline~).stringify(),
  )
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution`.
pub fn pdf_image_resolution(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> Array[(Int, String, Int, Int, Double, Double, Int)] raise @core.PdfError {
  document.image_resolution(page_numbers, dpi, inline~)
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution_json`.
pub fn pdf_image_resolution_json(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> Json raise @core.PdfError {
  document.image_resolution_json(page_numbers, dpi, inline~)
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution_json_blob`.
pub fn pdf_image_resolution_json_blob(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> @core.PdfBytes raise @core.PdfError {
  document.image_resolution_json_blob(page_numbers, dpi, inline~)
}

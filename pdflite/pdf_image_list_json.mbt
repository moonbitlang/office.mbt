///|
fn pdf_image_list_entry_json(entry : PdfImageListEntry) -> Json {
  entry.pages.sort()
  Json::object(
    Map([
      ("Object", pdf_image_json_int(entry.object_number)),
      (
        "Pages",
        Json::array(
          [
            for page_number in entry.pages => pdf_image_json_int(page_number)
          ],
        ),
      ),
      ("Name", Json::string(entry.name)),
      ("Width", pdf_image_json_int(entry.width)),
      ("Height", pdf_image_json_int(entry.height)),
      ("Bytes", pdf_image_json_int(entry.byte_count)),
      ("BitsPerComponent", pdf_image_json_int_or_null(entry.bits_per_component)),
      ("Colourspace", pdf_image_json_string_or_null(entry.colourspace)),
      ("Filter", pdf_image_json_string_or_null(entry.filter)),
      ("Mask", Json::string(entry.mask)),
      ("MaskObjNum", pdf_image_json_int_or_null(entry.mask_object_number)),
    ]),
  )
}

///|
/// List image XObjects referenced by selected pages as cpdf-style JSON rows.
pub fn PdfDocument::images_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  inline? : Bool = false,
) -> Json raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "images")
  let entries : Array[PdfImageListEntry] = Array::new(
    capacity=page_numbers.length(),
  )
  let form_numbers : @hashmap.HashMap[Int, Bool] = HashMap([])
  for page_number in page_numbers {
    self.pdf_image_collect_page_images(
      pages[page_number - 1],
      page_number,
      inline,
      entries,
      form_numbers,
    )
  }
  Json::array([ for entry in entries => pdf_image_list_entry_json(entry) ])
}

///|
/// List image XObjects referenced by selected pages as UTF-8 JSON bytes.
pub fn PdfDocument::images_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  inline? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  @utf8.encode(self.images_json(page_numbers, inline~).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::images_json`.
pub fn pdf_image_images(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise @core.PdfError {
  document.images_json(page_numbers, inline~)
}

///|
/// Source-spelled compatibility wrapper for cpdfimage's `images`.
pub fn pdf_images(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise @core.PdfError {
  document.images_json(page_numbers, inline~)
}

///|
/// Compatibility wrapper for `PdfDocument::images_json_blob`.
pub fn pdf_image_images_json_blob(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> @core.PdfBytes raise @core.PdfError {
  document.images_json_blob(page_numbers, inline~)
}

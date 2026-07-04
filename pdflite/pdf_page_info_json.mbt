///|
fn pdf_page_info_box_json(box : Array[Double]?) -> Json {
  match box {
    Some(values) => Json::array([ for value in values => Json::number(value) ])
    None => Json::null()
  }
}

///|
fn pdf_page_info_entry_json(entry : PdfPageInfoEntry) -> Json {
  Json::object(
    Map([
      ("Page", pdf_util_json_number(entry.page_number)),
      ("Label", Json::string(entry.label)),
      ("MediaBox", pdf_page_info_box_json(entry.mediabox)),
      ("CropBox", pdf_page_info_box_json(entry.cropbox)),
      ("BleedBox", pdf_page_info_box_json(entry.bleedbox)),
      ("TrimBox", pdf_page_info_box_json(entry.trimbox)),
      ("ArtBox", pdf_page_info_box_json(entry.artbox)),
      ("Rotation", pdf_util_json_number(entry.rotation)),
      ("Annotations", pdf_util_json_number(entry.annotations)),
    ]),
  )
}

///|
/// Return cpdf's page-info JSON array for selected 1-based page numbers.
pub fn PdfDocument::page_info_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : @geometry.PdfUnit = PdfPoint,
) -> Json raise @core.PdfError {
  Json::array(
    [
      for entry in self.pdf_page_info_entries(page_numbers, unit) => {
        pdf_page_info_entry_json(entry)
      }
    ],
  )
}

///|
/// Return cpdf's page-info JSON array as UTF-8 bytes.
pub fn PdfDocument::page_info_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  unit? : @geometry.PdfUnit = PdfPoint,
) -> @core.PdfBytes raise @core.PdfError {
  @utf8.encode(self.page_info_json(page_numbers, unit~).stringify())
}

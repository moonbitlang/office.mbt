///|
/// Return cpdf-style document information report fields as JSON.
pub fn PdfDocument::info_json(
  self : PdfDocument,
  encoding? : @metadata.PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : @geometry.PdfUnit = PdfPoint,
) -> Json raise @core.PdfError {
  let output : Map[String, Json] = Map([])
  let (major, minor) = self.version()
  let pages = self.pages_of_pagetree()
  output.set(
    "Version",
    Json::array([pdf_util_json_number(major), pdf_util_json_number(minor)]),
  )
  output.set("Pages", pdf_util_json_number(pages.length()))
  let info_fields : Array[(String, @core.PdfName)] = [
    ("Title", pdf_metadata_name("/Title")),
    ("Author", pdf_metadata_name("/Author")),
    ("Subject", pdf_metadata_name("/Subject")),
    ("Keywords", pdf_metadata_name("/Keywords")),
    ("Creator", pdf_metadata_name("/Creator")),
    ("Producer", pdf_metadata_name("/Producer")),
    ("Created", pdf_metadata_name("/CreationDate")),
    ("Modified", pdf_metadata_name("/ModDate")),
  ]
  for field in info_fields {
    pdf_metadata_set_json_string(
      output,
      field.0,
      self.pdf_metadata_info_encoded(field.1, encoding),
    )
  }
  output.set(
    "Trapped",
    pdf_metadata_bool_json(
      self.pdf_metadata_info_encoded(pdf_metadata_trapped(), encoding),
    ),
  )
  pdf_metadata_set_json_string(
    output,
    "PageMode",
    self.catalog_item(pdf_metadata_page_mode()),
  )
  pdf_metadata_set_json_string(
    output,
    "PageLayout",
    self.catalog_item(pdf_metadata_page_layout()),
  )
  output.set(
    "OpenAction",
    self.pdf_util_json_of_object(
      self.open_action(),
      true,
      false,
      false,
      false,
      false,
    ),
  )
  let viewer_bool_fields : Array[(String, @core.PdfName)] = [
    ("HideToolbar", pdf_metadata_name("/HideToolbar")),
    ("HideMenubar", pdf_metadata_name("/HideMenubar")),
    ("HideWindowUI", pdf_metadata_name("/HideWindowUI")),
    ("FitWindow", pdf_metadata_name("/FitWindow")),
    ("CenterWindow", pdf_metadata_name("/CenterWindow")),
    ("DisplayDocTitle", pdf_metadata_name("/DisplayDocTitle")),
  ]
  for field in viewer_bool_fields {
    output.set(
      field.0,
      pdf_metadata_bool_json(self.viewer_preference_item(field.1)),
    )
  }
  pdf_metadata_set_json_string(
    output,
    "NonFullPageScreenMode",
    self.viewer_preference_item(pdf_metadata_non_full_screen_page_mode()),
  )
  output.set(
    "AcroForm",
    Json::boolean(self.catalog_item(pdf_metadata_acroform()) != ""),
  )
  output.set("XFA", Json::boolean(self.is_xfa()))
  output.set(
    "Marked",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/Marked"))),
  )
  output.set(
    "UserProperties",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/UserProperties"))),
  )
  output.set(
    "Suspects",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/Suspects"))),
  )
  self.pdf_metadata_info_json_boxes(pages, unit, output)
  Json::object(output)
}

///|
/// Return cpdf-style document information report fields as UTF-8 JSON bytes.
pub fn PdfDocument::info_json_blob(
  self : PdfDocument,
  encoding? : @metadata.PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : @geometry.PdfUnit = PdfPoint,
) -> @core.PdfBytes raise @core.PdfError {
  @utf8.encode(self.info_json(encoding~, unit~).stringify())
}

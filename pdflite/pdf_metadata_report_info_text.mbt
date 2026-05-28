///|
/// Return cpdf-style document information report fields as stdout-style UTF-8 bytes.
pub fn PdfDocument::info_blob(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  let output : Array[String] = []
  let (major, minor) = self.version()
  let pages = self.pages_of_pagetree()
  pdf_metadata_push_text_line(
    output,
    "Version",
    major.to_string() + "." + minor.to_string(),
  )
  pdf_metadata_push_text_line(output, "Pages", pages.length().to_string())
  let info_fields : Array[(String, PdfName)] = [
    ("Title", pdf_metadata_name("/Title")),
    ("Author", pdf_metadata_name("/Author")),
    ("Subject", pdf_metadata_name("/Subject")),
    ("Keywords", pdf_metadata_name("/Keywords")),
    ("Creator", pdf_metadata_name("/Creator")),
    ("Producer", pdf_metadata_name("/Producer")),
    ("Created", pdf_metadata_name("/CreationDate")),
    ("Modified", pdf_metadata_name("/ModDate")),
    ("Trapped", pdf_metadata_trapped()),
  ]
  for field in info_fields {
    pdf_metadata_push_text_line(
      output,
      field.0,
      self.pdf_metadata_info_encoded(field.1, encoding),
    )
  }
  pdf_metadata_push_text_line(
    output,
    "PageMode",
    self.catalog_item(pdf_metadata_page_mode()),
  )
  pdf_metadata_push_text_line(
    output,
    "PageLayout",
    self.catalog_item(pdf_metadata_page_layout()),
  )
  pdf_metadata_push_text_line(output, "OpenAction", self.open_action_string())
  let viewer_fields : Array[(String, PdfName)] = [
    ("HideToolbar", pdf_metadata_name("/HideToolbar")),
    ("HideMenubar", pdf_metadata_name("/HideMenubar")),
    ("HideWindowUI", pdf_metadata_name("/HideWindowUI")),
    ("FitWindow", pdf_metadata_name("/FitWindow")),
    ("CenterWindow", pdf_metadata_name("/CenterWindow")),
    ("DisplayDocTitle", pdf_metadata_name("/DisplayDocTitle")),
    ("NonFullScreenPageMode", pdf_metadata_non_full_screen_page_mode()),
  ]
  for field in viewer_fields {
    pdf_metadata_push_text_line(
      output,
      field.0,
      self.viewer_preference_item(field.1),
    )
  }
  let acroform = match self.catalog_item(pdf_metadata_acroform()) {
    "" => "False"
    value => value
  }
  pdf_metadata_push_text_line(output, "AcroForm", acroform)
  pdf_metadata_push_text_line(
    output,
    "XFA",
    if self.is_xfa() {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "Marked",
    if self.mark_info_item(pdf_metadata_name("/Marked")) {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "UserProperties",
    if self.mark_info_item(pdf_metadata_name("/UserProperties")) {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "Suspects",
    if self.mark_info_item(pdf_metadata_name("/Suspects")) {
      "True"
    } else {
      "False"
    },
  )
  let mediaboxes : Array[PdfObject?] = []
  let cropboxes : Array[PdfObject?] = []
  let bleedboxes : Array[PdfObject?] = []
  let trimboxes : Array[PdfObject?] = []
  let artboxes : Array[PdfObject?] = []
  for page in pages {
    mediaboxes.push(Some(page.mediabox))
    cropboxes.push(self.lookup_direct(pdf_metadata_cropbox(), page.rest))
    bleedboxes.push(self.lookup_direct(pdf_metadata_bleedbox(), page.rest))
    trimboxes.push(self.lookup_direct(pdf_metadata_trimbox(), page.rest))
    artboxes.push(self.lookup_direct(pdf_metadata_artbox(), page.rest))
  }
  pdf_metadata_push_text_line(
    output,
    "MediaBox",
    self.pdf_metadata_info_box_text(mediaboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "CropBox",
    self.pdf_metadata_info_box_text(cropboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "BleedBox",
    self.pdf_metadata_info_box_text(bleedboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "TrimBox",
    self.pdf_metadata_info_box_text(trimboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "ArtBox",
    self.pdf_metadata_info_box_text(artboxes, unit),
  )
  @utf8.encode(output.join(""))
}

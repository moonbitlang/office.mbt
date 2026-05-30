///|
fn pdf_ua_matterhorn_xmp_field_exists(
  metadata : BytesView,
  xml_namespace : String,
  fallback_prefix : String,
  name : String,
) -> Bool {
  pdf_metadata_get_xmp_data(metadata, xml_namespace, fallback_prefix, name)
  is Some(_)
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(_) => None
    None => Some(Json::null())
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(metadata) =>
      if pdf_ua_matterhorn_xmp_field_exists(
          metadata, @metadata.pdf_metadata_pdfuaid_namespace, "pdfuaid", "part",
        ) {
        None
      } else {
        Some(Json::null())
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(metadata) =>
      if pdf_ua_matterhorn_xmp_field_exists(
          metadata, @metadata.pdf_metadata_dc_namespace, "dc", "title",
        ) {
        None
      } else {
        Some(Json::null())
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_display_doc_title(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ua_viewer_preferences_key(),
    pdf_ua_display_doc_title_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_07_001(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_display_doc_title() {
    None => Some(Json::null())
    Some(_) => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_07_002(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_display_doc_title() {
    Some(PdfBoolean(false)) => Some(Json::null())
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_11_001(self : PdfDocument) -> Json? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ua_lang_key(),
    ]) {
    Some(PdfString(value)) if value.length() == 0 =>
      Some(Json::string("Top-level /Lang is empty"))
    None => Some(Json::string("No top-level /Lang"))
    Some(_) => None
  }
}

///|
fn pdf_ua_matterhorn_check_source_unimplemented_language() -> Json? {
  None
}

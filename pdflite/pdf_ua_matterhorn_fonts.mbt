///|
fn pdf_ua_matterhorn_check_10_001_differences(
  differences : @syntax.PdfObject,
) -> Json? {
  match differences {
    PdfArray(items) =>
      for item in items {
        match item {
          PdfNameObject(name) if !pdf_ua_matterhorn_agl_glyph_name(name) =>
            return Some(Json::null())
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_10_001_font(
  self : PdfDocument,
  font : @syntax.PdfObject,
) -> (Json?, Bool) {
  if self.lookup_direct(pdf_text_tounicode_key_name, font) is Some(_) {
    (None, false)
  } else {
    match self.lookup_direct(pdf_text_encoding_key_name, font) {
      Some(PdfNameObject(name)) if name == pdf_text_mac_roman_encoding_name ||
        name == pdf_text_mac_expert_encoding_name ||
        name == pdf_text_win_ansi_encoding_name => (None, false)
      Some(encoding) =>
        match self.lookup_direct(pdf_text_differences_key_name, encoding) {
          Some(differences) =>
            (pdf_ua_matterhorn_check_10_001_differences(differences), false)
          None => (Some(Json::string("No /Differences")), false)
        }
      None =>
        match self.lookup_direct(pdf_text_subtype_key_name, font) {
          Some(PdfNameObject(subtype)) if subtype == pdf_text_type0_name =>
            (None, true)
          _ => (Some(Json::string("Not a Type 0 font")), false)
        }
    }
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_all_page_numbers(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  let pages : Array[Int] = []
  for page in 1..<=self.endpage() {
    pages.push(page)
  }
  pages
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_10_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.list_fonts(self.pdf_ua_matterhorn_all_page_numbers()) {
    match
      (
        self.lookup_direct(pdf_text_type_key_name, entry.font),
        self.lookup_direct(pdf_text_subtype_key_name, entry.font),
      ) {
      (Some(PdfNameObject(type_name)), Some(PdfNameObject(subtype))) if type_name ==
        pdf_text_font_name &&
        (
          subtype == pdf_ua_matterhorn_cid_font_type0() ||
          subtype == pdf_ua_matterhorn_cid_font_type2()
        ) => ()
      (Some(PdfNameObject(type_name)), _) if type_name == pdf_text_font_name => {
        let (failure, unimplemented) = self.pdf_ua_matterhorn_check_10_001_font(
          entry.font,
        )
        if unimplemented {
          return None
        }
        match failure {
          Some(extra) => return Some(extra)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

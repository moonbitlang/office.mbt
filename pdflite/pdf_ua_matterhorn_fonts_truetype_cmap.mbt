///|
fn PdfDocument::pdf_ua_matterhorn_truetype_fontfile(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> PdfBytes? raise PdfError {
  match
    self.lookup_chain(object, [
      pdf_text_font_descriptor_key_name, pdf_text_font_file2_key_name,
    ]) {
    Some(PdfStreamObject(stream)) => {
      let decoded = match
        self.pdf_stream_first_filter_direct(stream.dictionary) {
        None => stream
        Some(_) => self.pdf_decode_stream_until_unknown_value_direct(stream)
      }
      Some(@syntax.pdf_stream_data_bytes(decoded.data))
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_truetype_cmaps(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Array[(Int, Int)]? raise PdfError {
  match self.pdf_ua_matterhorn_truetype_fontfile(object) {
    Some(fontfile) => Some(pdf_truetype_cmaps(fontfile))
    None => None
  }
}

///|
fn pdf_ua_matterhorn_cmaps_contain(
  cmaps : ArrayView[(Int, Int)],
  platform_id : Int,
  encoding_id : Int,
) -> Bool {
  for cmap in cmaps {
    if cmap.0 == platform_id && cmap.1 == encoding_id {
      return true
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_symbolic_cmap(cmap : (Int, Int)) -> Bool {
  (cmap.0 == 1 && cmap.1 == 8) || (cmap.0 == 3 && cmap.1 == 0)
}

///|
fn pdf_ua_matterhorn_cmap_extra(cmap : (Int, Int)) -> Json {
  Json::string("(" + cmap.0.to_string() + ", " + cmap.1.to_string() + ") cmap")
}

///|
// Preserve cpdf source behavior: despite the 31-017 diagnostic saying
// "non-symbolic", the source checks symbolic TrueType fonts and reports any
// non-symbolic cmap entry.
fn PdfDocument::pdf_ua_matterhorn_check_31_017(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) =>
          for cmap in cmaps {
            if !pdf_ua_matterhorn_symbolic_cmap(cmap) {
              return Some(pdf_ua_matterhorn_cmap_extra(cmap))
            }
          }
        None => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_023(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) &&
      self.lookup_chain(entry.2, [
        pdf_text_encoding_key_name, pdf_text_differences_key_name,
      ])
      is Some(_) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if !pdf_ua_matterhorn_cmaps_contain(cmaps, 3, 1) =>
          return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_024(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) &&
      self.lookup_direct(pdf_text_encoding_key_name, entry.2) is Some(_) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_025(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if cmaps.length() == 0 => return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_026(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if cmaps.length() > 1 &&
          !pdf_ua_matterhorn_cmaps_contain(cmaps, 3, 0) =>
          return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

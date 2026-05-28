///|
fn PdfDocument::pdf_ua_matterhorn_is_non_symbolic(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_font_descriptor_key_name, object) {
    Some(descriptor) =>
      match self.lookup_direct(pdf_text_flags_key_name, descriptor) {
        Some(PdfInteger(flags)) => !((flags & 4) > 0)
        _ => true
      }
    None => true
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_truetype(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_text_true_type_name_value
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_non_symbolic_truetype(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  self.pdf_ua_matterhorn_is_truetype(object) &&
  self.pdf_ua_matterhorn_is_non_symbolic(object)
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_019(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) &&
      self.lookup_direct(pdf_text_encoding_key_name, entry.2) is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_020(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2),
        self.lookup_direct(pdf_text_encoding_key_name, entry.2),
      ) {
      (true, Some(PdfDictionary(_) as encoding)) =>
        if self.lookup_direct(pdf_text_base_encoding_key_name, encoding) is None {
          return Some(Json::null())
        }
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_is_mac_roman_or_win_ansi(name : PdfName) -> Bool {
  name == pdf_text_mac_roman_encoding_name ||
  name == pdf_text_win_ansi_encoding_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_021(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) {
      match self.lookup_direct(pdf_text_encoding_key_name, entry.2) {
        Some(PdfNameObject(name)) =>
          if !pdf_ua_matterhorn_is_mac_roman_or_win_ansi(name) {
            return Some(Json::null())
          }
        Some(PdfDictionary(_) as encoding) =>
          match self.lookup_direct(pdf_text_base_encoding_key_name, encoding) {
            Some(PdfNameObject(name)) if pdf_ua_matterhorn_is_mac_roman_or_win_ansi(
                name,
              ) => ()
            Some(base_encoding) =>
              return Some(pdf_ua_matterhorn_object_string_extra(base_encoding))
            None => ()
          }
        _ => ()
      }
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_agl_glyph_name(name : PdfName) -> Bool {
  match pdf_text_codepoints_of_agl_sequence_glyphname(name) {
    Some(_) => true
    None => pdf_text_codepoint_of_agl_base_glyphname(name) is Some(_)
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_022(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) {
      match self.lookup_direct(pdf_text_encoding_key_name, entry.2) {
        Some(encoding) =>
          match self.lookup_direct(pdf_text_differences_key_name, encoding) {
            Some(PdfArray(differences)) =>
              for difference in differences {
                match difference {
                  PdfNameObject(name) if !pdf_ua_matterhorn_agl_glyph_name(name) =>
                    return Some(pdf_ua_matterhorn_name_extra(name))
                  _ => ()
                }
              }
            _ => ()
          }
        None => ()
      }
    }
  }
  None
}

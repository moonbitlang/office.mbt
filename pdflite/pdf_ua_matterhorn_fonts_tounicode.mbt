///|
fn pdf_ua_matterhorn_font_uses_known_encoding(
  document : PdfDocument,
  object : @syntax.PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_text_encoding_key_name, object) {
    Some(PdfNameObject(name)) =>
      name == pdf_text_mac_roman_encoding_name ||
      name == pdf_text_mac_expert_encoding_name ||
      name == pdf_text_win_ansi_encoding_name
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_supported_cid_ordering(name : PdfName) -> Bool {
  name == pdf_ua_matterhorn_gb1_name ||
  name == pdf_ua_matterhorn_cns1_name ||
  name == pdf_ua_matterhorn_japan1_name ||
  name == pdf_ua_matterhorn_korea1_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_type0_uses_supported_cid_collection(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Bool {
  match
    (
      self.lookup_direct(pdf_text_subtype_key_name, object),
      self.lookup_direct(pdf_text_descendant_fonts_key_name, object),
    ) {
    (Some(PdfNameObject(subtype)), Some(PdfArray([descendant]))) if subtype ==
      pdf_text_type0_name =>
      match self.lookup_direct(pdf_text_cid_system_info_key_name, descendant) {
        Some(info) =>
          match
            (
              self.lookup_direct(pdf_text_registry_key_name, info),
              self.lookup_direct(pdf_text_ordering_key_name, info),
            ) {
            (Some(PdfNameObject(registry)), Some(PdfNameObject(ordering))) =>
              registry == pdf_ua_matterhorn_adobe() &&
              pdf_ua_matterhorn_supported_cid_ordering(ordering)
            _ => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_source_silences_missing_tounicode(
  subtype : PdfName,
) -> Bool {
  subtype == pdf_text_type0_name ||
  subtype == pdf_ua_matterhorn_cid_font_type0() ||
  subtype == pdf_ua_matterhorn_cid_font_type2()
}

///|
fn pdf_ua_matterhorn_missing_tounicode_source_unimplemented(
  subtype : PdfName,
) -> Bool {
  subtype == pdf_text_type1_name ||
  subtype == pdf_text_mmtype1_name ||
  subtype == pdf_text_type3_name
}

///|
/// Preserve cpdf source behavior: the Type1/Type3 referenced-glyph branch raises
/// MatterhornUnimplemented and is caught by the source runner as no failure.
fn PdfDocument::pdf_ua_matterhorn_check_31_027(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.lookup_direct(pdf_text_tounicode_key_name, entry.2) is None {
      match self.lookup_direct(pdf_text_type_key_name, entry.2) {
        Some(PdfNameObject(type_name)) if type_name == pdf_text_font_name =>
          if !pdf_ua_matterhorn_font_uses_known_encoding(self, entry.2) &&
            !self.pdf_ua_matterhorn_type0_uses_supported_cid_collection(entry.2) &&
            !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
            match self.lookup_direct(pdf_text_subtype_key_name, entry.2) {
              Some(PdfNameObject(subtype)) if pdf_ua_matterhorn_source_silences_missing_tounicode(
                  subtype,
                ) => ()
              Some(PdfNameObject(subtype)) if pdf_ua_matterhorn_missing_tounicode_source_unimplemented(
                  subtype,
                ) => return None
              _ => return Some(pdf_ua_matterhorn_object_string_extra(entry.2))
            }
          }
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_tounicode_numbers(
  self : PdfDocument,
) -> Array[Int] {
  let numbers : Array[Int] = []
  for entry in self.parsed_object_entries() {
    match self.indirect_number(pdf_text_tounicode_key_name, entry.2) {
      Some(number) if !pdf_ua_matterhorn_int_array_contains(numbers, number) =>
        numbers.push(number)
      _ => ()
    }
  }
  numbers
}

///|
fn pdf_ua_matterhorn_tounicode_has_codepoint(
  map : ArrayView[(Int, PdfBytes)],
  codepoint : Int,
) -> Bool raise PdfError {
  for entry in map {
    for parsed_codepoint in pdf_codepoints_of_utf16be(entry.1) {
      if parsed_codepoint == codepoint {
        return true
      }
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_028(
  self : PdfDocument,
) -> Json? raise PdfError {
  for number in self.pdf_ua_matterhorn_tounicode_numbers() {
    let parsed = self.parse_cmap(PdfIndirect(number))
    if pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_029(
  self : PdfDocument,
) -> Json? raise PdfError {
  for number in self.pdf_ua_matterhorn_tounicode_numbers() {
    let parsed = self.parse_cmap(PdfIndirect(number))
    if pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0xFEFF) ||
      pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0xFFFE) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_check_source_unimplemented_font_file() -> Json? {
  None
}

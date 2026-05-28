///|
fn PdfDocument::pdf_ua_matterhorn_type0_indirect_encoding(
  self : PdfDocument,
  object : PdfObject,
) -> Int? {
  let direct_object = self.direct(object)
  match
    (
      self.lookup_direct(pdf_ua_subtype_key(), direct_object),
      direct_object.lookup_immediate(pdf_ua_matterhorn_encoding_key()),
    ) {
    (Some(PdfNameObject(subtype)), Some(PdfNameObject(encoding))) if subtype ==
      pdf_ua_matterhorn_type0() &&
      (
        encoding == pdf_ua_matterhorn_identity_h() ||
        encoding == pdf_ua_matterhorn_identity_v()
      ) => None
    (Some(PdfNameObject(subtype)), Some(PdfIndirect(encoding_number))) if subtype ==
      pdf_ua_matterhorn_type0() => Some(encoding_number)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_cid_system_entry(
  self : PdfDocument,
  object : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match self.lookup_direct(pdf_ua_matterhorn_cid_system_info_key(), object) {
    Some(info) => self.lookup_direct(key, info)
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_descendant_cid_system_entry(
  self : PdfDocument,
  type0_font : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match
    self.lookup_direct(pdf_ua_matterhorn_descendant_fonts_key(), type0_font) {
    Some(PdfArray([descendant, ..])) =>
      self.pdf_ua_matterhorn_cid_system_entry(descendant, key)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_type0_cid_system_entry(
  self : PdfDocument,
  key : PdfName,
) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.pdf_ua_matterhorn_type0_indirect_encoding(entry.2) {
      Some(encoding_number) =>
        if self.pdf_ua_matterhorn_cid_system_entry(
            PdfIndirect(encoding_number),
            key,
          ) !=
          self.pdf_ua_matterhorn_descendant_cid_system_entry(entry.2, key) {
          return Some(Json::null())
        }
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_001(self : PdfDocument) -> Json? {
  self.pdf_ua_matterhorn_check_type0_cid_system_entry(
    pdf_ua_matterhorn_registry_key(),
  )
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_002(self : PdfDocument) -> Json? {
  self.pdf_ua_matterhorn_check_type0_cid_system_entry(
    pdf_ua_matterhorn_ordering_key(),
  )
}

///|
// Preserve cpdf source behavior: 31-003 reports a Supplement comparison, but
// checks the CMap /Registry against the descendant CIDFont /Ordering.
fn PdfDocument::pdf_ua_matterhorn_check_31_003(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.pdf_ua_matterhorn_type0_indirect_encoding(entry.2) {
      Some(encoding_number) =>
        if self.pdf_ua_matterhorn_cid_system_entry(
            PdfIndirect(encoding_number),
            pdf_ua_matterhorn_registry_key(),
          ) !=
          self.pdf_ua_matterhorn_descendant_cid_system_entry(
            entry.2,
            pdf_ua_matterhorn_ordering_key(),
          ) {
          return Some(Json::null())
        }
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_cid_font_type2(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) =>
      subtype == pdf_ua_matterhorn_cid_font_type2()
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_object_string_extra(object : PdfObject) -> Json {
  let bytes = pdf_write_object(object) catch { _ => b"" }
  Json::string(@ascii.decode_lossy(bytes))
}

///|
fn pdf_ua_matterhorn_name_extra(name : PdfName) -> Json {
  Json::string(@ascii.decode_lossy(name.bytes()))
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_004(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_cid_font_type2(entry.2) {
      match
        self.lookup_direct(pdf_ua_matterhorn_cid_to_gid_map_key(), entry.2) {
        Some(PdfNameObject(name)) if name == pdf_ua_matterhorn_identity() => ()
        Some(PdfStreamObject(_)) => ()
        _ => return Some(pdf_ua_matterhorn_object_string_extra(entry.2))
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_005(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_cid_font_type2(entry.2) &&
      self.lookup_direct(pdf_ua_matterhorn_cid_to_gid_map_key(), entry.2)
      is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_006(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_subtype_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_encoding_key(), entry.2),
      ) {
      (Some(PdfNameObject(subtype)), Some(PdfNameObject(encoding))) if subtype ==
        pdf_ua_matterhorn_type0() &&
        !pdf_ua_matterhorn_cmap_name_is_listed(encoding) =>
        return Some(pdf_ua_matterhorn_name_extra(encoding))
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_007(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_matterhorn_wmode_key(), entry.2) {
      Some(PdfInteger(from_dictionary)) => {
        let bytes = self.pdf_text_decoded_cmap_stream_data_direct(entry.2)
        let from_stream = match pdf_parse_cmap_data(bytes).wmode {
          Some(value) => value
          None => 0
        }
        if from_stream != from_dictionary {
          return Some(Json::null())
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_008(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_matterhorn_usecmap_key(), entry.2) {
      Some(PdfNameObject(name)) if !pdf_ua_matterhorn_cmap_name_is_listed(name) =>
        return Some(pdf_ua_matterhorn_name_extra(name))
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_missing_font_extra(entry : PdfMissingFontEntry) -> Json {
  Json::string(
    entry.page.to_string() +
    " " +
    entry.name +
    " " +
    entry.subtype +
    " " +
    entry.basefont +
    " " +
    entry.encoding,
  )
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_009(
  self : PdfDocument,
) -> Json? raise PdfError {
  let page_count = self.pages_of_pagetree().length()
  let missing = self.missing_fonts(
    [
      for page_number in 1..<=page_count => page_number
    ],
  )
  if missing.length() == 0 {
    None
  } else {
    Some(
      Json::array(
        [
          for entry in missing => pdf_ua_matterhorn_missing_font_extra(entry)
        ],
      ),
    )
  }
}

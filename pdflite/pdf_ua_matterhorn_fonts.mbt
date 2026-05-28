///|
fn pdf_ua_matterhorn_check_10_001_differences(differences : PdfObject) -> Json? {
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
  font : PdfObject,
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

///|
fn PdfDocument::pdf_ua_matterhorn_truetype_fontfile(
  self : PdfDocument,
  object : PdfObject,
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
      Some(pdf_stream_data_bytes(decoded.data))
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_truetype_cmaps(
  self : PdfDocument,
  object : PdfObject,
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

///|
fn pdf_ua_matterhorn_font_uses_known_encoding(
  document : PdfDocument,
  object : PdfObject,
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
  object : PdfObject,
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

///|
fn pdf_text_notdef_name() -> PdfName {
  pdf_text_name(".notdef")
}

///|
fn pdf_text_tounicode_glyphname(bytes : PdfBytes) -> PdfName {
  let output : Array[Byte] = [47]
  for byte in bytes {
    output.push(byte)
  }
  pdf_name_of_bytes(Bytes::from_array(output))
}

///|
fn PdfTextExtractor::pdf_text_encoded_glyph_of_charcode(
  self : PdfTextExtractor,
  code : Int,
) -> PdfTextGlyph {
  match self.font.pdf_text_glyphname_of_charcode(code) {
    Some(glyphname) =>
      match self.font.pdf_text_codepoints_of_glyphname(glyphname) {
        Some(codepoints) => { glyphname, codepoints }
        None => { glyphname, codepoints: [code] }
      }
    None => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
  }
}

///|
fn pdf_text_lookup_cmap_cid(map : ArrayView[(Int, Int)], code : Int) -> Int? {
  for entry in map {
    if entry.0 == code {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_reverse_lookup_cmap_cid(
  map : ArrayView[(Int, Int)],
  cid : Int,
) -> Int? {
  for entry in map {
    if entry.1 == cid {
      break Some(entry.0)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_cmap_has_charcode(map : ArrayView[(Int, Int)], code : Int) -> Bool {
  for entry in map {
    if entry.0 == code {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_cmap_has_charcode_in_any(
  first : ArrayView[(Int, Int)],
  second : ArrayView[(Int, Int)],
  code : Int,
) -> Bool {
  pdf_text_cmap_has_charcode(first, code) ||
  pdf_text_cmap_has_charcode(second, code)
}

///|
fn pdf_text_parsed_cmap_has_explicit_charcode(
  parsed : PdfParsedCMap,
  code : Int,
) -> Bool {
  pdf_text_tounicode_has_charcode(parsed.map, code) ||
  pdf_text_cmap_has_charcode_in_any(parsed.cid_map, parsed.notdef_map, code)
}

///|
fn PdfFont::pdf_text_external_cmap_codepoints(
  self : PdfFont,
  code : Int,
) -> Array[Int]? {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfExternalCMap(_, parsed) =>
          match pdf_text_lookup_cmap_cid(parsed.cid_map, code) {
            Some(cid) => Some([cid])
            None =>
              match pdf_text_lookup_cmap_cid(parsed.notdef_map, code) {
                Some(cid) => Some([cid])
                None =>
                  match pdf_text_lookup_tounicode_codepoints(parsed.map, code) {
                    Some(codepoints) => Some(codepoints)
                    None =>
                      match pdf_text_parsed_cmap_predefined_base(parsed) {
                        Some(name) => {
                          let base_font : PdfFont = PdfFontCIDKeyed({
                            ..font,
                            encoding: PdfPredefinedCMap(name),
                          })
                          match
                            base_font.pdf_text_predefined_builtin_codepoints(
                              code,
                            ) {
                            Some(codepoints) => Some(codepoints)
                            None => None
                          }
                        }
                        None =>
                          if pdf_text_parsed_cmap_has_identity_base(parsed) &&
                            code >= 0 &&
                            code <= 0xFFFF {
                            Some([code])
                          } else {
                            None
                          }
                      }
                  }
              }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn pdf_text_external_cmap_codepoints_from_lookup(
  font : PdfCIDKeyedFont,
  parsed : PdfParsedCMap,
  lookup : PdfTextExternalCMapLookup,
  code : Int,
) -> Array[Int]? {
  match lookup.cid_map.get(code) {
    Some(cid) => Some([cid])
    None =>
      match lookup.notdef_map.get(code) {
        Some(cid) => Some([cid])
        None =>
          match lookup.map.get(code) {
            Some(codepoints) => Some(codepoints)
            None =>
              match pdf_text_parsed_cmap_predefined_base(parsed) {
                Some(name) => {
                  let base_font : PdfFont = PdfFontCIDKeyed({
                    ..font,
                    encoding: PdfPredefinedCMap(name),
                  })
                  base_font.pdf_text_predefined_builtin_codepoints(code)
                }
                None =>
                  if pdf_text_parsed_cmap_has_identity_base(parsed) &&
                    code >= 0 &&
                    code <= 0xFFFF {
                    Some([code])
                  } else {
                    None
                  }
              }
          }
      }
  }
}

///|
fn PdfFont::pdf_text_external_cmap_charcode(self : PdfFont, cid : Int) -> Int? {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfExternalCMap(_, parsed) =>
          match pdf_text_reverse_lookup_cmap_cid(parsed.cid_map, cid) {
            Some(code) => Some(code)
            None =>
              match pdf_text_reverse_lookup_cmap_cid(parsed.notdef_map, cid) {
                Some(code) =>
                  if pdf_text_cmap_has_charcode(parsed.cid_map, code) {
                    None
                  } else {
                    Some(code)
                  }
                None =>
                  match
                    pdf_text_reverse_lookup_tounicode_charcode(
                      parsed.map,
                      cid,
                      parsed.cid_map,
                      parsed.notdef_map,
                    ) {
                    Some(code) => Some(code)
                    None =>
                      match pdf_text_parsed_cmap_predefined_base(parsed) {
                        Some(name) => {
                          let base_font : PdfFont = PdfFontCIDKeyed({
                            ..font,
                            encoding: PdfPredefinedCMap(name),
                          })
                          match
                            base_font.pdf_text_predefined_builtin_charcode(cid) {
                            Some(code) =>
                              if pdf_text_parsed_cmap_has_explicit_charcode(
                                  parsed, code,
                                ) {
                                None
                              } else {
                                Some(code)
                              }
                            None => None
                          }
                        }
                        None =>
                          if pdf_text_parsed_cmap_has_identity_base(parsed) &&
                            cid >= 0 &&
                            cid <= 0xFFFF &&
                            !pdf_text_parsed_cmap_has_explicit_charcode(
                              parsed, cid,
                            ) {
                            Some(cid)
                          } else {
                            None
                          }
                      }
                  }
              }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn PdfFont::pdf_text_predefined_builtin_codepoints(
  self : PdfFont,
  code : Int,
) -> Array[Int]? {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfPredefinedCMap(name) =>
          match pdf_text_predefined_direct_unicode_codepoints(name, code) {
            Some(codepoints) => Some(codepoints)
            None =>
              match pdf_text_predefined_japan1_builtin_codepoints(name, code) {
                Some(codepoints) => Some(codepoints)
                None =>
                  if pdf_text_predefined_cmap_uses_shift_jis_charcodes(name) {
                    match pdf_text_predefined_rksj_single_byte_codepoint(code) {
                      Some(codepoint) => Some([codepoint])
                      None => None
                    }
                  } else if pdf_text_predefined_cmap_uses_gb_euc_charcodes(name) {
                    match
                      pdf_text_predefined_vertical_codepoint(
                        pdf_text_predefined_gb1_vertical_codepoint_table(name),
                        code,
                      ) {
                      Some(codepoint) => Some([codepoint])
                      None =>
                        match pdf_text_predefined_gb_euc_codepoint(code) {
                          Some(codepoint) => Some([codepoint])
                          None => None
                        }
                    }
                  } else if pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(
                      name,
                    ) {
                    match
                      pdf_text_predefined_vertical_codepoint(
                        pdf_text_predefined_gb1_vertical_codepoint_table(name),
                        code,
                      ) {
                      Some(codepoint) => Some([codepoint])
                      None => pdf_text_predefined_gbpc_euc_codepoints(code)
                    }
                  } else {
                    match
                      pdf_text_predefined_cns1_builtin_codepoints(name, code) {
                      Some(codepoints) => Some(codepoints)
                      None =>
                        if pdf_text_predefined_cmap_uses_uhc_charcodes(name) {
                          match
                            pdf_text_predefined_vertical_codepoint(
                              pdf_text_predefined_korea1_vertical_codepoint_table(
                                name,
                              ),
                              code,
                            ) {
                            Some(codepoint) => Some([codepoint])
                            None =>
                              match pdf_text_predefined_uhc_codepoint(code) {
                                Some(codepoint) => Some([codepoint])
                                None => None
                              }
                          }
                        } else if pdf_text_predefined_cmap_uses_ksc_euc_charcodes(
                            name,
                          ) {
                          match
                            pdf_text_predefined_vertical_codepoint(
                              pdf_text_predefined_korea1_vertical_codepoint_table(
                                name,
                              ),
                              code,
                            ) {
                            Some(codepoint) => Some([codepoint])
                            None =>
                              match
                                pdf_text_predefined_ksc_euc_codepoint(code) {
                                Some(codepoint) => Some([codepoint])
                                None => None
                              }
                          }
                        } else if pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(
                            name,
                          ) {
                          match
                            pdf_text_predefined_vertical_codepoint(
                              pdf_text_predefined_korea1_vertical_codepoint_table(
                                name,
                              ),
                              code,
                            ) {
                            Some(codepoint) => Some([codepoint])
                            None =>
                              pdf_text_predefined_kscpc_euc_codepoints(code)
                          }
                        } else if pdf_text_predefined_cmap_uses_gbk2k_charcodes(
                            name,
                          ) {
                          match
                            pdf_text_predefined_vertical_codepoint(
                              pdf_text_predefined_gb1_vertical_codepoint_table(
                                name,
                              ),
                              code,
                            ) {
                            Some(codepoint) => Some([codepoint])
                            None =>
                              match pdf_text_predefined_gbk2k_codepoint(code) {
                                Some(codepoint) => Some([codepoint])
                                None => None
                              }
                          }
                        } else if pdf_text_predefined_cmap_uses_gbk_charcodes(
                            name,
                          ) {
                          match
                            pdf_text_predefined_vertical_codepoint(
                              pdf_text_predefined_gb1_vertical_codepoint_table(
                                name,
                              ),
                              code,
                            ) {
                            Some(codepoint) => Some([codepoint])
                            None =>
                              match pdf_text_predefined_gbk_codepoint(code) {
                                Some(codepoint) => Some([codepoint])
                                None => None
                              }
                          }
                        } else {
                          None
                        }
                    }
                  }
              }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn PdfFont::pdf_text_predefined_builtin_charcode(
  self : PdfFont,
  codepoint : Int,
) -> Int? {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfPredefinedCMap(name) =>
          match pdf_text_predefined_direct_unicode_charcode(name, codepoint) {
            Some(code) => Some(code)
            None =>
              match
                pdf_text_predefined_japan1_builtin_charcode(name, codepoint) {
                Some(code) => Some(code)
                None =>
                  if pdf_text_predefined_cmap_uses_shift_jis_charcodes(name) {
                    pdf_text_predefined_rksj_single_byte_charcode(codepoint)
                  } else if pdf_text_predefined_cmap_uses_gb_euc_charcodes(name) {
                    match
                      pdf_text_predefined_vertical_charcode(
                        pdf_text_predefined_gb1_vertical_charcode_table(name),
                        codepoint,
                      ) {
                      Some(code) => Some(code)
                      None => pdf_text_predefined_gb_euc_charcode(codepoint)
                    }
                  } else if pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(
                      name,
                    ) {
                    match
                      pdf_text_predefined_vertical_charcode(
                        pdf_text_predefined_gb1_vertical_charcode_table(name),
                        codepoint,
                      ) {
                      Some(code) => Some(code)
                      None => pdf_text_predefined_gbpc_euc_charcode(codepoint)
                    }
                  } else {
                    match
                      pdf_text_predefined_cns1_builtin_charcode(name, codepoint) {
                      Some(code) => Some(code)
                      None =>
                        if pdf_text_predefined_cmap_uses_uhc_charcodes(name) {
                          match
                            pdf_text_predefined_vertical_charcode(
                              pdf_text_predefined_korea1_vertical_charcode_table(
                                name,
                              ),
                              codepoint,
                            ) {
                            Some(code) => Some(code)
                            None => pdf_text_predefined_uhc_charcode(codepoint)
                          }
                        } else if pdf_text_predefined_cmap_uses_ksc_euc_charcodes(
                            name,
                          ) {
                          match
                            pdf_text_predefined_vertical_charcode(
                              pdf_text_predefined_korea1_vertical_charcode_table(
                                name,
                              ),
                              codepoint,
                            ) {
                            Some(code) => Some(code)
                            None =>
                              pdf_text_predefined_ksc_euc_charcode(codepoint)
                          }
                        } else if pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(
                            name,
                          ) {
                          match
                            pdf_text_predefined_vertical_charcode(
                              pdf_text_predefined_korea1_vertical_charcode_table(
                                name,
                              ),
                              codepoint,
                            ) {
                            Some(code) => Some(code)
                            None =>
                              pdf_text_predefined_kscpc_euc_charcode(codepoint)
                          }
                        } else if pdf_text_predefined_cmap_uses_gbk2k_charcodes(
                            name,
                          ) {
                          match
                            pdf_text_predefined_vertical_charcode(
                              pdf_text_predefined_gb1_vertical_charcode_table(
                                name,
                              ),
                              codepoint,
                            ) {
                            Some(code) => Some(code)
                            None =>
                              pdf_text_predefined_gbk2k_charcode(codepoint)
                          }
                        } else if pdf_text_predefined_cmap_uses_gbk_charcodes(
                            name,
                          ) {
                          match
                            pdf_text_predefined_vertical_charcode(
                              pdf_text_predefined_gb1_vertical_charcode_table(
                                name,
                              ),
                              codepoint,
                            ) {
                            Some(code) => Some(code)
                            None => pdf_text_predefined_gbk_charcode(codepoint)
                          }
                        } else {
                          None
                        }
                    }
                  }
              }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn PdfTextExtractor::pdf_text_glyph_of_charcode(
  self : PdfTextExtractor,
  code : Int,
) -> PdfTextGlyph {
  match self.font.pdf_text_tounicode() {
    Some(tounicode) =>
      match pdf_text_lookup_tounicode(tounicode, code) {
        Some(bytes) =>
          try pdf_codepoints_of_utf16be(bytes) catch {
            _ => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
          } noraise {
            codepoints =>
              { glyphname: pdf_text_tounicode_glyphname(bytes), codepoints }
          }
        None => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
      }
    None =>
      match self.font.pdf_text_predefined_builtin_codepoints(code) {
        Some(codepoints) => { glyphname: pdf_text_notdef_name(), codepoints }
        None =>
          match self.font.pdf_text_external_cmap_codepoints(code) {
            Some(codepoints) =>
              { glyphname: pdf_text_notdef_name(), codepoints }
            None => self.pdf_text_encoded_glyph_of_charcode(code)
          }
      }
  }
}

///|
fn pdf_text_push_two_byte_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  guard index + 1 < text.length() else { raise BadText }
  output.push((text[index].to_int() << 8) | text[index + 1].to_int())
  index + 2
}

///|
fn pdf_text_push_three_byte_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  guard index + 2 < text.length() else { raise BadText }
  output.push(
    (((text[index].to_int() << 8) | text[index + 1].to_int()) << 8) |
    text[index + 2].to_int(),
  )
  index + 3
}

///|
fn pdf_text_push_four_byte_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  guard index + 3 < text.length() else { raise BadText }
  output.push(
    (
      (
        (((text[index].to_int() << 8) | text[index + 1].to_int()) << 8) |
        text[index + 2].to_int()
      ) <<
      8
    ) |
    text[index + 3].to_int(),
  )
  index + 4
}

///|
fn pdf_text_push_utf8_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  let first = text[index].to_int()
  let (length, code) = if first >> 7 == 0 {
    (1, first)
  } else if first >> 5 == 0b110 {
    guard index + 1 < text.length() else { raise InvalidUTF8 }
    (2, pdf_text_pack_two_bytes(first, text[index + 1].to_int()))
  } else if first >> 4 == 0b1110 {
    guard index + 2 < text.length() else { raise InvalidUTF8 }
    (3, pdf_text_pack_bytes_as_charcode(text[index:index + 3]))
  } else if first >> 3 == 0b11110 {
    guard index + 3 < text.length() else { raise InvalidUTF8 }
    (
      4,
      pdf_text_pack_four_bytes(
        first,
        text[index + 1].to_int(),
        text[index + 2].to_int(),
        text[index + 3].to_int(),
      ),
    )
  } else {
    raise InvalidUTF8
  }
  guard pdf_text_predefined_utf8_codepoints(code) is Some(_) else {
    raise InvalidUTF8
  }
  output.push(code)
  index + length
}

///|
fn pdf_text_push_utf16_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  let first = pdf_text_pack_two_bytes(
    text[index].to_int(),
    text[index + 1].to_int(),
  )
  if first >= 0xD800 && first <= 0xDBFF {
    guard index + 3 < text.length() else { raise InvalidUTF16BE }
    let second = pdf_text_pack_two_bytes(
      text[index + 2].to_int(),
      text[index + 3].to_int(),
    )
    guard second >= 0xDC00 && second <= 0xDFFF else { raise InvalidUTF16BE }
    output.push(
      pdf_text_pack_four_bytes(
        first >> 8,
        first & 0xFF,
        second >> 8,
        second & 0xFF,
      ),
    )
    index + 4
  } else if first >= 0xDC00 && first <= 0xDFFF {
    raise InvalidUTF16BE
  } else {
    output.push(first)
    index + 2
  }
}

///|
fn pdf_text_push_utf32_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  guard index + 3 < text.length() else { raise BadText }
  let code = pdf_text_pack_four_bytes(
    text[index].to_int(),
    text[index + 1].to_int(),
    text[index + 2].to_int(),
    text[index + 3].to_int(),
  )
  guard pdf_text_valid_unicode_codepoint(code) else {
    raise InvalidUnicodeCodepoint(code)
  }
  output.push(code)
  index + 4
}

///|
fn pdf_text_shift_jis_lead_byte(byte : Int) -> Bool {
  (byte >= 0x81 && byte <= 0x9F) || (byte >= 0xE0 && byte <= 0xFC)
}

///|
fn pdf_text_gbk2k_four_byte_prefix(first : Int, second : Int) -> Bool {
  first >= 0x81 && first <= 0xFE && second >= 0x30 && second <= 0x39
}

///|
fn pdf_text_predefined_mixed_byte_charcodes(
  name : PdfName,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let output : Array[Int] = Array::new(capacity=text.length())
  let shift_jis = pdf_text_predefined_cmap_uses_shift_jis_charcodes(name)
  let b5pc = pdf_text_predefined_cmap_uses_b5pc_charcodes(name)
  let cns1_b5 = pdf_text_predefined_cmap_uses_cns1_b5_charcodes(name)
  let cns_euc = pdf_text_predefined_cmap_uses_cns_euc_charcodes(name)
  let hkscs = pdf_text_predefined_cmap_uses_hkscs_charcodes(name)
  let gbpc_euc = pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(name)
  let hojo_euc = pdf_text_predefined_cmap_uses_hojo_euc_charcodes(name)
  let ksc_euc = pdf_text_predefined_cmap_uses_ksc_euc_charcodes(name)
  let kscpc_euc = pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(name)
  let gbk2k = pdf_text_predefined_cmap_uses_gbk2k_charcodes(name)
  let gbk = pdf_text_predefined_cmap_uses_gbk_charcodes(name)
  let mut index = 0
  while index < text.length() {
    let first = text[index].to_int()
    if shift_jis {
      if pdf_text_shift_jis_lead_byte(first) {
        index = pdf_text_push_two_byte_charcode(output, text, index)
      } else {
        output.push(first)
        index += 1
      }
    } else if hojo_euc {
      index = pdf_text_push_three_byte_charcode(output, text, index)
    } else if gbk2k &&
      index + 1 < text.length() &&
      pdf_text_gbk2k_four_byte_prefix(first, text[index + 1].to_int()) {
      index = pdf_text_push_four_byte_charcode(output, text, index)
    } else if cns_euc && first == 0x8E {
      index = pdf_text_push_four_byte_charcode(output, text, index)
    } else if first < 0x80 ||
      (cns_euc && first == 0x80) ||
      (
        b5pc &&
        (
          first == 0x80 ||
          (first >= 0x83 && first <= 0xA0) ||
          (first >= 0xFD && first <= 0xFF)
        )
      ) ||
      (
        gbpc_euc &&
        (
          first == 0x80 ||
          (first >= 0x83 && first <= 0xA0) ||
          (first >= 0xFD && first <= 0xFF)
        )
      ) ||
      (ksc_euc && first == 0x80) ||
      (
        kscpc_euc &&
        ((first >= 0x80 && first <= 0x9F) || first == 0xFE || first == 0xFF)
      ) ||
      (cns1_b5 && first == 0x80) ||
      (hkscs && first == 0x80) ||
      (gbk && (first == 0x80 || first == 0xFF)) {
      output.push(first)
      index += 1
    } else {
      index = pdf_text_push_two_byte_charcode(output, text, index)
    }
  }
  output
}

///|
fn pdf_text_predefined_cmap_charcodes_of_text(
  name : PdfName,
  text : BytesView,
) -> Array[Int] raise PdfError {
  if pdf_text_predefined_cmap_uses_utf8_charcodes(name) {
    let output : Array[Int] = Array::new(capacity=text.length())
    let mut index = 0
    while index < text.length() {
      index = pdf_text_push_utf8_charcode(output, text, index)
    }
    output
  } else if pdf_text_predefined_cmap_uses_utf16_charcodes(name) {
    guard text.length() % 2 == 0 else { raise BadText }
    let output : Array[Int] = Array::new(capacity=text.length() / 2)
    let mut index = 0
    while index < text.length() {
      index = pdf_text_push_utf16_charcode(output, text, index)
    }
    output
  } else if pdf_text_predefined_cmap_uses_utf32_charcodes(name) {
    guard text.length() % 4 == 0 else { raise BadText }
    let output : Array[Int] = Array::new(capacity=text.length() / 4)
    let mut index = 0
    while index < text.length() {
      index = pdf_text_push_utf32_charcode(output, text, index)
    }
    output
  } else if pdf_text_predefined_cmap_uses_mixed_byte_charcodes(name) {
    pdf_text_predefined_mixed_byte_charcodes(name, text)
  } else {
    let output : Array[Int] = Array::new(capacity=text.length())
    if name == pdf_text_identity_h_name ||
      name == pdf_text_identity_v_name ||
      pdf_text_predefined_cmap_uses_two_byte_charcodes(name) {
      guard text.length() % 2 == 0 else { raise BadText }
      let mut index = 0
      while index < text.length() {
        index = pdf_text_push_two_byte_charcode(output, text, index)
      }
    } else {
      for byte in text {
        output.push(byte.to_int())
      }
    }
    output
  }
}

///|
fn PdfFont::pdf_text_charcodes_of_text(
  self : PdfFont,
  text : BytesView,
) -> Array[Int] raise PdfError {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfPredefinedCMap(name) =>
          pdf_text_predefined_cmap_charcodes_of_text(name, text)
        PdfExternalCMap(_, parsed) =>
          pdf_text_parsed_cmap_charcodes_of_text(parsed, text)
        _ => self.pdf_text_fixed_or_single_byte_charcodes_of_text(text)
      }
    _ => self.pdf_text_fixed_or_single_byte_charcodes_of_text(text)
  }
}

///|
fn PdfFont::pdf_text_fixed_or_single_byte_charcodes_of_text(
  self : PdfFont,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let output : Array[Int] = Array::new(capacity=text.length())
  if self.uses_two_byte_codes() {
    guard text.length() % 2 == 0 else { raise BadText }
    let mut index = 0
    while index < text.length() {
      index = pdf_text_push_two_byte_charcode(output, text, index)
    }
  } else {
    for byte in text {
      output.push(byte.to_int())
    }
  }
  output
}

///|
/// Resolve glyph names and Unicode codepoints for each character code in text.
///
/// This lower-level extractor exposes both sides of the mapping. The input is
/// a PDF text byte sequence, not a MoonBit `String`, and malformed byte
/// segmentation raises `PdfError`.
pub fn PdfTextExtractor::glyphnames_and_codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfTextGlyph] raise PdfError {
  [
    for code in self.font.pdf_text_charcodes_of_text(text) => {
      self.pdf_text_glyph_of_charcode(code)
    }
  ]
}

///|
fn PdfTextExtractor::pdf_text_external_cmap_codepoints_of_text(
  self : PdfTextExtractor,
  font : PdfCIDKeyedFont,
  parsed : PdfParsedCMap,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let lookup = pdf_text_external_cmap_lookup(parsed)
  let output : Array[Int] = Array::new(capacity=text.length())
  for code in pdf_text_parsed_cmap_charcodes_of_text(parsed, text) {
    let codepoints = match
      pdf_text_external_cmap_codepoints_from_lookup(font, parsed, lookup, code) {
      Some(codepoints) => codepoints
      None => self.pdf_text_encoded_glyph_of_charcode(code).codepoints
    }
    for codepoint in codepoints {
      output.push(codepoint)
    }
  }
  output
}

///|
fn PdfTextExtractor::pdf_text_tounicode_codepoints_of_text(
  self : PdfTextExtractor,
  tounicode : ArrayView[(Int, PdfBytes)],
  text : BytesView,
) -> Array[Int] raise PdfError {
  let lookup = pdf_text_tounicode_codepoints_lookup_map(tounicode)
  let output : Array[Int] = Array::new(capacity=text.length())
  for code in self.font.pdf_text_charcodes_of_text(text) {
    match lookup.get(code) {
      Some(codepoints) =>
        for codepoint in codepoints {
          output.push(codepoint)
        }
      None => output.push(code)
    }
  }
  output
}

///|
fn PdfTextExtractor::pdf_text_regular_codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let output : Array[Int] = Array::new(capacity=text.length())
  for code in self.font.pdf_text_charcodes_of_text(text) {
    for codepoint in self.pdf_text_glyph_of_charcode(code).codepoints {
      output.push(codepoint)
    }
  }
  output
}

///|
/// Extract Unicode codepoints from PDF text bytes.
///
/// `/ToUnicode` mappings take precedence. External CMaps, predefined CMaps,
/// glyph names, and font-specific fallbacks are used when no explicit
/// ToUnicode mapping exists. Multi-codepoint glyph names are flattened into
/// the returned array.
pub fn PdfTextExtractor::codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[Int] raise PdfError {
  match self.font.pdf_text_tounicode() {
    Some(tounicode) =>
      self.pdf_text_tounicode_codepoints_of_text(tounicode, text)
    None =>
      match self.font {
        PdfFontCIDKeyed(font) =>
          match font.encoding {
            PdfExternalCMap(_, parsed) =>
              self.pdf_text_external_cmap_codepoints_of_text(font, parsed, text)
            _ => self.pdf_text_regular_codepoints_of_text(text)
          }
        _ => self.pdf_text_regular_codepoints_of_text(text)
      }
  }
}

///|
/// Resolve only glyph names from PDF text bytes.
///
/// This bypasses Unicode conversion and is useful for callers that need the
/// encoded glyph identity rather than extracted text.
pub fn PdfTextExtractor::glyphnames_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfName] raise PdfError {
  [
    for code in self.font.pdf_text_charcodes_of_text(text) => {
      self.pdf_text_glyph_of_charcode(code).glyphname
    }
  ]
}

///|
/// Compatibility wrapper for `PdfTextExtractor::codepoints_of_text`.
pub fn pdf_codepoints_of_text(
  extractor : PdfTextExtractor,
  text : BytesView,
) -> Array[Int] raise PdfError {
  extractor.codepoints_of_text(text)
}

///|
/// Compatibility wrapper for `PdfTextExtractor::glyphnames_of_text`.
pub fn pdf_glyphnames_of_text(
  extractor : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfName] raise PdfError {
  extractor.glyphnames_of_text(text)
}

///|
/// Return a PDF character code that can encode one Unicode codepoint.
///
/// The lookup prefers explicit ToUnicode reverse mappings, then predefined or
/// external CMap reverse lookup, then simple-font glyph names. `None` means
/// the current font has no known single-codepoint representation.
pub fn PdfTextExtractor::charcode_of_codepoint(
  self : PdfTextExtractor,
  codepoint : Int,
) -> Int? {
  match self.font.pdf_text_tounicode() {
    Some(tounicode) =>
      for entry in tounicode {
        try pdf_codepoints_of_utf16be(entry.1) catch {
          _ => ()
        } noraise {
          [single] if single == codepoint => break Some(entry.0)
          _ => ()
        }
      } nobreak {
        None
      }
    None =>
      match self.font.pdf_text_predefined_builtin_charcode(codepoint) {
        Some(code) => Some(code)
        None =>
          match self.font.pdf_text_external_cmap_charcode(codepoint) {
            Some(code) => Some(code)
            None =>
              for code in 0..<256 {
                match self.font.pdf_text_glyphname_of_charcode(code) {
                  Some(glyphname) =>
                    if self.font.pdf_text_glyphname_has_single_codepoint(
                        glyphname, codepoint,
                      ) {
                      break Some(code)
                    }
                  _ => ()
                }
              } nobreak {
                self.font.pdf_text_macexpert_duplicate_charcode(codepoint)
              }
          }
      }
  }
}

///|
/// Read a font dictionary and build a pure Unicode-to-charcode closure.
///
/// `debug` is accepted for CamlPDF API compatibility; this implementation
/// preserves pure lookup behavior and does not write missing-glyph diagnostics.
pub fn pdf_charcode_extractor_of_font(
  document : PdfDocument,
  font : PdfObject,
  debug? : Bool = false,
) -> ((Int) -> Int?) raise PdfError {
  pdf_charcode_extractor_of_font_real(document.read_font(font), debug~)
}

///|
/// Write a custom encoding dictionary and return its object number.
///
/// Currently this supports `/Differences` over an implicit base encoding, which
/// is the form needed by the font writer. Unsupported encodings raise
/// `PdfError::EncodingWriteUnsupported`.
pub fn PdfDocument::write_encoding(
  self : PdfDocument,
  encoding : PdfEncoding,
) -> Int raise PdfError {
  match encoding {
    PdfCustomEncoding(PdfImplicitInFontFile, differences) => {
      let values : Array[PdfObject] = Array::new(
        capacity=differences.length() * 2,
      )
      for difference in differences {
        values.push(PdfInteger(difference.code))
        values.push(PdfNameObject(difference.name))
      }
      self.add_object(
        PdfDictionary([
          (pdf_text_type_key_name, PdfNameObject(pdf_text_encoding_key_name)),
          (pdf_text_differences_key_name, PdfArray(values)),
        ]),
      )
    }
    _ => raise EncodingWriteUnsupported
  }
}

///|
/// Build a simple Type 1 font dictionary for a base font and named encoding.
///
/// Only encodings with a direct PDF name can be written this way; custom or
/// implicit encodings raise `PdfError::EncodingWriteUnsupported`.
pub fn pdf_make_font(
  fontname : PdfName,
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  match encoding.pdf_name() {
    Some(encoding_name) =>
      PdfDictionary([
        (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
        (pdf_text_subtype_key_name, PdfNameObject(pdf_text_type1_name)),
        (pdf_text_encoding_key_name, PdfNameObject(encoding_name)),
        (pdf_text_base_font_key_name, PdfNameObject(fontname)),
      ])
    None => raise EncodingWriteUnsupported
  }
}

///|
fn pdf_text_rectangle_object(rectangle : PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_text_type3_charprocs_object(
  charprocs : ArrayView[(PdfName, PdfObject)],
) -> PdfObject {
  PdfDictionary([ for entry in charprocs => entry ])
}

///|
fn pdf_text_type3_resources_entries(
  resources : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  match resources {
    PdfDictionary(entries) if entries.length() == 0 => []
    _ => [(pdf_text_resources_key_name, resources)]
  }
}

///|
fn pdf_text_type3_metrics_entries(
  firstchar : Int,
  lastchar : Int,
  widths : ArrayView[Int],
) -> Array[(PdfName, PdfObject)] {
  if widths.length() == 0 {
    [
      (pdf_text_first_char_key_name, PdfInteger(0)),
      (pdf_text_last_char_key_name, PdfInteger(0)),
      (pdf_text_widths_key_name, PdfArray([PdfReal(0.0)])),
    ]
  } else {
    [
      (pdf_text_first_char_key_name, PdfInteger(firstchar)),
      (pdf_text_last_char_key_name, PdfInteger(lastchar)),
      (
        pdf_text_widths_key_name,
        PdfArray([ for width in widths => PdfInteger(width) ]),
      ),
    ]
  }
}

///|
fn PdfDocument::pdf_text_type3_encoding_entries(
  self : PdfDocument,
  encoding : PdfEncoding,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match encoding {
    PdfImplicitInFontFile => []
    _ =>
      [(pdf_text_encoding_key_name, PdfIndirect(self.write_encoding(encoding)))]
  }
}

///|
fn PdfDocument::pdf_text_make_type3_font(
  self : PdfDocument,
  data : PdfType3Glyphs,
  firstchar : Int,
  lastchar : Int,
  widths : ArrayView[Int],
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  PdfDictionary(
    [
      (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
      (pdf_text_subtype_key_name, PdfNameObject(pdf_text_type3_name)),
      (pdf_text_font_bbox_key_name, pdf_text_rectangle_object(data.fontbbox)),
      (pdf_text_font_matrix_key_name, pdf_object_of_matrix(data.fontmatrix)),
      (
        pdf_text_charprocs_key_name,
        pdf_text_type3_charprocs_object(data.charprocs),
      ),
      ..pdf_text_type3_resources_entries(data.resources),
      ..pdf_text_type3_metrics_entries(firstchar, lastchar, widths),
      ..self.pdf_text_type3_encoding_entries(encoding),
    ],
  )
}

///|
fn pdf_text_integer_of_double(value : Double) -> PdfObject {
  PdfInteger(value.to_int())
}

///|
fn pdf_text_font_descriptor_bbox_object(fontbbox : PdfRectangle) -> PdfObject {
  PdfArray([
    pdf_text_integer_of_double(fontbbox.min_x),
    pdf_text_integer_of_double(fontbbox.min_y),
    pdf_text_integer_of_double(fontbbox.max_x),
    pdf_text_integer_of_double(fontbbox.max_y),
  ])
}

///|
fn pdf_text_fontfile2_number(fontfile : PdfFontFile?) -> Int? {
  match fontfile {
    Some(PdfFontFile2(number)) => Some(number)
    _ => None
  }
}

///|
fn pdf_text_true_type_encoding_name(encoding : PdfEncoding) -> PdfName? {
  match encoding {
    PdfFillUndefinedWithStandard(base) => base.pdf_name()
    _ => encoding.pdf_name()
  }
}

///|
fn pdf_text_tounicode_preamble() -> String {
  "/CIDInit /ProcSet findresource begin\n" +
  "12 dict begin\n" +
  "begincmap\n" +
  "/CIDSystemInfo <<\n" +
  "  /Registry (Adobe)\n" +
  "  /Ordering (UCS)\n" +
  "  /Supplement 0\n" +
  ">> def\n" +
  "/CMapName /Adobe-Identity-UCS def\n" +
  "/CMapType 2 def\n" +
  "1 begincodespacerange\n" +
  "<00><FF>\n" +
  "endcodespacerange\n"
}

///|
fn pdf_text_tounicode_postamble() -> String {
  "endbfrange\n" +
  "endcmap\n" +
  "CMapName currentdict /CMap defineresource pop\n" +
  "end\n" +
  "end\n"
}

///|
fn pdf_text_tounicode_sorted(
  entries : ArrayView[(Int, PdfBytes)],
) -> Array[(Int, PdfBytes)] {
  let sorted = [ for entry in entries => entry ]
  sorted.sort_by(fn(left, right) { left.0.compare(right.0) })
  sorted
}

///|
fn pdf_text_hex_int_min2(value : Int) -> String {
  let text = value.to_string(radix=16)
  if text.length() == 1 {
    "0" + text
  } else {
    text
  }
}

///|
fn pdf_text_ascii_length(text : String) -> Int {
  @ascii.encode(text).length()
}

///|
fn pdf_text_write_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut current = position
  for byte in @ascii.encode(text) {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_text_hex_bytes_length(bytes : BytesView) -> Int {
  bytes.length() * 2
}

///|
fn pdf_text_write_hex_bytes(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut current = position
  for byte in bytes {
    let value = byte.to_int()
    output[current] = pdf_writer_hex_digit(value / 16)
    output[current + 1] = pdf_writer_hex_digit(value % 16)
    current += 2
  }
  current
}

///|
fn pdf_text_tounicode_bfrange_length(
  charcode_text : String,
  bytes : BytesView,
) -> Int {
  pdf_text_ascii_length("<") +
  pdf_text_ascii_length(charcode_text) +
  pdf_text_ascii_length("><") +
  pdf_text_ascii_length(charcode_text) +
  pdf_text_ascii_length("><") +
  pdf_text_hex_bytes_length(bytes) +
  pdf_text_ascii_length(">\n")
}

///|
fn pdf_text_write_tounicode_bfrange(
  output : Array[Byte],
  position : Int,
  charcode_text : String,
  bytes : BytesView,
) -> Int {
  let mut current = pdf_text_write_ascii(output, position, "<")
  current = pdf_text_write_ascii(output, current, charcode_text)
  current = pdf_text_write_ascii(output, current, "><")
  current = pdf_text_write_ascii(output, current, charcode_text)
  current = pdf_text_write_ascii(output, current, "><")
  current = pdf_text_write_hex_bytes(output, current, bytes)
  pdf_text_write_ascii(output, current, ">\n")
}

///|
fn pdf_text_tounicode_bytes(sorted : ArrayView[(Int, PdfBytes)]) -> PdfBytes {
  let count_text = sorted.length().to_string()
  let mut length = pdf_text_ascii_length(pdf_text_tounicode_preamble()) +
    pdf_text_ascii_length(count_text) +
    pdf_text_ascii_length(" beginbfrange\n") +
    pdf_text_ascii_length(pdf_text_tounicode_postamble())
  let mut charcode = 33
  let charcode_texts : Array[String] = Array::new(capacity=sorted.length())
  for entry in sorted {
    let charcode_text = pdf_text_hex_int_min2(charcode)
    length += pdf_text_tounicode_bfrange_length(charcode_text, entry.1)
    charcode_texts.push(charcode_text)
    charcode += 1
  }
  let output = Array::make(length, b'\x00')
  let mut position = pdf_text_write_ascii(
    output,
    0,
    pdf_text_tounicode_preamble(),
  )
  position = pdf_text_write_ascii(output, position, count_text)
  position = pdf_text_write_ascii(output, position, " beginbfrange\n")
  for index, entry in sorted {
    position = pdf_text_write_tounicode_bfrange(
      output,
      position,
      charcode_texts[index],
      entry.1,
    )
  }
  let _ = pdf_text_write_ascii(output, position, pdf_text_tounicode_postamble())
  Bytes::from_array(output)
}

///|
fn PdfDocument::pdf_text_write_tounicode(
  self : PdfDocument,
  entries : ArrayView[(Int, PdfBytes)],
) -> Int {
  let sorted = pdf_text_tounicode_sorted(entries)
  let bytes = pdf_text_tounicode_bytes(sorted)
  self.add_object(
    pdf_stream(
      PdfDictionary([(pdf_text_length_key_name, PdfInteger(bytes.length()))]),
      StreamGot(bytes),
    ),
  )
}

///|
fn PdfDocument::pdf_text_make_true_type_font(
  self : PdfDocument,
  basefont : PdfName,
  firstchar : Int,
  lastchar : Int,
  widths : Array[Int],
  descriptor : PdfFontDescriptor,
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  let ttf = match pdf_text_fontfile2_number(descriptor.fontfile) {
    Some(number) => number
    None => raise FontWriteUnsupported
  }
  let fontdescriptor = PdfDictionary([
    (pdf_text_type_key_name, PdfNameObject(pdf_text_font_descriptor_key_name)),
    (pdf_text_font_name_key_name, PdfNameObject(basefont)),
    (pdf_text_flags_key_name, PdfInteger(descriptor.flags)),
    (
      pdf_text_font_bbox_key_name,
      pdf_text_font_descriptor_bbox_object(descriptor.fontbbox),
    ),
    (
      pdf_text_italic_angle_key_name,
      pdf_text_integer_of_double(descriptor.italicangle),
    ),
    (pdf_text_ascent_key_name, pdf_text_integer_of_double(descriptor.ascent)),
    (pdf_text_descent_key_name, pdf_text_integer_of_double(descriptor.descent)),
    (
      pdf_text_cap_height_key_name,
      pdf_text_integer_of_double(descriptor.capheight),
    ),
    (pdf_text_stemv_key_name, pdf_text_integer_of_double(descriptor.stemv)),
    (pdf_text_xheight_key_name, pdf_text_integer_of_double(descriptor.xheight)),
    (
      pdf_text_avg_width_key_name,
      pdf_text_integer_of_double(descriptor.avgwidth),
    ),
    (
      pdf_text_max_width_key_name,
      pdf_text_integer_of_double(descriptor.maxwidth),
    ),
    (pdf_text_font_file2_key_name, PdfIndirect(ttf)),
  ])
  let fontdescriptor_number = self.add_object(fontdescriptor)
  let tounicode_entry = match descriptor.tounicode {
    Some(tounicode) =>
      [
        (
          pdf_text_tounicode_key_name,
          PdfIndirect(self.pdf_text_write_tounicode(tounicode)),
        ),
      ]
    None => {
      let encoding_name = match pdf_text_true_type_encoding_name(encoding) {
        Some(name) => name
        None => raise EncodingWriteUnsupported
      }
      [(pdf_text_encoding_key_name, PdfNameObject(encoding_name))]
    }
  }
  PdfDictionary(
    [
      (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
      (pdf_text_subtype_key_name, PdfNameObject(pdf_text_true_type_name_value)),
      (pdf_text_base_font_key_name, PdfNameObject(basefont)),
      (pdf_text_font_descriptor_key_name, PdfIndirect(fontdescriptor_number)),
      (pdf_text_first_char_key_name, PdfInteger(firstchar)),
      (pdf_text_last_char_key_name, PdfInteger(lastchar)),
      (
        pdf_text_widths_key_name,
        PdfArray([ for width in widths => PdfInteger(width) ]),
      ),
      ..tounicode_entry,
    ],
  )
}

///|
fn PdfDocument::pdf_text_add_font_object(
  self : PdfDocument,
  object : PdfObject,
  objnum : Int?,
) -> Int {
  match objnum {
    Some(number) => {
      self.add_object_given_number(number, object)
      number
    }
    None => self.add_object(object)
  }
}

///|
/// Write a parsed font into the document and return its object number.
///
/// Standard fonts, Type 3 fonts with descriptors, and TrueType fonts with
/// descriptors are supported. `objnum` can force the destination object number
/// for rewrite workflows. Unsupported font shapes raise `PdfError::FontWriteUnsupported`.
pub fn PdfDocument::write_font(
  self : PdfDocument,
  font : PdfFont,
  objnum? : Int? = None,
) -> Int raise PdfError {
  match font {
    PdfFontStandard({ font, encoding }) =>
      self.pdf_text_add_font_object(
        pdf_make_font(font.pdf_name(), encoding),
        objnum,
      )
    PdfFontSimple(
      {
        fonttype: PdfType3(data),
        firstchar,
        lastchar,
        widths,
        encoding,
        fontdescriptor,
        ..,
      }
    ) =>
      match fontdescriptor {
        Some(_) =>
          self.pdf_text_add_font_object(
            self.pdf_text_make_type3_font(
              data, firstchar, lastchar, widths, encoding,
            ),
            objnum,
          )
        None => raise FontWriteUnsupported
      }
    PdfFontSimple(
      {
        fonttype: PdfTrueType,
        basefont: Some(basefont),
        firstchar,
        lastchar,
        widths,
        fontdescriptor: Some(descriptor),
        encoding,
        ..,
      }
    ) =>
      self.pdf_text_add_font_object(
        self.pdf_text_make_true_type_font(
          basefont, firstchar, lastchar, widths, descriptor, encoding,
        ),
        objnum,
      )
    _ => raise FontWriteUnsupported
  }
}

///|
/// Compatibility wrapper for `PdfDocument::write_font`.
pub fn pdf_write_font(
  document : PdfDocument,
  font : PdfFont,
  objnum? : Int? = None,
) -> Int raise PdfError {
  document.write_font(font, objnum~)
}

///|
/// Test whether a PDF string starts with the UTF-16BE byte-order mark.
///
/// PDF "Unicode strings" are byte strings beginning with `FE FF`; the input is
/// intentionally a `BytesView` rather than a MoonBit `String`.
pub fn pdf_is_unicode_string(bytes : BytesView) -> Bool {
  bytes.length() >= 2 && bytes[0].to_int() == 0xFE && bytes[1].to_int() == 0xFF
}

///|
fn pdf_text_write_utf16be_unit(
  output : Array[Byte],
  position : Int,
  value : Int,
) -> Int raise PdfError {
  output[position] = pdf_byte_of_int((value >> 8) & 0xFF)
  output[position + 1] = pdf_byte_of_int(value & 0xFF)
  position + 2
}

///|
fn pdf_text_utf16be_codepoint_length(codepoint : Int) -> Int raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  if codepoint < 0x10000 {
    2
  } else {
    4
  }
}

///|
fn pdf_text_write_utf16be_codepoint(
  output : Array[Byte],
  position : Int,
  codepoint : Int,
) -> Int raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  if codepoint < 0x10000 {
    pdf_text_write_utf16be_unit(output, position, codepoint)
  } else {
    let shifted = codepoint - 0x10000
    let current = pdf_text_write_utf16be_unit(
      output,
      position,
      0xD800 | (shifted >> 10),
    )
    pdf_text_write_utf16be_unit(output, current, 0xDC00 | (shifted & 0x3FF))
  }
}

///|
/// Encode Unicode scalar values as a PDF UTF-16BE string with BOM.
///
/// Invalid scalar values, including surrogate codepoints, raise
/// `PdfError::InvalidUnicodeCodepoint`.
pub fn pdf_utf16be_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let mut length = 2
  for codepoint in codepoints {
    length += pdf_text_utf16be_codepoint_length(codepoint)
  }
  let output = Array::make(length, b'\x00')
  output[0] = pdf_byte_of_int(0xFE)
  output[1] = pdf_byte_of_int(0xFF)
  let mut position = 2
  for codepoint in codepoints {
    position = pdf_text_write_utf16be_codepoint(output, position, codepoint)
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_utf16be_unit(bytes : BytesView, index : Int) -> Int raise PdfError {
  guard index + 1 < bytes.length() else { raise InvalidUTF16BE }
  (bytes[index].to_int() << 8) | bytes[index + 1].to_int()
}

///|
/// Decode UTF-16BE bytes into Unicode scalar values.
///
/// The input should not include the leading `FE FF` BOM; callers that receive a
/// PDF Unicode string normally pass `bytes[2:]`. Odd lengths, lone surrogates,
/// and malformed pairs raise `PdfError::InvalidUTF16BE`.
pub fn pdf_codepoints_of_utf16be(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  let codepoints : Array[Int] = Array::new(capacity=bytes.length() / 2)
  let mut index = 0
  while index < bytes.length() {
    let w1 = pdf_text_utf16be_unit(bytes, index)
    index += 2
    if w1 >= 0xD800 && w1 <= 0xDBFF {
      let w2 = pdf_text_utf16be_unit(bytes, index)
      guard w2 >= 0xDC00 && w2 <= 0xDFFF else { raise InvalidUTF16BE }
      index += 2
      codepoints.push((((w1 & 0x3FF) << 10) | (w2 & 0x3FF)) + 0x10000)
    } else if w1 >= 0xDC00 && w1 <= 0xDFFF {
      raise InvalidUTF16BE
    } else {
      codepoints.push(w1)
    }
  }
  codepoints
}

///|
fn pdf_text_check_unicode_codepoint(codepoint : Int) -> Unit raise PdfError {
  if codepoint < 0 ||
    codepoint > 0x10FFFF ||
    (codepoint >= 0xD800 && codepoint <= 0xDFFF) {
    raise InvalidUnicodeCodepoint(codepoint)
  }
}

///|
fn pdf_text_utf8_codepoint_length(codepoint : Int) -> Int raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  if codepoint <= 0x7F {
    1
  } else if codepoint <= 0x7FF {
    2
  } else if codepoint <= 0xFFFF {
    3
  } else {
    4
  }
}

///|
fn pdf_text_write_utf8_codepoint(
  output : Array[Byte],
  position : Int,
  codepoint : Int,
) -> Int raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  if codepoint <= 0x7F {
    output[position] = pdf_byte_of_int(codepoint)
    position + 1
  } else if codepoint <= 0x7FF {
    output[position] = pdf_byte_of_int((codepoint >> 6) | 0xC0)
    output[position + 1] = pdf_byte_of_int((codepoint & 0x3F) | 0x80)
    position + 2
  } else if codepoint <= 0xFFFF {
    output[position] = pdf_byte_of_int((codepoint >> 12) | 0xE0)
    output[position + 1] = pdf_byte_of_int(((codepoint >> 6) & 0x3F) | 0x80)
    output[position + 2] = pdf_byte_of_int((codepoint & 0x3F) | 0x80)
    position + 3
  } else {
    output[position] = pdf_byte_of_int((codepoint >> 18) | 0xF0)
    output[position + 1] = pdf_byte_of_int(((codepoint >> 12) & 0x3F) | 0x80)
    output[position + 2] = pdf_byte_of_int(((codepoint >> 6) & 0x3F) | 0x80)
    output[position + 3] = pdf_byte_of_int((codepoint & 0x3F) | 0x80)
    position + 4
  }
}

///|
/// Encode Unicode scalar values as UTF-8 bytes.
///
/// Invalid scalar values, including surrogate codepoints, raise
/// `PdfError::InvalidUnicodeCodepoint`.
pub fn pdf_utf8_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let mut length = 0
  for codepoint in codepoints {
    length += pdf_text_utf8_codepoint_length(codepoint)
  }
  let output = Array::make(length, b'\x00')
  let mut position = 0
  for codepoint in codepoints {
    position = pdf_text_write_utf8_codepoint(output, position, codepoint)
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_is_utf8_continuation(byte : Int) -> Bool {
  byte >> 6 == 0b10
}

///|
fn pdf_text_push_utf8_codepoint(
  output : Array[Int],
  codepoint : Int,
  min_codepoint : Int,
) -> Unit raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  guard codepoint >= min_codepoint else { raise InvalidUTF8 }
  output.push(codepoint)
}

///|
/// Decode UTF-8 bytes into Unicode scalar values.
///
/// Overlong encodings, invalid continuation bytes, truncated sequences, and
/// surrogate or out-of-range scalar values raise `PdfError::InvalidUTF8` or
/// `PdfError::InvalidUnicodeCodepoint`.
pub fn pdf_codepoints_of_utf8(bytes : BytesView) -> Array[Int] raise PdfError {
  let output : Array[Int] = Array::new(capacity=bytes.length())
  let mut index = 0
  while index < bytes.length() {
    let first = bytes[index].to_int()
    if first >> 7 == 0 {
      output.push(first)
      index += 1
    } else if first >> 5 == 0b110 {
      guard index + 1 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      guard pdf_text_is_utf8_continuation(b1) else { raise InvalidUTF8 }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x1F) << 6) | (b1 & 0x3F),
        0x80,
      )
      index += 2
    } else if first >> 4 == 0b1110 {
      guard index + 2 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      let b2 = bytes[index + 2].to_int()
      guard pdf_text_is_utf8_continuation(b1) &&
        pdf_text_is_utf8_continuation(b2) else {
        raise InvalidUTF8
      }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F),
        0x800,
      )
      index += 3
    } else if first >> 3 == 0b11110 {
      guard index + 3 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      let b2 = bytes[index + 2].to_int()
      let b3 = bytes[index + 3].to_int()
      guard pdf_text_is_utf8_continuation(b1) &&
        pdf_text_is_utf8_continuation(b2) &&
        pdf_text_is_utf8_continuation(b3) else {
        raise InvalidUTF8
      }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F),
        0x10000,
      )
      index += 4
    } else {
      raise InvalidUTF8
    }
  }
  output
}

///|
fn pdf_codepoint_of_pdfdocencoding_byte_option(value : Int) -> Int? {
  match value {
    0x09 => Some(0x0009)
    0x0A => Some(0x000A)
    0x0C => Some(0x000C)
    0x0D => Some(0x000D)
    0x18 => Some(0x02D8)
    0x19 => Some(0x02C7)
    0x1A => Some(0x02C6)
    0x1B => Some(0x02D9)
    0x1C => Some(0x02DD)
    0x1D => Some(0x02DB)
    0x1E => Some(0x02DA)
    0x1F => Some(0x02DC)
    0x20..=0x7E => Some(value)
    0x80 => Some(0x2022)
    0x81 => Some(0x2020)
    0x82 => Some(0x2021)
    0x83 => Some(0x2026)
    0x84 => Some(0x2014)
    0x85 => Some(0x2013)
    0x86 => Some(0x0192)
    0x87 => Some(0x2044)
    0x88 => Some(0x2039)
    0x89 => Some(0x203A)
    0x8A => Some(0x2212)
    0x8B => Some(0x2030)
    0x8C => Some(0x201E)
    0x8D => Some(0x201C)
    0x8E => Some(0x201D)
    0x8F => Some(0x2018)
    0x90 => Some(0x2019)
    0x91 => Some(0x201A)
    0x92 => Some(0x2122)
    0x93 => Some(0xFB02)
    0x95 => Some(0x0141)
    0x96 => Some(0x0152)
    0x97 => Some(0x0160)
    0x98 => Some(0x0178)
    0x99 => Some(0x017D)
    0x9A => Some(0x0131)
    0x9B => Some(0x0142)
    0x9C => Some(0x0153)
    0x9D => Some(0x0161)
    0x9E => Some(0x017E)
    0xA0 => Some(0x20AC)
    0xA1..=0xAC => Some(value)
    0xAE..=0xFF => Some(value)
    _ => None
  }
}

///|
/// Decode one PDFDocEncoding byte to a Unicode codepoint.
///
/// Undefined byte values raise `PdfError::InvalidPDFDocEncoding`.
pub fn pdf_codepoint_of_pdfdocencoding_byte(value : Int) -> Int raise PdfError {
  match pdf_codepoint_of_pdfdocencoding_byte_option(value) {
    Some(codepoint) => codepoint
    None => raise InvalidPDFDocEncoding(value)
  }
}

///|
/// Decode a PDFDocEncoding byte string to Unicode codepoints.
pub fn pdf_codepoints_of_pdfdocencoding(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  let codepoints : Array[Int] = Array::new(capacity=bytes.length())
  for byte in bytes {
    codepoints.push(pdf_codepoint_of_pdfdocencoding_byte(byte.to_int()))
  }
  codepoints
}

///|
/// Return the PDFDocEncoding byte for a Unicode codepoint, if representable.
///
/// The lookup preserves CamlPDF compatibility for the `fi` ligature by mapping
/// U+FB01 to byte `0x93`.
pub fn pdf_pdfdocencoding_byte_of_codepoint(codepoint : Int) -> Byte? {
  if codepoint == 0xFB01 {
    Some(0x93)
  } else {
    for value in 0..<=255 {
      match pdf_codepoint_of_pdfdocencoding_byte_option(value) {
        Some(decoded) if decoded == codepoint => break Some(value.to_byte())
        _ => ()
      }
    } nobreak {
      None
    }
  }
}

///|
/// Encode codepoints as PDFDocEncoding when every scalar is representable.
///
/// Returns `None` instead of falling back to UTF-16BE; use
/// `pdf_pdfdocstring_of_codepoints` for the PDF string policy fallback.
pub fn pdf_pdfdocencoding_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes? {
  let output = Array::make(codepoints.length(), b'\x00')
  for index in 0..<codepoints.length() {
    match pdf_pdfdocencoding_byte_of_codepoint(codepoints[index]) {
      Some(byte) => output[index] = byte
      None => return None
    }
  }
  Some(Bytes::from_array(output))
}

///|
/// Encode codepoints as a PDF string.
///
/// PDFDocEncoding is used when all codepoints are representable; otherwise the
/// result is a BOM-prefixed UTF-16BE string.
pub fn pdf_pdfdocstring_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  match pdf_pdfdocencoding_of_codepoints(codepoints) {
    Some(encoded) => encoded
    None => pdf_utf16be_of_codepoints(codepoints)
  }
}

///|
/// Decode a PDF string to Unicode codepoints.
///
/// BOM-prefixed strings are treated as UTF-16BE. Other byte strings are
/// decoded as PDFDocEncoding.
pub fn pdf_codepoints_of_pdfdocstring(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  if pdf_is_unicode_string(bytes) {
    pdf_codepoints_of_utf16be(bytes[2:])
  } else {
    pdf_codepoints_of_pdfdocencoding(bytes)
  }
}

///|
/// Convert a PDF string byte sequence to UTF-8 bytes.
pub fn pdf_utf8_of_pdfdocstring(bytes : BytesView) -> PdfBytes raise PdfError {
  pdf_utf8_of_codepoints(pdf_codepoints_of_pdfdocstring(bytes))
}

///|
/// Convert UTF-8 bytes to the compact PDF string representation.
///
/// The result uses PDFDocEncoding when possible and UTF-16BE otherwise.
pub fn pdf_pdfdocstring_of_utf8(bytes : BytesView) -> PdfBytes raise PdfError {
  pdf_pdfdocstring_of_codepoints(pdf_codepoints_of_utf8(bytes))
}

///|
/// Re-encode a UTF-16BE PDF string using PDFDocEncoding when possible.
///
/// Non-Unicode input is returned as an owned copy. Malformed UTF-16BE raises
/// `PdfError::InvalidUTF16BE`.
pub fn pdf_simplify_utf16be(bytes : BytesView) -> PdfBytes raise PdfError {
  if pdf_is_unicode_string(bytes) {
    pdf_pdfdocstring_of_codepoints(pdf_codepoints_of_pdfdocstring(bytes))
  } else {
    bytes.to_owned()
  }
}

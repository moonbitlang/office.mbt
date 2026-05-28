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

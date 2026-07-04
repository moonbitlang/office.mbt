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

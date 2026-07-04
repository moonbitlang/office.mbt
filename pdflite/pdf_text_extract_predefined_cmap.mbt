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

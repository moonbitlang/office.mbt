///|
fn pdf_text_codepoint_of_agl_base_glyphname(base_name : PdfName) -> Int? {
  match pdf_text_codepoint_of_basic_latin_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_digit_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_punctuation_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_ipa_extension_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_spacing_modifier_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_combining_mark_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_currency_letterlike_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_arrow_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_greek_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_cyrillic_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_armenian_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_hebrew_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_arabic_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_devanagari_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_bengali_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_gurmukhi_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_gujarati_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_thai_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_math_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_number_form_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_technical_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_enclosed_alnum_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_cjk_symbol_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_hiragana_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_katakana_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_bopomofo_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_hangul_compat_jamo_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_enclosed_cjk_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_cjk_compat_square_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_presentation_form_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_box_drawing_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_block_element_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_geometric_shape_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_misc_symbol_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_latin_extended_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_latin_ext_additional_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_private_use_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_expert_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_symbol_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_half_fullwidth_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  pdf_text_codepoint_of_dingbat_glyphname(base_name)
}

///|
fn pdf_text_codepoints_of_glyphname(name : PdfName) -> Array[Int]? {
  let base = pdf_text_glyphname_base_bytes(name)
  match pdf_text_uni_glyphname_codepoints(base) {
    Some(codepoints) => Some(codepoints)
    None =>
      match pdf_text_u_glyphname_codepoints(base) {
        Some(codepoints) => Some(codepoints)
        None =>
          match pdf_text_truetype_glyphname_codepoints(base) {
            Some(codepoints) => Some(codepoints)
            None =>
              if base.length() == 2 && base[0].to_int() == 47 {
                let value = base[1].to_int()
                if (value >= 65 && value <= 90) || (value >= 97 && value <= 122) {
                  Some([value])
                } else {
                  None
                }
              } else {
                let base_name = pdf_text_glyphname_base_name(name, base)
                match pdf_text_codepoints_of_agl_sequence_glyphname(base_name) {
                  Some(codepoints) => Some(codepoints)
                  None =>
                    match pdf_text_codepoint_of_agl_base_glyphname(base_name) {
                      Some(codepoint) => Some([codepoint])
                      None => None
                    }
                }
              }
          }
      }
  }
}

///|
fn pdf_text_codepoint_of_agl_symbol_conflict_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Delta" => Some(0x2206)
    "/Omega" => Some(0x2126)
    "/mu" => Some(0x00B5)
    _ => None
  }
}

///|
fn PdfFont::pdf_text_uses_symbol_codepoints(self : PdfFont) -> Bool {
  match self {
    PdfFontStandard(data) =>
      data.font == PdfSymbol && data.encoding == PdfImplicitInFontFile
    _ => false
  }
}

///|
fn PdfFont::pdf_text_codepoints_of_glyphname(
  self : PdfFont,
  glyphname : PdfName,
) -> Array[Int]? {
  if self.pdf_text_uses_symbol_codepoints() {
    pdf_text_codepoints_of_glyphname(glyphname)
  } else {
    match pdf_text_codepoint_of_agl_symbol_conflict_glyphname(glyphname) {
      Some(codepoint) => Some([codepoint])
      None => pdf_text_codepoints_of_glyphname(glyphname)
    }
  }
}

///|
fn PdfFont::pdf_text_glyphname_has_single_codepoint(
  self : PdfFont,
  glyphname : PdfName,
  codepoint : Int,
) -> Bool {
  match self.pdf_text_codepoints_of_glyphname(glyphname) {
    Some([single]) if single == codepoint => true
    _ => false
  }
}

///|
fn PdfEncoding::pdf_text_has_macexpert_base(self : PdfEncoding) -> Bool {
  match self {
    PdfMacExpertEncoding => true
    PdfCustomEncoding(base, _) => base.pdf_text_has_macexpert_base()
    PdfFillUndefinedWithStandard(base) => base.pdf_text_has_macexpert_base()
    _ => false
  }
}

///|
fn PdfFont::pdf_text_has_macexpert_base(self : PdfFont) -> Bool {
  match self {
    PdfFontStandard(data) => data.encoding.pdf_text_has_macexpert_base()
    PdfFontSimple(font) => font.encoding.pdf_text_has_macexpert_base()
    PdfFontCIDKeyed(_) => false
  }
}

///|
fn PdfFont::pdf_text_macexpert_duplicate_charcode(
  self : PdfFont,
  codepoint : Int,
) -> Int? {
  if codepoint == 0xF6E6 && self.pdf_text_has_macexpert_base() {
    Some(0x5F)
  } else {
    None
  }
}

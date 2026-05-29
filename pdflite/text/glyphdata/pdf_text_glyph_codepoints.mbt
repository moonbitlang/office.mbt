///|
/// Return the Unicode scalar for an Adobe Glyph List base glyph name.
pub fn pdf_text_codepoint_of_agl_base_glyphname(base_name : String) -> Int? {
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

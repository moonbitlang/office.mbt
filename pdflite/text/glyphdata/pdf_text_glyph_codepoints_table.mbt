///|
/// Dispatch a named generated glyph-codepoint table.
pub fn pdf_text_codepoint_of_glyphname_table(
  table : String,
  name : String,
) -> Int? {
  match table {
    "pdf_text_codepoint_of_arabic_glyphname" =>
      pdf_text_codepoint_of_arabic_glyphname(name)
    "pdf_text_codepoint_of_bengali_glyphname" =>
      pdf_text_codepoint_of_bengali_glyphname(name)
    "pdf_text_codepoint_of_cjk_compat_square_glyphname" =>
      pdf_text_codepoint_of_cjk_compat_square_glyphname(name)
    "pdf_text_codepoint_of_cyrillic_glyphname" =>
      pdf_text_codepoint_of_cyrillic_glyphname(name)
    "pdf_text_codepoint_of_gujarati_glyphname" =>
      pdf_text_codepoint_of_gujarati_glyphname(name)
    "pdf_text_codepoint_of_gurmukhi_glyphname" =>
      pdf_text_codepoint_of_gurmukhi_glyphname(name)
    "pdf_text_codepoint_of_hebrew_glyphname" =>
      pdf_text_codepoint_of_hebrew_glyphname(name)
    "pdf_text_codepoint_of_latin_ext_additional_glyphname" =>
      pdf_text_codepoint_of_latin_ext_additional_glyphname(name)
    "pdf_text_codepoint_of_presentation_form_glyphname" =>
      pdf_text_codepoint_of_presentation_form_glyphname(name)
    "pdf_text_codepoint_of_basic_latin_glyphname" =>
      pdf_text_codepoint_of_basic_latin_glyphname(name)
    "pdf_text_codepoint_of_digit_glyphname" =>
      pdf_text_codepoint_of_digit_glyphname(name)
    "pdf_text_codepoint_of_punctuation_glyphname" =>
      pdf_text_codepoint_of_punctuation_glyphname(name)
    "pdf_text_codepoint_of_ipa_extension_glyphname" =>
      pdf_text_codepoint_of_ipa_extension_glyphname(name)
    "pdf_text_codepoint_of_spacing_modifier_glyphname" =>
      pdf_text_codepoint_of_spacing_modifier_glyphname(name)
    "pdf_text_codepoint_of_combining_mark_glyphname" =>
      pdf_text_codepoint_of_combining_mark_glyphname(name)
    "pdf_text_codepoint_of_currency_letterlike_glyphname" =>
      pdf_text_codepoint_of_currency_letterlike_glyphname(name)
    "pdf_text_codepoint_of_arrow_glyphname" =>
      pdf_text_codepoint_of_arrow_glyphname(name)
    "pdf_text_codepoint_of_greek_glyphname" =>
      pdf_text_codepoint_of_greek_glyphname(name)
    "pdf_text_codepoint_of_cjk_symbol_glyphname" =>
      pdf_text_codepoint_of_cjk_symbol_glyphname(name)
    "pdf_text_codepoint_of_hiragana_glyphname" =>
      pdf_text_codepoint_of_hiragana_glyphname(name)
    "pdf_text_codepoint_of_katakana_glyphname" =>
      pdf_text_codepoint_of_katakana_glyphname(name)
    "pdf_text_codepoint_of_bopomofo_glyphname" =>
      pdf_text_codepoint_of_bopomofo_glyphname(name)
    "pdf_text_codepoint_of_hangul_compat_jamo_glyphname" =>
      pdf_text_codepoint_of_hangul_compat_jamo_glyphname(name)
    "pdf_text_codepoint_of_enclosed_cjk_glyphname" =>
      pdf_text_codepoint_of_enclosed_cjk_glyphname(name)
    "pdf_text_codepoint_of_expert_glyphname" =>
      pdf_text_codepoint_of_expert_glyphname(name)
    "pdf_text_codepoint_of_symbol_glyphname" =>
      pdf_text_codepoint_of_symbol_glyphname(name)
    "pdf_text_codepoint_of_half_fullwidth_glyphname" =>
      pdf_text_codepoint_of_half_fullwidth_glyphname(name)
    "pdf_text_codepoint_of_dingbat_glyphname" =>
      pdf_text_codepoint_of_dingbat_glyphname(name)
    "pdf_text_codepoint_of_latin_extended_glyphname" =>
      pdf_text_codepoint_of_latin_extended_glyphname(name)
    "pdf_text_codepoint_of_armenian_glyphname" =>
      pdf_text_codepoint_of_armenian_glyphname(name)
    "pdf_text_codepoint_of_devanagari_glyphname" =>
      pdf_text_codepoint_of_devanagari_glyphname(name)
    "pdf_text_codepoint_of_thai_glyphname" =>
      pdf_text_codepoint_of_thai_glyphname(name)
    "pdf_text_codepoint_of_box_drawing_glyphname" =>
      pdf_text_codepoint_of_box_drawing_glyphname(name)
    "pdf_text_codepoint_of_block_element_glyphname" =>
      pdf_text_codepoint_of_block_element_glyphname(name)
    "pdf_text_codepoint_of_geometric_shape_glyphname" =>
      pdf_text_codepoint_of_geometric_shape_glyphname(name)
    "pdf_text_codepoint_of_misc_symbol_glyphname" =>
      pdf_text_codepoint_of_misc_symbol_glyphname(name)
    "pdf_text_codepoint_of_private_use_glyphname" =>
      pdf_text_codepoint_of_private_use_glyphname(name)
    "pdf_text_codepoint_of_math_glyphname" =>
      pdf_text_codepoint_of_math_glyphname(name)
    "pdf_text_codepoint_of_number_form_glyphname" =>
      pdf_text_codepoint_of_number_form_glyphname(name)
    "pdf_text_codepoint_of_technical_glyphname" =>
      pdf_text_codepoint_of_technical_glyphname(name)
    "pdf_text_codepoint_of_enclosed_alnum_glyphname" =>
      pdf_text_codepoint_of_enclosed_alnum_glyphname(name)
    _ => None
  }
}

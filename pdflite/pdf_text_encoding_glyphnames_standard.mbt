///|
fn pdf_text_standard_control_glyphname(code : Int) -> PdfName? {
  match code {
    9 => Some(pdf_text_glyph_control_ht_name)
    10 => Some(pdf_text_glyph_control_lf_name)
    12 => Some(pdf_text_glyph_control_ff_name)
    13 => Some(pdf_text_glyph_control_cr_name)
    _ => None
  }
}

///|
fn pdf_text_basic_latin_glyphname(
  code : Int,
  standard_quotes : Bool,
) -> PdfName? {
  pdf_text_cached_basic_latin_glyphname(code, standard_quotes)
}

///|
fn pdf_text_standard_glyphname(code : Int) -> PdfName? {
  match pdf_text_standard_control_glyphname(code) {
    Some(name) => Some(name)
    None =>
      match pdf_text_basic_latin_glyphname(code, true) {
        Some(name) => Some(name)
        None =>
          match code {
            0xA1 => Some(pdf_text_name("/exclamdown"))
            0xA2 => Some(pdf_text_name("/cent"))
            0xA3 => Some(pdf_text_name("/sterling"))
            0xA4 => Some(pdf_text_name("/fraction"))
            0xA5 => Some(pdf_text_name("/yen"))
            0xA6 => Some(pdf_text_name("/florin"))
            0xA7 => Some(pdf_text_name("/section"))
            0xA8 => Some(pdf_text_name("/currency"))
            0xA9 => Some(pdf_text_name("/quotesingle"))
            0xAA => Some(pdf_text_name("/quotedblleft"))
            0xAB => Some(pdf_text_name("/guillemotleft"))
            0xAC => Some(pdf_text_name("/guilsinglleft"))
            0xAD => Some(pdf_text_name("/guilsinglright"))
            0xAE => Some(pdf_text_name("/fi"))
            0xAF => Some(pdf_text_name("/fl"))
            0xB1 => Some(pdf_text_name("/endash"))
            0xB2 => Some(pdf_text_name("/dagger"))
            0xB3 => Some(pdf_text_name("/daggerdbl"))
            0xB4 => Some(pdf_text_name("/periodcentered"))
            0xB6 => Some(pdf_text_name("/paragraph"))
            0xB7 => Some(pdf_text_name("/bullet"))
            0xB8 => Some(pdf_text_name("/quotesinglbase"))
            0xB9 => Some(pdf_text_name("/quotedblbase"))
            0xBA => Some(pdf_text_name("/quotedblright"))
            0xBB => Some(pdf_text_name("/guillemotright"))
            0xBC => Some(pdf_text_name("/ellipsis"))
            0xBD => Some(pdf_text_name("/perthousand"))
            0xBF => Some(pdf_text_name("/questiondown"))
            0xC1 => Some(pdf_text_name("/grave"))
            0xC2 => Some(pdf_text_name("/acute"))
            0xC3 => Some(pdf_text_name("/circumflex"))
            0xC4 => Some(pdf_text_name("/tilde"))
            0xC5 => Some(pdf_text_name("/macron"))
            0xC6 => Some(pdf_text_name("/breve"))
            0xC7 => Some(pdf_text_name("/dotaccent"))
            0xC8 => Some(pdf_text_name("/dieresis"))
            0xCA => Some(pdf_text_name("/ring"))
            0xCB => Some(pdf_text_name("/cedilla"))
            0xCD => Some(pdf_text_name("/hungarumlaut"))
            0xCE => Some(pdf_text_name("/ogonek"))
            0xCF => Some(pdf_text_name("/caron"))
            0xD0 => Some(pdf_text_name("/emdash"))
            0xE1 => Some(pdf_text_name("/AE"))
            0xE3 => Some(pdf_text_name("/ordfeminine"))
            0xE8 => Some(pdf_text_name("/Lslash"))
            0xE9 => Some(pdf_text_name("/Oslash"))
            0xEA => Some(pdf_text_name("/OE"))
            0xEB => Some(pdf_text_name("/ordmasculine"))
            0xF1 => Some(pdf_text_name("/ae"))
            0xF5 => Some(pdf_text_name("/dotlessi"))
            0xF8 => Some(pdf_text_name("/lslash"))
            0xFA => Some(pdf_text_name("/oe"))
            0xFB => Some(pdf_text_name("/germandbls"))
            _ => None
          }
      }
  }
}

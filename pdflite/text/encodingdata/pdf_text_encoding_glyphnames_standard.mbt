///|
fn pdf_text_standard_control_glyphname(code : Int) -> String? {
  match code {
    9 => Some("/controlHT")
    10 => Some("/controlLF")
    12 => Some("/controlFF")
    13 => Some("/controlCR")
    _ => None
  }
}

///|
/// Return the StandardEncoding glyph name for a single-byte character code.
pub fn pdf_text_standard_glyphname(code : Int) -> String? {
  match pdf_text_standard_control_glyphname(code) {
    Some(name) => Some(name)
    None =>
      match pdf_text_basic_latin_glyphname(code, true) {
        Some(name) => Some(name)
        None =>
          match code {
            0xA1 => Some("/exclamdown")
            0xA2 => Some("/cent")
            0xA3 => Some("/sterling")
            0xA4 => Some("/fraction")
            0xA5 => Some("/yen")
            0xA6 => Some("/florin")
            0xA7 => Some("/section")
            0xA8 => Some("/currency")
            0xA9 => Some("/quotesingle")
            0xAA => Some("/quotedblleft")
            0xAB => Some("/guillemotleft")
            0xAC => Some("/guilsinglleft")
            0xAD => Some("/guilsinglright")
            0xAE => Some("/fi")
            0xAF => Some("/fl")
            0xB1 => Some("/endash")
            0xB2 => Some("/dagger")
            0xB3 => Some("/daggerdbl")
            0xB4 => Some("/periodcentered")
            0xB6 => Some("/paragraph")
            0xB7 => Some("/bullet")
            0xB8 => Some("/quotesinglbase")
            0xB9 => Some("/quotedblbase")
            0xBA => Some("/quotedblright")
            0xBB => Some("/guillemotright")
            0xBC => Some("/ellipsis")
            0xBD => Some("/perthousand")
            0xBF => Some("/questiondown")
            0xC1 => Some("/grave")
            0xC2 => Some("/acute")
            0xC3 => Some("/circumflex")
            0xC4 => Some("/tilde")
            0xC5 => Some("/macron")
            0xC6 => Some("/breve")
            0xC7 => Some("/dotaccent")
            0xC8 => Some("/dieresis")
            0xCA => Some("/ring")
            0xCB => Some("/cedilla")
            0xCD => Some("/hungarumlaut")
            0xCE => Some("/ogonek")
            0xCF => Some("/caron")
            0xD0 => Some("/emdash")
            0xE1 => Some("/AE")
            0xE3 => Some("/ordfeminine")
            0xE8 => Some("/Lslash")
            0xE9 => Some("/Oslash")
            0xEA => Some("/OE")
            0xEB => Some("/ordmasculine")
            0xF1 => Some("/ae")
            0xF5 => Some("/dotlessi")
            0xF8 => Some("/lslash")
            0xFA => Some("/oe")
            0xFB => Some("/germandbls")
            _ => None
          }
      }
  }
}

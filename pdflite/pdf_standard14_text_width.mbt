///|
fn pdf_standard14_width_of_code(
  data : PdfAfmData,
  encoding : PdfEncoding,
  code : Int,
) -> Int {
  match encoding {
    PdfImplicitInFontFile =>
      @standard14.pdf_standard14_width_of_charcode(data, code)
    _ => {
      let glyphname = match encoding.pdf_text_glyphname_of_charcode(code) {
        Some(name) => name
        None => pdf_text_glyph_space_name
      }
      @standard14.pdf_standard14_width_of_glyphname(data, glyphname.bytes())
    }
  }
}

///|
/// Computes the width of byte-encoded text in standard-font glyph units.
///
/// When `kern` is true, AFM kerning pairs are included between adjacent
/// character codes.
pub fn pdf_standard14_text_width(
  font : PdfStandardFont,
  encoding : PdfEncoding,
  text : BytesView,
  kern? : Bool = false,
) -> Int {
  let data = font.afm_data()
  let mut width = 0
  for index in 0..<text.length() {
    let code = text[index].to_int()
    width += pdf_standard14_width_of_code(data, encoding, code)
    if kern && index + 1 < text.length() {
      width += @standard14.pdf_standard14_kern(
        data,
        code,
        text[index + 1].to_int(),
      )
    }
  }
  width
}

///|
/// CamlPDF-shaped wrapper for standard-14 text width calculation.
pub fn pdf_standard14_textwidth(
  kern : Bool,
  encoding : PdfEncoding,
  font : PdfStandardFont,
  text : BytesView,
) -> Int {
  pdf_standard14_text_width(font, encoding, text, kern~)
}

///|
/// Computes the width of byte-encoded text for this standard font.
pub fn PdfStandardFont::text_width(
  self : PdfStandardFont,
  encoding : PdfEncoding,
  text : BytesView,
  kern? : Bool = false,
) -> Int {
  pdf_standard14_text_width(self, encoding, text, kern~)
}

///|
/// Computes the width of byte-encoded text using this standard-font data and
/// its encoding.
pub fn PdfStandardFontData::text_width(
  self : PdfStandardFontData,
  text : BytesView,
  kern? : Bool = false,
) -> Int {
  pdf_standard14_text_width(self.font, self.encoding, text, kern~)
}

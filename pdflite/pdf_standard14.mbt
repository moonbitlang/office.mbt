///|
pub fn PdfStandardFont::afm_data(self : PdfStandardFont) -> PdfAfmData {
  pdf_standard14_afm_data_of_font(self)
}

///|
pub fn pdf_standard14_afm_data(font : PdfStandardFont) -> PdfAfmData {
  font.afm_data()
}

///|
pub fn pdf_standard14_baseline_adjustment(font : PdfStandardFont) -> Int {
  font.baseline_adjustment()
}

///|
pub fn pdf_standard14_stemv_of_standard_font(font : PdfStandardFont) -> Int {
  font.stemv()
}

///|
pub fn pdf_standard14_flags_of_standard_font(font : PdfStandardFont) -> Int {
  font.flags()
}

///|
fn pdf_standard14_width_of_charcode(
  widths : ArrayView[(Int, Int)],
  code : Int,
) -> Int {
  for entry in widths {
    let (candidate, width) = entry
    if candidate == code {
      break width
    }
  } nobreak {
    0
  }
}

///|
fn pdf_standard14_glyph_width_name(name : PdfName) -> BytesView {
  let bytes = name.bytes()
  if bytes.length() > 0 && bytes[0].to_int() == 0x2F {
    bytes[1:]
  } else {
    bytes[:]
  }
}

///|
fn pdf_standard14_width_of_glyphname(
  widths : ArrayView[(PdfBytes, Int)],
  name : PdfName,
) -> Int {
  let requested = pdf_standard14_glyph_width_name(name)
  for entry in widths {
    let (candidate, width) = entry
    if pdf_afm_view_equals(candidate[:], requested) {
      break width
    }
  } nobreak {
    0
  }
}

///|
fn pdf_standard14_width_of_code(
  data : PdfAfmData,
  encoding : PdfEncoding,
  code : Int,
) -> Int {
  match encoding {
    PdfImplicitInFontFile =>
      pdf_standard14_width_of_charcode(data.char_metrics, code)
    _ => {
      let glyphname = match encoding.pdf_text_glyphname_of_charcode(code) {
        Some(name) => name
        None => pdf_text_glyph_space_name
      }
      pdf_standard14_width_of_glyphname(data.char_name_widths, glyphname)
    }
  }
}

///|
fn pdf_standard14_kern(
  kerns : ArrayView[(Int, Int, Int)],
  left : Int,
  right : Int,
) -> Int {
  for entry in kerns {
    let (candidate_left, candidate_right, kern) = entry
    if candidate_left == left && candidate_right == right {
      break kern
    }
  } nobreak {
    0
  }
}

///|
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
      width += pdf_standard14_kern(data.kerns, code, text[index + 1].to_int())
    }
  }
  width
}

///|
pub fn pdf_standard14_textwidth(
  kern : Bool,
  encoding : PdfEncoding,
  font : PdfStandardFont,
  text : BytesView,
) -> Int {
  pdf_standard14_text_width(font, encoding, text, kern~)
}

///|
pub fn PdfStandardFont::text_width(
  self : PdfStandardFont,
  encoding : PdfEncoding,
  text : BytesView,
  kern? : Bool = false,
) -> Int {
  pdf_standard14_text_width(self, encoding, text, kern~)
}

///|
pub fn PdfStandardFontData::text_width(
  self : PdfStandardFontData,
  text : BytesView,
  kern? : Bool = false,
) -> Int {
  pdf_standard14_text_width(self.font, self.encoding, text, kern~)
}

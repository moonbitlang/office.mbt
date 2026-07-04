///|
fn pdf_text_width_of_standard_charcode(
  font : PdfStandardFont,
  encoding : PdfEncoding,
  code : Int,
) -> Double {
  if code >= 0 && code <= 255 {
    let bytes : FixedArray[Byte] = [code.to_byte()]
    font.text_width(encoding, Bytes::from_array(bytes)).to_double()
  } else {
    0.0
  }
}

///|
fn pdf_text_simple_font_charcode_width(
  font : PdfSimpleFont,
  code : Int,
) -> Double {
  match font.fontmetrics {
    Some(metrics) =>
      if code >= 0 && code < metrics.length() {
        metrics[code]
      } else {
        0.0
      }
    None =>
      match font.basefont {
        Some(basefont) =>
          match pdf_standard_font_of_pdf_name(basefont) {
            Some(standard_font) =>
              pdf_text_width_of_standard_charcode(
                standard_font,
                font.encoding,
                code,
              )
            None => 0.0
          }
        None => 0.0
      }
  }
}

///|
fn pdf_text_cid_font_charcode_width(
  font : PdfCIDKeyedFont,
  code : Int,
) -> Double {
  for entry in font.composite.cid_widths {
    if entry.0 == code {
      break entry.1
    }
  } nobreak {
    font.composite.cid_default_width
  }
}

///|
/// Measure PDF text bytes in glyph-space units for this extractor's font.
///
/// Text bytes are segmented according to the font encoding. Malformed byte
/// sequences raise `@core.PdfError`, and missing metrics contribute width `0`.
pub fn PdfTextExtractor::text_width(
  self : PdfTextExtractor,
  text : BytesView,
) -> Double raise @core.PdfError {
  match self.font {
    PdfFontStandard(font) => font.text_width(text).to_double()
    PdfFontSimple(font) => {
      let mut width = 0.0
      for code in self.font.pdf_text_charcodes_of_text(text) {
        width += pdf_text_simple_font_charcode_width(font, code)
      }
      width
    }
    PdfFontCIDKeyed(font) => {
      let mut width = 0.0
      for code in self.font.pdf_text_charcodes_of_text(text) {
        width += pdf_text_cid_font_charcode_width(font, code)
      }
      width
    }
  }
}

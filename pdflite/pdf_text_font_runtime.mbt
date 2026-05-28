///|
/// Return a human-readable simple-font subtype label.
///
/// Type 3 labels include the declared CharProc names to make debugging parsed
/// glyph programs easier.
pub fn PdfSimpleFontType::debug_name(self : PdfSimpleFontType) -> String {
  match self {
    PdfType1 => "Type 1"
    PdfMMType1 => "MM Type 1"
    PdfType3(data) => {
      let mut text = "Type 3: charprocs for"
      for entry in data.charprocs {
        let (name, _) = entry
        text = text + pdf_text_string_of_name(name)
      }
      text
    }
    PdfTrueType => "Truetype"
  }
}

///|
/// Return a multi-line debug summary for this simple font.
pub fn PdfSimpleFont::debug_name(self : PdfSimpleFont) -> String {
  let basefont = match self.basefont {
    Some(name) => pdf_text_string_of_name(name)
    None => ""
  }
  "fonttype = " +
  self.fonttype.debug_name() +
  "\nbasefont " +
  basefont +
  "\nencoding is " +
  self.encoding.debug_name() +
  "\n"
}

///|
/// One `/Differences` entry in a simple-font encoding dictionary.
///
/// `code` is the one-byte character code that maps to `name`.
pub(all) struct PdfEncodingDifference {
  name : PdfName
  code : Int
} derive(Debug, Eq, ToJson)

///|
/// Simple-font character encoding.
///
/// `PdfCustomEncoding` layers `/Differences` over a base encoding.
/// `PdfFillUndefinedWithStandard` models TrueType behavior where undefined
/// entries fall back to StandardEncoding.
pub(all) enum PdfEncoding {
  PdfImplicitInFontFile
  PdfStandardEncoding
  PdfMacRomanEncoding
  PdfWinAnsiEncoding
  PdfMacExpertEncoding
  PdfCustomEncoding(PdfEncoding, Array[PdfEncodingDifference])
  PdfFillUndefinedWithStandard(PdfEncoding)
} derive(Debug, Eq, ToJson)

///|
/// Parsed font model used by text extraction and font writing.
pub(all) enum PdfFont {
  PdfFontStandard(PdfStandardFontData)
  PdfFontSimple(PdfSimpleFont)
  PdfFontCIDKeyed(PdfCIDKeyedFont)
} derive(Debug, Eq, ToJson)

///|
/// Text extractor bound to a parsed font.
///
/// The extractor converts PDF text-string bytes to character codes, glyph
/// names, and Unicode codepoints according to the font's encoding data.
pub(all) struct PdfTextExtractor {
  font : PdfFont
} derive(Debug, Eq, ToJson)

///|
/// Extracted glyph result for one character code.
///
/// `glyphname` is the resolved PDF glyph name and `codepoints` is the Unicode
/// scalar sequence inferred from ToUnicode, CMap, or Adobe glyph-list data.
pub(all) struct PdfTextGlyph {
  glyphname : PdfName
  codepoints : Array[Int]
} derive(Debug, Eq, ToJson)

///|
/// Return a human-readable label for a parsed font.
pub fn PdfFont::debug_name(self : PdfFont) -> String {
  match self {
    PdfFontStandard(font) => font.debug_name()
    PdfFontSimple(font) => "SimpleFont " + font.debug_name()
    PdfFontCIDKeyed(font) => font.debug_name()
  }
}

///|
/// Compatibility wrapper for `PdfFont::debug_name`.
pub fn pdf_string_of_font(font : PdfFont) -> String {
  font.debug_name()
}

///|
/// Test whether this font is a Type 0 font using `/Identity-H`.
pub fn PdfFont::is_identity_h(self : PdfFont) -> Bool {
  match self {
    PdfFontCIDKeyed(font) => font.is_identity_h()
    _ => false
  }
}

///|
/// Compatibility wrapper for `PdfFont::is_identity_h`.
pub fn pdf_is_identity_h(font : PdfFont) -> Bool {
  font.is_identity_h()
}

///|
/// Test whether this font is a Type 0 font using `/Identity-V`.
pub fn PdfFont::is_identity_v(self : PdfFont) -> Bool {
  match self {
    PdfFontCIDKeyed(font) => font.is_identity_v()
    _ => false
  }
}

///|
/// Return true when this font consumes fixed two-byte text character codes.
pub fn PdfFont::uses_two_byte_codes(self : PdfFont) -> Bool {
  match self {
    PdfFontCIDKeyed(font) => font.uses_two_byte_codes()
    _ => false
  }
}

///|
/// Build a text extractor for an already parsed font.
pub fn PdfFont::text_extractor(self : PdfFont) -> PdfTextExtractor {
  { font: self }
}

///|
/// Compatibility wrapper for `PdfFont::text_extractor`.
pub fn pdf_text_extractor_of_font_real(font : PdfFont) -> PdfTextExtractor {
  font.text_extractor()
}

///|
/// Build a pure reverse lookup closure for an already parsed font.
///
/// The returned closure maps one Unicode codepoint to the first matching PDF
/// character code when the font can represent it. `debug` is accepted for
/// CamlPDF API compatibility; this implementation does not write diagnostics.
pub fn pdf_charcode_extractor_of_font_real(
  font : PdfFont,
  debug? : Bool = false,
) -> (Int) -> Int? {
  // CamlPDF reports missing glyphs to stderr when debug is true; this wrapper
  // keeps the lookup pure while preserving the API shape.
  ignore(debug)
  let extractor = font.text_extractor()
  fn(codepoint) { extractor.charcode_of_codepoint(codepoint) }
}

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
/// sequences raise `PdfError`, and missing metrics contribute width `0`.
pub fn PdfTextExtractor::text_width(
  self : PdfTextExtractor,
  text : BytesView,
) -> Double raise PdfError {
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

///|
/// Return a human-readable encoding label.
pub fn PdfEncoding::debug_name(self : PdfEncoding) -> String {
  match self {
    PdfImplicitInFontFile => "ImplicitInFontFile"
    PdfStandardEncoding => "StandardEncoding"
    PdfMacRomanEncoding => "MacRomanEncoding"
    PdfWinAnsiEncoding => "WinAnsiEncoding"
    PdfMacExpertEncoding => "MacExpertEncoding"
    PdfCustomEncoding(base, differences) => {
      let mut text = "CustomEncoding with base " +
        base.debug_name() +
        " and differences "
      for difference in differences {
        text = text +
          difference.code.to_string() +
          " -> " +
          pdf_text_string_of_name(difference.name) +
          ", "
      }
      text
    }
    PdfFillUndefinedWithStandard(base) =>
      "FillUndefinedWithStandard " + base.debug_name()
  }
}

///|
/// Return the PDF name for a built-in simple-font encoding.
///
/// Custom, implicit, and fallback encodings do not have a direct PDF name and
/// return `None`.
pub fn PdfEncoding::pdf_name(self : PdfEncoding) -> PdfName? {
  match self {
    PdfStandardEncoding => Some(pdf_text_standard_encoding_name)
    PdfMacRomanEncoding => Some(pdf_text_mac_roman_encoding_name)
    PdfWinAnsiEncoding => Some(pdf_text_win_ansi_encoding_name)
    PdfMacExpertEncoding => Some(pdf_text_mac_expert_encoding_name)
    _ => None
  }
}

///|
/// Recognize a built-in simple-font encoding name.
pub fn pdf_encoding_of_name(name : PdfName) -> PdfEncoding? {
  match name {
    name if name == pdf_text_standard_encoding_name => Some(PdfStandardEncoding)
    name if name == pdf_text_mac_roman_encoding_name =>
      Some(PdfMacRomanEncoding)
    name if name == pdf_text_win_ansi_encoding_name => Some(PdfWinAnsiEncoding)
    name if name == pdf_text_mac_expert_encoding_name =>
      Some(PdfMacExpertEncoding)
    _ => None
  }
}

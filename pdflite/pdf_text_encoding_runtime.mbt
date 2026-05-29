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

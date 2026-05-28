///|
/// Return true if a font dictionary is an unembedded standard 14 font.
///
/// A matching Type1 or TrueType `/BaseFont` without explicit `/Widths` is
/// treated as a standard-font dictionary.
pub fn PdfDocument::is_standard14_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) if pdf_text_is_standard14_subtype_name(subtype) =>
      match self.lookup_direct(pdf_text_base_font_key_name, font) {
        Some(PdfNameObject(base_font)) =>
          pdf_standard_font_of_pdf_name(base_font) != None &&
          self.lookup_direct(pdf_text_widths_key_name, font) == None
        _ => false
      }
    _ => false
  }
}

///|
/// Return true if a font dictionary has a simple-font subtype.
pub fn PdfDocument::is_simple_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) =>
      pdf_text_is_simple_font_subtype_name(subtype)
    _ => false
  }
}

///|
/// Return true if a font dictionary is a Type 0 CID-keyed font.
pub fn PdfDocument::is_cidkeyed_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) => subtype == pdf_text_type0_name
    _ => false
  }
}

///|
/// Read a standard 14 font dictionary.
///
/// The dictionary must contain a recognized `/BaseFont`; its encoding is read
/// with `read_encoding` so custom differences are preserved.
pub fn PdfDocument::read_standard14_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfStandardFontData raise PdfError {
  match self.lookup_direct(pdf_text_base_font_key_name, font) {
    Some(PdfNameObject(base_font)) =>
      match pdf_standard_font_of_pdf_name(base_font) {
        Some(standard_font) =>
          { font: standard_font, encoding: self.read_encoding(font) }
        None => raise StandardFontExpected
      }
    _ => raise BaseFontExpected
  }
}

///|
/// Read any supported PDF font dictionary.
///
/// The result is classified as standard 14, simple, or CID-keyed. A
/// `/ToUnicode` stream, when present and parseable, is attached to the parsed
/// font so extractors prefer explicit Unicode mappings.
pub fn PdfDocument::read_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfFont raise PdfError {
  let read = if self.is_standard14_font(font) {
    PdfFontStandard(self.read_standard14_font(font))
  } else if self.is_simple_font(font) {
    PdfFontSimple(self.read_simple_font(font))
  } else if self.is_cidkeyed_font(font) {
    PdfFontCIDKeyed(self.read_cidkeyed_font(font))
  } else {
    raise FontTypeExpected
  }
  read.pdf_text_with_tounicode(self.pdf_text_tounicode_of_font(font))
}

///|
/// Compatibility wrapper for `PdfDocument::read_font`.
pub fn pdf_read_font(
  document : PdfDocument,
  font : PdfObject,
) -> PdfFont raise PdfError {
  document.read_font(font)
}

///|
/// Read a font dictionary and return a text extractor for it.
pub fn PdfDocument::text_extractor_of_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfTextExtractor raise PdfError {
  self.read_font(font).text_extractor()
}

///|
/// Compatibility wrapper for `PdfDocument::text_extractor_of_font`.
pub fn pdf_text_extractor_of_font(
  document : PdfDocument,
  font : PdfObject,
) -> PdfTextExtractor raise PdfError {
  document.text_extractor_of_font(font)
}

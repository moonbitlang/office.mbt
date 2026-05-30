///|
fn PdfDocument::pdf_text_read_type3_glyphs(
  self : PdfDocument,
  font : @syntax.PdfObject,
) -> PdfType3Glyphs raise @core.PdfError {
  let fontbbox = match self.lookup_direct(pdf_text_font_bbox_key_name, font) {
    Some(value) =>
      self.parse_rectangle(value) catch {
        _ => pdf_text_zero_rectangle()
      }
    None => pdf_text_zero_rectangle()
  }
  let charprocs = match self.lookup_direct(pdf_text_charprocs_key_name, font) {
    Some(PdfDictionary(entries)) => entries
    _ => raise FontCharProcsExpected
  }
  let resources = match self.lookup_direct(pdf_text_resources_key_name, font) {
    Some(value) => value
    None => PdfDictionary([])
  }
  {
    fontbbox,
    fontmatrix: self.parse_matrix(pdf_text_font_matrix_key_name, font),
    charprocs,
    resources,
  }
}

///|
fn PdfDocument::pdf_text_simple_font_type_of_name(
  self : PdfDocument,
  font : @syntax.PdfObject,
  subtype : @core.PdfName,
) -> PdfSimpleFontType? raise @core.PdfError {
  if subtype == pdf_text_type1_name {
    Some(PdfType1)
  } else if subtype == pdf_text_mmtype1_name {
    Some(PdfMMType1)
  } else if subtype == pdf_text_type3_name {
    Some(PdfType3(self.pdf_text_read_type3_glyphs(font)))
  } else if subtype == pdf_text_true_type_name_value {
    Some(PdfTrueType)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_text_read_basefont(
  self : PdfDocument,
  font : @syntax.PdfObject,
) -> @core.PdfName? {
  match self.lookup_direct(pdf_text_base_font_key_name, font) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
/// Parse a simple-font dictionary.
///
/// Supported subtypes are Type1, MMType1, Type3, and TrueType. The returned
/// value includes optional descriptors, metrics, Type 3 CharProc data, and the
/// resolved simple-font encoding.
pub fn PdfDocument::read_simple_font(
  self : PdfDocument,
  font : @syntax.PdfObject,
) -> PdfSimpleFont raise @core.PdfError {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) =>
      match self.pdf_text_simple_font_type_of_name(font, subtype) {
        Some(fonttype) =>
          {
            fonttype,
            basefont: self.pdf_text_read_basefont(font),
            firstchar: 0,
            lastchar: 0,
            widths: [],
            fontdescriptor: self.read_font_descriptor(font),
            fontmetrics: self.read_font_metrics(font),
            encoding: self.read_encoding(font),
          }
        None => raise FontSubtypeExpected
      }
    _ => raise FontSubtypeExpected
  }
}

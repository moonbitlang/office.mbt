///|
/// Write a custom encoding dictionary and return its object number.
///
/// Currently this supports `/Differences` over an implicit base encoding, which
/// is the form needed by the font writer. Unsupported encodings raise
/// `@core.PdfError::EncodingWriteUnsupported`.
pub fn PdfDocument::write_encoding(
  self : PdfDocument,
  encoding : PdfEncoding,
) -> Int raise @core.PdfError {
  match encoding {
    PdfCustomEncoding(PdfImplicitInFontFile, differences) => {
      let values : Array[@syntax.PdfObject] = Array::new(
        capacity=differences.length() * 2,
      )
      for difference in differences {
        values.push(PdfInteger(difference.code))
        values.push(PdfNameObject(difference.name))
      }
      self.add_object(
        PdfDictionary([
          (pdf_text_type_key_name, PdfNameObject(pdf_text_encoding_key_name)),
          (pdf_text_differences_key_name, PdfArray(values)),
        ]),
      )
    }
    _ => raise EncodingWriteUnsupported
  }
}

///|
/// Build a simple Type 1 font dictionary for a base font and named encoding.
///
/// Only encodings with a direct PDF name can be written this way; custom or
/// implicit encodings raise `@core.PdfError::EncodingWriteUnsupported`.
pub fn pdf_make_font(
  fontname : @core.PdfName,
  encoding : PdfEncoding,
) -> @syntax.PdfObject raise @core.PdfError {
  match encoding.pdf_name() {
    Some(encoding_name) =>
      PdfDictionary([
        (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
        (pdf_text_subtype_key_name, PdfNameObject(pdf_text_type1_name)),
        (pdf_text_encoding_key_name, PdfNameObject(encoding_name)),
        (pdf_text_base_font_key_name, PdfNameObject(fontname)),
      ])
    None => raise EncodingWriteUnsupported
  }
}

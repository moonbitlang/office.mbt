///|
fn PdfDocument::pdf_text_add_font_object(
  self : PdfDocument,
  object : PdfObject,
  objnum : Int?,
) -> Int {
  match objnum {
    Some(number) => {
      self.add_object_given_number(number, object)
      number
    }
    None => self.add_object(object)
  }
}

///|
/// Write a parsed font into the document and return its object number.
///
/// Standard fonts, Type 3 fonts with descriptors, and TrueType fonts with
/// descriptors are supported. `objnum` can force the destination object number
/// for rewrite workflows. Unsupported font shapes raise `PdfError::FontWriteUnsupported`.
pub fn PdfDocument::write_font(
  self : PdfDocument,
  font : PdfFont,
  objnum? : Int? = None,
) -> Int raise PdfError {
  match font {
    PdfFontStandard({ font, encoding }) =>
      self.pdf_text_add_font_object(
        pdf_make_font(font.pdf_name(), encoding),
        objnum,
      )
    PdfFontSimple(
      {
        fonttype: PdfType3(data),
        firstchar,
        lastchar,
        widths,
        encoding,
        fontdescriptor,
        ..,
      }
    ) =>
      match fontdescriptor {
        Some(_) =>
          self.pdf_text_add_font_object(
            self.pdf_text_make_type3_font(
              data, firstchar, lastchar, widths, encoding,
            ),
            objnum,
          )
        None => raise FontWriteUnsupported
      }
    PdfFontSimple(
      {
        fonttype: PdfTrueType,
        basefont: Some(basefont),
        firstchar,
        lastchar,
        widths,
        fontdescriptor: Some(descriptor),
        encoding,
        ..,
      }
    ) =>
      self.pdf_text_add_font_object(
        self.pdf_text_make_true_type_font(
          basefont, firstchar, lastchar, widths, descriptor, encoding,
        ),
        objnum,
      )
    _ => raise FontWriteUnsupported
  }
}

///|
/// Compatibility wrapper for `PdfDocument::write_font`.
pub fn pdf_write_font(
  document : PdfDocument,
  font : PdfFont,
  objnum? : Int? = None,
) -> Int raise PdfError {
  document.write_font(font, objnum~)
}

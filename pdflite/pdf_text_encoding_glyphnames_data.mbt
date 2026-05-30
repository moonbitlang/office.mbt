///|
fn pdf_text_name_from_encodingdata(name : String?) -> @core.PdfName? {
  match name {
    Some(value) => Some(pdf_text_name(value))
    None => None
  }
}

///|
fn pdf_text_standard_glyphname(code : Int) -> @core.PdfName? {
  pdf_text_name_from_encodingdata(
    @encodingdata.pdf_text_standard_glyphname(code),
  )
}

///|
fn pdf_text_macroman_glyphname(code : Int) -> @core.PdfName? {
  pdf_text_name_from_encodingdata(
    @encodingdata.pdf_text_macroman_glyphname(code),
  )
}

///|
fn pdf_text_winansi_glyphname(code : Int) -> @core.PdfName? {
  pdf_text_name_from_encodingdata(
    @encodingdata.pdf_text_winansi_glyphname(code),
  )
}

///|
fn pdf_text_macexpert_glyphname(code : Int) -> @core.PdfName? {
  pdf_text_name_from_encodingdata(
    @encodingdata.pdf_text_macexpert_glyphname(code),
  )
}

///|
fn pdf_text_symbol_glyphname(code : Int) -> @core.PdfName? {
  pdf_text_name_from_encodingdata(@encodingdata.pdf_text_symbol_glyphname(code))
}

///|
fn pdf_text_zapfdingbats_glyphname(code : Int) -> @core.PdfName? {
  pdf_text_name_from_encodingdata(
    @encodingdata.pdf_text_zapfdingbats_glyphname(code),
  )
}

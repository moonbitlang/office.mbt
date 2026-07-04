///|
let pdf_text_glyph_space_name : @core.PdfName = pdf_text_static_name("/space")

///|
fn pdf_text_string_of_name(name : @core.PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

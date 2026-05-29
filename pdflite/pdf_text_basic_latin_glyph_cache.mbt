///|
let pdf_text_glyph_space_name : PdfName = pdf_text_static_name("/space")

///|
fn pdf_text_string_of_name(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

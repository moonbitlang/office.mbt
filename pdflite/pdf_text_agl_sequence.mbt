///|
fn pdf_text_codepoints_of_agl_sequence_glyphname(
  name : @core.PdfName,
) -> Array[Int]? {
  @glyphdata.pdf_text_codepoints_of_agl_sequence_glyphname(
    pdf_text_string_of_name(name),
  )
}

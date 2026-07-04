// Umbrella package: one entry point per sibling library, proving all three
// (mbtexcel, docx2html, pdflite) link into a single package.

///|
/// Build a tiny xlsx workbook and return its bytes.
pub fn make_workbook_bytes() -> Bytes raise {
  let wb = @mbtexcel.new_workbook()
  ignore(wb.add_sheet("Sheet1"))
  wb.set_cell_str("Sheet1", "A1", "Hello")
  @mbtexcel.write(wb)
}

///|
/// Build a minimal valid PDF and return its bytes.
pub fn make_pdf_bytes() -> Bytes raise {
  let doc = @pdflite.pdf_minimum_valid_pdf()
  @pdflite.pdf_write_document(doc)
}

///|
/// Convert a DOCX byte view to HTML.
pub fn docx_to_html(docx : BytesView) -> String raise {
  @docx2html.convert_to_html(docx).value
}

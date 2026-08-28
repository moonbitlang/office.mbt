///|
/// A descriptor carrying no font program. `/FontFile2` is optional in a
/// font descriptor (PDF 32000-1 §9.8.1); omitting it describes a font
/// the consumer substitutes, which is how a document references an
/// installed face rather than carrying it.
fn nonembedded_descriptor() -> @pdflite.PdfFontDescriptor {
  {
    ascent: 750,
    descent: -250,
    avgwidth: 500,
    maxwidth: 1000,
    flags: 32,
    fontbbox: { min_x: -100, min_y: -200, max_x: 1000, max_y: 900, },
    italicangle: 0,
    capheight: 700,
    xheight: 500,
    stemv: 80,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
fn nonembedded_font() -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfTrueType,
    basefont: Some(@core.pdf_name_of_bytes(b"/Carlito")),
    firstchar: 32,
    lastchar: 34,
    widths: [250, 500, 750],
    fontdescriptor: Some(nonembedded_descriptor()),
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
test "a TrueType font without a font program is written" {
  let document = @pdflite.pdf_document_empty()
  let number = document.write_font(nonembedded_font())
  assert_true(number > 0)
  // the descriptor and the font dictionary are both present
  assert_true(document.object_count() >= 2)
}

///|
test "the written font omits FontFile2 but keeps its widths" {
  let document = @pdflite.pdf_document_empty()
  ignore(document.write_font(nonembedded_font()))
  let page_root = document.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(document.add_root(page_root, []))
  let bytes = @pdflite.pdf_write_document(document)
  let sb = StringBuilder()
  for i in 0..<bytes.length() {
    sb.write_char(bytes[i].to_int().unsafe_to_char())
  }
  let text = sb.to_string()
  // a substitutable font: descriptor and widths, no embedded program
  assert_true(text.contains("/FontDescriptor"))
  assert_true(text.contains("/Widths"))
  assert_true(text.contains("/Carlito"))
  assert_false(text.contains("/FontFile2"))
}

///|
test "an embedded font still carries its program" {
  let document = @pdflite.pdf_document_empty()
  // a font file object the descriptor can point at
  let stub = document.add_object(PdfInteger(0))
  let font : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfTrueType,
    basefont: Some(@core.pdf_name_of_bytes(b"/Embedded")),
    firstchar: 32,
    lastchar: 32,
    widths: [500],
    fontdescriptor: Some({
      ..nonembedded_descriptor(),
      fontfile: Some(PdfFontFile2(stub)),
    }),
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
  ignore(document.write_font(font))
  let page_root = document.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(document.add_root(page_root, []))
  let bytes = @pdflite.pdf_write_document(document)
  let sb = StringBuilder()
  for i in 0..<bytes.length() {
    sb.write_char(bytes[i].to_int().unsafe_to_char())
  }
  assert_true(sb.to_string().contains("/FontFile2"))
}

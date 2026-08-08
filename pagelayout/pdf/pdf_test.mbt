///|
/// PDF bytes are not UTF-16; decode each byte as one character so the
/// content stream can be matched as text.
fn as_text(bytes : Bytes) -> String {
  let sb = StringBuilder()
  for i in 0..<bytes.length() {
    sb.write_char(bytes[i].to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
fn style(size_pt : Double) -> @paragraph.RunStyle {
  {
    family: "Calibri",
    size_pt,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
}

///|
fn para(text : String) -> @paragraph.ParagraphInput {
  {
    runs: [{ text, style: style(12) }],
    style: @paragraph.ParagraphStyle::default(),
  }
}

///|
test "a rendered pdf parses back as a valid document" {
  let model = @paginate.paginate([@paginate.Block::paragraph(para("Hello PDF"))])
  let bytes = @pdf.render_pdf(model)
  // the header and trailer a real PDF must have
  assert_true(bytes.length() > 500)
  inspect(as_text(bytes)[0:8].to_owned(), content="%PDF-1.7")
  // pdflite reads back what pdflite wrote: pages, and a resolvable tree
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  inspect(document.endpage(), content="1")
}

///|
test "text survives a round trip through the pdf" {
  let model = @paginate.paginate([
    @paginate.Block::paragraph(para("Round trip check")),
  ])
  let bytes = @pdf.render_pdf(model)
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let text = as_text(document.test_extract_text([1]))
  assert_true(text.contains("Round trip check"))
}

///|
test "multi-page models produce multi-page pdfs" {
  let model = @paginate.paginate([
    @paginate.Block::paragraph(para("one")),
    PageBreak,
    @paginate.Block::paragraph(para("two")),
    PageBreak,
    @paginate.Block::paragraph(para("three")),
  ])
  assert_eq(model.pages.length(), 3)
  let document = @pdflite.pdf_read_document_from_bytes(@pdf.render_pdf(model))
  inspect(document.endpage(), content="3")
}

///|
test "page geometry reaches the pdf mediabox" {
  // A4 portrait rather than the Letter default
  let section = @paginate.SectionProps::{
    page_width_pt: 595.3,
    page_height_pt: 841.9,
    margin_top_pt: 72,
    margin_right_pt: 72,
    margin_bottom_pt: 72,
    margin_left_pt: 72,
    header_pt: 36,
    footer_pt: 36,
  }
  let model = @paginate.paginate(
    [@paginate.Block::paragraph(para("A4"))],
    section~,
  )
  let bytes = @pdf.render_pdf(model)
  let text = as_text(bytes)
  // the MediaBox carries the section's size
  assert_true(text.contains("595.3"))
  assert_true(text.contains("841.9"))
}

///|
test "the y axis is flipped from the IR's top-left origin" {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Carlito", bold: false, italic: false })
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [] }
  page.items.push(
    Text({
      font,
      size_pt: 12,
      x_pt: 10,
      // 30pt down from the top is 70pt up from the bottom
      baseline_pt: 30,
      text: "x",
      advances_pt: [6.0],
      color: @pagelayout.black,
    }),
  )
  model.pages.push(page)
  let text = as_text(@pdf.render_pdf(model))
  // the text matrix places the baseline at 100 - 30
  assert_true(text.contains("1 0 0 1 10 70 Tm"))
}

///|
test "rects are flipped and filled" {
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [] }
  page.items.push(
    Rect({
      x_pt: 10,
      y_pt: 20,
      w_pt: 50,
      h_pt: 5,
      fill: Some(@pagelayout.Color::rgb(255, 0, 0)),
      stroke: None,
      stroke_w_pt: 0,
    }),
  )
  model.pages.push(page)
  let text = as_text(@pdf.render_pdf(model))
  // an IR rect anchored top-left at y=20 with height 5 sits at
  // 100 - 20 - 5 = 75 in PDF coordinates
  assert_true(text.contains("10 75 50 5 re"))
  assert_true(text.contains("1 0 0 rg"))
}

///|
fn docx_bytes(body : String) -> Bytes raise {
  let archive = @zip.Archive::new()
  let document = (
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
    ) +
    body +
    "</w:body></w:document>"
  archive.add("word/document.xml", @utf8.encode(document))
  @zip.write(archive)
}

///|
test "a real docx renders to a pdf that parses" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Heading</w:t></w:r></w:p>
        #|<w:p><w:r><w:t>Body text with punctuation — and a bullet •.</w:t></w:r></w:p>
      ),
    ),
  )
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  let bytes = @pdf.render_pdf(model)
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  inspect(document.endpage(), content="1")
  let text = as_text(document.test_extract_text([1]))
  assert_true(text.contains("Heading"))
  assert_true(text.contains("Body text"))
}

///|
test "characters outside WinAnsi do not break the run that follows" {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Carlito", bold: false, italic: false })
  let page = @pagelayout.Page::{ width_pt: 300, height_pt: 100, items: [] }
  page.items.push(
    Text({
      font,
      size_pt: 12,
      x_pt: 0,
      baseline_pt: 20,
      // the han character cannot be encoded in WinAnsi
      text: "ab中cd",
      advances_pt: [6.0, 6.0, 12.0, 6.0, 6.0],
      color: @pagelayout.black,
    }),
  )
  model.pages.push(page)
  let text = as_text(@pdf.render_pdf(model))
  // "ab" is drawn at x=0 and "cd" resumes at 6+6+12 = 24, so the tail
  // keeps the position the layout gave it
  assert_true(text.contains("1 0 0 1 0 80 Tm"))
  assert_true(text.contains("1 0 0 1 24 80 Tm"))
}

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
    runs: [{ text, style: style(12), field: NotAField }],
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

///|
test "an image becomes an XObject drawn at its box" {
  let png = b"\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90\x77\x53\xde\x00\x00\x00\x0c\x49\x44\x41\x54\x08\xd7\x63\xf8\xcf\xc0\x00\x00\x03\x01\x01\x00\x18\xdd\x8d\xb0\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82"
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [] }
  page.items.push(
    Image({
      x_pt: 10,
      y_pt: 20,
      w_pt: 50,
      h_pt: 30,
      data: png,
      mime: "image/png",
    }),
  )
  model.pages.push(page)
  let text = as_text(@pdf.render_pdf(model))
  // a PDF image fills the unit square, so the transform carries the
  // size; the box's bottom edge is 100 - 20 - 30 = 50
  assert_true(text.contains("50 0 0 30 10 50 cm"))
  assert_true(text.contains("Do"))
  assert_true(text.contains("/XObject"))
}

///|
test "an unembeddable image is skipped, not written as garbage" {
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [] }
  page.items.push(
    Image({
      x_pt: 0,
      y_pt: 0,
      w_pt: 10,
      h_pt: 10,
      data: b"not an image",
      mime: "image/tiff",
    }),
  )
  model.pages.push(page)
  // still a readable PDF, just without the image
  let document = @pdflite.pdf_read_document_from_bytes(@pdf.render_pdf(model))
  inspect(document.endpage(), content="1")
}

///|
test "cjk text is embedded as a composite font" {
  let model = @paginate.paginate([
    @paginate.Block::paragraph(para("中文测试")),
  ])
  let text = as_text(@pdf.render_pdf(model))
  // a composite font: Type0 root, Identity-H, CIDFontType2 descendant
  assert_true(text.contains("/Type0"))
  assert_true(text.contains("/Identity-H"))
  assert_true(text.contains("/CIDFontType2"))
  // and the program itself, without which Identity-H's glyph indices
  // would address whatever face the reader happened to substitute
  assert_true(text.contains("/FontFile2"))
  assert_true(text.contains("/CIDToGIDMap /Identity"))
  // the subset tag PDF wants on an embedded subset
  assert_true(text.contains("+NotoSansSC"))
}

///|
test "latin text stays a simple font, but an embedded one" {
  let model = @paginate.paginate([@paginate.Block::paragraph(para("Hello"))])
  let text = as_text(@pdf.render_pdf(model))
  // WinAnsi addresses everything here, so the font stays simple: smaller
  // than a composite, and spaced by /Widths rather than a /W array
  assert_true(text.contains("/TrueType"))
  assert_false(text.contains("/Type0"))
  // but the program travels with the document, so the page renders the
  // shapes it was laid out with rather than whatever the viewer picks
  assert_true(text.contains("/FontFile2"))
  assert_true(text.contains("+Carlito"))
}

///|
test "an embedded subset carries only the characters used" {
  // one ideograph pulls in a handful of glyphs, not all 31,036
  let small = @pdf.render_pdf(
    @paginate.paginate([@paginate.Block::paragraph(para("中"))]),
  )
  let large = @pdf.render_pdf(
    @paginate.paginate([
      @paginate.Block::paragraph(
        para(
          "中文测试排版引擎确定性输出字体嵌入子集化效果显著",
        ),
      ),
    ]),
  )
  // subsetting is what keeps a 10 MB face out of every document
  assert_true(small.length() < 60000)
  assert_true(large.length() > small.length())
}

///|
test "rendering the same model twice is byte-identical" {
  // subset tags come from the font's position in the model, not a
  // process-global counter, so output stays a function of input
  let model = @paginate.paginate([
    @paginate.Block::paragraph(para("中文 mixed with Latin")),
  ])
  let first = @pdf.render_pdf(model)
  let second = @pdf.render_pdf(model)
  assert_eq(first.length(), second.length())
  assert_true(first == second)
}

///|
test "embedded cjk carries a ToUnicode map so the text stays extractable" {
  let model = @paginate.paginate([@paginate.Block::paragraph(para("中文"))])
  let text = as_text(@pdf.render_pdf(model))
  // A composite font's codes are two bytes wide. Declaring a one-byte
  // codespace still *renders* correctly — the glyphs do not care — but a
  // reader then takes the high byte of every CID for a whole character,
  // and pdftotext returns nothing for the page.
  assert_true(text.contains("<0000><FFFF>"))
  assert_false(text.contains("<00><FF>"))
  // 中 is glyph 8805 (0x2265) and 文 glyph 14750 (0x399E) in Noto Sans SC;
  // Identity-H writes those ids as the codes, so ToUnicode maps them back
  assert_true(text.contains("<2265><2265><4E2D>"))
  assert_true(text.contains("<399e><399e><6587>"))
}

///|
test "metrics and outline programs agree on glyph ids" {
  // The renderer takes glyph ids from the *metrics* bundle and subsets
  // the *outline* bundle by codepoint. The two are separate packages
  // built by separate generators, so nothing but this checks that they
  // describe the same glyph order — and if they drifted, every CJK page
  // would draw the wrong characters while still looking well-formed.
  guard @fontoutlines.outline_sfnt("Noto Sans SC") is Some(program) else {
    fail("Noto Sans SC has no bundled outlines")
  }
  let from_program : Map[Int, Int] = Map([])
  for entry in @pdflite.pdf_truetype_cmap_glyphs(program) {
    from_program[entry.codepoint] = entry.glyph_index
  }
  let metrics = @fonts.face("Noto Sans SC")
  let mut compared = 0
  for codepoint, glyph in metrics.cmap {
    match from_program.get(codepoint) {
      Some(other) => {
        assert_eq(glyph, other)
        compared += 1
      }
      None => fail("outline program lacks U+\{codepoint} the metrics map")
    }
  }
  // a real comparison, not a vacuous one over an empty map
  assert_true(compared > 30000)
}

///|
test "cid bytes that collide with pdf string delimiters are escaped" {
  // Identity-H writes glyph ids as raw two-byte codes inside a PDF
  // string, so a glyph whose id contains 0x28, 0x29 or 0x5C would end or
  // corrupt that string if written literally. These three characters are
  // exactly that case in Noto Sans SC:
  //   仰 U+4EF0 -> glyph 9000  = 0x2328  ('(')
  //   仱 U+4EF1 -> glyph 9001  = 0x2329  (')')
  //   两 U+4E24 -> glyph 8796  = 0x225C  ('\')
  let model = @paginate.paginate([@paginate.Block::paragraph(para("仰仱两"))])
  let bytes = @pdf.render_pdf(model)
  let text = as_text(bytes)
  // the full two-byte code, escaped: 0x23 0x28 -> `#\(`, and so on. The
  // leading byte makes these precise rather than incidentally matched.
  assert_true(text.contains("#\\("))
  assert_true(text.contains("#\\)"))
  assert_true(text.contains("\"\\\\"))
  // and the document still reads back, which a broken string would stop
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  inspect(document.endpage(), content="1")
}

///|
test "two documents sharing image bytes each carry their own XObject" {
  // Object numbers are allocated per document. A cache that outlived one
  // render made the second document reference an object the first had
  // allocated — it kept the /XObject resource entry and lost the image,
  // so the file was a dangling reference rather than a visible error.
  let png = b"\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90\x77\x53\xde\x00\x00\x00\x0c\x49\x44\x41\x54\x08\xd7\x63\xf8\xcf\xc0\x00\x00\x03\x01\x01\x00\x18\xdd\x8d\xb0\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82"
  fn build() {
    let model = @pagelayout.PageModel::new()
    let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [] }
    page.items.push(
      Image({
        x_pt: 10,
        y_pt: 20,
        w_pt: 50,
        h_pt: 30,
        data: png,
        mime: "image/png",
      }),
    )
    model.pages.push(page)
    model
  }

  let first = @pdf.render_pdf(build())
  let second = @pdf.render_pdf(build())
  // the same model must render the same bytes however many came before
  assert_eq(first.length(), second.length())
  assert_true(first == second)
  // and the image itself has to be present, not merely referenced
  assert_true(as_text(second).contains("/Image"))
}

///|
test "a face goes composite only for characters it can actually draw" {
  // Carlito has no han glyphs. Going composite for 中 would spell it as
  // `.notdef` and then space the rest of the run by that glyph's width,
  // losing the advance the layout chose — so the emitter must keep the
  // font simple and break the run around the character instead.
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Carlito", bold: false, italic: false })
  let page = @pagelayout.Page::{ width_pt: 300, height_pt: 100, items: [] }
  page.items.push(
    Text({
      font,
      size_pt: 12,
      x_pt: 0,
      baseline_pt: 20,
      text: "ab中cd",
      advances_pt: [6.0, 6.0, 12.0, 6.0, 6.0],
      color: @pagelayout.black,
    }),
  )
  model.pages.push(page)
  let text = as_text(@pdf.render_pdf(model))
  assert_false(text.contains("/Type0"))
  // the tail still resumes at the position the layout gave it
  assert_true(text.contains("1 0 0 1 24 80 Tm"))
}

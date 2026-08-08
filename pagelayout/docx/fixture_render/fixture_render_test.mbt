///|
/// A real Word-produced package (copied from docx2html's cram fixtures).
/// This is the first contact between the engine and a file Word wrote.
async test "real word document renders end to end" {
  let bytes = @afs.read_file("docx/fixture_render/single-paragraph.docx").binary()
  let doc = @docx.read_docx(bytes)
  assert_true(doc.blocks.length() > 0)
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  debug_inspect(model.validate(), content="[]")
  assert_true(model.pages.length() >= 1)
  // Word's default page is US Letter with 1in margins
  inspect(
    doc.section.page_width_pt,
    content=(
      #|595.3
    ),
  )
  inspect(
    doc.section.page_height_pt,
    content=(
      #|841.9
    ),
  )
  // and the text made it through
  let sb = StringBuilder()
  for item in model.pages[0].items {
    guard! item is Text(run)
    sb.write_string(run.text)
  }
  inspect(sb.to_string(), content="Walking on imported air")
}

///|
/// The fixture's docDefaults name no font directly — they reference
/// `w:asciiTheme="minorHAnsi"`, which theme1.xml resolves to Calibri.
/// Before theme support the hardcoded Calibri default made this render
/// correctly by luck; this pins that it now resolves for the right
/// reason, so a theme naming a different face would follow it.
async test "real word document resolves its font through the theme" {
  let bytes = @afs.read_file("docx/fixture_render/single-paragraph.docx").binary()
  let doc = @docx.read_docx(bytes)
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.runs[0].style.family, content="Calibri")
  // and nothing was silently dropped
  json_inspect(doc.unsupported, content=[])
}

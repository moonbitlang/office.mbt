///|
/// Build a .docx package from a document.xml body and an optional
/// styles.xml, so tests state exactly the XML they exercise.
fn docx_bytes(
  body : String,
  styles? : String,
  theme? : String,
  numbering? : String,
) -> Bytes raise {
  let archive = @zip.Archive::new()
  let document = (
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
    ) +
    body +
    "</w:body></w:document>"
  archive.add("word/document.xml", @utf8.encode(document))
  match theme {
    Some(th) => {
      let theme_xml = (
          #|<?xml version="1.0" encoding="UTF-8"?>
          #|<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        ) +
        th +
        "</a:theme>"
      archive.add("word/theme/theme1.xml", @utf8.encode(theme_xml))
    }
    None => ()
  }
  match numbering {
    Some(n) => {
      let numbering_xml = (
          #|<?xml version="1.0" encoding="UTF-8"?>
          #|<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        ) +
        n +
        "</w:numbering>"
      archive.add("word/numbering.xml", @utf8.encode(numbering_xml))
    }
    None => ()
  }
  match styles {
    Some(s) => {
      let styles_xml = (
          #|<?xml version="1.0" encoding="UTF-8"?>
          #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        ) +
        s +
        "</w:styles>"
      archive.add("word/styles.xml", @utf8.encode(styles_xml))
    }
    None => ()
  }
  @zip.write(archive)
}

///|
fn first_run(doc : @docx.DocxDocument, index : Int) -> @paragraph.RunInput {
  guard! doc.blocks[index] is Paragraph(input~, ..)
  input.runs[0]
}

///|
test "a fully unspecified run resolves to the silent-hierarchy defaults" {
  // No docDefaults, no style, no direct rPr: nothing anywhere names a
  // size, which is a different case from Word's default template (that
  // writes sz="22" explicitly and never reaches the fallback). The
  // format leaves this to the consumer; 10pt is what LibreOffice — the
  // reference the harness can run — chooses, and what erased the
  // corpus's 1.10x width error. See RunProps::resolve.
  let doc = @docx.read_docx(
    docx_bytes("<w:p><w:r><w:t>Hello</w:t></w:r></w:p>"),
  )
  assert_eq(doc.blocks.length(), 1)
  let run = first_run(doc, 0)
  inspect(run.text, content="Hello")
  inspect(run.style.family, content="Calibri")
  inspect(run.style.size_pt, content="10")
  assert_false(run.style.bold)
  inspect(run.style.color.to_hex(), content="#000000")
}

///|
test "docDefaults sz=22 renders at 11pt, untouched by the fallback" {
  // Word's default template writes this exact declaration — the usual
  // recent-Word-template case: an explicit 22 half-points in
  // docDefaults. It must land as 11pt; the silent-hierarchy fallback
  // above never fires for it.
  let doc = @docx.read_docx(
    docx_bytes(
      "<w:p><w:r><w:t>Hello</w:t></w:r></w:p>",
      styles=(
        #|<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>
      ),
    ),
  )
  inspect(first_run(doc, 0).style.size_pt, content="11")
}

///|
test "direct run formatting is read with full fidelity" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:rPr><w:rFonts w:ascii="Times New Roman"/><w:sz w:val="21"/><w:b/><w:i/><w:color w:val="FF8000"/></w:rPr><w:t>styled</w:t></w:r></w:p>
      ),
    ),
  )
  let run = first_run(doc, 0)
  inspect(run.style.family, content="Times New Roman")
  // w:sz 21 half-points = 10.5pt — the fractional size docx2html's model
  // would have truncated to 10
  inspect(run.style.size_pt, content="10.5")
  assert_true(run.style.bold)
  assert_true(run.style.italic)
  inspect(run.style.color.to_hex(), content="#ff8000")
}

///|
test "toggle properties honor explicit off" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:rPr><w:b w:val="0"/><w:i w:val="true"/></w:rPr><w:t>x</w:t></w:r></w:p>
      ),
    ),
  )
  let run = first_run(doc, 0)
  assert_false(run.style.bold)
  assert_true(run.style.italic)
}

///|
test "paragraph properties map onto the engine's style" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:jc w:val="both"/><w:ind w:left="720" w:right="360" w:firstLine="240"/><w:spacing w:before="120" w:after="240" w:line="360" w:lineRule="auto"/></w:pPr><w:r><w:t>text</w:t></w:r></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  let style = input.style
  debug_inspect(style.align, content="AlignJustify")
  inspect(style.indent_left_pt, content="36") // 720 twips
  inspect(style.indent_right_pt, content="18")
  inspect(style.indent_first_pt, content="12")
  inspect(style.space_before_pt, content="6")
  inspect(style.space_after_pt, content="12")
  // w:line 360 with lineRule auto = 1.5x
  debug_inspect(style.line_spacing, content="Multiple(1.5)")
}

///|
test "hanging indent becomes a negative first-line indent" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.style.indent_first_pt, content="-18")
}

///|
test "exact and atLeast line rules pass through" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:spacing w:line="480" w:lineRule="exact"/></w:pPr><w:r><w:t>a</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:spacing w:line="480" w:lineRule="atLeast"/></w:pPr><w:r><w:t>b</w:t></w:r></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  debug_inspect(input.style.line_spacing, content="Exact(24)")
  guard! doc.blocks[1] is Paragraph(input=second, ..)
  debug_inspect(second.style.line_spacing, content="AtLeast(24)")
}

///|
test "style cascade: docDefaults, basedOn chain, then direct" {
  let styles =
    #|<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Cambria"/><w:sz w:val="20"/></w:rPr></w:rPrDefault></w:docDefaults>
    #|<w:style w:type="paragraph" w:styleId="Base"><w:rPr><w:sz w:val="24"/><w:b/></w:rPr></w:style>
    #|<w:style w:type="paragraph" w:styleId="Derived"><w:basedOn w:val="Base"/><w:rPr><w:i/></w:rPr></w:style>
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:pStyle w:val="Derived"/></w:pPr><w:r><w:t>a</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:pStyle w:val="Derived"/></w:pPr><w:r><w:rPr><w:b w:val="0"/></w:rPr><w:t>b</w:t></w:r></w:p>
      ),
      styles~,
    ),
  )
  // family from docDefaults, size+bold from Base, italic from Derived
  let a = first_run(doc, 0)
  inspect(a.style.family, content="Cambria")
  inspect(a.style.size_pt, content="12")
  assert_true(a.style.bold)
  assert_true(a.style.italic)
  // direct formatting beats the whole chain
  let b = first_run(doc, 1)
  assert_false(b.style.bold)
  assert_true(b.style.italic)
}

///|
test "default paragraph style applies to unstyled paragraphs" {
  let styles =
    #|<w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:rPr><w:rFonts w:ascii="Arial"/></w:rPr></w:style>
  let doc = @docx.read_docx(
    docx_bytes("<w:p><w:r><w:t>x</w:t></w:r></w:p>", styles~),
  )
  inspect(first_run(doc, 0).style.family, content="Arial")
}

///|
test "character style layers over the paragraph style" {
  let styles =
    #|<w:style w:type="paragraph" w:styleId="Body"><w:rPr><w:sz w:val="20"/></w:rPr></w:style>
    #|<w:style w:type="character" w:styleId="Emph"><w:rPr><w:i/><w:color w:val="0000FF"/></w:rPr></w:style>
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:pStyle w:val="Body"/></w:pPr><w:r><w:rPr><w:rStyle w:val="Emph"/></w:rPr><w:t>x</w:t></w:r></w:p>
      ),
      styles~,
    ),
  )
  let run = first_run(doc, 0)
  inspect(run.style.size_pt, content="10")
  assert_true(run.style.italic)
  inspect(run.style.color.to_hex(), content="#0000ff")
}

///|
test "a basedOn cycle terminates instead of hanging" {
  let styles =
    #|<w:style w:type="paragraph" w:styleId="A"><w:basedOn w:val="B"/><w:rPr><w:b/></w:rPr></w:style>
    #|<w:style w:type="paragraph" w:styleId="B"><w:basedOn w:val="A"/><w:rPr><w:i/></w:rPr></w:style>
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:pStyle w:val="A"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
      styles~,
    ),
  )
  let run = first_run(doc, 0)
  assert_true(run.style.bold)
  assert_true(run.style.italic)
}

///|
test "sectPr page geometry drives pagination" {
  // A4 landscape-ish: 16838 x 11906 twips, 0.5in margins
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>x</w:t></w:r></w:p>
        #|<w:sectPr><w:pgSz w:w="16838" w:h="11906"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr>
      ),
    ),
  )
  inspect(doc.section.page_width_pt, content="841.9")
  inspect(doc.section.page_height_pt, content="595.3")
  inspect(doc.section.margin_left_pt, content="36")
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  inspect(model.pages[0].width_pt, content="841.9")
  guard! model.pages[0].items[0] is Text(run)
  inspect(run.x_pt, content="36")
}

///|
test "keep flags and page breaks reach the paginator" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:keepNext/><w:keepLines/><w:widowControl w:val="0"/></w:pPr><w:r><w:t>heading</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:pageBreakBefore/></w:pPr><w:r><w:t>next page</w:t></w:r></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(keep_next~, keep_lines~, widow_control~, ..)
  assert_true(keep_next)
  assert_true(keep_lines)
  assert_false(widow_control)
  // pageBreakBefore inserted an explicit break between the paragraphs
  assert_eq(doc.blocks.length(), 3)
  assert_true(doc.blocks[1] is PageBreak)
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  assert_eq(model.pages.length(), 2)
}

///|
test "explicit page-break runs split the document" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>one</w:t></w:r></w:p>
        #|<w:p><w:r><w:br w:type="page"/></w:r><w:r><w:t>two</w:t></w:r></w:p>
      ),
    ),
  )
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  assert_eq(model.pages.length(), 2)
}

///|
test "tabs, line breaks and hyperlink runs contribute text" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t xml:space="preserve">a </w:t><w:tab/></w:r><w:hyperlink r:id="rId1" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:r><w:t>link</w:t></w:r></w:hyperlink></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  let joined = StringBuilder()
  for run in input.runs {
    joined.write_string(run.text)
  }
  inspect(joined.to_string(), content="a \tlink")
}

///|
test "missing document part is reported, not panicked" {
  let archive = @zip.Archive::new()
  archive.add("word/styles.xml", b"<x/>")
  let bytes = @zip.write(archive)
  try @docx.read_docx(bytes) catch {
    err => inspect(err is @core.DocxError::MissingPart(..), content="true")
  } noraise {
    _ => fail("expected a MissingPart error")
  }
}

///|
test "end to end: a generated docx renders to a page model" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>Title</w:t></w:r></w:p>
        #|<w:p><w:r><w:t>Body text with 中文 mixed in.</w:t></w:r></w:p>
      ),
    ),
  )
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  debug_inspect(model.validate(), content="[]")
  // the CJK characters picked up the fallback face
  let families : Array[String] = []
  for font in model.fonts {
    families.push(font.family)
  }
  assert_true(families.contains("Noto Sans SC"))
}

///|
// --- regression tests for the review findings ---

///|
test "page break at the end of a paragraph splits after it" {
  // Word's usual idiom: the break closes the page it ends
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>Cover</w:t><w:br w:type="page"/></w:r></w:p>
        #|<w:p><w:r><w:t>Chapter 1</w:t></w:r></w:p>
      ),
    ),
  )
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  assert_eq(model.pages.length(), 2)
  guard! model.pages[0].items[0] is Text(first)
  inspect(first.text, content="Cover")
  guard! model.pages[1].items[0] is Text(second)
  inspect(second.text, content="Chapter 1")
}

///|
test "runs inside tracked insertions, fields and content controls survive" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>a</w:t></w:r><w:ins w:id="1"><w:r><w:t>b</w:t></w:r></w:ins><w:fldSimple w:instr="PAGE"><w:r><w:t>c</w:t></w:r></w:fldSimple><w:sdt><w:sdtContent><w:r><w:t>d</w:t></w:r></w:sdtContent></w:sdt><w:smartTag><w:r><w:t>e</w:t></w:r></w:smartTag></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  let sb = StringBuilder()
  for run in input.runs {
    sb.write_string(run.text)
  }
  inspect(sb.to_string(), content="abcde")
}

///|
test "tracked deletions are not rendered" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>keep</w:t></w:r><w:del w:id="2"><w:r><w:delText>gone</w:delText></w:r></w:del></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.runs.length(), content="1")
  inspect(input.runs[0].text, content="keep")
}

///|
test "explicit textWrapping break is a line break" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>one</w:t><w:br w:type="textWrapping"/><w:t>two</w:t></w:r></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(
    input.runs[0].text,
    content=(
      #|one
      #|two
    ),
  )
}

///|
test "universal measures convert instead of being dropped" {
  // A4 written as centimetres rather than twips
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>x</w:t></w:r></w:p>
        #|<w:sectPr><w:pgSz w:w="21cm" w:h="29.7cm"/><w:pgMar w:top="1in" w:left="0.5in" w:right="36pt" w:bottom="1in"/></w:sectPr>
      ),
    ),
  )
  inspect(
    doc.section.page_width_pt,
    content=(
      #|595.25
    ),
  )
  inspect(
    doc.section.page_height_pt,
    content=(
      #|841.85
    ),
  )
  inspect(doc.section.margin_top_pt, content="72")
  inspect(doc.section.margin_left_pt, content="36")
  inspect(doc.section.margin_right_pt, content="36")
}

///|
test "out-of-range measures are rejected rather than wrapped" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>x</w:t></w:r></w:p>
        #|<w:sectPr><w:pgSz w:w="99999999999" w:h="11906"/></w:sectPr>
      ),
    ),
  )
  // the bad width falls back to the default instead of going negative
  inspect(doc.section.page_width_pt, content="612")
  assert_true(doc.section.page_width_pt > 0)
}

///|
test "theme fonts resolve through docDefaults" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>body</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>heading</w:t></w:r></w:p>
      ),
      styles=(
        #|<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:asciiTheme="minorHAnsi"/></w:rPr></w:rPrDefault></w:docDefaults>
        #|<w:style w:type="paragraph" w:styleId="Heading1"><w:rPr><w:rFonts w:asciiTheme="majorHAnsi"/></w:rPr></w:style>
      ),
      theme=(
        #|<a:themeElements><a:fontScheme><a:majorFont><a:latin typeface="Georgia"/></a:majorFont><a:minorFont><a:latin typeface="Verdana"/></a:minorFont></a:fontScheme></a:themeElements>
      ),
    ),
  )
  inspect(first_run(doc, 0).style.family, content="Verdana")
  inspect(first_run(doc, 1).style.family, content="Georgia")
}

///|
test "a direct family beats a theme reference" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:rPr><w:rFonts w:ascii="Courier New" w:asciiTheme="minorHAnsi"/></w:rPr><w:t>x</w:t></w:r></w:p>
      ),
      theme=(
        #|<a:themeElements><a:fontScheme><a:minorFont><a:latin typeface="Verdana"/></a:minorFont></a:fontScheme></a:themeElements>
      ),
    ),
  )
  inspect(first_run(doc, 0).style.family, content="Courier New")
}

///|
test "a dangling pStyle still gets the default style" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:pStyle w:val="NoSuchStyle"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
      styles=(
        #|<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:rPr><w:rFonts w:ascii="Arial"/></w:rPr></w:style>
      ),
    ),
  )
  inspect(first_run(doc, 0).style.family, content="Arial")
}

///|
test "an empty paragraph keeps its paragraph-mark styling" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:rPr><w:sz w:val="48"/></w:rPr></w:pPr></w:p>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.runs.length(), content="1")
  inspect(input.runs[0].style.size_pt, content="24")
}

///|
test "a table becomes a laid-out block, not an omission" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>before</w:t></w:r></w:p>
        #|<w:tbl><w:tblGrid><w:gridCol w:w="2880"/><w:gridCol w:w="2880"/></w:tblGrid><w:tr><w:tc><w:p><w:r><w:t>a1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>b1</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
        #|<w:p><w:r><w:t>after</w:t></w:r></w:p>
      ),
    ),
  )
  // paragraph, table, paragraph — nothing dropped
  inspect(doc.blocks.length(), content="3")
  json_inspect(doc.unsupported, content=[])
  guard! doc.blocks[1] is TableBlock(table~, ..)
  inspect(table.rows.length(), content="1")
  inspect(table.rows[0].cells.length(), content="2")
  inspect(table.column_count(), content="2")
}

///|
test "content controls are still reported as unsupported" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:r><w:t>x</w:t></w:r></w:p>
        #|<w:sdt><w:sdtContent><w:p><w:r><w:t>inside</w:t></w:r></w:p></w:sdtContent></w:sdt>
      ),
    ),
  )
  json_inspect(doc.unsupported, content=["content control"])
}

///|
test "table properties parse into the model" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/><w:tblLayout w:type="fixed"/><w:tblInd w:w="720" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="8" w:color="FF0000"/></w:tblBorders><w:tblCellMar><w:left w:w="200" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid><w:gridCol w:w="1440"/></w:tblGrid><w:tr><w:trPr><w:tblHeader/><w:cantSplit/><w:trHeight w:val="1440" w:hRule="atLeast"/></w:trPr><w:tc><w:tcPr><w:gridSpan w:val="1"/><w:shd w:fill="EEEEEE"/></w:tcPr><w:p><w:r><w:t>h</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
      ),
    ),
  )
  guard! doc.blocks[0] is TableBlock(table~, ..)
  debug_inspect(table.layout, content="Fixed")
  debug_inspect(table.width, content="Percent(5000)")
  inspect(table.indent.to_pt(), content="36")
  // the table border cascades down to the cell
  guard! table.borders.top is Some(top)
  inspect(top.color.to_hex(), content="#ff0000")
  inspect(top.width.to_pt(), content="1")
  let row = table.rows[0]
  assert_true(row.header)
  assert_true(row.cant_split)
  inspect(row.min_height.unwrap().to_pt(), content="72")
  let cell = row.cells[0]
  // table cell margin inherited, cell shading read
  inspect(cell.margins.left.to_pt(), content="10")
  inspect(cell.shading.unwrap().to_hex(), content="#eeeeee")
  guard! cell.borders.top is Some(_)
}

///|
test "gridSpan and vMerge parse" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:tbl><w:tblGrid><w:gridCol w:w="1440"/><w:gridCol w:w="1440"/></w:tblGrid>
        #|<w:tr><w:tc><w:tcPr><w:gridSpan w:val="2"/><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>wide</w:t></w:r></w:p></w:tc></w:tr>
        #|<w:tr><w:tc><w:tcPr><w:gridSpan w:val="2"/><w:vMerge/></w:tcPr><w:p><w:r><w:t>cont</w:t></w:r></w:p></w:tc></w:tr>
        #|</w:tbl>
      ),
    ),
  )
  guard! doc.blocks[0] is TableBlock(table~, ..)
  inspect(table.rows[0].cells[0].grid_span, content="2")
  debug_inspect(table.rows[0].cells[0].vmerge, content="VStart")
  debug_inspect(table.rows[1].cells[0].vmerge, content="VContinue")
}

///|
test "a table renders into the page model end to end" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:tbl><w:tblBorders><w:top w:val="single" w:sz="4"/><w:bottom w:val="single" w:sz="4"/></w:tblBorders><w:tblGrid><w:gridCol w:w="2880"/><w:gridCol w:w="2880"/></w:tblGrid>
        #|<w:tr><w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Value</w:t></w:r></w:p></w:tc></w:tr>
        #|<w:tr><w:tc><w:p><w:r><w:t>alpha</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc></w:tr>
        #|</w:tbl>
      ),
    ),
  )
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  debug_inspect(model.validate(), content="[]")
  assert_eq(model.pages.length(), 1)
  // every cell's text made it through, in reading order
  let sb = StringBuilder()
  for item in model.pages[0].items {
    if item is Text(run) {
      sb.write_string(run.text)
      sb.write_string("|")
    }
  }
  inspect(sb.to_string(), content="Name|Value|alpha|1|")
}

///|
// --- lists ---

///|
/// A numbering.xml with one decimal instance (numId 1) whose level 0
/// indents 720 twips with a 360 hanging indent, plus a bullet level 1.
fn list_numbering() -> String {
  (
    #|<w:abstractNum w:abstractNumId="100">
    #|<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl>
    #|<w:lvl w:ilvl="1"><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr></w:lvl>
    #|</w:abstractNum>
    #|<w:num w:numId="1"><w:abstractNumId w:val="100"/></w:num>
  )
}

///|
test "a numbered list gets labels and level indents" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>first</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>second</w:t></w:r></w:p>
      ),
      numbering=list_numbering(),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  // label run precedes the text
  inspect(input.runs[0].text, content="1.\t")
  inspect(input.runs[1].text, content="first")
  // the level's indents apply: 720 twips left, 360 hanging
  inspect(input.style.indent_left_pt, content="36")
  inspect(input.style.indent_first_pt, content="-18")
  guard! doc.blocks[1] is Paragraph(input=second, ..)
  inspect(second.runs[0].text, content="2.\t")
}

///|
test "counters advance across the document, not per paragraph" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>a</w:t></w:r></w:p>
        #|<w:p><w:r><w:t>interrupting body text</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>b</w:t></w:r></w:p>
      ),
      numbering=list_numbering(),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.runs[0].text, content="1.\t")
  // the unnumbered paragraph gets no label
  guard! doc.blocks[1] is Paragraph(input=body, ..)
  inspect(body.runs[0].text, content="interrupting body text")
  // and the list resumes at 2, as Word does
  guard! doc.blocks[2] is Paragraph(input=third, ..)
  inspect(
    third.runs[0].text,
    content=(
      #|2.	
    ),
  )
}

///|
test "a bullet sublevel uses its glyph and deeper indent" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>top</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>sub</w:t></w:r></w:p>
      ),
      numbering=list_numbering(),
    ),
  )
  guard! doc.blocks[1] is Paragraph(input~, ..)
  inspect(
    input.runs[0].text,
    content=(
      #|•	
    ),
  )
  inspect(
    input.style.indent_left_pt,
    content=(
      #|72
    ),
  )
}

///|
test "a paragraph's own indent overrides the level's" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr><w:ind w:left="2880"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
      numbering=list_numbering(),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.style.indent_left_pt, content="144")
}

///|
test "startOverride and lvlOverride reach the label" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
      numbering=(
        #|<w:abstractNum w:abstractNumId="100"><w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum>
        #|<w:num w:numId="2"><w:abstractNumId w:val="100"/><w:lvlOverride w:ilvl="0"><w:startOverride w:val="5"/><w:lvl w:ilvl="0"><w:numFmt w:val="upperLetter"/><w:lvlText w:val="(%1)"/></w:lvl></w:lvlOverride></w:num>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  // upperLetter starting at 5 is "E"
  inspect(
    input.runs[0].text,
    content=(
      #|(E)	
    ),
  )
}

///|
test "w:suff nothing omits the separator" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
      numbering=(
        #|<w:abstractNum w:abstractNumId="100"><w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:suff w:val="nothing"/></w:lvl></w:abstractNum>
        #|<w:num w:numId="1"><w:abstractNumId w:val="100"/></w:num>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(
    input.runs[0].text,
    content=(
      #|1.
    ),
  )
}

///|
test "the label takes the paragraph mark's formatting, not the first run's" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr><w:rPr><w:sz w:val="32"/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="48"/></w:rPr><w:t>bold item</w:t></w:r></w:p>
      ),
      numbering=list_numbering(),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  // the paragraph mark says 16pt regular; the body run's bold 24pt must
  // not bleed into the number
  assert_false(input.runs[0].style.bold)
  inspect(input.runs[0].style.size_pt, content="16")
  assert_true(input.runs[1].style.bold)
}

///|
test "numStyleLink delegates to the definition that declares it" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
      numbering=(
        #|<w:abstractNum w:abstractNumId="100"><w:styleLink w:val="MyList"/><w:lvl w:ilvl="0"><w:numFmt w:val="upperRoman"/><w:lvlText w:val="%1)"/></w:lvl></w:abstractNum>
        #|<w:abstractNum w:abstractNumId="101"><w:numStyleLink w:val="MyList"/></w:abstractNum>
        #|<w:num w:numId="1"><w:abstractNumId w:val="101"/></w:num>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(
    input.runs[0].text,
    content=(
      #|I)	
    ),
  )
}

///|
test "a list renders end to end with the label positioned" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>alpha</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>beta</w:t></w:r></w:p>
      ),
      numbering=list_numbering(),
    ),
  )
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  debug_inspect(model.validate(), content="[]")
  let sb = StringBuilder()
  for item in model.pages[0].items {
    if item is Text(run) {
      sb.write_string(run.text)
      sb.write_string("|")
    }
  }
  inspect(sb.to_string(), content="1.\t|alpha|2.\t|beta|")
  // left indent 36pt with an 18pt hanging indent puts the label at
  // 72 + 36 - 18 = 90, and the text one label-width further right
  guard! model.pages[0].items[0] is Text(first)
  inspect(first.x_pt, content="90")
}

///|
// --- regressions from the list review ---

///|
test "numId 0 cancels numbering instead of fabricating a label" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>numbered</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr></w:pPr><w:r><w:t>not numbered</w:t></w:r></w:p>
      ),
      numbering=list_numbering(),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.runs[0].text, content="1.\t")
  guard! doc.blocks[1] is Paragraph(input=second, ..)
  // no label run at all — the paragraph starts with its own text
  inspect(second.runs[0].text, content="not numbered")
}

///|
test "a style's indent does not suppress the level's nesting" {
  // Word writes every list item as ListParagraph + numPr, and its stock
  // ListParagraph carries w:ind left=720 — which must not flatten the
  // levels to one depth
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>top</w:t></w:r></w:p>
        #|<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="1"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>sub</w:t></w:r></w:p>
      ),
      styles=(
        #|<w:style w:type="paragraph" w:styleId="ListParagraph"><w:pPr><w:ind w:left="720"/></w:pPr></w:style>
      ),
      numbering=list_numbering(),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  guard! doc.blocks[1] is Paragraph(input=sub, ..)
  // level 0 is 720 twips, level 1 is 1440 — they must differ
  inspect(input.style.indent_left_pt, content="36")
  inspect(sub.style.indent_left_pt, content="72")
}

///|
test "a Symbol bullet keeps its own face" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>item</w:t></w:r></w:p>
      ),
      numbering=(
        #|<w:abstractNum w:abstractNumId="100"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/><w:lvlText w:val="\u{F0B7}"/><w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol"/></w:rPr></w:lvl></w:abstractNum>
        #|<w:num w:numId="1"><w:abstractNumId w:val="100"/></w:num>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  // the marker carries the level's font, not the body's
  inspect(input.runs[0].style.family, content="Symbol")
  inspect(input.runs[1].style.family, content="Calibri")
}

///|
test "a bullet level with no lvlText does not leak a placeholder" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
      numbering=(
        #|<w:abstractNum w:abstractNumId="100"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl></w:abstractNum>
        #|<w:num w:numId="1"><w:abstractNumId w:val="100"/></w:num>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  assert_false(input.runs[0].text.contains("%"))
}

///|
test "counters are shared with numbered paragraphs inside table cells" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>before</w:t></w:r></w:p>
        #|<w:tbl><w:tblGrid><w:gridCol w:w="2880"/></w:tblGrid><w:tr><w:tc><w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>in cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>after</w:t></w:r></w:p>
      ),
      numbering=list_numbering(),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.runs[0].text, content="1.\t")
  guard! doc.blocks[1] is TableBlock(table~, ..)
  inspect(table.rows[0].cells[0].content[0].runs[0].text, content="2.\t")
  guard! doc.blocks[2] is Paragraph(input=after, ..)
  inspect(after.runs[0].text, content="3.\t")
}

///|
test "a level's firstLine indent is read when there is no hanging" {
  let doc = @docx.read_docx(
    docx_bytes(
      (
        #|<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>x</w:t></w:r></w:p>
      ),
      numbering=(
        #|<w:abstractNum w:abstractNumId="100"><w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:pPr><w:ind w:left="720" w:firstLine="360"/></w:pPr></w:lvl></w:abstractNum>
        #|<w:num w:numId="1"><w:abstractNumId w:val="100"/></w:num>
      ),
    ),
  )
  guard! doc.blocks[0] is Paragraph(input~, ..)
  inspect(input.style.indent_first_pt, content="18")
}

///|
// --- headers and footers ---

///|
/// A package with a header and footer part wired through _rels, which is
/// how Word actually references them.
fn docx_with_furniture(body : String) -> Bytes raise {
  let archive = @zip.Archive::new()
  let ns =
    #|xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  archive.add(
    "word/document.xml",
    @utf8.encode(
      "<?xml version=\"1.0\"?><w:document " +
      ns +
      "><w:body>" +
      body +
      "</w:body></w:document>",
    ),
  )
  archive.add(
    "word/_rels/document.xml.rels",
    @utf8.encode(
      (
        #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        #|<Relationship Id="rH" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
        #|<Relationship Id="rF" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
        #|</Relationships>
      ),
    ),
  )
  archive.add(
    "word/header1.xml",
    @utf8.encode(
      "<?xml version=\"1.0\"?><w:hdr " +
      ns +
      "><w:p><w:r><w:t>Running header</w:t></w:r></w:p></w:hdr>",
    ),
  )
  archive.add(
    "word/footer1.xml",
    @utf8.encode(
      "<?xml version=\"1.0\"?><w:ftr " +
      ns +
      "><w:p><w:r><w:t>Page footer</w:t></w:r></w:p></w:ftr>",
    ),
  )
  @zip.write(archive)
}

///|
test "header and footer parts resolve through _rels" {
  let doc = @docx.read_docx(
    docx_with_furniture(
      (
        #|<w:p><w:r><w:t>body</w:t></w:r></w:p>
        #|<w:sectPr><w:headerReference w:type="default" r:id="rH"/><w:footerReference w:type="default" r:id="rF"/><w:pgMar w:top="1440" w:bottom="1440" w:left="1440" w:right="1440" w:header="720" w:footer="720"/></w:sectPr>
      ),
    ),
  )
  inspect(doc.furniture.header.length(), content="1")
  inspect(doc.furniture.footer.length(), content="1")
  // w:header/w:footer distances reach the section
  inspect(doc.section.header_pt, content="36")
  inspect(doc.section.footer_pt, content="36")
}

///|
test "furniture is stamped on every page" {
  let doc = @docx.read_docx(
    docx_with_furniture(
      (
        #|<w:p><w:r><w:t>one</w:t></w:r></w:p>
        #|<w:p><w:r><w:br w:type="page"/></w:r><w:r><w:t>two</w:t></w:r></w:p>
        #|<w:sectPr><w:headerReference w:type="default" r:id="rH"/><w:footerReference w:type="default" r:id="rF"/><w:pgMar w:top="1440" w:bottom="1440" w:left="1440" w:right="1440" w:header="720" w:footer="720"/></w:sectPr>
      ),
    ),
  )
  let model = @paginate.paginate(
    doc.blocks,
    section=doc.section,
    furniture=doc.furniture,
  )
  assert_eq(model.pages.length(), 2)
  debug_inspect(model.validate(), content="[]")
  // both pages carry the header and the footer
  for page in model.pages {
    let sb = StringBuilder()
    for item in page.items {
      if item is Text(run) {
        sb.write_string(run.text)
        sb.write_string("|")
      }
    }
    let text = sb.to_string()
    assert_true(text.contains("Running header"))
    assert_true(text.contains("Page footer"))
  }
}

///|
test "the header sits above the body and the footer below it" {
  let doc = @docx.read_docx(
    docx_with_furniture(
      (
        #|<w:p><w:r><w:t>body</w:t></w:r></w:p>
        #|<w:sectPr><w:headerReference w:type="default" r:id="rH"/><w:footerReference w:type="default" r:id="rF"/><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:bottom="1440" w:left="1440" w:right="1440" w:header="720" w:footer="720"/></w:sectPr>
      ),
    ),
  )
  let model = @paginate.paginate(
    doc.blocks,
    section=doc.section,
    furniture=doc.furniture,
  )
  let page = model.pages[0]
  let mut header_y = 0.0
  let mut body_y = 0.0
  let mut footer_y = 0.0
  for item in page.items {
    guard! item is Text(run)
    if run.text.contains("Running header") {
      header_y = run.baseline_pt
    } else if run.text.contains("Page footer") {
      footer_y = run.baseline_pt
    } else {
      body_y = run.baseline_pt
    }
  }
  // header above body above footer, all inside the page
  assert_true(header_y < body_y)
  assert_true(body_y < footer_y)
  assert_true(footer_y < page.height_pt)
  // the footer's baseline sits above the footer margin
  assert_true(footer_y > page.height_pt - doc.section.footer_pt - 40.0)
}

///|
// --- inline images ---

///|
/// A 1x1 PNG, the smallest real image bytes a reader will accept.
fn tiny_png() -> Bytes {
  b"\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90\x77\x53\xde\x00\x00\x00\x0c\x49\x44\x41\x54\x08\xd7\x63\xf8\xcf\xc0\x00\x00\x03\x01\x01\x00\x18\xdd\x8d\xb0\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82"
}

///|
fn docx_with_image(drawing : String) -> Bytes raise {
  let archive = @zip.Archive::new()
  let ns =
    #|xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  archive.add(
    "word/document.xml",
    @utf8.encode(
      "<?xml version=\"1.0\"?><w:document " +
      ns +
      "><w:body><w:p><w:r>" +
      drawing +
      "</w:r></w:p></w:body></w:document>",
    ),
  )
  archive.add(
    "word/_rels/document.xml.rels",
    @utf8.encode(
      (
        #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        #|<Relationship Id="rI" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/pic.png"/>
        #|</Relationships>
      ),
    ),
  )
  archive.add("word/media/pic.png", tiny_png())
  @zip.write(archive)
}

///|
/// An inline drawing 2in wide by 1in tall (EMU: 914400 per inch).
fn inline_drawing() -> String {
  (
    #|<w:drawing><wp:inline><wp:extent cx="1828800" cy="914400"/><a:graphic><a:graphicData><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:blipFill><a:blip r:embed="rI"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>
  )
}

///|
test "an inline drawing becomes an image block at its authored size" {
  let doc = @docx.read_docx(docx_with_image(inline_drawing()))
  json_inspect(doc.unsupported, content=[])
  // paragraph, then the image
  inspect(doc.blocks.length(), content="2")
  guard! doc.blocks[1] is ImageBlock(width_pt~, height_pt~, mime~, ..)
  // 1828800 EMU = 144pt, 914400 = 72pt
  inspect(width_pt, content="144")
  inspect(height_pt, content="72")
  inspect(mime, content="image/png")
}

///|
test "an image renders into the page model and validates" {
  let doc = @docx.read_docx(docx_with_image(inline_drawing()))
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  debug_inspect(model.validate(), content="[]")
  let mut images = 0
  for page in model.pages {
    for item in page.items {
      if item is Image(_) {
        images += 1
      }
    }
  }
  inspect(images, content="1")
}

///|
test "a floating drawing is reported rather than misplaced" {
  let doc = @docx.read_docx(
    docx_with_image(
      // wp:anchor is a floating image: placing it without text wrapping
      // would put it in the wrong place
      (
        #|<w:drawing><wp:anchor><wp:extent cx="914400" cy="914400"/><a:graphic><a:graphicData><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:blipFill><a:blip r:embed="rI"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:anchor></w:drawing>
      ),
    ),
  )
  // one paragraph, no image block
  inspect(doc.blocks.length(), content="1")
}

///|
test "an image too wide for the measure scales down" {
  let doc = @docx.read_docx(
    docx_with_image(
      // 20in wide, far past a Letter measure
      (
        #|<w:drawing><wp:inline><wp:extent cx="18288000" cy="9144000"/><a:graphic><a:graphicData><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:blipFill><a:blip r:embed="rI"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>
      ),
    ),
  )
  let model = @paginate.paginate(doc.blocks, section=doc.section)
  guard! model.pages[0].items[0] is Image(image)
  // scaled to the 468pt content width, aspect ratio kept
  inspect(image.w_pt, content="468")
  inspect(image.h_pt, content="234")
}

///|
// --- fields ---

///|
/// A footer holding a complex PAGE field, with "99" as the value Word
/// cached when the document was last saved.
fn docx_with_page_field(footer_body : String) -> Bytes raise {
  let body =
    #|<w:p><w:r><w:t>one</w:t></w:r></w:p>
    #|<w:p><w:r><w:br w:type="page"/></w:r><w:r><w:t>two</w:t></w:r></w:p>
    #|<w:sectPr><w:footerReference w:type="default" r:id="rF"/><w:pgMar w:top="1440" w:bottom="1440" w:left="1440" w:right="1440" w:header="720" w:footer="720"/></w:sectPr>
  let ns =
    #|xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  let archive = @zip.Archive::new()
  archive.add(
    "word/document.xml",
    @utf8.encode(
      "<?xml version=\"1.0\"?><w:document " +
      ns +
      "><w:body>" +
      body +
      "</w:body></w:document>",
    ),
  )
  archive.add(
    "word/_rels/document.xml.rels",
    @utf8.encode(
      (
        #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        #|<Relationship Id="rF" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
        #|</Relationships>
      ),
    ),
  )
  archive.add(
    "word/footer1.xml",
    @utf8.encode(
      "<?xml version=\"1.0\"?><w:ftr " + ns + ">" + footer_body + "</w:ftr>",
    ),
  )
  @zip.write(archive)
}

///|
test "a complex PAGE field is marked, not taken literally" {
  let doc = @docx.read_docx(
    docx_with_page_field(
      (
        #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>99</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
      ),
    ),
  )
  guard! doc.furniture.footer[0] is Paragraph(input~, ..)
  // the instruction run contributes no text; the result run is a field
  inspect(input.runs.length(), content="1")
  inspect(input.runs[0].text, content="99")
  debug_inspect(input.runs[0].field, content="PageNumber")
}

///|
test "each page's footer shows its own number, not the cached one" {
  let doc = @docx.read_docx(
    docx_with_page_field(
      (
        #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>99</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
      ),
    ),
  )
  let model = @paginate.paginate(
    doc.blocks,
    section=doc.section,
    furniture=doc.furniture,
  )
  assert_eq(model.pages.length(), 2)
  let numbers : Array[String] = []
  for page in model.pages {
    for item in page.items {
      guard! item is Text(run)
      if run.text is ("1" | "2" | "99") {
        numbers.push(run.text)
      }
    }
  }
  json_inspect(numbers, content=["1", "2"])
}

///|
test "NUMPAGES shows the document total on every page" {
  let doc = @docx.read_docx(
    docx_with_page_field(
      (
        #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> NUMPAGES </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>99</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
      ),
    ),
  )
  let model = @paginate.paginate(
    doc.blocks,
    section=doc.section,
    furniture=doc.furniture,
  )
  let totals : Array[String] = []
  for page in model.pages {
    for item in page.items {
      guard! item is Text(run)
      if run.text is ("2" | "99") {
        totals.push(run.text)
      }
    }
  }
  // both pages report a two-page document
  json_inspect(totals, content=["2", "2"])
}

///|
test "a w:fldSimple PAGE field is evaluated too" {
  let doc = @docx.read_docx(
    docx_with_page_field(
      (
        #|<w:p><w:fldSimple w:instr=" PAGE "><w:r><w:t>99</w:t></w:r></w:fldSimple></w:p>
      ),
    ),
  )
  guard! doc.furniture.footer[0] is Paragraph(input~, ..)
  debug_inspect(input.runs[0].field, content="PageNumber")
}

///|
test "a field this engine cannot compute keeps its cached result" {
  let doc = @docx.read_docx(
    docx_with_page_field(
      (
        #|<w:p><w:fldSimple w:instr=" REF _Ref9 \h "><w:r><w:t>see section 4</w:t></w:r></w:fldSimple></w:p>
      ),
    ),
  )
  guard! doc.furniture.footer[0] is Paragraph(input~, ..)
  debug_inspect(input.runs[0].field, content="NotAField")
  inspect(input.runs[0].text, content="see section 4")
}

///|
/// Build a .docx package from a document.xml body and an optional
/// styles.xml, so tests state exactly the XML they exercise.
fn docx_bytes(body : String, styles? : String, theme? : String) -> Bytes raise {
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
test "plain paragraph carries text and Word's defaults" {
  let doc = @docx.read_docx(
    docx_bytes("<w:p><w:r><w:t>Hello</w:t></w:r></w:p>"),
  )
  assert_eq(doc.blocks.length(), 1)
  let run = first_run(doc, 0)
  inspect(run.text, content="Hello")
  inspect(run.style.family, content="Calibri")
  inspect(run.style.size_pt, content="11")
  assert_false(run.style.bold)
  inspect(run.style.color.to_hex(), content="#000000")
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

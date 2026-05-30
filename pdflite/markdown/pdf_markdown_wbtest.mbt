///|
fn markdown_chunk_for_wbtest(
  x : Double,
  y : Double,
  index : Int,
) -> PdfMarkdownTextChunk {
  { x, y, width: 1.0, font_size: 1.0, index, codepoints: [] }
}

///|
fn markdown_fullwidth_chunk_for_wbtest(
  font_size : Double,
) -> PdfMarkdownTextChunk {
  {
    x: 0.0,
    y: 0.0,
    width: font_size,
    font_size,
    index: 0,
    codepoints: [0x4E16],
  }
}

///|
fn markdown_text_chunk_for_wbtest(
  x : Double,
  y : Double,
  width : Double,
  index : Int,
  codepoints : Array[Int],
) -> PdfMarkdownTextChunk {
  { x, y, width, font_size: 10.0, index, codepoints }
}

///|
fn markdown_codepoints_for_wbtest(text : String) -> Array[Int] {
  let output : Array[Int] = []
  for byte in @ascii.encode(text) {
    output.push(byte.to_int())
  }
  output
}

///|
fn markdown_text_cell_for_wbtest(
  x : Double,
  y : Double,
  index : Int,
  text : String,
) -> PdfMarkdownTextChunk {
  markdown_text_chunk_for_wbtest(
    x,
    y,
    1.0,
    index,
    markdown_codepoints_for_wbtest(text),
  )
}

///|
test "private positioned chunk compare orders columns left to right" {
  @test.assert_eq(
    pdf_markdown_positioned_chunk_compare(
      markdown_chunk_for_wbtest(10.0, 100.0, 0),
      markdown_chunk_for_wbtest(20.0, 100.0, 1),
    ),
    -1,
  )
}

///|
test "private positioned chunk compare preserves stream order for equal origins" {
  @test.assert_eq(
    pdf_markdown_positioned_chunk_compare(
      markdown_chunk_for_wbtest(10.0, 100.0, 0),
      markdown_chunk_for_wbtest(10.0, 100.0, 1),
    ),
    -1,
  )
}

///|
test "private positioned text array treats large integer adjustment as space" {
  let chunks : Array[PdfMarkdownTextChunk] = []
  let next_index : Ref[Int] = { val: 0 }
  let extractor = @pdflite.pdf_text_extractor_of_font_real(
    PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding }),
  )
  pdf_markdown_add_positioned_text_array(
    chunks,
    next_index,
    @geometry.transform_identity_matrix,
    @geometry.transform_translate(10.0, 100.0),
    12.0,
    Some(extractor),
    [
      PdfString(@ascii.encode("A")),
      PdfInteger(-300),
      PdfString(@ascii.encode("B")),
    ],
  )
  @test.assert_eq(chunks.length(), 1)
  @test.assert_eq(chunks[0].codepoints, [0x41, 0x20, 0x42])
}

///|
test "private ASCII width estimate leaves room for inferred word gaps" {
  @test.assert_eq(pdf_markdown_estimated_codepoint_width(0x41, 10.0), 3.5)
}

///|
test "private positioned chunks do not add inferred spaces before punctuation" {
  @test.assert_eq(
    pdf_markdown_chunks_to_codepoints([
      markdown_text_chunk_for_wbtest(0.0, 100.0, 1.0, 0, [0x41]),
      markdown_text_chunk_for_wbtest(3.0, 100.0, 1.0, 1, [0x2C]),
      markdown_text_chunk_for_wbtest(5.0, 100.0, 1.0, 2, [0x42]),
    ]),
    [0x41, 0x2C, 0x20, 0x42],
  )
}

///|
test "private positioned chunks emit aligned table runs as Markdown tables" {
  let codepoints = pdf_markdown_chunks_to_codepoints([
    markdown_text_cell_for_wbtest(0.0, 100.0, 0, "Product"),
    markdown_text_cell_for_wbtest(50.0, 100.0, 1, "Expected"),
    markdown_text_cell_for_wbtest(100.0, 100.0, 2, "Actual"),
    markdown_text_cell_for_wbtest(0.0, 90.0, 3, "SKU-1"),
    markdown_text_cell_for_wbtest(50.0, 90.0, 4, "10"),
    markdown_text_cell_for_wbtest(100.0, 90.0, 5, "9"),
  ])
  @test.assert_eq(
    try! pdf_markdown_string_of_codepoints(codepoints),
    "| Product | Expected | Actual |\n| --- | --- | --- |\n| SKU-1 | 10 | 9 |",
  )
}

///|
test "private table detector keeps numbered prose out of Markdown tables" {
  let codepoints = pdf_markdown_chunks_to_codepoints([
    markdown_text_cell_for_wbtest(0.0, 100.0, 0, "2 Conversation programming."),
    markdown_text_cell_for_wbtest(150.0, 100.0, 1, "AutoGen"),
    markdown_text_cell_for_wbtest(220.0, 100.0, 2, "adopts"),
    markdown_text_cell_for_wbtest(
      0.0, 90.0, 3, "plex LLM application workflows",
    ),
    markdown_text_cell_for_wbtest(180.0, 90.0, 4, "as"),
    markdown_text_cell_for_wbtest(220.0, 90.0, 5, "conversations"),
  ])
  let text = try! pdf_markdown_string_of_codepoints(codepoints)
  @test.assert_eq(text.contains("|"), false)
}

///|
test "private table detector keeps prose-sized chunks out of Markdown tables" {
  let codepoints = pdf_markdown_chunks_to_codepoints([
    markdown_text_cell_for_wbtest(
      0.0, 100.0, 0, "This document has been derived directly",
    ),
    markdown_text_cell_for_wbtest(190.0, 100.0, 1, "from the"),
    markdown_text_cell_for_wbtest(240.0, 100.0, 2, "copyright standard"),
    markdown_text_cell_for_wbtest(0.0, 90.0, 3, "the ISO web site at"),
    markdown_text_cell_for_wbtest(150.0, 90.0, 4, "http://example.com"),
    markdown_text_cell_for_wbtest(260.0, 90.0, 5, "for details"),
  ])
  let text = try! pdf_markdown_string_of_codepoints(codepoints)
  @test.assert_eq(text.contains("|"), false)
}

///|
test "private table detector keeps dot leaders out of Markdown tables" {
  let codepoints = pdf_markdown_chunks_to_codepoints([
    markdown_text_cell_for_wbtest(0.0, 100.0, 0, "Foreword . . . . . . . . . ."),
    markdown_text_cell_for_wbtest(220.0, 100.0, 1, "vi"),
    markdown_text_cell_for_wbtest(0.0, 90.0, 2, "Introduction . . . . . . . ."),
    markdown_text_cell_for_wbtest(220.0, 90.0, 3, "vii"),
  ])
  let text = try! pdf_markdown_string_of_codepoints(codepoints)
  @test.assert_eq(text.contains("|"), false)
}

///|
test "private table detector keeps sentence punctuation out of Markdown tables" {
  let codepoints = pdf_markdown_chunks_to_codepoints([
    markdown_text_cell_for_wbtest(0.0, 100.0, 0, "PDF files may be created"),
    markdown_text_cell_for_wbtest(150.0, 100.0, 1, "natively in PDF form,"),
    markdown_text_cell_for_wbtest(280.0, 100.0, 2, "converted from other"),
    markdown_text_cell_for_wbtest(0.0, 90.0, 3, "microform or hard copy"),
    markdown_text_cell_for_wbtest(150.0, 90.0, 4, "archives and other"),
    markdown_text_cell_for_wbtest(280.0, 90.0, 5, "institutions"),
  ])
  let text = try! pdf_markdown_string_of_codepoints(codepoints)
  @test.assert_eq(text.contains("|"), false)
}

///|
test "private table detector rejects body prose with punctuation phrases" {
  @test.assert_eq(
    pdf_markdown_codepoints_have_sentence_punctuation_phrase(
      markdown_codepoints_for_wbtest("Hello, world"),
    ),
    true,
  )
  @test.assert_eq(
    pdf_markdown_line_has_sentence_punctuation_phrase({
      y: 100.0,
      chunks: [markdown_text_cell_for_wbtest(0.0, 100.0, 0, "Hello, world")],
    }),
    true,
  )
  @test.assert_eq(
    pdf_markdown_line_is_table_body_candidate({
      y: 100.0,
      chunks: [markdown_text_cell_for_wbtest(0.0, 100.0, 0, "Hello, world")],
    }),
    false,
  )
}

///|
test "private table detector rejects title dash headings" {
  @test.assert_eq(
    pdf_markdown_line_is_table_header_candidate({
      y: 100.0,
      chunks: [
        markdown_text_chunk_for_wbtest(0.0, 100.0, 1.0, 0, [0x2014]),
        markdown_text_cell_for_wbtest(50.0, 100.0, 1, "Expected"),
        markdown_text_cell_for_wbtest(100.0, 100.0, 2, "Actual"),
      ],
    }),
    false,
  )
}

///|
test "private table detector rejects empty header candidates" {
  @test.assert_eq(
    pdf_markdown_line_is_table_header_candidate({
      y: 100.0,
      chunks: [
        markdown_chunk_for_wbtest(0.0, 100.0, 0),
        markdown_chunk_for_wbtest(50.0, 100.0, 1),
        markdown_chunk_for_wbtest(100.0, 100.0, 2),
      ],
    }),
    false,
  )
}

///|
test "private positioned chunks escape table pipes and merge repeated cells" {
  let codepoints = pdf_markdown_chunks_to_codepoints([
    markdown_text_cell_for_wbtest(0.0, 120.0, 0, "Intro"),
    markdown_text_cell_for_wbtest(0.0, 100.0, 1, "A"),
    markdown_text_cell_for_wbtest(0.0, 100.0, 2, "|B"),
    markdown_text_cell_for_wbtest(50.0, 100.0, 3, "Qty"),
    markdown_text_cell_for_wbtest(100.0, 100.0, 4, "Notes"),
    markdown_text_cell_for_wbtest(0.0, 90.0, 5, "Row"),
    markdown_text_cell_for_wbtest(0.0, 90.0, 6, "one"),
    markdown_text_cell_for_wbtest(50.0, 90.0, 7, "2"),
    markdown_text_cell_for_wbtest(100.0, 90.0, 8, "ok"),
  ])
  @test.assert_eq(
    try! pdf_markdown_string_of_codepoints(codepoints),
    "Intro\n| A \\|B | Qty | Notes |\n| --- | --- | --- |\n| Row one | 2 | ok |",
  )
}

///|
test "private positioned chunks keep lone header-shaped lines regular" {
  let codepoints = pdf_markdown_chunks_to_codepoints([
    markdown_text_cell_for_wbtest(0.0, 120.0, 0, "Intro"),
    markdown_text_cell_for_wbtest(0.0, 100.0, 1, "Name"),
    markdown_text_cell_for_wbtest(50.0, 100.0, 2, "Value"),
    markdown_text_cell_for_wbtest(100.0, 100.0, 3, "Status"),
  ])
  @test.assert_eq(
    try! pdf_markdown_string_of_codepoints(codepoints),
    "Intro\nName Value Status",
  )
}

///|
test "private table detector rejects numeric-dominated total rows" {
  let codepoints = pdf_markdown_chunks_to_codepoints([
    markdown_text_cell_for_wbtest(0.0, 100.0, 0, "Sales Tax"),
    markdown_text_cell_for_wbtest(80.0, 100.0, 1, "10.20%"),
    markdown_text_cell_for_wbtest(140.0, 100.0, 2, "278.46"),
    markdown_text_cell_for_wbtest(0.0, 90.0, 3, "GRAND TOTAL"),
    markdown_text_cell_for_wbtest(140.0, 90.0, 4, "5,738"),
  ])
  let text = try! pdf_markdown_string_of_codepoints(codepoints)
  @test.assert_eq(text.contains("|"), false)
}

///|
test "private Markdown glyph filter keeps notdef non-control fallbacks" {
  let glyph : @pdflite.PdfTextGlyph = {
    glyphname: pdf_markdown_notdef_name(),
    codepoints: [0x41],
  }
  @test.assert_eq(
    pdf_markdown_glyph_has_unreliable_notdef_control(glyph),
    false,
  )
}

///|
test "private fullwidth gap tolerance uses larger neighboring font size" {
  @test.assert_eq(
    pdf_markdown_fullwidth_inline_gap_tolerance(
      markdown_fullwidth_chunk_for_wbtest(12.0),
      markdown_fullwidth_chunk_for_wbtest(10.0),
    ),
    9.600000000000001,
  )
}

///|
test "private fullwidth gap suppression requires a previous chunk" {
  @test.assert_eq(
    pdf_markdown_suppress_fullwidth_inline_gap(
      None,
      markdown_fullwidth_chunk_for_wbtest(10.0),
      1.0,
    ),
    false,
  )
}

///|
test "private TJ spacing joins Han but preserves Hangul word gaps" {
  @test.assert_eq(pdf_markdown_tj_word_space_needed([0x4E16], [0x754C]), false)
  @test.assert_eq(pdf_markdown_tj_word_space_needed([0xD55C], [0xAE00]), true)
}

///|
test "private word-space push ignores empty output" {
  let output : Array[Int] = []
  pdf_markdown_push_word_space(output)
  @test.assert_eq(output, [])
}

///|
fn markdown_wbtest_name(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "private Markdown font cache stores indirect extractors by object number" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    7,
    try! @pdflite.pdf_make_font(
      markdown_wbtest_name("/Helvetica"),
      PdfWinAnsiEncoding,
    ),
  )
  let resources = @syntax.pdf_dictionary([
    (
      markdown_wbtest_name("/Font"),
      @syntax.pdf_dictionary([(markdown_wbtest_name("/F0"), PdfIndirect(7))]),
    ),
  ])
  let cache = pdf_markdown_font_cache()
  let first = try! pdf_markdown_cached_text_extractor(
    cache,
    doc,
    resources,
    markdown_wbtest_name("/F0"),
  )
  guard first is Some(_) else { fail("expected cached extractor") }
  guard cache.values.get(7) is Some(Some(_)) else {
    fail("expected stored indirect extractor")
  }
  let second = try! pdf_markdown_cached_text_extractor(
    cache,
    doc,
    resources,
    markdown_wbtest_name("/F0"),
  )
  guard second is Some(_) else { fail("expected reused cached extractor") }
  @test.assert_eq(cache.values.keys().to_array().length(), 1)
}

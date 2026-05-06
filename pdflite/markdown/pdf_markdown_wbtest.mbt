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
    @pdflite.transform_identity_matrix,
    @pdflite.transform_translate(10.0, 100.0),
    12.0,
    Some(extractor),
    [
      @pdflite.PdfString(@ascii.encode("A")),
      PdfInteger(-300),
      PdfString(@ascii.encode("B")),
    ][:],
  )
  @test.assert_eq(chunks.length(), 1)
  @test.assert_eq(chunks[0].codepoints, [0x41, 0x20, 0x42])
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
  @test.assert_eq(
    pdf_markdown_tj_word_space_needed([0x4E16][:], [0x754C][:]),
    false,
  )
  @test.assert_eq(
    pdf_markdown_tj_word_space_needed([0xD55C][:], [0xAE00][:]),
    true,
  )
}

///|
test "private word-space push ignores empty output" {
  let output : Array[Int] = []
  pdf_markdown_push_word_space(output)
  @test.assert_eq(output, [])
}

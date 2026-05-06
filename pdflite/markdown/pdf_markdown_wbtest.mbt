///|
fn markdown_chunk_for_wbtest(
  x : Double,
  y : Double,
  index : Int,
) -> PdfMarkdownTextChunk {
  { x, y, width: 1.0, index, codepoints: [] }
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
  pdf_markdown_add_positioned_text_array(
    chunks,
    next_index,
    @pdflite.transform_identity_matrix,
    @pdflite.transform_translate(10.0, 100.0),
    12.0,
    None,
    [@pdflite.PdfInteger(-300)][:],
  )
  @test.assert_eq(chunks.length(), 1)
  @test.assert_eq(chunks[0].codepoints.length(), 1)
  @test.assert_eq(chunks[0].codepoints[0], 0x20)
}

///|
/// The writer cannot serialize unknown styles or bookmarks, so their
/// residual paths are exercised directly against the mapping functions
/// (real files from Word carry both; our writer never emits them).
test "inexpressible paragraph content residualizes and text degrades" {
  let residual : Array[DumpResidual] = []
  let params = docx_paragraph_params(
    [
      @document.BookmarkStart("m"),
      @document.run([@document.text("styled away")]),
    ],
    @document.paragraph_properties(
      style_id=Some("FancyQuote"),
      alignment=Some("weird"),
    ),
    3,
    residual,
  )
  // the text is kept, the style/alignment/bookmark are disclosed
  let rendered = Json::object(params).stringify()
  assert_true(rendered.contains("styled away"))
  assert_false(rendered.contains("FancyQuote"))
  assert_false(rendered.contains("weird"))
  let codes = residual.map(entry => entry.code)
  assert_true(codes.contains("docx.paragraph_style_dropped"))
  assert_true(codes.contains("docx.alignment_dropped"))
  assert_true(codes.contains("docx.bookmark_dropped"))
  assert_eq(codes.length(), 3)
}

///|
test "run styles and unserializable text residualize" {
  let residual : Array[DumpResidual] = []
  let styled = docx_run_spec(
    [@document.text("kept")],
    @document.run_properties(style_id=Some("Emphasis")),
    0,
    residual,
  )
  assert_true(styled is Some(_))
  assert_true(
    residual.map(entry => entry.code).contains("docx.run_style_dropped"),
  )
  let bad : Array[DumpResidual] = []
  let dropped = docx_run_spec(
    [@document.text("line\nbreak")],
    @document.run_properties(),
    0,
    bad,
  )
  assert_true(dropped is None)
  assert_true(bad.map(entry => entry.code).contains("docx.text_unserializable"))
}

///|
fn page_marks_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_marks_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn page_marks_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn page_marks_page_for_test(
  ops : ArrayView[@content.PdfContentOp],
  rest? : @syntax.PdfObject = PdfDictionary([]),
) -> @page.PdfPage {
  {
    content: [page_marks_stream_for_test(ops)],
    mediabox: page_marks_rect_for_test(0.0, 0.0, 100.0, 100.0),
    resources: PdfDictionary([]),
    rotate: Rotate0,
    rest,
  }
}

///|
fn page_marks_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  try! (try! @pdflite.pdf_blank_document(100.0, 100.0, pages.length())).change_pages(
    pages,
  )
}

///|
fn page_marks_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
fn page_marks_concat_for_test(
  left : ArrayView[@content.PdfContentOp],
  right : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = []
  for op in left {
    output.push(op)
  }
  for op in right {
    output.push(op)
  }
  output
}

///|
fn page_marks_box_ops_for_test(
  r : Double,
  g : Double,
  b : Double,
  dash : Array[Double],
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Array[@content.PdfContentOp] {
  [
    Op_q,
    Op_RG(r, g, b),
    Op_w(1.0),
    Op_d(dash, 0.0),
    Op_re(x, y, width, height),
    Op_S,
    Op_Q,
  ]
}

///|
fn page_marks_show_boxes_expected_for_test() -> Array[@content.PdfContentOp] {
  let ops : Array[@content.PdfContentOp] = [
    @content.pdf_content_begin_artifact(),
  ]
  for
    op in page_marks_box_ops_for_test(1.0, 0.0, 0.0, [], 0.0, 0.0, 100.0, 100.0) {
    ops.push(op)
  }
  for
    op in page_marks_box_ops_for_test(
      0.0,
      1.0,
      0.0,
      [7.0, 7.0],
      10.0,
      10.0,
      80.0,
      80.0,
    ) {
    ops.push(op)
  }
  for
    op in page_marks_box_ops_for_test(
      0.0,
      0.0,
      1.0,
      [5.0, 5.0],
      20.0,
      20.0,
      60.0,
      60.0,
    ) {
    ops.push(op)
  }
  for
    op in page_marks_box_ops_for_test(
      1.0,
      0.588235294118,
      0.0,
      [3.0, 3.0],
      30.0,
      30.0,
      40.0,
      40.0,
    ) {
    ops.push(op)
  }
  for
    op in page_marks_box_ops_for_test(
      1.0,
      0.0352941176471,
      0.576470588235,
      [2.0, 2.0],
      5.0,
      5.0,
      90.0,
      90.0,
    ) {
    ops.push(op)
  }
  ops.push(@content.pdf_content_end_artifact())
  ops
}

///|
fn page_marks_line_for_test(
  ops : Array[@content.PdfContentOp],
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  ops.push(Op_m(x0, y0))
  ops.push(Op_l(x1, y1))
  ops.push(Op_s)
}

///|
fn page_marks_trim_expected_for_test() -> Array[@content.PdfContentOp] {
  let ops : Array[@content.PdfContentOp] = [
    Op_q,
    Op_K(1.0, 1.0, 1.0, 1.0),
    Op_w(1.0),
    @content.pdf_content_begin_artifact(),
  ]
  page_marks_line_for_test(ops, 0.0, 80.0, 1.0, 80.0)
  page_marks_line_for_test(ops, 10.0, 89.0, 10.0, 100.0)
  page_marks_line_for_test(ops, 99.0, 80.0, 100.0, 80.0)
  page_marks_line_for_test(ops, 90.0, 89.0, 90.0, 100.0)
  page_marks_line_for_test(ops, 99.0, 20.0, 100.0, 20.0)
  page_marks_line_for_test(ops, 90.0, 11.0, 90.0, 0.0)
  page_marks_line_for_test(ops, 1.0, 20.0, 0.0, 20.0)
  page_marks_line_for_test(ops, 10.0, 11.0, 10.0, 0.0)
  ops.push(@content.pdf_content_end_artifact())
  ops.push(Op_Q)
  ops
}

///|
test "PdfDocument show_page_boxes appends cpdf page box outlines" {
  let key_art = page_marks_name_for_test("/ArtBox")
  let key_bleed = page_marks_name_for_test("/BleedBox")
  let key_crop = page_marks_name_for_test("/CropBox")
  let key_trim = page_marks_name_for_test("/TrimBox")
  let document = page_marks_document_for_test([
    page_marks_page_for_test(
      [Op_S],
      rest=PdfDictionary([
        (key_crop, page_marks_rect_for_test(10.0, 10.0, 90.0, 90.0)),
        (key_art, page_marks_rect_for_test(20.0, 20.0, 80.0, 80.0)),
        (key_trim, page_marks_rect_for_test(30.0, 30.0, 70.0, 70.0)),
        (key_bleed, page_marks_rect_for_test(5.0, 5.0, 95.0, 95.0)),
      ]),
    ),
    page_marks_page_for_test([Op_BT]),
  ])
  let marked = try! document.show_page_boxes([1])
  let pages = try! marked.pages_of_pagetree()
  @test.assert_eq(
    page_marks_ops_for_test(marked, pages[0]),
    page_marks_concat_for_test(
      [Op_q, Op_S, Op_Q],
      page_marks_show_boxes_expected_for_test(),
    ),
  )
  @test.assert_eq(page_marks_ops_for_test(marked, pages[1]), [Op_BT])
}

///|
test "PdfDocument trim_marks appends cpdf trim marks and skips missing trim boxes" {
  let key_trim = page_marks_name_for_test("/TrimBox")
  let document = page_marks_document_for_test([
    page_marks_page_for_test(
      [Op_S],
      rest=PdfDictionary([
        (key_trim, page_marks_rect_for_test(10.0, 20.0, 90.0, 80.0)),
      ]),
    ),
    page_marks_page_for_test([Op_BT]),
  ])
  let marked = try! @pdflite.pdf_trim_marks(document, [1, 2])
  let pages = try! marked.pages_of_pagetree()
  @test.assert_eq(
    page_marks_ops_for_test(marked, pages[0]),
    page_marks_concat_for_test(
      [Op_q, Op_S, Op_Q],
      page_marks_trim_expected_for_test(),
    ),
  )
  @test.assert_eq(page_marks_ops_for_test(marked, pages[1]), [Op_BT])
}

///|
test "PdfDocument page mark overlays validate selected pages" {
  let document = page_marks_document_for_test([page_marks_page_for_test([Op_S])])
  let bad_show : Result[@pdflite.PdfDocument, Error] = try? document.show_page_boxes([
      2,
    ],
  )
  guard bad_show
    is Err(
      @core.PdfError::BadPageSpecification(
        "show_page_boxes: range contains pages not present in pdf"
      )
    ) else {
    fail("expected show_page_boxes to reject an out-of-range page")
  }

  let bad_trim : Result[@pdflite.PdfDocument, Error] = try? document.trim_marks([
      2,
    ],
  )
  guard bad_trim
    is Err(
      @core.PdfError::BadPageSpecification(
        "trim_marks: range contains pages not present in pdf"
      )
    ) else {
    fail("expected trim_marks to reject an out-of-range page")
  }
}

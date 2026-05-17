///|
fn page_box_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_box_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn page_box_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn page_box_page_for_test(rest : @pdflite.PdfObject) -> @pdflite.PdfPage {
  {
    content: [page_box_stream_for_test([Op_S])],
    mediabox: page_box_rect_for_test(0.0, 0.0, 100.0, 200.0),
    resources: PdfDictionary([]),
    rotate: Rotate0,
    rest,
  }
}

///|
fn page_box_document_for_test() -> @pdflite.PdfDocument {
  let key_crop = page_box_name_for_test("/CropBox")
  let key_trim = page_box_name_for_test("/TrimBox")
  let first = page_box_page_for_test(
    PdfDictionary([
      (key_crop, page_box_rect_for_test(10.0, 20.0, 90.0, 150.0)),
      (key_trim, page_box_rect_for_test(1.0, 2.0, 3.0, 4.0)),
    ]),
  )
  let second = page_box_page_for_test(
    PdfDictionary([(key_crop, page_box_rect_for_test(30.0, 40.0, 70.0, 80.0))]),
  )
  try! (try! @pdflite.pdf_blank_document(100.0, 200.0, 2)).change_pages([
    first, second,
  ])
}

///|
fn page_box_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "PdfDocument hard_box prepends crop clipping operators" {
  let document = page_box_document_for_test()
  let clipped = try! document.hard_box([1], page_box_name_for_test("/CropBox"))
  let pages = try! clipped.pages_of_pagetree()
  @test.assert_eq(page_box_ops_for_test(clipped, pages[0]), [
    Op_re(10.0, 20.0, 80.0, 130.0),
    Op_W,
    Op_n,
    Op_S,
  ])
  @test.assert_eq(page_box_ops_for_test(clipped, pages[1]), [Op_S])

  let clipped_fast = try! @pdflite.pdf_hard_box(
    document,
    [1],
    page_box_name_for_test("/CropBox"),
    fast=true,
  )
  let fast_pages = try! clipped_fast.pages_of_pagetree()
  @test.assert_eq(fast_pages[0].content.length(), 2)
  @test.assert_eq(page_box_ops_for_test(clipped_fast, fast_pages[0]), [
    Op_re(10.0, 20.0, 80.0, 130.0),
    Op_W,
    Op_n,
    Op_S,
  ])
}

///|
test "PdfDocument hard_box handles missing boxes like cpdf" {
  let document = page_box_document_for_test()
  let missing : Result[@pdflite.PdfDocument, Error] = try? document.hard_box(
    [2],
    page_box_name_for_test("/TrimBox"),
  )
  guard missing
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "hard_box: box /TrimBox not found"
      )
    ) else {
    fail("expected hard_box to reject a missing selected box")
  }

  let fallback = try! document.hard_box(
    [2],
    page_box_name_for_test("/TrimBox"),
    mediabox_if_missing=true,
  )
  let pages = try! fallback.pages_of_pagetree()
  @test.assert_eq(page_box_ops_for_test(fallback, pages[1]), [
    Op_re(0.0, 0.0, 100.0, 200.0),
    Op_W,
    Op_n,
    Op_S,
  ])
}

///|
test "PdfDocument remove page boxes affects only selected box and pages" {
  let document = page_box_document_for_test()
  let key_crop = page_box_name_for_test("/CropBox")
  let key_trim = page_box_name_for_test("/TrimBox")
  let removed = try! document.remove_cropping([1])
  let pages = try! removed.pages_of_pagetree()
  @test.assert_eq(pages[0].rest.lookup_immediate(key_crop), None)
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_trim),
    Some(page_box_rect_for_test(1.0, 2.0, 3.0, 4.0)),
  )
  @test.assert_eq(
    pages[1].rest.lookup_immediate(key_crop),
    Some(page_box_rect_for_test(30.0, 40.0, 70.0, 80.0)),
  )

  let no_trim = try! @pdflite.pdf_remove_trim_pdf(removed, [1])
  let no_trim_pages = try! no_trim.pages_of_pagetree()
  @test.assert_eq(no_trim_pages[0].rest.lookup_immediate(key_trim), None)
}

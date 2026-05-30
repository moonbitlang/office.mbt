///|
fn chop_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn chop_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn chop_page_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @page.PdfPage {
  @page.pdf_page_custom(chop_rect_for_test(min_x, min_y, max_x, max_y))
}

///|
fn chop_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  let document = @pdflite.pdf_document_empty()
  let page_root = try! document.add_pagetree(pages)
  ignore(try! document.add_root(page_root, []))
  document
}

///|
fn chop_mediaboxes_for_test(
  document : @pdflite.PdfDocument,
) -> Array[@syntax.PdfObject] {
  let pages = try! document.pages_of_pagetree()
  [
    for page in pages => page.mediabox
  ]
}

///|
test "PdfDocument chop splits selected page by cropbox and erases page boxes" {
  let keep_key = chop_name_for_test("/Keep")
  let page = {
    ..chop_page_for_test(0.0, 0.0, 300.0, 300.0),
    rest: PdfDictionary([
      (
        chop_name_for_test("/CropBox"),
        chop_rect_for_test(10.0, 20.0, 110.0, 220.0),
      ),
      (chop_name_for_test("/BleedBox"), chop_rect_for_test(1.0, 2.0, 3.0, 4.0)),
      (chop_name_for_test("/TrimBox"), chop_rect_for_test(1.0, 2.0, 3.0, 4.0)),
      (chop_name_for_test("/ArtBox"), chop_rect_for_test(1.0, 2.0, 3.0, 4.0)),
      (chop_name_for_test("/Annots"), PdfArray([PdfInteger(1)])),
      (keep_key, PdfInteger(7)),
    ]),
  }
  let chopped = try! chop_document_for_test([page]).chop(
    2,
    2,
    false,
    false,
    false,
    [1],
  )
  @test.assert_eq(chop_mediaboxes_for_test(chopped), [
    chop_rect_for_test(10.0, 120.0, 60.0, 220.0),
    chop_rect_for_test(60.0, 120.0, 110.0, 220.0),
    chop_rect_for_test(10.0, 20.0, 60.0, 120.0),
    chop_rect_for_test(60.0, 20.0, 110.0, 120.0),
  ])
  let pages = try! chopped.pages_of_pagetree()
  @test.assert_eq(pages[0].rest, PdfDictionary([(keep_key, PdfInteger(7))]))
}

///|
test "PdfDocument chop respects column bottom-to-top right-to-left order" {
  let page = chop_page_for_test(0.0, 0.0, 100.0, 100.0)
  let chopped = try! chop_document_for_test([page]).chop(
    2,
    2,
    true,
    true,
    true,
    [1],
  )
  @test.assert_eq(chop_mediaboxes_for_test(chopped), [
    chop_rect_for_test(50.0, 0.0, 100.0, 50.0),
    chop_rect_for_test(50.0, 50.0, 100.0, 100.0),
    chop_rect_for_test(0.0, 0.0, 50.0, 50.0),
    chop_rect_for_test(0.0, 50.0, 50.0, 100.0),
  ])
}

///|
test "PdfDocument chop_hv splits horizontally and vertically" {
  let page = chop_page_for_test(0.0, 0.0, 100.0, 100.0)
  let horizontal = try! chop_document_for_test([page]).chop_hv(
    true,
    40.0,
    false,
    [1],
  )
  @test.assert_eq(chop_mediaboxes_for_test(horizontal), [
    chop_rect_for_test(0.0, 40.0, 100.0, 100.0),
    chop_rect_for_test(0.0, 0.0, 100.0, 40.0),
  ])
  let vertical = try! @pdflite.pdf_chop_hv(
    chop_document_for_test([page]),
    false,
    30.0,
    true,
    [1],
  )
  @test.assert_eq(chop_mediaboxes_for_test(vertical), [
    chop_rect_for_test(30.0, 0.0, 100.0, 100.0),
    chop_rect_for_test(0.0, 0.0, 30.0, 100.0),
  ])
  let source_order = try! @pdflite.pdf_chop_hv_cpdf_order(
    false,
    30.0,
    true,
    chop_document_for_test([page]),
    [1],
  )
  @test.assert_eq(chop_mediaboxes_for_test(source_order), [
    chop_rect_for_test(30.0, 0.0, 100.0, 100.0),
    chop_rect_for_test(0.0, 0.0, 30.0, 100.0),
  ])
}

///|
test "pdf_chop wrapper keeps unselected pages unchanged" {
  let first = chop_page_for_test(0.0, 0.0, 10.0, 10.0)
  let second = chop_page_for_test(0.0, 0.0, 20.0, 10.0)
  let document = chop_document_for_test([first, second])
  let chopped = try! @pdflite.pdf_chop(document, 2, 1, false, false, false, [2])
  let source_order = try! @pdflite.pdf_chop_cpdf_order(
    2,
    1,
    false,
    false,
    false,
    document,
    [2],
  )
  @test.assert_eq(chop_mediaboxes_for_test(chopped), [
    chop_rect_for_test(0.0, 0.0, 10.0, 10.0),
    chop_rect_for_test(0.0, 0.0, 10.0, 10.0),
    chop_rect_for_test(10.0, 0.0, 20.0, 10.0),
  ])
  @test.assert_eq(
    chop_mediaboxes_for_test(source_order),
    chop_mediaboxes_for_test(chopped),
  )
  @test.assert_eq(chop_mediaboxes_for_test(document), [
    chop_rect_for_test(0.0, 0.0, 10.0, 10.0),
    chop_rect_for_test(0.0, 0.0, 20.0, 10.0),
  ])
}

///|
test "PdfDocument chop validates grid and page range" {
  let document = chop_document_for_test([
    chop_page_for_test(0.0, 0.0, 10.0, 10.0),
  ])
  let bad_grid : Result[@pdflite.PdfDocument, Error] = try? document.chop(
    0,
    2,
    false,
    false,
    false,
    [1],
  )
  guard bad_grid
    is Err(@core.PdfError::BadNumberArgument("chop: x and y must be positive")) else {
    fail("expected bad chop grid")
  }
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.chop_hv(
    false,
    5.0,
    false,
    [2],
  )
  guard bad_page
    is Err(
      @core.PdfError::BadPageSpecification(
        "chop_v: range contains pages not present in pdf"
      )
    ) else {
    fail("expected bad chop page range")
  }
}

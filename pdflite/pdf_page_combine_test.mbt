///|
fn combine_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn combine_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn combine_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn combine_font_resources_for_test(name : String) -> @syntax.PdfObject {
  PdfDictionary([
    (
      combine_name_for_test("/Font"),
      PdfDictionary([(combine_name_for_test(name), PdfDictionary([]))]),
    ),
  ])
}

///|
fn combine_page_for_test(
  ops : ArrayView[@content.PdfContentOp],
  resources? : @syntax.PdfObject = PdfDictionary([]),
  width? : Double = 100.0,
  height? : Double = 100.0,
) -> @page.PdfPage {
  {
    content: [combine_stream_for_test(ops)],
    mediabox: combine_rect_for_test(0.0, 0.0, width, height),
    resources,
    rotate: Rotate0,
    rest: PdfDictionary([]),
  }
}

///|
fn combine_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  try! (try! @pdflite.pdf_blank_document(100.0, 100.0, pages.length())).change_pages(
    pages,
  )
}

///|
fn combine_content_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "PdfDocument combine_pages overlays paired pages and truncates extra overlay pages" {
  let key_font = combine_name_for_test("/Font")
  let under = combine_document_for_test([
    combine_page_for_test(
      [Op_S],
      resources=combine_font_resources_for_test("/F0"),
    ),
    combine_page_for_test([Op_BT, Op_ET]),
  ])
  let overlay = combine_document_for_test([
    combine_page_for_test(
      [Op_Tf(combine_name_for_test("/StampA"), 12.0)],
      resources=combine_font_resources_for_test("/StampA"),
    ),
    combine_page_for_test(
      [Op_Tf(combine_name_for_test("/StampB"), 8.0)],
      resources=combine_font_resources_for_test("/StampB"),
    ),
    combine_page_for_test(
      [Op_Tf(combine_name_for_test("/Drop"), 1.0)],
      resources=combine_font_resources_for_test("/Drop"),
    ),
  ])
  let combined = try under.combine_pages(overlay) catch {
    error => fail(ToJson::to_json(error).stringify())
  } noraise {
    combined => combined
  }
  let pages = try! combined.pages_of_pagetree()

  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(combine_content_ops_for_test(combined, pages[0]), [
    Op_q,
    Op_S,
    Op_Q,
    Op_q,
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_Tf(combine_name_for_test("/aStampA"), 12.0),
    Op_Q,
  ])
  @test.assert_eq(combine_content_ops_for_test(combined, pages[1]), [
    Op_q,
    Op_BT,
    Op_ET,
    Op_Q,
    Op_q,
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_Tf(combine_name_for_test("/aStampB"), 8.0),
    Op_Q,
  ])
  guard pages[0].resources.lookup_immediate(key_font)
    is Some(PdfDictionary(first_fonts)) else {
    fail("expected first page font resources")
  }
  @test.assert_eq(first_fonts[0].0, combine_name_for_test("/F0"))
  @test.assert_eq(first_fonts[1].0, combine_name_for_test("/aStampA"))
  guard pages[1].resources.lookup_immediate(key_font)
    is Some(PdfDictionary(second_fonts)) else {
    fail("expected second page font resources")
  }
  @test.assert_eq(second_fonts[0].0, combine_name_for_test("/aStampB"))
}

///|
test "pdf_combine_pages can put a padded overlay under base pages" {
  let under = combine_document_for_test([
    combine_page_for_test([Op_m(1.0, 2.0), Op_S]),
    combine_page_for_test([Op_l(3.0, 4.0), Op_S]),
  ])
  let overlay = combine_document_for_test([
    combine_page_for_test([Op_g(0.5)], width=10.0, height=10.0),
  ])
  let combined = try
    @pdflite.pdf_combine_pages(under, overlay, overlay_is_under=true)
  catch {
    error => fail(ToJson::to_json(error).stringify())
  } noraise {
    combined => combined
  }
  let pages = try! combined.pages_of_pagetree()

  @test.assert_eq(combine_content_ops_for_test(combined, pages[0]), [
    Op_q,
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_g(0.5),
    Op_Q,
    Op_q,
    Op_m(1.0, 2.0),
    Op_S,
    Op_Q,
  ])
  @test.assert_eq(combine_content_ops_for_test(combined, pages[1]), [
    Op_q,
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_Q,
    Op_q,
    Op_l(3.0, 4.0),
    Op_S,
    Op_Q,
  ])
  let cpdf_combined = try! @pdflite.pdf_combine_pages_cpdf_order(
    false, false, under, overlay, false, true,
  )
  let cpdf_pages = try! cpdf_combined.pages_of_pagetree()
  @test.assert_eq(
    combine_content_ops_for_test(cpdf_combined, cpdf_pages[0]),
    combine_content_ops_for_test(combined, pages[0]),
  )
  @test.assert_eq(
    combine_content_ops_for_test(cpdf_combined, cpdf_pages[1]),
    combine_content_ops_for_test(combined, pages[1]),
  )
}

///|
test "PdfDocument combine_pages scale_to_fit centers each overlay page" {
  let under = combine_document_for_test([
    combine_page_for_test([Op_S], width=100.0, height=100.0),
  ])
  let overlay = combine_document_for_test([
    combine_page_for_test([Op_g(0.25)], width=20.0, height=10.0),
  ])
  let combined = try under.combine_pages(overlay, scale_to_fit=true) catch {
    error => fail(ToJson::to_json(error).stringify())
  } noraise {
    combined => combined
  }
  let pages = try! combined.pages_of_pagetree()
  let expected_matrix = @geometry.transform_matrix_compose(
    @geometry.transform_translate(0.0, 25.0),
    @geometry.transform_scale(@geometry.point2(0.0, 0.0), 5.0, 5.0),
  )

  @test.assert_eq(combine_content_ops_for_test(combined, pages[0]), [
    Op_q,
    Op_S,
    Op_Q,
    Op_q,
    Op_cm(expected_matrix),
    Op_g(0.25),
    Op_Q,
  ])
}

///|
test "PdfDocument combine_pages retargets under and overlay bookmarks" {
  let under = combine_document_for_test([
    combine_page_for_test([Op_S]),
    combine_page_for_test([Op_s]),
  ])
  let under_refs = try! under.page_reference_numbers()
  let under = try! under.add_bookmarks([
    {
      level: 0,
      text: b"under second",
      target: DestFit(TargetPageObject(under_refs[1])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let overlay = combine_document_for_test([
    combine_page_for_test([Op_g(0.5)]),
    combine_page_for_test([Op_G(0.25)]),
  ])
  let overlay_refs = try! overlay.page_reference_numbers()
  let overlay = try! overlay.add_bookmarks([
    {
      level: 0,
      text: b"overlay first",
      target: DestFit(TargetPageObject(overlay_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let combined = try! under.combine_pages(overlay)
  let final_refs = try! combined.page_reference_numbers()

  @test.assert_eq(try! combined.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: b"under second",
      target: DestFit(TargetPageObject(final_refs[1])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: b"overlay first",
      target: DestFit(TargetPageObject(final_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

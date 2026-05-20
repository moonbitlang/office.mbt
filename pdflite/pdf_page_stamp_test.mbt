///|
fn stamp_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn stamp_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn stamp_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn stamp_page_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  resources? : @pdflite.PdfObject = PdfDictionary([]),
  rest? : @pdflite.PdfObject = PdfDictionary([]),
  width? : Double = 100.0,
  height? : Double = 100.0,
) -> @pdflite.PdfPage {
  {
    content: [stamp_stream_for_test(ops)],
    mediabox: stamp_rect_for_test(0.0, 0.0, width, height),
    resources,
    rotate: Rotate0,
    rest,
  }
}

///|
fn stamp_document_for_test(
  pages : ArrayView[@pdflite.PdfPage],
) -> @pdflite.PdfDocument {
  try! (try! @pdflite.pdf_blank_document(100.0, 100.0, pages.length())).change_pages(
    pages,
  )
}

///|
fn stamp_content_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
fn stamp_overlay_document_for_test() -> @pdflite.PdfDocument {
  let key_font = stamp_name_for_test("/Font")
  stamp_document_for_test([
    stamp_page_for_test(
      [Op_Tf(stamp_name_for_test("/StampFont"), 12.0)],
      resources=PdfDictionary([
        (
          key_font,
          PdfDictionary([(stamp_name_for_test("/StampFont"), PdfDictionary([]))]),
        ),
      ]),
      width=20.0,
      height=10.0,
    ),
    stamp_page_for_test([Op_BT, Op_ET], width=200.0, height=200.0),
  ])
}

///|
test "PdfDocument stamp_pages overlays selected pages with prefixed resources and annotations" {
  let key_annots = stamp_name_for_test("/Annots")
  let key_font = stamp_name_for_test("/Font")
  let key_rect = stamp_name_for_test("/Rect")
  let base_annotation : @pdflite.PdfObject = PdfDictionary([
    (key_rect, stamp_rect_for_test(1.0, 1.0, 2.0, 2.0)),
  ])
  let overlay_annotation : @pdflite.PdfObject = PdfDictionary([
    (key_rect, stamp_rect_for_test(0.0, 0.0, 5.0, 5.0)),
  ])
  let base = stamp_document_for_test([
    stamp_page_for_test(
      [Op_m(1.0, 2.0), Op_l(3.0, 4.0), Op_S],
      resources=PdfDictionary([
        (
          key_font,
          PdfDictionary([(stamp_name_for_test("/F0"), PdfDictionary([]))]),
        ),
      ]),
      rest=PdfDictionary([(key_annots, PdfArray([base_annotation]))]),
      width=100.0,
      height=50.0,
    ),
    stamp_page_for_test([Op_BT, Op_ET], width=100.0, height=50.0),
  ])
  let overlay = stamp_document_for_test([
    stamp_page_for_test(
      [Op_Tf(stamp_name_for_test("/StampFont"), 12.0)],
      resources=PdfDictionary([
        (
          key_font,
          PdfDictionary([(stamp_name_for_test("/StampFont"), PdfDictionary([]))]),
        ),
      ]),
      rest=PdfDictionary([(key_annots, PdfArray([overlay_annotation]))]),
      width=20.0,
      height=10.0,
    ),
  ])

  let stamped = try
    base.stamp_pages([1], overlay, position=PdfPositionBottomLeft(10.0, 20.0))
  catch {
    error => fail(error.to_json().stringify())
  } noraise {
    stamped => stamped
  }
  let pages = try! stamped.pages_of_pagetree()

  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(stamp_content_ops_for_test(stamped, pages[0]), [
    Op_q,
    Op_m(1.0, 2.0),
    Op_l(3.0, 4.0),
    Op_S,
    Op_Q,
    Op_q,
    Op_cm(@pdflite.transform_translate(10.0, 20.0)),
    Op_Tf(stamp_name_for_test("/aStampFont"), 12.0),
    Op_Q,
  ])
  guard pages[0].resources.lookup_immediate(key_font)
    is Some(PdfDictionary(resources)) else {
    fail("expected stamped font resources")
  }
  @test.assert_eq(resources[0].0, stamp_name_for_test("/F0"))
  @test.assert_eq(resources[1].0, stamp_name_for_test("/aStampFont"))
  @test.assert_eq(pages[1].resources.lookup_immediate(key_font), None)
  guard pages[0].rest.lookup_immediate(key_annots)
    is Some(PdfArray(annotations)) else {
    fail("expected combined annotations")
  }
  @test.assert_eq(annotations.length(), 2)
  @test.assert_eq(
    annotations[0].lookup_immediate(key_rect),
    Some(stamp_rect_for_test(1.0, 1.0, 2.0, 2.0)),
  )
  @test.assert_eq(
    annotations[1].lookup_immediate(key_rect),
    Some(stamp_rect_for_test(10.0, 20.0, 15.0, 25.0)),
  )
}

///|
test "pdf_stamp can place overlay content under the base content" {
  let base = stamp_document_for_test([
    stamp_page_for_test([Op_m(1.0, 2.0), Op_l(3.0, 4.0), Op_S]),
  ])
  let stamped = try
    @pdflite.pdf_stamp(
      base,
      [1],
      stamp_overlay_document_for_test(),
      position=PdfPositionBottomLeft(5.0, 6.0),
      is_over=false,
    )
  catch {
    error => fail(error.to_json().stringify())
  } noraise {
    stamped => stamped
  }
  let pages = try! stamped.pages_of_pagetree()

  @test.assert_eq(stamp_content_ops_for_test(stamped, pages[0]), [
    Op_q,
    Op_cm(@pdflite.transform_translate(5.0, 6.0)),
    Op_Tf(stamp_name_for_test("/aStampFont"), 12.0),
    Op_Q,
    Op_q,
    Op_m(1.0, 2.0),
    Op_l(3.0, 4.0),
    Op_S,
    Op_Q,
  ])
}

///|
test "PdfDocument stamp_pages scale_to_fit centers the first overlay page" {
  let base = stamp_document_for_test([
    stamp_page_for_test([Op_S], width=100.0, height=100.0),
  ])
  let stamped = try
    base.stamp_pages([1], stamp_overlay_document_for_test(), scale_to_fit=true)
  catch {
    error => fail(error.to_json().stringify())
  } noraise {
    stamped => stamped
  }
  let pages = try! stamped.pages_of_pagetree()
  let expected_matrix = @pdflite.transform_matrix_compose(
    @pdflite.transform_translate(0.0, 25.0),
    @pdflite.transform_scale(@pdflite.point2(0.0, 0.0), 5.0, 5.0),
  )

  @test.assert_eq(stamp_content_ops_for_test(stamped, pages[0]), [
    Op_q,
    Op_S,
    Op_Q,
    Op_q,
    Op_cm(expected_matrix),
    Op_Tf(stamp_name_for_test("/aStampFont"), 12.0),
    Op_Q,
  ])
}

///|
test "PdfDocument stamp_pages can mark processed overlay content as artifact" {
  let base = stamp_document_for_test([stamp_page_for_test([Op_S])])
  let overlay = stamp_document_for_test([
    stamp_page_for_test(
      [Op_BMC(stamp_name_for_test("/Span")), Op_m(2.0, 3.0), Op_EMC],
      width=20.0,
      height=10.0,
    ),
  ])
  let stamped = try
    base.stamp_pages([1], overlay, process_struct_tree=true)
  catch {
    error => fail(error.to_json().stringify())
  } noraise {
    stamped => stamped
  }
  let pages = try! stamped.pages_of_pagetree()

  @test.assert_eq(stamp_content_ops_for_test(stamped, pages[0]), [
    Op_q,
    Op_S,
    Op_Q,
    Op_q,
    Op_cm(@pdflite.transform_translate(0.0, 0.0)),
    Op_BMC(stamp_name_for_test("/Artifact")),
    Op_m(2.0, 3.0),
    Op_EMC,
    Op_Q,
  ])
}

///|
test "PdfDocument stamp_pages rejects invalid page ranges and empty overlays" {
  let base = stamp_document_for_test([stamp_page_for_test([Op_S])])
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? base.stamp_pages(
    [2],
    stamp_overlay_document_for_test(),
  )
  guard bad_page
    is Err(
      PdfError::BadPageSpecification(
        "stamp_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected stamp_pages to reject invalid pages")
  }
  let empty_overlay : Result[@pdflite.PdfDocument, Error] = try? base.stamp_pages(
    [1],
    @pdflite.pdf_document_empty(),
  )
  guard empty_overlay is Err(_) else {
    fail("expected stamp_pages to reject an empty overlay")
  }
}

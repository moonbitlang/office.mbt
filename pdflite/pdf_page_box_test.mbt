///|
fn page_box_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_box_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn page_box_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn page_box_page_for_test(rest : @syntax.PdfObject) -> @page.PdfPage {
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
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
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

  let clipped_string = try! @pdflite.pdf_hard_box_string(
    document,
    [1],
    "/CropBox",
  )
  let string_pages = try! clipped_string.pages_of_pagetree()
  @test.assert_eq(page_box_ops_for_test(clipped_string, string_pages[0]), [
    Op_re(10.0, 20.0, 80.0, 130.0),
    Op_W,
    Op_n,
    Op_S,
  ])
}

///|
test "PdfDocument hard_box handles missing boxes like cpdf" {
  let document = page_box_document_for_test()
  let missing : Result[@pdflite.PdfDocument, Error] = try
    document.hard_box([2], page_box_name_for_test("/TrimBox"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing
    is Err(
      @core.PdfError::BadPageSpecification("hard_box: box /TrimBox not found")
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
test "PdfDocument has_page_box mirrors cpdf hasbox" {
  let document = page_box_document_for_test()
  let key_crop = page_box_name_for_test("/CropBox")
  let key_trim = page_box_name_for_test("/TrimBox")
  let key_media = page_box_name_for_test("/MediaBox")

  @test.assert_eq(try! document.has_page_box(1, key_crop), true)
  @test.assert_eq(try! @pdflite.pdf_hasbox(document, 2, key_trim), false)
  @test.assert_eq(try! document.hasbox_string(1, "/CropBox"), true)
  @test.assert_eq(
    try! @pdflite.pdf_hasbox_string(document, 2, "/TrimBox"),
    false,
  )
  @test.assert_eq(try! document.has_page_box(1, key_media), false)

  let bad_page : Result[Bool, Error] = try
    document.has_page_box(3, key_crop)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page
    is Err(@core.PdfError::BadPageSpecification("hasbox: bad page")) else {
    fail("expected hasbox to reject an invalid page")
  }
}

///|
test "PdfDocument copy_page_box copies selected boxes and wrappers" {
  let document = page_box_document_for_test()
  let key_crop = page_box_name_for_test("/CropBox")
  let key_media = page_box_name_for_test("/MediaBox")
  let key_trim = page_box_name_for_test("/TrimBox")
  let copied = try! document.copy_page_box([1], key_crop, key_media)
  let pages = try! copied.pages_of_pagetree()
  @test.assert_eq(try! copied.parse_rectangle(pages[0].mediabox), {
    min_x: 10.0,
    min_y: 20.0,
    max_x: 90.0,
    max_y: 150.0,
  })
  @test.assert_eq(try! copied.parse_rectangle(pages[1].mediabox), {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 100.0,
    max_y: 200.0,
  })

  let copied_media = try! @pdflite.pdf_copy_page_box(
    document,
    [2],
    key_media,
    key_trim,
  )
  let media_pages = try! copied_media.pages_of_pagetree()
  @test.assert_eq(
    media_pages[1].rest.lookup_immediate(key_trim),
    Some(page_box_rect_for_test(0.0, 0.0, 100.0, 200.0)),
  )

  let copied_string = try! @pdflite.pdf_copy_box(
    "/CropBox",
    "/MediaBox",
    false,
    document,
    [1],
  )
  let string_pages = try! copied_string.pages_of_pagetree()
  @test.assert_eq(
    try! copied_string.parse_rectangle(string_pages[0].mediabox),
    { min_x: 10.0, min_y: 20.0, max_x: 90.0, max_y: 150.0 },
  )
}

///|
test "PdfDocument copy_page_box handles missing sources like cpdf" {
  let document = page_box_document_for_test()
  let key_trim = page_box_name_for_test("/TrimBox")
  let key_bleed = page_box_name_for_test("/BleedBox")
  let unchanged = try! document.copy_page_box([2], key_trim, key_bleed)
  let unchanged_pages = try! unchanged.pages_of_pagetree()
  @test.assert_eq(unchanged_pages[1].rest.lookup_immediate(key_bleed), None)

  let fallback = try! document.copy_page_box(
    [2],
    key_trim,
    key_bleed,
    mediabox_if_missing=true,
  )
  let fallback_pages = try! fallback.pages_of_pagetree()
  @test.assert_eq(
    fallback_pages[1].rest.lookup_immediate(key_bleed),
    Some(page_box_rect_for_test(0.0, 0.0, 100.0, 200.0)),
  )

  let fallback_string = try! document.copy_box(
    [2],
    "/TrimBox",
    "/BleedBox",
    mediabox_if_missing=true,
  )
  let fallback_string_pages = try! fallback_string.pages_of_pagetree()
  @test.assert_eq(
    fallback_string_pages[1].rest.lookup_immediate(key_bleed),
    Some(page_box_rect_for_test(0.0, 0.0, 100.0, 200.0)),
  )

  let bad_page : Result[@pdflite.PdfDocument, Error] = try
    document.copy_page_box([3], key_trim, key_bleed)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page
    is Err(
      @core.PdfError::BadPageSpecification(
        "copy_page_box: range contains pages not present in pdf"
      )
    ) else {
    fail("expected copy_page_box to reject an out-of-range page")
  }
}

///|
test "PdfDocument change_boxes transforms media and known page boxes" {
  let document = page_box_document_for_test()
  let key_crop = page_box_name_for_test("/CropBox")
  let key_trim = page_box_name_for_test("/TrimBox")
  let pages = try! document.pages_of_pagetree()
  let changed = try! document.change_boxes(pages[0], (
    min_x,
    min_y,
    max_x,
    max_y,
  ) => (min_x + 1.0, min_y + 2.0, max_x + 3.0, max_y + 4.0))
  @test.assert_eq(try! document.parse_rectangle(changed.mediabox), {
    min_x: 1.0,
    min_y: 2.0,
    max_x: 103.0,
    max_y: 204.0,
  })
  @test.assert_eq(
    changed.rest.lookup_immediate(key_crop),
    Some(page_box_rect_for_test(11.0, 22.0, 93.0, 154.0)),
  )
  @test.assert_eq(
    changed.rest.lookup_immediate(key_trim),
    Some(page_box_rect_for_test(2.0, 4.0, 6.0, 8.0)),
  )

  let wrapped = try! @pdflite.pdf_change_boxes(document, pages[1], (
    min_x,
    min_y,
    max_x,
    max_y,
  ) => (min_x - 1.0, min_y - 1.0, max_x - 1.0, max_y - 1.0))
  @test.assert_eq(try! document.parse_rectangle(wrapped.mediabox), {
    min_x: -1.0,
    min_y: -1.0,
    max_x: 99.0,
    max_y: 199.0,
  })

  let source_order = try! @pdflite.pdf_change_boxes_cpdf_order(
    (min_x, min_y, max_x, max_y) => {
      (min_x + 10.0, min_y + 20.0, max_x + 30.0, max_y + 40.0)
    },
    document,
    pages[0],
  )
  @test.assert_eq(try! document.parse_rectangle(source_order.mediabox), {
    min_x: 10.0,
    min_y: 20.0,
    max_x: 130.0,
    max_y: 240.0,
  })
}

///|
test "PdfDocument rectify_boxes zeroes media origin and shifts content" {
  let document = page_box_document_for_test()
  let key_crop = page_box_name_for_test("/CropBox")
  let page = page_box_page_for_test(
    PdfDictionary([(key_crop, page_box_rect_for_test(20.0, 30.0, 80.0, 90.0))]),
  )
  let page = {
    ..page,
    mediabox: page_box_rect_for_test(10.0, 20.0, 110.0, 120.0),
  }
  let rectified = try! document.rectify_boxes(page)
  @test.assert_eq(try! document.parse_rectangle(rectified.mediabox), {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 100.0,
    max_y: 100.0,
  })
  @test.assert_eq(
    rectified.rest.lookup_immediate(key_crop),
    Some(page_box_rect_for_test(10.0, 10.0, 70.0, 70.0)),
  )
  @test.assert_eq(page_box_ops_for_test(document, rectified), [
    Op_cm(@geometry.transform_translate(-10.0, -20.0)),
    Op_S,
  ])

  let already_rectified = try! @pdflite.pdf_rectify_boxes(
    document,
    page_box_page_for_test(PdfDictionary([])),
  )
  @test.assert_eq(page_box_ops_for_test(document, already_rectified), [Op_S])
}

///|
test "PdfDocument set_mediaboxes uses page-indexed xywh boxes" {
  let document = page_box_document_for_test()
  let updated = try! document.set_mediaboxes([2], [
    (5.0, 6.0, 10.0, 20.0),
    (1.0, 2.0, 30.0, 40.0),
  ])
  let pages = try! updated.pages_of_pagetree()
  @test.assert_eq(try! updated.parse_rectangle(pages[0].mediabox), {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 100.0,
    max_y: 200.0,
  })
  @test.assert_eq(try! updated.parse_rectangle(pages[1].mediabox), {
    min_x: 1.0,
    min_y: 2.0,
    max_x: 31.0,
    max_y: 42.0,
  })

  let wrapped = try! @pdflite.pdf_set_mediaboxes(document, [1], [
    (10.0, 20.0, 30.0, 40.0),
    (1.0, 2.0, 3.0, 4.0),
  ])
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(try! wrapped.parse_rectangle(wrapped_pages[0].mediabox), {
    min_x: 10.0,
    min_y: 20.0,
    max_x: 40.0,
    max_y: 60.0,
  })

  let method_alias = try! document.set_mediabox([2], [
    (5.0, 6.0, 10.0, 20.0),
    (2.0, 4.0, 6.0, 8.0),
  ])
  let method_pages = try! method_alias.pages_of_pagetree()
  @test.assert_eq(try! method_alias.parse_rectangle(method_pages[1].mediabox), {
    min_x: 2.0,
    min_y: 4.0,
    max_x: 8.0,
    max_y: 12.0,
  })

  let source_order = try! @pdflite.pdf_set_mediabox(
    [(1.0, 3.0, 5.0, 7.0), (0.0, 0.0, 1.0, 1.0)],
    document,
    [1],
  )
  let source_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(try! source_order.parse_rectangle(source_pages[0].mediabox), {
    min_x: 1.0,
    min_y: 3.0,
    max_x: 6.0,
    max_y: 10.0,
  })
}

///|
test "PdfDocument set_mediaboxes validates page range and box count" {
  let document = page_box_document_for_test()
  let bad_count : Result[@pdflite.PdfDocument, Error] = try
    document.set_mediaboxes([1], [(1.0, 2.0, 3.0, 4.0)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_count
    is Err(
      @core.PdfError::BadPageSpecification(
        "set_mediaboxes: box count must match page count"
      )
    ) else {
    fail("expected set_mediaboxes to reject a partial page-indexed box list")
  }

  let bad_page : Result[@pdflite.PdfDocument, Error] = try
    document.set_mediaboxes([3], [(1.0, 2.0, 3.0, 4.0), (5.0, 6.0, 7.0, 8.0)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page
    is Err(
      @core.PdfError::BadPageSpecification(
        "set_mediaboxes: range contains pages not present in pdf"
      )
    ) else {
    fail("expected set_mediaboxes to reject an out-of-range page")
  }
}

///|
test "PdfDocument crop_pages sets selected page-indexed boxes" {
  let document = page_box_document_for_test()
  let key_crop = page_box_name_for_test("/CropBox")
  let key_bleed = page_box_name_for_test("/BleedBox")
  let cropped = try! document.crop_pages([2], [
    (1.0, 2.0, 10.0, 20.0),
    (3.0, 4.0, 30.0, 40.0),
  ])
  let pages = try! cropped.pages_of_pagetree()
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_crop),
    Some(page_box_rect_for_test(10.0, 20.0, 90.0, 150.0)),
  )
  @test.assert_eq(
    pages[1].rest.lookup_immediate(key_crop),
    Some(page_box_rect_for_test(3.0, 4.0, 33.0, 44.0)),
  )

  let wrapped = try! @pdflite.pdf_crop_pdf(
    document,
    [1],
    [(5.0, 6.0, 7.0, 8.0), (0.0, 0.0, 1.0, 1.0)],
    box_name=key_bleed,
  )
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(
    wrapped_pages[0].rest.lookup_immediate(key_bleed),
    Some(page_box_rect_for_test(5.0, 6.0, 12.0, 14.0)),
  )
  @test.assert_eq(wrapped_pages[1].rest.lookup_immediate(key_bleed), None)

  let string_wrapped = try! @pdflite.pdf_crop_pdf_string(
    [(5.0, 6.0, 7.0, 8.0), (0.0, 0.0, 1.0, 1.0)],
    document,
    [1],
    box_name="/BleedBox",
  )
  let string_pages = try! string_wrapped.pages_of_pagetree()
  @test.assert_eq(
    string_pages[0].rest.lookup_immediate(key_bleed),
    Some(page_box_rect_for_test(5.0, 6.0, 12.0, 14.0)),
  )
}

///|
test "PdfDocument crop_pages validates page range and box count" {
  let document = page_box_document_for_test()
  let bad_count : Result[@pdflite.PdfDocument, Error] = try
    document.crop_pages([1], [(1.0, 2.0, 3.0, 4.0)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_count
    is Err(
      @core.PdfError::BadPageSpecification(
        "crop_pages: box count must match page count"
      )
    ) else {
    fail("expected crop_pages to reject a partial page-indexed box list")
  }

  let bad_page : Result[@pdflite.PdfDocument, Error] = try
    document.crop_pages([3], [(1.0, 2.0, 3.0, 4.0), (5.0, 6.0, 7.0, 8.0)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page
    is Err(
      @core.PdfError::BadPageSpecification(
        "crop_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected crop_pages to reject an out-of-range page")
  }
}

///|
test "PdfDocument set_page_box sets fixed named page box" {
  let document = page_box_document_for_test()
  let key_art = page_box_name_for_test("/ArtBox")
  let key_bleed = page_box_name_for_test("/BleedBox")
  let boxed = try! document.set_page_box([2], key_art, 10.0, 70.0, 20.0, 80.0)
  let pages = try! boxed.pages_of_pagetree()
  @test.assert_eq(pages[0].rest.lookup_immediate(key_art), None)
  @test.assert_eq(
    pages[1].rest.lookup_immediate(key_art),
    Some(page_box_rect_for_test(10.0, 20.0, 70.0, 80.0)),
  )

  let wrapped = try! @pdflite.pdf_set_box(
    document,
    [1],
    key_bleed,
    1.0,
    4.0,
    2.0,
    5.0,
  )
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(
    wrapped_pages[0].rest.lookup_immediate(key_bleed),
    Some(page_box_rect_for_test(1.0, 2.0, 4.0, 5.0)),
  )
  @test.assert_eq(wrapped_pages[1].rest.lookup_immediate(key_bleed), None)

  let string_wrapped = try! @pdflite.pdf_set_box_string(
    "/BleedBox",
    2.0,
    5.0,
    3.0,
    6.0,
    document,
    [1],
  )
  let string_pages = try! string_wrapped.pages_of_pagetree()
  @test.assert_eq(
    string_pages[0].rest.lookup_immediate(key_bleed),
    Some(page_box_rect_for_test(2.0, 3.0, 5.0, 6.0)),
  )
}

///|
test "PdfDocument set_page_box validates selected pages" {
  let document = page_box_document_for_test()
  let bad_page : Result[@pdflite.PdfDocument, Error] = try
    document.set_page_box(
      [3],
      page_box_name_for_test("/ArtBox"),
      1.0,
      2.0,
      3.0,
      4.0,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page
    is Err(
      @core.PdfError::BadPageSpecification(
        "set_page_box: range contains pages not present in pdf"
      )
    ) else {
    fail("expected set_page_box to reject an out-of-range page")
  }
}

///|
test "PdfDocument shift_boxes shifts only selected page boxes" {
  let document = page_box_document_for_test()
  let key_crop = page_box_name_for_test("/CropBox")
  let key_trim = page_box_name_for_test("/TrimBox")
  let shifted = try! document.shift_boxes([2], [(100.0, 100.0), (5.0, -10.0)])
  let pages = try! shifted.pages_of_pagetree()
  @test.assert_eq(try! shifted.parse_rectangle(pages[0].mediabox), {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 100.0,
    max_y: 200.0,
  })
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_trim),
    Some(page_box_rect_for_test(1.0, 2.0, 3.0, 4.0)),
  )
  @test.assert_eq(try! shifted.parse_rectangle(pages[1].mediabox), {
    min_x: 5.0,
    min_y: -10.0,
    max_x: 105.0,
    max_y: 190.0,
  })
  @test.assert_eq(
    pages[1].rest.lookup_immediate(key_crop),
    Some(page_box_rect_for_test(35.0, 30.0, 75.0, 70.0)),
  )

  let wrapped = try! @pdflite.pdf_shift_boxes(document, [1], [
    (1.0, 2.0),
    (3.0, 4.0),
  ])
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(try! wrapped.parse_rectangle(wrapped_pages[0].mediabox), {
    min_x: 1.0,
    min_y: 2.0,
    max_x: 101.0,
    max_y: 202.0,
  })

  let source_order = try! @pdflite.pdf_shift_boxes_cpdf_order(
    [(2.0, 3.0), (4.0, 5.0)],
    document,
    [1],
  )
  let source_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(try! source_order.parse_rectangle(source_pages[0].mediabox), {
    min_x: 2.0,
    min_y: 3.0,
    max_x: 102.0,
    max_y: 203.0,
  })
}

///|
test "PdfDocument shift_boxes validates selected pages and offset count" {
  let document = page_box_document_for_test()
  let bad_count : Result[@pdflite.PdfDocument, Error] = try
    document.shift_boxes([1], [(1.0, 2.0)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_count
    is Err(
      @core.PdfError::BadPageSpecification(
        "shift_boxes: offset count must match page count"
      )
    ) else {
    fail("expected shift_boxes to reject a partial page-indexed offset list")
  }

  let bad_page : Result[@pdflite.PdfDocument, Error] = try
    document.shift_boxes([3], [(1.0, 2.0), (3.0, 4.0)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page
    is Err(
      @core.PdfError::BadPageSpecification(
        "shift_boxes: range contains pages not present in pdf"
      )
    ) else {
    fail("expected shift_boxes to reject an out-of-range page")
  }
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

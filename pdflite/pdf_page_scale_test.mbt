///|
fn page_scale_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_scale_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn page_scale_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn page_scale_page_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  resources? : @pdflite.PdfObject = PdfDictionary([]),
  rest? : @pdflite.PdfObject = PdfDictionary([]),
  width? : Double = 100.0,
  height? : Double = 100.0,
  rotate? : @pdflite.PdfPageRotation = Rotate0,
) -> @pdflite.PdfPage {
  {
    content: [page_scale_stream_for_test(ops)],
    mediabox: page_scale_rect_for_test(0.0, 0.0, width, height),
    resources,
    rotate,
    rest,
  }
}

///|
fn page_scale_document_for_test(
  pages : ArrayView[@pdflite.PdfPage],
) -> @pdflite.PdfDocument {
  try! (try! @pdflite.pdf_blank_document(100.0, 100.0, pages.length())).change_pages(
    pages,
  )
}

///|
fn page_scale_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "PdfDocument scale_contents uses cropbox position and transforms annotations and patterns" {
  let key_annots = page_scale_name_for_test("/Annots")
  let key_crop = page_scale_name_for_test("/CropBox")
  let key_rect = page_scale_name_for_test("/Rect")
  let key_pattern = page_scale_name_for_test("/Pattern")
  let key_matrix = page_scale_name_for_test("/Matrix")
  let pattern_name = page_scale_name_for_test("/P1")
  let old_matrix = @pdflite.transform_translate(1.0, 2.0)
  let matrix = @pdflite.transform_matrix_compose(
    @pdflite.transform_translate(5.0, 7.0),
    @pdflite.transform_scale(@pdflite.point2(10.0, 20.0), 0.5, 0.5),
  )
  let first = page_scale_page_for_test(
    [Op_scnName(pattern_name, []), Op_S],
    resources=PdfDictionary([
      (
        key_pattern,
        PdfDictionary([
          (
            pattern_name,
            PdfDictionary([
              (key_matrix, @pdflite.pdf_object_of_matrix(old_matrix)),
            ]),
          ),
        ]),
      ),
    ]),
    rest=PdfDictionary([
      (key_crop, page_scale_rect_for_test(10.0, 20.0, 110.0, 120.0)),
      (
        key_annots,
        PdfArray([
          PdfDictionary([
            (key_rect, page_scale_rect_for_test(20.0, 40.0, 30.0, 50.0)),
          ]),
        ]),
      ),
    ]),
  )
  let second = page_scale_page_for_test([Op_S])
  let document = page_scale_document_for_test([first, second])
  let scaled = try! document.scale_contents(
    [1],
    PdfPositionBottomLeft(5.0, 7.0),
    0.5,
  )
  let pages = try! scaled.pages_of_pagetree()
  @test.assert_eq(page_scale_ops_for_test(scaled, pages[0]), [
    Op_cm(matrix),
    Op_scnName(pattern_name, []),
    Op_S,
  ])
  @test.assert_eq(page_scale_ops_for_test(scaled, pages[1]), [Op_S])
  guard pages[0].rest.lookup_immediate(key_annots)
    is Some(PdfArray([PdfDictionary(_) as annotation])) else {
    fail("expected scaled direct annotation")
  }
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(page_scale_rect_for_test(20.0, 37.0, 25.0, 42.0)),
  )
  guard pages[0].resources.lookup_immediate(key_pattern)
    is Some(PdfDictionary([(name, PdfIndirect(number))])) &&
    name == pattern_name else {
    fail("expected scaled page pattern to be cloned")
  }
  @test.assert_eq(
    scaled.lookup_object_or_null(number).lookup_immediate(key_matrix),
    Some(
      @pdflite.pdf_object_of_matrix(
        @pdflite.transform_matrix_compose(matrix, old_matrix),
      ),
    ),
  )
}

///|
test "PdfDocument scale_contents transforms open-action destinations" {
  let key_open_action = page_scale_name_for_test("/OpenAction")
  let xyz_name = page_scale_name_for_test("/XYZ")
  let document = page_scale_document_for_test([page_scale_page_for_test([Op_S])])
  let page_numbers = try! document.page_reference_numbers()
  document.add_object_given_number(
    document.root(),
    try! document
    .lookup_object_or_null(document.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(page_numbers[0]),
        PdfNameObject(xyz_name),
        PdfReal(1.0),
        PdfReal(2.0),
        PdfNull,
      ]),
    ),
  )
  let scaled = try! @pdflite.pdf_scale_contents(
    document,
    [1],
    PdfPositionBottomLeft(0.0, 0.0),
    2.0,
  )
  let scaled_numbers = try! scaled.page_reference_numbers()
  guard scaled
    .lookup_object_or_null(scaled.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected scaled document open action")
  }
  @test.assert_eq(
    scaled.direct(open_action),
    PdfArray([
      PdfIndirect(scaled_numbers[0]),
      PdfNameObject(xyz_name),
      PdfReal(2.0),
      PdfReal(4.0),
      PdfNull,
    ]),
  )
}

///|
test "PdfDocument scale_contents validates page range" {
  let document = page_scale_document_for_test([page_scale_page_for_test([Op_S])])
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.scale_contents(
    [2],
    PdfPositionBottomLeft(0.0, 0.0),
    1.0,
  )
  guard bad_page
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_contents: range contains pages not present in pdf"
      )
    ) else {
    fail("expected page range validation")
  }
}

///|
test "PdfDocument scale_pages scales boxes content and destinations" {
  let key_crop = page_scale_name_for_test("/CropBox")
  let key_open_action = page_scale_name_for_test("/OpenAction")
  let xyz_name = page_scale_name_for_test("/XYZ")
  let first = page_scale_page_for_test(
    [Op_S],
    rest=PdfDictionary([
      (key_crop, page_scale_rect_for_test(10.0, 20.0, 50.0, 60.0)),
    ]),
    width=100.0,
    height=80.0,
  )
  let second = page_scale_page_for_test([Op_BT, Op_ET])
  let document = page_scale_document_for_test([first, second])
  let page_numbers = try! document.page_reference_numbers()
  document.add_object_given_number(
    document.root(),
    try! document
    .lookup_object_or_null(document.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(page_numbers[0]),
        PdfNameObject(xyz_name),
        PdfReal(4.0),
        PdfReal(5.0),
        PdfNull,
      ]),
    ),
  )
  let scaled = try! document.scale_pages([1], [(2.0, 3.0)])
  let pages = try! scaled.pages_of_pagetree()
  @test.assert_eq(
    pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 200.0, 240.0),
  )
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_crop),
    Some(page_scale_rect_for_test(20.0, 60.0, 100.0, 180.0)),
  )
  @test.assert_eq(page_scale_ops_for_test(scaled, pages[0]), [
    Op_cm(@pdflite.transform_scale(@pdflite.point2(0.0, 0.0), 2.0, 3.0)),
    Op_S,
  ])
  @test.assert_eq(
    pages[1].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 100.0, 100.0),
  )
  @test.assert_eq(page_scale_ops_for_test(scaled, pages[1]), [Op_BT, Op_ET])
  let scaled_numbers = try! scaled.page_reference_numbers()
  guard scaled
    .lookup_object_or_null(scaled.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected scaled document open action")
  }
  @test.assert_eq(
    scaled.direct(open_action),
    PdfArray([
      PdfIndirect(scaled_numbers[0]),
      PdfNameObject(xyz_name),
      PdfReal(8.0),
      PdfReal(15.0),
      PdfNull,
    ]),
  )
  let wrapped = try! @pdflite.pdf_scale_pages(document, [1], [(0.5, 0.5)])
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(
    wrapped_pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 50.0, 40.0),
  )
}

///|
test "cpdf scale_pdf wrapper uses absolute page-indexed scales" {
  let document = page_scale_document_for_test([
    page_scale_page_for_test([Op_S], width=80.0, height=90.0),
    page_scale_page_for_test([Op_BT, Op_ET], width=100.0, height=100.0),
  ])
  let scaled = try! @pdflite.pdf_scale_pdf([(9.0, 9.0), (2.0, 3.0)], document, [
    2,
  ])
  let pages = try! scaled.pages_of_pagetree()
  @test.assert_eq(
    pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 80.0, 90.0),
  )
  @test.assert_eq(
    pages[1].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 200.0, 300.0),
  )
  @test.assert_eq(page_scale_ops_for_test(scaled, pages[0]), [Op_S])
  @test.assert_eq(page_scale_ops_for_test(scaled, pages[1]), [
    Op_cm(@pdflite.transform_scale(@pdflite.point2(0.0, 0.0), 2.0, 3.0)),
    Op_BT,
    Op_ET,
  ])
}

///|
test "PdfDocument scale_pages validates scale counts and page range" {
  let document = page_scale_document_for_test([page_scale_page_for_test([Op_S])])
  let mismatch : Result[@pdflite.PdfDocument, Error] = try? document.scale_pages(
    [1],
    [],
  )
  guard mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_pages: scale count must match page count"
      )
    ) else {
    fail("expected scale_pages to reject scale count mismatch")
  }
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.scale_pages(
    [2],
    [(1.0, 1.0)],
  )
  guard bad_page
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected scale_pages to reject invalid pages")
  }

  let cpdf_mismatch : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_scale_pdf(
    [],
    document,
    [1],
  )
  guard cpdf_mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_pdf: scale count must match page count"
      )
    ) else {
    fail("expected cpdf scale_pdf count validation")
  }
}

///|
test "PdfDocument stretch_pages scales from cropbox without preserving aspect" {
  let key_crop = page_scale_name_for_test("/CropBox")
  let key_open_action = page_scale_name_for_test("/OpenAction")
  let xyz_name = page_scale_name_for_test("/XYZ")
  let matrix = @pdflite.transform_scale(@pdflite.point2(0.0, 0.0), 3.0, 4.0)
  let first = page_scale_page_for_test(
    [Op_S],
    rest=PdfDictionary([
      (key_crop, page_scale_rect_for_test(10.0, 10.0, 60.0, 30.0)),
    ]),
    width=100.0,
    height=50.0,
  )
  let second = page_scale_page_for_test([Op_BT])
  let document = page_scale_document_for_test([first, second])
  let page_numbers = try! document.page_reference_numbers()
  document.add_object_given_number(
    document.root(),
    try! document
    .lookup_object_or_null(document.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(page_numbers[0]),
        PdfNameObject(xyz_name),
        PdfReal(20.0),
        PdfReal(10.0),
        PdfNull,
      ]),
    ),
  )
  let stretched = try! document.stretch_pages([1], [(150.0, 80.0)])
  let pages = try! stretched.pages_of_pagetree()
  @test.assert_eq(
    pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 300.0, 200.0),
  )
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_crop),
    Some(page_scale_rect_for_test(30.0, 40.0, 180.0, 120.0)),
  )
  @test.assert_eq(page_scale_ops_for_test(stretched, pages[0]), [
    Op_cm(matrix),
    Op_S,
  ])
  @test.assert_eq(page_scale_ops_for_test(stretched, pages[1]), [Op_BT])
  let stretched_numbers = try! stretched.page_reference_numbers()
  guard stretched
    .lookup_object_or_null(stretched.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected stretched document open action")
  }
  @test.assert_eq(
    stretched.direct(open_action),
    PdfArray([
      PdfIndirect(stretched_numbers[0]),
      PdfNameObject(xyz_name),
      PdfReal(60.0),
      PdfReal(40.0),
      PdfNull,
    ]),
  )

  let wrapped = try! @pdflite.pdf_stretch_pages(document, [2], [(50.0, 50.0)])
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(page_scale_ops_for_test(wrapped, wrapped_pages[0]), [Op_S])
  guard page_scale_ops_for_test(wrapped, wrapped_pages[1]) is [Op_cm(_), Op_BT] else {
    fail("expected wrapper to stretch selected second page")
  }
}

///|
test "cpdf stretch wrapper uses absolute page-indexed sizes" {
  let document = page_scale_document_for_test([
    page_scale_page_for_test([Op_S], width=80.0, height=90.0),
    page_scale_page_for_test([Op_BT], width=100.0, height=100.0),
  ])
  let stretched = try! @pdflite.pdf_stretch(
    [(900.0, 900.0), (50.0, 200.0)],
    document,
    [2],
  )
  let pages = try! stretched.pages_of_pagetree()
  @test.assert_eq(
    pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 80.0, 90.0),
  )
  @test.assert_eq(
    pages[1].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 50.0, 200.0),
  )
  @test.assert_eq(page_scale_ops_for_test(stretched, pages[0]), [Op_S])
  @test.assert_eq(page_scale_ops_for_test(stretched, pages[1]), [
    Op_cm(@pdflite.transform_scale(@pdflite.point2(0.0, 0.0), 0.5, 2.0)),
    Op_BT,
  ])
}

///|
test "PdfDocument stretch_pages validates size counts page range and zero boxes" {
  let document = page_scale_document_for_test([page_scale_page_for_test([Op_S])])
  let mismatch : Result[@pdflite.PdfDocument, Error] = try? document.stretch_pages(
    [1],
    [],
  )
  guard mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "stretch_pages: size count must match page count"
      )
    ) else {
    fail("expected stretch_pages to reject size count mismatch")
  }
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.stretch_pages(
    [2],
    [(100.0, 100.0)],
  )
  guard bad_page
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "stretch_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected stretch_pages to reject invalid pages")
  }
  let zero = page_scale_document_for_test([
    page_scale_page_for_test([Op_S], width=0.0, height=10.0),
  ])
  let bad_size : Result[@pdflite.PdfDocument, Error] = try? zero.stretch_pages(
    [1],
    [(100.0, 100.0)],
  )
  guard bad_size
    is Err(
      @pdflite.PdfError::BadNumberArgument(
        "stretch_pages: zero-sized pages are invalid"
      )
    ) else {
    fail("expected stretch_pages to reject zero-sized pages")
  }

  let cpdf_mismatch : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_stretch(
    [],
    document,
    [1],
  )
  guard cpdf_mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "stretch: size count must match page count"
      )
    ) else {
    fail("expected cpdf stretch size count validation")
  }
}

///|
test "PdfDocument scale_to_fit_pages centers content and sets target boxes" {
  let key_crop = page_scale_name_for_test("/CropBox")
  let page = page_scale_page_for_test(
    [Op_S],
    rest=PdfDictionary([
      (key_crop, page_scale_rect_for_test(0.0, 0.0, 100.0, 50.0)),
    ]),
    width=100.0,
    height=50.0,
  )
  let document = page_scale_document_for_test([page])
  let fitted = try! document.scale_to_fit_pages([1], [(200.0, 200.0)])
  let pages = try! fitted.pages_of_pagetree()
  @test.assert_eq(
    pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 200.0, 200.0),
  )
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_crop),
    Some(page_scale_rect_for_test(0.0, 0.0, 200.0, 200.0)),
  )
  @test.assert_eq(page_scale_ops_for_test(fitted, pages[0]), [
    Op_cm(
      @pdflite.transform_matrix_compose(
        @pdflite.transform_translate(0.0, 0.0),
        @pdflite.transform_matrix_compose(
          @pdflite.transform_translate(0.0, 0.0),
          @pdflite.transform_matrix_compose(
            @pdflite.transform_translate(0.0, 50.0),
            @pdflite.transform_scale(@pdflite.point2(0.0, 0.0), 2.0, 2.0),
          ),
        ),
      ),
    ),
    Op_S,
  ])
  let wrapped = try! @pdflite.pdf_scale_to_fit_pages(
    document,
    [1],
    [(50.0, 50.0)],
    position=PdfPositionLeft(0.0),
  )
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(
    wrapped_pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 50.0, 50.0),
  )
}

///|
test "cpdf scale_to_fit_pdf wrapper uses absolute page-indexed sizes" {
  let document = page_scale_document_for_test([
    page_scale_page_for_test([Op_S], width=80.0, height=90.0),
    page_scale_page_for_test([Op_BT], width=100.0, height=50.0),
  ])
  let fitted = try! @pdflite.pdf_scale_to_fit_pdf(
    PdfPositionCentre,
    1.0,
    [(500.0, 500.0), (50.0, 100.0)],
    (),
    document,
    [2],
  )
  let pages = try! fitted.pages_of_pagetree()
  @test.assert_eq(
    pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 80.0, 90.0),
  )
  @test.assert_eq(
    pages[1].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 50.0, 100.0),
  )
  @test.assert_eq(page_scale_ops_for_test(fitted, pages[0]), [Op_S])
  guard page_scale_ops_for_test(fitted, pages[1]) is [Op_cm(_), Op_BT] else {
    fail("expected cpdf scale_to_fit_pdf to transform selected second page")
  }
}

///|
test "PdfDocument scale_to_fit_pages validates size counts and zero boxes" {
  let document = page_scale_document_for_test([page_scale_page_for_test([Op_S])])
  let mismatch : Result[@pdflite.PdfDocument, Error] = try? document.scale_to_fit_pages(
    [1],
    [],
  )
  guard mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_to_fit_pages: size count must match page count"
      )
    ) else {
    fail("expected scale_to_fit_pages to reject size count mismatch")
  }
  let zero = page_scale_document_for_test([
    page_scale_page_for_test([Op_S], width=0.0, height=10.0),
  ])
  let bad_size : Result[@pdflite.PdfDocument, Error] = try? zero.scale_to_fit_pages(
    [1],
    [(100.0, 100.0)],
  )
  guard bad_size
    is Err(
      @pdflite.PdfError::BadNumberArgument(
        "scale_to_fit_pages: zero-sized pages are invalid"
      )
    ) else {
    fail("expected scale_to_fit_pages to reject zero-sized pages")
  }

  let cpdf_mismatch : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_scale_to_fit_pdf(
    PdfPositionCentre,
    1.0,
    [],
    (),
    document,
    [1],
  )
  guard cpdf_mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_to_fit_pdf: size count must match page count"
      )
    ) else {
    fail("expected cpdf scale_to_fit_pdf size count validation")
  }
}

///|
test "PdfDocument scale_to_fit_rotate_pages rotates mismatched orientation before upright" {
  let document = page_scale_document_for_test([
    page_scale_page_for_test([Op_S], width=100.0, height=200.0),
  ])
  let rotated = try! document.scale_to_fit_rotate_pages(
    [1],
    [(300.0, 100.0)],
    90,
  )
  let expected = try! (try! document.rotate_pages_by(90, [1])).upright_pages([1])
  let rotated_pages = try! rotated.pages_of_pagetree()
  let expected_pages = try! expected.pages_of_pagetree()
  @test.assert_eq(rotated_pages[0].mediabox, expected_pages[0].mediabox)
  @test.assert_eq(rotated_pages[0].rotate, expected_pages[0].rotate)
  @test.assert_eq(
    page_scale_ops_for_test(rotated, rotated_pages[0]),
    page_scale_ops_for_test(expected, expected_pages[0]),
  )
  @test.assert_eq(try! rotated.all_pages_upright([1]), true)
}

///|
test "PdfDocument scale_to_fit_rotate_pages uprights selected pages even without added rotation" {
  let document = page_scale_document_for_test([
    page_scale_page_for_test([Op_S], width=100.0, height=200.0, rotate=Rotate90),
  ])
  let upright = try! @pdflite.pdf_scale_to_fit_rotate_pages(
    document,
    [1],
    [(100.0, 300.0)],
    90,
  )
  let expected = try! document.upright_pages([1])
  let upright_pages = try! upright.pages_of_pagetree()
  let expected_pages = try! expected.pages_of_pagetree()
  @test.assert_eq(upright_pages[0].mediabox, expected_pages[0].mediabox)
  @test.assert_eq(upright_pages[0].rotate, expected_pages[0].rotate)
  @test.assert_eq(
    page_scale_ops_for_test(upright, upright_pages[0]),
    page_scale_ops_for_test(expected, expected_pages[0]),
  )
  @test.assert_eq(try! upright.all_pages_upright([1]), true)
}

///|
test "cpdf scale_to_fit_rotate wrapper uses absolute page-indexed sizes" {
  let document = page_scale_document_for_test([
    page_scale_page_for_test([Op_S], width=200.0, height=100.0),
    page_scale_page_for_test([Op_BT], width=100.0, height=200.0),
  ])
  let rotated = try! @pdflite.pdf_scale_to_fit_rotate(
    [(100.0, 200.0), (300.0, 100.0)],
    90,
    document,
    [2],
  )
  let expected = try! document.scale_to_fit_rotate_pages(
    [2],
    [(300.0, 100.0)],
    90,
  )
  let rotated_pages = try! rotated.pages_of_pagetree()
  let expected_pages = try! expected.pages_of_pagetree()
  @test.assert_eq(
    rotated_pages[0].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 200.0, 100.0),
  )
  @test.assert_eq(rotated_pages[1].mediabox, expected_pages[1].mediabox)
  @test.assert_eq(rotated_pages[1].rotate, expected_pages[1].rotate)
  @test.assert_eq(
    page_scale_ops_for_test(rotated, rotated_pages[1]),
    page_scale_ops_for_test(expected, expected_pages[1]),
  )
}

///|
test "PdfDocument scale_to_fit_rotate_pages validates page range and size count" {
  let document = page_scale_document_for_test([page_scale_page_for_test([Op_S])])
  let mismatch : Result[@pdflite.PdfDocument, Error] = try? document.scale_to_fit_rotate_pages(
    [1],
    [],
    90,
  )
  guard mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_to_fit_rotate_pages: size count must match page count"
      )
    ) else {
    fail("expected scale_to_fit_rotate_pages to reject size count mismatch")
  }

  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.scale_to_fit_rotate_pages(
    [2],
    [(100.0, 200.0)],
    90,
  )
  guard bad_page
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_to_fit_rotate_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected scale_to_fit_rotate_pages to reject an out-of-range page")
  }

  let cpdf_mismatch : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_scale_to_fit_rotate(
    [],
    90,
    document,
    [1],
  )
  guard cpdf_mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "scale_to_fit_rotate: size count must match page count"
      )
    ) else {
    fail("expected cpdf scale_to_fit_rotate size count validation")
  }
}

///|
test "PdfDocument center_to_fit_pages composes cpdf box operations" {
  let key_art = page_scale_name_for_test("/ArtBox")
  let key_bleed = page_scale_name_for_test("/BleedBox")
  let key_crop = page_scale_name_for_test("/CropBox")
  let key_trim = page_scale_name_for_test("/TrimBox")
  let document = page_scale_document_for_test([
    page_scale_page_for_test(
      [Op_S],
      rest=PdfDictionary([
        (key_crop, page_scale_rect_for_test(10.0, 20.0, 90.0, 120.0)),
        (key_art, page_scale_rect_for_test(1.0, 2.0, 3.0, 4.0)),
        (key_bleed, page_scale_rect_for_test(5.0, 6.0, 7.0, 8.0)),
        (key_trim, page_scale_rect_for_test(9.0, 10.0, 11.0, 12.0)),
      ]),
      width=100.0,
      height=150.0,
    ),
    page_scale_page_for_test(
      [Op_BT, Op_ET],
      rest=PdfDictionary([
        (key_art, page_scale_rect_for_test(20.0, 30.0, 40.0, 50.0)),
        (key_bleed, page_scale_rect_for_test(60.0, 70.0, 80.0, 90.0)),
      ]),
    ),
  ])
  let centered = try! document.center_to_fit_pages([1], [
    (200.0, 300.0),
    (400.0, 500.0),
  ])
  let pages = try! centered.pages_of_pagetree()
  @test.assert_eq(
    pages[0].mediabox,
    page_scale_rect_for_test(-60.0, -100.0, 140.0, 200.0),
  )
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_crop),
    Some(page_scale_rect_for_test(-60.0, -100.0, 140.0, 200.0)),
  )
  @test.assert_eq(pages[0].rest.lookup_immediate(key_art), None)
  @test.assert_eq(pages[0].rest.lookup_immediate(key_bleed), None)
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_trim),
    Some(page_scale_rect_for_test(-51.0, -90.0, -49.0, -88.0)),
  )
  @test.assert_eq(
    pages[1].mediabox,
    page_scale_rect_for_test(0.0, 0.0, 100.0, 100.0),
  )
  @test.assert_eq(
    pages[1].rest.lookup_immediate(key_art),
    Some(page_scale_rect_for_test(20.0, 30.0, 40.0, 50.0)),
  )
}

///|
test "PdfDocument center_to_fit_pages wrapper uses first target for all offsets" {
  let document = page_scale_document_for_test([
    page_scale_page_for_test([Op_S]),
    page_scale_page_for_test([Op_BT, Op_ET]),
  ])
  let centered = try! @pdflite.pdf_center_to_fit_pages(document, [2], [
    (200.0, 300.0),
    (400.0, 500.0),
  ])
  let pages = try! centered.pages_of_pagetree()
  @test.assert_eq(
    pages[1].mediabox,
    page_scale_rect_for_test(-50.0, -100.0, 350.0, 400.0),
  )
  let cpdf_centered = try! @pdflite.pdf_center_to_fit(
    [(200.0, 300.0), (400.0, 500.0)],
    document,
    [2],
  )
  let cpdf_pages = try! cpdf_centered.pages_of_pagetree()
  @test.assert_eq(
    cpdf_pages[1].mediabox,
    page_scale_rect_for_test(-50.0, -100.0, 350.0, 400.0),
  )
}

///|
test "PdfDocument center_to_fit_pages validates page range and size count" {
  let document = page_scale_document_for_test([page_scale_page_for_test([Op_S])])
  let mismatch : Result[@pdflite.PdfDocument, Error] = try? document.center_to_fit_pages(
    [1],
    [],
  )
  guard mismatch
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "center_to_fit_pages: size count must match page count"
      )
    ) else {
    fail("expected center_to_fit_pages to reject size count mismatch")
  }

  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.center_to_fit_pages(
    [2],
    [(100.0, 200.0)],
  )
  guard bad_page
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "center_to_fit_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected center_to_fit_pages to reject an out-of-range page")
  }
}

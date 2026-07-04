///|
fn page_upright_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_upright_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn page_upright_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn page_upright_page_for_test(
  ops : ArrayView[@content.PdfContentOp],
  mediabox : @syntax.PdfObject,
  rotate? : @page.PdfPageRotation = Rotate0,
  rest? : @syntax.PdfObject = PdfDictionary([]),
) -> @page.PdfPage {
  {
    content: [page_upright_stream_for_test(ops)],
    mediabox,
    resources: PdfDictionary([]),
    rotate,
    rest,
  }
}

///|
fn page_upright_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  try! (try! @pdflite.pdf_blank_document(100.0, 100.0, pages.length())).change_pages(
    pages,
  )
}

///|
fn page_upright_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "PdfDocument upright predicates mirror cpdf page checks" {
  let upright = page_upright_page_for_test(
    [Op_S],
    page_upright_rect_for_test(0.0, 0.0, 100.0, 100.0),
  )
  let shifted_origin = page_upright_page_for_test(
    [Op_S],
    page_upright_rect_for_test(10.0, 20.0, 110.0, 120.0),
  )
  let rotated = page_upright_page_for_test(
    [Op_S],
    page_upright_rect_for_test(0.0, 0.0, 100.0, 100.0),
    rotate=Rotate90,
  )
  let document = page_upright_document_for_test([
    upright, shifted_origin, rotated,
  ])

  @test.assert_eq(try! document.all_pages_upright([1]), true)
  @test.assert_eq(try! document.all_pages_upright([1, 2]), false)
  @test.assert_eq(try! document.all_pages_upright_only([1, 2]), true)
  @test.assert_eq(try! document.all_pages_upright_only([1, 3]), false)
  @test.assert_eq(try! @pdflite.pdf_allupright(document, [1]), true)
  @test.assert_eq(try! @pdflite.pdf_alluprightonly(document, [2]), true)
  @test.assert_eq(try! @pdflite.pdf_allupright_cpdf_order([1], document), true)
  @test.assert_eq(
    try! @pdflite.pdf_allupright_cpdf_order([1, 2], document),
    false,
  )
  @test.assert_eq(
    try! @pdflite.pdf_alluprightonly_cpdf_order([1, 2], document),
    true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_alluprightonly_cpdf_order([1, 3], document),
    false,
  )

  // cpdf's select_pages helper ignores invalid page numbers for these checks.
  @test.assert_eq(try! document.all_pages_upright([4]), true)
  @test.assert_eq(try! document.all_pages_upright_only([0, 4]), true)
}

///|
test "PdfDocument upright_pages removes rotation and rectifies boxes" {
  let key_annots = page_upright_name_for_test("/Annots")
  let key_crop = page_upright_name_for_test("/CropBox")
  let key_rect = page_upright_name_for_test("/Rect")
  let mediabox = page_upright_rect_for_test(0.0, 0.0, 100.0, 200.0)
  let cropbox = page_upright_rect_for_test(10.0, 20.0, 90.0, 180.0)
  let annotation_rect = page_upright_rect_for_test(0.0, 0.0, 10.0, 20.0)
  let document = page_upright_document_for_test([
    page_upright_page_for_test(
      [Op_S],
      mediabox,
      rotate=Rotate90,
      rest=PdfDictionary([
        (key_crop, cropbox),
        (key_annots, PdfArray([PdfDictionary([(key_rect, annotation_rect)])])),
      ]),
    ),
  ])
  let rotation_matrix = @geometry.transform_rotate(
    @geometry.point2(50.0, 100.0),
    -@math.PI / 2.0,
  )
  let content_rotation_matrix = { ..rotation_matrix, a: 0.0, d: 0.0 }
  let rotated_mediabox = try! document.transform_rect(rotation_matrix, mediabox)
  let rotated_bounds = try! document.parse_rectangle(rotated_mediabox)
  let rectification_matrix = @geometry.transform_translate(
    -rotated_bounds.min_x,
    -rotated_bounds.min_y,
  )
  let total_matrix = @geometry.transform_matrix_compose(
    rectification_matrix, rotation_matrix,
  )
  let upright = try! document.upright_pages([1])
  let method_alias = try! document.upright([1])
  let pages = try! upright.pages_of_pagetree()
  let alias_pages = try! method_alias.pages_of_pagetree()
  @test.assert_eq(pages[0].rotate, Rotate0)
  @test.assert_eq(alias_pages[0].rotate, Rotate0)
  @test.assert_eq(
    pages[0].mediabox,
    try! document.transform_rect(rectification_matrix, rotated_mediabox),
  )
  @test.assert_eq(alias_pages[0].mediabox, pages[0].mediabox)
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_crop),
    Some(
      try! document.transform_rect(
        rectification_matrix,
        try! document.transform_rect(rotation_matrix, cropbox),
      ),
    ),
  )
  @test.assert_eq(page_upright_ops_for_test(upright, pages[0]), [
    Op_cm(rectification_matrix),
    Op_cm(content_rotation_matrix),
    Op_S,
  ])
  guard pages[0].rest.lookup_immediate(key_annots)
    is Some(PdfArray([PdfDictionary(_) as annotation])) else {
    fail("expected transformed annotation")
  }
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(try! document.transform_rect(total_matrix, annotation_rect)),
  )
}

///|
test "PdfDocument upright_pages rectifies non-zero origins and destinations" {
  let key_open_action = page_upright_name_for_test("/OpenAction")
  let xyz_name = page_upright_name_for_test("/XYZ")
  let document = page_upright_document_for_test([
    page_upright_page_for_test(
      [Op_S],
      page_upright_rect_for_test(10.0, 20.0, 110.0, 120.0),
    ),
  ])
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
        PdfReal(30.0),
        PdfNull,
      ]),
    ),
  )
  let upright = try! @pdflite.pdf_upright_pages(document, [1])
  let pages = try! upright.pages_of_pagetree()
  let upright_numbers = try! upright.page_reference_numbers()
  @test.assert_eq(
    pages[0].mediabox,
    page_upright_rect_for_test(0.0, 0.0, 100.0, 100.0),
  )
  @test.assert_eq(page_upright_ops_for_test(upright, pages[0]), [
    Op_cm(@geometry.transform_translate(-10.0, -20.0)),
    Op_S,
  ])
  guard upright
    .lookup_object_or_null(upright.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected transformed open action")
  }
  @test.assert_eq(
    upright.direct(open_action),
    PdfArray([
      PdfIndirect(upright_numbers[0]),
      PdfNameObject(xyz_name),
      PdfReal(10.0),
      PdfReal(10.0),
      PdfNull,
    ]),
  )

  let source_order = try! @pdflite.pdf_upright([1], document)
  let source_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(
    source_pages[0].mediabox,
    page_upright_rect_for_test(0.0, 0.0, 100.0, 100.0),
  )
}

///|
test "PdfDocument upright_pages validates page range" {
  let document = page_upright_document_for_test([
    page_upright_page_for_test(
      [Op_S],
      page_upright_rect_for_test(0.0, 0.0, 100.0, 100.0),
    ),
  ])
  let bad_page : Result[@pdflite.PdfDocument, Error] = try
    document.upright_pages([2])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page
    is Err(
      @core.PdfError::BadPageSpecification(
        "upright_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected page range validation")
  }
}

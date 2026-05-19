///|
fn rotate_page_for_test(
  rotate? : @pdflite.PdfPageRotation = Rotate0,
) -> @pdflite.PdfPage {
  { ..@pdflite.pdf_page_blank(@pdflite.paper_a4), rotate, }
}

///|
fn rotate_document_for_test(
  pages : ArrayView[@pdflite.PdfPage],
) -> @pdflite.PdfDocument raise @pdflite.PdfError {
  @pdflite.pdf_blank_document(100.0, 100.0, pages.length()).change_pages(pages)
}

///|
fn rotate_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn rotate_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn rotate_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn rotate_content_page_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  rest? : @pdflite.PdfObject = PdfDictionary([]),
  resources? : @pdflite.PdfObject = PdfDictionary([]),
  mediabox? : @pdflite.PdfObject = rotate_rect_for_test(0.0, 0.0, 100.0, 100.0),
) -> @pdflite.PdfPage {
  {
    content: [rotate_stream_for_test(ops)],
    mediabox,
    resources,
    rotate: Rotate0,
    rest,
  }
}

///|
fn rotate_content_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "PdfDocument rotate_pages sets absolute page rotation" {
  let document = try! rotate_document_for_test([
    rotate_page_for_test(),
    rotate_page_for_test(rotate=Rotate90),
  ])
  let rotated = try! document.rotate_pages(-90, [1])
  let pages = try! rotated.pages_of_pagetree()
  @test.assert_eq(pages[0].rotate, Rotate270)
  @test.assert_eq(pages[1].rotate, Rotate90)
  let wrapped = try! @pdflite.pdf_rotate_pages(document, 180, [2])
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(wrapped_pages[0].rotate, Rotate0)
  @test.assert_eq(wrapped_pages[1].rotate, Rotate180)
}

///|
test "PdfDocument rotate_pages_by adds to existing page rotation" {
  let document = try! rotate_document_for_test([
    rotate_page_for_test(rotate=Rotate90),
    rotate_page_for_test(rotate=Rotate270),
  ])
  let rotated = try! @pdflite.pdf_rotate_pages_by(document, 90, [1, 2])
  let pages = try! rotated.pages_of_pagetree()
  @test.assert_eq(pages[0].rotate, Rotate180)
  @test.assert_eq(pages[1].rotate, Rotate0)
}

///|
test "PdfDocument rotate_pages validates rotation and page range" {
  let document = try! rotate_document_for_test([rotate_page_for_test()])
  let bad_rotation : Result[@pdflite.PdfDocument, Error] = try? document.rotate_pages(
    45,
    [1],
  )
  guard bad_rotation is Err(PdfError::PageRotationExpected(45)) else {
    fail("expected PageRotationExpected for non-right-angle rotation")
  }
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.rotate_pages_by(
    90,
    [2],
  )
  guard bad_page
    is Err(
      PdfError::BadPageSpecification(
        "rotate_pages_by: range contains pages not present in pdf"
      )
    ) else {
    fail("expected rotate_pages_by to reject invalid pages")
  }
}

///|
test "PdfDocument rotate_contents transforms content annotations patterns and destinations" {
  let key_annots = rotate_name_for_test("/Annots")
  let key_open_action = rotate_name_for_test("/OpenAction")
  let key_pattern = rotate_name_for_test("/Pattern")
  let key_matrix = rotate_name_for_test("/Matrix")
  let key_rect = rotate_name_for_test("/Rect")
  let pattern_name = rotate_name_for_test("/P1")
  let xyz_name = rotate_name_for_test("/XYZ")
  let old_matrix = @pdflite.transform_translate(1.0, 2.0)
  let matrix = @pdflite.transform_rotate(
    @pdflite.point2(50.0, 50.0),
    -@math.PI / 2.0,
  )
  let content_matrix : @pdflite.TransformMatrix = {
    a: 0.0,
    b: -1.0,
    c: 1.0,
    d: 0.0,
    e: 0.0,
    f: 100.0,
  }
  let annotation_rect = rotate_rect_for_test(60.0, 70.0, 80.0, 90.0)
  let first = rotate_content_page_for_test(
    [Op_scnName(pattern_name, []), Op_S],
    rest=PdfDictionary([
      (key_annots, PdfArray([PdfDictionary([(key_rect, annotation_rect)])])),
    ]),
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
  )
  let second = rotate_content_page_for_test([Op_BT])
  let document = try! rotate_document_for_test([first, second])
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
        PdfReal(60.0),
        PdfReal(70.0),
        PdfNull,
      ]),
    ),
  )

  let rotated = try! document.rotate_contents(90.0, [1])
  let pages = try! rotated.pages_of_pagetree()
  @test.assert_eq(pages[0].mediabox, first.mediabox)
  @test.assert_eq(pages[0].rotate, Rotate0)
  @test.assert_eq(rotate_content_ops_for_test(rotated, pages[0]), [
    Op_cm(content_matrix),
    Op_scnName(pattern_name, []),
    Op_S,
  ])
  @test.assert_eq(rotate_content_ops_for_test(rotated, pages[1]), [Op_BT])

  guard pages[0].rest.lookup_immediate(key_annots)
    is Some(PdfArray([PdfDictionary(_) as annotation])) else {
    fail("expected rotated annotation")
  }
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(try! document.transform_rect(matrix, annotation_rect)),
  )
  guard pages[0].resources.lookup_immediate(key_pattern)
    is Some(PdfDictionary([(name, PdfIndirect(number))])) &&
    name == pattern_name else {
    fail("expected rotated page pattern to be cloned")
  }
  @test.assert_eq(
    rotated.lookup_object_or_null(number).lookup_immediate(key_matrix),
    Some(
      @pdflite.pdf_object_of_matrix(
        @pdflite.transform_matrix_compose(matrix, old_matrix),
      ),
    ),
  )

  let rotated_numbers = try! rotated.page_reference_numbers()
  let destination_point = matrix.apply(@pdflite.point2(60.0, 70.0))
  guard rotated
    .lookup_object_or_null(rotated.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected rotated document open action")
  }
  @test.assert_eq(
    rotated.direct(open_action),
    PdfArray([
      PdfIndirect(rotated_numbers[0]),
      PdfNameObject(xyz_name),
      PdfReal(destination_point.x),
      PdfReal(destination_point.y),
      PdfNull,
    ]),
  )

  let wrapped = try! @pdflite.pdf_rotate_contents(document, 180.0, [2])
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(rotate_content_ops_for_test(wrapped, wrapped_pages[0]), [
    Op_scnName(pattern_name, []),
    Op_S,
  ])
  guard rotate_content_ops_for_test(wrapped, wrapped_pages[1])
    is [Op_cm(_), Op_BT] else {
    fail("expected wrapper to rotate selected second page content")
  }
}

///|
test "PdfDocument rotate_contents validates selected pages" {
  let document = try! rotate_document_for_test([
    rotate_content_page_for_test([Op_S]),
  ])
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.rotate_contents(
    90.0,
    [2],
  )
  guard bad_page
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "rotate_contents: range contains pages not present in pdf"
      )
    ) else {
    fail("expected rotate_contents to reject invalid pages")
  }
}

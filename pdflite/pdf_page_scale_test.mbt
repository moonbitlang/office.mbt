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
) -> @pdflite.PdfPage {
  {
    content: [page_scale_stream_for_test(ops)],
    mediabox: page_scale_rect_for_test(0.0, 0.0, 100.0, 100.0),
    resources,
    rotate: Rotate0,
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

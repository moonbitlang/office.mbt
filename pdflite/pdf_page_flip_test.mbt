///|
fn page_flip_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_flip_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn page_flip_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn page_flip_page_for_test(
  ops : ArrayView[@content.PdfContentOp],
  resources? : @syntax.PdfObject = PdfDictionary([]),
  rest? : @syntax.PdfObject = PdfDictionary([]),
  mediabox? : @syntax.PdfObject = page_flip_rect_for_test(
    0.0, 0.0, 100.0, 100.0,
  ),
) -> @page.PdfPage {
  {
    content: [page_flip_stream_for_test(ops)],
    mediabox,
    resources,
    rotate: Rotate0,
    rest,
  }
}

///|
fn page_flip_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  try! (try! @pdflite.pdf_blank_document(100.0, 100.0, pages.length())).change_pages(
    pages,
  )
}

///|
fn page_flip_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "PdfDocument flip_pages_vertically transforms content annotations patterns and destinations" {
  let key_annots = page_flip_name_for_test("/Annots")
  let key_rect = page_flip_name_for_test("/Rect")
  let key_pattern = page_flip_name_for_test("/Pattern")
  let key_matrix = page_flip_name_for_test("/Matrix")
  let key_open_action = page_flip_name_for_test("/OpenAction")
  let pattern_name = page_flip_name_for_test("/P1")
  let xyz_name = page_flip_name_for_test("/XYZ")
  let old_matrix = @geometry.transform_translate(1.0, 2.0)
  let flip_matrix = @geometry.transform_scale(
    @geometry.point2(0.0, 120.0),
    1.0,
    -1.0,
  )
  let first = page_flip_page_for_test(
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
      (
        key_annots,
        PdfArray([
          PdfDictionary([
            (key_rect, page_flip_rect_for_test(20.0, 30.0, 40.0, 50.0)),
          ]),
        ]),
      ),
    ]),
    mediabox=page_flip_rect_for_test(10.0, 20.0, 110.0, 220.0),
  )
  let second = page_flip_page_for_test([Op_BT, Op_ET])
  let document = page_flip_document_for_test([first, second])
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

  let flipped = try! document.flip_pages_vertically([1])
  let pages = try! flipped.pages_of_pagetree()
  @test.assert_eq(
    pages[0].mediabox,
    page_flip_rect_for_test(10.0, 20.0, 110.0, 220.0),
  )
  @test.assert_eq(page_flip_ops_for_test(flipped, pages[0]), [
    Op_cm(flip_matrix),
    Op_scnName(pattern_name, []),
    Op_S,
  ])
  @test.assert_eq(page_flip_ops_for_test(flipped, pages[1]), [Op_BT, Op_ET])
  guard pages[0].rest.lookup_immediate(key_annots)
    is Some(PdfArray([PdfDictionary(_) as annotation])) else {
    fail("expected flipped direct annotation")
  }
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(page_flip_rect_for_test(20.0, 190.0, 40.0, 210.0)),
  )
  guard pages[0].resources.lookup_immediate(key_pattern)
    is Some(PdfDictionary([(name, PdfIndirect(number))])) &&
    name == pattern_name else {
    fail("expected flipped page pattern to be cloned")
  }
  @test.assert_eq(
    flipped.lookup_object_or_null(number).lookup_immediate(key_matrix),
    Some(
      @pdflite.pdf_object_of_matrix(
        @geometry.transform_matrix_compose(flip_matrix, old_matrix),
      ),
    ),
  )
  let flipped_numbers = try! flipped.page_reference_numbers()
  guard flipped
    .lookup_object_or_null(flipped.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected flipped document open action")
  }
  @test.assert_eq(
    flipped.direct(open_action),
    PdfArray([
      PdfIndirect(flipped_numbers[0]),
      PdfNameObject(xyz_name),
      PdfReal(1.0),
      PdfReal(238.0),
      PdfNull,
    ]),
  )
  let method_alias = try! document.vflip_pdf([1])
  let alias_pages = try! method_alias.pages_of_pagetree()
  @test.assert_eq(page_flip_ops_for_test(method_alias, alias_pages[0]), [
    Op_cm(flip_matrix),
    Op_scnName(pattern_name, []),
    Op_S,
  ])
}

///|
test "PdfDocument flip_pages_horizontally transforms selected pages and wrapper" {
  let horizontal_matrix = @geometry.transform_scale(
    @geometry.point2(60.0, 0.0),
    -1.0,
    1.0,
  )
  let document = page_flip_document_for_test([
    page_flip_page_for_test(
      [Op_S],
      mediabox=page_flip_rect_for_test(10.0, 20.0, 110.0, 220.0),
    ),
    page_flip_page_for_test([Op_BT, Op_ET]),
  ])
  let flipped = try! @pdflite.pdf_hflip_pdf(document, [1])
  let pages = try! flipped.pages_of_pagetree()
  @test.assert_eq(page_flip_ops_for_test(flipped, pages[0]), [
    Op_cm(horizontal_matrix),
    Op_S,
  ])
  @test.assert_eq(page_flip_ops_for_test(flipped, pages[1]), [Op_BT, Op_ET])
  let method_alias = try! document.hflip_pdf([1])
  let alias_pages = try! method_alias.pages_of_pagetree()
  @test.assert_eq(page_flip_ops_for_test(method_alias, alias_pages[0]), [
    Op_cm(horizontal_matrix),
    Op_S,
  ])
}

///|
test "PdfDocument flip pages validate selected pages" {
  let document = page_flip_document_for_test([page_flip_page_for_test([Op_S])])
  let bad_vertical : Result[@pdflite.PdfDocument, Error] = try? document.flip_pages_vertically([
      2,
    ],
  )
  guard bad_vertical
    is Err(
      @core.PdfError::BadPageSpecification(
        "flip_pages_vertically: range contains pages not present in pdf"
      )
    ) else {
    fail("expected vertical flip page range validation")
  }

  let bad_horizontal : Result[@pdflite.PdfDocument, Error] = try? document.flip_pages_horizontally([
      2,
    ],
  )
  guard bad_horizontal
    is Err(
      @core.PdfError::BadPageSpecification(
        "flip_pages_horizontally: range contains pages not present in pdf"
      )
    ) else {
    fail("expected horizontal flip page range validation")
  }
}

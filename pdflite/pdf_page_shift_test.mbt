///|
fn page_shift_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_shift_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn page_shift_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn page_shift_page_for_test(
  ops : ArrayView[@content.PdfContentOp],
  resources? : @syntax.PdfObject = PdfDictionary([]),
  rest? : @syntax.PdfObject = PdfDictionary([]),
) -> @page.PdfPage {
  {
    content: [page_shift_stream_for_test(ops)],
    mediabox: page_shift_rect_for_test(0.0, 0.0, 100.0, 100.0),
    resources,
    rotate: Rotate0,
    rest,
  }
}

///|
fn page_shift_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  try! (try! @pdflite.pdf_blank_document(100.0, 100.0, pages.length())).change_pages(
    pages,
  )
}

///|
fn page_shift_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "PdfDocument shift_pages transforms content annotations and pattern matrices" {
  let key_annots = page_shift_name_for_test("/Annots")
  let key_rect = page_shift_name_for_test("/Rect")
  let key_pattern = page_shift_name_for_test("/Pattern")
  let key_matrix = page_shift_name_for_test("/Matrix")
  let pattern_name = page_shift_name_for_test("/P1")
  let old_matrix = @geometry.transform_translate(1.0, 2.0)
  let first = page_shift_page_for_test(
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
            (key_rect, page_shift_rect_for_test(0.0, 0.0, 10.0, 20.0)),
          ]),
        ]),
      ),
    ]),
  )
  let second = page_shift_page_for_test([Op_S])
  let document = page_shift_document_for_test([first, second])
  let shifted = try! document.shift_pages([1], [(10.0, 20.0)])
  let pages = try! shifted.pages_of_pagetree()
  @test.assert_eq(page_shift_ops_for_test(shifted, pages[0]), [
    Op_cm(@geometry.transform_translate(10.0, 20.0)),
    Op_scnName(pattern_name, []),
    Op_S,
  ])
  @test.assert_eq(page_shift_ops_for_test(shifted, pages[1]), [Op_S])
  guard pages[0].rest.lookup_immediate(key_annots)
    is Some(PdfArray([PdfDictionary(_) as annotation])) else {
    fail("expected shifted direct annotation")
  }
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(page_shift_rect_for_test(10.0, 20.0, 20.0, 40.0)),
  )
  guard pages[0].resources.lookup_immediate(key_pattern)
    is Some(PdfDictionary([(name, PdfIndirect(number))])) &&
    name == pattern_name else {
    fail("expected shifted page pattern to be cloned")
  }
  @test.assert_eq(
    shifted.lookup_object_or_null(number).lookup_immediate(key_matrix),
    Some(
      @pdflite.pdf_object_of_matrix(
        @geometry.transform_matrix_compose(
          @geometry.transform_translate(10.0, 20.0),
          old_matrix,
        ),
      ),
    ),
  )
}

///|
test "change_pattern_matrices_page exposes cpdfpage pattern rewrite helper" {
  let key_pattern = page_shift_name_for_test("/Pattern")
  let key_matrix = page_shift_name_for_test("/Matrix")
  let pattern_name = page_shift_name_for_test("/P1")
  let old_matrix = @geometry.transform_translate(1.0, 2.0)
  let page = page_shift_page_for_test(
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
  )
  let document = page_shift_document_for_test([page])
  let matrix = @geometry.transform_translate(10.0, 20.0)
  let rewritten = try! document.change_pattern_matrices_page(matrix, page)
  guard rewritten.resources.lookup_immediate(key_pattern)
    is Some(PdfDictionary([(name, PdfIndirect(number))])) &&
    name == pattern_name else {
    fail("expected page pattern to be cloned through public method")
  }
  @test.assert_eq(
    document.lookup_object_or_null(number).lookup_immediate(key_matrix),
    Some(
      @pdflite.pdf_object_of_matrix(
        @geometry.transform_matrix_compose(matrix, old_matrix),
      ),
    ),
  )
  let wrapper_page = page_shift_page_for_test(
    [Op_SCNName(pattern_name, [])],
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
  let wrapper_document = page_shift_document_for_test([wrapper_page])
  let wrapper_rewritten = try! @pdflite.pdf_change_pattern_matrices_page(
    wrapper_document, matrix, wrapper_page,
  )
  guard wrapper_rewritten.resources.lookup_immediate(key_pattern)
    is Some(PdfDictionary([(wrapper_name, PdfIndirect(wrapper_number))])) &&
    wrapper_name == pattern_name else {
    fail("expected page pattern to be cloned through cpdf wrapper")
  }
  @test.assert_eq(
    wrapper_document
    .lookup_object_or_null(wrapper_number)
    .lookup_immediate(key_matrix),
    Some(
      @pdflite.pdf_object_of_matrix(
        @geometry.transform_matrix_compose(matrix, old_matrix),
      ),
    ),
  )
}

///|
test "PdfDocument shift_pages transforms open-action destinations" {
  let key_open_action = page_shift_name_for_test("/OpenAction")
  let xyz_name = page_shift_name_for_test("/XYZ")
  let document = page_shift_document_for_test([page_shift_page_for_test([Op_S])])
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
  let shifted = try! @pdflite.pdf_shift_pages(document, [1], [(10.0, 20.0)])
  let shifted_numbers = try! shifted.page_reference_numbers()
  guard shifted
    .lookup_object_or_null(shifted.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected shifted document open action")
  }
  @test.assert_eq(
    shifted.direct(open_action),
    PdfArray([
      PdfIndirect(shifted_numbers[0]),
      PdfNameObject(xyz_name),
      PdfReal(11.0),
      PdfReal(22.0),
      PdfNull,
    ]),
  )
}

///|
test "cpdf shift_pdf wrapper uses absolute page-indexed offsets" {
  let document = page_shift_document_for_test([
    page_shift_page_for_test([Op_S]),
    page_shift_page_for_test([Op_BT, Op_ET]),
  ])
  let shifted = try! @pdflite.pdf_shift_pdf(
    [(100.0, 200.0), (10.0, 20.0)],
    document,
    [2],
  )
  let pages = try! shifted.pages_of_pagetree()
  @test.assert_eq(page_shift_ops_for_test(shifted, pages[0]), [Op_S])
  @test.assert_eq(page_shift_ops_for_test(shifted, pages[1]), [
    Op_cm(@geometry.transform_translate(10.0, 20.0)),
    Op_BT,
    Op_ET,
  ])
}

///|
test "PdfDocument shift_pages rejects invalid offset lists" {
  let document = page_shift_document_for_test([page_shift_page_for_test([Op_S])])
  let mismatch : Result[@pdflite.PdfDocument, Error] = try
    document.shift_pages([1], [])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard mismatch
    is Err(
      @core.PdfError::BadPageSpecification(
        "shift_pages: offset count must match page count"
      )
    ) else {
    fail("expected offset count validation")
  }
  let bad_page : Result[@pdflite.PdfDocument, Error] = try
    document.shift_pages([2], [(0.0, 0.0)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page
    is Err(
      @core.PdfError::BadPageSpecification(
        "shift_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected page range validation")
  }

  let cpdf_mismatch : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_shift_pdf([], document, [1])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard cpdf_mismatch
    is Err(
      @core.PdfError::BadPageSpecification(
        "shift_pdf: offset count must match page count"
      )
    ) else {
    fail("expected cpdf shift_pdf offset count validation")
  }
}

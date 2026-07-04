///|
fn redact_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn redact_rectangle_array_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn redact_annotation_object_for_test(
  subtype : String,
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfDictionary([
    (
      redact_name_for_test("/Subtype"),
      PdfNameObject(redact_name_for_test(subtype)),
    ),
    (
      redact_name_for_test("/Rect"),
      redact_rectangle_array_for_test(min_x, min_y, max_x, max_y),
    ),
  ])
}

///|
fn redact_content_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
fn redact_expected_annotation_box_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
  light : Bool,
) -> Array[@content.PdfContentOp] {
  let stroke : @content.PdfContentOp = if light {
    Op_RG(1.0, 1.0, 0.5)
  } else {
    Op_RG(1.0, 1.0, 0.0)
  }
  [
    stroke,
    Op_w(1.0),
    Op_m(min_x, min_y),
    Op_l(min_x, max_y),
    Op_l(max_x, max_y),
    Op_l(max_x, min_y),
    Op_l(min_x, min_y),
    Op_h,
    Op_S,
  ]
}

///|
fn redact_expected_path_content_box_for_test(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  light : Bool,
) -> Array[@content.PdfContentOp] {
  let stroke : @content.PdfContentOp = if light {
    Op_RG(0.5, 0.5, 1.0)
  } else {
    Op_RG(0.0, 0.0, 1.0)
  }
  [
    Op_q,
    stroke,
    Op_w(0.5),
    Op_m(x0, y0),
    Op_l(x1, y1),
    Op_l(x2, y2),
    Op_l(x3, y3),
    Op_h,
    Op_S,
    Op_Q,
  ]
}

///|
fn redact_concat_ops_for_test(
  first : ArrayView[@content.PdfContentOp],
  second : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = []
  for op in first {
    output.push(op)
  }
  for op in second {
    output.push(op)
  }
  output
}

///|
test "PdfDocument redact_path preserves content and validates selected pages" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let document = try! base.change_pages([
    {
      ..pages[0],
      content: [try! @pdflite.pdf_content_stream_of_ops([Op_BT, Op_ET])],
    },
    pages[1],
  ])
  let path : ReadOnlyArray[(Double, Double)] = [
    (0.0, 0.0),
    (10.0, 10.0),
    (20.0, 0.0),
  ]
  let redacted = try! document.redact_path(path, [1])
  let wrapper = try! @pdflite.pdf_redact(document, path, [1])
  let redacted_pages = try! redacted.pages_of_pagetree()
  let wrapper_pages = try! wrapper.pages_of_pagetree()
  @test.assert_eq(redact_content_ops_for_test(redacted, redacted_pages[0]), [
    Op_BT,
    Op_ET,
  ])
  @test.assert_eq(redact_content_ops_for_test(redacted, redacted_pages[1]), [])
  @test.assert_eq(redact_content_ops_for_test(wrapper, wrapper_pages[0]), [
    Op_BT,
    Op_ET,
  ])
  let bad_page : Result[@pdflite.PdfDocument, Error] = try
    document.redact_path(path, [3])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page is Err(@core.PdfError::BadPageSpecification(_)) else {
    fail("expected @core.PdfError::BadPageSpecification")
  }
}

///|
test "redaction apply stubs leave documents untouched" {
  let document = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  document.apply_redactions([99])
  @pdflite.pdf_apply_redactions(document, [99])
  @pdflite.pdf_apply(document, [99])
  document.apply_redaction_type("Square", [99])
  @pdflite.pdf_apply_redaction_type(document, "Square", [99])
  @pdflite.pdf_apply_type(document, "Square", [99])
  @test.assert_eq((try! document.pages_of_pagetree()).length(), 1)
}

///|
test "PdfDocument show_annotation_bounding_boxes draws selected annotation rectangles" {
  let key_annots = redact_name_for_test("/Annots")
  let direct_annotation = redact_annotation_object_for_test(
    "/Text", 10.0, 20.0, 30.0, 40.0,
  )
  let indirect_annotation = redact_annotation_object_for_test(
    "/Link", 50.0, 60.0, 70.0, 80.0,
  )
  let unselected_annotation = redact_annotation_object_for_test(
    "/Square", 1.0, 2.0, 3.0, 4.0,
  )
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  base.add_object_given_number(50, indirect_annotation)
  let pages = try! base.pages_of_pagetree()
  let document = try! base.change_pages([
    {
      ..pages[0],
      rest: PdfDictionary([
        (key_annots, PdfArray([direct_annotation, PdfIndirect(50)])),
      ]),
    },
    {
      ..pages[1],
      rest: PdfDictionary([(key_annots, PdfArray([unselected_annotation]))]),
    },
  ])

  let boxed = try! document.show_annotation_bounding_boxes([1])
  let boxed_pages = try! boxed.pages_of_pagetree()
  @test.assert_eq(
    redact_content_ops_for_test(boxed, boxed_pages[0]),
    redact_concat_ops_for_test(
      redact_expected_annotation_box_for_test(10.0, 20.0, 30.0, 40.0, false),
      redact_expected_annotation_box_for_test(50.0, 60.0, 70.0, 80.0, false),
    ),
  )
  @test.assert_eq(redact_content_ops_for_test(boxed, boxed_pages[1]), [])
}

///|
test "pdf_show_annotation_bounding_boxes supports light fast overlay" {
  let key_annots = redact_name_for_test("/Annots")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let pages = try! base.pages_of_pagetree()
  let page = {
    ..pages[0],
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_BT, Op_ET])],
    rest: PdfDictionary([
      (
        key_annots,
        PdfArray([
          redact_annotation_object_for_test("/Text", 4.0, 5.0, 6.0, 7.0),
        ]),
      ),
    ]),
  }
  let document = try! base.change_pages([page])
  let boxed = try! @pdflite.pdf_show_annotation_bounding_boxes(
    document,
    [1],
    light=true,
    fast=true,
  )
  let boxed_page = (try! boxed.pages_of_pagetree())[0]
  let expected = redact_concat_ops_for_test(
    [Op_BT, Op_ET, Op_q],
    redact_concat_ops_for_test(
      redact_expected_annotation_box_for_test(4.0, 5.0, 6.0, 7.0, true),
      [Op_Q],
    ),
  )
  @test.assert_eq(redact_content_ops_for_test(boxed, boxed_page), expected)
}

///|
test "PdfDocument show_bounding_boxes draws page content rectangles" {
  let base = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let source_ops : Array[@content.PdfContentOp] = [
    Op_m(10.0, 20.0),
    Op_l(30.0, 20.0),
    Op_S,
  ]
  let document = try! base.change_pages([
    {
      ..pages[0],
      content: [try! @pdflite.pdf_content_stream_of_ops(source_ops)],
    },
    pages[1],
  ])
  let boxed = try! document.show_bounding_boxes([1])
  let boxed_pages = try! boxed.pages_of_pagetree()
  let expected_box = redact_expected_path_content_box_for_test(
    9.5, 19.5, 9.5, 20.5, 30.5, 20.5, 30.5, 19.5, false,
  )
  @test.assert_eq(
    redact_content_ops_for_test(boxed, boxed_pages[0]),
    redact_concat_ops_for_test([Op_q, ..source_ops, Op_Q], expected_box),
  )
  @test.assert_eq(redact_content_ops_for_test(boxed, boxed_pages[1]), [])
  let source_order = try! @pdflite.pdf_show_bounding_boxes_cpdf_order(
    false,
    None,
    false,
    document,
    [1],
  )
  let source_order_page = (try! source_order.pages_of_pagetree())[0]
  @test.assert_eq(
    redact_content_ops_for_test(source_order, source_order_page),
    redact_content_ops_for_test(boxed, boxed_pages[0]),
  )
  let filtered = try! @pdflite.pdf_show_bounding_boxes(
    document,
    [1],
    shape=Some({ min_x: 0.0, min_y: 0.0, max_x: 5.0, max_y: 5.0 }),
    light=true,
    fast=true,
  )
  let filtered_page = (try! filtered.pages_of_pagetree())[0]
  @test.assert_eq(
    redact_content_ops_for_test(filtered, filtered_page),
    source_ops,
  )
  let filtered_source_order = try! @pdflite.pdf_show_bounding_boxes_cpdf_order(
    true,
    Some({ min_x: 0.0, min_y: 0.0, max_x: 5.0, max_y: 5.0 }),
    true,
    document,
    [1],
  )
  let filtered_source_order_page = (try! filtered_source_order.pages_of_pagetree())[0]
  @test.assert_eq(
    redact_content_ops_for_test(
      filtered_source_order, filtered_source_order_page,
    ),
    redact_content_ops_for_test(filtered, filtered_page),
  )
}

///|
fn redact_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn redact_rectangle_array_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn redact_annotation_object_for_test(
  subtype : String,
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
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
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
fn redact_expected_annotation_box_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
  light : Bool,
) -> Array[@pdflite.PdfContentOp] {
  let stroke : @pdflite.PdfContentOp = if light {
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
fn redact_concat_ops_for_test(
  first : ArrayView[@pdflite.PdfContentOp],
  second : ArrayView[@pdflite.PdfContentOp],
) -> Array[@pdflite.PdfContentOp] {
  let output : Array[@pdflite.PdfContentOp] = []
  for op in first {
    output.push(op)
  }
  for op in second {
    output.push(op)
  }
  output
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

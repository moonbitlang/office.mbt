///|
fn addtext_annot_assert_close_for_test(
  actual : Double,
  expected : Double,
) -> Unit raise {
  if (actual - expected).abs() > 0.000000001 {
    fail("addtext values were not close enough")
  }
}

///|
fn addtext_annot_assert_point_close_for_test(
  actual : @geometry.Point2,
  expected : @geometry.Point2,
) -> Unit raise {
  addtext_annot_assert_close_for_test(actual.x, expected.x)
  addtext_annot_assert_close_for_test(actual.y, expected.y)
}

///|
fn addtext_annot_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn addtext_annot_bounds_for_test() -> @geometry.PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 50.0 }
}

///|
fn addtext_annot_content_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
fn addtext_annot_font_descriptor_for_test(
  capheight : Double,
) -> @pdflite.PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
    italicangle: 0.0,
    capheight,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
fn addtext_annot_simple_font_for_test(capheight : Double) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: -1,
    widths: [],
    fontdescriptor: Some(addtext_annot_font_descriptor_for_test(capheight)),
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
test "pdf_addtext_url_annotation builds cpdf link annotation objects" {
  let annotation = @pdflite.pdf_addtext_url_annotation(
    @geometry.point2(1.0, 2.0),
    @geometry.point2(3.0, 4.0),
    @geometry.point2(5.0, 6.0),
    @geometry.point2(7.0, 8.0),
    { min_x: 1.0, min_y: 2.0, max_x: 7.0, max_y: 8.0 },
    "https://example.test",
    true,
  )
  let expected : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_annot_name_for_test("/Subtype"),
      PdfNameObject(addtext_annot_name_for_test("/Link")),
    ),
    (
      addtext_annot_name_for_test("/QuadPoints"),
      PdfArray([
        PdfReal(1.0),
        PdfReal(2.0),
        PdfReal(7.0),
        PdfReal(8.0),
        PdfReal(3.0),
        PdfReal(4.0),
        PdfReal(5.0),
        PdfReal(6.0),
      ]),
    ),
    (
      addtext_annot_name_for_test("/Rect"),
      PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(7.0), PdfReal(8.0)]),
    ),
    (
      addtext_annot_name_for_test("/BS"),
      PdfDictionary([(addtext_annot_name_for_test("/W"), PdfInteger(1))]),
    ),
    (
      addtext_annot_name_for_test("/A"),
      PdfDictionary([
        (
          addtext_annot_name_for_test("/URI"),
          PdfString(@utf8.encode("https://example.test")),
        ),
        (
          addtext_annot_name_for_test("/Type"),
          PdfNameObject(addtext_annot_name_for_test("/Action")),
        ),
        (
          addtext_annot_name_for_test("/S"),
          PdfNameObject(addtext_annot_name_for_test("/URI")),
        ),
      ]),
    ),
  ])
  @test.assert_eq(annotation, expected)
  let hidden_border = @pdflite.pdf_addtext_url_annotation(
    @geometry.point2(1.0, 2.0),
    @geometry.point2(3.0, 4.0),
    @geometry.point2(5.0, 6.0),
    @geometry.point2(7.0, 8.0),
    addtext_annot_bounds_for_test(),
    "https://example.test",
    false,
  )
  guard hidden_border.lookup_immediate(addtext_annot_name_for_test("/BS"))
    is Some(bs) else {
    fail("expected URL border dictionary")
  }
  @test.assert_eq(
    bs.lookup_immediate(addtext_annot_name_for_test("/W")),
    Some(PdfInteger(0)),
  )
}

///|
test "pdf_addtext_url_annotation_height uses cap height and font-size fallback" {
  addtext_annot_assert_close_for_test(
    @pdflite.pdf_addtext_url_annotation_height(None, "Helvetica", 10.0),
    7.18,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_url_annotation_height(None, "NotAFont", 10.0),
    10.0,
  )
}

///|
test "pdf_addtext_url_annotation_geometry builds unrotated quads and bounds" {
  let geometry = @pdflite.pdf_addtext_url_annotation_geometry(
    @geometry.point2(100.0, 200.0),
    10.0,
    20.0,
    5.0,
    0.0,
    @geometry.point2(0.0, 0.0),
    0.0,
    3.0,
    13.0,
    7.0,
  )
  @test.assert_eq(geometry.p0, @geometry.point2(88.0, 180.0))
  @test.assert_eq(geometry.p1, @geometry.point2(98.0, 187.0))
  @test.assert_eq(geometry.p2, @geometry.point2(88.0, 187.0))
  @test.assert_eq(geometry.p3, @geometry.point2(98.0, 180.0))
  @test.assert_eq(geometry.rectangle, {
    min_x: 88.0,
    min_y: 180.0,
    max_x: 98.0,
    max_y: 187.0,
  })
}

///|
test "pdf_addtext_url_annotation_geometry applies rotation before offset" {
  let geometry = @pdflite.pdf_addtext_url_annotation_geometry(
    @geometry.point2(10.0, 20.0),
    0.0,
    0.0,
    0.0,
    @math.PI / 2.0,
    @geometry.point2(1.0, 2.0),
    0.0,
    0.0,
    4.0,
    2.0,
  )
  addtext_annot_assert_point_close_for_test(
    geometry.p0,
    @geometry.point2(11.0, 22.0),
  )
  addtext_annot_assert_point_close_for_test(
    geometry.p1,
    @geometry.point2(9.0, 26.0),
  )
  addtext_annot_assert_point_close_for_test(
    geometry.p2,
    @geometry.point2(9.0, 22.0),
  )
  addtext_annot_assert_point_close_for_test(
    geometry.p3,
    @geometry.point2(11.0, 26.0),
  )
  addtext_annot_assert_close_for_test(geometry.rectangle.min_x, 9.0)
  addtext_annot_assert_close_for_test(geometry.rectangle.min_y, 22.0)
  addtext_annot_assert_close_for_test(geometry.rectangle.max_x, 11.0)
  addtext_annot_assert_close_for_test(geometry.rectangle.max_y, 26.0)
}

///|
test "pdf_addtext_url_annotation_widths measures span prefixes" {
  let span : @addtext.PdfAddTextUrl = { url: "u", start: 1, end: 4 }
  @test.assert_eq(
    try! @pdflite.pdf_addtext_url_annotation_widths("abcde", span, fn(prefix) {
      prefix.length().to_double() * 2.0
    }),
    (2.0, 8.0),
  )
}

///|
test "pdf_addtext_url_annotation_widths uses UTF-8 byte offsets" {
  let span : @addtext.PdfAddTextUrl = { url: "u", start: 2, end: 3 }
  @test.assert_eq(
    try! @pdflite.pdf_addtext_url_annotation_widths("éx", span, fn(prefix) {
      @utf8.encode(prefix).length().to_double()
    }),
    (2.0, 3.0),
  )
  let bad : Result[(Double, Double), Error] = try? @pdflite.pdf_addtext_url_annotation_widths(
    "é",
    { url: "u", start: 1, end: 2 },
    fn(prefix) { prefix.length().to_double() },
  )
  guard bad is Err(@pdflite.PdfError::SoftError("bad add-text URL byte offset")) else {
    fail("expected invalid UTF-8 span offset to raise SoftError")
  }
}

///|
test "PdfDocument addtext_url_annotation_references creates indirect links" {
  let document = @pdflite.pdf_document_empty()
  let urls : Array[@addtext.PdfAddTextUrl] = [
    { url: "https://a.test", start: 1, end: 3 },
    { url: "https://b.test", start: 0, end: 4 },
  ]
  let refs = try! document.addtext_url_annotation_references(
    "abcd",
    urls,
    fn(prefix) { prefix.length().to_double() * 2.0 },
    @geometry.point2(100.0, 200.0),
    10.0,
    20.0,
    5.0,
    0.0,
    @geometry.point2(0.0, 0.0),
    0.0,
    None,
    "NotAFont",
    7.0,
    true,
  )
  @test.assert_eq(refs.length(), 2)
  guard refs[0] is PdfIndirect(first_number) else {
    fail("expected first annotation reference")
  }
  let first = document.lookup_object_or_null(first_number)
  guard first is PdfDictionary(_) else {
    fail("expected first annotation object")
  }
  @test.assert_eq(
    first.lookup_immediate(addtext_annot_name_for_test("/Rect")),
    Some(
      PdfArray([PdfReal(87.0), PdfReal(180.0), PdfReal(91.0), PdfReal(187.0)]),
    ),
  )
  @test.assert_eq(
    first.lookup_immediate(addtext_annot_name_for_test("/QuadPoints")),
    Some(
      PdfArray([
        PdfReal(87.0),
        PdfReal(180.0),
        PdfReal(91.0),
        PdfReal(180.0),
        PdfReal(91.0),
        PdfReal(187.0),
        PdfReal(87.0),
        PdfReal(187.0),
      ]),
    ),
  )
  guard first.lookup_immediate(addtext_annot_name_for_test("/A"))
    is Some(action) else {
    fail("expected link action")
  }
  @test.assert_eq(
    action.lookup_immediate(addtext_annot_name_for_test("/URI")),
    Some(PdfString(@utf8.encode("https://a.test"))),
  )
}

///|
test "pdf_addtext_url_annotation_references wrapper propagates measure errors" {
  let document = @pdflite.pdf_document_empty()
  let urls : Array[@addtext.PdfAddTextUrl] = [
    { url: "https://a.test", start: 0, end: 2 },
  ]
  let result : Result[Array[@pdflite.PdfObject], Error] = try? @pdflite.pdf_addtext_url_annotation_references(
    document,
    "ab",
    urls,
    fn(prefix) raise @pdflite.PdfError {
      if prefix.length() == 2 {
        raise SoftError("measure failed")
      }
      prefix.length().to_double()
    },
    @geometry.point2(0.0, 0.0),
    0.0,
    0.0,
    0.0,
    0.0,
    @geometry.point2(0.0, 0.0),
    0.0,
    Some(addtext_annot_simple_font_for_test(500.0)),
    "Ignored",
    10.0,
    false,
  )
  guard result is Err(@pdflite.PdfError::SoftError("measure failed")) else {
    fail("expected measure error")
  }
}

///|
test "pdf_addtext_page_rest_with_annotations preserves empty annotation updates" {
  let document = @pdflite.pdf_document_empty()
  let rest : @pdflite.PdfObject = PdfInteger(7)
  let annotations : Array[@pdflite.PdfObject] = []
  @test.assert_eq(
    try! document.addtext_page_rest_with_annotations(rest, annotations),
    rest,
  )
}

///|
test "pdf_addtext_page_rest_with_annotations prepends resolved existing arrays" {
  let document = @pdflite.pdf_document_empty()
  let existing_number = document.add_object(PdfArray([PdfIndirect(30)]))
  let key_annots = addtext_annot_name_for_test("/Annots")
  let key_other = addtext_annot_name_for_test("/Other")
  let rest : @pdflite.PdfObject = PdfDictionary([
    (key_annots, PdfIndirect(existing_number)),
    (key_other, PdfInteger(5)),
  ])
  let annotations : Array[@pdflite.PdfObject] = [
    PdfIndirect(10),
    PdfIndirect(11),
  ]
  let updated = try! document.addtext_page_rest_with_annotations(
    rest, annotations,
  )
  @test.assert_eq(
    updated.lookup_immediate(key_annots),
    Some(PdfArray([PdfIndirect(10), PdfIndirect(11), PdfIndirect(30)])),
  )
  @test.assert_eq(updated.lookup_immediate(key_other), Some(PdfInteger(5)))
}

///|
test "pdf_addtext_page_rest_with_annotations treats malformed annots as empty" {
  let document = @pdflite.pdf_document_empty()
  let key_annots = addtext_annot_name_for_test("/Annots")
  let rest : @pdflite.PdfObject = PdfDictionary([(key_annots, PdfInteger(99))])
  let annotations : Array[@pdflite.PdfObject] = [PdfIndirect(20)]
  let updated = try! @pdflite.pdf_addtext_page_rest_with_annotations(
    document, rest, annotations,
  )
  @test.assert_eq(
    updated.lookup_immediate(key_annots),
    Some(PdfArray([PdfIndirect(20)])),
  )
}

///|
test "pdf_addtext_rectangle_origin lowers top positions by rectangle height" {
  let bounds = addtext_annot_bounds_for_test()
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionTopLeft(3.0, 4.0),
      20.0,
      10.0,
    ),
    (3.0, 36.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionTop(5.0),
      20.0,
      10.0,
    ),
    (40.0, 35.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionTopRight(3.0, 4.0),
      20.0,
      10.0,
    ),
    (77.0, 36.0),
  )
}

///|
test "pdf_addtext_rectangle_origin handles center and unchanged positions" {
  let bounds = addtext_annot_bounds_for_test()
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(bounds, PdfPositionCentre, 20.0, 10.0),
    (40.0, 20.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionPosCentre(50.0, 4.0),
      20.0,
      10.0,
    ),
    (40.0, -1.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionBottomLeft(3.0, 4.0),
      20.0,
      10.0,
    ),
    (3.0, 4.0),
  )
}

///|
test "PdfDocument addtext_rectangle appends selected page rectangle" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 2)
  let stamped = try! document.addtext_rectangle(
    [2],
    "20 10",
    PdfContentRGB(1.0, 0.0, 0.0),
    PdfPositionTopRight(3.0, 4.0),
  )
  let pages = try! stamped.pages_of_pagetree()
  @test.assert_eq(pages[0].content.length(), 0)
  @test.assert_eq(
    addtext_annot_content_ops_for_test(stamped, pages[1]),
    @pdflite.pdf_addtext_rectangle_ops(
      77.0,
      36.0,
      20.0,
      10.0,
      PdfContentRGB(1.0, 0.0, 0.0),
      false,
      1.0,
      None,
    ),
  )
}

///|
test "PdfDocument addtext_rectangle handles relative box opacity and underneath fast mode" {
  let base = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let pages = try! base.pages_of_pagetree()
  let cropbox = addtext_annot_name_for_test("/CropBox")
  let extgstate = addtext_annot_name_for_test("/ExtGState")
  let gs = addtext_annot_name_for_test("/gs0")
  let ca = addtext_annot_name_for_test("/ca")
  let ca_stroke = addtext_annot_name_for_test("/CA")
  let page = {
    ..pages[0],
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_BT, Op_ET])],
    rest: @pdflite.pdf_dictionary([
      (
        cropbox,
        PdfArray([PdfReal(10.0), PdfReal(20.0), PdfReal(70.0), PdfReal(40.0)]),
      ),
    ]),
  }
  let document = try! base.change_pages([page])
  let stamped = try! @pdflite.pdf_addtext_rectangle(
    document,
    [1],
    "20 10",
    PdfContentGrey(0.5),
    PdfPositionCentre,
    relative_to_box=cropbox,
    outline=true,
    line_width=1.25,
    opacity=0.5,
    underneath=true,
    fast=true,
  )
  let source_order = try! @pdflite.pdf_addrectangle(
    true,
    "20 10",
    PdfContentGrey(0.5),
    true,
    1.25,
    0.5,
    PdfPositionCentre,
    "/CropBox",
    true,
    [1],
    document,
  )
  let stamped_pages = try! stamped.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(
    addtext_annot_content_ops_for_test(stamped, stamped_pages[0]),
    [
      ..@pdflite.pdf_addtext_rectangle_ops(
        30.0,
        25.0,
        20.0,
        10.0,
        PdfContentGrey(0.5),
        true,
        1.25,
        Some(gs),
      ),
      Op_BT,
      Op_ET,
    ],
  )
  @test.assert_eq(
    addtext_annot_content_ops_for_test(source_order, source_order_pages[0]),
    addtext_annot_content_ops_for_test(stamped, stamped_pages[0]),
  )
  guard stamped.lookup_direct(extgstate, stamped_pages[0].resources)
    is Some(resource_dictionary) else {
    fail("expected ExtGState resource dictionary")
  }
  guard stamped.lookup_direct(gs, resource_dictionary)
    is Some(opacity_dictionary) else {
    fail("expected generated opacity graphics state")
  }
  @test.assert_eq(
    stamped.lookup_direct(ca, opacity_dictionary),
    Some(PdfReal(0.5)),
  )
  @test.assert_eq(
    stamped.lookup_direct(ca_stroke, opacity_dictionary),
    Some(PdfReal(0.5)),
  )
}

///|
test "PdfDocument addtext_rectangle reports bad coordinate specifications" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let result : Result[@pdflite.PdfDocument, Error] = try? document.addtext_rectangle(
    [1],
    "10 20 30",
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(0.0, 0.0),
  )
  guard result
    is Err(@pdflite.PdfError::SoftError("bad coordinate specification")) else {
    fail("expected SoftError for addtext rectangle coordinate arity")
  }
}

///|
test "PdfDocument addtext_rectangle validates selected pages" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let result : Result[@pdflite.PdfDocument, Error] = try? document.addtext_rectangle(
    [2],
    "10 20",
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(0.0, 0.0),
  )
  guard result
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "addtext_rectangle: range contains pages not present in pdf"
      )
    ) else {
    fail(
      "expected BadPageSpecification for out-of-range addtext rectangle page",
    )
  }
}

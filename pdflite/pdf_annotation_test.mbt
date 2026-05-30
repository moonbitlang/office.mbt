///|
fn annotation_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn annotation_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @geometry.PdfRectangle {
  { min_x, min_y, max_x, max_y }
}

///|
fn annotation_contents_for_test(text : String) -> @syntax.PdfObject {
  PdfString(@ascii.encode(text))
}

///|
fn annotation_cpdf_helper_document_for_test() -> @pdflite.PdfDocument raise {
  let key_annots = annotation_name_for_test("/Annots")
  let key_contents = annotation_name_for_test("/Contents")
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  document.add_object_given_number(
    30,
    PdfDictionary([(key_contents, annotation_contents_for_test("second"))]),
  )
  let first_page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    rest: PdfDictionary([
      (
        key_annots,
        PdfArray([
          PdfDictionary([(key_contents, annotation_contents_for_test("first"))]),
        ]),
      ),
    ]),
  }
  let second_page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    rest: PdfDictionary([
      (key_annots, PdfArray([PdfIndirect(30), PdfDictionary([])])),
    ]),
  }
  document.change_pages([first_page, second_page])
}

///|
fn annotation_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn annotation_json_pdf_int_for_test(value : Int) -> Json {
  Json::object(Map([("I", annotation_json_int_for_test(value))]))
}

///|
fn annotation_json_name_for_test(name : String) -> Json {
  Json::object(Map([("N", Json::string(name))]))
}

///|
fn annotation_json_text_for_test(text : String) -> Json {
  Json::object(Map([("U", Json::string(text))]))
}

///|
fn annotation_json_header_for_test() -> Json {
  Json::array([
    annotation_json_int_for_test(-1),
    Json::object(
      Map([("/CPDFJSONannotformatversion", annotation_json_pdf_int_for_test(1))]),
    ),
  ])
}

///|
fn annotation_json_helper_document_for_test() -> @pdflite.PdfDocument {
  let key_annots = annotation_name_for_test("/Annots")
  let key_contents = annotation_name_for_test("/Contents")
  let key_p = annotation_name_for_test("/P")
  let key_dest = annotation_name_for_test("/Dest")
  let key_a = annotation_name_for_test("/A")
  let key_d = annotation_name_for_test("/D")
  let key_ref = annotation_name_for_test("/Ref")
  let key_popup = annotation_name_for_test("/Popup")
  let key_parent = annotation_name_for_test("/Parent")
  let key_extra = annotation_name_for_test("/Extra")
  let type_fit = annotation_name_for_test("/Fit")
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let pages = try! document.pages_of_pagetree()
  let second_page = {
    ..pages[1],
    rest: try! pages[1].rest.add_dict_entry(
      key_annots,
      PdfArray([
        PdfIndirect(30),
        PdfIndirect(31),
        PdfDictionary([(key_contents, annotation_contents_for_test("direct"))]),
      ]),
    ),
  }
  let changed = try! document.change_pages([pages[0], second_page])
  let page_refs = try! changed.page_reference_numbers()
  changed.add_object_given_number(
    30,
    PdfDictionary([
      (key_contents, annotation_contents_for_test("json")),
      (key_p, PdfIndirect(page_refs[1])),
      (
        key_a,
        PdfDictionary([
          (
            key_d,
            PdfArray([PdfIndirect(page_refs[1]), PdfNameObject(type_fit)]),
          ),
        ]),
      ),
      (key_ref, PdfIndirect(40)),
      (key_popup, PdfIndirect(41)),
      (key_parent, PdfIndirect(42)),
    ]),
  )
  changed.add_object_given_number(
    31,
    PdfDictionary([
      (key_contents, annotation_contents_for_test("dest")),
      (key_dest, PdfArray([PdfIndirect(page_refs[0]), PdfNameObject(type_fit)])),
    ]),
  )
  changed.add_object_given_number(
    40,
    PdfDictionary([(key_extra, annotation_contents_for_test("kept"))]),
  )
  changed.add_object_given_number(
    41,
    PdfDictionary([(key_contents, annotation_contents_for_test("popup"))]),
  )
  changed.add_object_given_number(
    42,
    PdfDictionary([(key_contents, annotation_contents_for_test("parent"))]),
  )
  changed
}

///|
test "PdfDocument get_annotations returns old-style page content pairs" {
  let document = try! annotation_cpdf_helper_document_for_test()
  let expected = [
    (1, @ascii.encode("first")),
    (2, @ascii.encode("second")),
    (2, Bytes::new(0)),
  ]
  @test.assert_eq(
    try! document.get_annotations(encoding=PdfMetadataRaw),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_annotations(PdfMetadataRaw, document),
    expected,
  )
}

///|
test "PdfDocument list_annotations renders selected non-empty old-style lines" {
  let document = try! annotation_cpdf_helper_document_for_test()
  let expected = @ascii.encode("Page 1: first\nPage 2: second\n")
  @test.assert_eq(
    try! document.list_annotations([1, 2], encoding=PdfMetadataRaw),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_list_annotations([1, 2], PdfMetadataRaw, document),
    expected,
  )
  @test.assert_eq(
    try! document.list_annotations([2], encoding=PdfMetadataRaw),
    @ascii.encode("Page 2: second\n"),
  )
  let bad_page : Result[@pdflite.PdfBytes, Error] = try? document.list_annotations(
    [3],
    encoding=PdfMetadataRaw,
  )
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected @pdflite.PdfError::BadPageSpecification")
  }
}

///|
test "PdfDocument annotations_json exports cpdf annotation rows" {
  let document = annotation_json_helper_document_for_test()
  let expected_annotation = Json::object(
    Map([
      ("/Contents", annotation_json_text_for_test("json")),
      ("/P", annotation_json_pdf_int_for_test(2)),
      (
        "/A",
        Json::object(
          Map([
            (
              "/D",
              Json::array([
                annotation_json_pdf_int_for_test(2),
                annotation_json_name_for_test("/Fit"),
              ]),
            ),
          ]),
        ),
      ),
      ("/Ref", annotation_json_int_for_test(40)),
      ("/Popup", annotation_json_int_for_test(41)),
      ("/Parent", annotation_json_int_for_test(42)),
    ]),
  )
  let expected_destination_annotation = Json::object(
    Map([
      ("/Contents", annotation_json_text_for_test("dest")),
      (
        "/Dest",
        Json::array([
          annotation_json_pdf_int_for_test(1),
          annotation_json_name_for_test("/Fit"),
        ]),
      ),
    ]),
  )
  let expected_extra = Json::object(
    Map([("/Extra", annotation_json_text_for_test("kept"))]),
  )
  let expected = Json::array([
    annotation_json_header_for_test(),
    Json::array([
      annotation_json_int_for_test(2),
      annotation_json_int_for_test(30),
      expected_annotation,
    ]),
    Json::array([
      annotation_json_int_for_test(2),
      annotation_json_int_for_test(31),
      expected_destination_annotation,
    ]),
    Json::array([annotation_json_int_for_test(40), expected_extra]),
  ])
  @test.assert_eq(try! document.annotations_json([2]), expected)
  @test.assert_eq(
    try! @pdflite.pdf_get_annotations_json([2], document),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_annotations_json_cpdf_order(document, [2]),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! document.annotations_json([1]),
    Json::array([annotation_json_header_for_test()]),
  )
  let bad_page : Result[Json, Error] = try? document.annotations_json([3])
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected @pdflite.PdfError::BadPageSpecification")
  }
}

///|
test "PdfDocument set_annotations_json imports cpdf annotation rows" {
  let key_contents = annotation_name_for_test("/Contents")
  let key_p = annotation_name_for_test("/P")
  let key_dest = annotation_name_for_test("/Dest")
  let key_a = annotation_name_for_test("/A")
  let key_d = annotation_name_for_test("/D")
  let key_ref = annotation_name_for_test("/Ref")
  let key_extra = annotation_name_for_test("/Extra")
  let fit = annotation_name_for_test("/Fit")
  let source = annotation_json_helper_document_for_test()
  let target = try! annotation_cpdf_helper_document_for_test()
  let json = try! source.annotations_json([2])
  let imported = try! target.set_annotations_json(json)
  let wrapper = try! @pdflite.pdf_set_annotations_json(json, target)
  let source_order_wrapper = try! @pdflite.pdf_set_annotations_json_cpdf_order(
    target, json,
  )
  let copied = try! target.copy_annotations_from(source, [2])
  let copied_wrapper = try! @pdflite.pdf_copy_annotations([2], source, target)
  let expected_annotations = [
    (1, @ascii.encode("first")),
    (2, @ascii.encode("second")),
    (2, Bytes::new(0)),
    (2, @ascii.encode("json")),
    (2, @ascii.encode("dest")),
  ]
  @test.assert_eq(try! target.get_annotations(encoding=PdfMetadataRaw), [
    (1, @ascii.encode("first")),
    (2, @ascii.encode("second")),
    (2, Bytes::new(0)),
  ])
  @test.assert_eq(
    try! imported.get_annotations(encoding=PdfMetadataRaw),
    expected_annotations,
  )
  @test.assert_eq(
    try! wrapper.get_annotations(encoding=PdfMetadataRaw),
    expected_annotations,
  )
  @test.assert_eq(
    try! source_order_wrapper.get_annotations(encoding=PdfMetadataRaw),
    expected_annotations,
  )
  @test.assert_eq(
    try! copied.get_annotations(encoding=PdfMetadataRaw),
    expected_annotations,
  )
  @test.assert_eq(
    try! copied_wrapper.get_annotations(encoding=PdfMetadataRaw),
    expected_annotations,
  )
  let page_refs = try! imported.page_reference_numbers()
  guard imported.lookup_object_or_null(30) is PdfDictionary(imported_entries) else {
    fail("expected imported annotation 30")
  }
  let imported_annotation : @syntax.PdfObject = PdfDictionary(imported_entries)
  @test.assert_eq(
    imported_annotation.lookup_immediate(key_contents),
    Some(annotation_contents_for_test("json")),
  )
  @test.assert_eq(
    imported_annotation.lookup_immediate(key_p),
    Some(PdfIndirect(page_refs[1])),
  )
  @test.assert_eq(
    imported_annotation.lookup_immediate(key_ref),
    Some(PdfIndirect(40)),
  )
  guard imported_annotation.lookup_immediate(key_a)
    is Some(PdfDictionary(action_entries)) else {
    fail("expected imported action")
  }
  let action_object : @syntax.PdfObject = PdfDictionary(action_entries)
  @test.assert_eq(
    action_object.lookup_immediate(key_d),
    Some(PdfArray([PdfIndirect(page_refs[1]), PdfNameObject(fit)])),
  )
  @test.assert_eq(
    imported.lookup_object_or_null(40),
    PdfDictionary([(key_extra, annotation_contents_for_test("kept"))]),
  )
  guard imported.lookup_object_or_null(31) is PdfDictionary(dest_entries) else {
    fail("expected imported annotation 31")
  }
  let dest_annotation : @syntax.PdfObject = PdfDictionary(dest_entries)
  @test.assert_eq(
    dest_annotation.lookup_immediate(key_dest),
    Some(PdfArray([PdfIndirect(page_refs[0]), PdfNameObject(fit)])),
  )
}

///|
test "PdfDocument set_annotations_json reports malformed annotation JSON" {
  let target = try! annotation_cpdf_helper_document_for_test()
  let bad_top_level : Result[@pdflite.PdfDocument, Error] = try? target.set_annotations_json(
    Json::object(Map([])),
  )
  guard bad_top_level is Err(@pdflite.PdfError::SoftError(_)) else {
    fail("expected @pdflite.PdfError::SoftError for annotation JSON top level")
  }
  let malformed_row : Result[@pdflite.PdfDocument, Error] = try? target.set_annotations_json(
    Json::array([Json::array([Json::string("bad")])]),
  )
  guard malformed_row is Err(@pdflite.PdfError::SoftError(_)) else {
    fail("expected @pdflite.PdfError::SoftError for annotation JSON row")
  }
}

///|
test "PdfDocument remove_annotations removes selected page arrays" {
  let key_annots = annotation_name_for_test("/Annots")
  let document = try! annotation_cpdf_helper_document_for_test()
  let removed = try! document.remove_annotations([2])
  let wrapper = try! @pdflite.pdf_remove_annotations([2], document)
  @test.assert_eq(try! document.get_annotations(encoding=PdfMetadataRaw), [
    (1, @ascii.encode("first")),
    (2, @ascii.encode("second")),
    (2, Bytes::new(0)),
  ])
  @test.assert_eq(try! removed.get_annotations(encoding=PdfMetadataRaw), [
    (1, @ascii.encode("first")),
  ])
  @test.assert_eq(
    try! wrapper.get_annotations(encoding=PdfMetadataRaw),
    try! removed.get_annotations(encoding=PdfMetadataRaw),
  )
  let pages = try! removed.pages_of_pagetree()
  guard pages[0].rest.lookup_immediate(key_annots) is Some(_) else {
    fail("expected first page annotations")
  }
  @test.assert_eq(pages[1].rest.lookup_immediate(key_annots), None)
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? document.remove_annotations([
      3,
    ],
  )
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected @pdflite.PdfError::BadPageSpecification")
  }
}

///|
test "PdfDocument annotations_of_page reads popup annotations" {
  let key_subtype = annotation_name_for_test("/Subtype")
  let key_contents = annotation_name_for_test("/Contents")
  let key_subject = annotation_name_for_test("/Subj")
  let key_rect = annotation_name_for_test("/Rect")
  let key_bs = annotation_name_for_test("/BS")
  let key_width = annotation_name_for_test("/W")
  let key_style = annotation_name_for_test("/S")
  let key_dash = annotation_name_for_test("/D")
  let key_colour = annotation_name_for_test("/C")
  let key_parent = annotation_name_for_test("/Parent")
  let key_nm = annotation_name_for_test("/NM")
  let key_annots = annotation_name_for_test("/Annots")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_subtype, PdfNameObject(annotation_name_for_test("/Text"))),
      (key_contents, PdfString(@ascii.encode("hello"))),
      (key_subject, PdfString(@ascii.encode("topic"))),
      (
        key_rect,
        PdfArray([
          PdfInteger(10),
          PdfInteger(20),
          PdfInteger(30),
          PdfInteger(40),
        ]),
      ),
      (
        key_bs,
        PdfDictionary([
          (key_width, PdfReal(2.0)),
          (key_style, PdfNameObject(annotation_name_for_test("/D"))),
          (key_dash, PdfArray([PdfInteger(3), PdfInteger(1)])),
        ]),
      ),
      (key_colour, PdfArray([PdfInteger(1), PdfInteger(2), PdfInteger(3)])),
      (key_nm, PdfString(@ascii.encode("n1"))),
    ]),
  )
  doc.add_object_given_number(
    11,
    PdfDictionary([
      (key_subtype, PdfNameObject(annotation_name_for_test("/Popup"))),
      (key_parent, PdfIndirect(10)),
      (
        key_rect,
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(1), PdfInteger(1)]),
      ),
    ]),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    rest: PdfDictionary([
      (key_annots, PdfArray([PdfIndirect(10), PdfIndirect(11)])),
    ]),
  }
  let annotations = try! doc.annotations_of_page(page)
  @test.assert_eq(try! @pdflite.pdf_annotations_of_page(doc, page), annotations)
  @test.assert_eq(annotations.length(), 1)
  guard annotations[0].subtype is AnnotationPopup(parent) else {
    fail("expected popup annotation")
  }
  @test.assert_eq(parent.subtype, AnnotationText)
  @test.assert_eq(parent.contents, Some(@ascii.encode("hello")))
  @test.assert_eq(parent.subject, Some(@ascii.encode("topic")))
  @test.assert_eq(
    parent.rectangle,
    annotation_rect_for_test(10.0, 20.0, 30.0, 40.0),
  )
  @test.assert_eq(parent.border, {
    width: 2.0,
    vertical_radius: 0.0,
    horizontal_radius: 0.0,
    style: AnnotationDashed,
    dash_array: [3, 1],
  })
  @test.assert_eq(parent.colour, Some({ red: 1, green: 2, blue: 3 }))
  @test.assert_eq(
    parent.rest,
    PdfDictionary([(key_nm, PdfString(@ascii.encode("n1")))]),
  )
  @test.assert_eq(
    annotations[0].rest,
    PdfDictionary([(key_parent, PdfIndirect(10))]),
  )
}

///|
test "PdfDocument add_annotation writes annotation objects into page rest" {
  let key_annots = annotation_name_for_test("/Annots")
  let key_subtype = annotation_name_for_test("/Subtype")
  let key_contents = annotation_name_for_test("/Contents")
  let key_rect = annotation_name_for_test("/Rect")
  let key_border = annotation_name_for_test("/Border")
  let key_colour = annotation_name_for_test("/C")
  let key_subject = annotation_name_for_test("/Subj")
  let doc = @pdflite.pdf_document_empty()
  let annotation = @annotation.pdf_annotation_make(
    AnnotationLink,
    contents=Some(@ascii.encode("jump")),
    border=@annotation.pdf_annotation_make_border(
      2.0,
      vertical_radius=1.0,
      horizontal_radius=3.0,
      dash_array=[4, 2],
    ),
    rectangle=annotation_rect_for_test(1.0, 2.0, 3.0, 4.0),
    colour=Some({ red: 9, green: 8, blue: 7 }),
    subject=Some(@ascii.encode("subject")),
  )
  let page = try! doc.add_annotation(
    @page.pdf_page_blank(@geometry.paper_a4),
    annotation,
  )
  let page_from_function = try! @pdflite.pdf_add_annotation(
    doc,
    @page.pdf_page_blank(@geometry.paper_a4),
    annotation,
  )
  @test.assert_eq(page_from_function.rest, page.rest)
  match page.rest.lookup_immediate(key_annots) {
    Some(PdfArray([PdfDictionary(_) as object])) => {
      @test.assert_eq(
        object.lookup_immediate(key_subtype),
        Some(PdfNameObject(annotation_name_for_test("/Link"))),
      )
      @test.assert_eq(
        object.lookup_immediate(key_contents),
        Some(PdfString(@ascii.encode("jump"))),
      )
      @test.assert_eq(
        object.lookup_immediate(key_rect),
        Some(PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(3.0), PdfReal(4.0)])),
      )
      @test.assert_eq(
        object.lookup_immediate(key_border),
        Some(
          PdfArray([
            PdfReal(3.0),
            PdfReal(1.0),
            PdfReal(2.0),
            PdfArray([PdfInteger(4), PdfInteger(2)]),
          ]),
        ),
      )
      @test.assert_eq(
        object.lookup_immediate(key_colour),
        Some(PdfArray([PdfInteger(9), PdfInteger(8), PdfInteger(7)])),
      )
      @test.assert_eq(
        object.lookup_immediate(key_subject),
        Some(PdfString(@ascii.encode("subject"))),
      )
    }
    _ => fail("expected one direct annotation")
  }
}

///|
test "PdfDocument annotation APIs report malformed annotation dictionaries" {
  let key_annots = annotation_name_for_test("/Annots")
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.annotations_of_page(@page.pdf_page_blank(@geometry.paper_a4)),
    [],
  )
  let missing_rect : Result[@annotation.PdfAnnotation, Error] = try? doc.read_annotation(
    PdfDictionary([]),
  )
  guard missing_rect is Err(@pdflite.PdfError::RectangleExpected) else {
    fail("expected @pdflite.PdfError::RectangleExpected")
  }
  let bad_rest = {
    ..@annotation.pdf_annotation_make(AnnotationText),
    rest: PdfInteger(1),
  }
  let bad_rest_result : Result[@page.PdfPage, Error] = try? doc.add_annotation(
    @page.pdf_page_blank(@geometry.paper_a4),
    bad_rest,
  )
  guard bad_rest_result is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected @pdflite.PdfError::DictionaryExpected")
  }
  let bad_annots_result : Result[@page.PdfPage, Error] = try? doc.add_annotation(
    {
      ..@page.pdf_page_blank(@geometry.paper_a4),
      rest: PdfDictionary([(key_annots, PdfInteger(1))]),
    },
    @annotation.pdf_annotation_make(AnnotationText),
  )
  guard bad_annots_result is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected @pdflite.PdfError::DictionaryExpected")
  }
}

///|
test "PdfDocument add_annotation writes subtype names for annotation variants" {
  let key_annots = annotation_name_for_test("/Annots")
  let key_subtype = annotation_name_for_test("/Subtype")
  let custom_name = annotation_name_for_test("/Custom")
  let popup_parent = @annotation.pdf_annotation_make(AnnotationText)
  let cases : Array[(@annotation.PdfAnnotationSubtype, @pdflite.PdfName)] = [
    (AnnotationText, annotation_name_for_test("/Text")),
    (AnnotationLink, annotation_name_for_test("/Link")),
    (AnnotationFreeText, annotation_name_for_test("/FreeText")),
    (AnnotationLine, annotation_name_for_test("/Line")),
    (AnnotationSquare, annotation_name_for_test("/Square")),
    (AnnotationCircle, annotation_name_for_test("/Circle")),
    (AnnotationPolygon, annotation_name_for_test("/Polygon")),
    (AnnotationPolyLine, annotation_name_for_test("/PolyLine")),
    (AnnotationHighlight, annotation_name_for_test("/Highlight")),
    (AnnotationUnderline, annotation_name_for_test("/Underline")),
    (AnnotationSquiggly, annotation_name_for_test("/Squiggly")),
    (AnnotationStrikeOut, annotation_name_for_test("/StrikeOut")),
    (AnnotationStamp, annotation_name_for_test("/Stamp")),
    (AnnotationCaret, annotation_name_for_test("/Caret")),
    (AnnotationInk, annotation_name_for_test("/Ink")),
    (AnnotationPopup(popup_parent), annotation_name_for_test("/Popup")),
    (AnnotationFileAttachment, annotation_name_for_test("/FileAttachment")),
    (AnnotationSound, annotation_name_for_test("/Sound")),
    (AnnotationMovie, annotation_name_for_test("/Movie")),
    (AnnotationWidget, annotation_name_for_test("/Widget")),
    (AnnotationScreen, annotation_name_for_test("/Screen")),
    (AnnotationPrinterMark, annotation_name_for_test("/PrinterMark")),
    (AnnotationTrapNet, annotation_name_for_test("/TrapNet")),
    (AnnotationWatermark, annotation_name_for_test("/Watermark")),
    (AnnotationThreeDee, annotation_name_for_test("/3D")),
    (AnnotationUnknown(custom_name), annotation_name_for_test("/Unknown")),
  ]
  let doc = @pdflite.pdf_document_empty()
  for case in cases {
    let page = try! doc.add_annotation(
      @page.pdf_page_blank(@geometry.paper_a4),
      @annotation.pdf_annotation_make(case.0),
    )
    guard page.rest.lookup_immediate(key_annots)
      is Some(PdfArray([PdfDictionary(_) as annotation])) else {
      fail("expected one serialized annotation")
    }
    @test.assert_eq(
      annotation.lookup_immediate(key_subtype),
      Some(PdfNameObject(case.1)),
    )
  }
}

///|
test "PdfDocument read_annotation maps subtype names and border styles" {
  let key_subtype = annotation_name_for_test("/Subtype")
  let key_rect = annotation_name_for_test("/Rect")
  let key_border = annotation_name_for_test("/Border")
  let key_bs = annotation_name_for_test("/BS")
  let key_style = annotation_name_for_test("/S")
  let key_dash = annotation_name_for_test("/D")
  let doc = @pdflite.pdf_document_empty()
  let rectangle : @syntax.PdfObject = PdfArray([
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(1),
    PdfInteger(1),
  ])
  let subtype_cases : Array[
    (@pdflite.PdfName, @annotation.PdfAnnotationSubtype),
  ] = [
    (annotation_name_for_test("/Text"), AnnotationText),
    (annotation_name_for_test("/FreeText"), AnnotationFreeText),
    (annotation_name_for_test("/Stamp"), AnnotationStamp),
    (annotation_name_for_test("/Link"), AnnotationLink),
    (annotation_name_for_test("/Line"), AnnotationLine),
    (annotation_name_for_test("/Square"), AnnotationSquare),
    (annotation_name_for_test("/Circle"), AnnotationCircle),
    (annotation_name_for_test("/Polygon"), AnnotationPolygon),
    (annotation_name_for_test("/PolyLine"), AnnotationPolyLine),
    (annotation_name_for_test("/Highlight"), AnnotationHighlight),
    (annotation_name_for_test("/Underline"), AnnotationUnderline),
    (annotation_name_for_test("/Squiggly"), AnnotationSquiggly),
    (annotation_name_for_test("/StrikeOut"), AnnotationStrikeOut),
    (annotation_name_for_test("/Caret"), AnnotationCaret),
    (annotation_name_for_test("/Ink"), AnnotationInk),
    (annotation_name_for_test("/FileAttachment"), AnnotationFileAttachment),
    (annotation_name_for_test("/Sound"), AnnotationSound),
    (annotation_name_for_test("/Movie"), AnnotationMovie),
    (annotation_name_for_test("/Widget"), AnnotationWidget),
    (annotation_name_for_test("/Screen"), AnnotationScreen),
    (annotation_name_for_test("/PrinterMark"), AnnotationPrinterMark),
    (annotation_name_for_test("/TrapNet"), AnnotationTrapNet),
    (annotation_name_for_test("/Watermark"), AnnotationWatermark),
    (annotation_name_for_test("/3D"), AnnotationThreeDee),
  ]
  for case in subtype_cases {
    let annotation = try! doc.read_annotation(
      PdfDictionary([
        (key_subtype, PdfNameObject(case.0)),
        (key_rect, rectangle),
      ]),
    )
    @test.assert_eq(annotation.subtype, case.1)
  }
  let custom_name = annotation_name_for_test("/Custom")
  @test.assert_eq(
    (try! doc.read_annotation(
      PdfDictionary([
        (key_subtype, PdfNameObject(custom_name)),
        (key_rect, rectangle),
      ]),
    )).subtype,
    AnnotationUnknown(custom_name),
  )
  @test.assert_eq(
    (try! doc.read_annotation(PdfDictionary([(key_rect, rectangle)]))).subtype,
    AnnotationUnknown(annotation_name_for_test("")),
  )
  @test.assert_eq(
    (try! doc.read_annotation(
      PdfDictionary([
        (key_subtype, PdfNameObject(annotation_name_for_test("/Popup"))),
        (key_rect, rectangle),
      ]),
    )).subtype,
    AnnotationUnknown(annotation_name_for_test("")),
  )
  let style_cases : Array[(@pdflite.PdfName, @annotation.PdfAnnotationStyle)] = [
    (annotation_name_for_test("/S"), AnnotationSolid),
    (annotation_name_for_test("/D"), AnnotationDashed),
    (annotation_name_for_test("/B"), AnnotationBeveled),
    (annotation_name_for_test("/I"), AnnotationInset),
    (annotation_name_for_test("/U"), AnnotationUnderlineStyle),
    (annotation_name_for_test("/Unknown"), AnnotationNoStyle),
  ]
  for case in style_cases {
    let annotation = try! doc.read_annotation(
      PdfDictionary([
        (key_subtype, PdfNameObject(annotation_name_for_test("/Text"))),
        (key_rect, rectangle),
        (key_bs, PdfDictionary([(key_style, PdfNameObject(case.0))])),
      ]),
    )
    @test.assert_eq(annotation.border.style, case.1)
  }
  @test.assert_eq(
    (try! doc.read_annotation(
      PdfDictionary([
        (key_subtype, PdfNameObject(annotation_name_for_test("/Text"))),
        (key_rect, rectangle),
        (key_bs, PdfDictionary([])),
      ]),
    )).border.style,
    AnnotationNoStyle,
  )
  @test.assert_eq(
    (try! doc.read_annotation(
      PdfDictionary([
        (key_subtype, PdfNameObject(annotation_name_for_test("/Text"))),
        (key_rect, rectangle),
        (key_bs, PdfDictionary([(key_dash, PdfInteger(9))])),
      ]),
    )).border.dash_array,
    [],
  )
  @test.assert_eq(
    (try! doc.read_annotation(
      PdfDictionary([
        (key_subtype, PdfNameObject(annotation_name_for_test("/Text"))),
        (key_rect, rectangle),
        (key_border, PdfArray([PdfInteger(2), PdfInteger(3), PdfInteger(4)])),
      ]),
    )).border,
    {
      width: 4.0,
      vertical_radius: 3.0,
      horizontal_radius: 2.0,
      style: AnnotationNoStyle,
      dash_array: [],
    },
  )
  @test.assert_eq(
    (try! doc.read_annotation(
      PdfDictionary([
        (key_subtype, PdfNameObject(annotation_name_for_test("/Text"))),
        (key_rect, rectangle),
        (
          key_border,
          PdfArray([
            PdfInteger(2),
            PdfInteger(3),
            PdfInteger(4),
            PdfArray([PdfInteger(5), PdfInteger(6)]),
          ]),
        ),
      ]),
    )).border.dash_array,
    [5, 6],
  )
}

///|
test "PdfDocument add_annotation prepends to existing annotations and keeps rest" {
  let key_annots = annotation_name_for_test("/Annots")
  let key_nm = annotation_name_for_test("/NM")
  let doc = @pdflite.pdf_document_empty()
  let annotation = {
    ..@annotation.pdf_annotation_make(AnnotationText),
    rest: PdfDictionary([(key_nm, PdfString(@ascii.encode("a1")))]),
  }
  let page = try! doc.add_annotation(
    {
      ..@page.pdf_page_blank(@geometry.paper_a4),
      rest: PdfDictionary([(key_annots, PdfArray([PdfIndirect(99)]))]),
    },
    annotation,
  )
  guard page.rest.lookup_immediate(key_annots)
    is Some(PdfArray([PdfDictionary(_) as inserted, PdfIndirect(99)])) else {
    fail("expected prepended direct annotation")
  }
  @test.assert_eq(
    inserted.lookup_immediate(key_nm),
    Some(PdfString(@ascii.encode("a1"))),
  )
}

///|
test "PdfDocument transform_annotations updates annotation geometry" {
  let key_annots = annotation_name_for_test("/Annots")
  let key_rect = annotation_name_for_test("/Rect")
  let key_quadpoints = annotation_name_for_test("/QuadPoints")
  let key_line = annotation_name_for_test("/L")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (
        key_rect,
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(20)]),
      ),
      (
        key_quadpoints,
        PdfArray([
          PdfInteger(0),
          PdfInteger(0),
          PdfInteger(10),
          PdfInteger(0),
          PdfInteger(10),
          PdfInteger(10),
          PdfInteger(0),
          PdfInteger(10),
        ]),
      ),
      (
        key_line,
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(5), PdfInteger(5)]),
      ),
    ]),
  )
  doc.add_object_given_number(
    11,
    PdfDictionary([
      (
        key_quadpoints,
        PdfArray([
          PdfInteger(0),
          PdfNameObject(annotation_name_for_test("/Bad")),
          PdfInteger(10),
          PdfInteger(0),
          PdfInteger(10),
          PdfInteger(10),
          PdfInteger(0),
          PdfInteger(10),
          PdfInteger(99),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    12,
    PdfDictionary([(key_quadpoints, PdfInteger(1))]),
  )
  doc.add_object_given_number(
    13,
    PdfDictionary([
      (
        key_rect,
        PdfArray([PdfInteger(1), PdfInteger(1), PdfInteger(2), PdfInteger(2)]),
      ),
    ]),
  )
  let rest : @syntax.PdfObject = PdfDictionary([
    (
      key_annots,
      PdfArray([
        PdfIndirect(10),
        PdfIndirect(11),
        PdfIndirect(12),
        PdfIndirect(13),
        PdfNull,
      ]),
    ),
  ])
  try! @pdflite.pdf_transform_annotations(
    doc,
    @geometry.transform_translate(1.0, 2.0),
    rest,
  )
  let annotation = doc.lookup_object_or_null(10)
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(11.0), PdfReal(22.0)])),
  )
  @test.assert_eq(
    annotation.lookup_immediate(key_quadpoints),
    Some(
      PdfArray([
        PdfReal(1.0),
        PdfReal(2.0),
        PdfReal(11.0),
        PdfReal(2.0),
        PdfReal(11.0),
        PdfReal(12.0),
        PdfReal(1.0),
        PdfReal(12.0),
      ]),
    ),
  )
  @test.assert_eq(
    annotation.lookup_immediate(key_line),
    Some(PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(6.0), PdfReal(7.0)])),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(11).lookup_immediate(key_quadpoints),
    Some(
      PdfArray([
        PdfInteger(0),
        PdfNameObject(annotation_name_for_test("/Bad")),
        PdfInteger(10),
        PdfInteger(0),
        PdfInteger(10),
        PdfInteger(10),
        PdfInteger(0),
        PdfInteger(10),
        PdfInteger(99),
      ]),
    ),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(12).lookup_immediate(key_quadpoints),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(13).lookup_immediate(key_rect),
    Some(PdfArray([PdfReal(2.0), PdfReal(3.0), PdfReal(3.0), PdfReal(4.0)])),
  )
  try! doc.transform_annotations(
    @geometry.transform_translate(1.0, 2.0),
    PdfDictionary([]),
  )
}

///|
test "PdfDocument transform_annotations updates direct annotation dictionaries" {
  let key_annots = annotation_name_for_test("/Annots")
  let key_rect = annotation_name_for_test("/Rect")
  let key_quadpoints = annotation_name_for_test("/QuadPoints")
  let key_line = annotation_name_for_test("/L")
  let doc = @pdflite.pdf_document_empty()
  let rest : @syntax.PdfObject = PdfDictionary([
    (
      key_annots,
      PdfArray([
        PdfDictionary([
          (
            key_rect,
            PdfArray([
              PdfInteger(0),
              PdfInteger(0),
              PdfInteger(10),
              PdfInteger(20),
            ]),
          ),
          (
            key_quadpoints,
            PdfArray([
              PdfInteger(0),
              PdfInteger(0),
              PdfInteger(10),
              PdfInteger(0),
              PdfInteger(10),
              PdfInteger(10),
              PdfInteger(0),
              PdfInteger(10),
            ]),
          ),
          (
            key_line,
            PdfArray([
              PdfInteger(0),
              PdfInteger(0),
              PdfInteger(5),
              PdfInteger(5),
            ]),
          ),
        ]),
        PdfNull,
      ]),
    ),
  ])
  try! doc.transform_annotations(@geometry.transform_translate(1.0, 2.0), rest)
  guard rest.lookup_immediate(key_annots)
    is Some(PdfArray([PdfDictionary(_) as annotation, PdfNull])) else {
    fail("expected transformed direct annotation")
  }
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(11.0), PdfReal(22.0)])),
  )
  @test.assert_eq(
    annotation.lookup_immediate(key_quadpoints),
    Some(
      PdfArray([
        PdfReal(1.0),
        PdfReal(2.0),
        PdfReal(11.0),
        PdfReal(2.0),
        PdfReal(11.0),
        PdfReal(12.0),
        PdfReal(1.0),
        PdfReal(12.0),
      ]),
    ),
  )
  @test.assert_eq(
    annotation.lookup_immediate(key_line),
    Some(PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(6.0), PdfReal(7.0)])),
  )
}

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
) -> @pdflite.PdfRectangle {
  { min_x, min_y, max_x, max_y }
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
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    rest: PdfDictionary([
      (key_annots, PdfArray([PdfIndirect(10), PdfIndirect(11)])),
    ]),
  }
  let annotations = try! doc.annotations_of_page(page)
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
  let annotation = @pdflite.pdf_annotation_make(
    AnnotationLink,
    contents=Some(@ascii.encode("jump")),
    border=@pdflite.pdf_annotation_make_border(
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
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
    annotation,
  )
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
  let rest : @pdflite.PdfObject = PdfDictionary([
    (key_annots, PdfArray([PdfIndirect(10)])),
  ])
  try! doc.transform_annotations(@pdflite.transform_translate(1.0, 2.0), rest)
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
}

///|
fn page_info_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_info_number_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn page_info_box_for_test(values : ArrayView[Double]) -> Json {
  Json::array([ for value in values => Json::number(value) ])
}

///|
fn page_info_pdfdoc_for_test(
  text : String,
) -> @core.PdfBytes raise @core.PdfError {
  @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode(text))
}

///|
fn page_info_document_for_test() -> @pdflite.PdfDocument raise @core.PdfError {
  let document = try! @pdflite.pdf_blank_document(72.0, 144.0, 2)
  let pages = try! document.pages_of_pagetree()
  let cropbox = page_info_name_for_test("/CropBox")
  let trimbox = page_info_name_for_test("/TrimBox")
  let annots = page_info_name_for_test("/Annots")
  let first_rest = try! (try! (try! pages[0].rest.add_dict_entry(
    cropbox,
    PdfArray([PdfReal(54.0), PdfInteger(36), PdfInteger(18), PdfInteger(72)]),
  )).add_dict_entry(
    trimbox,
    PdfArray([PdfReal(9.0), PdfReal(18.0), PdfReal(45.0), PdfReal(54.0)]),
  )).add_dict_entry(annots, PdfArray([PdfDictionary([]), PdfDictionary([])]))
  let changed = try! document.change_pages([
    { ..pages[0], rotate: Rotate90, rest: first_rest },
    pages[1],
  ])
  changed.write_page_labels([
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(try! page_info_pdfdoc_for_test("A-")),
      start_page: 1,
      start_value: 7,
    },
  ])
}

///|
test "PdfDocument page_info_json reports selected pages in source range order" {
  let document = try! page_info_document_for_test()
  let expected = Json::array([
    Json::object(
      Map([
        ("Page", page_info_number_for_test(2)),
        ("Label", Json::string("A-8")),
        ("MediaBox", page_info_box_for_test([0.0, 0.0, 1.0, 2.0])),
        ("CropBox", Json::null()),
        ("BleedBox", Json::null()),
        ("TrimBox", Json::null()),
        ("ArtBox", Json::null()),
        ("Rotation", page_info_number_for_test(0)),
        ("Annotations", page_info_number_for_test(0)),
      ]),
    ),
    Json::object(
      Map([
        ("Page", page_info_number_for_test(1)),
        ("Label", Json::string("A-7")),
        ("MediaBox", page_info_box_for_test([0.0, 0.0, 1.0, 2.0])),
        ("CropBox", page_info_box_for_test([0.75, 0.5, 0.25, 1.0])),
        ("BleedBox", Json::null()),
        ("TrimBox", page_info_box_for_test([0.125, 0.25, 0.625, 0.75])),
        ("ArtBox", Json::null()),
        ("Rotation", page_info_number_for_test(90)),
        ("Annotations", page_info_number_for_test(2)),
      ]),
    ),
  ])
  @test.assert_eq(try! document.page_info_json([2, 1], unit=Inch), expected)
  @test.assert_eq(
    try! @pdflite.pdf_page_info_json(document, [2, 1], unit=Inch),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_json_page_info(document, [2, 1], Inch),
    expected,
  )
  @test.assert_eq(
    try! document.page_info_json_blob([2, 1], unit=Inch),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! @pdflite.pdf_output_page_info_json_blob(document, [2, 1], unit=Inch),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! document.output_page_info([2, 1], unit=Inch, json=true),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! @pdflite.pdf_output_page_info(
      Inch,
      document,
      [2, 1],
      json=true,
      raisejson=true,
    ),
    @utf8.encode(expected.stringify()),
  )
}

///|
test "PdfDocument page_info_text renders cpdf plain page report" {
  let document = try! page_info_document_for_test()
  let expected = @utf8.encode(
    "Page 1:\n" +
    "Label: A-7\n" +
    "MediaBox: 0.000000 0.000000 72.000000 144.000000\n" +
    "CropBox: 54.000000 36.000000 18.000000 72.000000\n" +
    "BleedBox: \n" +
    "TrimBox: 9.000000 18.000000 45.000000 54.000000\n" +
    "ArtBox: \n" +
    "Rotation: 90\n" +
    "Annotations: 2\n",
  )
  @test.assert_eq(try! document.page_info_text([1]), expected)
  @test.assert_eq(
    try! @pdflite.pdf_output_page_info_text(document, [1]),
    expected,
  )
  @test.assert_eq(try! document.output_page_info([1]), expected)
  @test.assert_eq(
    try! @pdflite.pdf_output_page_info(PdfPoint, document, [1]),
    expected,
  )
}

///|
test "PdfDocument page_info handles empty and invalid ranges" {
  let document = try! page_info_document_for_test()
  @test.assert_eq(try! document.page_info_json([]), Json::array([]))
  @test.assert_eq(try! document.page_info_text([]), b"")
  let bad_json : Result[Json, Error] = try document.page_info_json([3]) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_json is Err(@core.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for page info JSON")
  }
  let bad_text : Result[Bytes, Error] = try document.page_info_text([3]) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_text is Err(@core.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for page info text")
  }
}

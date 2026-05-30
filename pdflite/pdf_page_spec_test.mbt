///|
fn page_spec_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_spec_rectangle_for_test(width : Int, height : Int) -> @syntax.PdfObject {
  PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(width), PdfInteger(height)])
}

///|
fn page_spec_page_for_test(
  width : Int,
  height : Int,
  annotated? : Bool = false,
) -> @page.PdfPage {
  let page = @page.pdf_page_custom(page_spec_rectangle_for_test(width, height))
  if annotated {
    {
      ..page,
      rest: PdfDictionary([
        (page_spec_name_for_test("/Annots"), PdfArray([PdfDictionary([])])),
      ]),
    }
  } else {
    page
  }
}

///|
fn page_spec_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument raise {
  let document = @pdflite.pdf_document_empty()
  let page_root = document.add_pagetree(pages)
  ignore(document.add_root(page_root, []))
  document
}

///|
test "cpdf pagespec parses basic ranges and words" {
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, ""), [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "1,3-5,7"), [
    1, 3, 4, 5, 7,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "5-3"), [5, 4, 3])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "end-8"), [
    10, 9, 8,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "8-end"), [
    8, 9, 10,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "~1,~3"), [10, 8])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "reverse"), [
    10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "empty"), [])
}

///|
test "cpdf pagespec applies odd even not duplicate and bounds filtering" {
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "odd"), [
    1, 3, 5, 7, 9,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "even"), [
    2, 4, 6, 8, 10,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "1-8odd"), [
    1, 3, 5, 7,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "1-8even"), [
    2, 4, 6, 8,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "NOT1-8even"), [
    1, 3, 5, 7, 9, 10,
  ])
  @test.assert_eq(@spec.pdf_invert_range(10, [2, 4, 6, 8]), [1, 3, 5, 7, 9, 10])
  @test.assert_eq(
    @spec.pdf_invert_range(10, [2, 4, 6, 8]),
    @spec.pdf_invert_page_range(10, [2, 4, 6, 8]),
  )
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "2DUP1-3"), [
    1, 1, 2, 2, 3, 3,
  ])
  @test.assert_eq(try! @spec.pdf_parse_pagespec_for_count(10, "0,1,11"), [1])
}

///|
test "cpdf pagespec rejects malformed syntax" {
  let leading_comma : Result[Array[Int], Error] = try? @spec.pdf_parse_pagespec_for_count(
    10, ",1",
  )
  guard leading_comma is Err(@core.PdfError::BadPageSpecification(",1")) else {
    fail("expected BadPageSpecification for leading comma")
  }
  let doubled_dash : Result[Array[Int], Error] = try? @spec.pdf_parse_pagespec_for_count(
    10, "1--3",
  )
  guard doubled_dash is Err(@core.PdfError::BadPageSpecification("1--3")) else {
    fail("expected BadPageSpecification for doubled dash")
  }
  let zero_pages : Result[Array[Int], Error] = try? @spec.pdf_parse_pagespec_for_count(
    0, "1",
  )
  guard zero_pages is Err(@core.PdfError::BadPageSpecification("1")) else {
    fail("expected BadPageSpecification for empty page count")
  }
}

///|
test "cpdf pagespec filters document portrait landscape and annotated pages" {
  let document = try! page_spec_document_for_test([
    page_spec_page_for_test(400, 600),
    page_spec_page_for_test(800, 500, annotated=true),
    page_spec_page_for_test(600, 600),
    page_spec_page_for_test(300, 900, annotated=true),
  ])
  @test.assert_eq(try! document.parse_pagespec("portrait"), [1, 4])
  @test.assert_eq(try! document.parse_pagespec("landscape"), [2])
  @test.assert_eq(try! document.parse_pagespec("1-3landscape"), [2])
  @test.assert_eq(try! document.parse_pagespec("annotated"), [2, 4])
}

///|
test "cpdf pagespec resolves page labels" {
  let document = try! page_spec_document_for_test([
    page_spec_page_for_test(400, 600),
    page_spec_page_for_test(400, 600),
    page_spec_page_for_test(400, 600),
    page_spec_page_for_test(400, 600),
  ])
  let labels : Array[@label.PdfPageLabel] = [
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(@ascii.encode("A-")),
      start_page: 4,
      start_value: 1,
    },
  ]
  let labeled = try! document.write_page_labels(labels)
  @test.assert_eq(try! labeled.parse_pagespec("[iii],[A-1]"), [3, 4])
  let missing : Result[Array[Int], Error] = try? labeled.parse_pagespec(
    "[missing]",
  )
  guard missing is Err(@core.PdfError::BadPageSpecification("[missing]")) else {
    fail("expected BadPageSpecification for an unknown page label")
  }
}

///|
test "cpdf pagespec resolves escaped bracket page labels" {
  let document = try! page_spec_document_for_test([
    page_spec_page_for_test(400, 600),
    page_spec_page_for_test(400, 600),
    page_spec_page_for_test(400, 600),
  ])
  let labels : Array[@label.PdfPageLabel] = [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(@ascii.encode("A]")),
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(@ascii.encode("B[")),
      start_page: 2,
      start_value: 1,
    },
  ]
  let labeled = try! document.write_page_labels(labels)
  @test.assert_eq(try! labeled.parse_pagespec("[A\\]1],[B\\[2]"), [1, 3])
  let nested : Result[Array[Int], Error] = try? labeled.parse_pagespec("[A]1]")
  guard nested is Err(@core.PdfError::BadPageSpecification("[A]1]")) else {
    fail("expected BadPageSpecification for an unescaped closing bracket")
  }
}

///|
test "cpdf pagespec formats ranges" {
  @test.assert_eq(
    @spec.pdf_string_of_pagespec_for_count(10, [2, 4, 6, 8, 10]),
    "even",
  )
  @test.assert_eq(
    @spec.pdf_string_of_pagespec_for_count(9, [1, 3, 5, 7, 9]),
    "odd",
  )
  @test.assert_eq(
    @spec.pdf_string_of_pagespec_for_count(4, [1, 2, 3, 4]),
    "all",
  )
  @test.assert_eq(
    @spec.pdf_string_of_pagespec_for_count(10, [5, 1, 2, 4, 9, 10]),
    "1-2,4-5,9-10",
  )
  @test.assert_eq(@spec.pdf_string_of_pagespec_for_count(10, []), "")
}

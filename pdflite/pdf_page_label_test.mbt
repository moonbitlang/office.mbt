///|
fn page_label_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_label_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn page_label_catalog_document_for_test() -> @pdflite.PdfDocument {
  let key_root = page_label_name_for_test("/Root")
  let key_type = page_label_name_for_test("/Type")
  let type_catalog = page_label_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([(key_type, PdfNameObject(type_catalog))]),
  )
  doc
}

///|
test "PdfDocument write_page_labels builds a readable page label tree" {
  let key_page_labels = page_label_name_for_test("/PageLabels")
  let key_nums = page_label_name_for_test("/Nums")
  let key_style = page_label_name_for_test("/S")
  let key_prefix = page_label_name_for_test("/P")
  let key_start_value = page_label_name_for_test("/St")
  let doc = page_label_catalog_document_for_test()
  let labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(page_label_bytes_for_test("intro-")),
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 6,
      start_value: 1,
    },
    {
      label_style: PageLabelNoLabelPrefixOnly,
      label_prefix: Some(page_label_bytes_for_test("appendix")),
      start_page: 12,
      start_value: 3,
    },
  ]
  let updated = try! doc.write_page_labels(labels)
  @test.assert_eq(try! doc.read_page_labels(), [])
  @test.assert_eq(try! updated.read_page_labels(), labels)
  @test.assert_eq(updated.root(), 2)
  let catalog = updated.lookup_object_or_null(updated.root())
  guard catalog.lookup_immediate(key_page_labels) is Some(label_tree) else {
    fail("expected PageLabels")
  }
  guard label_tree.lookup_immediate(key_nums) is Some(PdfArray(items)) else {
    fail("expected flat number tree")
  }
  @test.assert_eq(items[0], PdfInteger(0))
  @test.assert_eq(items[2], PdfInteger(5))
  @test.assert_eq(items[4], PdfInteger(11))
  guard items[0 + 1] is PdfDictionary(first_entries) else {
    fail("expected first label dictionary")
  }
  let first : @pdflite.PdfObject = PdfDictionary(first_entries)
  @test.assert_eq(
    first.lookup_immediate(key_style),
    Some(PdfNameObject(page_label_name_for_test("/r"))),
  )
  @test.assert_eq(
    first.lookup_immediate(key_prefix),
    Some(PdfString(page_label_bytes_for_test("intro-"))),
  )
  @test.assert_eq(first.lookup_immediate(key_start_value), None)
  guard items[4 + 1] is PdfDictionary(third_entries) else {
    fail("expected third label dictionary")
  }
  let third : @pdflite.PdfObject = PdfDictionary(third_entries)
  @test.assert_eq(third.lookup_immediate(key_style), None)
  @test.assert_eq(
    third.lookup_immediate(key_prefix),
    Some(PdfString(page_label_bytes_for_test("appendix"))),
  )
  @test.assert_eq(third.lookup_immediate(key_start_value), Some(PdfInteger(3)))
}

///|
test "PdfDocument read_page_labels decodes all label styles" {
  let key_page_labels = page_label_name_for_test("/PageLabels")
  let key_nums = page_label_name_for_test("/Nums")
  let key_style = page_label_name_for_test("/S")
  let doc = page_label_catalog_document_for_test()
  let label_tree : @pdflite.PdfObject = PdfDictionary([
    (
      key_nums,
      PdfArray([
        PdfInteger(0),
        PdfDictionary([
          (key_style, PdfNameObject(page_label_name_for_test("/D"))),
        ]),
        PdfInteger(1),
        PdfDictionary([
          (key_style, PdfNameObject(page_label_name_for_test("/R"))),
        ]),
        PdfInteger(2),
        PdfDictionary([
          (key_style, PdfNameObject(page_label_name_for_test("/r"))),
        ]),
        PdfInteger(3),
        PdfDictionary([
          (key_style, PdfNameObject(page_label_name_for_test("/A"))),
        ]),
        PdfInteger(4),
        PdfDictionary([
          (key_style, PdfNameObject(page_label_name_for_test("/a"))),
        ]),
        PdfInteger(5),
        PdfDictionary([]),
      ]),
    ),
  ])
  doc.add_object_given_number(
    1,
    try! doc
    .lookup_object_or_null(1)
    .add_dict_entry(key_page_labels, label_tree),
  )
  @test.assert_eq(try! doc.read_page_labels(), [
    {
      ..@pdflite.pdf_page_label_basic,
      label_style: PageLabelDecimalArabic,
      start_page: 1,
    },
    {
      ..@pdflite.pdf_page_label_basic,
      label_style: PageLabelUppercaseRoman,
      start_page: 2,
    },
    {
      ..@pdflite.pdf_page_label_basic,
      label_style: PageLabelLowercaseRoman,
      start_page: 3,
    },
    {
      ..@pdflite.pdf_page_label_basic,
      label_style: PageLabelUppercaseLetters,
      start_page: 4,
    },
    {
      ..@pdflite.pdf_page_label_basic,
      label_style: PageLabelLowercaseLetters,
      start_page: 5,
    },
    {
      ..@pdflite.pdf_page_label_basic,
      label_style: PageLabelNoLabelPrefixOnly,
      start_page: 6,
    },
  ])
}

///|
test "PdfDocument remove_page_labels and empty write drop labels" {
  let labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
  ]
  let doc = page_label_catalog_document_for_test()
  let labelled = try! doc.write_page_labels(labels)
  let removed = try! labelled.remove_page_labels()
  let empty_written = try! labelled.write_page_labels([])
  @test.assert_eq(try! labelled.read_page_labels(), labels)
  @test.assert_eq(try! removed.read_page_labels(), [])
  @test.assert_eq(try! empty_written.read_page_labels(), [])
}

///|
test "PdfDocument page label APIs require a root catalog" {
  let doc = @pdflite.pdf_document_empty()
  let labels : Array[@pdflite.PdfPageLabel] = [@pdflite.pdf_page_label_basic]
  let read_result : Result[Array[@pdflite.PdfPageLabel], Error] = try? doc.read_page_labels()
  guard read_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected from read_page_labels")
  }
  let write_result : Result[@pdflite.PdfDocument, Error] = try? doc.write_page_labels(
    labels,
  )
  guard write_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected from write_page_labels")
  }
  let remove_result : Result[@pdflite.PdfDocument, Error] = try? doc.remove_page_labels()
  guard remove_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected from remove_page_labels")
  }
}

///|
test "pdf_page_label_complete supplies a basic first range" {
  let later : @pdflite.PdfPageLabel = {
    label_style: PageLabelUppercaseRoman,
    label_prefix: None,
    start_page: 3,
    start_value: 1,
  }
  @test.assert_eq(@pdflite.pdf_page_label_complete([]), [
    @pdflite.pdf_page_label_basic,
  ])
  @test.assert_eq(@pdflite.pdf_page_label_complete([later]), [
    @pdflite.pdf_page_label_basic, later,
  ])
  @test.assert_eq(
    @pdflite.pdf_page_label_complete([@pdflite.pdf_page_label_basic, later]),
    [@pdflite.pdf_page_label_basic, later],
  )
}

///|
test "pdf_page_label_text_of_page_number renders label bytes" {
  let labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(page_label_bytes_for_test("intro-")),
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 6,
      start_value: 1,
    },
    {
      label_style: PageLabelUppercaseLetters,
      label_prefix: Some(page_label_bytes_for_test("A-")),
      start_page: 10,
      start_value: 27,
    },
    {
      label_style: PageLabelNoLabelPrefixOnly,
      label_prefix: Some(page_label_bytes_for_test("cover")),
      start_page: 12,
      start_value: 1,
    },
  ]
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(4, labels),
    Some(page_label_bytes_for_test("intro-iv")),
  )
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(7, labels),
    Some(page_label_bytes_for_test("2")),
  )
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(10, labels),
    Some(page_label_bytes_for_test("A-AA")),
  )
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(12, labels),
    Some(page_label_bytes_for_test("cover")),
  )
  @test.assert_eq(@pdflite.pdf_page_label_text_of_page_number(1, []), None)
}

///|
test "pdf_page_label_of_page_number returns a single-page label" {
  let labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(page_label_bytes_for_test("p.")),
      start_page: 6,
      start_value: 1,
    },
  ]
  @test.assert_eq(
    @pdflite.pdf_page_label_of_page_number(7, labels),
    Some({
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(page_label_bytes_for_test("p.")),
      start_page: 2,
      start_value: 2,
    }),
  )
  @test.assert_eq(@pdflite.pdf_page_label_of_page_number(1, []), None)
}

///|
test "pdf_page_label_coalesce removes redundant adjacent ranges" {
  let first : @pdflite.PdfPageLabel = {
    label_style: PageLabelDecimalArabic,
    label_prefix: None,
    start_page: 1,
    start_value: 1,
  }
  let redundant : @pdflite.PdfPageLabel = {
    ..first,
    start_page: 3,
    start_value: 3,
  }
  let kept_offset : @pdflite.PdfPageLabel = {
    ..first,
    start_page: 6,
    start_value: 1,
  }
  let kept_prefix : @pdflite.PdfPageLabel = {
    ..kept_offset,
    label_prefix: Some(page_label_bytes_for_test("A")),
  }
  @test.assert_eq(
    @pdflite.pdf_page_label_coalesce([
      first, redundant, kept_offset, kept_prefix,
    ]),
    [first, kept_offset, kept_prefix],
  )
}

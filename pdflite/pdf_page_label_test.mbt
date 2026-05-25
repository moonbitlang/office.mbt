///|
fn page_label_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_label_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn page_label_bytes_from_ints_for_test(
  values : ArrayView[Int],
) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
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
test "PdfPageLabelStyle converts to and from CamlPDF names" {
  let styles : Array[(@pdflite.PdfPageLabelStyle, String)] = [
    (PageLabelDecimalArabic, "DecimalArabic"),
    (PageLabelUppercaseRoman, "UppercaseRoman"),
    (PageLabelLowercaseRoman, "LowercaseRoman"),
    (PageLabelUppercaseLetters, "UppercaseLetters"),
    (PageLabelLowercaseLetters, "LowercaseLetters"),
    (PageLabelNoLabelPrefixOnly, "NoLabelPrefixOnly"),
  ]
  for entry in styles {
    @test.assert_eq(entry.0.debug_name(), entry.1)
    @test.assert_eq(
      try! @pdflite.pdf_page_label_style_of_string(entry.1),
      entry.0,
    )
  }
  let result : Result[@pdflite.PdfPageLabelStyle, Error] = try? @pdflite.pdf_page_label_style_of_string(
    "Missing",
  )
  guard result is Err(@pdflite.PdfError::PageLabelStyleExpected("Missing")) else {
    fail("expected @pdflite.PdfError::PageLabelStyleExpected")
  }
}

///|
test "pdf_string_of_page_label renders CamlPDF debug bytes" {
  let no_prefix : @pdflite.PdfPageLabel = {
    label_style: PageLabelDecimalArabic,
    label_prefix: None,
    start_page: 1,
    start_value: 1,
  }
  @test.assert_eq(
    @pdflite.pdf_string_of_page_label(no_prefix),
    page_label_bytes_for_test(
      "labelstyle: DecimalArabic\n" +
      "labelprefix: None\n" +
      "startpage: 1\n" +
      "startvalue: 1\n",
    ),
  )
  let prefix = page_label_bytes_from_ints_for_test([65, 0xFF])
  let label : @pdflite.PdfPageLabel = {
    label_style: PageLabelLowercaseRoman,
    label_prefix: Some(prefix),
    start_page: 3,
    start_value: 7,
  }
  @test.assert_eq(
    @pdflite.pdf_string_of_page_label(label),
    page_label_bytes_from_ints_for_test([
      108, 97, 98, 101, 108, 115, 116, 121, 108, 101, 58, 32, 76, 111, 119, 101,
      114, 99, 97, 115, 101, 82, 111, 109, 97, 110, 10, 108, 97, 98, 101, 108, 112,
      114, 101, 102, 105, 120, 58, 32, 65, 0xFF, 10, 115, 116, 97, 114, 116, 112,
      97, 103, 101, 58, 32, 51, 10, 115, 116, 97, 114, 116, 118, 97, 108, 117, 101,
      58, 32, 55, 10,
    ]),
  )
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
    {
      label_style: PageLabelUppercaseRoman,
      label_prefix: None,
      start_page: 20,
      start_value: 4,
    },
    {
      label_style: PageLabelUppercaseLetters,
      label_prefix: None,
      start_page: 21,
      start_value: 2,
    },
    {
      label_style: PageLabelLowercaseLetters,
      label_prefix: None,
      start_page: 22,
      start_value: 3,
    },
  ]
  let updated = try! doc.write_page_labels(labels)
  let updated_from_function = try! @pdflite.pdf_write_page_labels(doc, labels)
  @test.assert_eq(try! doc.read_page_labels(), [])
  @test.assert_eq(try! updated.read_page_labels(), labels)
  @test.assert_eq(
    try! @pdflite.pdf_read_page_labels(updated_from_function),
    labels,
  )
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
test "PdfDocument read_page_labels keeps CamlPDF malformed range defaults" {
  let key_page_labels = page_label_name_for_test("/PageLabels")
  let key_nums = page_label_name_for_test("/Nums")
  let key_kids = page_label_name_for_test("/Kids")
  let key_style = page_label_name_for_test("/S")
  let key_prefix = page_label_name_for_test("/P")
  let doc = page_label_catalog_document_for_test()
  let label_tree : @pdflite.PdfObject = PdfDictionary([
    (
      key_nums,
      PdfArray([
        PdfNameObject(page_label_name_for_test("/BadStart")),
        PdfDictionary([
          (key_style, PdfNameObject(page_label_name_for_test("/r"))),
          (key_prefix, PdfString(page_label_bytes_for_test("bad-"))),
        ]),
        PdfInteger(2),
        PdfDictionary([
          (key_style, PdfNameObject(page_label_name_for_test("/D"))),
        ]),
        PdfInteger(99),
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
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(page_label_bytes_for_test("bad-")),
      start_page: 1,
      start_value: 1,
    },
    {
      ..@pdflite.pdf_page_label_basic,
      label_style: PageLabelDecimalArabic,
      start_page: 3,
    },
  ])

  let kids_doc = page_label_catalog_document_for_test()
  let kids_label_tree : @pdflite.PdfObject = PdfDictionary([
    (
      key_kids,
      PdfArray([
        PdfDictionary([
          (
            key_nums,
            PdfArray([
              PdfInteger(0),
              PdfDictionary([
                (key_style, PdfNameObject(page_label_name_for_test("/A"))),
              ]),
            ]),
          ),
        ]),
      ]),
    ),
  ])
  kids_doc.add_object_given_number(
    1,
    try! kids_doc
    .lookup_object_or_null(1)
    .add_dict_entry(key_page_labels, kids_label_tree),
  )
  @test.assert_eq(try! kids_doc.read_page_labels(), [
    {
      ..@pdflite.pdf_page_label_basic,
      label_style: PageLabelUppercaseLetters,
      start_page: 1,
    },
  ])

  let empty_doc = page_label_catalog_document_for_test()
  empty_doc.add_object_given_number(
    1,
    try! empty_doc
    .lookup_object_or_null(1)
    .add_dict_entry(key_page_labels, PdfDictionary([])),
  )
  let empty_result : Result[Array[@pdflite.PdfPageLabel], Error] = try? empty_doc.read_page_labels()
  guard empty_result is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected @pdflite.PdfError::PageTreeExpected")
  }
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
  let removed_from_function = try! @pdflite.pdf_remove_page_labels(labelled)
  let empty_written = try! labelled.write_page_labels([])
  @test.assert_eq(try! labelled.read_page_labels(), labels)
  @test.assert_eq(try! removed.read_page_labels(), [])
  @test.assert_eq(try! removed_from_function.read_page_labels(), [])
  @test.assert_eq(try! empty_written.read_page_labels(), [])
}

///|
test "PdfDocument page labels use trailer root catalog" {
  let key_root = page_label_name_for_test("/Root")
  let key_lang = page_label_name_for_test("/Lang")
  let labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(page_label_bytes_for_test("active-")),
      start_page: 1,
      start_value: 1,
    },
  ]
  let replacement : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelUppercaseLetters,
      label_prefix: Some(page_label_bytes_for_test("new-")),
      start_page: 2,
      start_value: 3,
    },
  ]
  let doc = page_label_catalog_document_for_test()
  let stale = try! doc.write_page_labels([
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(page_label_bytes_for_test("stale-")),
      start_page: 1,
      start_value: 1,
    },
  ])
  stale.add_object_given_number(
    stale.root(),
    try! stale
    .lookup_object_or_null(stale.root())
    .add_dict_entry(key_lang, PdfString(page_label_bytes_for_test("stale"))),
  )
  let active = try! doc.write_page_labels(labels)
  let active_root = 10
  stale.add_object_given_number(
    active_root,
    try! active
    .lookup_object_or_null(active.root())
    .add_dict_entry(key_lang, PdfString(page_label_bytes_for_test("active"))),
  )
  stale.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(active_root))]))

  @test.assert_eq(
    stale.lookup_object_or_null(stale.root()).lookup_immediate(key_lang),
    Some(PdfString(page_label_bytes_for_test("stale"))),
  )
  @test.assert_eq(try! stale.read_page_labels(), labels)
  let removed = try! stale.remove_page_labels()
  let removed_catalog = removed.lookup_object_or_null(removed.root())
  @test.assert_eq(
    removed_catalog.lookup_immediate(key_lang),
    Some(PdfString(page_label_bytes_for_test("active"))),
  )
  @test.assert_eq(try! removed.read_page_labels(), [])

  let written = try! stale.write_page_labels(replacement)
  let written_catalog = written.lookup_object_or_null(written.root())
  @test.assert_eq(
    written_catalog.lookup_immediate(key_lang),
    Some(PdfString(page_label_bytes_for_test("active"))),
  )
  @test.assert_eq(try! written.read_page_labels(), replacement)
}

///|
test "PdfDocument page label APIs require a root catalog" {
  let doc = @pdflite.pdf_document_empty()
  let labels : Array[@pdflite.PdfPageLabel] = [@pdflite.pdf_page_label_basic]
  let read_result : Result[Array[@pdflite.PdfPageLabel], Error] = try? doc.read_page_labels()
  guard read_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected from read_page_labels")
  }
  let write_result : Result[@pdflite.PdfDocument, Error] = try? doc.write_page_labels(
    labels,
  )
  guard write_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected from write_page_labels")
  }
  let remove_result : Result[@pdflite.PdfDocument, Error] = try? doc.remove_page_labels()
  guard remove_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected from remove_page_labels")
  }

  let key_root = page_label_name_for_test("/Root")
  let unresolved = page_label_catalog_document_for_test()
  unresolved.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(99))]))
  let unresolved_read : Result[Array[@pdflite.PdfPageLabel], Error] = try? unresolved.read_page_labels()
  guard unresolved_read is Err(@pdflite.PdfError::RootExpected) else {
    fail(
      "expected @pdflite.PdfError::RootExpected from unresolved trailer root",
    )
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
test "pdf_page_label_add_label inserts a bounded label range" {
  let basic = @pdflite.pdf_page_label_basic
  let appendix : @pdflite.PdfPageLabel = {
    label_style: PageLabelUppercaseLetters,
    label_prefix: Some(page_label_bytes_for_test("A-")),
    start_page: 10,
    start_value: 1,
  }
  let inserted : @pdflite.PdfPageLabel = {
    label_style: PageLabelLowercaseRoman,
    label_prefix: Some(page_label_bytes_for_test("intro-")),
    start_page: 3,
    start_value: 1,
  }
  @test.assert_eq(
    @pdflite.pdf_page_label_add_label(12, [basic, appendix], inserted, 5),
    [basic, inserted, { ..basic, start_page: 6, start_value: 6 }, appendix],
  )
}

///|
test "pdf_page_label_add_label avoids redundant continuation labels" {
  let basic = @pdflite.pdf_page_label_basic
  let next : @pdflite.PdfPageLabel = {
    label_style: PageLabelDecimalArabic,
    label_prefix: Some(page_label_bytes_for_test("p.")),
    start_page: 6,
    start_value: 1,
  }
  let inserted : @pdflite.PdfPageLabel = {
    label_style: PageLabelNoLabelPrefixOnly,
    label_prefix: Some(page_label_bytes_for_test("cover")),
    start_page: 3,
    start_value: 1,
  }
  @test.assert_eq(
    @pdflite.pdf_page_label_add_label(12, [basic, next], inserted, 5),
    [basic, inserted, next],
  )
  @test.assert_eq(@pdflite.pdf_page_label_add_label(5, [basic], inserted, 5), [
    basic, inserted,
  ])
  @test.assert_eq(@pdflite.pdf_page_label_add_label(8, [], inserted, 5), [
    inserted,
  ])
}

///|
test "pdf_page_label_add_label removes overlapped ranges" {
  let basic = @pdflite.pdf_page_label_basic
  let old_inner : @pdflite.PdfPageLabel = {
    label_style: PageLabelLowercaseRoman,
    label_prefix: None,
    start_page: 4,
    start_value: 1,
  }
  let after : @pdflite.PdfPageLabel = {
    label_style: PageLabelUppercaseLetters,
    label_prefix: None,
    start_page: 8,
    start_value: 1,
  }
  let inserted : @pdflite.PdfPageLabel = {
    label_style: PageLabelDecimalArabic,
    label_prefix: Some(page_label_bytes_for_test("new-")),
    start_page: 3,
    start_value: 10,
  }
  @test.assert_eq(
    @pdflite.pdf_page_label_add_label(
      12,
      [basic, old_inner, after],
      inserted,
      6,
    ),
    [basic, inserted, { ..old_inner, start_page: 7, start_value: 4 }, after],
  )
}

///|
test "pdf_page_label_add_label replaces an existing same-start label" {
  let basic = @pdflite.pdf_page_label_basic
  let old : @pdflite.PdfPageLabel = {
    label_style: PageLabelLowercaseRoman,
    label_prefix: None,
    start_page: 4,
    start_value: 1,
  }
  let inserted : @pdflite.PdfPageLabel = {
    label_style: PageLabelUppercaseRoman,
    label_prefix: None,
    start_page: 4,
    start_value: 20,
  }
  @test.assert_eq(
    @pdflite.pdf_page_label_add_label(10, [basic, old], inserted, 6),
    [basic, inserted, { ..old, start_page: 7, start_value: 4 }],
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
    {
      label_style: PageLabelUppercaseRoman,
      label_prefix: None,
      start_page: 13,
      start_value: 1000,
    },
    {
      label_style: PageLabelLowercaseLetters,
      label_prefix: None,
      start_page: 14,
      start_value: 27,
    },
    {
      label_style: PageLabelUppercaseRoman,
      label_prefix: Some(page_label_bytes_for_test("roman-")),
      start_page: 15,
      start_value: 944,
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
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(13, labels),
    Some(page_label_bytes_for_test("M")),
  )
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(14, labels),
    Some(page_label_bytes_for_test("aa")),
  )
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(15, labels),
    Some(page_label_bytes_for_test("roman-CMXLIV")),
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

///|
test "pdf_page_label_merge retargets selected page labels" {
  let first_doc = page_label_catalog_document_for_test()
  let first_labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(page_label_bytes_for_test("intro-")),
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 3,
      start_value: 1,
    },
  ]
  let first_doc = try! first_doc.write_page_labels(first_labels)
  let second_doc = page_label_catalog_document_for_test()
  let second_labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(page_label_bytes_for_test("sec-")),
      start_page: 1,
      start_value: 10,
    },
  ]
  let second_doc = try! second_doc.write_page_labels(second_labels)
  let merged = try! @pdflite.pdf_page_label_merge([first_doc, second_doc], [
    [2, 3],
    [1, 2],
  ])
  @test.assert_eq(merged, [
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(page_label_bytes_for_test("intro-")),
      start_page: 1,
      start_value: 2,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 2,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(page_label_bytes_for_test("sec-")),
      start_page: 3,
      start_value: 10,
    },
  ])
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(1, merged),
    Some(page_label_bytes_for_test("intro-ii")),
  )
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(2, merged),
    Some(page_label_bytes_for_test("1")),
  )
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(4, merged),
    Some(page_label_bytes_for_test("sec-11")),
  )
}

///|
test "pdf_page_label_merge uses basic labels for unlabeled source PDFs" {
  let doc = page_label_catalog_document_for_test()
  let merged = try! @pdflite.pdf_page_label_merge([doc], [[2, 3]])
  @test.assert_eq(merged, [
    { ..@pdflite.pdf_page_label_basic, start_page: 1, start_value: 2 },
  ])
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(2, merged),
    Some(page_label_bytes_for_test("3")),
  )
}

///|
test "pdf_page_label_merge rejects mismatched inputs" {
  let doc = page_label_catalog_document_for_test()
  let result : Result[Array[@pdflite.PdfPageLabel], Error] = try? @pdflite.pdf_page_label_merge(
    [doc],
    [],
  )
  guard result is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected @pdflite.PdfError::PageTreeExpected")
  }
}

///|
test "PdfDocument add_page_labels splits ranges and progresses numbering" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 5)
  let updated = try! document.add_page_labels(
    true,
    PageLabelDecimalArabic,
    Some(page_label_bytes_for_test("A-")),
    10,
    [2, 3, 5],
  )
  let labels = try! updated.read_page_labels()
  @test.assert_eq(labels, [
    @pdflite.pdf_page_label_basic,
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(page_label_bytes_for_test("A-")),
      start_page: 2,
      start_value: 10,
    },
    { ..@pdflite.pdf_page_label_basic, start_page: 4, start_value: 4 },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(page_label_bytes_for_test("A-")),
      start_page: 5,
      start_value: 12,
    },
  ])
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(3, labels),
    Some(page_label_bytes_for_test("A-11")),
  )
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(5, labels),
    Some(page_label_bytes_for_test("A-12")),
  )
}

///|
test "pdf_add_page_labels can reuse start value for each range" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 5)
  let updated = try! @pdflite.pdf_add_page_labels(
    document,
    false,
    PageLabelDecimalArabic,
    Some(page_label_bytes_for_test("A-")),
    10,
    [2, 3, 5],
  )
  let labels = try! updated.read_page_labels()
  @test.assert_eq(labels[3], {
    label_style: PageLabelDecimalArabic,
    label_prefix: Some(page_label_bytes_for_test("A-")),
    start_page: 5,
    start_value: 10,
  })
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(5, labels),
    Some(page_label_bytes_for_test("A-10")),
  )
}

///|
test "PdfDocument add_page_labels_json writes cpdf JSON label array" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 3)
  let prefix = try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode("Résumé-"))
  let json : Json = [
    {
      "labelstyle": "LowercaseRoman",
      "labelprefix": "Résumé-",
      "startpage": 1.0,
      "startvalue": 3.0,
    },
    {
      "labelstyle": "NoLabelPrefixOnly",
      "labelprefix": null,
      "startpage": 3.0,
      "startvalue": 1.0,
    },
  ]
  let expected : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(prefix),
      start_page: 1,
      start_value: 3,
    },
    {
      label_style: PageLabelNoLabelPrefixOnly,
      label_prefix: None,
      start_page: 3,
      start_value: 1,
    },
  ]

  let updated = try! document.add_page_labels_json(json)
  let updated_from_wrapper = try! @pdflite.pdf_add_page_labels_json(
    document, json,
  )

  @test.assert_eq(try! updated.read_page_labels(), expected)
  @test.assert_eq(try! updated_from_wrapper.read_page_labels(), expected)
}

///|
test "PdfDocument add_page_labels_json rejects malformed JSON" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 1)
  let not_list : Json = {}
  let malformed : Result[@pdflite.PdfDocument, Error] = try? document.add_page_labels_json(
    not_list,
  )
  guard malformed is Err(@pdflite.PdfError::BadText) else {
    fail("expected BadText for non-list page-label JSON")
  }

  let missing_field : Json = [
    { "labelstyle": "DecimalArabic", "labelprefix": null, "startpage": 1.0 },
  ]
  let missing_result : Result[@pdflite.PdfDocument, Error] = try? document.add_page_labels_json(
    missing_field,
  )
  guard missing_result is Err(@pdflite.PdfError::BadText) else {
    fail("expected BadText for missing page-label JSON field")
  }

  let bad_style : Json = [
    {
      "labelstyle": "Missing",
      "labelprefix": null,
      "startpage": 1.0,
      "startvalue": 1.0,
    },
  ]
  let style_result : Result[@pdflite.PdfDocument, Error] = try? document.add_page_labels_json(
    bad_style,
  )
  guard style_result
    is Err(@pdflite.PdfError::PageLabelStyleExpected("Missing")) else {
    fail("expected PageLabelStyleExpected for bad page-label style")
  }
}

///|
test "PdfDocument add_page_labels preserves an existing page one label" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 5)
  let original : @pdflite.PdfPageLabel = {
    label_style: PageLabelLowercaseRoman,
    label_prefix: Some(page_label_bytes_for_test("pre-")),
    start_page: 1,
    start_value: 3,
  }
  let seeded = try! document.write_page_labels([original])
  let updated = try! seeded.add_page_labels(
    false,
    PageLabelUppercaseLetters,
    None,
    1,
    [3],
  )
  let labels = try! updated.read_page_labels()
  @test.assert_eq(labels, [
    original,
    {
      label_style: PageLabelUppercaseLetters,
      label_prefix: None,
      start_page: 3,
      start_value: 1,
    },
    { ..original, start_page: 4, start_value: 6 },
  ])
}

///|
test "PdfDocument add_page_labels rejects empty page ranges" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 1)
  let result : Result[@pdflite.PdfDocument, Error] = try? document.add_page_labels(
    false,
    PageLabelDecimalArabic,
    None,
    1,
    [],
  )
  guard result
    is Err(@pdflite.PdfError::BadPageSpecification("empty page label range")) else {
    fail("expected empty page-label range error")
  }
}

///|
fn merge_one_page_doc_for_test(
  major : Int,
  minor : Int,
) -> @pdflite.PdfDocument {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.set_version(major, minor)
  doc
}

///|
fn merge_bookmarked_doc_for_test(label : String) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  let page_refs = try! doc.page_reference_numbers()
  try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode(label),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn merge_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn merge_add_catalog_entry_for_test(
  doc : @pdflite.PdfDocument,
  key : @pdflite.PdfName,
  value : @pdflite.PdfObject,
) -> @pdflite.PdfDocument {
  let root = doc.lookup_object_or_null(doc.root())
  let new_root = doc.add_object(try! root.add_dict_entry(key, value))
  doc.set_root(new_root)
  doc.set_trailer_dict(
    try! doc
    .trailer_dict()
    .add_dict_entry(merge_name_for_test("/Root"), PdfIndirect(new_root)),
  )
  doc
}

///|
fn merge_destination_object_for_test(
  doc : @pdflite.PdfDocument,
) -> @pdflite.PdfObject {
  let page_refs = try! doc.page_reference_numbers()
  @pdflite.pdf_object_of_destination(DestFit(TargetPageObject(page_refs[0])))
}

///|
fn merge_ocg_doc_for_test(number : Int, label : String) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 5)
  try! doc.write_optional_content_groups({
    ocgs: [
      (
        number,
        {
          name: @ascii.encode(label),
          intent: [merge_name_for_test("/View")],
          usage: None,
        },
      ),
    ],
    default_config: {
      ..@pdflite.pdf_ocg_default_config(),
      on: [number],
      order: Some([(Some(@ascii.encode(label)), [number])]),
    },
    configs: [],
  })
}

///|
fn merge_oldstyle_dest_doc_for_test(name : String) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  let dests : @pdflite.PdfObject = PdfDictionary([
    (merge_name_for_test(name), merge_destination_object_for_test(doc)),
  ])
  merge_add_catalog_entry_for_test(doc, merge_name_for_test("/Dests"), dests)
}

///|
fn merge_nametree_dest_doc_for_test(name : String) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  let tree = doc.build_name_tree([
    (@ascii.encode(name), merge_destination_object_for_test(doc)),
  ])
  let names : @pdflite.PdfObject = PdfDictionary([
    (merge_name_for_test("/Dests"), tree),
  ])
  merge_add_catalog_entry_for_test(doc, merge_name_for_test("/Names"), names)
}

///|
fn merge_name_dictionary_doc_for_test(
  tree_key : @pdflite.PdfName,
  name : String,
  value : String,
) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  let tree = doc.build_name_tree([
    (@ascii.encode(name), PdfString(@ascii.encode(value))),
  ])
  let names : @pdflite.PdfObject = PdfDictionary([(tree_key, tree)])
  merge_add_catalog_entry_for_test(doc, merge_name_for_test("/Names"), names)
}

///|
fn merge_info_doc_for_test(title : String) -> @pdflite.PdfDocument {
  let key_info = merge_name_for_test("/Info")
  let key_title = merge_name_for_test("/Title")
  let doc = merge_one_page_doc_for_test(1, 4)
  let info_number = doc.add_object(
    PdfDictionary([(key_title, PdfString(@ascii.encode(title)))]),
  )
  doc.set_trailer_dict(
    try! doc.trailer_dict().add_dict_entry(key_info, PdfIndirect(info_number)),
  )
  doc
}

///|
fn merge_acroform_doc_for_test(
  field_number : Int,
  label : String,
) -> @pdflite.PdfDocument {
  let key_acroform = merge_name_for_test("/AcroForm")
  let key_fields = merge_name_for_test("/Fields")
  let key_t = merge_name_for_test("/T")
  let doc = merge_one_page_doc_for_test(1, 6)
  doc.add_object_given_number(
    field_number,
    PdfDictionary([(key_t, PdfString(@ascii.encode(label)))]),
  )
  let form : @pdflite.PdfObject = PdfDictionary([
    (key_fields, PdfArray([PdfIndirect(field_number)])),
  ])
  merge_add_catalog_entry_for_test(doc, key_acroform, form)
}

///|
fn merge_duplicate_stream_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_stream(
    PdfDictionary([(merge_name_for_test("/Length"), PdfInteger(2))]),
    StreamGot(@ascii.encode("Hi")),
  )
}

///|
fn merge_catalog_stream_doc_for_test(
  key : @pdflite.PdfName,
  stream_number : Int,
) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  doc.add_object_given_number(stream_number, merge_duplicate_stream_for_test())
  merge_add_catalog_entry_for_test(doc, key, PdfIndirect(stream_number))
}

///|
test "pdf_merge_documents concatenates selected pages from renumbered inputs" {
  let first = merge_one_page_doc_for_test(1, 4)
  let second = merge_one_page_doc_for_test(1, 7)
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  @test.assert_eq(merged.version(), (1, 7))
  @test.assert_eq(try! merged.endpage(), 2)
  let rendered = try! @pdflite.pdf_write_document(merged)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.version(), (1, 7))
  @test.assert_eq(try! parsed.endpage(), 2)
}

///|
test "pdf_merge_documents optionally retains merged page labels" {
  let first = try! merge_one_page_doc_for_test(1, 4).write_page_labels([
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(@ascii.encode("A-")),
      start_page: 1,
      start_value: 1,
    },
  ])
  let second = try! merge_one_page_doc_for_test(1, 4).write_page_labels([
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(@ascii.encode("B-")),
      start_page: 1,
      start_value: 4,
    },
  ])
  let without_labels = try! @pdflite.pdf_merge_documents([first, second], [
    [1],
    [1],
  ])
  @test.assert_eq(try! without_labels.read_page_labels(), [])
  let retained = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_numbering=true,
  )
  @test.assert_eq(
    try! retained.read_page_labels(),
    try! @pdflite.pdf_page_label_merge([first, second], [[1], [1]]),
  )
}

///|
test "pdf_merge_documents retargets retained bookmarks to merged pages" {
  let first = merge_bookmarked_doc_for_test("A")
  let second = merge_bookmarked_doc_for_test("B")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let bookmarks = try! merged.read_bookmarks()
  @test.assert_eq([ for bookmark in bookmarks => bookmark.text ], [
    @ascii.encode("A"),
    @ascii.encode("B"),
  ])
  @test.assert_eq(try! merged.page_number_of_target(bookmarks[0].target), 1)
  @test.assert_eq(try! merged.page_number_of_target(bookmarks[1].target), 2)
  let without_bookmarks = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_bookmarks=false,
  )
  @test.assert_eq(try! without_bookmarks.read_bookmarks(), [])
}

///|
test "pdf_merge_documents retains optional content groups before pruning" {
  let first = merge_ocg_doc_for_test(20, "Layer A")
  let second = merge_ocg_doc_for_test(20, "Layer B")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  guard (try! merged.read_optional_content_groups()) is Some(content) else {
    fail("expected optional content")
  }
  @test.assert_eq(content.ocgs.length(), 2)
  @test.assert_eq(content.ocgs[0].1.name, @ascii.encode("Layer A"))
  @test.assert_eq(content.ocgs[1].1.name, @ascii.encode("Layer B"))
  @test.assert_eq(content.default_config.on.length(), 2)
  let without_ocg = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_optional_content=false,
  )
  @test.assert_eq(try! without_ocg.read_optional_content_groups(), None)
}

///|
test "pdf_merge_documents merges AcroForm fields" {
  let key_acroform = merge_name_for_test("/AcroForm")
  let key_fields = merge_name_for_test("/Fields")
  let key_t = merge_name_for_test("/T")
  let first = merge_acroform_doc_for_test(30, "first")
  let second = merge_acroform_doc_for_test(30, "second")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let root = merged.lookup_object_or_null(merged.root())
  guard merged.lookup_direct(key_acroform, root) is Some(form) else {
    fail("expected AcroForm")
  }
  guard form.lookup_immediate(key_fields) is Some(PdfArray(fields)) else {
    fail("expected AcroForm fields")
  }
  @test.assert_eq(fields.length(), 2)
  guard fields[0] is PdfIndirect(first_field) else {
    fail("expected first field reference")
  }
  guard fields[1] is PdfIndirect(second_field) else {
    fail("expected second field reference")
  }
  @test.assert_eq(
    merged.lookup_object_or_null(first_field).lookup_immediate(key_t),
    Some(PdfString(@ascii.encode("first"))),
  )
  @test.assert_eq(
    merged.lookup_object_or_null(second_field).lookup_immediate(key_t),
    Some(PdfString(@ascii.encode("second"))),
  )
  let without_acroform = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_acroforms=false,
  )
  @test.assert_eq(
    without_acroform.lookup_direct(
      key_acroform,
      without_acroform.lookup_object_or_null(without_acroform.root()),
    ),
    None,
  )
}

///|
test "pdf_merge_documents retains and retargets named destinations" {
  let oldstyle_name = merge_name_for_test("/First")
  let first = merge_oldstyle_dest_doc_for_test("/First")
  let second = merge_nametree_dest_doc_for_test("second")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  @test.assert_eq(
    try! merged.page_number_of_target(
      try! merged.read_destination(PdfNameObject(oldstyle_name)),
    ),
    1,
  )
  @test.assert_eq(
    try! merged.page_number_of_target(
      try! merged.read_destination(PdfString(@ascii.encode("second"))),
    ),
    2,
  )
  let without_destinations = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_named_destinations=false,
  )
  @test.assert_eq(
    try! without_destinations.read_destination(PdfNameObject(oldstyle_name)),
    DestNamed(oldstyle_name),
  )
  @test.assert_eq(
    try! without_destinations.read_destination(
      PdfString(@ascii.encode("second")),
    ),
    DestString(@ascii.encode("second")),
  )
}

///|
test "pdf_merge_documents retains non-destination name trees" {
  let key_names = merge_name_for_test("/Names")
  let key_embedded_files = merge_name_for_test("/EmbeddedFiles")
  let key_javascript = merge_name_for_test("/JavaScript")
  let first = merge_name_dictionary_doc_for_test(
    key_embedded_files, "file-a", "payload-a",
  )
  let second = merge_name_dictionary_doc_for_test(
    key_javascript, "script-b", "payload-b",
  )
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let root = merged.lookup_object_or_null(merged.root())
  guard root.lookup_immediate(key_names) is Some(names) else {
    fail("expected Names dictionary")
  }
  guard merged.lookup_direct(key_embedded_files, names) is Some(embedded_tree) else {
    fail("expected EmbeddedFiles tree")
  }
  guard merged.lookup_direct(key_javascript, names) is Some(javascript_tree) else {
    fail("expected JavaScript tree")
  }
  @test.assert_eq(merged.read_name_tree(embedded_tree), [
    (@ascii.encode("file-a"), PdfString(@ascii.encode("payload-a"))),
  ])
  @test.assert_eq(merged.read_name_tree(javascript_tree), [
    (@ascii.encode("script-b"), PdfString(@ascii.encode("payload-b"))),
  ])
  let without_names = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_name_dictionary=false,
  )
  let root = without_names.lookup_object_or_null(without_names.root())
  @test.assert_eq(root.lookup_immediate(key_names), None)
}

///|
test "pdf_merge_documents retains first document info dictionary" {
  let key_info = merge_name_for_test("/Info")
  let key_title = merge_name_for_test("/Title")
  let first = merge_info_doc_for_test("first")
  let second = merge_info_doc_for_test("second")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  guard merged.lookup_direct(key_info, merged.trailer_dict()) is Some(info) else {
    fail("expected Info")
  }
  @test.assert_eq(
    info.lookup_immediate(key_title),
    Some(PdfString(@ascii.encode("first"))),
  )
  let without_info = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_info=false,
  )
  @test.assert_eq(
    without_info.lookup_direct(key_info, without_info.trailer_dict()),
    None,
  )
}

///|
test "pdf_merge_documents retains safe catalog entries" {
  let key_page_mode = merge_name_for_test("/PageMode")
  let key_viewer_preferences = merge_name_for_test("/ViewerPreferences")
  let key_open_action = merge_name_for_test("/OpenAction")
  let first = merge_add_catalog_entry_for_test(
    merge_one_page_doc_for_test(1, 4),
    key_page_mode,
    PdfNameObject(merge_name_for_test("/UseOutlines")),
  )
  let first = merge_add_catalog_entry_for_test(
    first,
    key_open_action,
    PdfString(@ascii.encode("drop")),
  )
  let preferences : @pdflite.PdfObject = PdfDictionary([
    (merge_name_for_test("/HideToolbar"), PdfBoolean(true)),
  ])
  let second = merge_add_catalog_entry_for_test(
    merge_one_page_doc_for_test(1, 4),
    key_viewer_preferences,
    preferences,
  )
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let root = merged.lookup_object_or_null(merged.root())
  @test.assert_eq(
    root.lookup_immediate(key_page_mode),
    Some(PdfNameObject(merge_name_for_test("/UseOutlines"))),
  )
  @test.assert_eq(
    root.lookup_immediate(key_viewer_preferences),
    Some(preferences),
  )
  @test.assert_eq(root.lookup_immediate(key_open_action), None)
  let without_catalog_entries = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_catalog_entries=false,
  )
  let root = without_catalog_entries.lookup_object_or_null(
    without_catalog_entries.root(),
  )
  @test.assert_eq(root.lookup_immediate(key_page_mode), None)
  @test.assert_eq(root.lookup_immediate(key_viewer_preferences), None)
}

///|
test "PdfDocument remove_duplicate_fonts coalesces identical streams" {
  let key_info = merge_name_for_test("/Info")
  let doc = @pdflite.pdf_document_empty()
  let stream = merge_duplicate_stream_for_test()
  doc.add_object_given_number(1, stream)
  doc.add_object_given_number(2, stream)
  doc.add_object_given_number(3, PdfArray([PdfIndirect(1), PdfIndirect(2)]))
  doc.set_trailer_dict(PdfDictionary([(key_info, PdfIndirect(2))]))
  doc.remove_duplicate_fonts()
  @test.assert_eq(doc.lookup_object_or_null(1), stream)
  @test.assert_eq(doc.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(
    doc.lookup_object_or_null(3),
    PdfArray([PdfIndirect(1), PdfIndirect(1)]),
  )
  @test.assert_eq(
    doc.trailer_dict().lookup_immediate(key_info),
    Some(PdfIndirect(1)),
  )
}

///|
test "pdf_merge_documents can remove duplicate font streams" {
  let key_first_stream = merge_name_for_test("/PieceInfo")
  let key_second_stream = merge_name_for_test("/Metadata")
  let first = merge_catalog_stream_doc_for_test(key_first_stream, 30)
  let second = merge_catalog_stream_doc_for_test(key_second_stream, 30)
  let without_dedupe = try! @pdflite.pdf_merge_documents([first, second], [
    [1],
    [1],
  ])
  let root = without_dedupe.lookup_object_or_null(without_dedupe.root())
  guard root.lookup_immediate(key_first_stream)
    is Some(PdfIndirect(first_stream)) else {
    fail("expected first stream")
  }
  guard root.lookup_immediate(key_second_stream)
    is Some(PdfIndirect(second_stream)) else {
    fail("expected second stream")
  }
  @test.assert_eq(first_stream == second_stream, false)
  let deduped = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    remove_duplicate_fonts=true,
  )
  let root = deduped.lookup_object_or_null(deduped.root())
  guard root.lookup_immediate(key_first_stream)
    is Some(PdfIndirect(first_stream)) else {
    fail("expected deduped first stream")
  }
  guard root.lookup_immediate(key_second_stream)
    is Some(PdfIndirect(second_stream)) else {
    fail("expected deduped second stream")
  }
  @test.assert_eq(first_stream, second_stream)
  @test.assert_eq(
    deduped.lookup_object_or_null(first_stream),
    merge_duplicate_stream_for_test(),
  )
}

///|
test "pdf_merge_documents rejects empty and mismatched inputs" {
  let doc = merge_one_page_doc_for_test(1, 4)
  let empty : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_merge_documents(
    [],
    [],
  )
  guard empty is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected for empty merge")
  }
  let mismatched : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_merge_documents(
    [doc],
    [],
  )
  guard mismatched is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected for mismatched merge")
  }
}

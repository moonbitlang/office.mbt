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
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn merge_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn merge_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn merge_restore_env_for_test(previous : String?) -> Unit {
  match previous {
    Some(value) => @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", value)
    None => @env.unset_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  }
}

///|
fn merge_add_catalog_entry_for_test(
  doc : @pdflite.PdfDocument,
  key : @core.PdfName,
  value : @syntax.PdfObject,
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
) -> @syntax.PdfObject {
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
      ..@ocg.pdf_ocg_default_config(),
      on: [number],
      order: Some([(Some(@ascii.encode(label)), [number])]),
    },
    configs: [],
  })
}

///|
fn merge_oldstyle_dest_doc_for_test(name : String) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  let dests : @syntax.PdfObject = PdfDictionary([
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
  let names : @syntax.PdfObject = PdfDictionary([
    (merge_name_for_test("/Dests"), tree),
  ])
  merge_add_catalog_entry_for_test(doc, merge_name_for_test("/Names"), names)
}

///|
fn merge_nametree_dest_callsite_doc_for_test(
  name : String,
  label : String,
) -> @pdflite.PdfDocument {
  let key_annots = merge_name_for_test("/Annots")
  let key_subtype = merge_name_for_test("/Subtype")
  let key_dest = merge_name_for_test("/Dest")
  let type_link = merge_name_for_test("/Link")
  let annotation_number = 50
  let doc = merge_nametree_dest_doc_for_test(name)
  let page_refs = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    annotation_number,
    PdfDictionary([
      (key_subtype, PdfNameObject(type_link)),
      (key_dest, PdfString(@ascii.encode(name))),
    ]),
  )
  doc.add_object_given_number(
    page_refs[0],
    try! doc
    .lookup_object_or_null(page_refs[0])
    .add_dict_entry(key_annots, PdfArray([PdfIndirect(annotation_number)])),
  )
  try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode(label),
      target: DestString(@ascii.encode(name)),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn merge_oldstyle_dest_callsite_doc_for_test(
  name : String,
  label : String,
) -> @pdflite.PdfDocument {
  let key_annots = merge_name_for_test("/Annots")
  let key_subtype = merge_name_for_test("/Subtype")
  let key_dest = merge_name_for_test("/Dest")
  let type_link = merge_name_for_test("/Link")
  let annotation_number = 51
  let doc = merge_oldstyle_dest_doc_for_test(name)
  let destination_name = merge_name_for_test(name)
  let page_refs = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    annotation_number,
    PdfDictionary([
      (key_subtype, PdfNameObject(type_link)),
      (key_dest, PdfNameObject(destination_name)),
    ]),
  )
  doc.add_object_given_number(
    page_refs[0],
    try! doc
    .lookup_object_or_null(page_refs[0])
    .add_dict_entry(key_annots, PdfArray([PdfIndirect(annotation_number)])),
  )
  try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode(label),
      target: DestNamed(destination_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn merge_external_dest_callsite_doc_for_test(
  destination : @syntax.PdfObject,
) -> @pdflite.PdfDocument {
  let key_annots = merge_name_for_test("/Annots")
  let key_subtype = merge_name_for_test("/Subtype")
  let key_dest = merge_name_for_test("/Dest")
  let type_link = merge_name_for_test("/Link")
  let annotation_number = 52
  let doc = merge_one_page_doc_for_test(1, 4)
  let page_refs = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    annotation_number,
    PdfDictionary([
      (key_subtype, PdfNameObject(type_link)),
      (key_dest, destination),
    ]),
  )
  doc.add_object_given_number(
    page_refs[0],
    try! doc
    .lookup_object_or_null(page_refs[0])
    .add_dict_entry(key_annots, PdfArray([PdfIndirect(annotation_number)])),
  )
  doc
}

///|
fn merge_destination_name_entries_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[(@core.PdfBytes, @syntax.PdfObject)] {
  match
    doc.lookup_chain(doc.lookup_object_or_null(doc.root()), [
      merge_name_for_test("/Names"),
      merge_name_for_test("/Dests"),
    ]) {
    Some(tree) => doc.read_name_tree(tree)
    None => []
  }
}

///|
fn merge_first_annotation_dest_for_test(
  doc : @pdflite.PdfDocument,
  page_index : Int,
) -> @syntax.PdfObject? {
  let page_refs = try! doc.page_reference_numbers()
  match
    doc
    .lookup_object_or_null(page_refs[page_index])
    .lookup_immediate(merge_name_for_test("/Annots")) {
    Some(PdfArray([PdfIndirect(annotation_number), ..])) =>
      doc
      .lookup_object_or_null(annotation_number)
      .lookup_immediate(merge_name_for_test("/Dest"))
    _ => None
  }
}

///|
fn merge_catalog_destination_for_test(
  doc : @pdflite.PdfDocument,
  name : @core.PdfName,
) -> @syntax.PdfObject? {
  match
    doc
    .lookup_object_or_null(doc.root())
    .lookup_immediate(merge_name_for_test("/Dests")) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        let (key, value) = entry
        if key == name {
          break Some(value)
        }
      } nobreak {
        None
      }
    _ => None
  }
}

///|
fn merge_name_dictionary_doc_for_test(
  tree_key : @core.PdfName,
  name : String,
  value : String,
) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  let tree = doc.build_name_tree([
    (@ascii.encode(name), PdfString(@ascii.encode(value))),
  ])
  let names : @syntax.PdfObject = PdfDictionary([(tree_key, tree)])
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
fn merge_acroform_doc_with_entries_for_test(
  field_number : Int,
  label : String,
  extra_entries : ArrayView[(@core.PdfName, @syntax.PdfObject)],
) -> @pdflite.PdfDocument {
  let key_acroform = merge_name_for_test("/AcroForm")
  let key_fields = merge_name_for_test("/Fields")
  let key_t = merge_name_for_test("/T")
  let doc = merge_one_page_doc_for_test(1, 6)
  doc.add_object_given_number(
    field_number,
    PdfDictionary([(key_t, PdfString(@ascii.encode(label)))]),
  )
  let form_entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (key_fields, PdfArray([PdfIndirect(field_number)])),
  ]
  for entry in extra_entries {
    form_entries.push(entry)
  }
  let form : @syntax.PdfObject = PdfDictionary(form_entries)
  merge_add_catalog_entry_for_test(doc, key_acroform, form)
}

///|
fn merge_pdfmergeexample_workflow_for_test(
  documents : ArrayView[@pdflite.PdfDocument],
) -> @pdflite.PdfDocument {
  let renumbered = try! @pdflite.pdf_renumber_documents(documents)
  let merged = @pdflite.pdf_document_empty()
  let pages : Array[@page.PdfPage] = []
  let mut max_minor = 0
  for document in renumbered {
    let (_, minor) = document.version()
    if minor > max_minor {
      max_minor = minor
    }
    for number in document.object_numbers() {
      merged.add_object_given_number(
        number,
        document.lookup_object_or_null(number),
      )
    }
    let document_pages = try! document.pages_of_pagetree()
    for page in document_pages {
      pages.push(page)
    }
  }
  let page_root = try! merged.add_pagetree(pages)
  ignore(try! merged.add_root(page_root, []))
  merged.set_version(1, max_minor)
  try! merged.remove_unreferenced()
  merged
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
test "pdfmergeexample-style workflow renumbers copies and roundtrips" {
  let detached : @syntax.PdfObject = PdfString(@ascii.encode("detached"))
  let first = merge_one_page_doc_for_test(1, 4)
  first.add_object_given_number(99, detached)
  let second = merge_one_page_doc_for_test(1, 7)
  let merged = merge_pdfmergeexample_workflow_for_test([first, second])
  @test.assert_eq(merged.version(), (1, 7))
  @test.assert_eq(try! merged.endpage(), 2)
  let mut retained_detached = false
  for number in merged.object_numbers() {
    if merged.lookup_object_or_null(number) == detached {
      retained_detached = true
    }
  }
  @test.assert_eq(retained_detached, false)
  let rendered = try! @pdflite.pdf_write_document(merged)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.version(), (1, 7))
  @test.assert_eq(try! parsed.endpage(), 2)
  let page_refs = try! parsed.page_reference_numbers()
  @test.assert_eq(page_refs.length(), 2)
  @test.assert_eq(page_refs[0] != page_refs[1], true)
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
test "pdf_merge_pdfs exposes CamlPDF-shaped merge wrapper" {
  let first = try! merge_one_page_doc_for_test(1, 4).write_page_labels([
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(@ascii.encode("A-")),
      start_page: 1,
      start_value: 1,
    },
  ])
  let second = try! merge_one_page_doc_for_test(1, 5).write_page_labels([
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(@ascii.encode("B-")),
      start_page: 1,
      start_value: 4,
    },
  ])
  let merged = try! @pdflite.pdf_merge_pdfs(
    true,
    false,
    ["a.pdf", "b.pdf"],
    [first, second],
    [[1], [1]],
    process_struct_trees=false,
  )
  @test.assert_eq(try! merged.endpage(), 2)
  @test.assert_eq(merged.version(), (1, 5))
  @test.assert_eq(
    try! merged.read_page_labels(),
    try! @pdflite.pdf_page_label_merge([first, second], [[1], [1]]),
  )
  let bad_names : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_merge_pdfs(
    false,
    false,
    ["a.pdf"],
    [first, second],
    [[1], [1]],
  )
  guard bad_names is Err(_) else {
    fail("expected name/document length mismatch to raise")
  }
}

///|
test "pdf_merge_pdfs repeated names preserve per-inclusion destinations" {
  let source = merge_nametree_dest_callsite_doc_for_test("shared", "Same")
  let merged = try! @pdflite.pdf_merge_pdfs(
    false,
    false,
    ["same.pdf", "same.pdf"],
    [source, source],
    [[1], [1]],
    process_struct_trees=false,
  )
  let first_name = @ascii.encode("shared-f0")
  let second_name = @ascii.encode("shared-f1")
  @test.assert_eq(try! merged.endpage(), 2)
  @test.assert_eq(
    [
      for entry in merge_destination_name_entries_for_test(merged) => entry.0
    ],
    [first_name, second_name],
  )
  @test.assert_eq(
    merge_first_annotation_dest_for_test(merged, 0),
    Some(PdfString(first_name)),
  )
  @test.assert_eq(
    merge_first_annotation_dest_for_test(merged, 1),
    Some(PdfString(second_name)),
  )
  @test.assert_eq(
    try! merged.page_number_of_target(
      try! merged.read_destination(PdfString(first_name)),
    ),
    1,
  )
  @test.assert_eq(
    try! merged.page_number_of_target(
      try! merged.read_destination(PdfString(second_name)),
    ),
    2,
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
test "pdf_merge_documents ignores malformed source bookmarks" {
  let key_dest = merge_name_for_test("/Dest")
  let key_first = merge_name_for_test("/First")
  let key_last = merge_name_for_test("/Last")
  let key_outlines = merge_name_for_test("/Outlines")
  let key_parent = merge_name_for_test("/Parent")
  let key_title = merge_name_for_test("/Title")
  let type_fitr = merge_name_for_test("/FitR")
  let bad_coordinate = merge_name_for_test("/Bad")
  let first = merge_one_page_doc_for_test(1, 4)
  let first_page_refs = try! first.page_reference_numbers()
  first.add_object_given_number(
    40,
    PdfDictionary([(key_first, PdfIndirect(41)), (key_last, PdfIndirect(41))]),
  )
  first.add_object_given_number(
    41,
    PdfDictionary([
      (key_parent, PdfIndirect(40)),
      (key_title, PdfString(@ascii.encode("bad"))),
      (
        key_dest,
        PdfArray([
          PdfIndirect(first_page_refs[0]),
          PdfNameObject(type_fitr),
          PdfNameObject(bad_coordinate),
          PdfInteger(2),
          PdfInteger(3),
          PdfInteger(4),
        ]),
      ),
    ]),
  )
  let first = merge_add_catalog_entry_for_test(
    first,
    key_outlines,
    PdfIndirect(40),
  )
  let second = merge_bookmarked_doc_for_test("B")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let bookmarks = try! merged.read_bookmarks()
  @test.assert_eq([ for bookmark in bookmarks => bookmark.text ], [
    @ascii.encode("B"),
  ])
  @test.assert_eq(try! merged.page_number_of_target(bookmarks[0].target), 2)
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
test "pdf_merge_documents ignores malformed optional content merge data" {
  let key_ocproperties = merge_name_for_test("/OCProperties")
  let key_ocgs = merge_name_for_test("/OCGs")
  let malformed = merge_add_catalog_entry_for_test(
    merge_one_page_doc_for_test(1, 5),
    key_ocproperties,
    PdfDictionary([(key_ocgs, PdfArray([]))]),
  )
  let valid = merge_ocg_doc_for_test(20, "Layer A")
  let merged = try! @pdflite.pdf_merge_documents([malformed, valid], [[1], [1]])
  @test.assert_eq(try! merged.read_optional_content_groups(), None)
}

///|
test "pdf_merge_documents merges AcroForm fields" {
  let key_acroform = merge_name_for_test("/AcroForm")
  let key_fields = merge_name_for_test("/Fields")
  let key_need_appearances = merge_name_for_test("/NeedAppearances")
  let key_t = merge_name_for_test("/T")
  let first = merge_acroform_doc_with_entries_for_test(30, "first", [
    (key_need_appearances, PdfBoolean(false)),
  ])
  let second = merge_acroform_doc_with_entries_for_test(30, "second", [
    (key_need_appearances, PdfBoolean(true)),
  ])
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
  guard form.dictionary_view() is Some(form_entries) else {
    fail("expected AcroForm dictionary")
  }
  let appearances : Array[@syntax.PdfObject] = []
  for entry in form_entries {
    let (key, value) = entry
    if key == key_need_appearances {
      appearances.push(value)
    }
  }
  @test.assert_eq(appearances, [PdfBoolean(true)])
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
test "pdf_merge_documents tolerates malformed named destinations" {
  let key_names = merge_name_for_test("/Names")
  let key_dests = merge_name_for_test("/Dests")
  let type_fitr = merge_name_for_test("/FitR")
  let bad_coordinate = merge_name_for_test("/Bad")
  let catalog_name = merge_name_for_test("/BadCatalog")
  let string_name = @ascii.encode("bad-string")
  let doc = merge_one_page_doc_for_test(1, 4)
  let page_refs = try! doc.page_reference_numbers()
  let bad_destination : @syntax.PdfObject = PdfArray([
    PdfIndirect(page_refs[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  let with_names = merge_add_catalog_entry_for_test(
    doc,
    key_names,
    PdfDictionary([
      (key_dests, doc.build_name_tree([(string_name, bad_destination)])),
    ]),
  )
  let with_destinations = merge_add_catalog_entry_for_test(
    with_names,
    key_dests,
    PdfDictionary([(catalog_name, bad_destination)]),
  )
  let merged = try! @pdflite.pdf_merge_documents([with_destinations], [[1]])
  let merged_page_refs = try! merged.page_reference_numbers()
  let renumbered_bad_destination : @syntax.PdfObject = PdfArray([
    PdfIndirect(merged_page_refs[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  @test.assert_eq(
    merge_catalog_destination_for_test(merged, catalog_name),
    Some(renumbered_bad_destination),
  )
  @test.assert_eq(merge_destination_name_entries_for_test(merged), [
    (string_name, renumbered_bad_destination),
  ])
}

///|
test "pdf_merge_documents renames colliding string destinations" {
  let first = merge_nametree_dest_callsite_doc_for_test("shared", "First")
  let second = merge_nametree_dest_callsite_doc_for_test("shared", "Second")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let first_name = @ascii.encode("shared-f0")
  let second_name = @ascii.encode("shared-f1")
  @test.assert_eq(
    [
      for entry in merge_destination_name_entries_for_test(merged) => entry.0
    ],
    [first_name, second_name],
  )
  @test.assert_eq(
    merge_first_annotation_dest_for_test(merged, 0),
    Some(PdfString(first_name)),
  )
  @test.assert_eq(
    merge_first_annotation_dest_for_test(merged, 1),
    Some(PdfString(second_name)),
  )
  @test.assert_eq(try! merged.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("First"),
      target: DestString(first_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestString(second_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  @test.assert_eq(
    try! merged.page_number_of_target(
      try! merged.read_destination(PdfString(first_name)),
    ),
    1,
  )
  @test.assert_eq(
    try! merged.page_number_of_target(
      try! merged.read_destination(PdfString(second_name)),
    ),
    2,
  )
}

///|
test "pdf_merge_documents renames colliding catalog destinations" {
  let first = merge_oldstyle_dest_callsite_doc_for_test("/Shared", "First")
  let second = merge_oldstyle_dest_callsite_doc_for_test("/Shared", "Second")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let first_name = merge_name_for_test("/Shared-f0")
  let second_name = merge_name_for_test("/Shared-f1")
  guard merge_catalog_destination_for_test(merged, first_name) is Some(_) else {
    fail("expected first renamed catalog destination")
  }
  guard merge_catalog_destination_for_test(merged, second_name) is Some(_) else {
    fail("expected second renamed catalog destination")
  }
  @test.assert_eq(
    merge_first_annotation_dest_for_test(merged, 0),
    Some(PdfNameObject(first_name)),
  )
  @test.assert_eq(
    merge_first_annotation_dest_for_test(merged, 1),
    Some(PdfNameObject(second_name)),
  )
  @test.assert_eq(try! merged.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("First"),
      target: DestNamed(first_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestNamed(second_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  @test.assert_eq(
    try! merged.page_number_of_target(
      try! merged.read_destination(PdfNameObject(first_name)),
    ),
    1,
  )
  @test.assert_eq(
    try! merged.page_number_of_target(
      try! merged.read_destination(PdfNameObject(second_name)),
    ),
    2,
  )
}

///|
test "pdf_merge_documents rewrites external destination callsites" {
  let string_caller = merge_external_dest_callsite_doc_for_test(
    PdfString(@ascii.encode("shared")),
  )
  let string_first = merge_nametree_dest_doc_for_test("shared")
  let string_second = merge_nametree_dest_doc_for_test("shared")
  let string_merged = try! @pdflite.pdf_merge_documents(
    [string_caller, string_first, string_second],
    [[1], [1], [1]],
  )
  let first_string_name = @ascii.encode("shared-f1")
  @test.assert_eq(
    merge_first_annotation_dest_for_test(string_merged, 0),
    Some(PdfString(first_string_name)),
  )
  @test.assert_eq(
    try! string_merged.page_number_of_target(
      try! string_merged.read_destination(PdfString(first_string_name)),
    ),
    2,
  )

  let catalog_name = merge_name_for_test("/Shared")
  let catalog_caller = merge_external_dest_callsite_doc_for_test(
    PdfNameObject(catalog_name),
  )
  let catalog_first = merge_oldstyle_dest_doc_for_test("/Shared")
  let catalog_second = merge_oldstyle_dest_doc_for_test("/Shared")
  let catalog_merged = try! @pdflite.pdf_merge_documents(
    [catalog_caller, catalog_first, catalog_second],
    [[1], [1], [1]],
  )
  let first_catalog_name = merge_name_for_test("/Shared-f1")
  @test.assert_eq(
    merge_first_annotation_dest_for_test(catalog_merged, 0),
    Some(PdfNameObject(first_catalog_name)),
  )
  @test.assert_eq(
    try! catalog_merged.page_number_of_target(
      try! catalog_merged.read_destination(PdfNameObject(first_catalog_name)),
    ),
    2,
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
test "pdf_merge_documents installs trailer file id" {
  let key_id = merge_name_for_test("/ID")
  let first = merge_one_page_doc_for_test(1, 4)
  let second = merge_one_page_doc_for_test(2, 4)
  let previous = @env.get_env_var("CAMLPDF_REPRODUCIBLE_IDS")
  @env.set_env_var("CAMLPDF_REPRODUCIBLE_IDS", "true")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  merge_restore_env_for_test(previous)
  let expected = merge_bytes_for_test([
    0xe1, 0x43, 0x6d, 0x66, 0xa1, 0x0b, 0xd6, 0x4e, 0xc8, 0xc8, 0xdc, 0x0a, 0xd7,
    0xc3, 0x83, 0x55,
  ])
  @test.assert_eq(
    merged.trailer_dict().lookup_immediate(key_id),
    Some(PdfArray([PdfString(expected), PdfString(expected)])),
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
  let preferences : @syntax.PdfObject = PdfDictionary([
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
test "pdf_merge_documents retains and retargets OpenAction destinations" {
  let key_open_action = merge_name_for_test("/OpenAction")
  let type_fit = merge_name_for_test("/Fit")
  let first = merge_one_page_doc_for_test(1, 4)
  let first_page_refs = try! first.page_reference_numbers()
  let open_action : @syntax.PdfObject = PdfArray([
    PdfIndirect(first_page_refs[0]),
    PdfNameObject(type_fit),
  ])
  let first = merge_add_catalog_entry_for_test(
    first, key_open_action, open_action,
  )
  let second = merge_one_page_doc_for_test(1, 4)
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let merged_page_refs = try! merged.page_reference_numbers()
  let root = merged.lookup_object_or_null(merged.root())
  @test.assert_eq(
    root.lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(merged_page_refs[0]), PdfNameObject(type_fit)])),
  )
  let without_named_destinations = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_named_destinations=false,
  )
  let retained_page_refs = try! without_named_destinations.page_reference_numbers()
  let root = without_named_destinations.lookup_object_or_null(
    without_named_destinations.root(),
  )
  @test.assert_eq(
    root.lookup_immediate(key_open_action),
    Some(
      PdfArray([PdfIndirect(retained_page_refs[0]), PdfNameObject(type_fit)]),
    ),
  )
  let without_open_action = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_catalog_entries=false,
  )
  let root = without_open_action.lookup_object_or_null(
    without_open_action.root(),
  )
  @test.assert_eq(root.lookup_immediate(key_open_action), None)
}

///|
test "pdf_merge_documents keeps first valid OpenAction action" {
  let key_open_action = merge_name_for_test("/OpenAction")
  let key_s = merge_name_for_test("/S")
  let key_d = merge_name_for_test("/D")
  let type_goto = merge_name_for_test("/GoTo")
  let type_fit = merge_name_for_test("/Fit")
  let first = merge_add_catalog_entry_for_test(
    merge_one_page_doc_for_test(1, 4),
    key_open_action,
    PdfString(@ascii.encode("drop")),
  )
  let second = merge_one_page_doc_for_test(1, 4)
  let second_page_refs = try! second.page_reference_numbers()
  let open_action : @syntax.PdfObject = PdfDictionary([
    (key_s, PdfNameObject(type_goto)),
    (
      key_d,
      PdfArray([PdfIndirect(second_page_refs[0]), PdfNameObject(type_fit)]),
    ),
  ])
  let second = merge_add_catalog_entry_for_test(
    second, key_open_action, open_action,
  )
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let merged_page_refs = try! merged.page_reference_numbers()
  let root = merged.lookup_object_or_null(merged.root())
  @test.assert_eq(
    root.lookup_immediate(key_open_action),
    Some(
      PdfDictionary([
        (key_s, PdfNameObject(type_goto)),
        (
          key_d,
          PdfArray([PdfIndirect(merged_page_refs[1]), PdfNameObject(type_fit)]),
        ),
      ]),
    ),
  )
  guard root.lookup_immediate(key_open_action) is Some(action) else {
    fail("expected OpenAction")
  }
  @test.assert_eq(
    try! merged.page_number_of_target(try! merged.read_destination(action)),
    2,
  )
}

///|
test "pdf_merge_documents ignores malformed OpenAction destinations" {
  let key_open_action = merge_name_for_test("/OpenAction")
  let type_fit = merge_name_for_test("/Fit")
  let type_fitr = merge_name_for_test("/FitR")
  let bad_coordinate = merge_name_for_test("/Bad")
  let first = merge_one_page_doc_for_test(1, 4)
  let first_page_refs = try! first.page_reference_numbers()
  let malformed_open_action : @syntax.PdfObject = PdfArray([
    PdfIndirect(first_page_refs[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  let first = merge_add_catalog_entry_for_test(
    first, key_open_action, malformed_open_action,
  )
  let malformed_only = try! @pdflite.pdf_merge_documents([first], [[1]])
  let root = malformed_only.lookup_object_or_null(malformed_only.root())
  @test.assert_eq(root.lookup_immediate(key_open_action), None)
  let second = merge_one_page_doc_for_test(1, 4)
  let second_page_refs = try! second.page_reference_numbers()
  let valid_open_action : @syntax.PdfObject = PdfArray([
    PdfIndirect(second_page_refs[0]),
    PdfNameObject(type_fit),
  ])
  let second = merge_add_catalog_entry_for_test(
    second, key_open_action, valid_open_action,
  )
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let merged_page_refs = try! merged.page_reference_numbers()
  let root = merged.lookup_object_or_null(merged.root())
  @test.assert_eq(
    root.lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(merged_page_refs[1]), PdfNameObject(type_fit)])),
  )
}

///|
test "pdf_merge_documents rewrites named OpenAction destinations" {
  let key_open_action = merge_name_for_test("/OpenAction")
  let key_s = merge_name_for_test("/S")
  let key_d = merge_name_for_test("/D")
  let type_goto = merge_name_for_test("/GoTo")
  let first_name = @ascii.encode("shared-f0")
  let first_action : @syntax.PdfObject = PdfDictionary([
    (key_s, PdfNameObject(type_goto)),
    (key_d, PdfString(@ascii.encode("shared"))),
  ])
  let first = merge_add_catalog_entry_for_test(
    merge_nametree_dest_doc_for_test("shared"),
    key_open_action,
    first_action,
  )
  let second = merge_nametree_dest_doc_for_test("shared")
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let root = merged.lookup_object_or_null(merged.root())
  @test.assert_eq(
    root.lookup_immediate(key_open_action),
    Some(
      PdfDictionary([
        (key_s, PdfNameObject(type_goto)),
        (key_d, PdfString(first_name)),
      ]),
    ),
  )
  guard root.lookup_immediate(key_open_action) is Some(action) else {
    fail("expected OpenAction")
  }
  @test.assert_eq(
    try! merged.page_number_of_target(try! merged.read_destination(action)),
    1,
  )
  let without_destinations = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_named_destinations=false,
  )
  let root = without_destinations.lookup_object_or_null(
    without_destinations.root(),
  )
  @test.assert_eq(root.lookup_immediate(key_open_action), None)
}

///|
test "pdf_merge_documents rejects empty and mismatched inputs" {
  let doc = merge_one_page_doc_for_test(1, 4)
  let empty : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_merge_documents(
    [],
    [],
  )
  guard empty is Err(@core.PdfError::PageTreeExpected) else {
    fail("expected @core.PdfError::PageTreeExpected for empty merge")
  }
  let mismatched : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_merge_documents(
    [doc],
    [],
  )
  guard mismatched is Err(@core.PdfError::PageTreeExpected) else {
    fail("expected @core.PdfError::PageTreeExpected for mismatched merge")
  }
}

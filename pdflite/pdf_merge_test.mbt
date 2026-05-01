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
      colour: @pdflite.pdf_bookmark_black,
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
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn merge_destination_name_entries_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[(@pdflite.PdfBytes, @pdflite.PdfObject)] {
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
) -> @pdflite.PdfObject? {
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
  name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
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
fn merge_page_reference_catalog_doc_for_test(
  key : @pdflite.PdfName,
) -> @pdflite.PdfDocument {
  let doc = merge_one_page_doc_for_test(1, 4)
  let page_refs = try! doc.page_reference_numbers()
  merge_add_catalog_entry_for_test(doc, key, PdfIndirect(page_refs[0]))
}

///|
fn merge_structure_tree_doc_for_test() -> @pdflite.PdfDocument {
  let key_struct_tree_root = merge_name_for_test("/StructTreeRoot")
  let key_k = merge_name_for_test("/K")
  let key_pg = merge_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_refs = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    PdfDictionary([(key_k, PdfArray([PdfIndirect(31), PdfIndirect(32)]))]),
  )
  doc.add_object_given_number(
    31,
    PdfDictionary([(key_pg, PdfIndirect(page_refs[0])), (key_k, PdfInteger(0))]),
  )
  doc.add_object_given_number(
    32,
    PdfDictionary([(key_pg, PdfIndirect(page_refs[1])), (key_k, PdfInteger(0))]),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_struct_tree_root, PdfIndirect(30)),
  )
  doc
}

///|
fn merge_parent_tree_doc_for_test() -> @pdflite.PdfDocument {
  let key_parent_tree = merge_name_for_test("/ParentTree")
  let key_struct_parents = merge_name_for_test("/StructParents")
  let key_struct_tree_root = merge_name_for_test("/StructTreeRoot")
  let key_k = merge_name_for_test("/K")
  let key_pg = merge_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_refs = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    page_refs[0],
    try! doc
    .lookup_object_or_null(page_refs[0])
    .add_dict_entry(key_struct_parents, PdfInteger(0)),
  )
  doc.add_object_given_number(
    30,
    PdfDictionary([
      (key_k, PdfIndirect(31)),
      (key_parent_tree, doc.build_number_tree([(0, PdfIndirect(31))])),
    ]),
  )
  doc.add_object_given_number(
    31,
    PdfDictionary([(key_pg, PdfIndirect(page_refs[0])), (key_k, PdfInteger(0))]),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_struct_tree_root, PdfIndirect(30)),
  )
  doc
}

///|
fn merge_add_object_entry_for_test(
  doc : @pdflite.PdfDocument,
  number : Int,
  key : @pdflite.PdfName,
  value : @pdflite.PdfObject,
) -> @pdflite.PdfDocument {
  doc.add_object_given_number(
    number,
    try! doc.lookup_object_or_null(number).add_dict_entry(key, value),
  )
  doc
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
  extra_entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfDocument {
  let key_acroform = merge_name_for_test("/AcroForm")
  let key_fields = merge_name_for_test("/Fields")
  let key_t = merge_name_for_test("/T")
  let doc = merge_one_page_doc_for_test(1, 6)
  doc.add_object_given_number(
    field_number,
    PdfDictionary([(key_t, PdfString(@ascii.encode(label)))]),
  )
  let form_entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (key_fields, PdfArray([PdfIndirect(field_number)])),
  ]
  for entry in extra_entries {
    form_entries.push(entry)
  }
  let form : @pdflite.PdfObject = PdfDictionary(form_entries)
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
  let appearances : Array[@pdflite.PdfObject] = []
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
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestString(second_name),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
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
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestNamed(second_name),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
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
test "pdf_merge_documents retains and retargets OpenAction destinations" {
  let key_open_action = merge_name_for_test("/OpenAction")
  let type_fit = merge_name_for_test("/Fit")
  let first = merge_one_page_doc_for_test(1, 4)
  let first_page_refs = try! first.page_reference_numbers()
  let open_action : @pdflite.PdfObject = PdfArray([
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
  let open_action : @pdflite.PdfObject = PdfDictionary([
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
test "pdf_merge_documents rewrites named OpenAction destinations" {
  let key_open_action = merge_name_for_test("/OpenAction")
  let key_s = merge_name_for_test("/S")
  let key_d = merge_name_for_test("/D")
  let type_goto = merge_name_for_test("/GoTo")
  let first_name = @ascii.encode("shared-f0")
  let first_action : @pdflite.PdfObject = PdfDictionary([
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
test "pdf_merge_documents rewrites retained page references to merged pages" {
  let key_first_reference = merge_name_for_test("/PieceInfo")
  let key_second_reference = merge_name_for_test("/Metadata")
  let first = merge_page_reference_catalog_doc_for_test(key_first_reference)
  let second = merge_page_reference_catalog_doc_for_test(key_second_reference)
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let page_refs = try! merged.page_reference_numbers()
  let root = merged.lookup_object_or_null(merged.root())
  @test.assert_eq(
    root.lookup_immediate(key_first_reference),
    Some(PdfIndirect(page_refs[0])),
  )
  @test.assert_eq(
    root.lookup_immediate(key_second_reference),
    Some(PdfIndirect(page_refs[1])),
  )
}

///|
test "pdf_merge_documents retains a single trimmed structure tree" {
  let key_struct_tree_root = merge_name_for_test("/StructTreeRoot")
  let key_k = merge_name_for_test("/K")
  let key_pg = merge_name_for_test("/Pg")
  let document = merge_structure_tree_doc_for_test()
  let merged = try! @pdflite.pdf_merge_documents([document], [[1]])
  let page_refs = try! merged.page_reference_numbers()
  let root = merged.lookup_object_or_null(merged.root())
  @test.assert_eq(
    root.lookup_immediate(key_struct_tree_root),
    Some(PdfIndirect(30)),
  )
  @test.assert_eq(
    merged.lookup_object_or_null(30).lookup_immediate(key_k),
    Some(PdfIndirect(31)),
  )
  @test.assert_eq(
    merged.lookup_object_or_null(31).lookup_immediate(key_pg),
    Some(PdfIndirect(page_refs[0])),
  )
  @test.assert_eq(merged.lookup_object_or_null(32), PdfNull)
  let without_structure = try! @pdflite.pdf_merge_documents(
    [document],
    [[1]],
    retain_structure_tree=false,
  )
  let root = without_structure.lookup_object_or_null(without_structure.root())
  @test.assert_eq(root.lookup_immediate(key_struct_tree_root), None)
}

///|
test "pdf_merge_documents merges multiple structure tree roots" {
  let key_struct_tree_root = merge_name_for_test("/StructTreeRoot")
  let key_k = merge_name_for_test("/K")
  let key_p = merge_name_for_test("/P")
  let key_pg = merge_name_for_test("/Pg")
  let first = merge_structure_tree_doc_for_test()
  let second = merge_structure_tree_doc_for_test()
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let page_refs = try! merged.page_reference_numbers()
  let root = merged.lookup_object_or_null(merged.root())
  guard root.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(struct_root_number)) else {
    fail("expected merged StructTreeRoot")
  }
  let struct_root = merged.lookup_object_or_null(struct_root_number)
  guard struct_root.lookup_immediate(key_k) is Some(PdfArray(kids)) else {
    fail("expected merged structure kids")
  }
  @test.assert_eq(kids.length(), 2)
  guard kids[0] is PdfIndirect(first_child) else {
    fail("expected first structure child")
  }
  guard kids[1] is PdfIndirect(second_child) else {
    fail("expected second structure child")
  }
  @test.assert_eq(
    merged.lookup_object_or_null(first_child).lookup_immediate(key_p),
    Some(PdfIndirect(struct_root_number)),
  )
  @test.assert_eq(
    merged.lookup_object_or_null(second_child).lookup_immediate(key_p),
    Some(PdfIndirect(struct_root_number)),
  )
  @test.assert_eq(
    merged.lookup_object_or_null(first_child).lookup_immediate(key_pg),
    Some(PdfIndirect(page_refs[0])),
  )
  @test.assert_eq(
    merged.lookup_object_or_null(second_child).lookup_immediate(key_pg),
    Some(PdfIndirect(page_refs[1])),
  )
}

///|
test "pdf_merge_documents renumbers merged structure parent trees" {
  let key_parent_tree = merge_name_for_test("/ParentTree")
  let key_struct_parents = merge_name_for_test("/StructParents")
  let key_struct_tree_root = merge_name_for_test("/StructTreeRoot")
  let first = merge_parent_tree_doc_for_test()
  let second = merge_parent_tree_doc_for_test()
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let root = merged.lookup_object_or_null(merged.root())
  guard root.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(struct_root_number)) else {
    fail("expected merged StructTreeRoot")
  }
  guard merged.lookup_direct(
      key_parent_tree,
      merged.lookup_object_or_null(struct_root_number),
    )
    is Some(parent_tree) else {
    fail("expected merged ParentTree")
  }
  let parent_entries = merged.read_number_tree(parent_tree)
  @test.assert_eq(parent_entries.length(), 2)
  @test.assert_eq([ for entry in parent_entries => entry.0 ], [0, 1])
  let page_refs = try! merged.page_reference_numbers()
  @test.assert_eq(
    merged
    .lookup_object_or_null(page_refs[0])
    .lookup_immediate(key_struct_parents),
    Some(PdfInteger(0)),
  )
  @test.assert_eq(
    merged
    .lookup_object_or_null(page_refs[1])
    .lookup_immediate(key_struct_parents),
    Some(PdfInteger(1)),
  )
}

///|
test "pdf_merge_documents merges structure root metadata" {
  let key_af = merge_name_for_test("/AF")
  let key_class_map = merge_name_for_test("/ClassMap")
  let key_id_tree = merge_name_for_test("/IDTree")
  let key_namespaces = merge_name_for_test("/Namespaces")
  let key_role_map = merge_name_for_test("/RoleMap")
  let key_struct_tree_root = merge_name_for_test("/StructTreeRoot")
  let key_h1 = merge_name_for_test("/H1")
  let key_figure = merge_name_for_test("/Figure")
  let key_important = merge_name_for_test("/Important")
  let first = merge_parent_tree_doc_for_test()
  let first = merge_add_object_entry_for_test(
    first,
    30,
    key_role_map,
    PdfDictionary([(key_h1, PdfNameObject(merge_name_for_test("/Sect")))]),
  )
  let first = merge_add_object_entry_for_test(
    first,
    30,
    key_namespaces,
    PdfArray([PdfString(@ascii.encode("ns-a"))]),
  )
  let first = merge_add_object_entry_for_test(
    first,
    30,
    key_id_tree,
    first.build_name_tree([(@ascii.encode("id-a"), PdfIndirect(31))]),
  )
  let second = merge_parent_tree_doc_for_test()
  let second = merge_add_object_entry_for_test(
    second,
    30,
    key_role_map,
    PdfDictionary([(key_figure, PdfNameObject(merge_name_for_test("/Figure")))]),
  )
  let second = merge_add_object_entry_for_test(
    second,
    30,
    key_class_map,
    PdfDictionary([(key_important, PdfString(@ascii.encode("class-b")))]),
  )
  let second = merge_add_object_entry_for_test(
    second,
    30,
    key_namespaces,
    PdfArray([PdfString(@ascii.encode("ns-b"))]),
  )
  let second = merge_add_object_entry_for_test(
    second,
    30,
    key_af,
    PdfArray([PdfString(@ascii.encode("af-b"))]),
  )
  let second = merge_add_object_entry_for_test(
    second,
    30,
    key_id_tree,
    second.build_name_tree([(@ascii.encode("id-b"), PdfIndirect(31))]),
  )
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let root = merged.lookup_object_or_null(merged.root())
  guard root.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(struct_root_number)) else {
    fail("expected merged StructTreeRoot")
  }
  let struct_root = merged.lookup_object_or_null(struct_root_number)
  guard merged.lookup_direct(key_role_map, struct_root) is Some(role_map) else {
    fail("expected merged RoleMap")
  }
  @test.assert_eq(
    role_map.lookup_immediate(key_h1),
    Some(PdfNameObject(merge_name_for_test("/Sect"))),
  )
  @test.assert_eq(
    role_map.lookup_immediate(key_figure),
    Some(PdfNameObject(merge_name_for_test("/Figure"))),
  )
  guard merged.lookup_direct(key_class_map, struct_root) is Some(class_map) else {
    fail("expected merged ClassMap")
  }
  @test.assert_eq(
    class_map.lookup_immediate(key_important),
    Some(PdfString(@ascii.encode("class-b"))),
  )
  @test.assert_eq(
    merged.lookup_direct(key_namespaces, struct_root),
    Some(
      PdfArray([
        PdfString(@ascii.encode("ns-a")),
        PdfString(@ascii.encode("ns-b")),
      ]),
    ),
  )
  @test.assert_eq(
    merged.lookup_direct(key_af, struct_root),
    Some(PdfArray([PdfString(@ascii.encode("af-b"))])),
  )
  guard merged.lookup_direct(key_id_tree, struct_root) is Some(id_tree) else {
    fail("expected merged IDTree")
  }
  @test.assert_eq([ for entry in merged.read_name_tree(id_tree) => entry.0 ], [
    @ascii.encode("id-a"),
    @ascii.encode("id-b"),
  ])
}

///|
test "pdf_merge_documents can add top-level document structure element" {
  let key_k = merge_name_for_test("/K")
  let key_namespaces = merge_name_for_test("/Namespaces")
  let key_ns = merge_name_for_test("/NS")
  let key_p = merge_name_for_test("/P")
  let key_s = merge_name_for_test("/S")
  let key_struct_tree_root = merge_name_for_test("/StructTreeRoot")
  let first = merge_structure_tree_doc_for_test()
  let second = merge_structure_tree_doc_for_test()
  let merged = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    add_toplevel_document=true,
  )
  let root = merged.lookup_object_or_null(merged.root())
  guard root.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(struct_root_number)) else {
    fail("expected merged StructTreeRoot")
  }
  let struct_root = merged.lookup_object_or_null(struct_root_number)
  guard struct_root.lookup_immediate(key_k)
    is Some(PdfIndirect(document_number)) else {
    fail("expected top-level Document")
  }
  let document = merged.lookup_object_or_null(document_number)
  @test.assert_eq(
    document.lookup_immediate(key_s),
    Some(PdfNameObject(merge_name_for_test("/Document"))),
  )
  @test.assert_eq(
    document.lookup_immediate(key_p),
    Some(PdfIndirect(struct_root_number)),
  )
  guard document.lookup_immediate(key_k) is Some(PdfArray(kids)) else {
    fail("expected original kids under Document")
  }
  @test.assert_eq(kids.length(), 2)
  guard kids[0] is PdfIndirect(first_child) else {
    fail("expected first wrapped structure child")
  }
  guard kids[1] is PdfIndirect(second_child) else {
    fail("expected second wrapped structure child")
  }
  @test.assert_eq(
    merged.lookup_object_or_null(first_child).lookup_immediate(key_p),
    Some(PdfIndirect(struct_root_number)),
  )
  @test.assert_eq(
    merged.lookup_object_or_null(second_child).lookup_immediate(key_p),
    Some(PdfIndirect(struct_root_number)),
  )
  guard struct_root.lookup_immediate(key_namespaces)
    is Some(PdfArray(namespaces)) else {
    fail("expected Namespaces")
  }
  @test.assert_eq(namespaces.length() > 0, true)
  guard namespaces[0] is PdfIndirect(namespace_number) else {
    fail("expected PDF/UA namespace")
  }
  @test.assert_eq(
    merged.lookup_object_or_null(namespace_number).lookup_immediate(key_ns),
    Some(PdfString(@ascii.encode("http://iso.org/pdf2/ssn"))),
  )
  @test.assert_eq(
    document.lookup_immediate(key_ns),
    Some(PdfIndirect(namespace_number)),
  )
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

///|
fn structure_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn structure_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn structure_struct_tree_doc_for_test() -> @pdflite.PdfDocument raise {
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let key_k = structure_name_for_test("/K")
  let key_pg = structure_name_for_test("/Pg")
  let key_label = structure_name_for_test("/Label")
  let doc = @pdflite.pdf_document_empty()
  let page_root = doc.add_pagetree([@page.pdf_page_blank(@geometry.paper_a4)])
  ignore(doc.add_root(page_root, [(key_struct_tree_root, PdfIndirect(30))]))
  let page_numbers = doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @syntax.pdf_dictionary([(key_k, PdfIndirect(31))]),
  )
  doc.add_object_given_number(
    31,
    @syntax.pdf_dictionary([
      (key_pg, PdfIndirect(page_numbers[0])),
      (key_k, PdfInteger(0)),
      (key_label, PdfString(@ascii.encode("figure"))),
    ]),
  )
  doc
}

///|
fn structure_parent_tree_doc_for_test(
  entries : ArrayView[(Int, @syntax.PdfObject)],
) -> @pdflite.PdfDocument {
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let key_parent_tree = structure_name_for_test("/ParentTree")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_struct_tree_root, PdfIndirect(10))]),
  )
  doc.add_object_given_number(
    10,
    @syntax.pdf_dictionary([(key_parent_tree, doc.build_number_tree(entries))]),
  )
  doc
}

///|
fn structure_parent_tree_entries_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[(Int, @syntax.PdfObject)] raise {
  structure_parent_tree_entries_from_catalog_for_test(doc, doc.root())
}

///|
fn structure_parent_tree_entries_from_catalog_for_test(
  doc : @pdflite.PdfDocument,
  catalog_number : Int,
) -> Array[(Int, @syntax.PdfObject)] raise {
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let key_parent_tree = structure_name_for_test("/ParentTree")
  let catalog = doc.lookup_object_or_null(catalog_number)
  guard doc.lookup_direct(key_struct_tree_root, catalog) is Some(struct_root) else {
    fail("expected StructTreeRoot")
  }
  guard doc.lookup_direct(key_parent_tree, struct_root) is Some(parent_tree) else {
    fail("expected ParentTree")
  }
  doc.read_number_tree(parent_tree)
}

///|
fn structure_merge_add_root_and_child_for_test(
  doc : @pdflite.PdfDocument,
  root_number : Int,
  child_number : Int,
  parent_key : Int,
  label : String,
) -> Unit {
  let key_parent_tree = structure_name_for_test("/ParentTree")
  let key_k = structure_name_for_test("/K")
  let key_label = structure_name_for_test("/Label")
  doc.add_object_given_number(
    root_number,
    @syntax.pdf_dictionary([
      (key_k, PdfIndirect(child_number)),
      (
        key_parent_tree,
        doc.build_number_tree([(parent_key, PdfIndirect(child_number))]),
      ),
    ]),
  )
  doc.add_object_given_number(
    child_number,
    @syntax.pdf_dictionary([
      (key_k, PdfInteger(0)),
      (key_label, PdfString(@ascii.encode(label))),
    ]),
  )
}

///|
fn structure_merge_source_doc_for_test(
  root_number : Int,
  child_number : Int,
  parent_key : Int,
  label : String,
) -> @pdflite.PdfDocument {
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_struct_tree_root, PdfIndirect(root_number))]),
  )
  structure_merge_add_root_and_child_for_test(
    doc, root_number, child_number, parent_key, label,
  )
  doc
}

///|
fn structure_direct_root_doc_for_test() -> @pdflite.PdfDocument {
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let key_k = structure_name_for_test("/K")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([
      (key_struct_tree_root, @syntax.pdf_dictionary([(key_k, PdfInteger(0))])),
    ]),
  )
  doc
}

///|
fn structure_text_tree_doc_for_test() -> @pdflite.PdfDocument raise {
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let key_k = structure_name_for_test("/K")
  let key_pg = structure_name_for_test("/Pg")
  let key_rolemap = structure_name_for_test("/RoleMap")
  let key_s = structure_name_for_test("/S")
  let name_figure = structure_name_for_test("/Figure")
  let name_section = structure_name_for_test("/Sect")
  let name_document = structure_name_for_test("/Document")
  let doc = @pdflite.pdf_document_empty()
  let page_root = doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(doc.add_root(page_root, [(key_struct_tree_root, PdfIndirect(30))]))
  let page_numbers = doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @syntax.pdf_dictionary([
      (
        key_rolemap,
        @syntax.pdf_dictionary([(name_section, PdfNameObject(name_document))]),
      ),
      (key_k, PdfIndirect(31)),
    ]),
  )
  doc.add_object_given_number(
    31,
    @syntax.pdf_dictionary([
      (key_s, PdfNameObject(name_section)),
      (key_pg, PdfIndirect(page_numbers[0])),
      (key_k, PdfArray([PdfInteger(0), PdfIndirect(32)])),
    ]),
  )
  doc.add_object_given_number(
    32,
    @syntax.pdf_dictionary([
      (key_s, PdfNameObject(name_figure)),
      (key_pg, PdfIndirect(page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc
}

///|
test "PdfDocument extract_struct_tree exports cpdf-style object graph JSON" {
  let doc = try! structure_struct_tree_doc_for_test()
  let page_numbers = try! doc.page_reference_numbers()
  let exported = try! doc.extract_struct_tree()
  let expected = Json::array([
    Json::array([
      structure_json_int_for_test(0),
      Json::object(
        Map([
          ("/CPDFJSONformatversion", structure_json_int_for_test(1)),
          (
            "/CPDFJSONpageobjnumbers",
            Json::array([structure_json_int_for_test(page_numbers[0])]),
          ),
        ]),
      ),
    ]),
    Json::array([
      structure_json_int_for_test(30),
      try! doc.json_of_object(doc.lookup_object_or_null(30), utf8=true),
    ]),
    Json::array([
      structure_json_int_for_test(31),
      try! doc.json_of_object(doc.lookup_object_or_null(31), utf8=true),
    ]),
  ])
  @test.assert_eq(exported, expected)
  @test.assert_eq(try! @pdflite.pdf_ua_extract_struct_tree(doc), exported)
  @test.assert_eq(
    try! doc.struct_tree_json_blob(),
    @utf8.encode(exported.stringify()),
  )

  let without_tree = @pdflite.pdf_blank_document_paper(@geometry.paper_a4, 1)
  guard (try! without_tree.extract_struct_tree()) is Array([_]) else {
    fail("expected only the CPDFJSON header when no structure tree exists")
  }
}

///|
test "PdfDocument struct_tree_text renders cpdf-style tree with role map and page numbers" {
  let doc = try! structure_text_tree_doc_for_test()
  let expected = @utf8.encode(
    "StructTreeRoot\n└── Document (1)\n    └── Figure (2)\n",
  )
  @test.assert_eq(try! doc.struct_tree_text(), expected)
  @test.assert_eq(try! @pdflite.pdf_ua_print_struct_tree(doc), expected)

  let without_tree = @pdflite.pdf_blank_document_paper(@geometry.paper_a4, 1)
  @test.assert_eq(try! without_tree.struct_tree_text(), Bytes::new(0))
}

///|
test "PdfDocument replace_struct_tree imports new negative objects" {
  let key_k = structure_name_for_test("/K")
  let key_label = structure_name_for_test("/Label")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    30,
    @syntax.pdf_dictionary([
      (key_k, PdfInteger(0)),
      (key_label, PdfString(@ascii.encode("old"))),
    ]),
  )
  let replacement = Json::array([
    Json::array([structure_json_int_for_test(0), Json::null()]),
    Json::array([
      structure_json_int_for_test(30),
      try! doc.json_of_object(
        @syntax.pdf_dictionary([(key_k, PdfIndirect(-1))]),
        utf8=true,
      ),
    ]),
    Json::array([
      structure_json_int_for_test(-1),
      try! doc.json_of_object(
        @syntax.pdf_dictionary([
          (key_k, PdfInteger(0)),
          (key_label, PdfString(@ascii.encode("new"))),
        ]),
        utf8=true,
      ),
    ]),
  ])
  let replaced = try! @pdflite.pdf_ua_replace_struct_tree(doc, replacement)
  @test.assert_eq(
    doc.lookup_object_or_null(30).lookup_immediate(key_label),
    Some(PdfString(@ascii.encode("old"))),
  )
  @test.assert_eq(
    replaced.lookup_object_or_null(30).lookup_immediate(key_k),
    Some(PdfIndirect(31)),
  )
  @test.assert_eq(
    replaced.lookup_object_or_null(31).lookup_immediate(key_label),
    Some(PdfString(@ascii.encode("new"))),
  )
  let bad : Result[@pdflite.PdfDocument, Error] = try? doc.replace_struct_tree(
    Json::null(),
  )
  guard bad is Err(@core.PdfError::SoftError(_)) else {
    fail("expected malformed structure-tree JSON to raise SoftError")
  }
}

///|
test "pdf_renumber_parent_trees uses trailer root parent trees" {
  let key_root = structure_name_for_test("/Root")
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let key_parent_tree = structure_name_for_test("/ParentTree")
  let key_struct_parent = structure_name_for_test("/StructParent")
  let first = @pdflite.pdf_document_empty()
  first.set_root(1)
  first.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_struct_tree_root, PdfIndirect(11))]),
  )
  first.add_object_given_number(
    11,
    @syntax.pdf_dictionary([
      (
        key_parent_tree,
        first.build_number_tree([(5, PdfString(@ascii.encode("root")))]),
      ),
    ]),
  )
  first.add_object_given_number(
    10,
    @syntax.pdf_dictionary([(key_struct_tree_root, PdfIndirect(12))]),
  )
  first.add_object_given_number(
    12,
    @syntax.pdf_dictionary([
      (
        key_parent_tree,
        first.build_number_tree([(7, PdfString(@ascii.encode("trailer")))]),
      ),
    ]),
  )
  first.add_object_given_number(
    20,
    @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(7))]),
  )
  first.set_trailer_dict(@syntax.pdf_dictionary([(key_root, PdfIndirect(10))]))
  let second = structure_parent_tree_doc_for_test([
    (2, PdfString(@ascii.encode("second"))),
  ])
  second.add_object_given_number(
    20,
    @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(2))]),
  )

  try! @pdflite.pdf_renumber_parent_trees([first, second])

  let first_trailer_entries = try! structure_parent_tree_entries_from_catalog_for_test(
    first, 10,
  )
  @test.assert_eq([ for entry in first_trailer_entries => entry.0 ], [0])
  let first_root_entries = try! structure_parent_tree_entries_from_catalog_for_test(
    first, 1,
  )
  @test.assert_eq([ for entry in first_root_entries => entry.0 ], [5])
  @test.assert_eq(
    first.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(0)),
  )
  let second_entries = try! structure_parent_tree_entries_for_test(second)
  @test.assert_eq([ for entry in second_entries => entry.0 ], [1])
  @test.assert_eq(
    second.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(1)),
  )
}

///|
test "pdf_renumber_parent_trees ignores unresolved trailer root parent tree" {
  let key_root = structure_name_for_test("/Root")
  let key_struct_parent = structure_name_for_test("/StructParent")
  let first = structure_parent_tree_doc_for_test([
    (5, PdfString(@ascii.encode("root"))),
  ])
  first.add_object_given_number(
    20,
    @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(5))]),
  )
  first.set_trailer_dict(@syntax.pdf_dictionary([(key_root, PdfIndirect(99))]))
  let second = structure_parent_tree_doc_for_test([
    (2, PdfString(@ascii.encode("second"))),
  ])
  second.add_object_given_number(
    20,
    @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(2))]),
  )

  try! @pdflite.pdf_renumber_parent_trees([first, second])

  let first_entries = try! structure_parent_tree_entries_for_test(first)
  @test.assert_eq([ for entry in first_entries => entry.0 ], [5])
  @test.assert_eq(
    first.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(5)),
  )
  let second_entries = try! structure_parent_tree_entries_for_test(second)
  @test.assert_eq([ for entry in second_entries => entry.0 ], [0])
  @test.assert_eq(
    second.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(0)),
  )
}

///|
test "pdf_renumber_parent_trees skips catalogs without structure trees" {
  let key_root = structure_name_for_test("/Root")
  let key_type = structure_name_for_test("/Type")
  let key_struct_parent = structure_name_for_test("/StructParent")
  let first = @pdflite.pdf_document_empty()
  first.set_root(1)
  first.add_object_given_number(
    1,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(structure_name_for_test("/Catalog"))),
    ]),
  )
  first.add_object_given_number(
    20,
    @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(5))]),
  )
  first.set_trailer_dict(@syntax.pdf_dictionary([(key_root, PdfIndirect(1))]))
  let second = structure_parent_tree_doc_for_test([
    (2, PdfString(@ascii.encode("second"))),
  ])
  second.add_object_given_number(
    20,
    @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(2))]),
  )

  try! @pdflite.pdf_renumber_parent_trees([first, second])

  @test.assert_eq(
    first.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(5)),
  )
  let second_entries = try! structure_parent_tree_entries_for_test(second)
  @test.assert_eq([ for entry in second_entries => entry.0 ], [0])
  @test.assert_eq(
    second.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(0)),
  )
}

///|
test "pdf_renumber_parent_trees rewrites parent tree keys and object metadata" {
  let key_struct_parent = structure_name_for_test("/StructParent")
  let key_struct_parents = structure_name_for_test("/StructParents")
  let first = structure_parent_tree_doc_for_test([
    (5, @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(5))])),
  ])
  first.add_object_given_number(
    20,
    @syntax.pdf_dictionary([
      (key_struct_parent, PdfInteger(5)),
      (
        structure_name_for_test("/Nested"),
        PdfArray([@syntax.pdf_dictionary([(key_struct_parents, PdfInteger(5))])]),
      ),
    ]),
  )
  first.add_object_given_number(
    21,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([(key_struct_parents, PdfInteger(5))]),
      StreamGot(@ascii.encode("x")),
    ),
  )
  let second = structure_parent_tree_doc_for_test([
    (2, PdfString(@ascii.encode("two"))),
    (9, PdfString(@ascii.encode("nine"))),
  ])
  second.add_object_given_number(
    20,
    @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(2))]),
  )
  second.add_object_given_number(
    21,
    @syntax.pdf_dictionary([(key_struct_parents, PdfInteger(9))]),
  )

  try! @pdflite.pdf_renumber_parent_trees([first, second])

  let first_entries = try! structure_parent_tree_entries_for_test(first)
  @test.assert_eq([ for entry in first_entries => entry.0 ], [0])
  @test.assert_eq(
    first_entries[0].1.lookup_immediate(key_struct_parent),
    Some(PdfInteger(0)),
  )
  @test.assert_eq(
    first.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(0)),
  )
  guard first
    .lookup_object_or_null(20)
    .lookup_immediate(structure_name_for_test("/Nested"))
    is Some(PdfArray([nested])) else {
    fail("expected nested struct parent metadata")
  }
  @test.assert_eq(
    nested.lookup_immediate(key_struct_parents),
    Some(PdfInteger(0)),
  )
  guard first.lookup_object_or_null(21) is PdfStreamObject(stream) else {
    fail("expected stream")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(key_struct_parents),
    Some(PdfInteger(0)),
  )

  let second_entries = try! structure_parent_tree_entries_for_test(second)
  @test.assert_eq([ for entry in second_entries => entry.0 ], [1, 2])
  @test.assert_eq(
    second.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    second.lookup_object_or_null(21).lookup_immediate(key_struct_parents),
    Some(PdfInteger(2)),
  )
}

///|
test "pdf_renumber_parent_trees leaves a single document unchanged" {
  let key_struct_parent = structure_name_for_test("/StructParent")
  let doc = structure_parent_tree_doc_for_test([
    (5, PdfString(@ascii.encode("five"))),
  ])
  doc.add_object_given_number(
    20,
    @syntax.pdf_dictionary([(key_struct_parent, PdfInteger(5))]),
  )
  try! @pdflite.pdf_renumber_parent_trees([doc])
  let entries = try! structure_parent_tree_entries_for_test(doc)
  @test.assert_eq([ for entry in entries => entry.0 ], [5])
  @test.assert_eq(
    doc.lookup_object_or_null(20).lookup_immediate(key_struct_parent),
    Some(PdfInteger(5)),
  )
}

///|
test "pdf_merge_structure_trees handles no roots and single-root cases" {
  let empty_target = @pdflite.pdf_document_empty()
  @test.assert_eq(@pdflite.pdf_merge_structure_trees(empty_target, []), None)

  let target = @pdflite.pdf_document_empty()
  structure_merge_add_root_and_child_for_test(target, 30, 31, 5, "single")
  let single = structure_merge_source_doc_for_test(30, 31, 5, "single")
  @test.assert_eq(
    @pdflite.pdf_merge_structure_trees(target, [single]),
    Some(30),
  )
  @test.assert_eq(
    target
    .lookup_object_or_null(31)
    .lookup_immediate(structure_name_for_test("/P")),
    None,
  )

  let direct = structure_direct_root_doc_for_test()
  @test.assert_eq(
    @pdflite.pdf_merge_structure_trees(empty_target, [direct]),
    Some(0),
  )
}

///|
test "pdf_merge_structure_trees merges structure kids and parent tree entries" {
  let key_k = structure_name_for_test("/K")
  let key_p = structure_name_for_test("/P")
  let key_parent_tree = structure_name_for_test("/ParentTree")
  let first = structure_merge_source_doc_for_test(30, 31, 5, "first")
  let second = structure_merge_source_doc_for_test(40, 41, 9, "second")
  let target = @pdflite.pdf_document_empty()
  structure_merge_add_root_and_child_for_test(target, 30, 31, 5, "first")
  structure_merge_add_root_and_child_for_test(target, 40, 41, 9, "second")

  guard @pdflite.pdf_merge_structure_trees(target, [first, second])
    is Some(root_number) else {
    fail("expected merged structure tree root")
  }

  let root = target.lookup_object_or_null(root_number)
  @test.assert_eq(
    root.lookup_immediate(key_k),
    Some(PdfArray([PdfIndirect(31), PdfIndirect(41)])),
  )
  @test.assert_eq(
    target.lookup_object_or_null(31).lookup_immediate(key_p),
    Some(PdfIndirect(root_number)),
  )
  @test.assert_eq(
    target.lookup_object_or_null(41).lookup_immediate(key_p),
    Some(PdfIndirect(root_number)),
  )
  guard target.lookup_direct(key_parent_tree, PdfIndirect(root_number))
    is Some(parent_tree) else {
    fail("expected merged parent tree")
  }
  let parent_entries = target.read_number_tree(parent_tree)
  @test.assert_eq([ for entry in parent_entries => entry.0 ], [5, 9])
  @test.assert_eq([ for entry in parent_entries => entry.1 ], [
    PdfIndirect(31),
    PdfIndirect(41),
  ])
}

///|
test "pdf_merge_structure_trees can add a top-level Document node" {
  let key_k = structure_name_for_test("/K")
  let key_ns = structure_name_for_test("/NS")
  let key_namespaces = structure_name_for_test("/Namespaces")
  let key_p = structure_name_for_test("/P")
  let key_s = structure_name_for_test("/S")
  let first = structure_merge_source_doc_for_test(30, 31, 5, "first")
  let second = structure_merge_source_doc_for_test(40, 41, 9, "second")
  let target = @pdflite.pdf_document_empty()
  structure_merge_add_root_and_child_for_test(target, 30, 31, 5, "first")
  structure_merge_add_root_and_child_for_test(target, 40, 41, 9, "second")

  guard @pdflite.pdf_merge_structure_trees(
      target,
      [first, second],
      add_toplevel_document=true,
    )
    is Some(root_number) else {
    fail("expected merged structure tree root")
  }

  let root = target.lookup_object_or_null(root_number)
  guard root.lookup_immediate(key_k) is Some(PdfIndirect(document_number)) else {
    fail("expected top-level document node")
  }
  let top_level = target.lookup_object_or_null(document_number)
  @test.assert_eq(
    top_level.lookup_immediate(key_s),
    Some(PdfNameObject(structure_name_for_test("/Document"))),
  )
  @test.assert_eq(
    top_level.lookup_immediate(key_p),
    Some(PdfIndirect(root_number)),
  )
  @test.assert_eq(
    top_level.lookup_immediate(key_k),
    Some(PdfArray([PdfIndirect(31), PdfIndirect(41)])),
  )
  guard root.lookup_immediate(key_namespaces) is Some(PdfArray([ns_entry])) else {
    fail("expected PDF/UA-2 namespace entry")
  }
  guard ns_entry is PdfIndirect(namespace_number) else {
    fail("expected indirect namespace entry")
  }
  @test.assert_eq(
    target.lookup_object_or_null(namespace_number).lookup_immediate(key_ns),
    Some(PdfString(@ascii.encode("http://iso.org/pdf2/ssn"))),
  )
}

///|
test "PdfDocument trim_structure_tree removes parents whose kids target deleted objects" {
  let key_k = structure_name_for_test("/K")
  let key_obj = structure_name_for_test("/Obj")
  let doc = @pdflite.pdf_document_empty()
  let page_root = doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(doc.add_root(page_root, []))
  let page_numbers = doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @syntax.pdf_dictionary([(key_k, PdfArray([PdfIndirect(31)]))]),
  )
  doc.add_object_given_number(
    31,
    @syntax.pdf_dictionary([
      (key_obj, PdfIndirect(page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  @pdflite.pdf_trim_structure_tree(doc, [1])
  @test.assert_eq(doc.lookup_object_or_null(30), PdfNull)
  @test.assert_eq(
    doc.lookup_object_or_null(31).lookup_immediate(key_obj),
    Some(PdfIndirect(page_numbers[1])),
  )
}

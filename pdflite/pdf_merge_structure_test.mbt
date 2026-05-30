///|
fn merge_structure_one_page_doc_for_test(
  major : Int,
  minor : Int,
) -> @pdflite.PdfDocument {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.set_version(major, minor)
  doc
}

///|
fn merge_structure_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn merge_structure_add_catalog_entry_for_test(
  doc : @pdflite.PdfDocument,
  key : @pdflite.PdfName,
  value : @syntax.PdfObject,
) -> @pdflite.PdfDocument {
  let root = doc.lookup_object_or_null(doc.root())
  let new_root = doc.add_object(try! root.add_dict_entry(key, value))
  doc.set_root(new_root)
  doc.set_trailer_dict(
    try! doc
    .trailer_dict()
    .add_dict_entry(
      merge_structure_name_for_test("/Root"),
      PdfIndirect(new_root),
    ),
  )
  doc
}

///|
fn merge_structure_page_reference_catalog_doc_for_test(
  key : @pdflite.PdfName,
) -> @pdflite.PdfDocument {
  let doc = merge_structure_one_page_doc_for_test(1, 4)
  let page_refs = try! doc.page_reference_numbers()
  merge_structure_add_catalog_entry_for_test(
    doc,
    key,
    PdfIndirect(page_refs[0]),
  )
}

///|
fn merge_structure_tree_doc_for_test() -> @pdflite.PdfDocument {
  let key_struct_tree_root = merge_structure_name_for_test("/StructTreeRoot")
  let key_k = merge_structure_name_for_test("/K")
  let key_pg = merge_structure_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
    @page.pdf_page_blank(@geometry.paper_a4),
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
fn merge_structure_parent_tree_doc_for_test() -> @pdflite.PdfDocument {
  let key_parent_tree = merge_structure_name_for_test("/ParentTree")
  let key_struct_parents = merge_structure_name_for_test("/StructParents")
  let key_struct_tree_root = merge_structure_name_for_test("/StructTreeRoot")
  let key_k = merge_structure_name_for_test("/K")
  let key_pg = merge_structure_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
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
fn merge_structure_add_object_entry_for_test(
  doc : @pdflite.PdfDocument,
  number : Int,
  key : @pdflite.PdfName,
  value : @syntax.PdfObject,
) -> @pdflite.PdfDocument {
  doc.add_object_given_number(
    number,
    try! doc.lookup_object_or_null(number).add_dict_entry(key, value),
  )
  doc
}

///|
test "pdf_merge_documents rewrites retained page references to merged pages" {
  let key_first_reference = merge_structure_name_for_test("/PieceInfo")
  let key_second_reference = merge_structure_name_for_test("/Metadata")
  let first = merge_structure_page_reference_catalog_doc_for_test(
    key_first_reference,
  )
  let second = merge_structure_page_reference_catalog_doc_for_test(
    key_second_reference,
  )
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
  let key_struct_tree_root = merge_structure_name_for_test("/StructTreeRoot")
  let key_k = merge_structure_name_for_test("/K")
  let key_pg = merge_structure_name_for_test("/Pg")
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
  let key_struct_tree_root = merge_structure_name_for_test("/StructTreeRoot")
  let key_k = merge_structure_name_for_test("/K")
  let key_p = merge_structure_name_for_test("/P")
  let key_pg = merge_structure_name_for_test("/Pg")
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
  let key_parent_tree = merge_structure_name_for_test("/ParentTree")
  let key_struct_parents = merge_structure_name_for_test("/StructParents")
  let key_struct_tree_root = merge_structure_name_for_test("/StructTreeRoot")
  let first = merge_structure_parent_tree_doc_for_test()
  let second = merge_structure_parent_tree_doc_for_test()
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
  let key_af = merge_structure_name_for_test("/AF")
  let key_class_map = merge_structure_name_for_test("/ClassMap")
  let key_id_tree = merge_structure_name_for_test("/IDTree")
  let key_namespaces = merge_structure_name_for_test("/Namespaces")
  let key_role_map = merge_structure_name_for_test("/RoleMap")
  let key_struct_tree_root = merge_structure_name_for_test("/StructTreeRoot")
  let key_h1 = merge_structure_name_for_test("/H1")
  let key_figure = merge_structure_name_for_test("/Figure")
  let key_important = merge_structure_name_for_test("/Important")
  let first = merge_structure_parent_tree_doc_for_test()
  let first = merge_structure_add_object_entry_for_test(
    first,
    30,
    key_role_map,
    PdfDictionary([
      (key_h1, PdfNameObject(merge_structure_name_for_test("/Sect"))),
    ]),
  )
  let first = merge_structure_add_object_entry_for_test(
    first,
    30,
    key_namespaces,
    PdfArray([PdfString(@ascii.encode("ns-a"))]),
  )
  let first = merge_structure_add_object_entry_for_test(
    first,
    30,
    key_id_tree,
    first.build_name_tree([(@ascii.encode("id-a"), PdfIndirect(31))]),
  )
  let second = merge_structure_parent_tree_doc_for_test()
  let second = merge_structure_add_object_entry_for_test(
    second,
    30,
    key_role_map,
    PdfDictionary([
      (key_figure, PdfNameObject(merge_structure_name_for_test("/Figure"))),
    ]),
  )
  let second = merge_structure_add_object_entry_for_test(
    second,
    30,
    key_class_map,
    PdfDictionary([(key_important, PdfString(@ascii.encode("class-b")))]),
  )
  let second = merge_structure_add_object_entry_for_test(
    second,
    30,
    key_namespaces,
    PdfArray([PdfString(@ascii.encode("ns-b"))]),
  )
  let second = merge_structure_add_object_entry_for_test(
    second,
    30,
    key_af,
    PdfArray([PdfString(@ascii.encode("af-b"))]),
  )
  let second = merge_structure_add_object_entry_for_test(
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
    Some(PdfNameObject(merge_structure_name_for_test("/Sect"))),
  )
  @test.assert_eq(
    role_map.lookup_immediate(key_figure),
    Some(PdfNameObject(merge_structure_name_for_test("/Figure"))),
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
  let key_k = merge_structure_name_for_test("/K")
  let key_namespaces = merge_structure_name_for_test("/Namespaces")
  let key_ns = merge_structure_name_for_test("/NS")
  let key_p = merge_structure_name_for_test("/P")
  let key_s = merge_structure_name_for_test("/S")
  let key_struct_tree_root = merge_structure_name_for_test("/StructTreeRoot")
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
    Some(PdfNameObject(merge_structure_name_for_test("/Document"))),
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

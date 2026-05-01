///|
fn structure_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn structure_parent_tree_doc_for_test(
  entries : ArrayView[(Int, @pdflite.PdfObject)],
) -> @pdflite.PdfDocument {
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let key_parent_tree = structure_name_for_test("/ParentTree")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(key_struct_tree_root, PdfIndirect(10))]),
  )
  doc.add_object_given_number(
    10,
    @pdflite.pdf_dictionary([(key_parent_tree, doc.build_number_tree(entries))]),
  )
  doc
}

///|
fn structure_parent_tree_entries_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[(Int, @pdflite.PdfObject)] raise {
  let key_struct_tree_root = structure_name_for_test("/StructTreeRoot")
  let key_parent_tree = structure_name_for_test("/ParentTree")
  let catalog = doc.lookup_object_or_null(doc.root())
  guard doc.lookup_direct(key_struct_tree_root, catalog) is Some(struct_root) else {
    fail("expected StructTreeRoot")
  }
  guard doc.lookup_direct(key_parent_tree, struct_root) is Some(parent_tree) else {
    fail("expected ParentTree")
  }
  doc.read_number_tree(parent_tree)
}

///|
test "pdf_renumber_parent_trees rewrites parent tree keys and object metadata" {
  let key_struct_parent = structure_name_for_test("/StructParent")
  let key_struct_parents = structure_name_for_test("/StructParents")
  let first = structure_parent_tree_doc_for_test([
    (5, @pdflite.pdf_dictionary([(key_struct_parent, PdfInteger(5))])),
  ])
  first.add_object_given_number(
    20,
    @pdflite.pdf_dictionary([
      (key_struct_parent, PdfInteger(5)),
      (
        structure_name_for_test("/Nested"),
        PdfArray([
          @pdflite.pdf_dictionary([(key_struct_parents, PdfInteger(5))]),
        ]),
      ),
    ]),
  )
  first.add_object_given_number(
    21,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([(key_struct_parents, PdfInteger(5))]),
      StreamGot(@ascii.encode("x")),
    ),
  )
  let second = structure_parent_tree_doc_for_test([
    (2, PdfString(@ascii.encode("two"))),
    (9, PdfString(@ascii.encode("nine"))),
  ])
  second.add_object_given_number(
    20,
    @pdflite.pdf_dictionary([(key_struct_parent, PdfInteger(2))]),
  )
  second.add_object_given_number(
    21,
    @pdflite.pdf_dictionary([(key_struct_parents, PdfInteger(9))]),
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
    @pdflite.pdf_dictionary([(key_struct_parent, PdfInteger(5))]),
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
test "PdfDocument trim_structure_tree removes parents whose kids target deleted objects" {
  let key_k = structure_name_for_test("/K")
  let key_obj = structure_name_for_test("/Obj")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @pdflite.pdf_dictionary([(key_k, PdfArray([PdfIndirect(31)]))]),
  )
  doc.add_object_given_number(
    31,
    @pdflite.pdf_dictionary([
      (key_obj, PdfIndirect(page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  try! doc.trim_structure_tree([1])
  @test.assert_eq(doc.lookup_object_or_null(30), PdfNull)
  @test.assert_eq(
    doc.lookup_object_or_null(31).lookup_immediate(key_obj),
    Some(PdfIndirect(page_numbers[1])),
  )
}

///|
fn structure_wb_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "structure parent tree helpers cover absent roots and direct roots" {
  let key_struct_tree_root = structure_wb_name("/StructTreeRoot")
  let key_parent_tree = structure_wb_name("/ParentTree")
  let no_root = pdf_document_empty()
  @test.assert_eq(no_root.pdf_structure_root_parent_tree_entries(), [])
  try! no_root.pdf_structure_replace_parent_tree(PdfDictionary([]))

  let no_parent_tree = pdf_document_empty()
  no_parent_tree.set_root(1)
  no_parent_tree.add_object_given_number(
    1,
    pdf_dictionary([(key_struct_tree_root, PdfDictionary([]))]),
  )
  @test.assert_eq(no_parent_tree.pdf_structure_root_parent_tree_entries(), [])

  let direct_root = pdf_document_empty()
  direct_root.set_root(1)
  direct_root.add_object_given_number(
    1,
    pdf_dictionary([(key_struct_tree_root, PdfDictionary([]))]),
  )
  try! direct_root.pdf_structure_replace_parent_tree(
    direct_root.build_number_tree([(0, PdfInteger(7))]),
  )
  guard direct_root.lookup_direct(
      key_struct_tree_root,
      direct_root.lookup_object_or_null(1),
    )
    is Some(struct_root) else {
    fail("expected direct StructTreeRoot")
  }
  guard direct_root.lookup_direct(key_parent_tree, struct_root)
    is Some(parent_tree) else {
    fail("expected parent tree")
  }
  @test.assert_eq(direct_root.read_number_tree(parent_tree), [
    (0, PdfInteger(7)),
  ])
}

///|
test "structure parent tree change helpers ignore unmatched keys" {
  let changes = pdf_merge_parent_tree_change_map([(1, 0)])
  @test.assert_eq(pdf_structure_changed_parent_tree_key(changes, 2), None)
  @test.assert_eq(
    pdf_structure_apply_parent_tree_changes([(2, PdfInteger(9))], [(1, 0)]),
    [],
  )
}

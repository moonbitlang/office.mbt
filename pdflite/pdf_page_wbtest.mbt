///|
fn page_wb_text(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn page_wb_document_with_pages(pages : ArrayView[PdfPage]) -> PdfDocument {
  let doc = pdf_document_empty()
  let page_root = try! doc.add_pagetree(pages)
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
fn page_wb_fit_destination(page_number : Int) -> PdfObject {
  PdfArray([PdfIndirect(page_number), PdfNameObject(pdf_dest_type_fit())])
}

///|
fn page_wb_xyz_destination(
  page_number : Int,
  left : Int,
  top : Int,
) -> PdfObject {
  PdfArray([
    PdfIndirect(page_number),
    PdfNameObject(pdf_dest_type_xyz()),
    PdfInteger(left),
    PdfInteger(top),
    PdfNull,
  ])
}

///|
fn page_wb_catalog_destination(
  doc : PdfDocument,
  catalog_number : Int,
  name : PdfName,
) -> PdfObject? {
  match
    doc
    .lookup_object_or_null(catalog_number)
    .lookup_immediate(pdf_page_dests_key()) {
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
fn page_wb_name_tree_entries_from_catalog(
  doc : PdfDocument,
  catalog_number : Int,
) -> Array[(PdfBytes, PdfObject)] {
  match
    doc.lookup_chain(doc.lookup_object_or_null(catalog_number), [
      pdf_page_names_key(),
      pdf_page_dests_key(),
    ]) {
    Some(tree) => doc.read_name_tree(tree)
    None => []
  }
}

///|
test "private page tree readers cover guard branches" {
  let doc = pdf_document_empty()
  @test.assert_eq(pdf_page_int_of_rotation(Rotate180), 180)
  @test.assert_eq(pdf_page_int_of_rotation(Rotate270), 270)
  let bad_entries : Result[Array[(PdfName, PdfObject)], Error] = try? pdf_page_rest_entries(
    PdfInteger(1),
  )
  guard bad_entries is Err(PdfError::DictionaryExpected) else {
    fail("expected rest dictionary")
  }
  let bad_rest : Result[PdfObject, Error] = try? pdf_page_rest_object_from_page(
    PdfInteger(1),
  )
  guard bad_rest is Err(PdfError::DictionaryExpected) else {
    fail("expected page dictionary")
  }
  let bad_root : Result[Array[(PdfName, PdfObject)], Error] = try? pdf_page_root_entries_without_catalog_keys(
    PdfInteger(1),
  )
  guard bad_root is Err(PdfError::DictionaryExpected) else {
    fail("expected root dictionary")
  }

  let direct_child = PdfDictionary([
    (pdf_page_type_key(), PdfNameObject(pdf_page_type_page())),
  ])
  @test.assert_eq(try! doc.pdf_page_direct_child(direct_child), direct_child)
  let missing_child : Result[PdfObject, Error] = try? doc.pdf_page_direct_child(
    PdfIndirect(99),
  )
  guard missing_child is Err(PdfError::PageTreeExpected) else {
    fail("expected missing child")
  }
  let malformed_child : Result[PdfObject, Error] = try? doc.pdf_page_direct_child(
    PdfInteger(1),
  )
  guard malformed_child is Err(PdfError::PageTreeExpected) else {
    fail("expected malformed child")
  }
  let missing_kids : Result[Array[PdfPage], Error] = try? doc.pdf_pages_of_branch(
    PdfDictionary([]),
    None,
    None,
    Rotate0,
    { val: pdf_page_default_mediabox() },
    0,
  )
  guard missing_kids is Err(PdfError::PageTreeExpected) else {
    fail("expected missing kids")
  }
  let too_deep : Result[Array[PdfPage], Error] = try? doc.pdf_pages_of_node(
    PdfDictionary([]),
    None,
    None,
    Rotate0,
    { val: pdf_page_default_mediabox() },
    10001,
  )
  guard too_deep is Err(PdfError::PageTreeExpected) else {
    fail("expected page tree depth guard")
  }
  let inherited_too_deep : Result[PdfObject?, Error] = try? doc.pdf_page_find_inherited_attribute(
    PdfDictionary([]),
    pdf_page_mediabox_key(),
    10001,
  )
  guard inherited_too_deep is Err(PdfError::PageTreeExpected) else {
    fail("expected inherited attribute depth guard")
  }
  @test.assert_eq(try! doc.pdf_pages_of_pagetree_quick_node(PdfNull, 0), 0)
  let quick_too_deep : Result[Int, Error] = try? doc.pdf_pages_of_pagetree_quick_node(
    PdfDictionary([]),
    10001,
  )
  guard quick_too_deep is Err(PdfError::PageTreeExpected) else {
    fail("expected quick page tree depth guard")
  }
  let quick_missing_kid : Result[Int, Error] = try? doc.pdf_pages_of_pagetree_quick_node(
    PdfDictionary([(pdf_page_kids_key(), PdfArray([PdfIndirect(99)]))]),
    0,
  )
  guard quick_missing_kid is Err(PdfError::PageTreeExpected) else {
    fail("expected quick missing kid")
  }
  let quick_missing_kids : Result[Int, Error] = try? doc.pdf_pages_of_pagetree_quick_node(
    PdfDictionary([]),
    0,
  )
  guard quick_missing_kids is Err(PdfError::PageTreeExpected) else {
    fail("expected quick missing kids")
  }

  let last_mediabox : Ref[PdfObject] = { val: pdf_page_default_mediabox() }
  let branch_pages = try! doc.pdf_pages_of_node(
    PdfDictionary([(pdf_page_kids_key(), PdfArray([PdfDictionary([])]))]),
    None,
    None,
    Rotate0,
    last_mediabox,
    0,
  )
  @test.assert_eq(branch_pages.length(), 1)
  let leaf_pages = try! doc.pdf_pages_of_node(
    PdfDictionary([]),
    None,
    None,
    Rotate0,
    last_mediabox,
    0,
  )
  @test.assert_eq(leaf_pages.length(), 1)
}

///|
test "private page root and content helpers cover filtered shapes" {
  let doc = pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
      (pdf_page_pages_key(), PdfIndirect(9)),
      (pdf_page_name("/Lang"), PdfString(page_wb_text("en"))),
      (pdf_page_name("/Metadata"), PdfString(page_wb_text("old-meta"))),
    ]),
  )
  let root_number = try! doc.add_root(2, [
    (pdf_page_type_key(), PdfNameObject(pdf_page_name("/Ignored"))),
    (pdf_page_pages_key(), PdfIndirect(99)),
    (pdf_page_name("/Metadata"), PdfString(page_wb_text("meta"))),
  ])
  let root = doc.lookup_object_or_null(root_number)
  @test.assert_eq(
    root.lookup_immediate(pdf_page_type_key()),
    Some(PdfNameObject(pdf_page_type_catalog())),
  )
  @test.assert_eq(
    root.lookup_immediate(pdf_page_pages_key()),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    root.lookup_immediate(pdf_page_name("/Lang")),
    Some(PdfString(page_wb_text("en"))),
  )
  @test.assert_eq(
    root.lookup_immediate(pdf_page_name("/Metadata")),
    Some(PdfString(page_wb_text("meta"))),
  )
  let active_doc = pdf_document_empty()
  active_doc.set_root(1)
  active_doc.add_object_given_number(
    1,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
      (pdf_page_pages_key(), PdfIndirect(9)),
      (pdf_page_name("/Lang"), PdfString(page_wb_text("stale"))),
    ]),
  )
  active_doc.add_object_given_number(
    10,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
      (pdf_page_pages_key(), PdfIndirect(19)),
      (pdf_page_name("/Lang"), PdfString(page_wb_text("active"))),
    ]),
  )
  active_doc.set_trailer_dict(
    PdfDictionary([(pdf_page_root_key(), PdfIndirect(10))]),
  )
  let active_root_number = try! active_doc.add_root(2, [])
  let active_root = active_doc.lookup_object_or_null(active_root_number)
  @test.assert_eq(
    active_root.lookup_immediate(pdf_page_name("/Lang")),
    Some(PdfString(page_wb_text("active"))),
  )

  let stream = try! pdf_content_stream_of_ops([Op_BT, Op_ET])
  doc.add_object_given_number(10, PdfArray([PdfIndirect(11)]))
  doc.add_object_given_number(11, stream)
  @test.assert_eq(
    doc.pdf_page_content_object(
      PdfDictionary([(pdf_page_contents_key(), PdfIndirect(10))]),
    ),
    Some(PdfArray([PdfIndirect(11)])),
  )
  @test.assert_eq(doc.pdf_page_content_list(Some(PdfIndirect(11))), [
    PdfIndirect(11),
  ])
  @test.assert_eq(doc.pdf_page_content_list(Some(PdfInteger(1))), [])

  let fast_page = try! doc.postpend_operators(
    { ..pdf_page_blank(paper_a4), content: [stream] },
    [Op_g(0.5)],
    fast=true,
  )
  @test.assert_eq(fast_page.content.length(), 2)
  @test.assert_eq(try! doc.parse_content_ops(fast_page.content), [
    Op_BT,
    Op_ET,
    Op_q,
    Op_g(0.5),
    Op_Q,
  ])
}

///|
test "private page object entry rewriting covers parser states" {
  @test.assert_eq(
    pdf_page_renumber_entry(
      pdf_object_entry(ObjectParsedAlreadyDecrypted(PdfIndirect(1))),
      [(1, 7)],
    ),
    pdf_object_entry(ObjectParsedAlreadyDecrypted(PdfIndirect(7))),
  )
  @test.assert_eq(
    pdf_page_renumber_entry(pdf_object_entry(ObjectToParse), [(1, 7)]),
    pdf_object_entry(ObjectToParse),
  )
  @test.assert_eq(
    pdf_page_nullify_entry(
      pdf_object_entry(ObjectParsedAlreadyDecrypted(PdfIndirect(1))),
      [1],
    ),
    pdf_object_entry(ObjectParsedAlreadyDecrypted(PdfNull)),
  )
  @test.assert_eq(
    pdf_page_nullify_entry(pdf_object_entry(ObjectToParse), [1]),
    pdf_object_entry(ObjectToParse),
  )
}

///|
test "private page destination transforms cover unchanged branches" {
  let doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  let page_numbers = try! doc.page_reference_numbers()
  let destination = page_wb_fit_destination(page_numbers[0])
  @test.assert_eq(
    pdf_page_matrix_for_page_number([(2, transform_translate(10.0, 20.0))], 1),
    None,
  )
  @test.assert_eq(
    try! doc.pdf_page_matrix_for_destination(
      DestNull,
      [(1, transform_translate(10.0, 20.0))],
      page_numbers,
    ),
    None,
  )
  @test.assert_eq(
    try! doc.pdf_page_transform_destination_object(
      destination,
      [],
      page_numbers,
    ),
    None,
  )
  let action = PdfDictionary([
    (pdf_dest_s_key(), PdfNameObject(pdf_dest_goto_name())),
    (pdf_dest_d_key(), destination),
  ])
  @test.assert_eq(
    try! doc.pdf_page_transform_action_object(action, [], page_numbers),
    None,
  )
  @test.assert_eq(
    try! doc.pdf_page_transform_action_object(
      PdfDictionary([]),
      [],
      page_numbers,
    ),
    None,
  )

  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: page_wb_text("Top"),
      target: DestFit(TargetPageObject(page_numbers[0])),
      is_open: false,
      colour: pdf_bookmark_black,
      flags: 0,
    },
  ])
  let unchanged = try! bookmarked.pdf_page_transform_bookmarks_for_matrices(
    [],
    page_numbers,
  )
  @test.assert_eq(
    try! unchanged.read_bookmarks(preserve_actions=true),
    try! bookmarked.read_bookmarks(preserve_actions=true),
  )
}

///|
test "private page link and open-action transforms cover fallback branches" {
  let key_annots = pdf_page_annots_key()
  let key_subtype = pdf_page_subtype_key()
  let key_dest = pdf_page_dest_key()
  let key_action = pdf_page_action_key()
  let doc = page_wb_document_with_pages([
    {
      ..pdf_page_blank(paper_a4),
      rest: PdfDictionary([
        (
          key_annots,
          PdfArray([
            PdfIndirect(20),
            PdfIndirect(21),
            PdfIndirect(22),
            PdfIndirect(23),
            PdfDictionary([(key_subtype, PdfNameObject(pdf_page_type_link()))]),
            PdfInteger(1),
          ]),
        ),
      ]),
    },
  ])
  let page_numbers = try! doc.page_reference_numbers()
  let destination = page_wb_fit_destination(page_numbers[0])
  doc.add_object_given_number(
    20,
    PdfDictionary([
      (key_subtype, PdfNameObject(pdf_page_type_link())),
      (key_dest, destination),
    ]),
  )
  doc.add_object_given_number(
    21,
    PdfDictionary([
      (key_subtype, PdfNameObject(pdf_page_type_link())),
      (
        key_action,
        PdfDictionary([
          (pdf_dest_s_key(), PdfNameObject(pdf_dest_goto_name())),
          (pdf_dest_d_key(), destination),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    22,
    PdfDictionary([(key_subtype, PdfNameObject(pdf_page_type_link()))]),
  )
  doc.add_object_given_number(23, PdfDictionary([]))
  try! doc.pdf_page_transform_link_annotations_for_matrices([], page_numbers)
  @test.assert_eq(
    doc.lookup_object_or_null(20).lookup_immediate(key_dest),
    Some(destination),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(21).lookup_immediate(key_action) is Some(_),
    true,
  )

  doc.add_object_given_number(
    doc.root(),
    doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(pdf_page_open_action_key(), destination),
  )
  try! doc.pdf_page_transform_open_action_for_matrices([], page_numbers)
  @test.assert_eq(
    doc
    .lookup_object_or_null(doc.root())
    .lookup_immediate(pdf_page_open_action_key()),
    Some(destination),
  )
  let action = PdfDictionary([
    (pdf_dest_s_key(), PdfNameObject(pdf_dest_goto_name())),
    (pdf_dest_d_key(), page_wb_xyz_destination(page_numbers[0], 1, 2)),
  ])
  doc.add_object_given_number(
    doc.root(),
    doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(pdf_page_open_action_key(), action),
  )
  try! doc.pdf_page_transform_open_action_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    page_numbers,
  )
  match
    doc
    .lookup_object_or_null(doc.root())
    .lookup_immediate(pdf_page_open_action_key()) {
    Some(PdfDictionary(_) as updated_action) =>
      @test.assert_eq(
        updated_action.lookup_immediate(pdf_dest_d_key()),
        Some(
          PdfArray([
            PdfIndirect(page_numbers[0]),
            PdfNameObject(pdf_dest_type_xyz()),
            PdfReal(11.0),
            PdfReal(22.0),
            PdfNull,
          ]),
        ),
      )
    _ => fail("expected open action dictionary")
  }
  doc.add_object_given_number(
    doc.root(),
    doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(pdf_page_open_action_key(), action),
  )
  try! doc.pdf_page_transform_open_action_for_matrices([], page_numbers)
  @test.assert_eq(
    doc
    .lookup_object_or_null(doc.root())
    .lookup_immediate(pdf_page_open_action_key()),
    Some(action),
  )
  doc.add_object_given_number(
    doc.root(),
    doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(pdf_page_open_action_key(), PdfInteger(1)),
  )
  try! doc.pdf_page_transform_open_action_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    page_numbers,
  )
  let unresolved = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  unresolved.set_trailer_dict(
    PdfDictionary([(pdf_page_root_key(), PdfIndirect(99))]),
  )
  try! unresolved.pdf_page_transform_open_action_for_matrices([], [])
}

///|
test "private page open-action transform uses trailer root catalog" {
  let doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  let page_numbers = try! doc.page_reference_numbers()
  let stale_root = doc.root()
  let active_root = 10
  let stale_destination = page_wb_xyz_destination(page_numbers[0], 5, 6)
  let active_destination = page_wb_xyz_destination(page_numbers[0], 1, 2)
  doc.add_object_given_number(
    stale_root,
    try! doc
    .lookup_object_or_null(stale_root)
    .add_dict_entry(pdf_page_open_action_key(), stale_destination),
  )
  doc.add_object_given_number(
    active_root,
    try! doc
    .lookup_object_or_null(stale_root)
    .add_dict_entry(pdf_page_open_action_key(), active_destination),
  )
  doc.set_trailer_dict(PdfDictionary([(pdf_page_root_key(), PdfIndirect(10))]))

  try! doc.pdf_page_transform_open_action_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    page_numbers,
  )

  @test.assert_eq(
    doc
    .lookup_object_or_null(stale_root)
    .lookup_immediate(pdf_page_open_action_key()),
    Some(stale_destination),
  )
  @test.assert_eq(
    doc
    .lookup_object_or_null(active_root)
    .lookup_immediate(pdf_page_open_action_key()),
    Some(
      PdfArray([
        PdfIndirect(page_numbers[0]),
        PdfNameObject(pdf_dest_type_xyz()),
        PdfReal(11.0),
        PdfReal(22.0),
        PdfNull,
      ]),
    ),
  )
}

///|
test "private page selection annotation and destination helpers cover fallbacks" {
  let empty_numbers : Result[Array[Int], Error] = try? pdf_page_select_numbers(
    [1],
    [],
  )
  guard empty_numbers is Err(PdfError::PageTreeExpected) else {
    fail("expected empty selection rejection")
  }
  let bad_number : Result[Array[Int], Error] = try? pdf_page_select_numbers(
    [1],
    [2],
  )
  guard bad_number is Err(PdfError::PageTreeExpected) else {
    fail("expected invalid selection rejection")
  }
  @test.assert_eq(pdf_page_number_index([1, 2], 9), None)

  let doc = pdf_document_empty()
  doc.add_object_given_number(5, PdfArray([PdfIndirect(7), PdfInteger(1)]))
  @test.assert_eq(
    doc.pdf_page_annotation_numbers(
      PdfDictionary([(pdf_page_annots_key(), PdfIndirect(5))]),
    ),
    [7],
  )
  let annotation = PdfDictionary([(pdf_page_popup_key(), PdfIndirect(99))])
  @test.assert_eq(
    try! pdf_page_fixup_annotation_link(annotation, pdf_page_popup_key(), [1], [
      2,
    ]),
    annotation,
  )
  @test.assert_eq(
    doc.pdf_page_destination_was_nulled(
      PdfArray([PdfInteger(1), PdfNameObject(pdf_dest_type_fit())]),
    ),
    false,
  )
  @test.assert_eq(doc.pdf_page_destination_was_nulled(PdfInteger(1)), false)
  @test.assert_eq(
    doc.pdf_page_live_catalog_destinations(PdfInteger(1)),
    PdfInteger(1),
  )
}

///|
test "private page destination cleanup covers indirect containers" {
  let doc = page_wb_document_with_pages([
    pdf_page_blank(paper_a4),
    pdf_page_blank(paper_a4),
  ])
  let page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    50,
    PdfDictionary([
      (
        pdf_page_name("/Drop"),
        PdfArray([PdfNull, PdfNameObject(pdf_dest_type_fit())]),
      ),
      (pdf_page_name("/Keep"), page_wb_fit_destination(page_numbers[0])),
    ]),
  )
  doc.add_object_given_number(
    doc.root(),
    doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(pdf_page_dests_key(), PdfIndirect(50)),
  )
  try! doc.pdf_page_fixup_catalog_destinations()
  @test.assert_eq(
    doc.lookup_object_or_null(50),
    PdfDictionary([
      (pdf_page_name("/Keep"), page_wb_fit_destination(page_numbers[0])),
    ]),
  )

  let names_doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  let names_page_numbers = try! names_doc.page_reference_numbers()
  let dest_tree = names_doc.build_name_tree([
    (page_wb_text("keep"), page_wb_fit_destination(names_page_numbers[0])),
  ])
  names_doc.add_object_given_number(
    60,
    PdfDictionary([(pdf_page_dests_key(), dest_tree)]),
  )
  names_doc.add_object_given_number(
    names_doc.root(),
    names_doc
    .lookup_object_or_null(names_doc.root())
    .add_dict_entry(pdf_page_names_key(), PdfIndirect(60)),
  )
  try! names_doc.pdf_page_fixup_destination_name_tree()
  guard names_doc
    .lookup_object_or_null(60)
    .lookup_immediate(pdf_page_dests_key())
    is Some(_) else {
    fail("expected rewritten destination tree")
  }

  let sparse_names_doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  sparse_names_doc.add_object_given_number(61, PdfDictionary([]))
  sparse_names_doc.add_object_given_number(
    sparse_names_doc.root(),
    sparse_names_doc
    .lookup_object_or_null(sparse_names_doc.root())
    .add_dict_entry(pdf_page_names_key(), PdfIndirect(61)),
  )
  try! sparse_names_doc.pdf_page_fixup_destination_name_tree()
  @test.assert_eq(sparse_names_doc.lookup_object_or_null(61), PdfDictionary([]))
}

///|
test "private page destination cleanup uses trailer root catalog" {
  let drop_name = pdf_page_name("/Drop")
  let keep_name = pdf_page_name("/Keep")
  let doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  let page_numbers = try! doc.page_reference_numbers()
  let stale_catalog_number = doc.root()
  let stale_tree = doc.build_name_tree([
    (
      page_wb_text("drop"),
      PdfArray([PdfNull, PdfNameObject(pdf_dest_type_fit())]),
    ),
    (page_wb_text("keep"), page_wb_fit_destination(page_numbers[0])),
  ])
  let stale_catalog = try! doc
    .lookup_object_or_null(stale_catalog_number)
    .add_dict_entry(
      pdf_page_dests_key(),
      PdfDictionary([
        (drop_name, PdfArray([PdfNull, PdfNameObject(pdf_dest_type_fit())])),
        (keep_name, page_wb_fit_destination(page_numbers[0])),
      ]),
    )
  let stale_catalog = try! stale_catalog.add_dict_entry(
    pdf_page_names_key(),
    PdfDictionary([(pdf_page_dests_key(), stale_tree)]),
  )
  doc.add_object_given_number(stale_catalog_number, stale_catalog)
  let active_tree = doc.build_name_tree([
    (
      page_wb_text("drop"),
      PdfArray([PdfNull, PdfNameObject(pdf_dest_type_fit())]),
    ),
    (page_wb_text("keep"), page_wb_fit_destination(page_numbers[0])),
  ])
  doc.add_object_given_number(
    90,
    PdfDictionary([
      (
        pdf_page_dests_key(),
        PdfDictionary([
          (drop_name, PdfArray([PdfNull, PdfNameObject(pdf_dest_type_fit())])),
          (keep_name, page_wb_fit_destination(page_numbers[0])),
        ]),
      ),
      (
        pdf_page_names_key(),
        PdfDictionary([(pdf_page_dests_key(), active_tree)]),
      ),
    ]),
  )
  doc.set_trailer_dict(
    try! doc.trailer_dict().add_dict_entry(pdf_page_root_key(), PdfIndirect(90)),
  )

  try! doc.pdf_page_fixup_destination_name_tree()
  try! doc.pdf_page_fixup_catalog_destinations()

  @test.assert_eq(page_wb_catalog_destination(doc, 90, drop_name), None)
  @test.assert_eq(
    page_wb_catalog_destination(doc, 90, keep_name),
    Some(page_wb_fit_destination(page_numbers[0])),
  )
  @test.assert_eq(
    page_wb_catalog_destination(doc, stale_catalog_number, drop_name),
    Some(PdfArray([PdfNull, PdfNameObject(pdf_dest_type_fit())])),
  )
  @test.assert_eq(page_wb_name_tree_entries_from_catalog(doc, 90), [
    (page_wb_text("keep"), page_wb_fit_destination(page_numbers[0])),
  ])
  @test.assert_eq(
    [
      for entry in page_wb_name_tree_entries_from_catalog(
        doc, stale_catalog_number,
      ) => entry.0
    ],
    [page_wb_text("drop"), page_wb_text("keep")],
  )
}

///|
test "private page named destination transforms cover indirect containers" {
  let doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  let page_numbers = try! doc.page_reference_numbers()
  @test.assert_eq(
    try! doc.pdf_page_transform_catalog_destinations_object(
      PdfInteger(1),
      [(1, transform_translate(10.0, 20.0))],
      page_numbers,
    ),
    None,
  )
  @test.assert_eq(
    try! doc.pdf_page_transform_catalog_destinations_object(
      PdfDictionary([
        (pdf_page_name("/Keep"), page_wb_fit_destination(page_numbers[0])),
      ]),
      [],
      page_numbers,
    ),
    None,
  )
  doc.add_object_given_number(
    70,
    PdfDictionary([
      (pdf_page_name("/Keep"), page_wb_xyz_destination(page_numbers[0], 1, 2)),
    ]),
  )
  doc.add_object_given_number(
    doc.root(),
    doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(pdf_page_dests_key(), PdfIndirect(70)),
  )
  try! doc.pdf_page_transform_catalog_destinations_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    page_numbers,
  )
  @test.assert_eq(
    doc.lookup_object_or_null(70),
    PdfDictionary([
      (
        pdf_page_name("/Keep"),
        PdfArray([
          PdfIndirect(page_numbers[0]),
          PdfNameObject(pdf_dest_type_xyz()),
          PdfReal(11.0),
          PdfReal(22.0),
          PdfNull,
        ]),
      ),
    ]),
  )

  let unchanged_indirect_doc = page_wb_document_with_pages([
    pdf_page_blank(paper_a4),
  ])
  let unchanged_indirect_pages = try! unchanged_indirect_doc.page_reference_numbers()
  unchanged_indirect_doc.add_object_given_number(
    71,
    PdfDictionary([
      (
        pdf_page_name("/Keep"),
        page_wb_fit_destination(unchanged_indirect_pages[0]),
      ),
    ]),
  )
  unchanged_indirect_doc.add_object_given_number(
    unchanged_indirect_doc.root(),
    unchanged_indirect_doc
    .lookup_object_or_null(unchanged_indirect_doc.root())
    .add_dict_entry(pdf_page_dests_key(), PdfIndirect(71)),
  )
  try! unchanged_indirect_doc.pdf_page_transform_catalog_destinations_for_matrices(
    [],
    unchanged_indirect_pages,
  )
  @test.assert_eq(
    unchanged_indirect_doc.lookup_object_or_null(71),
    PdfDictionary([
      (
        pdf_page_name("/Keep"),
        page_wb_fit_destination(unchanged_indirect_pages[0]),
      ),
    ]),
  )

  let unchanged_direct_doc = page_wb_document_with_pages([
    pdf_page_blank(paper_a4),
  ])
  let unchanged_direct_pages = try! unchanged_direct_doc.page_reference_numbers()
  unchanged_direct_doc.add_object_given_number(
    unchanged_direct_doc.root(),
    unchanged_direct_doc
    .lookup_object_or_null(unchanged_direct_doc.root())
    .add_dict_entry(
      pdf_page_dests_key(),
      PdfDictionary([
        (
          pdf_page_name("/Keep"),
          page_wb_fit_destination(unchanged_direct_pages[0]),
        ),
      ]),
    ),
  )
  try! unchanged_direct_doc.pdf_page_transform_catalog_destinations_for_matrices(
    [],
    unchanged_direct_pages,
  )
  @test.assert_eq(
    unchanged_direct_doc
    .lookup_object_or_null(unchanged_direct_doc.root())
    .lookup_immediate(pdf_page_dests_key()),
    Some(
      PdfDictionary([
        (
          pdf_page_name("/Keep"),
          page_wb_fit_destination(unchanged_direct_pages[0]),
        ),
      ]),
    ),
  )

  let names_doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  let names_page_numbers = try! names_doc.page_reference_numbers()
  let dest_tree = names_doc.build_name_tree([
    (page_wb_text("keep"), page_wb_xyz_destination(names_page_numbers[0], 3, 4)),
  ])
  @test.assert_eq(
    try! names_doc.pdf_page_transform_name_tree_destination_entries(
      dest_tree,
      [],
      names_page_numbers,
    ),
    None,
  )
  names_doc.add_object_given_number(
    80,
    PdfDictionary([(pdf_page_dests_key(), dest_tree)]),
  )
  names_doc.add_object_given_number(
    names_doc.root(),
    names_doc
    .lookup_object_or_null(names_doc.root())
    .add_dict_entry(pdf_page_names_key(), PdfIndirect(80)),
  )
  try! names_doc.pdf_page_transform_destination_name_tree_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    names_page_numbers,
  )
  match
    names_doc.lookup_object_or_null(80).lookup_immediate(pdf_page_dests_key()) {
    Some(tree) =>
      @test.assert_eq(names_doc.read_name_tree(tree), [
        (
          page_wb_text("keep"),
          PdfArray([
            PdfIndirect(names_page_numbers[0]),
            PdfNameObject(pdf_dest_type_xyz()),
            PdfReal(13.0),
            PdfReal(24.0),
            PdfNull,
          ]),
        ),
      ])
    None => fail("expected transformed destination tree")
  }

  let sparse_names_doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  sparse_names_doc.add_object_given_number(
    sparse_names_doc.root(),
    sparse_names_doc
    .lookup_object_or_null(sparse_names_doc.root())
    .add_dict_entry(pdf_page_names_key(), PdfDictionary([])),
  )
  try! sparse_names_doc.pdf_page_transform_destination_name_tree_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    try! sparse_names_doc.page_reference_numbers(),
  )

  let unchanged_indirect_names_doc = page_wb_document_with_pages([
    pdf_page_blank(paper_a4),
  ])
  let unchanged_indirect_name_pages = try! unchanged_indirect_names_doc.page_reference_numbers()
  let unchanged_indirect_tree = unchanged_indirect_names_doc.build_name_tree([
    (
      page_wb_text("keep"),
      page_wb_fit_destination(unchanged_indirect_name_pages[0]),
    ),
  ])
  unchanged_indirect_names_doc.add_object_given_number(
    81,
    PdfDictionary([(pdf_page_dests_key(), unchanged_indirect_tree)]),
  )
  unchanged_indirect_names_doc.add_object_given_number(
    unchanged_indirect_names_doc.root(),
    unchanged_indirect_names_doc
    .lookup_object_or_null(unchanged_indirect_names_doc.root())
    .add_dict_entry(pdf_page_names_key(), PdfIndirect(81)),
  )
  try! unchanged_indirect_names_doc.pdf_page_transform_destination_name_tree_for_matrices(
    [],
    unchanged_indirect_name_pages,
  )
  guard unchanged_indirect_names_doc
    .lookup_object_or_null(81)
    .lookup_immediate(pdf_page_dests_key())
    is Some(_) else {
    fail("expected unchanged indirect destination tree")
  }

  let sparse_indirect_names_doc = page_wb_document_with_pages([
    pdf_page_blank(paper_a4),
  ])
  sparse_indirect_names_doc.add_object_given_number(82, PdfDictionary([]))
  sparse_indirect_names_doc.add_object_given_number(
    sparse_indirect_names_doc.root(),
    sparse_indirect_names_doc
    .lookup_object_or_null(sparse_indirect_names_doc.root())
    .add_dict_entry(pdf_page_names_key(), PdfIndirect(82)),
  )
  try! sparse_indirect_names_doc.pdf_page_transform_destination_name_tree_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    try! sparse_indirect_names_doc.page_reference_numbers(),
  )
  @test.assert_eq(
    sparse_indirect_names_doc.lookup_object_or_null(82),
    PdfDictionary([]),
  )

  let unchanged_direct_names_doc = page_wb_document_with_pages([
    pdf_page_blank(paper_a4),
  ])
  let unchanged_direct_name_pages = try! unchanged_direct_names_doc.page_reference_numbers()
  let unchanged_direct_tree = unchanged_direct_names_doc.build_name_tree([
    (
      page_wb_text("keep"),
      page_wb_fit_destination(unchanged_direct_name_pages[0]),
    ),
  ])
  unchanged_direct_names_doc.add_object_given_number(
    unchanged_direct_names_doc.root(),
    unchanged_direct_names_doc
    .lookup_object_or_null(unchanged_direct_names_doc.root())
    .add_dict_entry(
      pdf_page_names_key(),
      PdfDictionary([(pdf_page_dests_key(), unchanged_direct_tree)]),
    ),
  )
  try! unchanged_direct_names_doc.pdf_page_transform_destination_name_tree_for_matrices(
    [],
    unchanged_direct_name_pages,
  )
  guard unchanged_direct_names_doc
    .lookup_object_or_null(unchanged_direct_names_doc.root())
    .lookup_immediate(pdf_page_names_key())
    is Some(_) else {
    fail("expected unchanged direct destination tree")
  }
}

///|
test "private page named destination transforms use trailer root catalog" {
  let active_name = pdf_page_name("/Active")
  let stale_name = pdf_page_name("/Stale")
  let doc = page_wb_document_with_pages([pdf_page_blank(paper_a4)])
  let page_numbers = try! doc.page_reference_numbers()
  let stale_catalog_number = doc.root()
  let stale_tree = doc.build_name_tree([
    (page_wb_text("stale"), page_wb_fit_destination(page_numbers[0])),
  ])
  let stale_catalog = try! doc
    .lookup_object_or_null(stale_catalog_number)
    .add_dict_entry(
      pdf_page_dests_key(),
      PdfDictionary([(stale_name, page_wb_fit_destination(page_numbers[0]))]),
    )
  let stale_catalog = try! stale_catalog.add_dict_entry(
    pdf_page_names_key(),
    PdfDictionary([(pdf_page_dests_key(), stale_tree)]),
  )
  doc.add_object_given_number(stale_catalog_number, stale_catalog)
  let active_tree = doc.build_name_tree([
    (page_wb_text("active"), page_wb_xyz_destination(page_numbers[0], 3, 4)),
  ])
  doc.add_object_given_number(
    90,
    PdfDictionary([
      (
        pdf_page_dests_key(),
        PdfDictionary([
          (active_name, page_wb_xyz_destination(page_numbers[0], 1, 2)),
        ]),
      ),
      (
        pdf_page_names_key(),
        PdfDictionary([(pdf_page_dests_key(), active_tree)]),
      ),
    ]),
  )
  doc.set_trailer_dict(
    try! doc.trailer_dict().add_dict_entry(pdf_page_root_key(), PdfIndirect(90)),
  )

  try! doc.pdf_page_transform_catalog_destinations_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    page_numbers,
  )
  try! doc.pdf_page_transform_destination_name_tree_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    page_numbers,
  )

  @test.assert_eq(
    page_wb_catalog_destination(doc, 90, active_name),
    Some(
      PdfArray([
        PdfIndirect(page_numbers[0]),
        PdfNameObject(pdf_dest_type_xyz()),
        PdfReal(11.0),
        PdfReal(22.0),
        PdfNull,
      ]),
    ),
  )
  @test.assert_eq(
    page_wb_catalog_destination(doc, stale_catalog_number, stale_name),
    Some(page_wb_fit_destination(page_numbers[0])),
  )
  @test.assert_eq(page_wb_name_tree_entries_from_catalog(doc, 90), [
    (
      page_wb_text("active"),
      PdfArray([
        PdfIndirect(page_numbers[0]),
        PdfNameObject(pdf_dest_type_xyz()),
        PdfReal(13.0),
        PdfReal(24.0),
        PdfNull,
      ]),
    ),
  ])
  @test.assert_eq(
    page_wb_name_tree_entries_from_catalog(doc, stale_catalog_number),
    [(page_wb_text("stale"), page_wb_fit_destination(page_numbers[0]))],
  )
}

///|
test "private page active catalog covers fallback and absent roots" {
  let name = pdf_page_name("/Fallback")
  let fallback = pdf_document_empty()
  fallback.set_root(1)
  fallback.add_object_given_number(
    1,
    PdfDictionary([
      (
        pdf_page_dests_key(),
        PdfDictionary([(name, page_wb_xyz_destination(7, 1, 2))]),
      ),
    ]),
  )
  try! fallback.pdf_page_transform_catalog_destinations_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    [7],
  )
  @test.assert_eq(
    page_wb_catalog_destination(fallback, 1, name),
    Some(
      PdfArray([
        PdfIndirect(7),
        PdfNameObject(pdf_dest_type_xyz()),
        PdfReal(11.0),
        PdfReal(22.0),
        PdfNull,
      ]),
    ),
  )

  let empty = pdf_document_empty()
  try! empty.pdf_page_transform_catalog_destinations_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    [7],
  )
  try! empty.pdf_page_transform_destination_name_tree_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    [7],
  )
  try! empty.pdf_page_fixup_catalog_destinations()
  try! empty.pdf_page_fixup_destination_name_tree()

  let unresolved = pdf_document_empty()
  unresolved.set_root(1)
  unresolved.add_object_given_number(
    1,
    PdfDictionary([
      (
        pdf_page_dests_key(),
        PdfDictionary([(name, page_wb_xyz_destination(7, 1, 2))]),
      ),
    ]),
  )
  unresolved.set_trailer_dict(
    PdfDictionary([(pdf_page_root_key(), PdfIndirect(99))]),
  )
  try! unresolved.pdf_page_transform_catalog_destinations_for_matrices(
    [(1, transform_translate(10.0, 20.0))],
    [7],
  )
  @test.assert_eq(
    page_wb_catalog_destination(unresolved, 1, name),
    Some(page_wb_xyz_destination(7, 1, 2)),
  )
}

///|
test "private page prefix helpers cover direct and fallback operators" {
  @test.assert_eq(
    pdf_page_name_text_without_slash(pdf_name_of_bytes(page_wb_text("Plain"))),
    "Plain",
  )
  let invalid_name_bytes : Array[Byte] = [255]
  @test.assert_eq(
    pdf_page_name_text_without_slash(
      pdf_name_of_bytes(Bytes::from_array(invalid_name_bytes)),
    ),
    "",
  )
  @test.assert_eq(pdf_page_next_prefix(""), "a")

  let doc = pdf_document_empty()
  let inline_direct = PdfDictionary([
    (pdf_page_name("/CS"), PdfNameObject(pdf_page_name("/RGB"))),
  ])
  @test.assert_eq(
    try! doc.pdf_page_prefix_inline_image_dictionary("p", inline_direct),
    inline_direct,
  )
  @test.assert_eq(
    try! doc.pdf_page_prefix_content_op("p", Op_CS(pdf_page_name("/Custom"))),
    Op_CS(pdf_page_name("/pCustom")),
  )
  @test.assert_eq(
    try! doc.pdf_page_prefix_content_op("p", Op_cs(pdf_page_name("/DeviceRGB"))),
    Op_cs(pdf_page_name("/DeviceRGB")),
  )
  @test.assert_eq(try! doc.pdf_page_prefix_content_op("p", Op_BT), Op_BT)
}

///|
test "private page resource renumber helpers cover optional misses" {
  let color_space = pdf_page_name("/ColorSpace")
  let properties = pdf_page_name("/Properties")
  let changes = [
    (color_space, 1, pdf_page_name("/CS1"), pdf_page_name("/r1")),
    (properties, 1, pdf_page_name("/Prop1"), pdf_page_name("/r2")),
  ]
  @test.assert_eq(
    pdf_page_renumber_lookup_optional(
      changes,
      color_space,
      1,
      pdf_page_name("/Missing"),
    ),
    None,
  )
  let missing : Result[PdfName, Error] = try? pdf_page_renumber_lookup(
    changes,
    pdf_page_name("/Font"),
    1,
    pdf_page_name("/Missing"),
  )
  guard missing is Err(PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected missing resource name")
  }

  let doc = pdf_document_empty()
  let inline_direct = PdfDictionary([
    (pdf_page_name("/CS"), PdfNameObject(pdf_page_name("/RGB"))),
  ])
  @test.assert_eq(
    try! doc.pdf_page_renumber_inline_image_dictionary(
      changes, 1, inline_direct,
    ),
    inline_direct,
  )
  @test.assert_eq(
    try! doc.pdf_page_renumber_content_op(
      changes,
      1,
      Op_CS(pdf_page_name("/CS1")),
    ),
    Op_CS(pdf_page_name("/r1")),
  )
  @test.assert_eq(
    try! doc.pdf_page_renumber_content_op(
      changes,
      1,
      Op_cs(pdf_page_name("/DeviceRGB")),
    ),
    Op_cs(pdf_page_name("/DeviceRGB")),
  )
  @test.assert_eq(
    try! doc.pdf_page_renumber_content_op(
      changes,
      1,
      Op_CS(pdf_page_name("/Missing")),
    ),
    Op_CS(pdf_page_name("/Missing")),
  )
  @test.assert_eq(
    try! doc.pdf_page_renumber_content_op(
      changes,
      1,
      Op_cs(pdf_page_name("/Missing")),
    ),
    Op_cs(pdf_page_name("/Missing")),
  )
  @test.assert_eq(
    try! doc.pdf_page_renumber_content_op(
      changes,
      1,
      Op_BDC(pdf_page_name("/Span"), PdfNameObject(pdf_page_name("/Missing"))),
    ),
    Op_BDC(pdf_page_name("/Span"), PdfNameObject(pdf_page_name("/Missing"))),
  )
  @test.assert_eq(
    try! doc.pdf_page_renumber_content_op(changes, 1, Op_BT),
    Op_BT,
  )
  @test.assert_eq(try! doc.renumber_pages([]), [])
}

///|
test "private page reference collection covers malformed nodes" {
  let doc = pdf_document_empty()
  let too_deep : Result[Array[Int], Error] = try? pdf_page_reference_numbers_inner(
    doc,
    PdfDictionary([]),
    1,
    10001,
  )
  guard too_deep is Err(PdfError::PageTreeExpected) else {
    fail("expected reference depth guard")
  }
  @test.assert_eq(
    try! pdf_page_reference_numbers_inner(
      doc,
      PdfDictionary([(pdf_page_kids_key(), PdfArray([PdfInteger(1)]))]),
      8,
      0,
    ),
    [],
  )
  @test.assert_eq(
    try! pdf_page_reference_numbers_inner(doc, PdfDictionary([]), 8, 0),
    [8],
  )

  let fast_doc = pdf_document_empty()
  fast_doc.set_root(1)
  fast_doc.add_object_given_number(
    1,
    PdfDictionary([(pdf_page_pages_key(), PdfIndirect(2))]),
  )
  fast_doc.add_object_given_number(2, PdfDictionary([]))
  @test.assert_eq(try! fast_doc.endpage_fast(), 0)
}

///|
test "private page tree root helpers use trailer root catalog" {
  let doc = pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
      (pdf_page_pages_key(), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
      (pdf_page_kids_key(), PdfArray([PdfIndirect(3)])),
      (pdf_page_count_key(), PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    3,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_page())),
      (pdf_page_parent_key(), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
      (pdf_page_pages_key(), PdfIndirect(20)),
    ]),
  )
  doc.add_object_given_number(
    20,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
      (pdf_page_kids_key(), PdfArray([PdfIndirect(21)])),
      (pdf_page_count_key(), PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    21,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_page())),
      (pdf_page_parent_key(), PdfIndirect(20)),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(pdf_page_root_key(), PdfIndirect(10))]))

  @test.assert_eq(try! pdf_page_root_pages_number(doc), 20)
  @test.assert_eq(try! doc.page_reference_numbers(), [21])
  @test.assert_eq(try! doc.pages_of_pagetree_quick(), 1)
}

///|
fn page_wb_duplicate_page_tree_doc() -> PdfDocument {
  let doc = pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
      (pdf_page_pages_key(), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
      (pdf_page_kids_key(), PdfArray([PdfIndirect(3), PdfIndirect(3)])),
      (pdf_page_count_key(), PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    3,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_page())),
      (pdf_page_parent_key(), PdfIndirect(2)),
    ]),
  )
  doc
}

///|
test "private page tree duplicate fixup copies repeated page references" {
  let doc = page_wb_duplicate_page_tree_doc()
  @test.assert_eq(try! pdf_page_root_pages_number(doc), 2)
  @test.assert_eq(try! doc.pdf_page_tree_nodes_not_pages(), [2])
  @test.assert_eq(try! doc.pdf_page_reference_numbers_unordered(), [3, 3])
  @test.assert_eq(pdf_page_first_duplicate_number([5, 3, 5, 4]), Some(5))
  @test.assert_eq(pdf_page_first_duplicate_number([5, 3, 4]), None)

  let (rewritten_kids, rewritten) = pdf_page_rewrite_first_kid(
    [PdfIndirect(3), PdfIndirect(3), PdfInteger(0)],
    3,
    4,
  )
  @test.assert_eq(rewritten, true)
  @test.assert_eq(rewritten_kids, [
    PdfIndirect(4),
    PdfIndirect(3),
    PdfInteger(0),
  ])
  let (_, not_rewritten) = pdf_page_rewrite_first_kid([PdfInteger(0)], 3, 4)
  @test.assert_eq(not_rewritten, false)
  @test.assert_eq(try! doc.pdf_page_rewrite_first_indirect(3, 99, 100), false)

  try! doc.pdf_page_fixup_duplicate_pages()
  @test.assert_eq(try! doc.page_reference_numbers(), [4, 3])
  @test.assert_eq(
    doc.lookup_object_or_null(2).lookup_immediate(pdf_page_kids_key()),
    Some(PdfArray([PdfIndirect(4), PdfIndirect(3)])),
  )
  @test.assert_eq(doc.lookup_object_or_null(4), doc.lookup_object_or_null(3))
  try! doc.pdf_page_fixup_duplicate_pages()
  @test.assert_eq(try! doc.page_reference_numbers(), [4, 3])
}

///|
test "private page tree parent fixup rewrites stale parent links" {
  let doc = pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
      (pdf_page_pages_key(), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
      (pdf_page_kids_key(), PdfArray([PdfIndirect(4)])),
      (pdf_page_count_key(), PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    4,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
      (pdf_page_parent_key(), PdfIndirect(99)),
      (pdf_page_kids_key(), PdfArray([PdfIndirect(3), PdfInteger(0)])),
      (pdf_page_count_key(), PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    3,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_page())),
      (pdf_page_parent_key(), PdfIndirect(99)),
    ]),
  )
  @test.assert_eq(try! doc.pdf_page_tree_nodes_not_pages(), [2, 4])
  @test.assert_eq(try! doc.pdf_page_reference_numbers_unordered(), [3])
  try! doc.pdf_page_fixup_parents()
  @test.assert_eq(
    doc.lookup_object_or_null(4).lookup_immediate(pdf_page_parent_key()),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(3).lookup_immediate(pdf_page_parent_key()),
    Some(PdfIndirect(4)),
  )
}

///|
test "private page tree repair helpers report malformed roots and depth" {
  let missing_root = pdf_document_empty()
  missing_root.set_root(99)
  let missing_pages : Result[Int, Error] = try? pdf_page_root_pages_number(
    missing_root,
  )
  guard missing_pages is Err(PdfError::RootExpected) else {
    fail("expected missing root")
  }

  let direct_pages = pdf_document_empty()
  direct_pages.set_root(1)
  direct_pages.add_object_given_number(
    1,
    PdfDictionary([(pdf_page_pages_key(), PdfDictionary([]))]),
  )
  let bad_pages : Result[Int, Error] = try? pdf_page_root_pages_number(
    direct_pages,
  )
  guard bad_pages is Err(PdfError::PageTreeExpected) else {
    fail("expected indirect pages root")
  }

  let doc = page_wb_duplicate_page_tree_doc()
  let node_depth : Result[Array[Int], Error] = try? doc.pdf_page_tree_nodes_not_pages_inner(
    PdfDictionary([]),
    2,
    10001,
  )
  guard node_depth is Err(PdfError::PageTreeExpected) else {
    fail("expected node depth guard")
  }
  @test.assert_eq(
    try! doc.pdf_page_tree_nodes_not_pages_inner(PdfDictionary([]), 2, 0),
    [],
  )
  let unordered_depth : Result[Array[Int], Error] = try? doc.pdf_page_reference_numbers_unordered_inner(
    PdfDictionary([]),
    2,
    10001,
  )
  guard unordered_depth is Err(PdfError::PageTreeExpected) else {
    fail("expected unordered depth guard")
  }
  @test.assert_eq(
    try! doc.pdf_page_reference_numbers_unordered_inner(PdfDictionary([]), 2, 0),
    [2],
  )
  let parent_depth : Result[Unit, Error] = try? doc.pdf_page_fixup_parents_inner(
    0, 2, 10001,
  )
  guard parent_depth is Err(PdfError::PageTreeExpected) else {
    fail("expected parent depth guard")
  }
  let rewrite_missing : Result[Unit, Error] = try? doc.pdf_page_rewrite_page_tree_first(
    [],
    3,
  )
  guard rewrite_missing is Err(PdfError::PageTreeExpected) else {
    fail("expected rewrite failure")
  }
  @test.assert_eq(doc.lookup_object_or_null(4), PdfNull)
}

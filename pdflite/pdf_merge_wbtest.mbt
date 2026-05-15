///|
test "private merge helpers cover guards and membership branches" {
  let empty_version : Result[(Int, Int), Error] = try? pdf_merge_max_version([])
  guard empty_version is Err(PdfError::PageTreeExpected) else {
    fail("expected PdfError::PageTreeExpected")
  }

  let key = pdf_merge_name("/ViewerPreferences")
  let seen_names = pdf_merge_name_set()
  seen_names.add(key)
  @test.assert_eq(seen_names.contains(key), true)
  let seen_bytes = pdf_merge_bytes_set()
  let bytes_key = @ascii.encode("shared")
  @test.assert_eq(seen_bytes.contains(bytes_key), false)
  seen_bytes.add(bytes_key)
  @test.assert_eq(seen_bytes.contains(bytes_key), true)
  @test.assert_eq(pdf_merge_object_member([PdfInteger(1)], PdfInteger(1)), true)
  @test.assert_eq(
    pdf_merge_destination_needs_named_retention(DestFit(TargetPageObject(1))),
    false,
  )
  let parent_changes = pdf_merge_parent_tree_change_map([(1, 2), (1, 3)])
  @test.assert_eq(pdf_merge_changed_parent_tree_key(parent_changes, 1), Some(2))
  @test.assert_eq(pdf_merge_changed_parent_tree_key(parent_changes, 3), None)

  let builder = pdf_merge_dictionary_builder()
  builder.add_entry(key, PdfInteger(1))
  builder.add_entry(key, PdfInteger(2))
  @test.assert_eq(builder.entries, [(key, PdfInteger(2))])

  let doc = pdf_document_empty()
  doc.add_object_given_number(1, PdfInteger(1))
  doc.set_root(1)
  @test.assert_eq(try! pdf_merge_catalog_extra_entries([doc]), [])
  let duplicate_key = pdf_merge_name("/Lang")
  let first = pdf_document_empty()
  first.add_object_given_number(
    1,
    PdfDictionary([(duplicate_key, PdfString(@ascii.encode("first")))]),
  )
  first.set_root(1)
  let second = pdf_document_empty()
  second.add_object_given_number(
    1,
    PdfDictionary([(duplicate_key, PdfString(@ascii.encode("second")))]),
  )
  second.set_root(1)
  @test.assert_eq(try! pdf_merge_catalog_extra_entries([first, second]), [
    (duplicate_key, PdfString(@ascii.encode("first"))),
  ])
  @test.assert_eq(
    pdf_merge_destination_name_changes_are_unique([
      [(bytes_key, bytes_key)],
      [(@ascii.encode("other"), bytes_key)],
    ]),
    false,
  )
  @test.assert_eq(
    pdf_merge_catalog_destination_name_changes_are_unique([
      [(key, key)],
      [(duplicate_key, key)],
    ]),
    false,
  )
}

///|
test "private merge destination-name lookup preserves local and global precedence" {
  let old_name = @ascii.encode("shared")
  let local_name = @ascii.encode("shared-f0")
  let global_name = @ascii.encode("shared-f1")
  @test.assert_eq(
    pdf_merge_destination_name_lookup([(old_name, local_name)], [
      (old_name, global_name),
    ]).changed(old_name),
    local_name,
  )
  @test.assert_eq(
    pdf_merge_destination_name_lookup([], [(old_name, global_name)]).changed(
      old_name,
    ),
    global_name,
  )
  @test.assert_eq(
    pdf_merge_destination_name_lookup(
      [(old_name, local_name), (old_name, global_name)],
      [],
    ).changed(old_name),
    local_name,
  )
  let old_catalog_name = pdf_merge_name("/Shared")
  let local_catalog_name = pdf_merge_name("/Shared-f0")
  let global_catalog_name = pdf_merge_name("/Shared-f1")
  @test.assert_eq(
    pdf_merge_catalog_destination_name_lookup(
      [(old_catalog_name, local_catalog_name)],
      [(old_catalog_name, global_catalog_name)],
    ).changed(old_catalog_name),
    local_catalog_name,
  )
  @test.assert_eq(
    pdf_merge_catalog_destination_name_lookup([], [
      (old_catalog_name, global_catalog_name),
    ]).changed(old_catalog_name),
    global_catalog_name,
  )
  @test.assert_eq(
    pdf_merge_catalog_destination_name_lookup(
      [
        (old_catalog_name, local_catalog_name),
        (old_catalog_name, global_catalog_name),
      ],
      [],
    ).changed(old_catalog_name),
    local_catalog_name,
  )
}

///|
test "private merge destination-name rewrite covers action and stream callsites" {
  let old_name = @ascii.encode("shared")
  let new_name = @ascii.encode("shared-f0")
  let changes : ReadOnlyArray[(PdfBytes, PdfBytes)] = [(old_name, new_name)]
  let name_lookup = pdf_merge_destination_name_lookup(changes, changes)
  let empty_name_lookup = pdf_merge_destination_name_lookup([], [])
  let empty_catalog_lookup = pdf_merge_catalog_destination_name_lookup([], [])
  @test.assert_eq(
    try! pdf_merge_rewrite_destination_callsite_object(
      PdfDictionary([
        (pdf_merge_s_key(), PdfNameObject(pdf_dest_goto_name())),
        (pdf_dest_d_key(), PdfString(old_name)),
      ]),
      name_lookup,
      empty_catalog_lookup,
    ),
    PdfDictionary([
      (pdf_merge_s_key(), PdfNameObject(pdf_dest_goto_name())),
      (pdf_dest_d_key(), PdfString(new_name)),
    ]),
  )
  @test.assert_eq(
    try! pdf_merge_rewrite_destination_callsite_object(
      pdf_stream(
        PdfDictionary([(pdf_merge_dest_key(), PdfString(old_name))]),
        StreamGot(@ascii.encode("data")),
      ),
      name_lookup,
      empty_catalog_lookup,
    ),
    pdf_stream(
      PdfDictionary([(pdf_merge_dest_key(), PdfString(new_name))]),
      StreamGot(@ascii.encode("data")),
    ),
  )
  let old_catalog_name = pdf_merge_name("/Shared")
  let new_catalog_name = pdf_merge_name("/Shared-f0")
  let catalog_changes : ReadOnlyArray[(PdfName, PdfName)] = [
    (old_catalog_name, new_catalog_name),
  ]
  let catalog_lookup = pdf_merge_catalog_destination_name_lookup(
    catalog_changes, catalog_changes,
  )
  @test.assert_eq(
    try! pdf_merge_rewrite_destination_callsite_object(
      PdfDictionary([
        (pdf_merge_s_key(), PdfNameObject(pdf_dest_goto_name())),
        (pdf_dest_d_key(), PdfNameObject(old_catalog_name)),
      ]),
      empty_name_lookup,
      catalog_lookup,
    ),
    PdfDictionary([
      (pdf_merge_s_key(), PdfNameObject(pdf_dest_goto_name())),
      (pdf_dest_d_key(), PdfNameObject(new_catalog_name)),
    ]),
  )
  @test.assert_eq(
    try! pdf_merge_rewrite_destination_callsite_object(
      PdfDictionary([(pdf_merge_dest_key(), PdfNameObject(old_catalog_name))]),
      empty_name_lookup,
      catalog_lookup,
    ),
    PdfDictionary([(pdf_merge_dest_key(), PdfNameObject(new_catalog_name))]),
  )
}

///|
test "private merge structure helpers cover direct variants" {
  let doc = pdf_document_empty()
  @test.assert_eq(
    doc.pdf_merge_structure_tree_root_k_items(
      PdfDictionary([(pdf_merge_k_key(), PdfArray([PdfInteger(1)]))]),
    ),
    [PdfInteger(1)],
  )
  @test.assert_eq(
    doc.pdf_merge_structure_tree_root_k_items(PdfDictionary([])),
    [],
  )

  let struct_parent = pdf_merge_struct_parent_key()
  let struct_parents = pdf_merge_struct_parents_key()
  let original = PdfDictionary([
    (struct_parent, PdfInteger(9)),
    (struct_parents, PdfNameObject(pdf_merge_name("/Bad"))),
  ])
  let no_parent_changes = pdf_merge_parent_tree_change_map([])
  @test.assert_eq(
    pdf_merge_renumber_struct_parent_object(original, no_parent_changes),
    original,
  )
  let parent_changes = pdf_merge_parent_tree_change_map([(1, 7)])

  let stream = pdf_stream(
    PdfDictionary([(struct_parent, PdfInteger(1))]),
    StreamGot(@ascii.encode("x")),
  )
  @test.assert_eq(
    pdf_merge_renumber_struct_parent_object(stream, parent_changes),
    pdf_stream(
      PdfDictionary([(struct_parent, PdfInteger(7))]),
      StreamGot(@ascii.encode("x")),
    ),
  )

  @test.assert_eq(
    pdf_merge_renumber_struct_parent_entry(
      pdf_object_entry(
        ObjectParsedAlreadyDecrypted(
          PdfDictionary([(struct_parent, PdfInteger(1))]),
        ),
      ),
      parent_changes,
    ),
    pdf_object_entry(
      ObjectParsedAlreadyDecrypted(
        PdfDictionary([(struct_parent, PdfInteger(7))]),
      ),
    ),
  )
  @test.assert_eq(
    pdf_merge_renumber_struct_parent_entry(
      pdf_object_entry(ObjectToParse),
      parent_changes,
    ),
    pdf_object_entry(ObjectToParse),
  )

  doc.add_object_given_number(5, PdfInteger(5))
  @test.assert_eq(
    try! doc.pdf_merge_structure_parented_item(PdfIndirect(5), 9),
    PdfIndirect(5),
  )
  @test.assert_eq(
    try! doc.pdf_merge_structure_parented_item(PdfDictionary([]), 9),
    PdfDictionary([(pdf_merge_parent_key(), PdfIndirect(9))]),
  )
  @test.assert_eq(
    try! doc.pdf_merge_structure_parented_item(PdfInteger(1), 9),
    PdfInteger(1),
  )

  let root_with_lexicon = PdfDictionary([
    (
      pdf_merge_pronunciation_lexicon_key(),
      PdfArray([PdfString(@ascii.encode("lex"))]),
    ),
  ])
  let merged = try! doc.pdf_merge_structure_tree_root(
    [root_with_lexicon, root_with_lexicon],
    [],
    false,
  )
  guard merged is Some(PdfIndirect(merged_root_number)) else {
    fail("expected merged structure root")
  }
  @test.assert_eq(
    doc
    .lookup_object_or_null(merged_root_number)
    .lookup_immediate(pdf_merge_pronunciation_lexicon_key()),
    Some(PdfArray([PdfString(@ascii.encode("lex"))])),
  )
}

///|
test "private merge catalog and AcroForm helpers cover malformed roots" {
  let key = pdf_merge_name("/ViewerPreferences")
  let empty = pdf_document_empty()
  let read_missing_root : Result[PdfObject?, Error] = try? empty.pdf_merge_catalog_entry(
    key,
  )
  guard read_missing_root is Err(PdfError::RootExpected) else {
    fail("expected PdfError::RootExpected")
  }
  let add_missing_root : Result[PdfDocument, Error] = try? empty.pdf_merge_add_catalog_entry(
    key,
    PdfInteger(1),
  )
  guard add_missing_root is Err(PdfError::RootExpected) else {
    fail("expected PdfError::RootExpected")
  }

  let conflict = pdf_document_empty()
  conflict.set_root(1)
  conflict.add_object_given_number(
    1,
    PdfDictionary([(key, PdfString(@ascii.encode("root")))]),
  )
  conflict.add_object_given_number(
    10,
    PdfDictionary([(key, PdfString(@ascii.encode("trailer")))]),
  )
  conflict.set_trailer_dict(
    PdfDictionary([(pdf_merge_root_key(), PdfIndirect(10))]),
  )
  @test.assert_eq(
    try! conflict.pdf_merge_catalog_entry(key),
    Some(PdfString(@ascii.encode("trailer"))),
  )
  @test.assert_eq(try! pdf_merge_catalog_extra_entries([conflict]), [
    (key, PdfString(@ascii.encode("trailer"))),
  ])
  let added_key = pdf_merge_name("/PageMode")
  let updated = try! conflict.pdf_merge_add_catalog_entry(
    added_key,
    PdfNameObject(pdf_merge_name("/UseOutlines")),
  )
  let updated_root = updated.lookup_object_or_null(updated.root())
  @test.assert_eq(
    updated_root.lookup_immediate(key),
    Some(PdfString(@ascii.encode("trailer"))),
  )
  @test.assert_eq(
    updated_root.lookup_immediate(added_key),
    Some(PdfNameObject(pdf_merge_name("/UseOutlines"))),
  )

  let structure_conflict = pdf_document_empty()
  structure_conflict.set_root(1)
  structure_conflict.add_object_given_number(1, PdfDictionary([]))
  structure_conflict.add_object_given_number(
    10,
    PdfDictionary([(pdf_merge_struct_tree_root_key(), PdfIndirect(30))]),
  )
  structure_conflict.set_trailer_dict(
    PdfDictionary([(pdf_merge_root_key(), PdfIndirect(10))]),
  )
  @test.assert_eq(try! pdf_merge_structure_tree_roots([structure_conflict]), [
    PdfIndirect(30),
  ])

  let unresolved = pdf_document_empty()
  unresolved.set_root(1)
  unresolved.add_object_given_number(
    1,
    PdfDictionary([(key, PdfString(@ascii.encode("root")))]),
  )
  unresolved.set_trailer_dict(
    PdfDictionary([(pdf_merge_root_key(), PdfIndirect(99))]),
  )
  let unresolved_result : Result[PdfObject?, Error] = try? unresolved.pdf_merge_catalog_entry(
    key,
  )
  guard unresolved_result is Err(PdfError::RootExpected) else {
    fail("expected unresolved trailer root")
  }

  let doc = pdf_document_empty()
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (
        pdf_merge_acroform_key(),
        PdfDictionary([
          (pdf_merge_fields_key(), PdfInteger(1)),
          (pdf_merge_name("/NeedAppearances"), PdfBoolean(true)),
        ]),
      ),
    ]),
  )
  doc.set_root(1)
  @test.assert_eq(
    try! pdf_merge_acroforms([doc]),
    Some(
      PdfDictionary([
        (pdf_merge_fields_key(), PdfArray([])),
        (pdf_merge_name("/NeedAppearances"), PdfBoolean(true)),
      ]),
    ),
  )
}

///|
test "private merge destination renumbering covers all target variants" {
  let changes : ReadOnlyArray[(Int, Int)] = [(1, 10)]
  let change_map = pdf_page_reference_map(changes)
  @test.assert_eq(
    pdf_merge_renumber_target_page_with_map(
      TargetOtherDocPageNumber(3),
      change_map,
    ),
    TargetOtherDocPageNumber(3),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(DestNull, change_map),
    DestNull,
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestNamed(pdf_merge_name("/Named")),
      change_map,
    ),
    DestNamed(pdf_merge_name("/Named")),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestString(@ascii.encode("named")),
      change_map,
    ),
    DestString(@ascii.encode("named")),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestAction(PdfDictionary([(pdf_merge_name("/D"), PdfIndirect(1))])),
      change_map,
    ),
    DestAction(PdfDictionary([(pdf_merge_name("/D"), PdfIndirect(10))])),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestXYZ(TargetPageObject(1), Some(1.0), Some(2.0), Some(3.0)),
      change_map,
    ),
    DestXYZ(TargetPageObject(10), Some(1.0), Some(2.0), Some(3.0)),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestFitH(TargetPageObject(1), Some(2.0)),
      change_map,
    ),
    DestFitH(TargetPageObject(10), Some(2.0)),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestFitV(TargetPageObject(1), Some(2.0)),
      change_map,
    ),
    DestFitV(TargetPageObject(10), Some(2.0)),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestFitR(TargetPageObject(1), 1.0, 2.0, 3.0, 4.0),
      change_map,
    ),
    DestFitR(TargetPageObject(10), 1.0, 2.0, 3.0, 4.0),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestFitB(TargetPageObject(1)),
      change_map,
    ),
    DestFitB(TargetPageObject(10)),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestFitBH(TargetPageObject(1), Some(2.0)),
      change_map,
    ),
    DestFitBH(TargetPageObject(10), Some(2.0)),
  )
  @test.assert_eq(
    pdf_merge_renumber_destination_with_map(
      DestFitBV(TargetPageObject(1), Some(2.0)),
      change_map,
    ),
    DestFitBV(TargetPageObject(10), Some(2.0)),
  )
}

///|
/// Merges selected page ranges from multiple documents into one document.
///
/// Each entry in `ranges` belongs to the document at the same index and uses
/// one-based page numbers. The retain flags control whether numbering,
/// bookmarks, optional-content data, AcroForms, named destinations, name
/// dictionary entries, structure trees, info dictionaries, and catalog entries
/// are copied into the output. Raises `PdfError::PageTreeExpected` when the
/// document and range lists do not align.
pub fn pdf_merge_documents(
  documents : ArrayView[PdfDocument],
  ranges : ArrayView[Array[Int]],
  retain_numbering? : Bool = false,
  retain_bookmarks? : Bool = true,
  retain_optional_content? : Bool = true,
  retain_acroforms? : Bool = true,
  retain_named_destinations? : Bool = true,
  retain_name_dictionary? : Bool = true,
  retain_structure_tree? : Bool = true,
  add_toplevel_document? : Bool = false,
  retain_info? : Bool = true,
  retain_catalog_entries? : Bool = true,
  remove_duplicate_fonts? : Bool = false,
) -> PdfDocument raise PdfError {
  if documents.length() == 0 || documents.length() != ranges.length() {
    raise PageTreeExpected
  }
  let page_labels = if retain_numbering {
    pdf_page_label_merge(documents, ranges)
  } else {
    []
  }
  let staged : Array[PdfDocument] = []
  let mut offset = 0
  for i in 0..<documents.length() {
    let extracted = documents[i].pdf_of_pages(
      ranges[i],
      process_struct_tree=retain_structure_tree,
    )
    let renumbered = extracted.renumber_objects_by_offset(offset)
    offset = renumbered.objects.max_object_number()
    staged.push(renumbered)
  }
  let destination_name_changes = if retain_named_destinations {
    pdf_merge_destination_name_changes(staged)
  } else {
    [
      for _ in staged => []
    ]
  }
  let catalog_destination_name_changes = if retain_named_destinations {
    pdf_merge_catalog_destination_name_changes(staged)
  } else {
    [
      for _ in staged => []
    ]
  }
  let all_destination_name_changes = pdf_merge_all_destination_name_changes(
    destination_name_changes,
  )
  let all_catalog_destination_name_changes = pdf_merge_all_catalog_destination_name_changes(
    catalog_destination_name_changes,
  )
  let open_action = if retain_catalog_entries {
    pdf_merge_open_action(
      staged, retain_named_destinations, destination_name_changes, all_destination_name_changes,
      catalog_destination_name_changes, all_catalog_destination_name_changes,
    )
  } else {
    None
  }
  if retain_named_destinations {
    for i in 0..<staged.length() {
      staged[i].pdf_merge_rewrite_destination_callsite_names(
        destination_name_changes[i],
        all_destination_name_changes,
        catalog_destination_name_changes[i],
        all_catalog_destination_name_changes,
      )
    }
  }
  let optional_content = if retain_optional_content {
    pdf_merge_optional_content(staged)
  } else {
    None
  }
  let acroform = if retain_acroforms {
    pdf_merge_acroforms(staged)
  } else {
    None
  }
  let info = if retain_info { pdf_merge_info_dictionary(staged) } else { None }
  let name_dictionary_entries = if retain_name_dictionary {
    pdf_merge_name_dictionary_entries(staged)
  } else {
    []
  }
  let structure_tree_roots = if retain_structure_tree {
    pdf_merge_structure_tree_roots(staged)
  } else {
    []
  }
  let parent_tree_entries = if retain_structure_tree &&
    structure_tree_roots.length() > 1 {
    pdf_merge_renumber_parent_trees(staged)
  } else {
    []
  }
  let catalog_entries = if retain_catalog_entries {
    pdf_merge_catalog_extra_entries(staged)
  } else {
    []
  }
  let merged = pdf_document_empty()
  let (major, minor) = pdf_merge_max_version(staged)
  merged.set_version(major, minor)
  let pages : Array[@page.PdfPage] = []
  let old_page_numbers : Array[Int] = []
  let bookmarks : Array[@bookmark.PdfBookmark] = []
  let oldstyle_destinations : Array[(PdfName, PdfObject)] = []
  let nametree_destinations : Array[(PdfBytes, PdfObject)] = []
  for document in staged {
    merged.pdf_merge_copy_objects_from(document)
    let old_page_numbers_for_document = document.page_reference_numbers()
    for page_number in old_page_numbers_for_document {
      old_page_numbers.push(page_number)
    }
    if retain_bookmarks {
      for bookmark in document.read_bookmarks(preserve_actions=true) {
        bookmarks.push(bookmark)
      }
    }
    for page in document.pages_of_pagetree() {
      pages.push(page)
    }
  }
  let page_root_number = merged.add_pagetree(pages)
  ignore(merged.add_root(page_root_number, []))
  let merged = if catalog_entries.length() > 0 {
    for entry in catalog_entries {
      let (key, value) = entry
      ignore(merged.pdf_merge_add_catalog_entry(key, value))
    }
    merged
  } else {
    merged
  }
  let merged = match
    merged.pdf_merge_structure_tree_root(
      structure_tree_roots, parent_tree_entries, add_toplevel_document,
    ) {
    Some(structure_tree_root) =>
      merged.pdf_merge_add_catalog_entry(
        pdf_merge_struct_tree_root_key(),
        structure_tree_root,
      )
    None => merged
  }
  let new_page_numbers = merged.page_reference_numbers()
  let changes = pdf_page_reference_changes(old_page_numbers, new_page_numbers)
  let change_map = pdf_page_reference_map(changes)
  merged.pdf_page_renumber_references(changes)
  let merged = match open_action {
    Some(open_action) =>
      merged.pdf_merge_add_catalog_entry(
        pdf_merge_open_action_key(),
        pdf_page_renumber_object_with_map(open_action, change_map),
      )
    None => merged
  }
  if retain_named_destinations {
    for i in 0..<staged.length() {
      let document = staged[i]
      for
        entry in document.pdf_merge_oldstyle_destinations(
          changes,
          catalog_destination_name_changes[i],
        ) {
        oldstyle_destinations.push(entry)
      }
      for
        entry in document.pdf_merge_nametree_destinations(
          changes,
          destination_name_changes[i],
        ) {
        nametree_destinations.push(entry)
      }
    }
  }
  let merged = match optional_content {
    Some(content) => merged.write_optional_content_groups(content)
    None => merged
  }
  let merged = match acroform {
    Some(form) =>
      merged.pdf_merge_add_catalog_entry(
        pdf_merge_acroform_key(),
        PdfIndirect(merged.add_object(form)),
      )
    None => merged
  }
  let merged = if retain_named_destinations ||
    name_dictionary_entries.length() > 0 {
    merged.pdf_merge_add_named_destinations(
      oldstyle_destinations, nametree_destinations, name_dictionary_entries,
    )
  } else {
    merged
  }
  match info {
    Some(info) =>
      merged.set_trailer_dict(
        merged
        .trailer_dict()
        .add_dict_entry(
          pdf_merge_info_key(),
          PdfIndirect(merged.add_object(info)),
        ),
      )
    None => ()
  }
  merged.remove_unreferenced()
  let merged = if retain_bookmarks && bookmarks.length() > 0 {
    merged.add_bookmarks(
      [
        for bookmark in bookmarks => {
          pdf_merge_renumber_bookmark_with_map(bookmark, change_map)
        }
      ],
    )
  } else {
    merged
  }
  let merged = if retain_numbering && page_labels.length() > 0 {
    merged.write_page_labels(page_labels)
  } else {
    merged
  }
  if remove_duplicate_fonts {
    merged.remove_duplicate_fonts()
  }
  let (merged, _) = merged.with_file_id()
  merged
}

///|
/// CamlPDF-shaped convenience wrapper for merging PDFs.
///
/// `names` must have the same length as `documents`; it is retained for API
/// compatibility with CamlPDF's merge entry point. Structure-tree processing
/// and optional top-level `/Document` wrapping are controlled by the optional
/// flags.
pub fn pdf_merge_pdfs(
  retain_numbering : Bool,
  remove_duplicate_fonts : Bool,
  names : ArrayView[String],
  documents : ArrayView[PdfDocument],
  ranges : ArrayView[Array[Int]],
  process_struct_trees? : Bool = true,
  add_toplevel_document? : Bool = false,
) -> PdfDocument raise PdfError {
  if names.length() != documents.length() {
    raise PageTreeExpected
  }
  pdf_merge_documents(
    documents,
    ranges,
    retain_numbering~,
    retain_structure_tree=process_struct_trees,
    add_toplevel_document~,
    remove_duplicate_fonts~,
  )
}

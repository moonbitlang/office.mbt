///|
fn pdf_merge_max_version(
  documents : ArrayView[PdfDocument],
) -> (Int, Int) raise PdfError {
  if documents.length() == 0 {
    raise PageTreeExpected
  }
  let mut major = documents[0].major
  let mut minor = documents[0].minor
  for i in 1..<documents.length() {
    let (candidate_major, candidate_minor) = documents[i].version()
    if candidate_major > major ||
      (candidate_major == major && candidate_minor > minor) {
      major = candidate_major
      minor = candidate_minor
    }
  }
  (major, minor)
}

///|
fn pdf_merge_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_merge_root_key() -> PdfName {
  pdf_merge_name("/Root")
}

///|
fn pdf_merge_acroform_key() -> PdfName {
  pdf_merge_name("/AcroForm")
}

///|
fn pdf_merge_open_action_key() -> PdfName {
  pdf_merge_name("/OpenAction")
}

///|
fn pdf_merge_ocproperties_key() -> PdfName {
  pdf_merge_name("/OCProperties")
}

///|
fn pdf_merge_outlines_key() -> PdfName {
  pdf_merge_name("/Outlines")
}

///|
fn pdf_merge_page_labels_key() -> PdfName {
  pdf_merge_name("/PageLabels")
}

///|
fn pdf_merge_pages_key() -> PdfName {
  pdf_merge_name("/Pages")
}

///|
fn pdf_merge_struct_tree_root_key() -> PdfName {
  pdf_merge_name("/StructTreeRoot")
}

///|
fn pdf_merge_type_key() -> PdfName {
  pdf_merge_name("/Type")
}

///|
fn pdf_merge_dests_key() -> PdfName {
  pdf_merge_name("/Dests")
}

///|
fn pdf_merge_fields_key() -> PdfName {
  pdf_merge_name("/Fields")
}

///|
fn pdf_merge_info_key() -> PdfName {
  pdf_merge_name("/Info")
}

///|
fn pdf_merge_names_key() -> PdfName {
  pdf_merge_name("/Names")
}

///|
fn PdfDocument::pdf_merge_copy_objects_from(
  self : PdfDocument,
  source : PdfDocument,
) -> Unit {
  for number in source.object_numbers() {
    match source.objects.get_entry(number) {
      Some(entry) =>
        self.objects.set_entry(number, {
          data: entry.data,
          generation: entry.generation,
        })
      None => ()
    }
  }
}

///|
fn pdf_merge_name_member(names : ArrayView[PdfName], name : PdfName) -> Bool {
  for existing in names {
    if existing == name {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_merge_catalog_extra_key(key : PdfName) -> Bool {
  !(key == pdf_merge_type_key() ||
  key == pdf_merge_pages_key() ||
  key == pdf_merge_page_labels_key() ||
  key == pdf_merge_outlines_key() ||
  key == pdf_merge_dests_key() ||
  key == pdf_merge_names_key() ||
  key == pdf_merge_ocproperties_key() ||
  key == pdf_merge_acroform_key() ||
  key == pdf_merge_struct_tree_root_key() ||
  key == pdf_merge_open_action_key())
}

///|
fn pdf_merge_catalog_extra_entries(
  documents : ArrayView[PdfDocument],
) -> Array[(PdfName, PdfObject)] {
  let entries : Array[(PdfName, PdfObject)] = []
  let seen : Array[PdfName] = []
  for document in documents {
    match document.lookup_object_or_null(document.root()) {
      PdfDictionary(root_entries) =>
        for entry in root_entries {
          let (key, _) = entry
          if pdf_merge_catalog_extra_key(key) &&
            !pdf_merge_name_member(seen, key) {
            entries.push(entry)
            seen.push(key)
          }
        }
      _ => ()
    }
  }
  entries
}

///|
fn PdfDocument::pdf_merge_catalog_entry(
  self : PdfDocument,
  key : PdfName,
) -> PdfObject? raise PdfError {
  let root = self.lookup_object_or_null(self.root())
  if root == PdfNull {
    raise RootExpected
  }
  self.lookup_direct(key, root)
}

///|
fn pdf_merge_acroforms(
  documents : ArrayView[PdfDocument],
) -> PdfObject? raise PdfError {
  let forms : Array[PdfObject] = []
  for document in documents {
    match document.pdf_merge_catalog_entry(pdf_merge_acroform_key()) {
      Some(PdfDictionary(_) as form) => forms.push(form)
      _ => ()
    }
  }
  if forms.length() == 0 {
    None
  } else {
    let fields : Array[PdfObject] = []
    let entries : Array[(PdfName, PdfObject)] = []
    for form in forms {
      match form {
        PdfDictionary(form_entries) =>
          for entry in form_entries {
            let (key, value) = entry
            if key == pdf_merge_fields_key() {
              match value {
                PdfArray(items) =>
                  for item in items {
                    fields.push(item)
                  }
                _ => ()
              }
            } else {
              entries.push(entry)
            }
          }
        _ => ()
      }
    }
    Some(
      PdfDictionary(entries).add_dict_entry(
        pdf_merge_fields_key(),
        PdfArray(fields),
      ),
    )
  }
}

///|
fn pdf_merge_info_dictionary(documents : ArrayView[PdfDocument]) -> PdfObject? {
  for document in documents {
    match
      document.lookup_direct(pdf_merge_info_key(), document.trailer_dict()) {
      Some(info) => break Some(info)
      None => ()
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_merge_oldstyle_destinations(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match self.pdf_merge_catalog_entry(pdf_merge_dests_key()) {
    Some(PdfDictionary(entries)) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, destination) = entry
        output.push(
          (
            key,
            pdf_object_of_destination(
              pdf_merge_renumber_destination(
                self.read_destination(destination, shallow=true),
                changes,
              ),
            ),
          ),
        )
      }
      output
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_merge_nametree_destinations(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> Array[(PdfBytes, PdfObject)] raise PdfError {
  match self.pdf_merge_catalog_entry(pdf_merge_names_key()) {
    Some(names) =>
      match self.lookup_direct(pdf_merge_dests_key(), names) {
        Some(dests_tree) => {
          let output : Array[(PdfBytes, PdfObject)] = []
          for entry in self.read_name_tree(dests_tree) {
            let (key, destination) = entry
            output.push(
              (
                key,
                pdf_object_of_destination(
                  pdf_merge_renumber_destination(
                    self.read_destination(destination, shallow=true),
                    changes,
                  ),
                ),
              ),
            )
          }
          output
        }
        None => []
      }
    None => []
  }
}

///|
fn PdfDocument::pdf_merge_add_catalog_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
) -> PdfDocument raise PdfError {
  let root = self.lookup_object_or_null(self.root())
  if root == PdfNull {
    raise RootExpected
  }
  let new_root = self.add_object(root.add_dict_entry(key, value))
  self.set_root(new_root)
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_merge_root_key(), PdfIndirect(new_root)),
  )
  self
}

///|
fn PdfDocument::pdf_merge_add_named_destinations(
  self : PdfDocument,
  oldstyle_destinations : ArrayView[(PdfName, PdfObject)],
  nametree_destinations : ArrayView[(PdfBytes, PdfObject)],
) -> PdfDocument raise PdfError {
  let pdf = if oldstyle_destinations.length() > 0 {
    self.pdf_merge_add_catalog_entry(
      pdf_merge_dests_key(),
      PdfDictionary([ for entry in oldstyle_destinations => entry ]),
    )
  } else {
    self
  }
  if nametree_destinations.length() > 0 {
    pdf.pdf_merge_add_catalog_entry(
      pdf_merge_names_key(),
      PdfDictionary([
        (pdf_merge_dests_key(), pdf.build_name_tree(nametree_destinations)),
      ]),
    )
  } else {
    pdf
  }
}

///|
fn pdf_merge_renumber_target_page(
  target : PdfTargetPage,
  changes : ArrayView[(Int, Int)],
) -> PdfTargetPage {
  match target {
    TargetPageObject(number) =>
      TargetPageObject(pdf_page_changed_reference(changes, number))
    TargetOtherDocPageNumber(_) => target
  }
}

///|
fn pdf_merge_renumber_destination(
  destination : PdfDestination,
  changes : ArrayView[(Int, Int)],
) -> PdfDestination {
  match destination {
    DestAction(action) => DestAction(pdf_page_renumber_object(action, changes))
    DestNull => DestNull
    DestNamed(_) => destination
    DestString(_) => destination
    DestXYZ(target, left, top, zoom) =>
      DestXYZ(pdf_merge_renumber_target_page(target, changes), left, top, zoom)
    DestFit(target) => DestFit(pdf_merge_renumber_target_page(target, changes))
    DestFitH(target, top) =>
      DestFitH(pdf_merge_renumber_target_page(target, changes), top)
    DestFitV(target, left) =>
      DestFitV(pdf_merge_renumber_target_page(target, changes), left)
    DestFitR(target, left, bottom, right, top) =>
      DestFitR(
        pdf_merge_renumber_target_page(target, changes),
        left,
        bottom,
        right,
        top,
      )
    DestFitB(target) =>
      DestFitB(pdf_merge_renumber_target_page(target, changes))
    DestFitBH(target, top) =>
      DestFitBH(pdf_merge_renumber_target_page(target, changes), top)
    DestFitBV(target, left) =>
      DestFitBV(pdf_merge_renumber_target_page(target, changes), left)
  }
}

///|
fn pdf_merge_renumber_bookmark(
  bookmark : PdfBookmark,
  changes : ArrayView[(Int, Int)],
) -> PdfBookmark {
  {
    ..bookmark,
    target: pdf_merge_renumber_destination(bookmark.target, changes),
  }
}

///|
pub fn pdf_merge_documents(
  documents : ArrayView[PdfDocument],
  ranges : ArrayView[Array[Int]],
  retain_numbering? : Bool = false,
  retain_bookmarks? : Bool = true,
  retain_optional_content? : Bool = true,
  retain_acroforms? : Bool = true,
  retain_named_destinations? : Bool = true,
  retain_info? : Bool = true,
  retain_catalog_entries? : Bool = true,
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
    let extracted = documents[i].pdf_of_pages(ranges[i])
    let renumbered = extracted.renumber_objects_by_offset(offset)
    offset = renumbered.objects.max_object_number()
    staged.push(renumbered)
  }
  let optional_content = if retain_optional_content {
    pdf_optional_content_merge(staged)
  } else {
    None
  }
  let acroform = if retain_acroforms {
    pdf_merge_acroforms(staged)
  } else {
    None
  }
  let info = if retain_info { pdf_merge_info_dictionary(staged) } else { None }
  let catalog_entries = if retain_catalog_entries {
    pdf_merge_catalog_extra_entries(staged)
  } else {
    []
  }
  let merged = pdf_document_empty()
  let (major, minor) = pdf_merge_max_version(staged)
  merged.set_version(major, minor)
  let pages : Array[PdfPage] = []
  let old_page_numbers : Array[Int] = []
  let bookmarks : Array[PdfBookmark] = []
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
  let new_page_numbers = merged.page_reference_numbers()
  let changes = pdf_page_reference_changes(old_page_numbers, new_page_numbers)
  if retain_named_destinations {
    for document in staged {
      for entry in document.pdf_merge_oldstyle_destinations(changes) {
        oldstyle_destinations.push(entry)
      }
      for entry in document.pdf_merge_nametree_destinations(changes) {
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
  let merged = if retain_named_destinations {
    merged.pdf_merge_add_named_destinations(
      oldstyle_destinations, nametree_destinations,
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
          pdf_merge_renumber_bookmark(bookmark, changes)
        }
      ],
    )
  } else {
    merged
  }
  if retain_numbering && page_labels.length() > 0 {
    merged.write_page_labels(page_labels)
  } else {
    merged
  }
}

///|
priv struct PdfPageMatrixLookup {
  page_numbers : PdfPageNumberLookup
  matrices : @hashmap.HashMap[Int, TransformMatrix]
}

///|
fn pdf_page_matrix_lookup(
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfPageMatrixLookup {
  let values : @hashmap.HashMap[Int, TransformMatrix] = HashMap([])
  for entry in matrices {
    let (matrix_page_number, matrix) = entry
    if !values.contains(matrix_page_number) {
      values[matrix_page_number] = matrix
    }
  }
  {
    page_numbers: pdf_page_number_lookup(page_reference_numbers),
    matrices: values,
  }
}

///|
fn PdfPageMatrixLookup::matrix_for_page_number(
  self : PdfPageMatrixLookup,
  page_number : Int,
) -> TransformMatrix? {
  self.matrices.get(page_number)
}

///|
fn PdfPageMatrixLookup::page_number_of_target(
  self : PdfPageMatrixLookup,
  target : PdfTargetPage,
) -> Int {
  match target {
    TargetPageObject(object_number) =>
      self.page_numbers.page_number(object_number)
    TargetOtherDocPageNumber(_) => 0
  }
}

///|
fn PdfDocument::pdf_page_matrix_for_destination_with_lookup(
  self : PdfDocument,
  destination : PdfDestination,
  lookup : PdfPageMatrixLookup,
) -> TransformMatrix? raise PdfError {
  let page_number = self.pdf_page_matrix_page_number_for_destination_with_lookup(
    destination, lookup,
  )
  if page_number == 0 {
    None
  } else {
    lookup.matrix_for_page_number(page_number)
  }
}

///|
fn PdfDocument::pdf_page_matrix_page_number_for_destination_with_lookup(
  self : PdfDocument,
  destination : PdfDestination,
  lookup : PdfPageMatrixLookup,
) -> Int raise PdfError {
  match destination {
    DestNamed(_) | DestString(_) => {
      let resolved = self.read_destination(
        pdf_object_of_destination(destination),
      )
      if resolved == destination {
        0
      } else {
        self.pdf_page_matrix_page_number_for_destination_with_lookup(
          resolved, lookup,
        )
      }
    }
    DestAction(action) =>
      match
        (
          self.lookup_direct(pdf_dest_s_key(), action),
          self.lookup_direct(pdf_dest_d_key(), action),
        ) {
        (Some(PdfNameObject(name)), Some(raw_destination)) if name ==
          pdf_dest_goto_name() =>
          self.pdf_page_matrix_page_number_for_destination_with_lookup(
            self.read_destination(raw_destination),
            lookup,
          )
        _ => 0
      }
    DestXYZ(target, _, _, _)
    | DestFitH(target, _)
    | DestFitV(target, _)
    | DestFitR(target, _, _, _, _)
    | DestFitBH(target, _)
    | DestFitBV(target, _) => lookup.page_number_of_target(target)
    _ => 0
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_object_with_lookup(
  self : PdfDocument,
  raw_destination : PdfObject,
  lookup : PdfPageMatrixLookup,
) -> PdfObject? raise PdfError {
  match
    self.pdf_page_transform_destination_object_with_shallow_lookup(
      raw_destination, lookup, false,
    ) {
    Some(destination) => Some(PdfIndirect(self.add_object(destination)))
    None => None
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_object_with_shallow_lookup(
  self : PdfDocument,
  raw_destination : PdfObject,
  lookup : PdfPageMatrixLookup,
  shallow : Bool,
) -> PdfObject? raise PdfError {
  let destination = self.read_destination(raw_destination, shallow~)
  match self.pdf_page_matrix_for_destination_with_lookup(destination, lookup) {
    Some(matrix) if matrix != transform_identity_matrix =>
      Some(
        pdf_object_of_destination(
          self.transform_destination(matrix, destination),
        ),
      )
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_transform_catalog_destinations_object(
  self : PdfDocument,
  dests : PdfObject,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfObject? {
  let lookup = pdf_page_matrix_lookup(matrices, page_reference_numbers)
  match dests {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      let mut changed = false
      for entry in entries {
        let (key, destination) = entry
        try {
          match
            self.pdf_page_transform_destination_object_with_shallow_lookup(
              destination, lookup, true,
            ) {
            Some(transformed) => {
              output.push((key, transformed))
              changed = true
            }
            None => output.push(entry)
          }
        } catch {
          _ => output.push(entry)
        }
      }
      if changed {
        Some(PdfDictionary(output))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_active_catalog(
  self : PdfDocument,
) -> (PdfObject, Bool)? {
  let uses_trailer_root = self
    .trailer_dict()
    .lookup_immediate(pdf_page_root_key())
    is Some(_)
  Some((self.catalog(), uses_trailer_root)) catch {
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_replace_active_catalog_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  catalog : PdfObject,
  uses_trailer_root : Bool,
) -> Unit raise PdfError {
  if uses_trailer_root {
    self.replace_chain([pdf_page_root_key(), key], value)
  } else {
    self.add_object_given_number(
      self.root(),
      catalog.add_dict_entry(key, value),
    )
  }
}

///|
fn PdfDocument::pdf_page_transform_catalog_destinations_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_dests_key()) {
        Some(PdfIndirect(dests_number)) =>
          match
            self.pdf_page_transform_catalog_destinations_object(
              self.lookup_object_or_null(dests_number),
              matrices,
              page_reference_numbers,
            ) {
            Some(dests) => self.add_object_given_number(dests_number, dests)
            None => ()
          }
        Some(dests) =>
          match
            self.pdf_page_transform_catalog_destinations_object(
              dests, matrices, page_reference_numbers,
            ) {
            Some(transformed) =>
              self.pdf_page_replace_active_catalog_entry(
                pdf_page_dests_key(),
                transformed,
                root_object,
                uses_trailer_root,
              )
            None => ()
          }
        None => ()
      }
    None => ()
  }
}

///|
fn PdfDocument::pdf_page_transform_name_tree_destination_entries(
  self : PdfDocument,
  dests_tree : PdfObject,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Array[(PdfBytes, PdfObject)]? {
  let lookup = pdf_page_matrix_lookup(matrices, page_reference_numbers)
  let output : Array[(PdfBytes, PdfObject)] = []
  let mut changed = false
  for entry in self.read_name_tree(dests_tree) {
    let (key, destination) = entry
    try {
      match
        self.pdf_page_transform_destination_object_with_shallow_lookup(
          destination, lookup, true,
        ) {
        Some(transformed) => {
          output.push((key, transformed))
          changed = true
        }
        None => output.push(entry)
      }
    } catch {
      _ => output.push(entry)
    }
  }
  if changed {
    Some(output)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_name_tree_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_names_key()) {
        Some(PdfIndirect(names_number)) => {
          let names_object = self.lookup_object_or_null(names_number)
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              match
                self.pdf_page_transform_name_tree_destination_entries(
                  dests_tree, matrices, page_reference_numbers,
                ) {
                Some(entries) =>
                  self.add_object_given_number(
                    names_number,
                    names_object.add_dict_entry(
                      pdf_page_dests_key(),
                      self.build_name_tree(entries),
                    ),
                  )
                None => ()
              }
            None => ()
          }
        }
        Some(PdfDictionary(_) as names_object) =>
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              match
                self.pdf_page_transform_name_tree_destination_entries(
                  dests_tree, matrices, page_reference_numbers,
                ) {
                Some(entries) =>
                  self.pdf_page_replace_active_catalog_entry(
                    pdf_page_names_key(),
                    names_object.add_dict_entry(
                      pdf_page_dests_key(),
                      self.build_name_tree(entries),
                    ),
                    root_object,
                    uses_trailer_root,
                  )
                None => ()
              }
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_page_transform_action_object_with_lookup(
  self : PdfDocument,
  raw_action : PdfObject,
  lookup : PdfPageMatrixLookup,
) -> PdfObject? raise PdfError {
  let action = self.direct(raw_action)
  match
    (
      self.lookup_direct(pdf_dest_s_key(), action),
      action.lookup_immediate(pdf_dest_d_key()),
    ) {
    (Some(PdfNameObject(name)), Some(raw_destination)) if name ==
      pdf_dest_goto_name() =>
      match
        self.pdf_page_transform_destination_object_with_lookup(
          raw_destination, lookup,
        ) {
        Some(destination) =>
          Some(action.add_dict_entry(pdf_dest_d_key(), destination))
        None => None
      }
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_transform_bookmarks_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let lookup = pdf_page_matrix_lookup(matrices, page_reference_numbers)
  let output : Array[PdfBookmark] = []
  let mut changed = false
  for bookmark in bookmarks {
    let target = match
      self.pdf_page_matrix_for_destination_with_lookup(bookmark.target, lookup) {
      Some(matrix) if matrix != transform_identity_matrix => {
        changed = true
        self.transform_destination(matrix, bookmark.target)
      }
      _ => bookmark.target
    }
    output.push({ ..bookmark, target, })
  }
  if changed {
    self.add_bookmarks(output)
  } else {
    self
  }
}

///|
fn PdfDocument::pdf_page_transform_link_annotation_object_with_lookup(
  self : PdfDocument,
  annotation : PdfObject,
  lookup : PdfPageMatrixLookup,
) -> PdfObject? raise PdfError {
  match self.lookup_direct(pdf_page_subtype_key(), annotation) {
    Some(PdfNameObject(kind)) if kind == pdf_page_type_link() =>
      match annotation.lookup_immediate(pdf_page_dest_key()) {
        Some(raw_destination) =>
          match
            self.pdf_page_transform_destination_object_with_lookup(
              raw_destination, lookup,
            ) {
            Some(destination) =>
              Some(annotation.add_dict_entry(pdf_page_dest_key(), destination))
            None => None
          }
        None =>
          match annotation.lookup_immediate(pdf_page_action_key()) {
            Some(raw_action) =>
              match
                self.pdf_page_transform_action_object_with_lookup(
                  raw_action, lookup,
                ) {
                Some(action) =>
                  Some(annotation.add_dict_entry(pdf_page_action_key(), action))
                None => None
              }
            None => None
          }
      }
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_transform_link_annotations_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  let lookup = pdf_page_matrix_lookup(matrices, page_reference_numbers)
  for page_number in self.page_reference_numbers() {
    let page_object = self.lookup_object_or_null(page_number)
    match self.lookup_direct(pdf_page_annots_key(), page_object) {
      Some(PdfArray(annotations)) =>
        for index in 0..<annotations.length() {
          match annotations[index] {
            PdfIndirect(annotation_number) =>
              try {
                let annotation = self.lookup_object_or_null(annotation_number)
                match
                  self.pdf_page_transform_link_annotation_object_with_lookup(
                    annotation, lookup,
                  ) {
                  Some(updated) =>
                    self.add_object_given_number(annotation_number, updated)
                  None => ()
                }
              } catch {
                _ => ()
              }
            PdfDictionary(_) as annotation =>
              try {
                match
                  self.pdf_page_transform_link_annotation_object_with_lookup(
                    annotation, lookup,
                  ) {
                  Some(updated) => annotations[index] = updated
                  None => ()
                }
              } catch {
                _ => ()
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_page_transform_open_action_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit {
  let lookup = pdf_page_matrix_lookup(matrices, page_reference_numbers)
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_open_action_key()) {
        Some(raw_open_action) =>
          match self.direct(raw_open_action) {
            PdfArray(_) as raw_destination =>
              try {
                match
                  self.pdf_page_transform_destination_object_with_lookup(
                    raw_destination, lookup,
                  ) {
                  Some(destination) =>
                    self.pdf_page_replace_active_catalog_entry(
                      pdf_page_open_action_key(),
                      destination,
                      root_object,
                      uses_trailer_root,
                    )
                  None => ()
                }
              } catch {
                _ => ()
              }
            PdfDictionary(_) as raw_action =>
              try {
                match
                  self.pdf_page_transform_action_object_with_lookup(
                    raw_action, lookup,
                  ) {
                  Some(action) =>
                    self.pdf_page_replace_active_catalog_entry(
                      pdf_page_open_action_key(),
                      action,
                      root_object,
                      uses_trailer_root,
                    )
                  None => ()
                }
              } catch {
                _ => ()
              }
            _ => ()
          }
        None => ()
      }
    None => ()
  }
}

///|
fn PdfDocument::pdf_page_transform_matrix_destinations(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
  transform_bookmarks : Bool,
) -> PdfDocument raise PdfError {
  let pdf = if transform_bookmarks {
    self.pdf_page_transform_bookmarks_for_matrices(
      matrices, page_reference_numbers,
    )
  } else {
    self
  }
  pdf.pdf_page_transform_link_annotations_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_open_action_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_catalog_destinations_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_destination_name_tree_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf
}

///|
/// Replace the document page tree with `pages`.
///
/// When `change_references` is true, page-object references in destinations,
/// actions, annotations, and bookmarks are rewritten from the old page set to
/// the new one. `matrices` can transform destination coordinates for pages
/// whose geometry changed, and `changes` can map old page serials to new
/// serials when page counts differ.
pub fn PdfDocument::change_pages(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  change_references? : Bool = false,
  matrices? : ArrayView[(Int, TransformMatrix)] = [],
  changes? : ArrayView[(Int, Int)] = [],
) -> PdfDocument raise PdfError {
  let old_page_numbers = self.page_reference_numbers()
  let pdf = self.copy()
  let page_root_number = pdf.add_pagetree(pages)
  ignore(pdf.add_root(page_root_number, []))
  if change_references {
    let new_page_numbers = pdf.page_reference_numbers()
    let reference_changes = if changes.length() > 0 {
      pdf_page_reference_changes_from_serials(
        old_page_numbers, new_page_numbers, changes,
      )
    } else if old_page_numbers.length() != new_page_numbers.length() {
      []
    } else {
      pdf_page_reference_changes(old_page_numbers, new_page_numbers)
    }
    pdf.pdf_page_renumber_references(reference_changes)
    if matrices.length() > 0 {
      pdf.pdf_page_transform_matrix_destinations(
        matrices,
        new_page_numbers,
        old_page_numbers.length() == new_page_numbers.length(),
      )
    } else {
      pdf
    }
  } else {
    pdf
  }
}

///|
/// Compatibility wrapper for `PdfDocument::change_pages`.
pub fn pdf_change_pages(
  change_references : Bool,
  document : PdfDocument,
  pages : ArrayView[PdfPage],
  matrices? : ArrayView[(Int, TransformMatrix)] = [],
  changes? : ArrayView[(Int, Int)] = [],
) -> PdfDocument raise PdfError {
  document.change_pages(pages, change_references~, matrices~, changes~)
}

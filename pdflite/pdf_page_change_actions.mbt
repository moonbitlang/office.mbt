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
  let output : Array[@bookmark.PdfBookmark] = Array::new(
    capacity=bookmarks.length(),
  )
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

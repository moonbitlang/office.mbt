///|
fn PdfDocument::pdf_page_transform_name_tree_destination_entries(
  self : PdfDocument,
  dests_tree : PdfObject,
  matrices : ArrayView[(Int, @geometry.TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Array[(PdfBytes, PdfObject)]? {
  let lookup = pdf_page_matrix_lookup(matrices, page_reference_numbers)
  let entries = self.read_name_tree(dests_tree)
  let output : Array[(PdfBytes, PdfObject)] = Array::new(
    capacity=entries.length(),
  )
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
    Some(output)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_name_tree_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, @geometry.TransformMatrix)],
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

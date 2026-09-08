///|
fn PdfDocument::pdf_page_transform_catalog_destinations_object(
  self : PdfDocument,
  dests : @syntax.PdfObject,
  matrices : ArrayView[(Int, @geometry.TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> @syntax.PdfObject? {
  let lookup = pdf_page_matrix_lookup(matrices, page_reference_numbers)
  match dests {
    PdfDictionary(entries) => {
      let output : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
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
) -> (@syntax.PdfObject, Bool)? {
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
  key : @core.PdfName,
  value : @syntax.PdfObject,
  catalog : @syntax.PdfObject,
  uses_trailer_root : Bool,
) -> Unit raise @core.PdfError {
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
  matrices : ArrayView[(Int, @geometry.TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise @core.PdfError {
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

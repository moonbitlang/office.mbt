///|
fn PdfDocument::pdf_page_destination_was_nulled(
  self : PdfDocument,
  destination : PdfObject,
) -> Bool {
  match self.direct(destination) {
    PdfArray(items) if items.length() > 0 =>
      match items[0] {
        PdfNull => true
        PdfIndirect(number) => self.lookup_object_or_null(number) == PdfNull
        _ => false
      }
    _ => false
  }
}

///|
fn PdfDocument::pdf_page_live_destinations(
  self : PdfDocument,
  dests_tree : PdfObject,
) -> Array[(PdfBytes, PdfObject)] {
  let entries = self.read_name_tree(dests_tree)
  let output : Array[(PdfBytes, PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    let (_, destination) = entry
    if !self.pdf_page_destination_was_nulled(destination) {
      output.push(entry)
    }
  }
  output
}

///|
fn PdfDocument::pdf_page_live_catalog_destinations(
  self : PdfDocument,
  dests : PdfObject,
) -> PdfObject {
  match dests {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (_, destination) = entry
        if !self.pdf_page_destination_was_nulled(destination) {
          output.push(entry)
        }
      }
      PdfDictionary(output)
    }
    _ => dests
  }
}

///|
fn PdfDocument::pdf_page_fixup_catalog_destinations(
  self : PdfDocument,
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_dests_key()) {
        Some(PdfIndirect(dests_number)) =>
          self.add_object_given_number(
            dests_number,
            self.pdf_page_live_catalog_destinations(
              self.lookup_object_or_null(dests_number),
            ),
          )
        Some(dests) =>
          self.pdf_page_replace_active_catalog_entry(
            pdf_page_dests_key(),
            self.pdf_page_live_catalog_destinations(dests),
            root_object,
            uses_trailer_root,
          )
        None => ()
      }
    None => ()
  }
}

///|
fn PdfDocument::pdf_page_fixup_destination_name_tree(
  self : PdfDocument,
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_names_key()) {
        Some(PdfIndirect(names_number)) => {
          let names_object = self.lookup_object_or_null(names_number)
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              self.add_object_given_number(
                names_number,
                names_object.add_dict_entry(
                  pdf_page_dests_key(),
                  self.build_name_tree(
                    self.pdf_page_live_destinations(dests_tree),
                  ),
                ),
              )
            None => ()
          }
        }
        Some(PdfDictionary(_) as names_object) =>
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              self.pdf_page_replace_active_catalog_entry(
                pdf_page_names_key(),
                names_object.add_dict_entry(
                  pdf_page_dests_key(),
                  self.build_name_tree(
                    self.pdf_page_live_destinations(dests_tree),
                  ),
                ),
                root_object,
                uses_trailer_root,
              )
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

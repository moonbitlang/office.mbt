///|
fn pdf_merge_acroforms(
  documents : ArrayView[PdfDocument],
) -> PdfObject? raise PdfError {
  let forms : Array[Array[(PdfName, PdfObject)]] = []
  for document in documents {
    match document.pdf_merge_catalog_entry(pdf_merge_acroform_key()) {
      Some(PdfDictionary(form_entries)) => forms.push(form_entries)
      _ => ()
    }
  }
  if forms.length() == 0 {
    None
  } else {
    let fields : Array[PdfObject] = []
    let builder = pdf_merge_dictionary_builder()
    for form_entries in forms {
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
          builder.add_entry(key, value)
        }
      }
    }
    Some(
      PdfDictionary(builder.entries).add_dict_entry(
        pdf_merge_fields_key(),
        PdfArray(fields),
      ),
    )
  }
}

///|
fn pdf_merge_optional_content(
  documents : ArrayView[PdfDocument],
) -> PdfOptionalContent? {
  pdf_optional_content_merge(documents) catch {
    _ => None
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
fn PdfDocument::pdf_merge_open_action_destination(
  self : PdfDocument,
  open_action : PdfObject,
) -> PdfDestination raise PdfError {
  match self.direct(open_action) {
    PdfArray(_) as destination =>
      self.read_destination(destination, shallow=true)
    PdfDictionary(_) as action => DestAction(action)
    _ => DestNull
  }
}

///|
fn PdfDocument::pdf_merge_open_action_target(
  self : PdfDocument,
  open_action : PdfObject,
) -> PdfDestination raise PdfError {
  match self.direct(open_action) {
    PdfArray(_) as destination =>
      self.read_destination(destination, shallow=true)
    PdfDictionary(_) as action => self.read_destination(action, shallow=true)
    _ => DestNull
  }
}

///|
fn pdf_merge_destination_needs_named_retention(
  destination : PdfDestination,
) -> Bool {
  match destination {
    DestNamed(_) | DestString(_) => true
    _ => false
  }
}

///|
fn PdfDocument::pdf_merge_open_action(
  self : PdfDocument,
  retain_named_destinations : Bool,
) -> PdfObject? raise PdfError {
  match self.pdf_merge_catalog_entry(pdf_merge_open_action_key()) {
    Some(open_action) => {
      let target = self.pdf_merge_open_action_target(open_action)
      let destination = self.pdf_merge_open_action_destination(open_action)
      if !retain_named_destinations &&
        pdf_merge_destination_needs_named_retention(target) {
        None
      } else if self.page_number_of_target(destination) > 0 {
        Some(open_action)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn pdf_merge_open_action(
  documents : ArrayView[PdfDocument],
  retain_named_destinations : Bool,
  destination_name_changes : ArrayView[Array[(PdfBytes, PdfBytes)]],
  all_destination_name_changes : ArrayView[(PdfBytes, PdfBytes)],
  catalog_destination_name_changes : ArrayView[Array[(PdfName, PdfName)]],
  all_catalog_destination_name_changes : ArrayView[(PdfName, PdfName)],
) -> PdfObject? raise PdfError {
  for i in 0..<documents.length() {
    let document = documents[i]
    let candidate = document.pdf_merge_open_action(retain_named_destinations) catch {
      _ => None
    }
    match candidate {
      Some(open_action) => {
        let name_lookup = pdf_merge_destination_name_lookup(
          destination_name_changes[i],
          all_destination_name_changes,
        )
        let catalog_name_lookup = pdf_merge_catalog_destination_name_lookup(
          catalog_destination_name_changes[i],
          all_catalog_destination_name_changes,
        )
        break Some(
          pdf_merge_rewrite_destination_callsite_object(
            open_action, name_lookup, catalog_name_lookup,
          ),
        )
      }
      None => ()
    }
  } nobreak {
    None
  }
}

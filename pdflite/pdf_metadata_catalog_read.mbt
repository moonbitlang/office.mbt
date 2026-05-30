///|
/// Return a catalog item in cpdf's text-reporting form.
pub fn PdfDocument::catalog_item(self : PdfDocument, key : PdfName) -> String {
  try self.catalog() catch {
    _ => ""
  } noraise {
    catalog =>
      match self.lookup_direct(key, catalog) {
        Some(PdfNameObject(name)) =>
          pdf_metadata_name_string(name) catch {
            _ => ""
          }
        Some(PdfDictionary(_)) => "True"
        _ => ""
      }
  }
}

///|
/// Return a catalog item for a cpdf-style slash-prefixed string key.
pub fn PdfDocument::catalog_item_string(
  self : PdfDocument,
  key : String,
) -> String {
  self.catalog_item(pdf_metadata_source_key_name(key))
}

///|
/// Return a viewer-preference item in cpdf's text-reporting form.
pub fn PdfDocument::viewer_preference_item(
  self : PdfDocument,
  key : PdfName,
) -> String {
  try self.catalog() catch {
    _ => ""
  } noraise {
    catalog =>
      match self.lookup_direct(pdf_metadata_viewer_preferences(), catalog) {
        Some(preferences) =>
          match self.lookup_direct(key, preferences) {
            Some(PdfNameObject(name)) =>
              pdf_metadata_name_string(name) catch {
                _ => ""
              }
            Some(PdfBoolean(value)) => if value { "true" } else { "false" }
            _ => ""
          }
        None => ""
      }
  }
}

///|
/// Return a viewer-preference item for a cpdf-style slash-prefixed string key.
pub fn PdfDocument::viewer_preference_item_string(
  self : PdfDocument,
  key : String,
) -> String {
  self.viewer_preference_item(pdf_metadata_source_key_name(key))
}

///|
/// Return a `/MarkInfo` boolean item, or false when absent/malformed.
pub fn PdfDocument::mark_info_item(self : PdfDocument, key : PdfName) -> Bool {
  try self.catalog() catch {
    _ => false
  } noraise {
    catalog =>
      match self.lookup_direct(pdf_metadata_mark_info(), catalog) {
        Some(mark_info) =>
          match self.lookup_direct(key, mark_info) {
            Some(PdfBoolean(value)) => value
            _ => false
          }
        None => false
      }
  }
}

///|
/// Return true when the catalog contains an AcroForm XFA entry.
pub fn PdfDocument::is_xfa(self : PdfDocument) -> Bool {
  self.lookup_chain(self.trailer_dict(), [
    pdf_metadata_root(),
    pdf_metadata_acroform(),
    pdf_metadata_xfa(),
  ]) !=
  None
}

///|
fn PdfDocument::pdf_metadata_page_number_for_reference(
  self : PdfDocument,
  reference : Int,
) -> Int? raise PdfError {
  let page_numbers = self.page_reference_numbers()
  for index in 0..<page_numbers.length() {
    if page_numbers[index] == reference {
      break Some(index + 1)
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_metadata_rewrite_open_action_page(
  self : PdfDocument,
  action : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match action {
    PdfArray([PdfIndirect(reference), .. rest]) =>
      match self.pdf_metadata_page_number_for_reference(reference) {
        Some(page_number) => PdfArray([PdfInteger(page_number), ..rest])
        None => action
      }
    _ => action
  }
}

///|
/// Return the catalog `/OpenAction` in cpdf's reporting form.
///
/// Destination arrays beginning with a page indirect reference are rewritten
/// to one-based page numbers. For GoTo action dictionaries with `/D`, the
/// destination is returned; other action objects are returned unchanged.
pub fn PdfDocument::open_action(
  self : PdfDocument,
) -> @syntax.PdfObject raise PdfError {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_metadata_root(),
      pdf_metadata_open_action(),
    ]) {
    Some(PdfArray(_) as action) =>
      self.pdf_metadata_rewrite_open_action_page(action)
    Some(PdfDictionary(_) as action) =>
      match self.lookup_direct(pdf_metadata_d(), action) {
        Some(PdfArray(_) as destination) =>
          self.pdf_metadata_rewrite_open_action_page(destination)
        _ => action
      }
    Some(action) => action
    None => PdfNull
  }
}

///|
/// Return the catalog `/OpenAction` as cpdf-style JSON bytes.
pub fn PdfDocument::open_action_json_blob(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  @utf8.encode(
    self
    .pdf_util_json_of_object(
      self.open_action(),
      true,
      false,
      false,
      false,
      false,
    )
    .stringify(),
  )
}

///|
/// Return the catalog `/OpenAction` as cpdf-style PDF syntax.
pub fn PdfDocument::open_action_string(
  self : PdfDocument,
) -> String raise PdfError {
  match self.open_action() {
    PdfNull => ""
    action =>
      @ascii.decode(pdf_write_object(action)) catch {
        _ => raise InvalidUTF8
      }
  }
}

///|
/// Set or replace one `/ViewerPreferences` dictionary entry.
pub fn PdfDocument::set_viewer_preference(
  self : PdfDocument,
  key : @core.PdfName,
  value : @syntax.PdfObject,
  version : Int,
  keep_version? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise @core.PdfError {
    let preferences = match
      document.lookup_direct(pdf_metadata_viewer_preferences(), catalog) {
      Some(dictionary) => dictionary
      None => PdfDictionary([])
    }
    catalog.add_dict_entry(
      pdf_metadata_viewer_preferences(),
      preferences.add_dict_entry(key, value),
    )
  })
  document.pdf_metadata_bump_minor(version, keep_version)
  document
}

///|
/// Set one `/ViewerPreferences` entry from cpdf's string-key tuple form.
pub fn PdfDocument::set_viewer_preference_string(
  self : PdfDocument,
  entry : (String, @syntax.PdfObject, Int),
) -> PdfDocument raise @core.PdfError {
  self.set_viewer_preference(
    pdf_metadata_source_key_name(entry.0),
    entry.1,
    entry.2,
  )
}

///|
/// Set the catalog `/PageLayout` value using a name without the leading slash.
pub fn PdfDocument::set_page_layout(
  self : PdfDocument,
  layout : String,
) -> PdfDocument raise @core.PdfError {
  let name = pdf_metadata_known_name(
    layout,
    [
      "SinglePage", "OneColumn", "TwoColumnLeft", "TwoColumnRight", "TwoPageLeft",
      "TwoPageRight",
    ],
    "Unknown page layout: ",
  )
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise @core.PdfError {
    catalog.add_dict_entry(pdf_metadata_page_layout(), PdfNameObject(name))
  })
  document
}

///|
/// Set the catalog `/PageMode` value using a name without the leading slash.
pub fn PdfDocument::set_page_mode(
  self : PdfDocument,
  mode : String,
) -> PdfDocument raise @core.PdfError {
  let name = pdf_metadata_known_name(
    mode,
    [
      "UseNone", "UseOutlines", "UseThumbs", "FullScreen", "UseOC", "UseAttachments",
    ],
    "Unknown page mode: ",
  )
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise @core.PdfError {
    catalog.add_dict_entry(pdf_metadata_page_mode(), PdfNameObject(name))
  })
  document
}

///|
/// Set `/ViewerPreferences /NonFullScreenPageMode`.
pub fn PdfDocument::set_non_full_screen_page_mode(
  self : PdfDocument,
  mode : String,
) -> PdfDocument raise @core.PdfError {
  let name = pdf_metadata_known_name(
    mode,
    ["UseNone", "UseOutlines", "UseThumbs", "UseOC", "UseAttachments"],
    "Unknown non full screen page mode: ",
  )
  self.set_viewer_preference(
    pdf_metadata_non_full_screen_page_mode(),
    PdfNameObject(name),
    2,
  )
}

///|
fn PdfDocument::pdf_metadata_rewrite_destination_page(
  self : PdfDocument,
  destination : @syntax.PdfObject,
) -> @syntax.PdfObject raise @core.PdfError {
  match destination {
    PdfArray(values) =>
      match values {
        [PdfInteger(page_number), .. rest] => {
          let page_numbers = self.page_reference_numbers()
          if page_number < 1 || page_number > page_numbers.length() {
            raise BadPageSpecification(page_number.to_string())
          }
          PdfArray([PdfIndirect(page_numbers[page_number - 1]), ..rest])
        }
        _ => destination
      }
    _ => destination
  }
}

///|
fn pdf_metadata_parse_open_action_destination(
  destination : String,
) -> @syntax.PdfObject raise @core.PdfError {
  let parsed : Result[@syntax.PdfObject, Error] = try? @syntax.pdf_parse_object_from_bytes(
    @ascii.encode(destination),
  )
  match parsed {
    Ok(object) =>
      match object {
        PdfArray([PdfInteger(_), ..]) => object
        _ => raise BadNumberArgument("Bad destination syntax")
      }
    Err(_) => raise BadNumberArgument("Bad destination syntax")
  }
}

///|
/// Set the catalog `/OpenAction` to a GoTo action.
///
/// `page_number` is one-based. When `destination` is supplied and starts with a
/// page number integer, that integer is rewritten to the corresponding page
/// indirect reference.
pub fn PdfDocument::set_open_action(
  self : PdfDocument,
  page_number : Int,
  fit? : Bool = true,
  destination? : @syntax.PdfObject? = None,
) -> PdfDocument raise @core.PdfError {
  let page_numbers = self.page_reference_numbers()
  if page_number < 1 || page_number > page_numbers.length() {
    raise BadPageSpecification(page_number.to_string())
  }
  let destination = match destination {
    Some(value) => self.pdf_metadata_rewrite_destination_page(value)
    None =>
      if fit {
        PdfArray([
          PdfIndirect(page_numbers[page_number - 1]),
          PdfNameObject(pdf_metadata_fit()),
        ])
      } else {
        PdfArray([
          PdfIndirect(page_numbers[page_number - 1]),
          PdfNameObject(pdf_metadata_xyz()),
          PdfNull,
          PdfNull,
          PdfNull,
        ])
      }
  }
  let open_action = @syntax.PdfDictionary([
    (pdf_metadata_d(), destination),
    (pdf_metadata_s(), PdfNameObject(pdf_metadata_goto())),
  ])
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise @core.PdfError {
    catalog.add_dict_entry(pdf_metadata_open_action(), open_action)
  })
  document
}

///|
/// Set the catalog `/OpenAction` from cpdf-style PDF destination syntax.
pub fn PdfDocument::set_open_action_string_destination(
  self : PdfDocument,
  page_number : Int,
  fit? : Bool = true,
  destination? : String? = None,
) -> PdfDocument raise @core.PdfError {
  let destination_object = match destination {
    Some(value) => Some(pdf_metadata_parse_open_action_destination(value))
    None => None
  }
  self.set_open_action(page_number, fit~, destination=destination_object)
}

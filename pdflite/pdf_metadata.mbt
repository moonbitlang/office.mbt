///|
fn pdf_metadata_bool_string(value : Bool) -> String {
  if value {
    "True"
  } else {
    "False"
  }
}

///|
fn pdf_metadata_ascii_codepoints(bytes : BytesView) -> PdfBytes raise PdfError {
  let codepoints = pdf_codepoints_of_pdfdocstring(bytes)
  let mut output_length = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      output_length += 1
    }
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      output[position] = pdf_byte_of_int(codepoint)
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
/// Encode a PDF string for metadata/reporting output.
pub fn pdf_metadata_encode_output(
  encoding : PdfMetadataEncoding,
  bytes : BytesView,
) -> PdfBytes raise PdfError {
  match encoding {
    PdfMetadataRaw => bytes.to_owned()
    PdfMetadataUTF8 => pdf_utf8_of_pdfdocstring(bytes)
    PdfMetadataStripped => pdf_metadata_ascii_codepoints(bytes)
  }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `encode_output`.
pub fn pdf_encode_output(
  encoding : PdfMetadataEncoding,
  bytes : BytesView,
) -> PdfBytes raise PdfError {
  pdf_metadata_encode_output(encoding, bytes)
}

///|
fn PdfDocument::pdf_metadata_bump_minor(
  self : PdfDocument,
  version : Int,
  keep_version : Bool,
) -> Unit {
  if self.major == 1 && !keep_version && self.minor < version {
    self.minor = version
  }
}

///|
fn PdfDocument::pdf_metadata_replace_catalog(
  self : PdfDocument,
  catalog : PdfObject,
) -> Unit raise PdfError {
  let root_number = self.add_object(catalog)
  self.set_root(root_number)
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_metadata_root(), PdfIndirect(root_number)),
  )
}

///|
fn PdfDocument::pdf_metadata_update_catalog(
  self : PdfDocument,
  update : (PdfObject) -> PdfObject raise PdfError,
) -> Unit raise PdfError {
  let catalog = self.catalog()
  self.pdf_metadata_replace_catalog(update(catalog))
}

///|
fn pdf_metadata_name_string(name : PdfName) -> String raise PdfError {
  let bytes = name.bytes()
  let start = if bytes.length() > 0 && bytes[0].to_int() == 47 { 1 } else { 0 }
  @ascii.decode(bytes[start:]) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_metadata_known_name(
  value : String,
  allowed : ArrayView[String],
  error_prefix : String,
) -> PdfName raise PdfError {
  for allowed_value in allowed {
    if value == allowed_value {
      break pdf_metadata_name("/" + value)
    }
  } nobreak {
    raise BadNumberArgument(error_prefix + value)
  }
}

///|
/// Copy the trailer `/ID` from `source` onto this document.
///
/// The original document is left unchanged. When `keep_version` is false, PDF
/// 1.x outputs are bumped to at least 1.1, matching cpdf.
pub fn PdfDocument::copy_id_from(
  self : PdfDocument,
  source : PdfDocument,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  match source.lookup_direct(pdf_metadata_id(), source.trailer_dict()) {
    Some(id) => {
      document.set_trailer_dict(
        document.trailer_dict().add_dict_entry(pdf_metadata_id(), id),
      )
      document.pdf_metadata_bump_minor(1, keep_version)
      document
    }
    None => document
  }
}

///|
/// Set or replace one `/Info` dictionary entry.
pub fn PdfDocument::set_info_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  version : Int,
  keep_version? : Bool = false,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = if xmp_just_set {
    self
  } else {
    let document = self.copy()
    let info = match
      document.lookup_direct(pdf_metadata_info(), document.trailer_dict()) {
      Some(dictionary) => dictionary
      None => PdfDictionary([])
    }
    let info_number = document.add_object(info.add_dict_entry(key, value))
    document.set_trailer_dict(
      document
      .trailer_dict()
      .add_dict_entry(pdf_metadata_info(), PdfIndirect(info_number)),
    )
    document.pdf_metadata_bump_minor(version, keep_version)
    document
  }
  if !xmp_also {
    document
  } else {
    match document.metadata() {
      None => document
      Some(metadata) => {
        let (changes, replacement) = pdf_metadata_info_xmp_changes(key, value)
        let mut updated = metadata
        for change in changes {
          updated = pdf_metadata_rewrite_xmp_field(
            updated,
            change.0,
            pdf_metadata_namespace_fallback_prefix(change.0),
            change.1,
            replacement,
          )
        }
        document.set_metadata_from_bytes(updated, keep_version=true)
      }
    }
  }
}

///|
/// Set or replace one `/Info` entry from cpdf's string-key tuple form.
pub fn PdfDocument::set_info_entry_string(
  self : PdfDocument,
  entry : (String, PdfObject, Int),
  keep_version? : Bool = false,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  self.set_info_entry(
    pdf_metadata_source_key_name(entry.0),
    entry.1,
    entry.2,
    keep_version~,
    xmp_also~,
    xmp_just_set~,
  )
}

///|
/// Return one `/Info` dictionary entry as a UTF-8 string.
pub fn PdfDocument::info_utf8(self : PdfDocument, key : PdfName) -> String {
  let info = match
    self.lookup_direct(pdf_metadata_info(), self.trailer_dict()) {
    Some(dictionary) => dictionary
    None => PdfDictionary([])
  }
  match self.lookup_direct(key, info) {
    Some(PdfString(bytes)) =>
      @utf8.decode(pdf_utf8_of_pdfdocstring(bytes)) catch {
        _ => ""
      }
    Some(PdfBoolean(value)) => pdf_metadata_bool_string(value)
    _ => if key == pdf_metadata_trapped() { "False" } else { "" }
  }
}

///|
/// Return one cpdf-style slash-prefixed string-key `/Info` entry as UTF-8.
pub fn PdfDocument::info_utf8_string(
  self : PdfDocument,
  key : String,
) -> String {
  self.info_utf8(pdf_metadata_source_key_name(key))
}

///|
/// Set or replace one `/ViewerPreferences` dictionary entry.
pub fn PdfDocument::set_viewer_preference(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  version : Int,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
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
  entry : (String, PdfObject, Int),
) -> PdfDocument raise PdfError {
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
) -> PdfDocument raise PdfError {
  let name = pdf_metadata_known_name(
    layout,
    [
      "SinglePage", "OneColumn", "TwoColumnLeft", "TwoColumnRight", "TwoPageLeft",
      "TwoPageRight",
    ],
    "Unknown page layout: ",
  )
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(pdf_metadata_page_layout(), PdfNameObject(name))
  })
  document
}

///|
/// Set the catalog `/PageMode` value using a name without the leading slash.
pub fn PdfDocument::set_page_mode(
  self : PdfDocument,
  mode : String,
) -> PdfDocument raise PdfError {
  let name = pdf_metadata_known_name(
    mode,
    [
      "UseNone", "UseOutlines", "UseThumbs", "FullScreen", "UseOC", "UseAttachments",
    ],
    "Unknown page mode: ",
  )
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(pdf_metadata_page_mode(), PdfNameObject(name))
  })
  document
}

///|
/// Set `/ViewerPreferences /NonFullScreenPageMode`.
pub fn PdfDocument::set_non_full_screen_page_mode(
  self : PdfDocument,
  mode : String,
) -> PdfDocument raise PdfError {
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
  destination : PdfObject,
) -> PdfObject raise PdfError {
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
) -> PdfObject raise PdfError {
  let parsed : Result[PdfObject, Error] = try? pdf_parse_object_from_bytes(
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
  destination? : PdfObject? = None,
) -> PdfDocument raise PdfError {
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
  let open_action = PdfDictionary([
    (pdf_metadata_d(), destination),
    (pdf_metadata_s(), PdfNameObject(pdf_metadata_goto())),
  ])
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
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
) -> PdfDocument raise PdfError {
  let destination_object = match destination {
    Some(value) => Some(pdf_metadata_parse_open_action_destination(value))
    None => None
  }
  self.set_open_action(page_number, fit~, destination=destination_object)
}

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
  action : PdfObject,
) -> PdfObject raise PdfError {
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
pub fn PdfDocument::open_action(self : PdfDocument) -> PdfObject raise PdfError {
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

///|
fn pdf_metadata_xml_value_of_object(value : PdfObject) -> String raise PdfError {
  match value {
    PdfString(bytes) =>
      @utf8.decode(pdf_utf8_of_pdfdocstring(bytes)) catch {
        _ => raise InvalidUTF8
      }
    PdfBoolean(true) => "True"
    PdfBoolean(false) => "False"
    _ => raise BadNumberArgument("set_pdf_info_xml: not a string")
  }
}

///|
fn pdf_metadata_xmp_date_of_object(value : PdfObject) -> String raise PdfError {
  match value {
    PdfString(bytes) =>
      pdf_metadata_xmp_date(
        @ascii.decode(bytes) catch {
          _ => raise InvalidUTF8
        },
      )
    _ => raise BadNumberArgument("xmp_date not a string")
  }
}

///|
fn pdf_metadata_info_xmp_changes(
  key : PdfName,
  value : PdfObject,
) -> (Array[(String, String)], String) raise PdfError {
  match pdf_metadata_name_with_slash(key) {
    Some("/Producer") =>
      (
        [(pdf_metadata_adobe_namespace, "Producer")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Creator") =>
      (
        [
          (pdf_metadata_adobe_namespace, "Creator"),
          (pdf_metadata_xmp_namespace, "CreatorTool"),
          (pdf_metadata_dc_namespace, "creator"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Author") =>
      (
        [(pdf_metadata_adobe_namespace, "Author")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Title") =>
      (
        [
          (pdf_metadata_adobe_namespace, "Title"),
          (pdf_metadata_dc_namespace, "title"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Subject") =>
      (
        [
          (pdf_metadata_adobe_namespace, "Subject"),
          (pdf_metadata_dc_namespace, "subject"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Keywords") =>
      (
        [(pdf_metadata_adobe_namespace, "Keywords")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/CreationDate") =>
      (
        [
          (pdf_metadata_adobe_namespace, "CreationDate"),
          (pdf_metadata_xmp_namespace, "CreateDate"),
        ],
        pdf_metadata_xmp_date_of_object(value),
      )
    Some("/ModDate") =>
      (
        [
          (pdf_metadata_adobe_namespace, "ModDate"),
          (pdf_metadata_xmp_namespace, "ModifyDate"),
        ],
        pdf_metadata_xmp_date_of_object(value),
      )
    Some("/Trapped") =>
      (
        [(pdf_metadata_adobe_namespace, "Trapped")],
        pdf_metadata_xml_value_of_object(value),
      )
    _ => raise BadNumberArgument("Unknown call to set_pdf_info")
  }
}

///|
/// Return the catalog `/Lang` value, if present.
pub fn PdfDocument::language(self : PdfDocument) -> PdfBytes? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_metadata_root(),
      pdf_metadata_lang(),
    ]) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
}

///|
/// Return the catalog `/Lang` value as text for cpdf-style string APIs.
pub fn PdfDocument::language_string(self : PdfDocument) -> String? {
  match self.language() {
    Some(value) => Some(@utf8.decode_lossy(value))
    None => None
  }
}

///|
/// Set the catalog `/Lang` value.
pub fn PdfDocument::set_language(
  self : PdfDocument,
  language : BytesView,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(pdf_metadata_lang(), PdfString(language.to_owned()))
  })
  document
}

///|
/// Set the catalog `/Lang` value from a cpdf-style string.
pub fn PdfDocument::set_language_string(
  self : PdfDocument,
  language : String,
) -> PdfDocument raise PdfError {
  self.set_language(@utf8.encode(language))
}

///|
fn pdf_metadata_stream(data : BytesView) -> PdfObject {
  pdf_stream(
    PdfDictionary([
      (pdf_metadata_length(), PdfInteger(data.length())),
      (pdf_metadata_type(), PdfNameObject(pdf_metadata_metadata())),
      (pdf_metadata_subtype(), PdfNameObject(pdf_metadata_xml())),
    ]),
    StreamGot(data.to_owned()),
  )
}

///|
/// Set the catalog metadata XML stream from in-memory bytes.
pub fn PdfDocument::set_metadata_from_bytes(
  self : PdfDocument,
  data : BytesView,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let metadata_number = document.add_object(pdf_metadata_stream(data))
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(
      pdf_metadata_metadata(),
      PdfIndirect(metadata_number),
    )
  })
  document.pdf_metadata_bump_minor(4, keep_version)
  document
}

///|
/// Set the XMP `/Metadata` stream's `xmp:MetadataDate` field.
pub fn PdfDocument::set_metadata_date(
  self : PdfDocument,
  date : String,
) -> PdfDocument raise PdfError {
  match self.metadata() {
    None => self
    Some(metadata) => {
      let value = if date == "now" {
        pdf_metadata_xmp_date(pdf_metadata_expand_date(date))
      } else {
        date
      }
      let updated = pdf_metadata_rewrite_xmp_field(
        metadata, pdf_metadata_xmp_namespace, "xmp", "MetadataDate", value,
      )
      self.set_metadata_from_bytes(updated, keep_version=true)
    }
  }
}

///|
/// Create a fresh XMP metadata stream from the document `/Info` dictionary.
pub fn PdfDocument::create_metadata(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let mut xmp = pdf_metadata_xmp_template
  for replacement in self.pdf_metadata_template_replacements() {
    xmp = pdf_metadata_replace_all(xmp, replacement.0, replacement.1)
  }
  self.set_metadata_from_bytes(@utf8.encode(xmp))
}

///|
/// Extract the catalog metadata XML stream, decoding supported stream filters.
pub fn PdfDocument::metadata(self : PdfDocument) -> PdfBytes? raise PdfError {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_metadata_root(),
      pdf_metadata_metadata(),
    ]) {
    Some(PdfStreamObject(_) as stream) => {
      let decoded = self.pdf_decode_stream(stream)
      Some(decoded.stream_bytes())
    }
    _ => None
  }
}

///|
/// Remove the catalog `/Metadata` entry.
pub fn PdfDocument::remove_metadata(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.remove_dict_entry(pdf_metadata_metadata())
  })
  document
}

///|
/// Remove the catalog metadata entry and every parsed object whose `/Type` is
/// `/Metadata`.
pub fn PdfDocument::remove_all_metadata(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.remove_metadata()
  let to_remove : Array[Int] = []
  for entry in document.parsed_object_entries() {
    match document.lookup_direct(pdf_metadata_type(), entry.2) {
      Some(PdfNameObject(name)) if name == pdf_metadata_metadata() =>
        to_remove.push(entry.0)
      _ => ()
    }
  }
  for number in to_remove {
    document.remove_object(number)
  }
  document
}

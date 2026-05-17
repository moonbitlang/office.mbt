///|
pub(all) enum PdfMetadataEncoding {
  PdfMetadataRaw
  PdfMetadataUTF8
  PdfMetadataStripped
} derive(Debug, Eq, ToJson)

///|
fn pdf_metadata_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_metadata_root_name : PdfName = pdf_metadata_name("/Root")

///|
fn pdf_metadata_root() -> PdfName {
  pdf_metadata_root_name
}

///|
let pdf_metadata_info_name : PdfName = pdf_metadata_name("/Info")

///|
fn pdf_metadata_info() -> PdfName {
  pdf_metadata_info_name
}

///|
let pdf_metadata_id_name : PdfName = pdf_metadata_name("/ID")

///|
fn pdf_metadata_id() -> PdfName {
  pdf_metadata_id_name
}

///|
let pdf_metadata_metadata_name : PdfName = pdf_metadata_name("/Metadata")

///|
fn pdf_metadata_metadata() -> PdfName {
  pdf_metadata_metadata_name
}

///|
let pdf_metadata_type_name : PdfName = pdf_metadata_name("/Type")

///|
fn pdf_metadata_type() -> PdfName {
  pdf_metadata_type_name
}

///|
let pdf_metadata_subtype_name : PdfName = pdf_metadata_name("/Subtype")

///|
fn pdf_metadata_subtype() -> PdfName {
  pdf_metadata_subtype_name
}

///|
let pdf_metadata_xml_name : PdfName = pdf_metadata_name("/XML")

///|
fn pdf_metadata_xml() -> PdfName {
  pdf_metadata_xml_name
}

///|
let pdf_metadata_length_name : PdfName = pdf_metadata_name("/Length")

///|
fn pdf_metadata_length() -> PdfName {
  pdf_metadata_length_name
}

///|
let pdf_metadata_viewer_preferences_name : PdfName = pdf_metadata_name(
  "/ViewerPreferences",
)

///|
fn pdf_metadata_viewer_preferences() -> PdfName {
  pdf_metadata_viewer_preferences_name
}

///|
let pdf_metadata_page_layout_name : PdfName = pdf_metadata_name("/PageLayout")

///|
fn pdf_metadata_page_layout() -> PdfName {
  pdf_metadata_page_layout_name
}

///|
let pdf_metadata_page_mode_name : PdfName = pdf_metadata_name("/PageMode")

///|
fn pdf_metadata_page_mode() -> PdfName {
  pdf_metadata_page_mode_name
}

///|
let pdf_metadata_non_full_screen_page_mode_name : PdfName = pdf_metadata_name(
  "/NonFullScreenPageMode",
)

///|
fn pdf_metadata_non_full_screen_page_mode() -> PdfName {
  pdf_metadata_non_full_screen_page_mode_name
}

///|
let pdf_metadata_open_action_name : PdfName = pdf_metadata_name("/OpenAction")

///|
fn pdf_metadata_open_action() -> PdfName {
  pdf_metadata_open_action_name
}

///|
let pdf_metadata_d_name : PdfName = pdf_metadata_name("/D")

///|
fn pdf_metadata_d() -> PdfName {
  pdf_metadata_d_name
}

///|
let pdf_metadata_s_name : PdfName = pdf_metadata_name("/S")

///|
fn pdf_metadata_s() -> PdfName {
  pdf_metadata_s_name
}

///|
let pdf_metadata_goto_name : PdfName = pdf_metadata_name("/GoTo")

///|
fn pdf_metadata_goto() -> PdfName {
  pdf_metadata_goto_name
}

///|
let pdf_metadata_fit_name : PdfName = pdf_metadata_name("/Fit")

///|
fn pdf_metadata_fit() -> PdfName {
  pdf_metadata_fit_name
}

///|
let pdf_metadata_xyz_name : PdfName = pdf_metadata_name("/XYZ")

///|
fn pdf_metadata_xyz() -> PdfName {
  pdf_metadata_xyz_name
}

///|
let pdf_metadata_lang_name : PdfName = pdf_metadata_name("/Lang")

///|
fn pdf_metadata_lang() -> PdfName {
  pdf_metadata_lang_name
}

///|
let pdf_metadata_trapped_name : PdfName = pdf_metadata_name("/Trapped")

///|
fn pdf_metadata_trapped() -> PdfName {
  pdf_metadata_trapped_name
}

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
  let output : Array[Byte] = []
  for codepoint in pdf_codepoints_of_pdfdocstring(bytes) {
    if codepoint <= 127 {
      output.push(pdf_byte_of_int(codepoint))
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
///
/// This core metadata slice updates the document information dictionary only;
/// XMP synchronization is intentionally left to a later XML/XMP slice.
pub fn PdfDocument::set_info_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  version : Int,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
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

///|
/// Compatibility wrapper for `PdfDocument::copy_id_from`.
pub fn pdf_copy_id(
  keep_version : Bool,
  copy_from : PdfDocument,
  copy_to : PdfDocument,
) -> PdfDocument raise PdfError {
  copy_to.copy_id_from(copy_from, keep_version~)
}

///|
/// Compatibility wrapper for `PdfDocument::set_info_entry`.
pub fn pdf_set_pdf_info(
  key : PdfName,
  value : PdfObject,
  version : Int,
  document : PdfDocument,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
  document.set_info_entry(key, value, version, keep_version~)
}

///|
/// Compatibility wrapper for `PdfDocument::info_utf8`.
pub fn pdf_get_info_utf8(document : PdfDocument, key : PdfName) -> String {
  document.info_utf8(key)
}

///|
/// Compatibility wrapper for `PdfDocument::set_viewer_preference`.
pub fn pdf_set_viewer_preference(
  key : PdfName,
  value : PdfObject,
  version : Int,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.set_viewer_preference(key, value, version)
}

///|
/// Compatibility wrapper for `PdfDocument::set_metadata_from_bytes`.
pub fn pdf_set_metadata_from_bytes(
  keep_version : Bool,
  data : BytesView,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.set_metadata_from_bytes(data, keep_version~)
}

///|
/// Compatibility wrapper for `PdfDocument::metadata`.
pub fn pdf_get_metadata(document : PdfDocument) -> PdfBytes? raise PdfError {
  document.metadata()
}

///|
/// Compatibility wrapper for `PdfDocument::remove_metadata`.
pub fn pdf_remove_metadata(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_metadata()
}

///|
/// Compatibility wrapper for `PdfDocument::remove_all_metadata`.
pub fn pdf_remove_all_metadata(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_all_metadata()
}

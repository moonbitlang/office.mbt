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
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  document.set_info_entry(
    key,
    value,
    version,
    keep_version~,
    xmp_also~,
    xmp_just_set~,
  )
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key tuple form.
pub fn pdf_set_pdf_info_cpdf_order(
  entry : (String, PdfObject, Int),
  document : PdfDocument,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  document.set_info_entry_string(entry, xmp_also~, xmp_just_set~)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key tuple form.
pub fn pdf_set_pdf_info_string(
  entry : (String, PdfObject, Int),
  document : PdfDocument,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_set_pdf_info_cpdf_order(entry, document, xmp_also~, xmp_just_set~)
}

///|
/// Compatibility wrapper for `PdfDocument::info_utf8`.
pub fn pdf_get_info_utf8(document : PdfDocument, key : PdfName) -> String {
  document.info_utf8(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key `get_info_utf8`.
pub fn pdf_get_info_utf8_string(document : PdfDocument, key : String) -> String {
  document.info_utf8_string(key)
}

///|
/// Compatibility wrapper for `PdfDocument::xmp_info`.
pub fn pdf_get_xmp_info(document : PdfDocument, key : PdfName) -> String {
  document.xmp_info(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key `get_xmp_info`.
pub fn pdf_get_xmp_info_string(document : PdfDocument, key : String) -> String {
  document.xmp_info_string(key)
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
/// Compatibility wrapper matching cpdfmetadata's string-key tuple form.
pub fn pdf_set_viewer_preference_cpdf_order(
  entry : (String, PdfObject, Int),
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.set_viewer_preference_string(entry)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key tuple form.
pub fn pdf_set_viewer_preference_string(
  entry : (String, PdfObject, Int),
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  pdf_set_viewer_preference_cpdf_order(entry, document)
}

///|
/// Compatibility wrapper for `PdfDocument::set_page_layout`.
pub fn pdf_set_page_layout(
  document : PdfDocument,
  layout : String,
) -> PdfDocument raise PdfError {
  document.set_page_layout(layout)
}

///|
/// Compatibility wrapper for `PdfDocument::set_page_mode`.
pub fn pdf_set_page_mode(
  document : PdfDocument,
  mode : String,
) -> PdfDocument raise PdfError {
  document.set_page_mode(mode)
}

///|
/// Compatibility wrapper for `PdfDocument::set_non_full_screen_page_mode`.
pub fn pdf_set_non_full_screen_page_mode(
  document : PdfDocument,
  mode : String,
) -> PdfDocument raise PdfError {
  document.set_non_full_screen_page_mode(mode)
}

///|
/// Compatibility wrapper for `PdfDocument::set_open_action`.
pub fn pdf_set_open_action(
  document : PdfDocument,
  fit : Bool,
  page_number : Int,
  destination? : PdfObject? = None,
) -> PdfDocument raise PdfError {
  document.set_open_action(page_number, fit~, destination~)
}

///|
/// Compatibility wrapper for cpdfmetadata's string destination syntax.
pub fn pdf_set_open_action_string_destination(
  document : PdfDocument,
  fit : Bool,
  page_number : Int,
  destination? : String? = None,
) -> PdfDocument raise PdfError {
  document.set_open_action_string_destination(page_number, fit~, destination~)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string destination API.
pub fn pdf_set_open_action_cpdf_order(
  document : PdfDocument,
  fit : Bool,
  page_number : Int,
  destination? : String? = None,
) -> PdfDocument raise PdfError {
  pdf_set_open_action_string_destination(
    document,
    fit,
    page_number,
    destination~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::catalog_item`.
pub fn pdf_get_catalog_item(key : PdfName, document : PdfDocument) -> String {
  document.catalog_item(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key `get_catalog_item`.
pub fn pdf_get_catalog_item_string(
  key : String,
  document : PdfDocument,
) -> String {
  document.catalog_item_string(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's `get_catalog_item`.
pub fn pdf_get_catalog_item_cpdf_order(
  key : String,
  document : PdfDocument,
) -> String {
  document.catalog_item_string(key)
}

///|
/// Compatibility wrapper for `PdfDocument::viewer_preference_item`.
pub fn pdf_get_viewer_pref_item(
  key : PdfName,
  document : PdfDocument,
) -> String {
  document.viewer_preference_item(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key `get_viewer_pref_item`.
pub fn pdf_get_viewer_pref_item_string(
  key : String,
  document : PdfDocument,
) -> String {
  document.viewer_preference_item_string(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's `get_viewer_pref_item`.
pub fn pdf_get_viewer_pref_item_cpdf_order(
  key : String,
  document : PdfDocument,
) -> String {
  document.viewer_preference_item_string(key)
}

///|
/// Compatibility wrapper for `PdfDocument::mark_info_item`.
pub fn pdf_get_mark_info_item(key : PdfName, document : PdfDocument) -> Bool {
  document.mark_info_item(key)
}

///|
/// Compatibility wrapper for `PdfDocument::is_xfa`.
pub fn pdf_is_xfa(document : PdfDocument) -> Bool {
  document.is_xfa()
}

///|
/// Compatibility wrapper for `PdfDocument::open_action`.
pub fn pdf_get_open_action(document : PdfDocument) -> PdfObject raise PdfError {
  document.open_action()
}

///|
/// Compatibility wrapper for `PdfDocument::open_action_json_blob`.
pub fn pdf_get_open_action_json_blob(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.open_action_json_blob()
}

///|
/// Compatibility wrapper for `PdfDocument::open_action_string`.
pub fn pdf_get_open_action_string(
  document : PdfDocument,
) -> String raise PdfError {
  document.open_action_string()
}

///|
/// Compatibility wrapper for cpdf's minor-version setter.
pub fn pdf_set_version(minor : Int, document : PdfDocument) -> Unit {
  let (major, _) = document.version()
  document.set_version(major, minor)
}

///|
/// Compatibility wrapper for `PdfDocument::determine_subformats`.
pub fn pdf_determine_subformats(
  document : PdfDocument,
) -> Array[String] raise PdfError {
  document.determine_subformats()
}

///|
/// Compatibility wrapper for `PdfDocument::info_json_blob`.
pub fn pdf_output_info_json_blob(
  document : PdfDocument,
  encoding? : @metadata.PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  document.info_json_blob(encoding~, unit~)
}

///|
/// Compatibility wrapper for `PdfDocument::info_blob`.
pub fn pdf_output_info(
  document : PdfDocument,
  encoding? : @metadata.PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  document.info_blob(encoding~, unit~)
}

///|
/// Compatibility wrapper for `PdfDocument::xmp_info_json_blob`.
pub fn pdf_output_xmp_info_json_blob(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.xmp_info_json_blob()
}

///|
/// Compatibility wrapper for `PdfDocument::xmp_info_blob`.
pub fn pdf_output_xmp_info(
  document : PdfDocument,
  encoding? : @metadata.PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  ignore(encoding)
  ignore(unit)
  document.xmp_info_blob()
}

///|
/// Compatibility wrapper for `PdfDocument::language`.
pub fn pdf_language(document : PdfDocument) -> PdfBytes? {
  document.language()
}

///|
/// Compatibility wrapper returning `/Lang` as cpdf-style text.
pub fn pdf_language_string(document : PdfDocument) -> String? {
  document.language_string()
}

///|
/// Compatibility wrapper for `PdfDocument::set_language`.
pub fn pdf_set_language(
  document : PdfDocument,
  language : BytesView,
) -> PdfDocument raise PdfError {
  document.set_language(language)
}

///|
/// Compatibility wrapper setting `/Lang` from cpdf-style text.
pub fn pdf_set_language_string(
  document : PdfDocument,
  language : String,
) -> PdfDocument raise PdfError {
  document.set_language_string(language)
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
/// Return the bytes cpdfmetadata's `print_metadata` would write to stdout.
pub fn pdf_print_metadata(document : PdfDocument) -> PdfBytes raise PdfError {
  match document.metadata() {
    Some(data) => data
    None => Bytes::new(0)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::set_metadata_date`.
pub fn pdf_set_metadata_date(
  document : PdfDocument,
  date : String,
) -> PdfDocument raise PdfError {
  document.set_metadata_date(date)
}

///|
/// Compatibility wrapper for `PdfDocument::create_metadata`.
pub fn pdf_create_metadata(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.create_metadata()
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

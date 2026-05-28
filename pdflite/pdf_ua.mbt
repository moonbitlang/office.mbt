///|
/// PDF/UA subformat selector used by CamlPDF-facing creation helpers.
pub(all) enum PdfUASubformat {
  PdfUA1
  PdfUA2
} derive(Debug, Eq, ToJson)

///|
/// Parse CamlPDF's PDF/UA subformat spelling.
pub fn pdf_ua_subformat_of_string(
  text : String,
) -> PdfUASubformat raise PdfError {
  match text {
    "PDF/UA-1" => PdfUA1
    "PDF/UA-2" => PdfUA2
    _ => raise BadText
  }
}

///|
/// Source-spelled compatibility alias for cpdfua's `subformat_of_string`.
pub fn pdf_subformat_of_string(text : String) -> PdfUASubformat raise PdfError {
  pdf_ua_subformat_of_string(text)
}

///|
fn pdf_ua_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_ua_root_key_name : PdfName = pdf_ua_name("/Root")

///|
fn pdf_ua_root_key() -> PdfName {
  pdf_ua_root_key_name
}

///|
let pdf_ua_info_key_name : PdfName = pdf_ua_name("/Info")

///|
fn pdf_ua_info_key() -> PdfName {
  pdf_ua_info_key_name
}

///|
let pdf_ua_title_key_name : PdfName = pdf_ua_name("/Title")

///|
fn pdf_ua_title_key() -> PdfName {
  pdf_ua_title_key_name
}

///|
let pdf_ua_type_key_name : PdfName = pdf_ua_name("/Type")

///|
fn pdf_ua_type_key() -> PdfName {
  pdf_ua_type_key_name
}

///|
let pdf_ua_metadata_key_name : PdfName = pdf_ua_name("/Metadata")

///|
fn pdf_ua_metadata_key() -> PdfName {
  pdf_ua_metadata_key_name
}

///|
let pdf_ua_metadata_name : PdfName = pdf_ua_name("/Metadata")

///|
fn pdf_ua_metadata() -> PdfName {
  pdf_ua_metadata_name
}

///|
let pdf_ua_subtype_key_name : PdfName = pdf_ua_name("/Subtype")

///|
fn pdf_ua_subtype_key() -> PdfName {
  pdf_ua_subtype_key_name
}

///|
let pdf_ua_xml_name : PdfName = pdf_ua_name("/XML")

///|
fn pdf_ua_xml() -> PdfName {
  pdf_ua_xml_name
}

///|
let pdf_ua_length_key_name : PdfName = pdf_ua_name("/Length")

///|
fn pdf_ua_length_key() -> PdfName {
  pdf_ua_length_key_name
}

///|
let pdf_ua_struct_tree_root_key_name : PdfName = pdf_ua_name("/StructTreeRoot")

///|
fn pdf_ua_struct_tree_root_key() -> PdfName {
  pdf_ua_struct_tree_root_key_name
}

///|
fn pdf_ua_struct_tree_root() -> PdfName {
  pdf_ua_struct_tree_root_key_name
}

///|
let pdf_ua_s_key_name : PdfName = pdf_ua_name("/S")

///|
fn pdf_ua_s_key() -> PdfName {
  pdf_ua_s_key_name
}

///|
let pdf_ua_k_key_name : PdfName = pdf_ua_name("/K")

///|
fn pdf_ua_k_key() -> PdfName {
  pdf_ua_k_key_name
}

///|
let pdf_ua_pg_key_name : PdfName = pdf_ua_name("/Pg")

///|
fn pdf_ua_pg_key() -> PdfName {
  pdf_ua_pg_key_name
}

///|
let pdf_ua_rolemap_key_name : PdfName = pdf_ua_name("/RoleMap")

///|
fn pdf_ua_rolemap_key() -> PdfName {
  pdf_ua_rolemap_key_name
}

///|
let pdf_ua_empty_name_value : PdfName = pdf_ua_name("")

///|
fn pdf_ua_empty_name() -> PdfName {
  pdf_ua_empty_name_value
}

///|
let pdf_ua_stm_key_name : PdfName = pdf_ua_name("/Stm")

///|
fn pdf_ua_stm_key() -> PdfName {
  pdf_ua_stm_key_name
}

///|
let pdf_ua_stm_own_key_name : PdfName = pdf_ua_name("/StmOwn")

///|
fn pdf_ua_stm_own_key() -> PdfName {
  pdf_ua_stm_own_key_name
}

///|
let pdf_ua_markinfo_key_name : PdfName = pdf_ua_name("/MarkInfo")

///|
fn pdf_ua_markinfo_key() -> PdfName {
  pdf_ua_markinfo_key_name
}

///|
let pdf_ua_marked_key_name : PdfName = pdf_ua_name("/Marked")

///|
fn pdf_ua_marked_key() -> PdfName {
  pdf_ua_marked_key_name
}

///|
let pdf_ua_lang_key_name : PdfName = pdf_ua_name("/Lang")

///|
fn pdf_ua_lang_key() -> PdfName {
  pdf_ua_lang_key_name
}

///|
let pdf_ua_viewer_preferences_key_name : PdfName = pdf_ua_name(
  "/ViewerPreferences",
)

///|
fn pdf_ua_viewer_preferences_key() -> PdfName {
  pdf_ua_viewer_preferences_key_name
}

///|
let pdf_ua_display_doc_title_key_name : PdfName = pdf_ua_name(
  "/DisplayDocTitle",
)

///|
fn pdf_ua_display_doc_title_key() -> PdfName {
  pdf_ua_display_doc_title_key_name
}

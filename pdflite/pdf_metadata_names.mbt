///|
fn pdf_metadata_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_metadata_source_key_name(key : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(key))
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
let pdf_metadata_mark_info_name : PdfName = pdf_metadata_name("/MarkInfo")

///|
fn pdf_metadata_mark_info() -> PdfName {
  pdf_metadata_mark_info_name
}

///|
let pdf_metadata_acroform_name : PdfName = pdf_metadata_name("/AcroForm")

///|
fn pdf_metadata_acroform() -> PdfName {
  pdf_metadata_acroform_name
}

///|
let pdf_metadata_xfa_name : PdfName = pdf_metadata_name("/XFA")

///|
fn pdf_metadata_xfa() -> PdfName {
  pdf_metadata_xfa_name
}

///|
let pdf_metadata_trapped_name : PdfName = pdf_metadata_name("/Trapped")

///|
fn pdf_metadata_trapped() -> PdfName {
  pdf_metadata_trapped_name
}

///|
let pdf_metadata_cropbox_name : PdfName = pdf_metadata_name("/CropBox")

///|
fn pdf_metadata_cropbox() -> PdfName {
  pdf_metadata_cropbox_name
}

///|
let pdf_metadata_bleedbox_name : PdfName = pdf_metadata_name("/BleedBox")

///|
fn pdf_metadata_bleedbox() -> PdfName {
  pdf_metadata_bleedbox_name
}

///|
let pdf_metadata_trimbox_name : PdfName = pdf_metadata_name("/TrimBox")

///|
fn pdf_metadata_trimbox() -> PdfName {
  pdf_metadata_trimbox_name
}

///|
let pdf_metadata_artbox_name : PdfName = pdf_metadata_name("/ArtBox")

///|
fn pdf_metadata_artbox() -> PdfName {
  pdf_metadata_artbox_name
}

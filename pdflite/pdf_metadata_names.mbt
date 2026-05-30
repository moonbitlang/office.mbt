///|
fn pdf_metadata_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_metadata_source_key_name(key : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(key))
}

///|
let pdf_metadata_root_name : @core.PdfName = pdf_metadata_name("/Root")

///|
fn pdf_metadata_root() -> @core.PdfName {
  pdf_metadata_root_name
}

///|
let pdf_metadata_info_name : @core.PdfName = pdf_metadata_name("/Info")

///|
fn pdf_metadata_info() -> @core.PdfName {
  pdf_metadata_info_name
}

///|
let pdf_metadata_id_name : @core.PdfName = pdf_metadata_name("/ID")

///|
fn pdf_metadata_id() -> @core.PdfName {
  pdf_metadata_id_name
}

///|
let pdf_metadata_metadata_name : @core.PdfName = pdf_metadata_name("/Metadata")

///|
fn pdf_metadata_metadata() -> @core.PdfName {
  pdf_metadata_metadata_name
}

///|
let pdf_metadata_type_name : @core.PdfName = pdf_metadata_name("/Type")

///|
fn pdf_metadata_type() -> @core.PdfName {
  pdf_metadata_type_name
}

///|
let pdf_metadata_subtype_name : @core.PdfName = pdf_metadata_name("/Subtype")

///|
fn pdf_metadata_subtype() -> @core.PdfName {
  pdf_metadata_subtype_name
}

///|
let pdf_metadata_xml_name : @core.PdfName = pdf_metadata_name("/XML")

///|
fn pdf_metadata_xml() -> @core.PdfName {
  pdf_metadata_xml_name
}

///|
let pdf_metadata_length_name : @core.PdfName = pdf_metadata_name("/Length")

///|
fn pdf_metadata_length() -> @core.PdfName {
  pdf_metadata_length_name
}

///|
let pdf_metadata_viewer_preferences_name : @core.PdfName = pdf_metadata_name(
  "/ViewerPreferences",
)

///|
fn pdf_metadata_viewer_preferences() -> @core.PdfName {
  pdf_metadata_viewer_preferences_name
}

///|
let pdf_metadata_page_layout_name : @core.PdfName = pdf_metadata_name(
  "/PageLayout",
)

///|
fn pdf_metadata_page_layout() -> @core.PdfName {
  pdf_metadata_page_layout_name
}

///|
let pdf_metadata_page_mode_name : @core.PdfName = pdf_metadata_name("/PageMode")

///|
fn pdf_metadata_page_mode() -> @core.PdfName {
  pdf_metadata_page_mode_name
}

///|
let pdf_metadata_non_full_screen_page_mode_name : @core.PdfName = pdf_metadata_name(
  "/NonFullScreenPageMode",
)

///|
fn pdf_metadata_non_full_screen_page_mode() -> @core.PdfName {
  pdf_metadata_non_full_screen_page_mode_name
}

///|
let pdf_metadata_open_action_name : @core.PdfName = pdf_metadata_name(
  "/OpenAction",
)

///|
fn pdf_metadata_open_action() -> @core.PdfName {
  pdf_metadata_open_action_name
}

///|
let pdf_metadata_d_name : @core.PdfName = pdf_metadata_name("/D")

///|
fn pdf_metadata_d() -> @core.PdfName {
  pdf_metadata_d_name
}

///|
let pdf_metadata_s_name : @core.PdfName = pdf_metadata_name("/S")

///|
fn pdf_metadata_s() -> @core.PdfName {
  pdf_metadata_s_name
}

///|
let pdf_metadata_goto_name : @core.PdfName = pdf_metadata_name("/GoTo")

///|
fn pdf_metadata_goto() -> @core.PdfName {
  pdf_metadata_goto_name
}

///|
let pdf_metadata_fit_name : @core.PdfName = pdf_metadata_name("/Fit")

///|
fn pdf_metadata_fit() -> @core.PdfName {
  pdf_metadata_fit_name
}

///|
let pdf_metadata_xyz_name : @core.PdfName = pdf_metadata_name("/XYZ")

///|
fn pdf_metadata_xyz() -> @core.PdfName {
  pdf_metadata_xyz_name
}

///|
let pdf_metadata_lang_name : @core.PdfName = pdf_metadata_name("/Lang")

///|
fn pdf_metadata_lang() -> @core.PdfName {
  pdf_metadata_lang_name
}

///|
let pdf_metadata_mark_info_name : @core.PdfName = pdf_metadata_name("/MarkInfo")

///|
fn pdf_metadata_mark_info() -> @core.PdfName {
  pdf_metadata_mark_info_name
}

///|
let pdf_metadata_acroform_name : @core.PdfName = pdf_metadata_name("/AcroForm")

///|
fn pdf_metadata_acroform() -> @core.PdfName {
  pdf_metadata_acroform_name
}

///|
let pdf_metadata_xfa_name : @core.PdfName = pdf_metadata_name("/XFA")

///|
fn pdf_metadata_xfa() -> @core.PdfName {
  pdf_metadata_xfa_name
}

///|
let pdf_metadata_trapped_name : @core.PdfName = pdf_metadata_name("/Trapped")

///|
fn pdf_metadata_trapped() -> @core.PdfName {
  pdf_metadata_trapped_name
}

///|
let pdf_metadata_cropbox_name : @core.PdfName = pdf_metadata_name("/CropBox")

///|
fn pdf_metadata_cropbox() -> @core.PdfName {
  pdf_metadata_cropbox_name
}

///|
let pdf_metadata_bleedbox_name : @core.PdfName = pdf_metadata_name("/BleedBox")

///|
fn pdf_metadata_bleedbox() -> @core.PdfName {
  pdf_metadata_bleedbox_name
}

///|
let pdf_metadata_trimbox_name : @core.PdfName = pdf_metadata_name("/TrimBox")

///|
fn pdf_metadata_trimbox() -> @core.PdfName {
  pdf_metadata_trimbox_name
}

///|
let pdf_metadata_artbox_name : @core.PdfName = pdf_metadata_name("/ArtBox")

///|
fn pdf_metadata_artbox() -> @core.PdfName {
  pdf_metadata_artbox_name
}

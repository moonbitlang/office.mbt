///|
fn pdf_ocg_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_ocg_root_key_name : @core.PdfName = pdf_ocg_name("/Root")

///|
fn pdf_ocg_root_key() -> @core.PdfName {
  pdf_ocg_root_key_name
}

///|
let pdf_ocg_ocproperties_key_name : @core.PdfName = pdf_ocg_name(
  "/OCProperties",
)

///|
fn pdf_ocg_ocproperties_key() -> @core.PdfName {
  pdf_ocg_ocproperties_key_name
}

///|
let pdf_ocg_ocgs_key_name : @core.PdfName = pdf_ocg_name("/OCGs")

///|
fn pdf_ocg_ocgs_key() -> @core.PdfName {
  pdf_ocg_ocgs_key_name
}

///|
let pdf_ocg_d_key_name : @core.PdfName = pdf_ocg_name("/D")

///|
fn pdf_ocg_d_key() -> @core.PdfName {
  pdf_ocg_d_key_name
}

///|
let pdf_ocg_configs_key_name : @core.PdfName = pdf_ocg_name("/Configs")

///|
fn pdf_ocg_configs_key() -> @core.PdfName {
  pdf_ocg_configs_key_name
}

///|
let pdf_ocg_type_key_name : @core.PdfName = pdf_ocg_name("/Type")

///|
fn pdf_ocg_type_key() -> @core.PdfName {
  pdf_ocg_type_key_name
}

///|
let pdf_ocg_name_key_name : @core.PdfName = pdf_ocg_name("/Name")

///|
fn pdf_ocg_name_key() -> @core.PdfName {
  pdf_ocg_name_key_name
}

///|
let pdf_ocg_intent_key_name : @core.PdfName = pdf_ocg_name("/Intent")

///|
fn pdf_ocg_intent_key() -> @core.PdfName {
  pdf_ocg_intent_key_name
}

///|
let pdf_ocg_usage_key_name : @core.PdfName = pdf_ocg_name("/Usage")

///|
fn pdf_ocg_usage_key() -> @core.PdfName {
  pdf_ocg_usage_key_name
}

///|
let pdf_ocg_creatorinfo_key_name : @core.PdfName = pdf_ocg_name("/CreatorInfo")

///|
fn pdf_ocg_creatorinfo_key() -> @core.PdfName {
  pdf_ocg_creatorinfo_key_name
}

///|
let pdf_ocg_creator_key_name : @core.PdfName = pdf_ocg_name("/Creator")

///|
fn pdf_ocg_creator_key() -> @core.PdfName {
  pdf_ocg_creator_key_name
}

///|
let pdf_ocg_subtype_key_name : @core.PdfName = pdf_ocg_name("/Subtype")

///|
fn pdf_ocg_subtype_key() -> @core.PdfName {
  pdf_ocg_subtype_key_name
}

///|
let pdf_ocg_language_key_name : @core.PdfName = pdf_ocg_name("/Language")

///|
fn pdf_ocg_language_key() -> @core.PdfName {
  pdf_ocg_language_key_name
}

///|
let pdf_ocg_lang_key_name : @core.PdfName = pdf_ocg_name("/Lang")

///|
fn pdf_ocg_lang_key() -> @core.PdfName {
  pdf_ocg_lang_key_name
}

///|
let pdf_ocg_preferred_key_name : @core.PdfName = pdf_ocg_name("/Preferred")

///|
fn pdf_ocg_preferred_key() -> @core.PdfName {
  pdf_ocg_preferred_key_name
}

///|
let pdf_ocg_export_key_name : @core.PdfName = pdf_ocg_name("/Export")

///|
fn pdf_ocg_export_key() -> @core.PdfName {
  pdf_ocg_export_key_name
}

///|
let pdf_ocg_export_state_key_name : @core.PdfName = pdf_ocg_name("/ExportState")

///|
fn pdf_ocg_export_state_key() -> @core.PdfName {
  pdf_ocg_export_state_key_name
}

///|
let pdf_ocg_zoom_key_name : @core.PdfName = pdf_ocg_name("/Zoom")

///|
fn pdf_ocg_zoom_key() -> @core.PdfName {
  pdf_ocg_zoom_key_name
}

///|
let pdf_ocg_min_key_name : @core.PdfName = pdf_ocg_name("/min")

///|
fn pdf_ocg_min_key() -> @core.PdfName {
  pdf_ocg_min_key_name
}

///|
let pdf_ocg_max_key_name : @core.PdfName = pdf_ocg_name("/max")

///|
fn pdf_ocg_max_key() -> @core.PdfName {
  pdf_ocg_max_key_name
}

///|
let pdf_ocg_print_key_name : @core.PdfName = pdf_ocg_name("/Print")

///|
fn pdf_ocg_print_key() -> @core.PdfName {
  pdf_ocg_print_key_name
}

///|
let pdf_ocg_print_state_key_name : @core.PdfName = pdf_ocg_name("/PrintState")

///|
fn pdf_ocg_print_state_key() -> @core.PdfName {
  pdf_ocg_print_state_key_name
}

///|
let pdf_ocg_view_key_name : @core.PdfName = pdf_ocg_name("/View")

///|
fn pdf_ocg_view_key() -> @core.PdfName {
  pdf_ocg_view_key_name
}

///|
let pdf_ocg_view_state_key_name : @core.PdfName = pdf_ocg_name("/ViewState")

///|
fn pdf_ocg_view_state_key() -> @core.PdfName {
  pdf_ocg_view_state_key_name
}

///|
let pdf_ocg_user_key_name : @core.PdfName = pdf_ocg_name("/User")

///|
fn pdf_ocg_user_key() -> @core.PdfName {
  pdf_ocg_user_key_name
}

///|
let pdf_ocg_page_element_key_name : @core.PdfName = pdf_ocg_name("/PageElement")

///|
fn pdf_ocg_page_element_key() -> @core.PdfName {
  pdf_ocg_page_element_key_name
}

///|
let pdf_ocg_event_key_name : @core.PdfName = pdf_ocg_name("/Event")

///|
fn pdf_ocg_event_key() -> @core.PdfName {
  pdf_ocg_event_key_name
}

///|
let pdf_ocg_category_key_name : @core.PdfName = pdf_ocg_name("/Category")

///|
fn pdf_ocg_category_key() -> @core.PdfName {
  pdf_ocg_category_key_name
}

///|
let pdf_ocg_base_state_key_name : @core.PdfName = pdf_ocg_name("/BaseState")

///|
fn pdf_ocg_base_state_key() -> @core.PdfName {
  pdf_ocg_base_state_key_name
}

///|
let pdf_ocg_on_key_name : @core.PdfName = pdf_ocg_name("/ON")

///|
fn pdf_ocg_on_key() -> @core.PdfName {
  pdf_ocg_on_key_name
}

///|
let pdf_ocg_off_key_name : @core.PdfName = pdf_ocg_name("/OFF")

///|
fn pdf_ocg_off_key() -> @core.PdfName {
  pdf_ocg_off_key_name
}

///|
let pdf_ocg_as_key_name : @core.PdfName = pdf_ocg_name("/AS")

///|
fn pdf_ocg_as_key() -> @core.PdfName {
  pdf_ocg_as_key_name
}

///|
let pdf_ocg_order_key_name : @core.PdfName = pdf_ocg_name("/Order")

///|
fn pdf_ocg_order_key() -> @core.PdfName {
  pdf_ocg_order_key_name
}

///|
let pdf_ocg_list_mode_key_name : @core.PdfName = pdf_ocg_name("/ListMode")

///|
fn pdf_ocg_list_mode_key() -> @core.PdfName {
  pdf_ocg_list_mode_key_name
}

///|
let pdf_ocg_rb_groups_key_name : @core.PdfName = pdf_ocg_name("/RBGroups")

///|
fn pdf_ocg_rb_groups_key() -> @core.PdfName {
  pdf_ocg_rb_groups_key_name
}

///|
let pdf_ocg_locked_key_name : @core.PdfName = pdf_ocg_name("/Locked")

///|
fn pdf_ocg_locked_key() -> @core.PdfName {
  pdf_ocg_locked_key_name
}

///|
let pdf_ocg_ocg_name_value : @core.PdfName = pdf_ocg_name("/OCG")

///|
fn pdf_ocg_ocg_name() -> @core.PdfName {
  pdf_ocg_ocg_name_value
}

///|
fn pdf_ocg_view_name() -> @core.PdfName {
  pdf_ocg_view_key_name
}

///|
fn pdf_ocg_print_name() -> @core.PdfName {
  pdf_ocg_print_key_name
}

///|
fn pdf_ocg_export_name() -> @core.PdfName {
  pdf_ocg_export_key_name
}

///|
fn pdf_ocg_off_name() -> @core.PdfName {
  pdf_ocg_off_key_name
}

///|
let pdf_ocg_unchanged_name_value : @core.PdfName = pdf_ocg_name("/Unchanged")

///|
fn pdf_ocg_unchanged_name() -> @core.PdfName {
  pdf_ocg_unchanged_name_value
}

///|
let pdf_ocg_visible_pages_name_value : @core.PdfName = pdf_ocg_name(
  "/VisiblePages",
)

///|
fn pdf_ocg_visible_pages_name() -> @core.PdfName {
  pdf_ocg_visible_pages_name_value
}

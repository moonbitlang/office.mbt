///|
fn pdf_ocg_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_ocg_root_key_name : PdfName = pdf_ocg_name("/Root")

///|
fn pdf_ocg_root_key() -> PdfName {
  pdf_ocg_root_key_name
}

///|
let pdf_ocg_ocproperties_key_name : PdfName = pdf_ocg_name("/OCProperties")

///|
fn pdf_ocg_ocproperties_key() -> PdfName {
  pdf_ocg_ocproperties_key_name
}

///|
let pdf_ocg_ocgs_key_name : PdfName = pdf_ocg_name("/OCGs")

///|
fn pdf_ocg_ocgs_key() -> PdfName {
  pdf_ocg_ocgs_key_name
}

///|
let pdf_ocg_d_key_name : PdfName = pdf_ocg_name("/D")

///|
fn pdf_ocg_d_key() -> PdfName {
  pdf_ocg_d_key_name
}

///|
let pdf_ocg_configs_key_name : PdfName = pdf_ocg_name("/Configs")

///|
fn pdf_ocg_configs_key() -> PdfName {
  pdf_ocg_configs_key_name
}

///|
let pdf_ocg_type_key_name : PdfName = pdf_ocg_name("/Type")

///|
fn pdf_ocg_type_key() -> PdfName {
  pdf_ocg_type_key_name
}

///|
let pdf_ocg_name_key_name : PdfName = pdf_ocg_name("/Name")

///|
fn pdf_ocg_name_key() -> PdfName {
  pdf_ocg_name_key_name
}

///|
let pdf_ocg_intent_key_name : PdfName = pdf_ocg_name("/Intent")

///|
fn pdf_ocg_intent_key() -> PdfName {
  pdf_ocg_intent_key_name
}

///|
let pdf_ocg_usage_key_name : PdfName = pdf_ocg_name("/Usage")

///|
fn pdf_ocg_usage_key() -> PdfName {
  pdf_ocg_usage_key_name
}

///|
let pdf_ocg_creatorinfo_key_name : PdfName = pdf_ocg_name("/CreatorInfo")

///|
fn pdf_ocg_creatorinfo_key() -> PdfName {
  pdf_ocg_creatorinfo_key_name
}

///|
let pdf_ocg_creator_key_name : PdfName = pdf_ocg_name("/Creator")

///|
fn pdf_ocg_creator_key() -> PdfName {
  pdf_ocg_creator_key_name
}

///|
let pdf_ocg_subtype_key_name : PdfName = pdf_ocg_name("/Subtype")

///|
fn pdf_ocg_subtype_key() -> PdfName {
  pdf_ocg_subtype_key_name
}

///|
let pdf_ocg_language_key_name : PdfName = pdf_ocg_name("/Language")

///|
fn pdf_ocg_language_key() -> PdfName {
  pdf_ocg_language_key_name
}

///|
let pdf_ocg_lang_key_name : PdfName = pdf_ocg_name("/Lang")

///|
fn pdf_ocg_lang_key() -> PdfName {
  pdf_ocg_lang_key_name
}

///|
let pdf_ocg_preferred_key_name : PdfName = pdf_ocg_name("/Preferred")

///|
fn pdf_ocg_preferred_key() -> PdfName {
  pdf_ocg_preferred_key_name
}

///|
let pdf_ocg_export_key_name : PdfName = pdf_ocg_name("/Export")

///|
fn pdf_ocg_export_key() -> PdfName {
  pdf_ocg_export_key_name
}

///|
let pdf_ocg_export_state_key_name : PdfName = pdf_ocg_name("/ExportState")

///|
fn pdf_ocg_export_state_key() -> PdfName {
  pdf_ocg_export_state_key_name
}

///|
let pdf_ocg_zoom_key_name : PdfName = pdf_ocg_name("/Zoom")

///|
fn pdf_ocg_zoom_key() -> PdfName {
  pdf_ocg_zoom_key_name
}

///|
let pdf_ocg_min_key_name : PdfName = pdf_ocg_name("/min")

///|
fn pdf_ocg_min_key() -> PdfName {
  pdf_ocg_min_key_name
}

///|
let pdf_ocg_max_key_name : PdfName = pdf_ocg_name("/max")

///|
fn pdf_ocg_max_key() -> PdfName {
  pdf_ocg_max_key_name
}

///|
let pdf_ocg_print_key_name : PdfName = pdf_ocg_name("/Print")

///|
fn pdf_ocg_print_key() -> PdfName {
  pdf_ocg_print_key_name
}

///|
let pdf_ocg_print_state_key_name : PdfName = pdf_ocg_name("/PrintState")

///|
fn pdf_ocg_print_state_key() -> PdfName {
  pdf_ocg_print_state_key_name
}

///|
let pdf_ocg_view_key_name : PdfName = pdf_ocg_name("/View")

///|
fn pdf_ocg_view_key() -> PdfName {
  pdf_ocg_view_key_name
}

///|
let pdf_ocg_view_state_key_name : PdfName = pdf_ocg_name("/ViewState")

///|
fn pdf_ocg_view_state_key() -> PdfName {
  pdf_ocg_view_state_key_name
}

///|
let pdf_ocg_user_key_name : PdfName = pdf_ocg_name("/User")

///|
fn pdf_ocg_user_key() -> PdfName {
  pdf_ocg_user_key_name
}

///|
let pdf_ocg_page_element_key_name : PdfName = pdf_ocg_name("/PageElement")

///|
fn pdf_ocg_page_element_key() -> PdfName {
  pdf_ocg_page_element_key_name
}

///|
let pdf_ocg_event_key_name : PdfName = pdf_ocg_name("/Event")

///|
fn pdf_ocg_event_key() -> PdfName {
  pdf_ocg_event_key_name
}

///|
let pdf_ocg_category_key_name : PdfName = pdf_ocg_name("/Category")

///|
fn pdf_ocg_category_key() -> PdfName {
  pdf_ocg_category_key_name
}

///|
let pdf_ocg_base_state_key_name : PdfName = pdf_ocg_name("/BaseState")

///|
fn pdf_ocg_base_state_key() -> PdfName {
  pdf_ocg_base_state_key_name
}

///|
let pdf_ocg_on_key_name : PdfName = pdf_ocg_name("/ON")

///|
fn pdf_ocg_on_key() -> PdfName {
  pdf_ocg_on_key_name
}

///|
let pdf_ocg_off_key_name : PdfName = pdf_ocg_name("/OFF")

///|
fn pdf_ocg_off_key() -> PdfName {
  pdf_ocg_off_key_name
}

///|
let pdf_ocg_as_key_name : PdfName = pdf_ocg_name("/AS")

///|
fn pdf_ocg_as_key() -> PdfName {
  pdf_ocg_as_key_name
}

///|
let pdf_ocg_order_key_name : PdfName = pdf_ocg_name("/Order")

///|
fn pdf_ocg_order_key() -> PdfName {
  pdf_ocg_order_key_name
}

///|
let pdf_ocg_list_mode_key_name : PdfName = pdf_ocg_name("/ListMode")

///|
fn pdf_ocg_list_mode_key() -> PdfName {
  pdf_ocg_list_mode_key_name
}

///|
let pdf_ocg_rb_groups_key_name : PdfName = pdf_ocg_name("/RBGroups")

///|
fn pdf_ocg_rb_groups_key() -> PdfName {
  pdf_ocg_rb_groups_key_name
}

///|
let pdf_ocg_locked_key_name : PdfName = pdf_ocg_name("/Locked")

///|
fn pdf_ocg_locked_key() -> PdfName {
  pdf_ocg_locked_key_name
}

///|
let pdf_ocg_ocg_name_value : PdfName = pdf_ocg_name("/OCG")

///|
fn pdf_ocg_ocg_name() -> PdfName {
  pdf_ocg_ocg_name_value
}

///|
fn pdf_ocg_view_name() -> PdfName {
  pdf_ocg_view_key_name
}

///|
fn pdf_ocg_print_name() -> PdfName {
  pdf_ocg_print_key_name
}

///|
fn pdf_ocg_export_name() -> PdfName {
  pdf_ocg_export_key_name
}

///|
fn pdf_ocg_off_name() -> PdfName {
  pdf_ocg_off_key_name
}

///|
let pdf_ocg_unchanged_name_value : PdfName = pdf_ocg_name("/Unchanged")

///|
fn pdf_ocg_unchanged_name() -> PdfName {
  pdf_ocg_unchanged_name_value
}

///|
let pdf_ocg_visible_pages_name_value : PdfName = pdf_ocg_name("/VisiblePages")

///|
fn pdf_ocg_visible_pages_name() -> PdfName {
  pdf_ocg_visible_pages_name_value
}

///|
/// Usage dictionary for a PDF optional content group.
///
/// Byte fields preserve PDF string bytes exactly. Name fields preserve the
/// corresponding PDF names for creator, language, export, zoom, print, view,
/// user, and page-element usage hints.
pub(all) struct PdfOcgUsage {
  creator_info : (PdfBytes, PdfName)?
  language : (PdfBytes, PdfName?)?
  export_state : PdfName?
  zoom_min : Double?
  zoom_max : Double?
  print_subtype : PdfName?
  print_state : PdfName?
  view_state : PdfName?
  user : (PdfName, Array[PdfBytes])?
  page_element_subtype : PdfName?
} derive(Debug, Eq, ToJson)

///|
/// One PDF optional content group dictionary.
///
/// The group's indirect object number is stored outside this record in
/// `PdfOptionalContent.ocgs`; `name` is the raw PDF string bytes.
pub(all) struct PdfOcg {
  name : PdfBytes
  intent : Array[PdfName]
  usage : PdfOcgUsage?
} derive(Debug, Eq, ToJson)

///|
/// Default visibility state for optional content groups in a configuration.
pub(all) enum PdfOcgState {
  OcgOn
  OcgOff
  OcgUnchanged
} derive(Debug, Eq, ToJson)

///|
/// Policy for whether the layer list is shown on all pages or only visible pages.
pub(all) enum PdfOcgListMode {
  OcgAllPages
  OcgVisiblePages
} derive(Debug, Eq, ToJson)

///|
/// Event context used by optional-content usage application dictionaries.
pub(all) enum PdfOcgEvent {
  OcgView
  OcgPrint
  OcgExport
} derive(Debug, Eq, ToJson)

///|
/// Optional-content usage application dictionary.
///
/// `ocgs` contains indirect object numbers of optional content groups, and
/// `category` stores the PDF usage-category names for the application.
pub(all) struct PdfOcgAppDict {
  event : PdfOcgEvent
  ocgs : Array[Int]
  category : Array[PdfName]
} derive(Debug, Eq, ToJson)

///|
/// Optional-content configuration dictionary.
///
/// Arrays such as `on`, `off`, `locked`, radio-button groups, and order entries
/// contain OCG indirect object numbers. `order` preserves the PDF layer-panel
/// grouping labels as raw string bytes.
pub(all) struct PdfOcgConfig {
  name : PdfBytes?
  creator : PdfBytes?
  base_state : PdfOcgState
  on : Array[Int]
  off : Array[Int]
  intent : Array[PdfName]
  usage_applications : Array[PdfOcgAppDict]
  order : Array[(PdfBytes?, Array[Int])]?
  list_mode : PdfOcgListMode
  radio_button_groups : Array[Array[Int]]?
  locked : Array[Int]
} derive(Debug, Eq, ToJson)

///|
/// Complete catalog optional-content properties.
///
/// `ocgs` pairs each group's existing indirect object number with the parsed
/// group dictionary. `default_config` maps `/D`; `configs` maps alternate
/// entries from `/Configs`.
pub(all) struct PdfOptionalContent {
  ocgs : Array[(Int, PdfOcg)]
  default_config : PdfOcgConfig
  configs : Array[PdfOcgConfig]
} derive(Debug, Eq, ToJson)

///|
/// Return the PDF default optional-content configuration used when none is set.
///
/// The default has base state `OcgOn`, `/Intent /View`, no explicit on/off
/// lists, no order, no radio-button groups, and no locked groups.
pub fn pdf_ocg_default_config() -> PdfOcgConfig {
  {
    name: None,
    creator: None,
    base_state: OcgOn,
    on: [],
    off: [],
    intent: [pdf_ocg_view_name()],
    usage_applications: [],
    order: None,
    list_mode: OcgAllPages,
    radio_button_groups: None,
    locked: [],
  }
}

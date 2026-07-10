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
fn pdf_ocg_default_view_name() -> PdfName {
  @core.pdf_name_of_bytes(b"/View")
}

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
    intent: [pdf_ocg_default_view_name()],
    usage_applications: [],
    order: None,
    list_mode: OcgAllPages,
    radio_button_groups: None,
    locked: [],
  }
}

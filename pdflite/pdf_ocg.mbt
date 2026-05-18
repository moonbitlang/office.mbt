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

///|
fn PdfDocument::pdf_ocg_root(self : PdfDocument) -> PdfObject raise PdfError {
  self.catalog()
}

///|
fn PdfDocument::pdf_ocg_name_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[PdfName] {
  match self.direct(object) {
    PdfNameObject(name) => [name]
    PdfArray(values) => {
      let names : Array[PdfName] = []
      for value in values {
        match self.direct(value) {
          PdfNameObject(name) => names.push(name)
          _ => ()
        }
      }
      names
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_ocg_indirect_numbers(
  self : PdfDocument,
  object : PdfObject,
) -> Array[Int] {
  match self.direct(object) {
    PdfArray(values) => {
      let numbers : Array[Int] = []
      for value in values {
        match value {
          PdfIndirect(number) => numbers.push(number)
          _ => ()
        }
      }
      numbers
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_ocg_string_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[PdfBytes] {
  match self.direct(object) {
    PdfString(text) => [text]
    PdfArray(values) => {
      let strings : Array[PdfBytes] = []
      for value in values {
        match self.direct(value) {
          PdfString(text) => strings.push(text)
          _ => ()
        }
      }
      strings
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_ocg_optional_number(
  self : PdfDocument,
  object : PdfObject,
) -> Double? {
  try self.get_number(object) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn PdfDocument::pdf_ocg_read_appdict(
  self : PdfDocument,
  appdict : PdfObject,
) -> PdfOcgAppDict {
  let event = match self.lookup_direct(pdf_ocg_event_key(), appdict) {
    Some(PdfNameObject(name)) if name == pdf_ocg_print_name() => OcgPrint
    Some(PdfNameObject(name)) if name == pdf_ocg_export_name() => OcgExport
    _ => OcgView
  }
  let ocgs = match self.lookup_direct(pdf_ocg_ocgs_key(), appdict) {
    Some(object) => self.pdf_ocg_indirect_numbers(object)
    _ => []
  }
  let category = match self.lookup_direct(pdf_ocg_category_key(), appdict) {
    Some(object) => self.pdf_ocg_name_array(object)
    _ => []
  }
  { event, ocgs, category }
}

///|
fn PdfDocument::pdf_ocg_read_order(
  self : PdfDocument,
  order : PdfObject,
) -> Array[(PdfBytes?, Array[Int])] {
  match self.direct(order) {
    PdfArray(items) => {
      let output : Array[(PdfBytes?, Array[Int])] = []
      for item in items {
        match item {
          PdfIndirect(number) => output.push((None, [number]))
          _ =>
            match self.direct(item) {
              PdfArray([PdfString(label), .. rest]) => {
                let numbers : Array[Int] = []
                for child in rest {
                  match child {
                    PdfIndirect(number) => numbers.push(number)
                    _ => ()
                  }
                }
                output.push((Some(label), numbers))
              }
              PdfArray(children) => {
                let numbers : Array[Int] = []
                for child in children {
                  match child {
                    PdfIndirect(number) => numbers.push(number)
                    _ => ()
                  }
                }
                output.push((None, numbers))
              }
              _ => output.push((None, []))
            }
        }
      }
      output
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_ocg_read_config(
  self : PdfDocument,
  config : PdfObject,
) -> PdfOcgConfig {
  let name = match self.lookup_direct(pdf_ocg_name_key(), config) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
  let creator = match self.lookup_direct(pdf_ocg_creator_key(), config) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
  let base_state = match self.lookup_direct(pdf_ocg_base_state_key(), config) {
    Some(PdfNameObject(name)) if name == pdf_ocg_off_name() => OcgOff
    Some(PdfNameObject(name)) if name == pdf_ocg_unchanged_name() =>
      OcgUnchanged
    _ => OcgOn
  }
  let on = match self.lookup_direct(pdf_ocg_on_key(), config) {
    Some(object) => self.pdf_ocg_indirect_numbers(object)
    _ => []
  }
  let off = match self.lookup_direct(pdf_ocg_off_key(), config) {
    Some(object) => self.pdf_ocg_indirect_numbers(object)
    _ => []
  }
  let intent = match self.lookup_direct(pdf_ocg_intent_key(), config) {
    Some(object) => self.pdf_ocg_name_array(object)
    _ => [pdf_ocg_view_name()]
  }
  let usage_applications = match self.lookup_direct(pdf_ocg_as_key(), config) {
    Some(PdfArray(appdicts)) =>
      [
        for appdict in appdicts => self.pdf_ocg_read_appdict(appdict)
      ]
    _ => []
  }
  let order = match self.lookup_direct(pdf_ocg_order_key(), config) {
    Some(object) => Some(self.pdf_ocg_read_order(object))
    None => None
  }
  let list_mode = match self.lookup_direct(pdf_ocg_list_mode_key(), config) {
    Some(PdfNameObject(name)) if name == pdf_ocg_visible_pages_name() =>
      OcgVisiblePages
    _ => OcgAllPages
  }
  let radio_button_groups = match
    self.lookup_direct(pdf_ocg_rb_groups_key(), config) {
    Some(PdfArray(groups)) =>
      Some([ for group in groups => self.pdf_ocg_indirect_numbers(group) ])
    _ => None
  }
  let locked = match self.lookup_direct(pdf_ocg_locked_key(), config) {
    Some(object) => self.pdf_ocg_indirect_numbers(object)
    _ => []
  }
  {
    name,
    creator,
    base_state,
    on,
    off,
    intent,
    usage_applications,
    order,
    list_mode,
    radio_button_groups,
    locked,
  }
}

///|
fn PdfDocument::pdf_ocg_read_usage(
  self : PdfDocument,
  usage : PdfObject,
) -> PdfOcgUsage {
  let creator = match
    self.lookup_chain(usage, [pdf_ocg_creatorinfo_key(), pdf_ocg_creator_key()]) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
  let creator_subtype = match
    self.lookup_chain(usage, [pdf_ocg_creatorinfo_key(), pdf_ocg_subtype_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let creator_info = match (creator, creator_subtype) {
    (Some(creator), Some(subtype)) => Some((creator, subtype))
    (Some(creator), None) => Some((creator, pdf_name_of_bytes([])))
    (None, Some(subtype)) => Some(([], subtype))
    _ => None
  }
  let language_value = match
    self.lookup_chain(usage, [pdf_ocg_language_key(), pdf_ocg_lang_key()]) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
  let language_preferred = match
    self.lookup_chain(usage, [pdf_ocg_language_key(), pdf_ocg_preferred_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let language = match language_value {
    Some(value) => Some((value, language_preferred))
    None => None
  }
  let export_state = match
    self.lookup_chain(usage, [pdf_ocg_export_key(), pdf_ocg_export_state_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let zoom_min = match
    self.lookup_chain(usage, [pdf_ocg_zoom_key(), pdf_ocg_min_key()]) {
    Some(value) => self.pdf_ocg_optional_number(value)
    _ => None
  }
  let zoom_max = match
    self.lookup_chain(usage, [pdf_ocg_zoom_key(), pdf_ocg_max_key()]) {
    Some(value) => self.pdf_ocg_optional_number(value)
    _ => None
  }
  let print_subtype = match
    self.lookup_chain(usage, [pdf_ocg_print_key(), pdf_ocg_subtype_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let print_state = match
    self.lookup_chain(usage, [pdf_ocg_print_key(), pdf_ocg_print_state_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let view_state = match
    self.lookup_chain(usage, [pdf_ocg_view_key(), pdf_ocg_view_state_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let user_type = match
    self.lookup_chain(usage, [pdf_ocg_user_key(), pdf_ocg_type_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  let user_names = match
    self.lookup_chain(usage, [pdf_ocg_user_key(), pdf_ocg_name_key()]) {
    Some(object) => {
      let names = self.pdf_ocg_string_array(object)
      if names.length() == 0 {
        None
      } else {
        Some(names)
      }
    }
    _ => None
  }
  let user = match (user_type, user_names) {
    (Some(user_type), Some(user_names)) => Some((user_type, user_names))
    _ => None
  }
  let page_element_subtype = match
    self.lookup_chain(usage, [pdf_ocg_page_element_key(), pdf_ocg_subtype_key()]) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
  {
    creator_info,
    language,
    export_state,
    zoom_min,
    zoom_max,
    print_subtype,
    print_state,
    view_state,
    user,
    page_element_subtype,
  }
}

///|
fn PdfDocument::pdf_ocg_read_individual(
  self : PdfDocument,
  ocg : PdfObject,
) -> PdfOcg raise PdfError {
  let name = match self.lookup_direct(pdf_ocg_name_key(), ocg) {
    Some(PdfString(name)) => name
    _ => raise DictionaryKeyNotFound(pdf_ocg_name_key())
  }
  let intent = match self.lookup_direct(pdf_ocg_intent_key(), ocg) {
    Some(object) => self.pdf_ocg_name_array(object)
    _ => [pdf_ocg_view_name()]
  }
  let usage = match self.lookup_direct(pdf_ocg_usage_key(), ocg) {
    Some(usage) => Some(self.pdf_ocg_read_usage(usage))
    None => None
  }
  { name, intent, usage }
}

///|
/// Read catalog `/OCProperties` from the document.
///
/// Returns `None` when the catalog has no optional-content properties. When
/// properties are present, OCG entries are returned with their indirect object
/// numbers so callers can preserve or renumber references before writing.
pub fn PdfDocument::read_optional_content_groups(
  self : PdfDocument,
) -> PdfOptionalContent? raise PdfError {
  let root = self.pdf_ocg_root()
  match self.lookup_direct(pdf_ocg_ocproperties_key(), root) {
    None => None
    Some(ocproperties) => {
      let ocgs = match self.lookup_direct(pdf_ocg_ocgs_key(), ocproperties) {
        Some(PdfArray(indirects)) => {
          let output : Array[(Int, PdfOcg)] = []
          for indirect in indirects {
            match indirect {
              PdfIndirect(number) =>
                output.push((number, self.pdf_ocg_read_individual(indirect)))
              _ => ()
            }
          }
          output
        }
        _ => []
      }
      let default_config = match
        self.lookup_direct(pdf_ocg_d_key(), ocproperties) {
        Some(config) => self.pdf_ocg_read_config(config)
        None => raise DictionaryKeyNotFound(pdf_ocg_d_key())
      }
      let configs = match
        self.lookup_direct(pdf_ocg_configs_key(), ocproperties) {
        Some(PdfArray(configs)) =>
          [
            for config in configs => self.pdf_ocg_read_config(config)
          ]
        _ => []
      }
      Some({ ocgs, default_config, configs })
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::read_optional_content_groups`.
pub fn pdf_read_ocg(
  document : PdfDocument,
) -> PdfOptionalContent? raise PdfError {
  document.read_optional_content_groups()
}

///|
/// Return the raw PDF string names of catalog optional-content groups.
///
/// This mirrors cpdf's `ocg_get_list`: missing optional-content metadata yields
/// an empty list, and malformed individual group entries are skipped.
pub fn PdfDocument::ocg_get_list(
  self : PdfDocument,
) -> Array[PdfBytes] raise PdfError {
  let root = self.pdf_ocg_root()
  match self.lookup_direct(pdf_ocg_ocproperties_key(), root) {
    None => []
    Some(ocproperties) =>
      match self.lookup_direct(pdf_ocg_ocgs_key(), ocproperties) {
        Some(PdfArray(indirects)) => {
          let names : Array[PdfBytes] = []
          for indirect in indirects {
            match indirect {
              PdfIndirect(_) =>
                match self.lookup_direct(pdf_ocg_name_key(), indirect) {
                  Some(PdfString(name)) => names.push(name)
                  _ => ()
                }
              _ => ()
            }
          }
          names
        }
        _ => []
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_get_list`.
pub fn pdf_ocg_get_list(
  document : PdfDocument,
) -> Array[PdfBytes] raise PdfError {
  document.ocg_get_list()
}

///|
fn pdf_ocg_json_int(value : Int) -> Json {
  pdf_util_json_number(value)
}

///|
fn pdf_ocg_json_ints(values : ArrayView[Int]) -> Json {
  Json::array([ for value in values => pdf_ocg_json_int(value) ])
}

///|
fn pdf_ocg_json_string(bytes : BytesView) -> Json raise PdfError {
  let utf8 = pdf_utf8_of_pdfdocstring(bytes)
  Json::string(pdf_util_string_from_utf8(utf8))
}

///|
fn pdf_ocg_json_name(name : PdfName) -> Json raise PdfError {
  Json::string(pdf_util_string_from_name(name))
}

///|
fn pdf_ocg_json_optional_string(bytes : PdfBytes?) -> Json raise PdfError {
  match bytes {
    Some(bytes) => pdf_ocg_json_string(bytes)
    None => Json::null()
  }
}

///|
fn pdf_ocg_json_optional_name(name : PdfName?) -> Json raise PdfError {
  match name {
    Some(name) => pdf_ocg_json_name(name)
    None => Json::null()
  }
}

///|
fn pdf_ocg_json_optional_float(value : Double?) -> Json {
  match value {
    Some(value) => Json::number(value)
    None => Json::null()
  }
}

///|
fn pdf_ocg_json_names(names : ArrayView[PdfName]) -> Json raise PdfError {
  let output : Array[Json] = []
  for name in names {
    output.push(pdf_ocg_json_name(name))
  }
  Json::array(output)
}

///|
fn pdf_ocg_json_strings(strings : ArrayView[PdfBytes]) -> Json raise PdfError {
  let output : Array[Json] = []
  for text in strings {
    output.push(pdf_ocg_json_string(text))
  }
  Json::array(output)
}

///|
fn pdf_ocg_json_state(state : PdfOcgState) -> Json {
  Json::string(
    match state {
      OcgOn => "/ON"
      OcgOff => "/OFF"
      OcgUnchanged => "/Unchanged"
    },
  )
}

///|
fn pdf_ocg_json_list_mode(mode : PdfOcgListMode) -> Json {
  Json::string(
    match mode {
      OcgAllPages => "/AllPages"
      OcgVisiblePages => "/VisiblePages"
    },
  )
}

///|
fn pdf_ocg_json_event(event : PdfOcgEvent) -> Json {
  Json::string(
    match event {
      OcgView => "/View"
      OcgPrint => "/Print"
      OcgExport => "/Export"
    },
  )
}

///|
fn pdf_ocg_json_order(
  order : ArrayView[(PdfBytes?, Array[Int])],
) -> Json raise PdfError {
  let output : Array[Json] = []
  for item in order {
    let (name, ocgs) = item
    output.push(
      Json::object(
        Map::of([
          ("Name", pdf_ocg_json_optional_string(name)),
          ("OCGs", pdf_ocg_json_ints(ocgs)),
        ]),
      ),
    )
  }
  Json::array(output)
}

///|
fn pdf_ocg_json_optional_order(
  order : Array[(PdfBytes?, Array[Int])]?,
) -> Json raise PdfError {
  match order {
    Some(order) => pdf_ocg_json_order(order)
    None => Json::null()
  }
}

///|
fn pdf_ocg_json_radio_groups(groups : Array[Array[Int]]?) -> Json {
  match groups {
    Some(groups) =>
      Json::array([ for group in groups => pdf_ocg_json_ints(group) ])
    None => Json::null()
  }
}

///|
fn pdf_ocg_json_appdict(appdict : PdfOcgAppDict) -> Json raise PdfError {
  Json::object(
    Map::of([
      ("Event", pdf_ocg_json_event(appdict.event)),
      ("OCGs", pdf_ocg_json_ints(appdict.ocgs)),
      ("Category", pdf_ocg_json_names(appdict.category)),
    ]),
  )
}

///|
fn pdf_ocg_json_appdicts(
  appdicts : ArrayView[PdfOcgAppDict],
) -> Json raise PdfError {
  let output : Array[Json] = []
  for appdict in appdicts {
    output.push(pdf_ocg_json_appdict(appdict))
  }
  Json::array(output)
}

///|
fn pdf_ocg_json_config(config : PdfOcgConfig) -> Json raise PdfError {
  Json::object(
    Map::of([
      ("Name", pdf_ocg_json_optional_string(config.name)),
      ("Creator", pdf_ocg_json_optional_string(config.creator)),
      ("BaseState", pdf_ocg_json_state(config.base_state)),
      ("ON", pdf_ocg_json_ints(config.on)),
      ("OFF", pdf_ocg_json_ints(config.off)),
      ("Intent", pdf_ocg_json_names(config.intent)),
      ("AS", pdf_ocg_json_appdicts(config.usage_applications)),
      ("Order", pdf_ocg_json_optional_order(config.order)),
      ("ListMode", pdf_ocg_json_list_mode(config.list_mode)),
      ("RBGroups", pdf_ocg_json_radio_groups(config.radio_button_groups)),
      ("Locked", pdf_ocg_json_ints(config.locked)),
    ]),
  )
}

///|
fn pdf_ocg_json_usage(usage : PdfOcgUsage) -> Json raise PdfError {
  Json::object(
    Map::of([
      (
        "CreatorInfo-Creator",
        match usage.creator_info {
          Some((creator, _)) => pdf_ocg_json_string(creator)
          None => Json::null()
        },
      ),
      (
        "CreatorInfo-Subtype",
        match usage.creator_info {
          Some((_, subtype)) => pdf_ocg_json_name(subtype)
          None => Json::null()
        },
      ),
      (
        "Language-Language",
        match usage.language {
          Some((language, _)) => pdf_ocg_json_string(language)
          None => Json::null()
        },
      ),
      (
        "Language-Preferred",
        match usage.language {
          Some((_, preferred)) => pdf_ocg_json_optional_name(preferred)
          None => Json::null()
        },
      ),
      ("Export", pdf_ocg_json_optional_name(usage.export_state)),
      ("Zoom-Min", pdf_ocg_json_optional_float(usage.zoom_min)),
      ("Zoom-Max", pdf_ocg_json_optional_float(usage.zoom_max)),
      ("Print-Subtype", pdf_ocg_json_optional_name(usage.print_subtype)),
      ("Print-PrintState", pdf_ocg_json_optional_name(usage.print_state)),
      ("ViewState", pdf_ocg_json_optional_name(usage.view_state)),
      (
        "User-Type",
        match usage.user {
          Some((user_type, _)) => pdf_ocg_json_name(user_type)
          None => Json::null()
        },
      ),
      (
        "User-Name",
        match usage.user {
          Some((_, names)) => pdf_ocg_json_strings(names)
          None => Json::null()
        },
      ),
      (
        "PageElement-Subtype",
        pdf_ocg_json_optional_name(usage.page_element_subtype),
      ),
    ]),
  )
}

///|
fn pdf_ocg_json_optional_usage(usage : PdfOcgUsage?) -> Json raise PdfError {
  match usage {
    Some(usage) => pdf_ocg_json_usage(usage)
    None => Json::null()
  }
}

///|
fn pdf_ocg_json_ocg(ocg : PdfOcg) -> Json raise PdfError {
  Json::object(
    Map::of([
      ("Name", pdf_ocg_json_string(ocg.name)),
      ("Intent", pdf_ocg_json_names(ocg.intent)),
      ("Usage", pdf_ocg_json_optional_usage(ocg.usage)),
    ]),
  )
}

///|
fn pdf_ocg_json_ocgs(ocgs : ArrayView[(Int, PdfOcg)]) -> Json raise PdfError {
  let entries : Map[String, Json] = Map([])
  for item in ocgs {
    let (number, ocg) = item
    entries.set(number.to_string(), pdf_ocg_json_ocg(ocg))
  }
  Json::object(entries)
}

///|
fn pdf_ocg_json_configs(
  configs : ArrayView[PdfOcgConfig],
) -> Json raise PdfError {
  let output : Array[Json] = []
  for config in configs {
    output.push(pdf_ocg_json_config(config))
  }
  Json::array(output)
}

///|
/// Return cpdf's optional-content group JSON listing.
pub fn PdfDocument::ocg_list_json(self : PdfDocument) -> Json raise PdfError {
  match self.read_optional_content_groups() {
    None => Json::null()
    Some(content) =>
      Json::object(
        Map::of([
          ("OCGs", pdf_ocg_json_ocgs(content.ocgs)),
          ("Default", pdf_ocg_json_config(content.default_config)),
          ("Configs", pdf_ocg_json_configs(content.configs)),
        ]),
      )
  }
}

///|
/// Return cpdf's optional-content group JSON listing as UTF-8 JSON bytes.
pub fn PdfDocument::ocg_list_json_blob(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.ocg_list_json().stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_list_json`.
pub fn pdf_ocg_list_json(document : PdfDocument) -> Json raise PdfError {
  document.ocg_list_json()
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_list_json_blob`.
pub fn pdf_ocg_list_json_blob(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.ocg_list_json_blob()
}

///|
fn pdf_ocg_read_json_field(
  entries : Map[String, Json],
  key : String,
  message : String,
) -> Json raise PdfError {
  match entries.get(key) {
    Some(value) => value
    None => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_pdf_string(
  json : Json,
  message : String,
) -> PdfBytes raise PdfError {
  match json {
    String(text) => pdf_pdfdocstring_of_utf8(@utf8.encode(text))
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_optional_pdf_string(
  json : Json,
  message : String,
) -> PdfBytes? raise PdfError {
  match json {
    Null => None
    String(text) => Some(pdf_pdfdocstring_of_utf8(@utf8.encode(text)))
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_name_text(text : String) -> PdfName {
  pdf_name_of_bytes(@utf8.encode(text))
}

///|
fn pdf_ocg_read_json_name(
  json : Json,
  message : String,
) -> PdfName raise PdfError {
  match json {
    String(text) => pdf_ocg_read_json_name_text(text)
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_optional_name(
  json : Json,
  message : String,
) -> PdfName? raise PdfError {
  match json {
    Null => None
    String(text) => Some(pdf_ocg_read_json_name_text(text))
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_optional_number(
  json : Json,
  message : String,
) -> Double? raise PdfError {
  match json {
    Null => None
    Number(value, repr=_) => Some(value)
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_int(json : Json, message : String) -> Int raise PdfError {
  match json {
    Number(value, repr=_) => pdf_util_json_truncated_number(value)
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_ints(
  json : Json,
  message : String,
) -> Array[Int] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[Int] = []
      for value in values {
        output.push(pdf_ocg_read_json_int(value, message))
      }
      output
    }
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_names(
  json : Json,
  message : String,
) -> Array[PdfName] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[PdfName] = []
      for value in values {
        output.push(pdf_ocg_read_json_name(value, message))
      }
      output
    }
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_pdf_strings(
  json : Json,
  message : String,
) -> Array[PdfBytes] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[PdfBytes] = []
      for value in values {
        output.push(pdf_ocg_read_json_pdf_string(value, message))
      }
      output
    }
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_state(
  json : Json,
  message : String,
) -> PdfOcgState raise PdfError {
  match json {
    String("/ON") => OcgOn
    String("/OFF") => OcgOff
    String("/Unchanged") => OcgUnchanged
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_list_mode(
  json : Json,
  message : String,
) -> PdfOcgListMode raise PdfError {
  match json {
    String("/AllPages") => OcgAllPages
    String("/VisiblePages") => OcgVisiblePages
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_event(
  json : Json,
  message : String,
) -> PdfOcgEvent raise PdfError {
  match json {
    String("/View") => OcgView
    String("/Print") => OcgPrint
    String("/Export") => OcgExport
    _ => raise SoftError(message)
  }
}

///|
fn pdf_ocg_read_json_usage(json : Json) -> PdfOcgUsage? raise PdfError {
  match json {
    Null => None
    Object(entries) if entries.length() == 13 => {
      let cc = pdf_ocg_read_json_field(
        entries, "CreatorInfo-Creator", "ocg_read_usage: malformed",
      )
      let cs = pdf_ocg_read_json_field(
        entries, "CreatorInfo-Subtype", "ocg_read_usage: malformed",
      )
      let ll = pdf_ocg_read_json_field(
        entries, "Language-Language", "ocg_read_usage: malformed",
      )
      let lp = pdf_ocg_read_json_field(
        entries, "Language-Preferred", "ocg_read_usage: malformed",
      )
      let e = pdf_ocg_read_json_field(
        entries, "Export", "ocg_read_usage: malformed",
      )
      let zmin = pdf_ocg_read_json_field(
        entries, "Zoom-Min", "ocg_read_usage: malformed",
      )
      let zmax = pdf_ocg_read_json_field(
        entries, "Zoom-Max", "ocg_read_usage: malformed",
      )
      let ps = pdf_ocg_read_json_field(
        entries, "Print-Subtype", "ocg_read_usage: malformed",
      )
      let pp = pdf_ocg_read_json_field(
        entries, "Print-PrintState", "ocg_read_usage: malformed",
      )
      let vs = pdf_ocg_read_json_field(
        entries, "ViewState", "ocg_read_usage: malformed",
      )
      let ut = pdf_ocg_read_json_field(
        entries, "User-Type", "ocg_read_usage: malformed",
      )
      let un = pdf_ocg_read_json_field(
        entries, "User-Name", "ocg_read_usage: malformed",
      )
      let pes = pdf_ocg_read_json_field(
        entries, "PageElement-Subtype", "ocg_read_usage: malformed",
      )
      let creator_info = match (cc, cs) {
        (Null, Null) => None
        (String(creator), String(subtype)) =>
          Some(
            (
              pdf_pdfdocstring_of_utf8(@utf8.encode(creator)),
              pdf_ocg_read_json_name_text(subtype),
            ),
          )
        _ => raise SoftError("ocg_read_usage: malformed creator info")
      }
      let language = match (ll, lp) {
        (Null, Null) => None
        (String(language), String(preferred)) =>
          Some(
            (
              pdf_pdfdocstring_of_utf8(@utf8.encode(language)),
              Some(pdf_ocg_read_json_name_text(preferred)),
            ),
          )
        (String(language), Null) =>
          Some((pdf_pdfdocstring_of_utf8(@utf8.encode(language)), None))
        _ => raise SoftError("ocg_read_usage: malformed language")
      }
      let user = match (ut, un) {
        (Null, Null) => None
        (String(user_type), Array(_)) =>
          Some(
            (
              pdf_ocg_read_json_name_text(user_type),
              pdf_ocg_read_json_pdf_strings(
                un, "ocg_read_usage: malformed user",
              ),
            ),
          )
        _ => raise SoftError("ocg_read_usage: malformed user")
      }
      Some({
        creator_info,
        language,
        export_state: pdf_ocg_read_json_optional_name(
          e, "ocg_read_usage: malformed export",
        ),
        zoom_min: pdf_ocg_read_json_optional_number(
          zmin, "ocg_read_usage: malformed zoom min",
        ),
        zoom_max: pdf_ocg_read_json_optional_number(
          zmax, "ocg_read_usage: malformed zoom max",
        ),
        print_subtype: pdf_ocg_read_json_optional_name(
          ps, "ocg_read_usage: malformed print subtype",
        ),
        print_state: pdf_ocg_read_json_optional_name(
          pp, "ocg_read_usage: malformed print printstate",
        ),
        view_state: pdf_ocg_read_json_optional_name(
          vs, "ocg_read_usage: malformed print viewstate",
        ),
        user,
        page_element_subtype: pdf_ocg_read_json_optional_name(
          pes, "ocg_read_usage: malformed subtype",
        ),
      })
    }
    _ => raise SoftError("ocg_read_usage: malformed")
  }
}

///|
fn pdf_ocg_read_json_order_item(
  json : Json,
) -> (PdfBytes?, Array[Int]) raise PdfError {
  match json {
    Object(entries) if entries.length() == 2 => {
      let name = pdf_ocg_read_json_optional_pdf_string(
        pdf_ocg_read_json_field(
          entries, "Name", "ocg_read_config: malformed order pair",
        ),
        "ocg_read_config: malformed order name",
      )
      let ocgs = pdf_ocg_read_json_ints(
        pdf_ocg_read_json_field(
          entries, "OCGs", "ocg_read_config: malformed order pair",
        ),
        "ocg_read_config: malformed order ocg",
      )
      (name, ocgs)
    }
    _ => raise SoftError("ocg_read_config: malformed order pair")
  }
}

///|
fn pdf_ocg_read_json_order(
  json : Json,
) -> Array[(PdfBytes?, Array[Int])]? raise PdfError {
  match json {
    Null => None
    Array(values) => {
      let output : Array[(PdfBytes?, Array[Int])] = []
      for value in values {
        output.push(pdf_ocg_read_json_order_item(value))
      }
      Some(output)
    }
    _ => raise SoftError("ocg_read_config: malformed order")
  }
}

///|
fn pdf_ocg_read_json_radio_groups(
  json : Json,
) -> Array[Array[Int]]? raise PdfError {
  match json {
    Null => None
    Array(values) => {
      let output : Array[Array[Int]] = []
      for value in values {
        output.push(
          pdf_ocg_read_json_ints(value, "ocg_read_config: bad rbgroups"),
        )
      }
      Some(output)
    }
    _ => raise SoftError("ocg_read_config: bad rbgroups")
  }
}

///|
fn pdf_ocg_read_json_appdict(json : Json) -> PdfOcgAppDict? raise PdfError {
  match json {
    Null => None
    Object(entries) if entries.length() == 3 => {
      let event = pdf_ocg_read_json_event(
        pdf_ocg_read_json_field(entries, "Event", "ocg_read_appdict: malformed"),
        "ocg_read_appdict: bad event",
      )
      let ocgs = pdf_ocg_read_json_ints(
        pdf_ocg_read_json_field(entries, "OCGs", "ocg_read_appdict: malformed"),
        "ocg_read_appdict: bad ocg",
      )
      let category = pdf_ocg_read_json_names(
        pdf_ocg_read_json_field(
          entries, "Category", "ocg_read_appdict: malformed",
        ),
        "ocg_read_ocg: bad category",
      )
      Some({ event, ocgs, category })
    }
    _ => raise SoftError("ocg_read_appdict: malformed")
  }
}

///|
fn pdf_ocg_read_json_appdicts(
  json : Json,
) -> Array[PdfOcgAppDict] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[PdfOcgAppDict] = []
      for value in values {
        match pdf_ocg_read_json_appdict(value) {
          Some(appdict) => output.push(appdict)
          None => ()
        }
      }
      output
    }
    _ =>
      raise SoftError(
        "ocg_read_config: malformed usage application dictionary list",
      )
  }
}

///|
fn pdf_ocg_read_json_config(json : Json) -> PdfOcgConfig raise PdfError {
  match json {
    Object(entries) if entries.length() == 11 => {
      let n = pdf_ocg_read_json_field(
        entries, "Name", "ocg_read_config: malformed",
      )
      let c = pdf_ocg_read_json_field(
        entries, "Creator", "ocg_read_config: malformed",
      )
      let bs = pdf_ocg_read_json_field(
        entries, "BaseState", "ocg_read_config: malformed",
      )
      let on = pdf_ocg_read_json_field(
        entries, "ON", "ocg_read_config: malformed",
      )
      let off = pdf_ocg_read_json_field(
        entries, "OFF", "ocg_read_config: malformed",
      )
      let i = pdf_ocg_read_json_field(
        entries, "Intent", "ocg_read_config: malformed",
      )
      let a = pdf_ocg_read_json_field(
        entries, "AS", "ocg_read_config: malformed",
      )
      let o = pdf_ocg_read_json_field(
        entries, "Order", "ocg_read_config: malformed",
      )
      let lm = pdf_ocg_read_json_field(
        entries, "ListMode", "ocg_read_config: malformed",
      )
      let rb = pdf_ocg_read_json_field(
        entries, "RBGroups", "ocg_read_config: malformed",
      )
      let l = pdf_ocg_read_json_field(
        entries, "Locked", "ocg_read_config: malformed",
      )
      {
        name: pdf_ocg_read_json_optional_pdf_string(
          n, "ocg_read_config: malformed name",
        ),
        creator: pdf_ocg_read_json_optional_pdf_string(
          c, "ocg_read_config: malformed creator",
        ),
        base_state: pdf_ocg_read_json_state(
          bs, "ocg_read_config: malformed base state",
        ),
        on: pdf_ocg_read_json_ints(on, "ocg_read_config: malformed on"),
        off: pdf_ocg_read_json_ints(off, "ocg_read_config: malformed off"),
        intent: pdf_ocg_read_json_names(i, "ocg_read_config: malformed intent"),
        usage_applications: pdf_ocg_read_json_appdicts(a),
        order: pdf_ocg_read_json_order(o),
        list_mode: pdf_ocg_read_json_list_mode(
          lm, "ocg_read_config: malformed list mode",
        ),
        radio_button_groups: pdf_ocg_read_json_radio_groups(rb),
        locked: pdf_ocg_read_json_ints(l, "ocg_read_config: malformed locked"),
      }
    }
    _ => raise SoftError("ocg_read_config: malformed")
  }
}

///|
fn pdf_ocg_read_json_ocg(json : Json) -> PdfOcg raise PdfError {
  match json {
    Object(entries) if entries.length() == 3 => {
      let intent = pdf_ocg_read_json_field(
        entries, "Intent", "ocg_read_ocg: malformed",
      )
      let name = pdf_ocg_read_json_field(
        entries, "Name", "ocg_read_ocg: malformed",
      )
      let usage = pdf_ocg_read_json_field(
        entries, "Usage", "ocg_read_ocg: malformed",
      )
      {
        name: pdf_ocg_read_json_pdf_string(name, "ocg_read_ocg: malformed"),
        intent: pdf_ocg_read_json_names(
          intent, "ocg_read_ocg: malformed intent",
        ),
        usage: pdf_ocg_read_json_usage(usage),
      }
    }
    _ => raise SoftError("ocg_read_ocg: malformed")
  }
}

///|
fn pdf_ocg_read_json_ocgs(json : Json) -> Array[(Int, PdfOcg)] raise PdfError {
  match json {
    Object(entries) => {
      let output : Array[(Int, PdfOcg)] = []
      for entry in entries {
        let number : Int = @strconv.from_str(entry.0) catch {
          _ =>
            raise SoftError(
              "ocg_read_json: malformed JSON top-level dictionary",
            )
        }
        output.push((number, pdf_ocg_read_json_ocg(entry.1)))
      }
      output
    }
    _ => raise SoftError("ocg_read_json: malformed JSON top-level dictionary")
  }
}

///|
fn pdf_ocg_read_json_configs(json : Json) -> Array[PdfOcgConfig] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[PdfOcgConfig] = []
      for value in values {
        output.push(pdf_ocg_read_json_config(value))
      }
      output
    }
    _ => raise SoftError("ocg_read_json: malformed JSON top-level dictionary")
  }
}

///|
/// Parse cpdf's optional-content group JSON representation.
pub fn pdf_ocg_read_json(json : Json) -> PdfOptionalContent? raise PdfError {
  match json {
    Null => None
    Object(entries) if entries.length() == 3 => {
      let ocgs = pdf_ocg_read_json_field(
        entries, "OCGs", "ocg_read_json: malformed JSON top-level dictionary",
      )
      let default = pdf_ocg_read_json_field(
        entries, "Default", "ocg_read_json: malformed JSON top-level dictionary",
      )
      let configs = pdf_ocg_read_json_field(
        entries, "Configs", "ocg_read_json: malformed JSON top-level dictionary",
      )
      Some({
        ocgs: pdf_ocg_read_json_ocgs(ocgs),
        default_config: pdf_ocg_read_json_config(default),
        configs: pdf_ocg_read_json_configs(configs),
      })
    }
    Object(_) =>
      raise SoftError("ocg_read_json: malformed JSON top-level dictionary")
    _ => raise SoftError("ocg_read_json: malformed JSON top-level")
  }
}

///|
/// Return a copy with catalog `/OCProperties` replaced from cpdf OCG JSON.
pub fn PdfDocument::ocg_replace_json(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  match pdf_ocg_read_json(json) {
    None => self.copy()
    Some(content) => self.write_optional_content_groups(content)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_replace_json`.
pub fn pdf_ocg_replace_json(
  json : Json,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.ocg_replace_json(json)
}

///|
/// Return a copy of the document with matching optional-content group names
/// replaced.
pub fn PdfDocument::ocg_rename(
  self : PdfDocument,
  old_name : PdfBytes,
  new_name : PdfBytes,
) -> PdfDocument {
  let pdf = self.copy()
  pdf.map_objects_in_place(fn(object) {
    match object {
      PdfDictionary(entries) =>
        match
          (
            pdf.lookup_direct(pdf_ocg_type_key(), object),
            pdf.lookup_direct(pdf_ocg_name_key(), object),
          ) {
          (Some(PdfNameObject(kind)), Some(PdfString(name))) =>
            if kind == pdf_ocg_ocg_name() && name == old_name {
              PdfDictionary(
                dict_add_entries(
                  entries,
                  pdf_ocg_name_key(),
                  PdfString(new_name),
                ),
              )
            } else {
              object
            }
          _ => object
        }
      _ => object
    }
  })
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_rename`.
pub fn pdf_ocg_rename(
  old_name : PdfBytes,
  new_name : PdfBytes,
  document : PdfDocument,
) -> PdfDocument {
  document.ocg_rename(old_name, new_name)
}

///|
/// Return a copy of the document with every OCG listed in the default `/Order`.
///
/// Documents without optional-content properties, without `/OCGs`, or without a
/// default `/D` dictionary are returned unchanged.
pub fn PdfDocument::ocg_order_all(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  match self.lookup_direct(pdf_ocg_ocproperties_key(), root) {
    None => self.copy()
    Some(ocproperties) =>
      match
        (
          self.lookup_direct(pdf_ocg_ocgs_key(), ocproperties),
          self.lookup_direct(pdf_ocg_d_key(), ocproperties),
        ) {
        (Some(PdfArray(ocgs)), Some(PdfDictionary(_))) => {
          let pdf = self.copy()
          let default_config = self
            .lookup_direct(pdf_ocg_d_key(), ocproperties)
            .unwrap()
            .add_dict_entry(pdf_ocg_order_key(), PdfArray(ocgs.copy()))
          let new_ocproperties = ocproperties.add_dict_entry(
            pdf_ocg_d_key(),
            default_config,
          )
          let ocproperties_number = pdf.add_object(new_ocproperties)
          let new_root = pdf.add_object(
            root.add_dict_entry(
              pdf_ocg_ocproperties_key(),
              PdfIndirect(ocproperties_number),
            ),
          )
          pdf.set_root(new_root)
          pdf.set_trailer_dict(
            pdf
            .trailer_dict()
            .add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
          )
          pdf
        }
        _ => self.copy()
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_order_all`.
pub fn pdf_ocg_order_all(document : PdfDocument) -> PdfDocument raise PdfError {
  document.ocg_order_all()
}

///|
fn pdf_ocg_copy_usage(usage : PdfOcgUsage) -> PdfOcgUsage {
  {
    creator_info: usage.creator_info,
    language: usage.language,
    export_state: usage.export_state,
    zoom_min: usage.zoom_min,
    zoom_max: usage.zoom_max,
    print_subtype: usage.print_subtype,
    print_state: usage.print_state,
    view_state: usage.view_state,
    user: match usage.user {
      Some((user_type, names)) => Some((user_type, names.copy()))
      None => None
    },
    page_element_subtype: usage.page_element_subtype,
  }
}

///|
fn pdf_ocg_copy_ocg(ocg : PdfOcg) -> PdfOcg {
  {
    name: ocg.name,
    intent: ocg.intent.copy(),
    usage: match ocg.usage {
      Some(usage) => Some(pdf_ocg_copy_usage(usage))
      None => None
    },
  }
}

///|
fn pdf_ocg_copy_order(
  order : ArrayView[(PdfBytes?, Array[Int])],
) -> Array[(PdfBytes?, Array[Int])] {
  [
    for item in order => (item.0, item.1.copy())
  ]
}

///|
fn pdf_ocg_copy_groups(groups : ArrayView[Array[Int]]) -> Array[Array[Int]] {
  [
    for group in groups => group.copy()
  ]
}

///|
fn pdf_ocg_copy_appdict(appdict : PdfOcgAppDict) -> PdfOcgAppDict {
  {
    event: appdict.event,
    ocgs: appdict.ocgs.copy(),
    category: appdict.category.copy(),
  }
}

///|
fn pdf_ocg_copy_config(config : PdfOcgConfig) -> PdfOcgConfig {
  {
    name: config.name,
    creator: config.creator,
    base_state: config.base_state,
    on: config.on.copy(),
    off: config.off.copy(),
    intent: config.intent.copy(),
    usage_applications: [
      for appdict in config.usage_applications => pdf_ocg_copy_appdict(appdict)
    ],
    order: match config.order {
      Some(order) => Some(pdf_ocg_copy_order(order))
      None => None
    },
    list_mode: config.list_mode,
    radio_button_groups: match config.radio_button_groups {
      Some(groups) => Some(pdf_ocg_copy_groups(groups))
      None => None
    },
    locked: config.locked.copy(),
  }
}

///|
/// Merge optional-content metadata from already-renumbered documents.
///
/// Documents without optional content are skipped. Indirect object numbers are
/// copied as-is into the merged result, so callers must renumber source
/// documents before merging when object numbers may collide.
pub fn pdf_optional_content_merge(
  documents : ArrayView[PdfDocument],
) -> PdfOptionalContent? raise PdfError {
  let contents : Array[PdfOptionalContent] = []
  for document in documents {
    match document.read_optional_content_groups() {
      Some(content) => contents.push(content)
      None => ()
    }
  }
  if contents.length() == 0 {
    None
  } else {
    let ocgs : Array[(Int, PdfOcg)] = []
    let configs : Array[PdfOcgConfig] = []
    let on : Array[Int] = []
    let off : Array[Int] = []
    let order : Array[(PdfBytes?, Array[Int])] = []
    let radio_button_groups : Array[Array[Int]] = []
    let mut has_order = false
    let mut has_radio_button_groups = false
    let mut name : PdfBytes? = None
    let mut creator : PdfBytes? = None
    let mut base_state = OcgOn
    let mut intent : Array[PdfName] = []
    let mut usage_applications : Array[PdfOcgAppDict] = []
    let mut list_mode = OcgAllPages
    let mut locked : Array[Int] = []
    for content in contents {
      for entry in content.ocgs {
        ocgs.push((entry.0, pdf_ocg_copy_ocg(entry.1)))
      }
      for config in content.configs {
        configs.push(pdf_ocg_copy_config(config))
      }
      let default_config = content.default_config
      for number in default_config.on {
        on.push(number)
      }
      for number in default_config.off {
        off.push(number)
      }
      match default_config.order {
        Some(items) => {
          has_order = true
          for item in pdf_ocg_copy_order(items) {
            order.push(item)
          }
        }
        None => ()
      }
      match default_config.radio_button_groups {
        Some(groups) => {
          has_radio_button_groups = true
          for group in pdf_ocg_copy_groups(groups) {
            radio_button_groups.push(group)
          }
        }
        None => ()
      }
      if name is None {
        name = default_config.name
      }
      if creator is None {
        creator = default_config.creator
      }
      if base_state == OcgOn && default_config.base_state != OcgOn {
        base_state = default_config.base_state
      }
      if intent.length() == 0 && default_config.intent.length() > 0 {
        intent = default_config.intent.copy()
      }
      if usage_applications.length() == 0 &&
        default_config.usage_applications.length() > 0 {
        usage_applications = [
          for appdict in default_config.usage_applications => {
            pdf_ocg_copy_appdict(appdict)
          }
        ]
      }
      if list_mode == OcgAllPages && default_config.list_mode != OcgAllPages {
        list_mode = default_config.list_mode
      }
      if locked.length() == 0 && default_config.locked.length() > 0 {
        locked = default_config.locked.copy()
      }
    }
    Some({
      ocgs,
      default_config: {
        name,
        creator,
        base_state,
        on,
        off,
        intent,
        usage_applications,
        order: if has_order {
          Some(order)
        } else {
          None
        },
        list_mode,
        radio_button_groups: if has_radio_button_groups {
          Some(radio_button_groups)
        } else {
          None
        },
        locked,
      },
      configs,
    })
  }
}

///|
fn pdf_ocg_representative_number(
  representatives : ArrayView[(PdfBytes, Int)],
  name : PdfBytes,
) -> Int? {
  for representative in representatives {
    if representative.0 == name {
      break Some(representative.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_ocg_changed_number(changes : ArrayView[(Int, Int)], number : Int) -> Int {
  for change in changes {
    if change.0 == number {
      break change.1
    }
  } nobreak {
    number
  }
}

///|
fn pdf_ocg_push_unique_number(output : Array[Int], number : Int) -> Unit {
  if !output.contains(number) {
    output.push(number)
  }
}

///|
fn pdf_ocg_coalesce_numbers(
  changes : ArrayView[(Int, Int)],
  numbers : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = []
  for number in numbers {
    pdf_ocg_push_unique_number(output, pdf_ocg_changed_number(changes, number))
  }
  output
}

///|
fn pdf_ocg_coalesce_order(
  changes : ArrayView[(Int, Int)],
  order : ArrayView[(PdfBytes?, Array[Int])],
) -> Array[(PdfBytes?, Array[Int])] {
  let output : Array[(PdfBytes?, Array[Int])] = []
  let seen : Array[Int] = []
  for item in order {
    let numbers : Array[Int] = []
    for number in item.1 {
      let changed = pdf_ocg_changed_number(changes, number)
      if !seen.contains(changed) {
        seen.push(changed)
        numbers.push(changed)
      }
    }
    if numbers.length() > 0 {
      output.push((item.0, numbers))
    }
  }
  output
}

///|
fn pdf_ocg_coalesce_appdict(
  changes : ArrayView[(Int, Int)],
  appdict : PdfOcgAppDict,
) -> PdfOcgAppDict {
  { ..appdict, ocgs: pdf_ocg_coalesce_numbers(changes, appdict.ocgs) }
}

///|
fn pdf_ocg_coalesce_config(
  changes : ArrayView[(Int, Int)],
  config : PdfOcgConfig,
) -> PdfOcgConfig {
  {
    ..config,
    on: pdf_ocg_coalesce_numbers(changes, config.on),
    off: pdf_ocg_coalesce_numbers(changes, config.off),
    usage_applications: [
      for appdict in config.usage_applications => {
        pdf_ocg_coalesce_appdict(changes, appdict)
      }
    ],
    order: match config.order {
      Some(order) => Some(pdf_ocg_coalesce_order(changes, order))
      None => None
    },
    radio_button_groups: match config.radio_button_groups {
      Some(groups) =>
        Some(
          [
            for group in groups => pdf_ocg_coalesce_numbers(changes, group)
          ],
        )
      None => None
    },
    locked: pdf_ocg_coalesce_numbers(changes, config.locked),
  }
}

///|
fn pdf_ocg_coalesce_content(
  content : PdfOptionalContent,
) -> (PdfOptionalContent, Array[(Int, Int)]) {
  let representatives : Array[(PdfBytes, Int)] = []
  let ocgs : Array[(Int, PdfOcg)] = []
  let changes : Array[(Int, Int)] = []
  for entry in content.ocgs {
    let (number, ocg) = entry
    match pdf_ocg_representative_number(representatives, ocg.name) {
      Some(representative) =>
        if representative != number {
          changes.push((number, representative))
        }
      None => {
        representatives.push((ocg.name, number))
        ocgs.push((number, pdf_ocg_copy_ocg(ocg)))
      }
    }
  }
  (
    {
      ocgs,
      default_config: pdf_ocg_coalesce_config(changes, content.default_config),
      configs: [
        for config in content.configs => {
          pdf_ocg_coalesce_config(changes, config)
        }
      ],
    },
    changes,
  )
}

///|
/// Return a copy with same-named optional-content groups coalesced.
///
/// The first group for each raw PDF name is kept. Duplicate group references in
/// optional-content metadata and parsed document objects are rewritten to the
/// kept object number, and duplicate OCG objects are removed.
pub fn PdfDocument::ocg_coalesce(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  match self.read_optional_content_groups() {
    None => self.copy()
    Some(content) => {
      let (coalesced, changes) = pdf_ocg_coalesce_content(content)
      if changes.length() == 0 {
        self.copy()
      } else {
        let pdf = self.write_optional_content_groups(coalesced)
        pdf.pdf_page_renumber_references(changes)
        for change in changes {
          pdf.remove_object(change.0)
        }
        pdf
      }
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_coalesce`.
pub fn pdf_ocg_coalesce(document : PdfDocument) -> PdfDocument raise PdfError {
  document.ocg_coalesce()
}

///|
fn pdf_ocg_name_array_object(names : ArrayView[PdfName]) -> PdfObject {
  PdfArray([ for name in names => PdfNameObject(name) ])
}

///|
fn pdf_ocg_indirect_array_object(numbers : ArrayView[Int]) -> PdfObject {
  PdfArray([ for number in numbers => PdfIndirect(number) ])
}

///|
fn pdf_ocg_string_array_object(strings : ArrayView[PdfBytes]) -> PdfObject {
  PdfArray([ for string in strings => PdfString(string) ])
}

///|
fn pdf_ocg_write_appdict(appdict : PdfOcgAppDict) -> PdfObject {
  let event_name = match appdict.event {
    OcgView => pdf_ocg_view_name()
    OcgPrint => pdf_ocg_print_name()
    OcgExport => pdf_ocg_export_name()
  }
  PdfDictionary([
    (pdf_ocg_event_key(), PdfNameObject(event_name)),
    (pdf_ocg_ocgs_key(), pdf_ocg_indirect_array_object(appdict.ocgs)),
    (pdf_ocg_category_key(), pdf_ocg_name_array_object(appdict.category)),
  ])
}

///|
fn PdfDocument::pdf_ocg_write_usage(
  self : PdfDocument,
  usage : PdfOcgUsage,
) -> Int {
  let entries : Array[(PdfName, PdfObject)] = []
  match usage.creator_info {
    Some((creator, subtype)) =>
      entries.push(
        (
          pdf_ocg_creatorinfo_key(),
          PdfDictionary([
            (pdf_ocg_creator_key(), PdfString(creator)),
            (pdf_ocg_subtype_key(), PdfNameObject(subtype)),
          ]),
        ),
      )
    None => ()
  }
  match usage.language {
    Some((lang, None)) =>
      entries.push(
        (
          pdf_ocg_language_key(),
          PdfDictionary([(pdf_ocg_lang_key(), PdfString(lang))]),
        ),
      )
    Some((lang, Some(preferred))) =>
      entries.push(
        (
          pdf_ocg_language_key(),
          PdfDictionary([
            (pdf_ocg_lang_key(), PdfString(lang)),
            (pdf_ocg_preferred_key(), PdfNameObject(preferred)),
          ]),
        ),
      )
    None => ()
  }
  match usage.export_state {
    Some(state) =>
      entries.push(
        (
          pdf_ocg_export_key(),
          PdfDictionary([(pdf_ocg_export_state_key(), PdfNameObject(state))]),
        ),
      )
    None => ()
  }
  match (usage.zoom_min, usage.zoom_max) {
    (Some(min), Some(max)) =>
      entries.push(
        (
          pdf_ocg_zoom_key(),
          PdfDictionary([
            (pdf_ocg_min_key(), PdfReal(min)),
            (pdf_ocg_max_key(), PdfReal(max)),
          ]),
        ),
      )
    (Some(min), None) =>
      entries.push(
        (pdf_ocg_zoom_key(), PdfDictionary([(pdf_ocg_min_key(), PdfReal(min))])),
      )
    (None, Some(max)) =>
      entries.push(
        (pdf_ocg_zoom_key(), PdfDictionary([(pdf_ocg_max_key(), PdfReal(max))])),
      )
    _ => ()
  }
  match (usage.print_subtype, usage.print_state) {
    (Some(subtype), Some(state)) =>
      entries.push(
        (
          pdf_ocg_print_key(),
          PdfDictionary([
            (pdf_ocg_subtype_key(), PdfNameObject(subtype)),
            (pdf_ocg_print_state_key(), PdfNameObject(state)),
          ]),
        ),
      )
    (Some(subtype), None) =>
      entries.push(
        (
          pdf_ocg_print_key(),
          PdfDictionary([(pdf_ocg_subtype_key(), PdfNameObject(subtype))]),
        ),
      )
    (None, Some(state)) =>
      entries.push(
        (
          pdf_ocg_print_key(),
          PdfDictionary([(pdf_ocg_print_state_key(), PdfNameObject(state))]),
        ),
      )
    _ => ()
  }
  match usage.view_state {
    Some(state) =>
      entries.push(
        (
          pdf_ocg_view_key(),
          PdfDictionary([(pdf_ocg_view_state_key(), PdfNameObject(state))]),
        ),
      )
    None => ()
  }
  match usage.user {
    Some((user_type, names)) =>
      entries.push(
        (
          pdf_ocg_user_key(),
          PdfDictionary([
            (pdf_ocg_type_key(), PdfNameObject(user_type)),
            (pdf_ocg_name_key(), pdf_ocg_string_array_object(names)),
          ]),
        ),
      )
    None => ()
  }
  match usage.page_element_subtype {
    Some(subtype) =>
      entries.push(
        (
          pdf_ocg_page_element_key(),
          PdfDictionary([(pdf_ocg_subtype_key(), PdfNameObject(subtype))]),
        ),
      )
    None => ()
  }
  self.add_object(PdfDictionary(entries))
}

///|
fn PdfDocument::pdf_ocg_write_config(
  self : PdfDocument,
  config : PdfOcgConfig,
) -> Int {
  let entries : Array[(PdfName, PdfObject)] = []
  match config.name {
    Some(name) => entries.push((pdf_ocg_name_key(), PdfString(name)))
    None => ()
  }
  match config.creator {
    Some(creator) => entries.push((pdf_ocg_creator_key(), PdfString(creator)))
    None => ()
  }
  match config.base_state {
    OcgOn => ()
    OcgOff =>
      entries.push(
        (pdf_ocg_base_state_key(), PdfNameObject(pdf_ocg_off_name())),
      )
    OcgUnchanged =>
      entries.push(
        (pdf_ocg_base_state_key(), PdfNameObject(pdf_ocg_unchanged_name())),
      )
  }
  if config.on.length() > 0 {
    entries.push((pdf_ocg_on_key(), pdf_ocg_indirect_array_object(config.on)))
  }
  if config.off.length() > 0 {
    entries.push((pdf_ocg_off_key(), pdf_ocg_indirect_array_object(config.off)))
  }
  if config.intent.length() > 0 {
    entries.push(
      (pdf_ocg_intent_key(), pdf_ocg_name_array_object(config.intent)),
    )
  }
  if config.usage_applications.length() > 0 {
    entries.push(
      (
        pdf_ocg_as_key(),
        PdfArray(
          [
            for appdict in config.usage_applications => {
              pdf_ocg_write_appdict(appdict)
            }
          ],
        ),
      ),
    )
  }
  match config.order {
    Some(order) => {
      let order_objects : Array[PdfObject] = []
      for item in order {
        let (label, numbers) = item
        match label {
          None =>
            if numbers.length() == 1 {
              order_objects.push(PdfIndirect(numbers[0]))
            } else {
              order_objects.push(pdf_ocg_indirect_array_object(numbers))
            }
          Some(label) => {
            let children : Array[PdfObject] = [PdfString(label)]
            for number in numbers {
              children.push(PdfIndirect(number))
            }
            order_objects.push(PdfArray(children))
          }
        }
      }
      entries.push((pdf_ocg_order_key(), PdfArray(order_objects)))
    }
    None => ()
  }
  match config.list_mode {
    OcgAllPages => ()
    OcgVisiblePages =>
      entries.push(
        (pdf_ocg_list_mode_key(), PdfNameObject(pdf_ocg_visible_pages_name())),
      )
  }
  match config.radio_button_groups {
    Some(groups) =>
      entries.push(
        (
          pdf_ocg_rb_groups_key(),
          PdfArray(
            [
              for group in groups => pdf_ocg_indirect_array_object(group)
            ],
          ),
        ),
      )
    None => ()
  }
  if config.locked.length() > 0 {
    entries.push(
      (pdf_ocg_locked_key(), pdf_ocg_indirect_array_object(config.locked)),
    )
  }
  self.add_object(PdfDictionary(entries))
}

///|
fn PdfDocument::pdf_ocg_write_ocg(
  self : PdfDocument,
  ocg : PdfOcg,
) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_ocg_type_key(), PdfNameObject(pdf_ocg_ocg_name())),
    (pdf_ocg_name_key(), PdfString(ocg.name)),
    (pdf_ocg_intent_key(), pdf_ocg_name_array_object(ocg.intent)),
  ]
  match ocg.usage {
    Some(usage) =>
      entries.push(
        (pdf_ocg_usage_key(), PdfIndirect(self.pdf_ocg_write_usage(usage))),
      )
    None => ()
  }
  PdfDictionary(entries)
}

///|
/// Return a copy of the document with catalog `/OCProperties` removed.
///
/// The original document is not mutated; the returned document receives a new
/// root object and trailer root reference.
pub fn PdfDocument::remove_optional_content_groups(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  let pdf = self.copy()
  let root_without_ocproperties = root.remove_dict_entry(
    pdf_ocg_ocproperties_key(),
  )
  let new_root = pdf.add_object(root_without_ocproperties)
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf.trailer_dict().add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::remove_optional_content_groups`.
pub fn pdf_remove_ocg(document : PdfDocument) -> PdfDocument raise PdfError {
  document.remove_optional_content_groups()
}

///|
/// Return a copy of the document with catalog `/OCProperties` replaced.
///
/// OCG dictionaries are written using the object numbers stored in
/// `optional_content.ocgs`. Configuration dictionaries are added as new
/// objects, and the original document is left unchanged.
pub fn PdfDocument::write_optional_content_groups(
  self : PdfDocument,
  optional_content : PdfOptionalContent,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  let pdf = self.copy()
  for entry in optional_content.ocgs {
    let (number, ocg) = entry
    pdf.add_object_given_number(number, pdf.pdf_ocg_write_ocg(ocg))
  }
  let ocg_array_number = pdf.add_object(
    PdfArray([ for entry in optional_content.ocgs => PdfIndirect(entry.0) ]),
  )
  let default_number = pdf.pdf_ocg_write_config(optional_content.default_config)
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_ocg_ocgs_key(), PdfIndirect(ocg_array_number)),
    (pdf_ocg_d_key(), PdfIndirect(default_number)),
  ]
  if optional_content.configs.length() > 0 {
    let configs_number = pdf.add_object(
      PdfArray(
        [
          for config in optional_content.configs => {
            PdfIndirect(pdf.pdf_ocg_write_config(config))
          }
        ],
      ),
    )
    entries.push((pdf_ocg_configs_key(), PdfIndirect(configs_number)))
  }
  let ocproperties_number = pdf.add_object(PdfDictionary(entries))
  let new_root = pdf.add_object(
    root.add_dict_entry(
      pdf_ocg_ocproperties_key(),
      PdfIndirect(ocproperties_number),
    ),
  )
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf.trailer_dict().add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::write_optional_content_groups`.
pub fn pdf_write_ocg(
  document : PdfDocument,
  optional_content : PdfOptionalContent,
) -> PdfDocument raise PdfError {
  document.write_optional_content_groups(optional_content)
}

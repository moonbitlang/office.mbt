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

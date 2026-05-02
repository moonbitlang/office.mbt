///|
fn pdf_ocg_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_ocg_root_key() -> PdfName {
  pdf_ocg_name("/Root")
}

///|
fn pdf_ocg_ocproperties_key() -> PdfName {
  pdf_ocg_name("/OCProperties")
}

///|
fn pdf_ocg_ocgs_key() -> PdfName {
  pdf_ocg_name("/OCGs")
}

///|
fn pdf_ocg_d_key() -> PdfName {
  pdf_ocg_name("/D")
}

///|
fn pdf_ocg_configs_key() -> PdfName {
  pdf_ocg_name("/Configs")
}

///|
fn pdf_ocg_type_key() -> PdfName {
  pdf_ocg_name("/Type")
}

///|
fn pdf_ocg_name_key() -> PdfName {
  pdf_ocg_name("/Name")
}

///|
fn pdf_ocg_intent_key() -> PdfName {
  pdf_ocg_name("/Intent")
}

///|
fn pdf_ocg_usage_key() -> PdfName {
  pdf_ocg_name("/Usage")
}

///|
fn pdf_ocg_creatorinfo_key() -> PdfName {
  pdf_ocg_name("/CreatorInfo")
}

///|
fn pdf_ocg_creator_key() -> PdfName {
  pdf_ocg_name("/Creator")
}

///|
fn pdf_ocg_subtype_key() -> PdfName {
  pdf_ocg_name("/Subtype")
}

///|
fn pdf_ocg_language_key() -> PdfName {
  pdf_ocg_name("/Language")
}

///|
fn pdf_ocg_lang_key() -> PdfName {
  pdf_ocg_name("/Lang")
}

///|
fn pdf_ocg_preferred_key() -> PdfName {
  pdf_ocg_name("/Preferred")
}

///|
fn pdf_ocg_export_key() -> PdfName {
  pdf_ocg_name("/Export")
}

///|
fn pdf_ocg_export_state_key() -> PdfName {
  pdf_ocg_name("/ExportState")
}

///|
fn pdf_ocg_zoom_key() -> PdfName {
  pdf_ocg_name("/Zoom")
}

///|
fn pdf_ocg_min_key() -> PdfName {
  pdf_ocg_name("/min")
}

///|
fn pdf_ocg_max_key() -> PdfName {
  pdf_ocg_name("/max")
}

///|
fn pdf_ocg_print_key() -> PdfName {
  pdf_ocg_name("/Print")
}

///|
fn pdf_ocg_print_state_key() -> PdfName {
  pdf_ocg_name("/PrintState")
}

///|
fn pdf_ocg_view_key() -> PdfName {
  pdf_ocg_name("/View")
}

///|
fn pdf_ocg_view_state_key() -> PdfName {
  pdf_ocg_name("/ViewState")
}

///|
fn pdf_ocg_user_key() -> PdfName {
  pdf_ocg_name("/User")
}

///|
fn pdf_ocg_page_element_key() -> PdfName {
  pdf_ocg_name("/PageElement")
}

///|
fn pdf_ocg_event_key() -> PdfName {
  pdf_ocg_name("/Event")
}

///|
fn pdf_ocg_category_key() -> PdfName {
  pdf_ocg_name("/Category")
}

///|
fn pdf_ocg_base_state_key() -> PdfName {
  pdf_ocg_name("/BaseState")
}

///|
fn pdf_ocg_on_key() -> PdfName {
  pdf_ocg_name("/ON")
}

///|
fn pdf_ocg_off_key() -> PdfName {
  pdf_ocg_name("/OFF")
}

///|
fn pdf_ocg_as_key() -> PdfName {
  pdf_ocg_name("/AS")
}

///|
fn pdf_ocg_order_key() -> PdfName {
  pdf_ocg_name("/Order")
}

///|
fn pdf_ocg_list_mode_key() -> PdfName {
  pdf_ocg_name("/ListMode")
}

///|
fn pdf_ocg_rb_groups_key() -> PdfName {
  pdf_ocg_name("/RBGroups")
}

///|
fn pdf_ocg_locked_key() -> PdfName {
  pdf_ocg_name("/Locked")
}

///|
fn pdf_ocg_ocg_name() -> PdfName {
  pdf_ocg_name("/OCG")
}

///|
fn pdf_ocg_view_name() -> PdfName {
  pdf_ocg_name("/View")
}

///|
fn pdf_ocg_print_name() -> PdfName {
  pdf_ocg_name("/Print")
}

///|
fn pdf_ocg_export_name() -> PdfName {
  pdf_ocg_name("/Export")
}

///|
fn pdf_ocg_off_name() -> PdfName {
  pdf_ocg_name("/OFF")
}

///|
fn pdf_ocg_unchanged_name() -> PdfName {
  pdf_ocg_name("/Unchanged")
}

///|
fn pdf_ocg_visible_pages_name() -> PdfName {
  pdf_ocg_name("/VisiblePages")
}

///|
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
pub(all) struct PdfOcg {
  name : PdfBytes
  intent : Array[PdfName]
  usage : PdfOcgUsage?
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfOcgState {
  OcgOn
  OcgOff
  OcgUnchanged
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfOcgListMode {
  OcgAllPages
  OcgVisiblePages
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfOcgEvent {
  OcgView
  OcgPrint
  OcgExport
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfOcgAppDict {
  event : PdfOcgEvent
  ocgs : Array[Int]
  category : Array[PdfName]
} derive(Debug, Eq, ToJson)

///|
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
pub(all) struct PdfOptionalContent {
  ocgs : Array[(Int, PdfOcg)]
  default_config : PdfOcgConfig
  configs : Array[PdfOcgConfig]
} derive(Debug, Eq, ToJson)

///|
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
  match self.trailer_dict().lookup_immediate(pdf_ocg_root_key()) {
    Some(root) =>
      match self.direct(root) {
        PdfNull => raise RootExpected
        catalog => catalog
      }
    None => {
      let root = self.lookup_object_or_null(self.root())
      if root == PdfNull {
        raise RootExpected
      }
      root
    }
  }
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

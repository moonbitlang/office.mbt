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
fn pdf_ocg_json_state(state : @ocg.PdfOcgState) -> Json {
  Json::string(
    match state {
      OcgOn => "/ON"
      OcgOff => "/OFF"
      OcgUnchanged => "/Unchanged"
    },
  )
}

///|
fn pdf_ocg_json_list_mode(mode : @ocg.PdfOcgListMode) -> Json {
  Json::string(
    match mode {
      OcgAllPages => "/AllPages"
      OcgVisiblePages => "/VisiblePages"
    },
  )
}

///|
fn pdf_ocg_json_event(event : @ocg.PdfOcgEvent) -> Json {
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
        Map([
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
fn pdf_ocg_json_appdict(appdict : @ocg.PdfOcgAppDict) -> Json raise PdfError {
  Json::object(
    Map([
      ("Event", pdf_ocg_json_event(appdict.event)),
      ("OCGs", pdf_ocg_json_ints(appdict.ocgs)),
      ("Category", pdf_ocg_json_names(appdict.category)),
    ]),
  )
}

///|
fn pdf_ocg_json_appdicts(
  appdicts : ArrayView[@ocg.PdfOcgAppDict],
) -> Json raise PdfError {
  let output : Array[Json] = []
  for appdict in appdicts {
    output.push(pdf_ocg_json_appdict(appdict))
  }
  Json::array(output)
}

///|
fn pdf_ocg_json_config(config : @ocg.PdfOcgConfig) -> Json raise PdfError {
  Json::object(
    Map([
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
fn pdf_ocg_json_usage(usage : @ocg.PdfOcgUsage) -> Json raise PdfError {
  Json::object(
    Map([
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
fn pdf_ocg_json_optional_usage(
  usage : @ocg.PdfOcgUsage?,
) -> Json raise PdfError {
  match usage {
    Some(usage) => pdf_ocg_json_usage(usage)
    None => Json::null()
  }
}

///|
fn pdf_ocg_json_ocg(ocg : @ocg.PdfOcg) -> Json raise PdfError {
  Json::object(
    Map([
      ("Name", pdf_ocg_json_string(ocg.name)),
      ("Intent", pdf_ocg_json_names(ocg.intent)),
      ("Usage", pdf_ocg_json_optional_usage(ocg.usage)),
    ]),
  )
}

///|
fn pdf_ocg_json_ocgs(
  ocgs : ArrayView[(Int, @ocg.PdfOcg)],
) -> Json raise PdfError {
  let entries : Map[String, Json] = Map([])
  for item in ocgs {
    let (number, ocg) = item
    entries.set(number.to_string(), pdf_ocg_json_ocg(ocg))
  }
  Json::object(entries)
}

///|
fn pdf_ocg_json_configs(
  configs : ArrayView[@ocg.PdfOcgConfig],
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
        Map([
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
/// Return cpdf's optional-content group listing output.
pub fn PdfDocument::ocg_list(
  self : PdfDocument,
  json : Bool,
) -> PdfBytes raise PdfError {
  if json {
    self.ocg_list_json_blob()
  } else {
    let names : Array[PdfBytes] = []
    let mut output_length = 0
    for name in self.ocg_get_list() {
      let text = pdf_utf8_of_pdfdocstring(name)
      output_length += text.length() + 1
      names.push(text)
    }
    let output = Array::make(output_length, b'\n')
    let mut position = 0
    for name in names {
      for byte in name {
        output[position] = byte
        position += 1
      }
      position += 1
    }
    Bytes::from_array(output)
  }
}

///|
/// Compatibility wrapper matching cpdfocg's `ocg_list`.
pub fn pdf_ocg_list(
  json : Bool,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.ocg_list(json)
}

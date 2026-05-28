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

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
fn pdf_ocg_read_json_appdict(json : Json) -> @ocg.PdfOcgAppDict? raise PdfError {
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
) -> Array[@ocg.PdfOcgAppDict] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[@ocg.PdfOcgAppDict] = []
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
fn pdf_ocg_read_json_config(json : Json) -> @ocg.PdfOcgConfig raise PdfError {
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

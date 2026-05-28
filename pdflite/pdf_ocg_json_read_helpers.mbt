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

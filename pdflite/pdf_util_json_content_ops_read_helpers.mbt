///|
fn pdf_util_json_op_float(json : Json) -> Double raise PdfError {
  match json {
    Object(entries) =>
      if entries.length() == 1 {
        match entries.get("F") {
          Some(Number(value, repr=_)) => value
          _ => raise NumberExpected
        }
      } else {
        raise NumberExpected
      }
    _ => raise NumberExpected
  }
}

///|
fn pdf_util_json_op_int(json : Json) -> Int raise PdfError {
  match json {
    Object(entries) =>
      if entries.length() == 1 {
        match entries.get("I") {
          Some(Number(value, repr=_)) => pdf_util_json_truncated_number(value)
          _ => raise NumberExpected
        }
      } else {
        raise NumberExpected
      }
    _ => raise NumberExpected
  }
}

///|
fn pdf_util_json_op_name(json : Json) -> PdfName raise PdfError {
  match json {
    String(name) => pdf_util_name_from_json_text(name)
    _ => raise BadText
  }
}

///|
fn pdf_util_json_op_bytes(json : Json) -> PdfBytes raise PdfError {
  match json {
    String(text) => pdf_util_pdf_string_from_json_text(text)
    _ => raise BadText
  }
}

///|
fn pdf_util_json_op_float_array(json : Json) -> Array[Double] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[Double] = Array::new(capacity=values.length())
      for value in values {
        output.push(pdf_util_json_op_float(value))
      }
      output
    }
    _ => raise BadText
  }
}

///|
fn pdf_util_json_op_floats(
  values : ArrayView[Json],
) -> Array[Double] raise PdfError {
  let output : Array[Double] = Array::new(capacity=values.length())
  for value in values {
    output.push(pdf_util_json_op_float(value))
  }
  output
}

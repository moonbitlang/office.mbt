///|
fn pdf_util_json_float_object(value : Double) -> Json {
  Json::object(Map([("F", Json::number(value))]))
}

///|
fn pdf_util_json_int_object(value : Int) -> Json {
  Json::object(Map([("I", pdf_util_json_number(value))]))
}

///|
fn pdf_util_json_float_objects(values : ArrayView[Double]) -> Array[Json] {
  let output : Array[Json] = Array::new(capacity=values.length())
  for value in values {
    output.push(pdf_util_json_float_object(value))
  }
  output
}

///|
fn pdf_util_json_op_items(items : ArrayView[Json], operator : String) -> Json {
  let output : Array[Json] = Array::new(capacity=items.length() + 1)
  for item in items {
    output.push(item)
  }
  output.push(Json::string(operator))
  Json::array(output)
}

///|
fn pdf_util_json_name_object(name : PdfName) -> Json raise PdfError {
  Json::string(pdf_util_string_from_name(name))
}

///|
fn pdf_util_json_op_string(bytes : PdfBytes) -> Json raise PdfError {
  Json::string(pdf_util_string_from_bytes(bytes))
}

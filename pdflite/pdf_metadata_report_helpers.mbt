///|
fn pdf_metadata_json_string_array(values : ArrayView[String]) -> Json {
  let items : Array[Json] = []
  for value in values {
    items.push(Json::string(value))
  }
  Json::array(items)
}

///|
fn pdf_metadata_combine_with_commas(values : ArrayView[String]) -> String {
  let mut output = ""
  for value in values {
    if output == "" {
      output = value
    } else {
      output = output + ", " + value
    }
  }
  output.trim().to_owned()
}

///|
fn pdf_metadata_unit_number(value : Double, unit : @geometry.PdfUnit) -> Double {
  match unit {
    PdfPoint => value
    Inch => @geometry.unit_inches(value, PdfPoint)
    Centimetre => @geometry.unit_centimetres(value, PdfPoint)
    Millimetre => @geometry.unit_millimetres(value, PdfPoint)
  }
}

///|
fn pdf_metadata_string_json(value : String) -> Json {
  if value == "" {
    Json::null()
  } else {
    Json::string(value)
  }
}

///|
fn pdf_metadata_bool_json(value : String) -> Json {
  if value == "" {
    Json::null()
  } else {
    Json::boolean(value.to_lower() == "true")
  }
}

///|
fn PdfDocument::pdf_metadata_info_encoded(
  self : PdfDocument,
  key : @core.PdfName,
  encoding : @metadata.PdfMetadataEncoding,
) -> String {
  let info = match
    self.lookup_direct(pdf_metadata_info(), self.trailer_dict()) {
    Some(dictionary) => dictionary
    None => PdfDictionary([])
  }
  match self.lookup_direct(key, info) {
    Some(PdfString(bytes)) =>
      @utf8.decode_lossy(
        pdf_metadata_encode_output(encoding, bytes) catch {
          _ => return ""
        },
      )
    Some(PdfBoolean(value)) => pdf_metadata_bool_string(value)
    _ => if key == pdf_metadata_trapped() { "False" } else { "" }
  }
}

///|
fn pdf_metadata_set_json_string(
  output : Map[String, Json],
  key : String,
  value : String,
) -> Unit {
  output.set(key, pdf_metadata_string_json(value))
}

///|
fn pdf_metadata_push_text_line(
  output : Array[String],
  key : String,
  value : String,
) -> Unit {
  output.push(key)
  output.push(": ")
  output.push(value)
  output.push("\n")
}

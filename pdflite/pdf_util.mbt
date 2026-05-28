///|
fn pdf_util_string_from_utf8(bytes : BytesView) -> String raise PdfError {
  @utf8.decode(bytes) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_util_string_from_bytes(bytes : BytesView) -> String raise PdfError {
  @utf8.decode(bytes) catch {
    _ =>
      @ascii.decode(pdf_write_hex_string(bytes)) catch {
        _ => raise InvalidUTF8
      }
  }
}

///|
fn pdf_util_string_from_name(name : PdfName) -> String raise PdfError {
  @ascii.decode(name.bytes()) catch {
    _ =>
      @ascii.decode(pdf_write_object(PdfNameObject(name))) catch {
        _ => raise InvalidUTF8
      }
  }
}

///|
fn pdf_util_json_number(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn pdf_util_json_integral_number(value : Double) -> Int raise PdfError {
  let integer = value.to_int()
  guard integer.to_double() == value else { raise NumberExpected }
  integer
}

///|
fn pdf_util_json_truncated_number(value : Double) -> Int {
  value.to_int()
}

///|
fn PdfDocument::pdf_util_json_of_object(
  self : PdfDocument,
  object : PdfObject,
  utf8 : Bool,
  clean_strings : Bool,
  no_stream_data : Bool,
  decompress_streams : Bool,
  parse_content : Bool,
) -> Json raise PdfError {
  match object {
    PdfNull => Json::null()
    PdfBoolean(value) => Json::boolean(value)
    PdfInteger(value) => Json::object(Map([("I", pdf_util_json_number(value))]))
    PdfReal(value) => Json::object(Map([("F", Json::number(value))]))
    PdfString(bytes) =>
      if utf8 {
        let utf8_bytes = pdf_utf8_of_pdfdocstring(bytes) catch {
          _ => return Json::string(pdf_util_string_from_bytes(bytes))
        }
        Json::object(
          Map([("U", Json::string(pdf_util_string_from_utf8(utf8_bytes)))]),
        )
      } else if clean_strings {
        let simplified = pdf_simplify_utf16be(bytes) catch { _ => bytes }
        Json::string(pdf_util_string_from_bytes(simplified))
      } else {
        Json::string(pdf_util_string_from_bytes(bytes))
      }
    PdfNameObject(name) =>
      Json::object(Map([("N", Json::string(pdf_util_string_from_name(name)))]))
    PdfArray(values) => {
      let json_values : Array[Json] = Array::new(capacity=values.length())
      for value in values {
        json_values.push(
          self.pdf_util_json_of_object(
            value, utf8, clean_strings, no_stream_data, decompress_streams, parse_content,
          ),
        )
      }
      Json::array(json_values)
    }
    PdfDictionary(entries) => {
      let json_entries : Map[String, Json] = Map([])
      for entry in entries {
        json_entries.set(
          pdf_util_string_from_name(entry.0),
          self.pdf_util_json_of_object(
            entry.1,
            utf8,
            clean_strings,
            no_stream_data,
            decompress_streams,
            parse_content,
          ),
        )
      }
      Json::object(json_entries)
    }
    PdfStreamObject(stream) => {
      let decode_function_stream = parse_content &&
        self.lookup_direct(
          pdf_util_cpdfjson_function_type_key(),
          stream.dictionary,
        ) !=
        None
      let output_stream = if decompress_streams || decode_function_stream {
        self.pdf_decode_stream_until_unknown_value_direct(stream)
      } else {
        stream
      }
      let stream_data_json = if no_stream_data && !decode_function_stream {
        Json::string("<<stream data elided>>")
      } else {
        let stream_data = PdfStreamObject(output_stream).stream_bytes()
        Json::string(pdf_util_string_from_bytes(stream_data))
      }
      Json::object(
        Map([
          (
            "S",
            Json::array([
              self.pdf_util_json_of_object(
                output_stream.dictionary,
                utf8,
                clean_strings,
                no_stream_data,
                decompress_streams,
                parse_content,
              ),
              stream_data_json,
            ]),
          ),
        ]),
      )
    }
    PdfIndirect(number) => pdf_util_json_number(number)
  }
}

///|
/// Convert a single PDF object to CPDFJSON format.
///
/// This exposes the single-object output side of cpdf's `cpdfjson`
/// conversion. `clean_strings` mirrors cpdf's deprecated
/// `-output-json-clean-strings` behavior for non-UTF8 output, and
/// `no_stream_data` emits cpdf's stream-data elision placeholder. When
/// `parse_content` is set, `/FunctionType` streams are decoded before output,
/// matching cpdf's single-object parse-content behavior. Full document
/// CPDFJSON import/export and parsed content-stream encoding are handled by
/// `json_of_document`.
pub fn PdfDocument::json_of_object(
  self : PdfDocument,
  object : PdfObject,
  utf8? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  parse_content? : Bool = false,
) -> Json raise PdfError {
  self.pdf_util_json_of_object(
    object, utf8, clean_strings, no_stream_data, false, parse_content,
  )
}

///|
fn pdf_util_pdf_string_from_json_text(text : String) -> PdfBytes {
  @utf8.encode(text)
}

///|
fn pdf_util_utf8_pdf_string_from_json_text(text : String) -> PdfBytes {
  pdf_pdfdocstring_of_utf8(@utf8.encode(text)) catch {
    _ => @utf8.encode(text)
  }
}

///|
fn pdf_util_name_from_json_text(text : String) -> PdfName {
  pdf_name_of_bytes(@utf8.encode(text))
}

///|
fn pdf_util_stream_of_json_data(
  dictionary_json : Json,
  data : String,
) -> PdfObject raise PdfError {
  let stream_data = pdf_util_pdf_string_from_json_text(data)
  let dictionary = pdf_object_of_json(dictionary_json).add_dict_entry(
    pdf_object_length_name(),
    PdfInteger(stream_data.length()),
  )
  pdf_stream(dictionary, StreamGot(stream_data))
}

///|
fn pdf_util_object_of_json_object(
  entries : Map[String, Json],
) -> PdfObject raise PdfError {
  if entries.length() == 1 {
    match entries.get("U") {
      Some(String(text)) =>
        return PdfString(pdf_util_utf8_pdf_string_from_json_text(text))
      _ => ()
    }
    match entries.get("I") {
      Some(Number(value, repr=_)) =>
        return PdfInteger(pdf_util_json_truncated_number(value))
      _ => ()
    }
    match entries.get("F") {
      Some(Number(value, repr=_)) => return PdfReal(value)
      _ => ()
    }
    match entries.get("N") {
      Some(String(name)) =>
        return PdfNameObject(pdf_util_name_from_json_text(name))
      _ => ()
    }
    match entries.get("S") {
      Some(Array([dictionary_json, String(data)])) =>
        return pdf_util_stream_of_json_data(dictionary_json, data)
      Some(Array([dictionary_json, Array(op_jsons)])) =>
        return pdf_util_stream_of_json_ops(dictionary_json, op_jsons)
      _ => ()
    }
  }
  let output : Array[(PdfName, PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    output.push(
      (pdf_util_name_from_json_text(entry.0), pdf_object_of_json(entry.1)),
    )
  }
  PdfDictionary(output)
}

///|
/// Convert a single CPDFJSON object to a PDF object.
///
/// This ports the ordinary object side of cpdf's `object_of_json`: primitive
/// JSON values, CPDFJSON integer/real/name/string wrappers, dictionaries,
/// arrays, indirect references, streams with embedded string data, and streams
/// with parsed content-operation arrays are supported.
pub fn pdf_object_of_json(json : Json) -> PdfObject raise PdfError {
  match json {
    Null => PdfNull
    True => PdfBoolean(true)
    False => PdfBoolean(false)
    Number(value, repr=_) => PdfIndirect(pdf_util_json_integral_number(value))
    String(text) => PdfString(pdf_util_pdf_string_from_json_text(text))
    Array(values) => {
      let output : Array[PdfObject] = Array::new(capacity=values.length())
      for value in values {
        output.push(pdf_object_of_json(value))
      }
      PdfArray(output)
    }
    Object(entries) => pdf_util_object_of_json_object(entries)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::json_of_object`.
pub fn pdf_json_of_object(
  document : PdfDocument,
  object : PdfObject,
  utf8? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  parse_content? : Bool = false,
) -> Json raise PdfError {
  document.json_of_object(
    object,
    utf8~,
    clean_strings~,
    no_stream_data~,
    parse_content~,
  )
}

///|
fn pdf_injectible_char(char : Char) -> Bool {
  char == '&' || char == '|' || char == '\n' || char == '`' || char == '$'
}

///|
/// Check that a path-like string is safe to pass through shell-style contexts.
///
/// This ports cpdf's injectible-character guard, but reports a checked
/// `PdfError::InsecurePathName` instead of terminating the process.
pub fn pdf_check_injectible(text : String) -> Unit raise PdfError {
  for char in text.iter() {
    if pdf_injectible_char(char) {
      raise InsecurePathName(text)
    }
  }
}

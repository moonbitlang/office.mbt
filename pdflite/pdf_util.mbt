///|
fn PdfDocument::pdf_util_dict_entry_single_object(
  self : PdfDocument,
  object : PdfObject,
  transform : (PdfObject) -> PdfObject,
) -> PdfObject {
  match object {
    PdfDictionary(entries) => {
      let rewritten = pdf_recurse_dict(
        fn(child) { self.pdf_util_dict_entry_single_object(child, transform) },
        entries,
      )
      transform(rewritten)
    }
    PdfStreamObject(stream) =>
      match stream.dictionary {
        PdfDictionary(entries) => {
          stream.dictionary = pdf_recurse_dict(
            fn(child) {
              self.pdf_util_dict_entry_single_object(child, transform)
            },
            entries,
          )
          transform(PdfStreamObject(stream))
        }
        _ => object
      }
    PdfArray(values) =>
      pdf_recurse_array(
        fn(child) { self.pdf_util_dict_entry_single_object(child, transform) },
        values,
      )
    _ => object
  }
}

///|
fn PdfDocument::pdf_util_rewrite_dict_entries(
  self : PdfDocument,
  transform : (PdfObject) -> PdfObject,
) -> Unit {
  self.map_objects_in_place(fn(object) {
    self.pdf_util_dict_entry_single_object(object, transform)
  })
  self.trailer_dict = self.pdf_util_dict_entry_single_object(
    self.trailer_dict,
    transform,
  )
}

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
) -> Json raise PdfError {
  match object {
    PdfNull => Json::null()
    PdfBoolean(value) => Json::boolean(value)
    PdfInteger(value) =>
      Json::object(Map::of([("I", pdf_util_json_number(value))]))
    PdfReal(value) => Json::object(Map::of([("F", Json::number(value))]))
    PdfString(bytes) =>
      if utf8 {
        let utf8_bytes = pdf_utf8_of_pdfdocstring(bytes) catch {
          _ => return Json::string(pdf_util_string_from_bytes(bytes))
        }
        Json::object(
          Map::of([("U", Json::string(pdf_util_string_from_utf8(utf8_bytes)))]),
        )
      } else {
        let simplified = pdf_simplify_utf16be(bytes) catch { _ => bytes }
        Json::string(pdf_util_string_from_bytes(simplified))
      }
    PdfNameObject(name) =>
      Json::object(
        Map::of([("N", Json::string(pdf_util_string_from_name(name)))]),
      )
    PdfArray(values) => {
      let json_values : Array[Json] = []
      for value in values {
        json_values.push(self.pdf_util_json_of_object(value, utf8))
      }
      Json::array(json_values)
    }
    PdfDictionary(entries) => {
      let json_entries : Map[String, Json] = Map([])
      for entry in entries {
        json_entries.set(
          pdf_util_string_from_name(entry.0),
          self.pdf_util_json_of_object(entry.1, utf8),
        )
      }
      Json::object(json_entries)
    }
    PdfStreamObject(stream) => {
      let stream_data = PdfStreamObject(stream).stream_bytes()
      Json::object(
        Map::of([
          (
            "S",
            Json::array([
              self.pdf_util_json_of_object(stream.dictionary, utf8),
              Json::string(pdf_util_string_from_bytes(stream_data)),
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
/// conversion. Full document CPDFJSON import/export and parsed content-stream
/// encoding are intentionally separate slices.
pub fn PdfDocument::json_of_object(
  self : PdfDocument,
  object : PdfObject,
  utf8? : Bool = false,
) -> Json raise PdfError {
  self.pdf_util_json_of_object(object, utf8)
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
      _ => ()
    }
  }
  let output : Array[(PdfName, PdfObject)] = []
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
/// arrays, indirect references, and streams with embedded string data are
/// supported. Parsed content-stream operation arrays are intentionally left for
/// a later full-document CPDFJSON slice.
pub fn pdf_object_of_json(json : Json) -> PdfObject raise PdfError {
  match json {
    Null => PdfNull
    True => PdfBoolean(true)
    False => PdfBoolean(false)
    Number(value, repr=_) => PdfIndirect(pdf_util_json_integral_number(value))
    String(text) => PdfString(pdf_util_pdf_string_from_json_text(text))
    Array(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(pdf_object_of_json(value))
      }
      PdfArray(output)
    }
    Object(entries) => pdf_util_object_of_json_object(entries)
  }
}

///|
fn PdfDocument::pdf_util_collect_dict_entry_values(
  self : PdfDocument,
  object : PdfObject,
  key : PdfName,
  output : Array[PdfObject],
) -> Unit {
  match object {
    PdfDictionary(entries) => {
      for entry in entries {
        self.pdf_util_collect_dict_entry_values(entry.1, key, output)
      }
      match self.lookup_direct(key, object) {
        Some(value) => output.push(value)
        None => ()
      }
    }
    PdfStreamObject(stream) => {
      match stream.dictionary {
        PdfDictionary(entries) =>
          for entry in entries {
            self.pdf_util_collect_dict_entry_values(entry.1, key, output)
          }
        _ => ()
      }
      match self.lookup_direct(key, object) {
        Some(value) => output.push(value)
        None => ()
      }
    }
    PdfArray(values) =>
      for value in values {
        self.pdf_util_collect_dict_entry_values(value, key, output)
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_util_remove_entry_transform(
  self : PdfDocument,
  key : PdfName,
  search : PdfObject?,
) -> (PdfObject) -> PdfObject {
  fn(object) {
    match search {
      None => try! object.remove_dict_entry(key)
      Some(expected) =>
        match self.lookup_direct(key, object) {
          Some(value) if value == expected => try! object.remove_dict_entry(key)
          _ => object
        }
    }
  }
}

///|
fn PdfDocument::pdf_util_replace_entry_transform(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  search : PdfObject?,
) -> (PdfObject) -> PdfObject {
  fn(object) {
    match search {
      None => {
        let replaced : Result[PdfObject, Error] = try? object.replace_dict_entry(
          key, value,
        )
        match replaced {
          Ok(updated) => updated
          Err(_) => object
        }
      }
      Some(expected) =>
        match self.lookup_direct(key, object) {
          Some(found) if found == expected =>
            try! object.replace_dict_entry(key, value)
          _ => object
        }
    }
  }
}

///|
/// Remove dictionary entries named `key` throughout parsed objects and trailer.
///
/// When `search` is supplied, an entry is removed only when its resolved value
/// equals `search`. Nested dictionaries, arrays, and stream dictionaries are
/// traversed recursively; deferred document objects are left untouched.
pub fn PdfDocument::remove_dict_entry_everywhere(
  self : PdfDocument,
  key : PdfName,
  search? : PdfObject? = None,
) -> Unit {
  self.pdf_util_rewrite_dict_entries(
    self.pdf_util_remove_entry_transform(key, search),
  )
}

///|
/// Replace dictionary entries named `key` throughout parsed objects and trailer.
///
/// Missing keys are ignored. When `search` is supplied, only entries whose
/// resolved current value equals `search` are replaced.
pub fn PdfDocument::replace_dict_entry_everywhere(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  search? : PdfObject? = None,
) -> Unit {
  self.pdf_util_rewrite_dict_entries(
    self.pdf_util_replace_entry_transform(key, value, search),
  )
}

///|
/// Return resolved values for dictionary entries named `key`.
///
/// Traversal mirrors cpdf's dictionary-entry reporting helpers: direct nested
/// dictionaries, arrays, stream dictionaries, all parsed document objects, and
/// the trailer are scanned. The matching value itself is resolved through the
/// document object table.
pub fn PdfDocument::dict_entry_values(
  self : PdfDocument,
  key : PdfName,
) -> Array[PdfObject] {
  let output : Array[PdfObject] = []
  for number in self.object_numbers() {
    self.pdf_util_collect_dict_entry_values(
      self.lookup_object_or_null(number),
      key,
      output,
    )
  }
  self.pdf_util_collect_dict_entry_values(self.trailer_dict, key, output)
  output
}

///|
/// Render dictionary entry values as PDF object syntax.
///
/// This is the side-effect-free native equivalent of cpdf's `print_dict_entry`.
pub fn PdfDocument::dict_entry_rendered_values(
  self : PdfDocument,
  key : PdfName,
) -> Array[PdfBytes] raise PdfError {
  let rendered : Array[PdfBytes] = []
  for value in self.dict_entry_values(key) {
    rendered.push(pdf_write_object(value))
  }
  rendered
}

///|
/// Return dictionary entry values in cpdf-style JSON format.
pub fn PdfDocument::dict_entries_json(
  self : PdfDocument,
  key : PdfName,
  utf8? : Bool = false,
) -> PdfBytes raise PdfError {
  let values : Array[Json] = []
  for value in self.dict_entry_values(key) {
    values.push(self.pdf_util_json_of_object(value, utf8))
  }
  @utf8.encode(Json::array(values).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entry_values`.
pub fn pdf_dict_entry_values(
  document : PdfDocument,
  key : PdfName,
) -> Array[PdfObject] {
  document.dict_entry_values(key)
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entry_rendered_values`.
pub fn pdf_print_dict_entry(
  document : PdfDocument,
  key : PdfName,
) -> Array[PdfBytes] raise PdfError {
  document.dict_entry_rendered_values(key)
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entries_json`.
pub fn pdf_get_dict_entries(
  document : PdfDocument,
  key : PdfName,
  utf8? : Bool = false,
) -> PdfBytes raise PdfError {
  document.dict_entries_json(key, utf8~)
}

///|
/// Compatibility wrapper for `PdfDocument::json_of_object`.
pub fn pdf_json_of_object(
  document : PdfDocument,
  object : PdfObject,
  utf8? : Bool = false,
) -> Json raise PdfError {
  document.json_of_object(object, utf8~)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_dict_entry_everywhere`.
pub fn pdf_remove_dict_entry(
  document : PdfDocument,
  key : PdfName,
  search? : PdfObject? = None,
) -> Unit {
  document.remove_dict_entry_everywhere(key, search~)
}

///|
/// Compatibility wrapper for `PdfDocument::replace_dict_entry_everywhere`.
pub fn pdf_replace_dict_entry(
  document : PdfDocument,
  key : PdfName,
  value : PdfObject,
  search? : PdfObject? = None,
) -> Unit {
  document.replace_dict_entry_everywhere(key, value, search~)
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

///|
fn PdfDocument::pdf_util_dict_entry_single_object(
  self : PdfDocument,
  object : @syntax.PdfObject,
  transform : (@syntax.PdfObject) -> @syntax.PdfObject,
) -> @syntax.PdfObject {
  match object {
    PdfDictionary(entries) => {
      let rewritten = @syntax.pdf_recurse_dict(
        fn(child) { self.pdf_util_dict_entry_single_object(child, transform) },
        entries,
      )
      transform(rewritten)
    }
    PdfStreamObject(stream) =>
      match stream.dictionary {
        PdfDictionary(entries) => {
          stream.dictionary = @syntax.pdf_recurse_dict(
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
      @syntax.pdf_recurse_array(
        fn(child) { self.pdf_util_dict_entry_single_object(child, transform) },
        values,
      )
    _ => object
  }
}

///|
fn PdfDocument::pdf_util_rewrite_dict_entries(
  self : PdfDocument,
  transform : (@syntax.PdfObject) -> @syntax.PdfObject,
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
fn PdfDocument::pdf_util_collect_dict_entry_values(
  self : PdfDocument,
  object : @syntax.PdfObject,
  key : @core.PdfName,
  output : Array[@syntax.PdfObject],
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
  key : @core.PdfName,
  search : @syntax.PdfObject?,
) -> (@syntax.PdfObject) -> @syntax.PdfObject {
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
  key : @core.PdfName,
  value : @syntax.PdfObject,
  search : @syntax.PdfObject?,
) -> (@syntax.PdfObject) -> @syntax.PdfObject {
  fn(object) {
    match search {
      None => {
        let replaced : Result[@syntax.PdfObject, Error] = try
          object.replace_dict_entry(key, value)
        catch {
          err => Err(err)
        } noraise {
          value => Ok(value)
        }
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
  key : @core.PdfName,
  search? : @syntax.PdfObject? = None,
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
  key : @core.PdfName,
  value : @syntax.PdfObject,
  search? : @syntax.PdfObject? = None,
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
  key : @core.PdfName,
) -> Array[@syntax.PdfObject] {
  let object_numbers = self.object_numbers()
  let output : Array[@syntax.PdfObject] = Array::new(
    capacity=object_numbers.length(),
  )
  for number in object_numbers {
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
  key : @core.PdfName,
) -> Array[@core.PdfBytes] raise @core.PdfError {
  let values = self.dict_entry_values(key)
  let rendered : Array[@core.PdfBytes] = Array::new(capacity=values.length())
  for value in values {
    rendered.push(pdf_write_object(value))
  }
  rendered
}

///|
/// Return dictionary entry values in cpdf-style JSON format.
pub fn PdfDocument::dict_entries_json(
  self : PdfDocument,
  key : @core.PdfName,
  utf8? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  let entry_values = self.dict_entry_values(key)
  let values : Array[Json] = Array::new(capacity=entry_values.length())
  for value in entry_values {
    values.push(
      self.pdf_util_json_of_object(value, utf8, false, false, false, false),
    )
  }
  @utf8.encode(Json::array(values).stringify())
}

///|
fn pdf_util_source_key_name(key : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(key))
}

///|
/// Render dictionary entry values for a cpdf-style slash-prefixed string key.
pub fn PdfDocument::dict_entry_rendered_values_string(
  self : PdfDocument,
  key : String,
) -> Array[@core.PdfBytes] raise @core.PdfError {
  self.dict_entry_rendered_values(pdf_util_source_key_name(key))
}

///|
/// Return dictionary entry values in cpdf-style JSON for a slash-prefixed key.
pub fn PdfDocument::dict_entries_json_string(
  self : PdfDocument,
  key : String,
  utf8? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  self.dict_entries_json(pdf_util_source_key_name(key), utf8~)
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entry_values`.
pub fn pdf_dict_entry_values(
  document : PdfDocument,
  key : @core.PdfName,
) -> Array[@syntax.PdfObject] {
  document.dict_entry_values(key)
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entry_rendered_values`.
pub fn pdf_print_dict_entry(
  document : PdfDocument,
  key : @core.PdfName,
) -> Array[@core.PdfBytes] raise @core.PdfError {
  document.dict_entry_rendered_values(key)
}

///|
/// Compatibility wrapper matching cpdftweak's string-key `print_dict_entry`.
pub fn pdf_print_dict_entry_string(
  document : PdfDocument,
  key : String,
) -> Array[@core.PdfBytes] raise @core.PdfError {
  document.dict_entry_rendered_values_string(key)
}

///|
/// Compatibility wrapper matching cpdftweak's `print_dict_entry` argument order.
pub fn pdf_print_dict_entry_cpdf_order(
  utf8 : Bool,
  document : PdfDocument,
  key : String,
) -> Array[@core.PdfBytes] raise @core.PdfError {
  ignore(utf8)
  document.dict_entry_rendered_values_string(key)
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entries_json`.
pub fn pdf_get_dict_entries(
  document : PdfDocument,
  key : @core.PdfName,
  utf8? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  document.dict_entries_json(key, utf8~)
}

///|
/// Compatibility wrapper matching cpdftweak's string-key `get_dict_entries`.
pub fn pdf_get_dict_entries_string(
  document : PdfDocument,
  key : String,
  utf8? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  document.dict_entries_json_string(key, utf8~)
}

///|
/// Compatibility wrapper matching cpdftweak's `get_dict_entries` argument order.
pub fn pdf_get_dict_entries_cpdf_order(
  utf8 : Bool,
  document : PdfDocument,
  key : String,
) -> @core.PdfBytes raise @core.PdfError {
  document.dict_entries_json_string(key, utf8~)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_dict_entry_everywhere`.
pub fn pdf_remove_dict_entry(
  document : PdfDocument,
  key : @core.PdfName,
  search? : @syntax.PdfObject? = None,
) -> Unit {
  document.remove_dict_entry_everywhere(key, search~)
}

///|
/// Compatibility wrapper matching cpdfutil's string-key `remove_dict_entry`.
pub fn PdfDocument::remove_dict_entry_string(
  self : PdfDocument,
  key : String,
  search? : @syntax.PdfObject? = None,
) -> Unit {
  self.remove_dict_entry_everywhere(
    @core.pdf_name_of_bytes(@ascii.encode(key)),
    search~,
  )
}

///|
/// Compatibility wrapper matching cpdfutil's string-key `remove_dict_entry`.
pub fn pdf_remove_dict_entry_string(
  document : PdfDocument,
  key : String,
  search? : @syntax.PdfObject? = None,
) -> Unit {
  document.remove_dict_entry_string(key, search~)
}

///|
/// Compatibility wrapper for `PdfDocument::replace_dict_entry_everywhere`.
pub fn pdf_replace_dict_entry(
  document : PdfDocument,
  key : @core.PdfName,
  value : @syntax.PdfObject,
  search? : @syntax.PdfObject? = None,
) -> Unit {
  document.replace_dict_entry_everywhere(key, value, search~)
}

///|
/// Compatibility wrapper matching cpdfutil's string-key `replace_dict_entry`.
pub fn PdfDocument::replace_dict_entry_string(
  self : PdfDocument,
  key : String,
  value : @syntax.PdfObject,
  search? : @syntax.PdfObject? = None,
) -> Unit {
  self.replace_dict_entry_everywhere(
    @core.pdf_name_of_bytes(@ascii.encode(key)),
    value,
    search~,
  )
}

///|
/// Compatibility wrapper matching cpdfutil's string-key `replace_dict_entry`.
pub fn pdf_replace_dict_entry_string(
  document : PdfDocument,
  key : String,
  value : @syntax.PdfObject,
  search? : @syntax.PdfObject? = None,
) -> Unit {
  document.replace_dict_entry_string(key, value, search~)
}

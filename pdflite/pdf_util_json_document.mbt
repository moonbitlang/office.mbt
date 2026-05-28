///|
let pdf_util_cpdfjson_stream_data_included_key_name : PdfName = pdf_util_name_from_json_text(
  "/CPDFJSONstreamdataincluded",
)

///|
fn pdf_util_cpdfjson_stream_data_included_key() -> PdfName {
  pdf_util_cpdfjson_stream_data_included_key_name
}

///|
let pdf_util_cpdfjson_major_version_key_name : PdfName = pdf_util_name_from_json_text(
  "/CPDFJSONmajorpdfversion",
)

///|
fn pdf_util_cpdfjson_major_version_key() -> PdfName {
  pdf_util_cpdfjson_major_version_key_name
}

///|
let pdf_util_cpdfjson_minor_version_key_name : PdfName = pdf_util_name_from_json_text(
  "/CPDFJSONminorpdfversion",
)

///|
fn pdf_util_cpdfjson_minor_version_key() -> PdfName {
  pdf_util_cpdfjson_minor_version_key_name
}

///|
let pdf_util_cpdfjson_root_key_name : PdfName = pdf_util_name_from_json_text(
  "/Root",
)

///|
fn pdf_util_cpdfjson_root_key() -> PdfName {
  pdf_util_cpdfjson_root_key_name
}

///|
let pdf_util_cpdfjson_contents_key_name : PdfName = pdf_util_name_from_json_text(
  "/Contents",
)

///|
fn pdf_util_cpdfjson_contents_key() -> PdfName {
  pdf_util_cpdfjson_contents_key_name
}

///|
let pdf_util_cpdfjson_subtype_key_name : PdfName = pdf_util_name_from_json_text(
  "/Subtype",
)

///|
fn pdf_util_cpdfjson_subtype_key() -> PdfName {
  pdf_util_cpdfjson_subtype_key_name
}

///|
let pdf_util_cpdfjson_form_name : PdfName = pdf_util_name_from_json_text(
  "/Form",
)

///|
fn pdf_util_cpdfjson_form() -> PdfName {
  pdf_util_cpdfjson_form_name
}

///|
let pdf_util_cpdfjson_type_key_name : PdfName = pdf_util_name_from_json_text(
  "/Type",
)

///|
fn pdf_util_cpdfjson_type_key() -> PdfName {
  pdf_util_cpdfjson_type_key_name
}

///|
let pdf_util_cpdfjson_pattern_name : PdfName = pdf_util_name_from_json_text(
  "/Pattern",
)

///|
fn pdf_util_cpdfjson_pattern() -> PdfName {
  pdf_util_cpdfjson_pattern_name
}

///|
let pdf_util_cpdfjson_function_type_key_name : PdfName = pdf_util_name_from_json_text(
  "/FunctionType",
)

///|
fn pdf_util_cpdfjson_function_type_key() -> PdfName {
  pdf_util_cpdfjson_function_type_key_name
}

///|
let pdf_util_cpdfjson_filter_key_name : PdfName = pdf_util_name_from_json_text(
  "/Filter",
)

///|
fn pdf_util_cpdfjson_filter_key() -> PdfName {
  pdf_util_cpdfjson_filter_key_name
}

///|
fn pdf_util_cpdfjson_integer_field(
  object : PdfObject,
  key : PdfName,
) -> Int raise PdfError {
  match object.lookup_immediate(key) {
    Some(PdfInteger(value)) => value
    _ => raise BadText
  }
}

///|
fn pdf_util_cpdfjson_check_stream_data(
  params : PdfObject,
) -> Unit raise PdfError {
  match params.lookup_immediate(pdf_util_cpdfjson_stream_data_included_key()) {
    Some(PdfBoolean(false)) => raise BadText
    _ => ()
  }
}

///|
fn pdf_util_cpdfjson_root_number(trailer : PdfObject) -> Int raise PdfError {
  match trailer {
    PdfDictionary(_) =>
      match trailer.lookup_immediate(pdf_util_cpdfjson_root_key()) {
        Some(PdfIndirect(number)) => number
        _ => raise RootExpected
      }
    _ => raise RootExpected
  }
}

///|
fn pdf_util_cpdfjson_item_number(json : Json) -> Int raise PdfError {
  match json {
    Number(value, repr=_) => pdf_util_json_integral_number(value)
    _ => raise BadText
  }
}

///|
fn pdf_util_cpdfjson_read_item(
  json : Json,
  params : Ref[PdfObject],
  trailer : Ref[PdfObject],
  objects : Array[(Int, PdfObject)],
) -> Unit raise PdfError {
  match json {
    Array([number_json, object_json]) => {
      let number = pdf_util_cpdfjson_item_number(number_json)
      match number {
        -1 => params.val = pdf_object_of_json(object_json)
        0 => trailer.val = pdf_object_of_json(object_json)
        value if value < 0 => ()
        value => objects.push((value, pdf_object_of_json(object_json)))
      }
    }
    _ => raise BadText
  }
}

///|
/// Convert a CPDFJSON top-level array into an in-memory PDF document.
///
/// This ports cpdf's `pdf_of_json` document-input path. Object `-1` supplies
/// CPDFJSON parameters, object `0` supplies the trailer dictionary, positive
/// object numbers populate the document object table, and other negative
/// object numbers are ignored. `/CPDFJSONstreamdataincluded false` is rejected
/// because the stream bytes needed for reconstruction are not present.
pub fn pdf_document_of_json(json : Json) -> PdfDocument raise PdfError {
  let items = match json {
    Array(values) => values
    _ => raise BadText
  }
  let params : Ref[PdfObject] = { val: PdfNull }
  let trailer : Ref[PdfObject] = { val: PdfNull }
  let objects : Array[(Int, PdfObject)] = Array::new(capacity=items.length())
  for item in items {
    pdf_util_cpdfjson_read_item(item, params, trailer, objects)
  }
  pdf_util_cpdfjson_check_stream_data(params.val)
  let major = pdf_util_cpdfjson_integer_field(
    params.val,
    pdf_util_cpdfjson_major_version_key(),
  )
  let minor = pdf_util_cpdfjson_integer_field(
    params.val,
    pdf_util_cpdfjson_minor_version_key(),
  )
  let root = pdf_util_cpdfjson_root_number(trailer.val)
  let document = pdf_document_empty()
  document.set_version(major, minor)
  document.set_root(root)
  document.set_trailer_dict(trailer.val)
  for entry in objects {
    document.load_object_given_number(entry.0, entry.1)
  }
  document
}

///|
/// Read a CPDFJSON document from UTF-8 JSON bytes.
///
/// This is the in-memory byte-input counterpart of cpdf's
/// `Cpdfjson.of_input`.
pub fn pdf_document_of_json_blob(
  data : BytesView,
) -> PdfDocument raise PdfError {
  let text = @utf8.decode(data) catch { _ => raise BadText }
  let json = @json.parse(text) catch { _ => raise BadText }
  pdf_document_of_json(json)
}

///|
fn pdf_util_int_array_contains(values : ArrayView[Int], value : Int) -> Bool {
  for item in values {
    if item == value {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_util_push_unique_int(values : Array[Int], value : Int) -> Unit {
  if !pdf_util_int_array_contains(values, value) {
    values.push(value)
  }
}

///|
fn PdfDocument::pdf_util_mark_contents_value(
  self : PdfDocument,
  value : PdfObject,
  numbers : Array[Int],
) -> Unit {
  match value {
    PdfIndirect(number) =>
      match self.lookup_object_or_null(number) {
        PdfArray(values) =>
          for item in values {
            match item {
              PdfIndirect(item_number) =>
                pdf_util_push_unique_int(numbers, item_number)
              _ => ()
            }
          }
        _ => pdf_util_push_unique_int(numbers, number)
      }
    PdfArray(values) =>
      for item in values {
        match item {
          PdfIndirect(number) => pdf_util_push_unique_int(numbers, number)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_util_indirect_marks_content_stream(
  self : PdfDocument,
  number : Int,
) -> Bool {
  match self.lookup_object_or_null(number) {
    PdfStreamObject(stream) =>
      match
        self.lookup_direct(
          pdf_util_cpdfjson_subtype_key(),
          PdfStreamObject(stream),
        ) {
        Some(PdfNameObject(name)) if name == pdf_util_cpdfjson_form() => true
        _ =>
          match
            self.lookup_direct(
              pdf_util_cpdfjson_type_key(),
              PdfStreamObject(stream),
            ) {
            Some(PdfNameObject(name)) if name == pdf_util_cpdfjson_pattern() =>
              true
            _ => false
          }
      }
    _ => false
  }
}

///|
fn PdfDocument::pdf_util_collect_content_stream_numbers(
  self : PdfDocument,
  object : PdfObject,
  numbers : Array[Int],
) -> Unit {
  match object {
    PdfDictionary(entries) =>
      for entry in entries {
        if entry.0 == pdf_util_cpdfjson_contents_key() {
          self.pdf_util_mark_contents_value(entry.1, numbers)
        }
        self.pdf_util_collect_content_stream_numbers(entry.1, numbers)
      }
    PdfStreamObject(stream) =>
      self.pdf_util_collect_content_stream_numbers(stream.dictionary, numbers)
    PdfArray(values) =>
      for value in values {
        self.pdf_util_collect_content_stream_numbers(value, numbers)
      }
    PdfIndirect(number) =>
      if self.pdf_util_indirect_marks_content_stream(number) {
        pdf_util_push_unique_int(numbers, number)
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_util_content_stream_numbers(
  self : PdfDocument,
) -> Array[Int] {
  let object_numbers = self.object_numbers()
  let numbers : Array[Int] = Array::new(capacity=object_numbers.length())
  self.pdf_util_collect_content_stream_numbers(self.trailer_dict(), numbers)
  for number in object_numbers {
    self.pdf_util_collect_content_stream_numbers(
      self.lookup_object_or_null(number),
      numbers,
    )
  }
  numbers
}

///|
fn PdfDocument::pdf_util_json_of_parsed_content_stream(
  self : PdfDocument,
  object : PdfObject,
  utf8 : Bool,
  clean_strings : Bool,
  no_stream_data : Bool,
) -> Json raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let decoded = self.pdf_decode_stream_until_unknown_value_direct(stream)
      let data = pdf_stream_data_bytes(decoded.data)
      let ops = pdf_parse_content_ops_from_bytes(data)
      let dictionary = decoded.dictionary
        .remove_dict_entry(pdf_object_length_name())
        .remove_dict_entry(pdf_util_cpdfjson_filter_key())
      let op_jsons : Array[Json] = Array::new(capacity=ops.length())
      for op in ops {
        op_jsons.push(self.pdf_util_json_of_content_op(op, utf8))
      }
      Json::object(
        Map([
          (
            "S",
            Json::array([
              self.pdf_util_json_of_object(
                dictionary, utf8, clean_strings, no_stream_data, false, false,
              ),
              Json::array(op_jsons),
            ]),
          ),
        ]),
      )
    }
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_util_precombine_page_content(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let mut changed = false
  for page in pages {
    if page.content.length() <= 1 {
      rewritten.push(page)
    } else {
      let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
      rewritten.push({ ..page, content: [pdf_content_stream_of_ops(ops)] })
      changed = true
    }
  }
  if changed {
    self.change_pages(rewritten, change_references=true)
  } else {
    self
  }
}

///|
fn PdfDocument::pdf_util_document_params_json(
  self : PdfDocument,
  utf8 : Bool,
  parse_content : Bool,
  no_stream_data : Bool,
) -> Json raise PdfError {
  let (major, minor) = self.version()
  self.pdf_util_json_of_object(
    PdfDictionary([
      (pdf_util_name_from_json_text("/CPDFJSONformatversion"), PdfInteger(3)),
      (
        pdf_util_name_from_json_text("/CPDFJSONcontentparsed"),
        PdfBoolean(parse_content),
      ),
      (
        pdf_util_cpdfjson_stream_data_included_key(),
        PdfBoolean(!no_stream_data),
      ),
      (pdf_util_cpdfjson_major_version_key(), PdfInteger(major)),
      (pdf_util_cpdfjson_minor_version_key(), PdfInteger(minor)),
    ]),
    utf8,
    false,
    false,
    false,
    false,
  )
}

///|
fn pdf_util_document_json_entry(number : Int, object : Json) -> Json {
  Json::array([pdf_util_json_number(number), object])
}

///|
fn PdfDocument::pdf_util_reachable_document_object_numbers(
  self : PdfDocument,
) -> Array[Int] {
  let referenced : @hashmap.HashMap[Int, Bool] = HashMap([])
  if self.trailer_dict().lookup_immediate(pdf_util_cpdfjson_root_key()) is None &&
    self.root() > 0 {
    referenced[self.root()] = true
    for
      number in self.referenced_object_numbers(
        self.lookup_object_or_null(self.root()),
      ) {
      referenced[number] = true
    }
  }
  for number in self.referenced_object_numbers(self.trailer_dict()) {
    referenced[number] = true
  }
  let object_numbers = self.object_numbers()
  let numbers : Array[Int] = Array::new(capacity=object_numbers.length())
  for number in object_numbers {
    if referenced.contains(number) {
      numbers.push(number)
    }
  }
  numbers
}

///|
/// Convert an in-memory document to CPDFJSON format with stream data included.
///
/// This ports the basic document-output shape from cpdf's `json_of_pdf`:
/// object `-1` carries CPDFJSON metadata, object `0` carries the trailer, and
/// positive object numbers reachable from the trailer or stored root are
/// emitted in ascending order. When `parse_content` is set, page `/Contents`
/// streams plus referenced Form XObject and Pattern streams are emitted as
/// cpdf-style operation arrays, after multi-stream pages are precombined on a
/// prepared copy of the document. When `clean_strings` is set for non-UTF8
/// output, UTF-16BE strings in positive objects are simplified while the
/// trailer dictionary is left unchanged to match cpdf's `/ID` precaution. When
/// `no_stream_data` is set, ordinary stream data is elided and CPDFJSON
/// metadata records that omission. When `decompress_streams` is set, positive
/// object streams are decoded through supported filters until the first
/// unknown filter.
pub fn PdfDocument::json_of_document(
  self : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> Json raise PdfError {
  let document = if parse_content {
    self.pdf_util_precombine_page_content()
  } else {
    self
  }
  let reachable_numbers = document.pdf_util_reachable_document_object_numbers()
  let entries : Array[Json] = Array::new(
    capacity=reachable_numbers.length() + 2,
  )
  entries.push(
    pdf_util_document_json_entry(
      -1,
      document.pdf_util_document_params_json(
        utf8, parse_content, no_stream_data,
      ),
    ),
  )
  entries.push(
    pdf_util_document_json_entry(
      0,
      document.pdf_util_json_of_object(
        document.trailer_dict(),
        utf8,
        false,
        no_stream_data,
        false,
        false,
      ),
    ),
  )
  let content_stream_numbers = if parse_content {
    document.pdf_util_content_stream_numbers()
  } else {
    []
  }
  for number in reachable_numbers {
    let object = document.lookup_object_or_null(number)
    let object_json = if pdf_util_int_array_contains(
        content_stream_numbers, number,
      ) {
      document.pdf_util_json_of_parsed_content_stream(
        object, utf8, clean_strings, no_stream_data,
      )
    } else {
      document.pdf_util_json_of_object(
        object, utf8, clean_strings, no_stream_data, decompress_streams, parse_content,
      )
    }
    entries.push(pdf_util_document_json_entry(number, object_json))
  }
  Json::array(entries)
}

///|
/// Render full-document CPDFJSON as UTF-8 bytes.
///
/// This is the side-effect-free byte-output counterpart of cpdf's
/// `Cpdfjson.to_output`.
pub fn PdfDocument::json_of_document_blob(
  self : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> PdfBytes raise PdfError {
  let json = self.json_of_document(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
  @utf8.encode(json.stringify())
}

///|
/// Source-spelled compatibility wrapper for cpdfjson's `to_output`.
///
/// The OCaml API writes to an output sink; this wrapper returns the same
/// UTF-8 bytes that would be written, while preserving cpdf's flag order.
pub fn PdfDocument::json_to_output(
  self : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
  clean_strings? : Bool = false,
) -> PdfBytes raise PdfError {
  self.json_of_document_blob(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::json_of_document`.
pub fn pdf_json_of_document(
  document : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> Json raise PdfError {
  document.json_of_document(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::json_of_document_blob`.
pub fn pdf_json_of_document_blob(
  document : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> PdfBytes raise PdfError {
  document.json_of_document_blob(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::json_to_output`.
pub fn pdf_json_to_output(
  document : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
  clean_strings? : Bool = false,
) -> PdfBytes raise PdfError {
  document.json_to_output(
    utf8~,
    parse_content~,
    no_stream_data~,
    decompress_streams~,
    clean_strings~,
  )
}

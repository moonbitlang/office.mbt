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

///|
fn pdf_tweak_is_digit_byte(byte : Byte) -> Bool {
  byte >= 48 && byte <= 57
}

///|
fn pdf_tweak_parse_digits(
  bytes : BytesView,
  start : Int,
  finish : Int,
  source : String,
) -> Int raise PdfError {
  if start >= finish {
    raise BadPageSpecification(source)
  }
  let mut value = 0
  for index in start..<finish {
    value = value * 10 + bytes[index].to_int() - 48
  }
  value
}

///|
fn pdf_tweak_digit_end(bytes : BytesView, start : Int) -> Int {
  let mut index = start
  while index < bytes.length() && pdf_tweak_is_digit_byte(bytes[index]) {
    index += 1
  }
  index
}

///|
fn pdf_tweak_split_chain(bytes : BytesView, start : Int) -> Array[PdfName] {
  let output : Array[PdfName] = []
  let mut index = start
  while index < bytes.length() {
    if bytes[index].to_int() == 47 {
      let segment_start = index
      index += 1
      while index < bytes.length() && bytes[index].to_int() != 47 {
        index += 1
      }
      output.push(pdf_name_of_bytes(bytes[segment_start:index].to_owned()))
    } else {
      index = bytes.length()
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_find_chained_object(
  self : PdfDocument,
  start : PdfObject,
  chain : ArrayView[PdfName],
  source : String,
) -> PdfObject raise PdfError {
  match self.lookup_chain(start, chain) {
    Some(object) => object
    None => raise BadPageSpecification(source)
  }
}

///|
fn PdfDocument::pdf_tweak_find_numbered_object(
  self : PdfDocument,
  number : Int,
  chain : ArrayView[PdfName],
  source : String,
) -> PdfObject raise PdfError {
  let object = if number == 0 {
    self.trailer_dict()
  } else {
    self.lookup_object_or_null(number)
  }
  self.pdf_tweak_find_chained_object(object, chain, source)
}

///|
fn pdf_tweak_replace_array_entry(
  values : ArrayView[PdfObject],
  index : Int,
  value : PdfObject,
  source : String,
) -> PdfObject raise PdfError {
  if index < 0 || index >= values.length() {
    raise BadPageSpecification(source)
  }
  PdfArray(
    [
      for i in 0..<values.length() => if i == index { value } else { values[i] }
    ],
  )
}

///|
fn pdf_tweak_chain_array_index(name : PdfName) -> Int? {
  let bytes = name.bytes()
  guard bytes.length() >= 3 &&
    bytes[0].to_int() == 47 &&
    bytes[1].to_int() == 91 else {
    return None
  }
  guard pdf_tweak_is_digit_byte(bytes[2]) else { return None }
  let mut value = 0
  let mut index = 2
  while index < bytes.length() && pdf_tweak_is_digit_byte(bytes[index]) {
    value = value * 10 + bytes[index].to_int() - 48
    index += 1
  }
  Some(value)
}

///|
fn PdfDocument::pdf_tweak_replace_existing_chain(
  self : PdfDocument,
  object : PdfObject,
  chain : ArrayView[PdfName],
  chain_index : Int,
  value : PdfObject,
  source : String,
) -> PdfObject raise PdfError {
  let key = chain[chain_index]
  let final_key = chain_index + 1 == chain.length()
  match object {
    PdfDictionary(_) | PdfStreamObject(_) =>
      if final_key {
        match object.lookup_immediate(key) {
          Some(_) => object.replace_dict_entry(key, value)
          None => raise BadPageSpecification(source)
        }
      } else {
        match object.lookup_immediate(key) {
          Some(PdfIndirect(number)) => {
            let updated = self.pdf_tweak_replace_existing_chain(
              self.lookup_object_or_null(number),
              chain,
              chain_index + 1,
              value,
              source,
            )
            self.add_object_given_number(number, updated)
            object
          }
          Some(child) => {
            let updated = self.pdf_tweak_replace_existing_chain(
              child,
              chain,
              chain_index + 1,
              value,
              source,
            )
            object.replace_dict_entry(key, updated)
          }
          None => raise BadPageSpecification(source)
        }
      }
    PdfArray(values) =>
      match pdf_tweak_chain_array_index(key) {
        Some(index) =>
          if final_key {
            pdf_tweak_replace_array_entry(values, index, value, source)
          } else {
            match values.get(index) {
              Some(PdfIndirect(number)) => {
                let updated = self.pdf_tweak_replace_existing_chain(
                  self.lookup_object_or_null(number),
                  chain,
                  chain_index + 1,
                  value,
                  source,
                )
                self.add_object_given_number(number, updated)
                object
              }
              Some(child) => {
                let updated = self.pdf_tweak_replace_existing_chain(
                  child,
                  chain,
                  chain_index + 1,
                  value,
                  source,
                )
                pdf_tweak_replace_array_entry(values, index, updated, source)
              }
              None => raise BadPageSpecification(source)
            }
          }
        None => raise BadPageSpecification(source)
      }
    _ => raise BadPageSpecification(source)
  }
}

///|
fn PdfDocument::pdf_tweak_replace_numbered_object(
  self : PdfDocument,
  number : Int,
  chain : ArrayView[PdfName],
  value : PdfObject,
  source : String,
) -> Unit raise PdfError {
  if chain.length() == 0 {
    if number == 0 {
      self.set_trailer_dict(value)
    } else {
      self.add_object_given_number(number, value)
    }
  } else {
    let object = if number == 0 {
      self.trailer_dict()
    } else {
      self.lookup_object_or_null(number)
    }
    let updated = self.pdf_tweak_replace_existing_chain(
      object, chain, 0, value, source,
    )
    if number == 0 {
      self.set_trailer_dict(updated)
    } else {
      self.add_object_given_number(number, updated)
    }
  }
}

///|
fn pdf_tweak_number_spec(spec : String) -> Int raise PdfError {
  let bytes = @ascii.encode(spec)
  if bytes.length() == 0 {
    raise BadPageSpecification(spec)
  }
  let digit_end = pdf_tweak_digit_end(bytes, 0)
  if digit_end != bytes.length() {
    raise BadPageSpecification(spec)
  }
  pdf_tweak_parse_digits(bytes, 0, digit_end, spec)
}

///|
/// Find an object using cpdf's object-spec grammar.
///
/// `""` selects the trailer dictionary, `/A/B` follows a trailer-rooted chain,
/// `4/A` follows a chain from object 4, and `P1/A` follows a chain from the
/// first page object.
pub fn PdfDocument::find_object_by_spec(
  self : PdfDocument,
  spec : String,
) -> PdfObject raise PdfError {
  let bytes = @ascii.encode(spec)
  if bytes.length() == 0 {
    self.trailer_dict()
  } else if bytes[0].to_int() == 80 {
    let digit_end = pdf_tweak_digit_end(bytes, 1)
    let page_number = pdf_tweak_parse_digits(bytes, 1, digit_end, spec)
    let page_refs = self.page_reference_numbers()
    if page_number < 1 || page_number > page_refs.length() {
      raise BadPageSpecification(spec)
    }
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_find_numbered_object(page_refs[page_number - 1], chain, spec)
  } else if bytes[0].to_int() == 47 {
    let chain = pdf_tweak_split_chain(bytes, 0)
    self.pdf_tweak_find_chained_object(self.trailer_dict(), chain, spec)
  } else {
    let digit_end = pdf_tweak_digit_end(bytes, 0)
    let object_number = pdf_tweak_parse_digits(bytes, 0, digit_end, spec)
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_find_numbered_object(object_number, chain, spec)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::find_object_by_spec`.
pub fn pdf_find_object(
  document : PdfDocument,
  spec : String,
) -> PdfObject raise PdfError {
  document.find_object_by_spec(spec)
}

///|
/// Compatibility wrapper matching cpdftweak's `find_obj` name.
pub fn pdf_find_obj(
  document : PdfDocument,
  spec : String,
) -> PdfObject raise PdfError {
  document.find_object_by_spec(spec)
}

///|
/// Replace an object using the cpdf object-spec grammar.
pub fn PdfDocument::replace_object_by_spec(
  self : PdfDocument,
  spec : String,
  value : PdfObject,
) -> Unit raise PdfError {
  let bytes = @ascii.encode(spec)
  if bytes.length() == 0 {
    self.set_trailer_dict(value)
  } else if bytes[0].to_int() == 80 {
    let digit_end = pdf_tweak_digit_end(bytes, 1)
    let page_number = pdf_tweak_parse_digits(bytes, 1, digit_end, spec)
    let page_refs = self.page_reference_numbers()
    if page_number < 1 || page_number > page_refs.length() {
      raise BadPageSpecification(spec)
    }
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_replace_numbered_object(
      page_refs[page_number - 1],
      chain,
      value,
      spec,
    )
  } else if bytes[0].to_int() == 47 {
    let chain = pdf_tweak_split_chain(bytes, 0)
    self.pdf_tweak_replace_numbered_object(0, chain, value, spec)
  } else {
    let digit_end = pdf_tweak_digit_end(bytes, 0)
    let object_number = pdf_tweak_parse_digits(bytes, 0, digit_end, spec)
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_replace_numbered_object(object_number, chain, value, spec)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::replace_object_by_spec`.
pub fn pdf_replace_object_by_spec(
  document : PdfDocument,
  spec : String,
  value : PdfObject,
) -> Unit raise PdfError {
  document.replace_object_by_spec(spec, value)
}

///|
/// Compatibility wrapper matching cpdftweak's `replace_obj` name.
pub fn pdf_replace_obj(
  document : PdfDocument,
  spec : String,
  value : PdfObject,
) -> Unit raise PdfError {
  document.replace_object_by_spec(spec, value)
}

///|
/// Remove an object by decimal object number string.
pub fn PdfDocument::remove_object_by_spec(
  self : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  self.remove_object(pdf_tweak_number_spec(spec))
}

///|
/// Compatibility wrapper for `PdfDocument::remove_object_by_spec`.
pub fn pdf_remove_object_by_spec(
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  document.remove_object_by_spec(spec)
}

///|
/// Compatibility wrapper matching cpdftweak's `remove_obj` name.
pub fn pdf_remove_obj(
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  document.remove_object_by_spec(spec)
}

///|
/// Replace a stream's bytes while preserving its dictionary except `/Length`.
pub fn PdfDocument::replace_stream_by_spec(
  self : PdfDocument,
  spec : String,
  data : BytesView,
) -> Unit raise PdfError {
  match self.find_object_by_spec(spec) {
    PdfStreamObject(stream) => {
      let data = data.to_owned()
      let dictionary = stream.dictionary.add_dict_entry(
        pdf_tweak_length_key(),
        PdfInteger(data.length()),
      )
      self.replace_object_by_spec(
        spec,
        PdfStreamObject({ dictionary, data: StreamGot(data) }),
      )
    }
    _ => raise ParseStreamExpected
  }
}

///|
/// Compatibility wrapper for `PdfDocument::replace_stream_by_spec`.
pub fn pdf_replace_stream_by_spec(
  document : PdfDocument,
  spec : String,
  data : BytesView,
) -> Unit raise PdfError {
  document.replace_stream_by_spec(spec, data)
}

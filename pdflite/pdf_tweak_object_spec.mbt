///|
/// Find an object using cpdf's object-spec grammar.
///
/// `""` selects the trailer dictionary, `/A/B` follows a trailer-rooted chain,
/// `4/A` follows a chain from object 4, and `P1/A` follows a chain from the
/// first page object.
pub fn PdfDocument::find_object_by_spec(
  self : PdfDocument,
  spec : String,
) -> @syntax.PdfObject raise PdfError {
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
) -> @syntax.PdfObject raise PdfError {
  document.find_object_by_spec(spec)
}

///|
/// Compatibility wrapper matching cpdftweak's `find_obj` name.
pub fn pdf_find_obj(
  document : PdfDocument,
  spec : String,
) -> @syntax.PdfObject raise PdfError {
  document.find_object_by_spec(spec)
}

///|
/// Replace an object using the cpdf object-spec grammar.
pub fn PdfDocument::replace_object_by_spec(
  self : PdfDocument,
  spec : String,
  value : @syntax.PdfObject,
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
  value : @syntax.PdfObject,
) -> Unit raise PdfError {
  document.replace_object_by_spec(spec, value)
}

///|
/// Compatibility wrapper matching cpdftweak's `replace_obj` name.
pub fn pdf_replace_obj(
  document : PdfDocument,
  spec : String,
  value : @syntax.PdfObject,
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

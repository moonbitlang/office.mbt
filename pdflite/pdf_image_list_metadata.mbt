///|
fn PdfDocument::pdf_image_lookup_int_or_default(
  self : PdfDocument,
  first_key : PdfName,
  second_key : PdfName,
  image : @syntax.PdfObject,
  default : Int,
) -> Int raise PdfError {
  match self.lookup_direct_or_else(first_key, second_key, image) {
    Some(value) => self.get_number(value).to_int()
    None => default
  }
}

///|
fn PdfDocument::pdf_image_stream_length(
  self : PdfDocument,
  image : @syntax.PdfObject,
  fallback : Int,
) -> Int {
  match self.lookup_direct(pdf_image_length_key(), image) {
    Some(PdfInteger(value)) => value
    _ => fallback
  }
}

///|
fn PdfDocument::pdf_image_bits_per_component_number(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> Int? raise PdfError {
  match self.image_bits_per_component(image) {
    Some(PdfInteger(value)) => Some(value)
    Some(_) => raise NumberExpected
    None => None
  }
}

///|
fn PdfDocument::pdf_image_colourspace_name(
  self : PdfDocument,
  image : @syntax.PdfObject,
  resources : @syntax.PdfObject,
) -> String? {
  Some(self.image_colour_space(image, resources).debug_name()) catch {
    _ => None
  }
}

///|
fn pdf_image_single_filter_object(
  filter : @syntax.PdfObject,
) -> @syntax.PdfObject {
  match filter {
    PdfArray([single]) => single
    _ => filter
  }
}

///|
fn pdf_image_filter_is_name(filter : @syntax.PdfObject, name : PdfName) -> Bool {
  match filter {
    PdfNameObject(filter_name) => filter_name == name
    PdfArray([PdfNameObject(filter_name)]) => filter_name == name
    _ => false
  }
}

///|
fn PdfDocument::pdf_image_first_decodeparms(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> @syntax.PdfObject? {
  match
    self.lookup_direct_or_else(
      pdf_image_decodeparms_key(),
      pdf_image_dp_key(),
      image,
    ) {
    Some(PdfArray([first, ..])) =>
      match self.direct(first) {
        PdfDictionary(_) as dictionary => Some(dictionary)
        _ => None
      }
    Some(PdfDictionary(_) as dictionary) => Some(dictionary)
    _ => None
  }
}

///|
fn PdfDocument::pdf_image_decodeparms_k(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> Int? {
  match self.pdf_image_first_decodeparms(image) {
    Some(decodeparms) =>
      match self.lookup_direct(pdf_image_k_key(), decodeparms) {
        Some(PdfInteger(value)) => Some(value)
        _ => None
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_image_decodeparms_has_jbig2_globals(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> Bool {
  match self.pdf_image_first_decodeparms(image) {
    Some(decodeparms) =>
      match self.lookup_direct(pdf_image_jbig2_globals_key(), decodeparms) {
        Some(_) => true
        None => false
      }
    None => false
  }
}

///|
fn PdfDocument::pdf_image_filter_name(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> String? raise PdfError {
  match
    self.lookup_direct_or_else(pdf_image_filter_key(), pdf_image_f_key(), image) {
    Some(filter) if pdf_image_filter_is_name(
        filter,
        pdf_image_ccittfaxdecode_name(),
      ) =>
      match self.pdf_image_decodeparms_k(image) {
        Some(value) if value < 0 => Some("/CCITTFaxDecodeG4")
        Some(value) if value > 0 => Some("/CCITTFaxDecodeG32D")
        Some(0) => Some("/CCITTFaxDecodeG31D")
        _ => Some("/CCITTFaxDecode")
      }
    Some(filter) if pdf_image_filter_is_name(
        filter,
        pdf_image_jbig2decode_name(),
      ) =>
      if self.pdf_image_decodeparms_has_jbig2_globals(image) {
        Some("/JBIG2DecodeLossy")
      } else {
        Some("/JBIG2DecodeLossless")
      }
    Some(filter) =>
      Some(
        @ascii.decode(pdf_write_object(pdf_image_single_filter_object(filter))) catch {
          _ => raise InvalidUTF8
        },
      )
    None => None
  }
}

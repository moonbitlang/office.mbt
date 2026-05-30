///|
let pdf_crypt_stream_length_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Length"),
)

///|
fn pdf_crypt_stream_length_key() -> PdfName {
  pdf_crypt_stream_length_key_name
}

///|
fn pdf_crypt_stream_filter_key() -> PdfName {
  pdf_crypt_filter_name
}

///|
fn pdf_crypt_stream_decodeparms_key() -> PdfName {
  pdf_crypt_decodeparms_name
}

///|
fn pdf_crypt_stream_name_key() -> PdfName {
  pdf_crypt_name_key_name
}

///|
fn pdf_crypt_stream_type_key() -> PdfName {
  pdf_crypt_type_name
}

///|
fn pdf_crypt_object_is_name(
  object : @syntax.PdfObject?,
  expected : PdfName,
) -> Bool {
  match object {
    Some(PdfNameObject(name)) => name == expected
    _ => false
  }
}

///|
fn pdf_crypt_first_filter_is_crypt(dictionary : @syntax.PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_crypt_stream_filter_key()) {
    Some(PdfNameObject(name)) => name == pdf_crypt_crypt_name
    Some(PdfArray([PdfNameObject(name), ..])) => name == pdf_crypt_crypt_name
    _ => false
  }
}

///|
fn pdf_crypt_decodeparms_is_identity(dictionary : @syntax.PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_crypt_stream_decodeparms_key()) {
    Some(PdfDictionary(_) as decodeparms)
    | Some(PdfArray([PdfDictionary(_) as decodeparms, ..])) =>
      match decodeparms.lookup_immediate(pdf_crypt_stream_name_key()) {
        Some(PdfNameObject(name)) => name == pdf_crypt_identity_name
        None => true
        _ => false
      }
    _ => true
  }
}

///|
fn pdf_crypt_stream_is_identity(
  no_encrypt_metadata : Bool,
  dictionary : @syntax.PdfObject,
) -> Bool {
  if no_encrypt_metadata &&
    pdf_crypt_object_is_name(
      dictionary.lookup_immediate(pdf_crypt_stream_type_key()),
      pdf_crypt_metadata_name,
    ) {
    true
  } else {
    pdf_crypt_first_filter_is_crypt(dictionary) &&
    pdf_crypt_decodeparms_is_identity(dictionary)
  }
}

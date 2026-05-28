///|
fn pdf_metadata_bool_string(value : Bool) -> String {
  if value {
    "True"
  } else {
    "False"
  }
}

///|
fn pdf_metadata_ascii_codepoints(bytes : BytesView) -> PdfBytes raise PdfError {
  let codepoints = pdf_codepoints_of_pdfdocstring(bytes)
  let mut output_length = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      output_length += 1
    }
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      output[position] = pdf_byte_of_int(codepoint)
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
/// Encode a PDF string for metadata/reporting output.
pub fn pdf_metadata_encode_output(
  encoding : PdfMetadataEncoding,
  bytes : BytesView,
) -> PdfBytes raise PdfError {
  match encoding {
    PdfMetadataRaw => bytes.to_owned()
    PdfMetadataUTF8 => pdf_utf8_of_pdfdocstring(bytes)
    PdfMetadataStripped => pdf_metadata_ascii_codepoints(bytes)
  }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `encode_output`.
pub fn pdf_encode_output(
  encoding : PdfMetadataEncoding,
  bytes : BytesView,
) -> PdfBytes raise PdfError {
  pdf_metadata_encode_output(encoding, bytes)
}

///|
fn PdfDocument::pdf_metadata_bump_minor(
  self : PdfDocument,
  version : Int,
  keep_version : Bool,
) -> Unit {
  if self.major == 1 && !keep_version && self.minor < version {
    self.minor = version
  }
}

///|
fn PdfDocument::pdf_metadata_replace_catalog(
  self : PdfDocument,
  catalog : PdfObject,
) -> Unit raise PdfError {
  let root_number = self.add_object(catalog)
  self.set_root(root_number)
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_metadata_root(), PdfIndirect(root_number)),
  )
}

///|
fn PdfDocument::pdf_metadata_update_catalog(
  self : PdfDocument,
  update : (PdfObject) -> PdfObject raise PdfError,
) -> Unit raise PdfError {
  let catalog = self.catalog()
  self.pdf_metadata_replace_catalog(update(catalog))
}

///|
fn pdf_metadata_name_string(name : PdfName) -> String raise PdfError {
  let bytes = name.bytes()
  let start = if bytes.length() > 0 && bytes[0].to_int() == 47 { 1 } else { 0 }
  @ascii.decode(bytes[start:]) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_metadata_known_name(
  value : String,
  allowed : ArrayView[String],
  error_prefix : String,
) -> PdfName raise PdfError {
  for allowed_value in allowed {
    if value == allowed_value {
      break pdf_metadata_name("/" + value)
    }
  } nobreak {
    raise BadNumberArgument(error_prefix + value)
  }
}

///|
/// Copy the trailer `/ID` from `source` onto this document.
///
/// The original document is left unchanged. When `keep_version` is false, PDF

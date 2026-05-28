///|
fn pdf_content_extgstate_number(object : PdfObject) -> Double? {
  match object {
    PdfReal(value) => Some(value)
    PdfInteger(value) => Some(value.to_double())
    _ => None
  }
}

///|
fn pdf_content_extgstate_integer(object : PdfObject) -> Int? {
  match object {
    PdfInteger(value) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::content_extgstate_number(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Double? {
  match self.lookup_direct(key, extgstate) {
    Some(value) => pdf_content_extgstate_number(value)
    None => None
  }
}

///|
fn PdfDocument::content_extgstate_integer(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Int? {
  match self.lookup_direct(key, extgstate) {
    Some(value) => pdf_content_extgstate_integer(value)
    None => None
  }
}

///|
fn PdfDocument::content_extgstate_name_value(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> PdfName? {
  match self.lookup_direct(key, extgstate) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::content_extgstate_boolean(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Bool? {
  match self.lookup_direct(key, extgstate) {
    Some(PdfBoolean(value)) => Some(value)
    _ => None
  }
}

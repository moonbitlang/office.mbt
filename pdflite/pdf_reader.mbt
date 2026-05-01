///|
pub(all) struct PdfVersion {
  major : Int
  minor : Int
} derive(Debug, Eq, ToJson)

///|
pub let pdf_default_version : PdfVersion = { major: 2, minor: 0 }

///|
fn pdf_is_digit_byte(value : Int) -> Bool {
  value >= 48 && value <= 57
}

///|
fn ByteCursor::pdf_header_at(self : ByteCursor, position : Int) -> PdfVersion? {
  if position < 0 || position + 7 >= self.data.length() {
    None
  } else if self.data[position].to_int() == 37 &&
    self.data[position + 1].to_int() == 80 &&
    self.data[position + 2].to_int() == 68 &&
    self.data[position + 3].to_int() == 70 &&
    self.data[position + 4].to_int() == 45 &&
    self.data[position + 6].to_int() == 46 {
    let major = self.data[position + 5].to_int()
    let minor = self.data[position + 7].to_int()
    if pdf_is_digit_byte(major) && pdf_is_digit_byte(minor) {
      Some({ major: major - 48, minor: minor - 48 })
    } else {
      None
    }
  } else {
    None
  }
}

///|
pub fn ByteCursor::read_pdf_header(
  self : ByteCursor,
) -> PdfVersion raise PdfError {
  let max_probe = if self.data.length() < 1024 {
    self.data.length()
  } else {
    1024
  }
  for position = 0; position <= max_probe; position = position + 1 {
    match self.pdf_header_at(position) {
      Some(version) => {
        self.set_offset(position)
        self.position = position + 8
        break version
      }
      None => ()
    }
  } nobreak {
    pdf_default_version
  }
}

///|
pub fn pdf_read_header_from_bytes(data : PdfBytes) -> PdfVersion raise PdfError {
  byte_cursor_of_bytes(data).read_pdf_header()
}

///|
pub fn pdf_document_of_parsed_indirect_objects(
  objects : ArrayView[PdfParsedIndirectObject],
  version? : PdfVersion = pdf_default_version,
) -> PdfDocument {
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  for parsed in objects {
    document.add_object_given_number(
      parsed.number,
      parsed.object,
      generation=parsed.generation,
    )
  }
  document
}

///|
pub fn pdf_read_primitive_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  let cursor = byte_cursor_of_bytes(data)
  let version = cursor.read_pdf_header()
  let objects = pdf_parse_indirect_objects(cursor.lex_pdf_tokens())
  pdf_document_of_parsed_indirect_objects(objects, version~)
}

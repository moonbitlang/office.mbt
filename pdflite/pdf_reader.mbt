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
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  let mut done = false
  while !done {
    let (objects, prefix) = pdf_parse_indirect_object_segments(
      cursor.lex_pdf_tokens(),
    )
    for parsed in objects {
      document.add_object_given_number(
        parsed.number,
        parsed.object,
        generation=parsed.generation,
      )
    }
    match prefix {
      Some(prefix) => {
        let stream = cursor.finish_pdf_stream_object(prefix)
        document.add_object_given_number(
          stream.number,
          stream.object,
          generation=stream.generation,
        )
      }
      None => done = true
    }
  }
  document
}

///|
fn pdf_length_name() -> PdfName {
  pdf_name_of_bytes(Bytes::from_array([47, 76, 101, 110, 103, 116, 104]))
}

///|
fn pdf_stream_length(object : PdfObject) -> Int raise PdfError {
  match object.lookup_immediate(pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    _ => raise StreamLengthExpected
  }
}

///|
fn ByteCursor::consume_pdf_ascii(
  self : ByteCursor,
  values : ArrayView[Int],
  error : PdfError,
) -> Unit raise PdfError {
  let position = self.absolute_position()
  if self.matches_pdf_ascii_at(position, values) {
    self.seek(position + values.length())
  } else {
    raise error
  }
}

///|
fn ByteCursor::consume_pdf_stream_line_break(self : ByteCursor) -> Unit {
  let value = self.peek_byte()
  if value == 13 {
    self.nudge()
    if self.peek_byte() == 10 {
      self.nudge()
    }
  } else if value == 10 {
    self.nudge()
  }
}

///|
fn ByteCursor::finish_pdf_stream_object(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
  let length = pdf_stream_length(prefix.object)
  self.consume_pdf_ascii([115, 116, 114, 101, 97, 109], ParseStreamExpected)
  self.consume_pdf_stream_line_break()
  let stream_data = self.read_bytes(length)
  self.consume_pdf_stream_line_break()
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii(
    [101, 110, 100, 115, 116, 114, 101, 97, 109],
    ParseEndStreamExpected,
  )
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii([101, 110, 100, 111, 98, 106], ParseEndObjectExpected)
  {
    number: prefix.number,
    generation: prefix.generation,
    object: pdf_stream(prefix.object, StreamGot(stream_data)),
  }
}

///|
pub fn pdf_parse_stream_object_from_bytes(
  data : PdfBytes,
) -> PdfParsedIndirectObject raise PdfError {
  let cursor = byte_cursor_of_bytes(data)
  let prefix = pdf_parse_indirect_object_prefix_lexemes(cursor.lex_pdf_tokens())
  cursor.finish_pdf_stream_object(prefix)
}

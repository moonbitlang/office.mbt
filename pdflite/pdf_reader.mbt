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
struct PdfClassicXRefEntry {
  object_number : Int
  offset : Int
  generation : Int
  in_use : Bool
} derive(Debug, Eq, ToJson)

///|
fn ByteCursor::seek_pdf_absolute(
  self : ByteCursor,
  position : Int,
) -> Unit raise PdfError {
  if position < 0 || position > self.data.length() {
    raise InvalidCursorPosition(position)
  }
  self.position = position
}

///|
fn pdf_view_matches_ascii_at(
  view : BytesView,
  position : Int,
  values : ArrayView[Int],
) -> Bool {
  if position < 0 || position + values.length() > view.length() {
    false
  } else {
    for i = 0; i < values.length(); i = i + 1 {
      if view[position + i].to_int() != values[i] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_find_last_ascii(view : BytesView, values : ArrayView[Int]) -> Int {
  if values.length() == 0 {
    view.length()
  } else if view.length() < values.length() {
    -1
  } else {
    for start = view.length() - values.length(); start >= 0; start = start - 1 {
      if pdf_view_matches_ascii_at(view, start, values) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn pdf_parse_ascii_int_view(view : BytesView) -> Int raise PdfError {
  if view.length() == 0 {
    raise NumberExpected
  }
  let mut value = 0
  for byte in view {
    let digit = byte.to_int()
    if !pdf_is_digit_byte(digit) {
      raise NumberExpected
    }
    value = value * 10 + digit - 48
  }
  value
}

///|
fn pdf_split_whitespace_tokens(view : BytesView) -> Array[BytesView] {
  let tokens : Array[BytesView] = []
  let mut index = 0
  while index < view.length() {
    while index < view.length() && pdf_is_whitespace_byte(view[index].to_int()) {
      index += 1
    }
    let start = index
    while index < view.length() && !pdf_is_whitespace_byte(view[index].to_int()) {
      index += 1
    }
    if start < index {
      tokens.push(view[start:index])
    }
  }
  tokens
}

///|
fn pdf_read_startxref_position(data : BytesView) -> Int raise PdfError {
  let start = pdf_find_last_ascii(data, [
    115, 116, 97, 114, 116, 120, 114, 101, 102,
  ])
  if start < 0 {
    raise StartXRefExpected
  }
  let cursor = byte_cursor_of_view(data[start + 9:])
  cursor.drop_pdf_whitespace()
  pdf_parse_ascii_int_view(cursor.read_pdf_regular_token_view())
}

///|
fn pdf_xref_token_in_use(token : BytesView) -> Bool raise PdfError {
  if token.length() == 0 {
    raise XRefEntryExpected
  }
  match token[0].to_int() {
    110 => true
    102 => false
    _ => raise XRefEntryExpected
  }
}

///|
fn pdf_classic_xref_lookup(
  xrefs : ArrayView[PdfClassicXRefEntry],
  object_number : Int,
) -> PdfClassicXRefEntry? {
  for xref in xrefs {
    if xref.in_use && xref.object_number == object_number {
      break Some(xref)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_classic_xrefs_contain(
  xrefs : ArrayView[PdfClassicXRefEntry],
  object_number : Int,
) -> Bool {
  for xref in xrefs {
    if xref.object_number == object_number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_classic_xrefs_add_newer_first(
  target : Array[PdfClassicXRefEntry],
  entries : ArrayView[PdfClassicXRefEntry],
) -> Unit {
  for entry in entries {
    if !pdf_classic_xrefs_contain(target[:], entry.object_number) {
      target.push(entry)
    }
  }
}

///|
fn ByteCursor::read_pdf_classic_xref_entries(
  self : ByteCursor,
) -> Array[PdfClassicXRefEntry] raise PdfError {
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii([120, 114, 101, 102], XRefExpected)
  let entries : Array[PdfClassicXRefEntry] = []
  let mut object_number = 0
  let mut done = false
  while !done {
    self.drop_pdf_whitespace()
    let position = self.absolute_position()
    if self.matches_pdf_ascii_at(position, [116, 114, 97, 105, 108, 101, 114]) {
      done = true
    } else if self.peek_byte() == pdf_no_more {
      raise TrailerExpected
    } else {
      let tokens = pdf_split_whitespace_tokens(self.read_line_view())
      if tokens.length() == 2 {
        object_number = pdf_parse_ascii_int_view(tokens[0])
        ignore(pdf_parse_ascii_int_view(tokens[1]))
      } else if tokens.length() >= 3 {
        entries.push({
          object_number,
          offset: pdf_parse_ascii_int_view(tokens[0]),
          generation: pdf_parse_ascii_int_view(tokens[1]),
          in_use: pdf_xref_token_in_use(tokens[2]),
        })
        object_number += 1
      } else {
        raise XRefEntryExpected
      }
    }
  }
  entries
}

///|
fn ByteCursor::read_pdf_trailer_dictionary(
  self : ByteCursor,
) -> PdfObject raise PdfError {
  self.drop_pdf_whitespace()
  self.consume_pdf_ascii([116, 114, 97, 105, 108, 101, 114], TrailerExpected)
  self.drop_pdf_whitespace()
  let object = pdf_parse_single_lexeme_object(self.lex_pdf_tokens())
  match object {
    PdfDictionary(_) => object
    _ => raise TrailerExpected
  }
}

///|
fn ByteCursor::read_plain_indirect_object_at_current(
  self : ByteCursor,
) -> PdfParsedIndirectObject raise PdfError {
  let (objects, prefix) = pdf_parse_indirect_object_segments(
    self.lex_pdf_tokens(),
  )
  if objects.length() > 0 {
    objects[0]
  } else {
    match prefix {
      Some(_) => raise StreamLengthExpected
      None => raise ParseIndirectObjectExpected
    }
  }
}

///|
fn ByteCursor::resolve_classic_stream_length(
  self : ByteCursor,
  object : PdfObject,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> Int raise PdfError {
  match object.lookup_immediate(pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    Some(PdfIndirect(number)) =>
      match pdf_classic_xref_lookup(xrefs, number) {
        Some(xref) => {
          let saved_position = self.absolute_position()
          self.seek_pdf_absolute(xref.offset)
          let parsed = self.read_plain_indirect_object_at_current()
          self.seek_pdf_absolute(saved_position)
          if parsed.number != number || parsed.generation != xref.generation {
            raise XRefEntryExpected
          }
          match parsed.object {
            PdfInteger(length) if length >= 0 => length
            _ => raise StreamLengthExpected
          }
        }
        None => raise StreamLengthExpected
      }
    _ => raise StreamLengthExpected
  }
}

///|
fn ByteCursor::read_first_indirect_object_at_current(
  self : ByteCursor,
  xrefs : ArrayView[PdfClassicXRefEntry],
) -> PdfParsedIndirectObject raise PdfError {
  let (objects, prefix) = pdf_parse_indirect_object_segments(
    self.lex_pdf_tokens(),
  )
  if objects.length() > 0 {
    objects[0]
  } else {
    match prefix {
      Some(prefix) => {
        let length = self.resolve_classic_stream_length(prefix.object, xrefs)
        self.finish_pdf_stream_object_with_length(prefix, length)
      }
      None => raise ParseIndirectObjectExpected
    }
  }
}

///|
fn pdf_reader_root_name() -> PdfName {
  pdf_name_of_bytes(Bytes::from_array([47, 82, 111, 111, 116]))
}

///|
fn pdf_reader_prev_name() -> PdfName {
  pdf_name_of_bytes(Bytes::from_array([47, 80, 114, 101, 118]))
}

///|
fn pdf_trailer_prev_position(trailer : PdfObject) -> Int? raise PdfError {
  match trailer.lookup_immediate(pdf_reader_prev_name()) {
    Some(PdfInteger(position)) if position >= 0 => Some(position)
    Some(_) => raise TrailerExpected
    None => None
  }
}

///|
fn PdfDocument::set_trailer_and_root(
  self : PdfDocument,
  trailer : PdfObject,
) -> Unit raise PdfError {
  self.set_trailer_dict(trailer)
  match trailer.lookup_immediate(pdf_reader_root_name()) {
    Some(PdfIndirect(root)) => self.set_root(root)
    _ => raise RootExpected
  }
}

///|
pub fn pdf_read_classic_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  let cursor = byte_cursor_of_bytes(data)
  let version = cursor.read_pdf_header()
  let xref_position = pdf_read_startxref_position(cursor.data)
  let xrefs : Array[PdfClassicXRefEntry] = []
  let mut trailer = PdfDictionary([])
  let mut current_xref = xref_position
  let mut done = false
  let mut depth = 0
  while !done {
    if depth >= 1024 {
      raise XRefExpected
    }
    cursor.seek_pdf_absolute(current_xref)
    pdf_classic_xrefs_add_newer_first(
      xrefs,
      cursor.read_pdf_classic_xref_entries(),
    )
    let current_trailer = cursor.read_pdf_trailer_dictionary()
    if depth == 0 {
      trailer = current_trailer
    }
    match pdf_trailer_prev_position(current_trailer) {
      Some(previous) => current_xref = previous
      None => done = true
    }
    depth += 1
  }
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(xref_position)
  document.set_trailer_and_root(trailer)
  for xref in xrefs {
    if xref.in_use && xref.object_number != 0 {
      cursor.seek_pdf_absolute(xref.offset)
      let parsed = cursor.read_first_indirect_object_at_current(xrefs)
      if parsed.number != xref.object_number ||
        parsed.generation != xref.generation {
        raise XRefEntryExpected
      }
      document.add_object_given_number(
        parsed.number,
        parsed.object,
        generation=parsed.generation,
      )
    }
  }
  document
}

///|
pub fn pdf_read_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_bytes(data)
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
  self.finish_pdf_stream_object_with_length(prefix, length)
}

///|
fn ByteCursor::finish_pdf_stream_object_with_length(
  self : ByteCursor,
  prefix : PdfParsedIndirectObject,
  length : Int,
) -> PdfParsedIndirectObject raise PdfError {
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

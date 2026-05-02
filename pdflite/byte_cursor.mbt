///|
pub let pdf_no_more : Int = -1

///|
pub struct ByteCursor {
  data : BytesView
  mut position : Int
  mut offset : Int
  source : String
} derive(Debug, Eq, ToJson)

///|
pub fn byte_cursor_of_bytes(
  data : PdfBytes,
  source? : String = "bytes",
) -> ByteCursor {
  byte_cursor_of_view(data[:], source~)
}

///|
pub fn byte_cursor_of_view(
  data : BytesView,
  source? : String = "bytes",
) -> ByteCursor {
  { data, position: 0, offset: 0, source }
}

///|
pub fn ByteCursor::source(self : ByteCursor) -> String {
  self.source
}

///|
pub fn ByteCursor::input_pdf_error(
  self : ByteCursor,
  message : String,
) -> String {
  message +
  " whilst reading file " +
  self.source +
  " at position " +
  self.position().to_string()
}

///|
pub fn ByteCursor::length(self : ByteCursor) -> Int {
  self.data.length()
}

///|
pub fn ByteCursor::position(self : ByteCursor) -> Int {
  self.position - self.offset
}

///|
pub fn ByteCursor::absolute_position(self : ByteCursor) -> Int {
  self.position
}

///|
pub fn ByteCursor::remaining_length(self : ByteCursor) -> Int {
  if self.position >= self.data.length() {
    0
  } else {
    self.data.length() - self.position
  }
}

///|
pub fn ByteCursor::set_offset(
  self : ByteCursor,
  offset : Int,
) -> Unit raise PdfError {
  if offset < 0 {
    raise InvalidCursorPosition(offset)
  }
  if self.offset == 0 {
    self.offset = offset
  }
}

///|
pub fn ByteCursor::seek(
  self : ByteCursor,
  position : Int,
) -> Unit raise PdfError {
  let absolute = position + self.offset
  if absolute < 0 {
    raise InvalidCursorPosition(position)
  }
  self.position = absolute
}

///|
pub fn ByteCursor::input_byte(self : ByteCursor) -> Int {
  let value = if self.position > self.data.length() - 1 {
    pdf_no_more
  } else {
    self.data[self.position].to_int()
  }
  self.position += 1
  value
}

///|
pub fn ByteCursor::read_byte(self : ByteCursor) -> Byte? {
  if self.position >= self.data.length() {
    None
  } else {
    let value = self.data[self.position]
    self.position += 1
    Some(value)
  }
}

///|
pub fn ByteCursor::peek_byte(self : ByteCursor) -> Int {
  let value = self.input_byte()
  self.position -= 1
  value
}

///|
pub fn ByteCursor::peek(self : ByteCursor) -> Byte? {
  let value = self.peek_byte()
  if value == pdf_no_more {
    None
  } else {
    Some(value.to_byte())
  }
}

///|
pub fn ByteCursor::nudge(self : ByteCursor) -> Unit {
  ignore(self.input_byte())
}

///|
pub fn ByteCursor::rewind(self : ByteCursor) -> Unit raise PdfError {
  if self.position <= self.offset {
    raise InvalidCursorPosition(self.position() - 1)
  }
  self.position -= 1
}

///|
pub fn ByteCursor::read_byte_back(self : ByteCursor) -> Byte? {
  if self.position <= self.offset {
    None
  } else {
    self.position -= 1
    if self.position >= self.data.length() {
      None
    } else {
      Some(self.data[self.position])
    }
  }
}

///|
pub fn ByteCursor::remaining_view(self : ByteCursor) -> BytesView {
  if self.position >= self.data.length() {
    self.data[self.data.length():]
  } else {
    self.data[self.position:]
  }
}

///|
pub fn ByteCursor::read_view(
  self : ByteCursor,
  length : Int,
) -> BytesView raise PdfError {
  if length < 0 {
    raise InvalidReadLength(length)
  }
  let end = self.position + length
  if end > self.data.length() {
    raise EndOfInput
  }
  let view = self.data[self.position:end]
  self.position = end
  view
}

///|
pub fn ByteCursor::read_view_at(
  self : ByteCursor,
  position : Int,
  length : Int,
) -> BytesView raise PdfError {
  self.seek(position)
  self.read_view(length)
}

///|
pub fn ByteCursor::read_until_view(
  self : ByteCursor,
  stop : (Int) -> Bool,
  eof_is_delimiter? : Bool = true,
) -> BytesView raise PdfError {
  let start = self.position
  let mut done = false
  while !done {
    let value = self.peek_byte()
    if value == pdf_no_more {
      if eof_is_delimiter {
        done = true
      } else {
        raise EndOfInput
      }
    } else if stop(value) {
      done = true
    } else {
      self.nudge()
    }
  }
  self.data[start:self.position]
}

///|
pub fn ByteCursor::ignore_until(
  self : ByteCursor,
  stop : (Int) -> Bool,
  eof_is_delimiter? : Bool = true,
) -> Unit raise PdfError {
  let mut done = false
  while !done {
    let value = self.peek_byte()
    if value == pdf_no_more {
      if eof_is_delimiter {
        done = true
      } else {
        raise EndOfInput
      }
    } else if stop(value) {
      done = true
    } else {
      self.nudge()
    }
  }
}

///|
pub fn ByteCursor::read_bytes(
  self : ByteCursor,
  length : Int,
) -> PdfBytes raise PdfError {
  self.read_view(length).to_owned()
}

///|
pub fn ByteCursor::read_bytes_at(
  self : ByteCursor,
  position : Int,
  length : Int,
) -> PdfBytes raise PdfError {
  self.read_view_at(position, length).to_owned()
}

///|
pub fn ByteCursor::read_line_view(
  self : ByteCursor,
) -> BytesView raise PdfError {
  if self.position >= self.data.length() {
    raise EndOfInput
  }
  let start = self.position
  let mut done = false
  while !done && self.position < self.data.length() {
    let value = self.input_byte()
    if value == 0x0A {
      done = true
    }
  }
  self.data[start:self.position]
}

///|
pub fn ByteCursor::read_line(self : ByteCursor) -> PdfBytes raise PdfError {
  self.read_line_view().to_owned()
}

///|
pub fn ByteCursor::read_line_views(self : ByteCursor) -> Array[BytesView] {
  let lines : Array[BytesView] = []
  while self.position < self.data.length() {
    lines.push(try! self.read_line_view())
  }
  lines
}

///|
pub fn ByteCursor::read_lines(self : ByteCursor) -> Array[PdfBytes] {
  self.read_line_views().map(view => view.to_owned())
}

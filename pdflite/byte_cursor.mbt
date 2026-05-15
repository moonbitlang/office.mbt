///|
/// Sentinel returned by legacy byte-reading helpers when the cursor is past the
/// end of input.
///
/// Newer APIs usually return `Byte?`, but this value preserves the CamlPDF-style
/// integer cursor contract used by parser code.
pub let pdf_no_more : Int = -1

///|
/// A mutable read cursor over a PDF byte view.
///
/// `ByteCursor` keeps a source label for diagnostics and supports an optional
/// logical offset. After `set_offset`, public positions are relative to that
/// offset while absolute positions still refer to the underlying byte view.
pub struct ByteCursor {
  data : BytesView
  mut position : Int
  mut offset : Int
  source : String
} derive(Debug, Eq, ToJson)

///|
/// Creates a cursor over owned PDF bytes.
///
/// The cursor borrows the byte storage through a view and does not copy it.
pub fn byte_cursor_of_bytes(
  data : PdfBytes,
  source? : String = "bytes",
) -> ByteCursor {
  byte_cursor_of_view(data, source~)
}

///|
/// Creates a cursor over a byte view.
///
/// The optional `source` label appears in parse error messages.
pub fn byte_cursor_of_view(
  data : BytesView,
  source? : String = "bytes",
) -> ByteCursor {
  { data, position: 0, offset: 0, source }
}

///|
/// Returns the diagnostic source label associated with this cursor.
pub fn ByteCursor::source(self : ByteCursor) -> String {
  self.source
}

///|
/// Formats an input error message with the source label and current logical
/// position.
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
/// Returns the total length of the underlying byte view.
pub fn ByteCursor::length(self : ByteCursor) -> Int {
  self.data.length()
}

///|
/// Returns the underlying read-only byte view without copying.
pub fn ByteCursor::view(self : ByteCursor) -> BytesView {
  self.data
}

///|
/// Copies the underlying byte view into owned PDF bytes.
pub fn ByteCursor::to_bytes(self : ByteCursor) -> PdfBytes {
  self.data.to_owned()
}

///|
/// Returns the current logical position, relative to the configured offset.
pub fn ByteCursor::position(self : ByteCursor) -> Int {
  self.position - self.offset
}

///|
/// Returns the current absolute position in the underlying byte view.
pub fn ByteCursor::absolute_position(self : ByteCursor) -> Int {
  self.position
}

///|
/// Returns the number of unread bytes remaining from the absolute cursor
/// position.
pub fn ByteCursor::remaining_length(self : ByteCursor) -> Int {
  if self.position >= self.data.length() {
    0
  } else {
    self.data.length() - self.position
  }
}

///|
/// Sets the logical position offset used by `position` and `seek`.
///
/// The offset can only be set once and must be non-negative. This is used when
/// parsing substreams whose local position should start at zero while retaining
/// absolute positions for diagnostics.
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
/// Moves the cursor to a logical position.
///
/// The supplied position is interpreted relative to the configured offset.
/// Seeking past the end is allowed so callers can probe EOF behavior; negative
/// absolute positions raise `PdfError::InvalidCursorPosition`.
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
/// Reads one byte as an integer and advances the cursor.
///
/// Returns `pdf_no_more` when reading past the end. This method always advances
/// by one position, matching the historical parser cursor behavior.
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
/// Reads one byte and advances the cursor, returning `None` at end of input.
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
/// Returns the next byte as an integer without consuming it.
///
/// Returns `pdf_no_more` at end of input.
pub fn ByteCursor::peek_byte(self : ByteCursor) -> Int {
  let value = self.input_byte()
  self.position -= 1
  value
}

///|
/// Returns the next byte without consuming it, or `None` at end of input.
pub fn ByteCursor::peek(self : ByteCursor) -> Byte? {
  let value = self.peek_byte()
  if value == pdf_no_more {
    None
  } else {
    Some(value.to_byte())
  }
}

///|
/// Returns a read-only view of the next `length` bytes without advancing.
///
/// Raises `PdfError::InvalidReadLength` for negative lengths and
/// `PdfError::EndOfInput` if the requested range extends past the input.
pub fn ByteCursor::peek_view(
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
  self.data[self.position:end]
}

///|
/// Copies the next `length` bytes without advancing.
///
/// Raises the same errors as `peek_view`.
pub fn ByteCursor::peek_bytes(
  self : ByteCursor,
  length : Int,
) -> PdfBytes raise PdfError {
  self.peek_view(length).to_owned()
}

///|
/// Advances the cursor by one byte, ignoring the value read.
pub fn ByteCursor::nudge(self : ByteCursor) -> Unit {
  ignore(self.input_byte())
}

///|
/// Moves the cursor one byte backward.
///
/// Raises `PdfError::InvalidCursorPosition` if the cursor is already at the
/// logical start position.
pub fn ByteCursor::rewind(self : ByteCursor) -> Unit raise PdfError {
  if self.position <= self.offset {
    raise InvalidCursorPosition(self.position() - 1)
  }
  self.position -= 1
}

///|
/// Reads the previous byte and moves the cursor backward.
///
/// Returns `None` when the cursor is at the logical start or when the resulting
/// position is outside the underlying view.
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
/// Returns a view of all bytes from the current position to the end of input.
pub fn ByteCursor::remaining_view(self : ByteCursor) -> BytesView {
  if self.position >= self.data.length() {
    self.data[self.data.length():]
  } else {
    self.data[self.position:]
  }
}

///|
/// Reads `length` bytes as a view and advances past them.
///
/// Raises `PdfError::InvalidReadLength` for negative lengths and
/// `PdfError::EndOfInput` if the requested range extends past the input.
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
/// Seeks to `position`, then reads `length` bytes as a view.
///
/// The returned view borrows the cursor input; use `read_bytes_at` when owned
/// bytes are required.
pub fn ByteCursor::read_view_at(
  self : ByteCursor,
  position : Int,
  length : Int,
) -> BytesView raise PdfError {
  self.seek(position)
  self.read_view(length)
}

///|
/// Reads until `stop` matches the next byte and returns the bytes before it.
///
/// The delimiter byte is not consumed. If EOF is reached and `eof_is_delimiter`
/// is true, the remaining bytes are returned; otherwise `PdfError::EndOfInput`
/// is raised.
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
/// Advances until `stop` matches the next byte.
///
/// The delimiter byte is left unread. EOF handling follows `read_until_view`.
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
/// Reads `length` bytes into owned PDF bytes and advances past them.
///
/// Raises the same errors as `read_view`.
pub fn ByteCursor::read_bytes(
  self : ByteCursor,
  length : Int,
) -> PdfBytes raise PdfError {
  self.read_view(length).to_owned()
}

///|
/// Reads all remaining bytes into owned PDF bytes and advances to EOF.
pub fn ByteCursor::read_remaining_bytes(self : ByteCursor) -> PdfBytes {
  let view = self.remaining_view()
  self.position = self.data.length()
  view.to_owned()
}

///|
/// Seeks to `position`, reads `length` bytes into owned PDF bytes, and advances
/// past them.
pub fn ByteCursor::read_bytes_at(
  self : ByteCursor,
  position : Int,
  length : Int,
) -> PdfBytes raise PdfError {
  self.read_view_at(position, length).to_owned()
}

///|
/// Reads one line as a view, including the line-ending bytes when present.
///
/// Both LF and CRLF are recognized. Raises `PdfError::EndOfInput` if called at
/// EOF.
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
    } else if value == 0x0D {
      if self.position < self.data.length() &&
        self.data[self.position].to_int() == 0x0A {
        ignore(self.input_byte())
      }
      done = true
    }
  }
  self.data[start:self.position]
}

///|
/// Reads one line into owned PDF bytes.
///
/// Raises `PdfError::EndOfInput` if called at EOF.
pub fn ByteCursor::read_line(self : ByteCursor) -> PdfBytes raise PdfError {
  self.read_line_view().to_owned()
}

///|
/// Reads all remaining lines as borrowed views.
///
/// Each line view includes the line-ending bytes when they were present in the
/// input.
pub fn ByteCursor::read_line_views(self : ByteCursor) -> Array[BytesView] {
  let lines : Array[BytesView] = []
  while self.position < self.data.length() {
    lines.push(try! self.read_line_view())
  }
  lines
}

///|
/// Reads all remaining lines as owned PDF bytes.
pub fn ByteCursor::read_lines(self : ByteCursor) -> Array[PdfBytes] {
  self.read_line_views().map(view => view.to_owned())
}

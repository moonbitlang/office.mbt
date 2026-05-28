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

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

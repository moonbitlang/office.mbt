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
fn ByteCursor::remaining_line_count(self : ByteCursor) -> Int {
  let mut index = self.position
  let mut count = 0
  while index < self.data.length() {
    count += 1
    let mut done = false
    while !done && index < self.data.length() {
      let value = self.data[index].to_int()
      index += 1
      if value == 0x0A {
        done = true
      } else if value == 0x0D {
        if index < self.data.length() && self.data[index].to_int() == 0x0A {
          index += 1
        }
        done = true
      }
    }
  }
  count
}

///|
/// Reads all remaining lines as borrowed views.
///
/// Each line view includes the line-ending bytes when they were present in the
/// input.
pub fn ByteCursor::read_line_views(self : ByteCursor) -> Array[BytesView] {
  let lines : Array[BytesView] = Array::new(
    capacity=self.remaining_line_count(),
  )
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

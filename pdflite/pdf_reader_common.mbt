///|
priv struct PdfXRefSection {
  entries : Array[PdfClassicXRefEntry]
  trailer : PdfObject
  stream_object_number : Int?
  stream_object_offset : Int?
}

///|
fn ByteCursor::seek_pdf_absolute(
  self : ByteCursor,
  position : Int,
) -> Unit raise PdfError {
  if position < 0 || position > self.data.length() {
    raise PdfError::InvalidCursorPosition(position)
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
fn pdf_view_equals_ascii(view : BytesView, values : ArrayView[Int]) -> Bool {
  view.length() == values.length() && pdf_view_matches_ascii_at(view, 0, values)
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
fn pdf_startxref_search_view(data : BytesView) -> BytesView {
  let eof = pdf_find_last_ascii(data, [37, 37, 69, 79, 70])
  if eof < 0 {
    data
  } else {
    data[:eof]
  }
}

///|
fn pdf_find_ascii_from(
  view : BytesView,
  start : Int,
  values : ArrayView[Int],
) -> Int {
  for position = start
      position <= view.length() - values.length()
      position = position + 1 {
    if pdf_view_matches_ascii_at(view, position, values) {
      break position
    }
  } nobreak {
    -1
  }
}

///|
fn pdf_parse_ascii_int_view(view : BytesView) -> Int raise PdfError {
  if view.length() == 0 {
    raise PdfError::NumberExpected
  }
  let limit = 2147483647L
  let mut value = 0L
  for byte in view {
    let digit = byte.to_int()
    if !pdf_is_digit_byte(digit) {
      raise PdfError::NumberExpected
    }
    value = value * 10L + (digit - 48).to_int64()
    if value > limit {
      raise PdfError::NumberExpected
    }
  }
  value.to_int()
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

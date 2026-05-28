///|
fn pdf_bookmark_import_is_whitespace(value : Int) -> Bool {
  pdf_is_whitespace_byte(value)
}

///|
fn pdf_bookmark_import_trim_line_end(line : BytesView) -> BytesView {
  let mut end = line.length()
  while end > 0 {
    let value = line[end - 1].to_int()
    if value == 10 || value == 13 {
      end -= 1
    } else {
      break
    }
  }
  line[:end]
}

///|
fn pdf_bookmark_import_skip_whitespace(
  line : BytesView,
  index : Ref[Int],
) -> Unit {
  while index.val < line.length() &&
        pdf_bookmark_import_is_whitespace(line[index.val].to_int()) {
    index.val += 1
  }
}

///|
fn pdf_bookmark_import_parse_int(line : BytesView, index : Ref[Int]) -> Int? {
  pdf_bookmark_import_skip_whitespace(line, index)
  let start = index.val
  let mut negative = false
  if index.val < line.length() {
    match line[index.val].to_int() {
      43 => index.val += 1
      45 => {
        negative = true
        index.val += 1
      }
      _ => ()
    }
  }
  let digits_start = index.val
  let mut value : Int64 = 0L
  let limit : Int64 = if negative { 2147483648L } else { 2147483647L }
  while index.val < line.length() {
    let digit = line[index.val].to_int()
    if digit < 48 || digit > 57 {
      break
    }
    value = value * 10L + (digit - 48).to_int64()
    if value > limit {
      index.val = start
      return None
    }
    index.val += 1
  }
  if index.val == digits_start {
    index.val = start
    None
  } else if negative {
    Some((0L - value).to_int())
  } else {
    Some(value.to_int())
  }
}

///|
fn pdf_bookmark_import_quoted_scan(
  line : BytesView,
  start : Int,
) -> (Int, Int, Bool) {
  let mut length = 0
  let mut index = start
  let mut closed = false
  while index < line.length() && !closed {
    let value = line[index].to_int()
    if value == 92 && index + 1 < line.length() {
      length += 2
      index += 2
    } else if value == 34 {
      index += 1
      closed = true
    } else {
      length += 1
      index += 1
    }
  }
  (length, index, closed)
}

///|
fn pdf_bookmark_import_copy_quoted(
  output : Array[Byte],
  line : BytesView,
  start : Int,
) -> Unit {
  let mut output_index = 0
  let mut index = start
  while output_index < output.length() {
    let value = line[index].to_int()
    if value == 92 && index + 1 < line.length() {
      output[output_index] = line[index]
      output[output_index + 1] = line[index + 1]
      output_index += 2
      index += 2
    } else {
      output[output_index] = line[index]
      output_index += 1
      index += 1
    }
  }
}

///|
fn pdf_bookmark_import_parse_quoted(
  line : BytesView,
  index : Ref[Int],
) -> PdfBytes? raise PdfError {
  pdf_bookmark_import_skip_whitespace(line, index)
  if index.val >= line.length() || line[index.val].to_int() != 34 {
    None
  } else {
    let start = index.val + 1
    let (length, next, closed) = pdf_bookmark_import_quoted_scan(line, start)
    if closed {
      let output = Array::make(length, b'\x00')
      pdf_bookmark_import_copy_quoted(output, line, start)
      index.val = next
      Some(Bytes::from_array(output))
    } else {
      raise SoftError("Bad bookmark file (unterminated string)")
    }
  }
}

///|
fn pdf_bookmark_import_take_open(line : BytesView, index : Ref[Int]) -> Bool {
  pdf_bookmark_import_skip_whitespace(line, index)
  let start = index.val
  if start + 4 <= line.length() &&
    line[start].to_int() == 111 &&
    line[start + 1].to_int() == 112 &&
    line[start + 2].to_int() == 101 &&
    line[start + 3].to_int() == 110 &&
    (
      start + 4 == line.length() ||
      pdf_bookmark_import_is_whitespace(line[start + 4].to_int())
    ) {
    index.val = start + 4
    true
  } else {
    false
  }
}

///|
fn pdf_bookmark_import_optional_destination(
  line : BytesView,
  index : Ref[Int],
) -> PdfBytes? raise PdfError {
  pdf_bookmark_import_skip_whitespace(line, index)
  if index.val >= line.length() || line[index.val].to_int() != 34 {
    None
  } else {
    let destination = pdf_bookmark_import_parse_quoted(line, index)
    pdf_bookmark_import_skip_whitespace(line, index)
    if index.val == line.length() {
      destination
    } else {
      None
    }
  }
}

///|
fn pdf_bookmark_import_fixup_escape(value : Int) -> Byte? {
  match value {
    92 => Some((92).to_byte())
    34 => Some((34).to_byte())
    110 => Some((10).to_byte())
    _ => None
  }
}

///|
fn pdf_bookmark_import_fixup_text_length(text : BytesView) -> Int {
  let mut length = 0
  let mut index = 0
  while index < text.length() {
    if text[index].to_int() == 92 && index + 1 < text.length() {
      match pdf_bookmark_import_fixup_escape(text[index + 1].to_int()) {
        Some(_) => index += 2
        None => index += 1
      }
    } else {
      index += 1
    }
    length += 1
  }
  length
}

///|
fn pdf_bookmark_import_fixup_text(text : BytesView) -> PdfBytes {
  let output = Array::make(pdf_bookmark_import_fixup_text_length(text), b'\x00')
  let mut position = 0
  let mut index = 0
  while index < text.length() {
    if text[index].to_int() == 92 && index + 1 < text.length() {
      match pdf_bookmark_import_fixup_escape(text[index + 1].to_int()) {
        Some(byte) => {
          output[position] = byte
          index += 2
        }
        None => {
          output[position] = text[index]
          index += 1
        }
      }
    } else {
      output[position] = text[index]
      index += 1
    }
    position += 1
  }
  Bytes::from_array(output)
}

///|
fn PdfDocument::pdf_bookmark_import_target_object(
  self : PdfDocument,
  page_number : Int,
  object : PdfObject,
) -> PdfDestination raise PdfError {
  match object {
    PdfArray([PdfInteger(_), .. rest]) =>
      match self.page_object_number(page_number) {
        Some(page_object_number) =>
          self.read_destination(
            PdfArray([PdfIndirect(page_object_number), ..rest]),
          )
        None => raise SoftError("bookmark_of_data: page obj num not found")
      }
    PdfNull => DestNull
    PdfString(name) => DestString(name)
    _ => DestAction(object)
  }
}

///|
fn PdfDocument::pdf_bookmark_import_target(
  self : PdfDocument,
  page_number : Int,
  destination : PdfBytes?,
) -> PdfDestination raise PdfError {
  match destination {
    Some(data) =>
      self.pdf_bookmark_import_target_object(
        page_number,
        pdf_parse_object_from_view(data),
      )
    None => self.target_of_page_number(page_number)
  }
}

///|
fn PdfDocument::pdf_bookmark_import_bookmark(
  self : PdfDocument,
  level : Int,
  title : BytesView,
  page_number : Int,
  is_open : Bool,
  destination : PdfBytes?,
) -> PdfBookmark raise PdfError {
  {
    level,
    text: pdf_pdfdocstring_of_utf8(pdf_bookmark_import_fixup_text(title)),
    target: self.pdf_bookmark_import_target(page_number, destination),
    is_open,
    colour: pdf_bookmark_black,
    flags: 0,
  }
}

///|
fn PdfDocument::pdf_bookmark_import_parse_line(
  self : PdfDocument,
  line : BytesView,
  line_number : Int,
) -> PdfBookmark? raise PdfError {
  let line = pdf_bookmark_import_trim_line_end(line)
  let index : Ref[Int] = { val: 0 }
  pdf_bookmark_import_skip_whitespace(line, index)
  if index.val == line.length() {
    None
  } else {
    let level = match pdf_bookmark_import_parse_int(line, index) {
      Some(value) => value
      None =>
        raise SoftError("Bad bookmark file, line " + line_number.to_string())
    }
    let title = match pdf_bookmark_import_parse_quoted(line, index) {
      Some(value) => value
      None =>
        raise SoftError("Bad bookmark file, line " + line_number.to_string())
    }
    let page_number = match pdf_bookmark_import_parse_int(line, index) {
      Some(value) => value
      None =>
        raise SoftError("Bad bookmark file, line " + line_number.to_string())
    }
    let is_open = pdf_bookmark_import_take_open(line, index)
    let destination = pdf_bookmark_import_optional_destination(line, index)
    Some(
      self.pdf_bookmark_import_bookmark(
        level, title, page_number, is_open, destination,
      ),
    )
  }
}

///|
fn PdfDocument::pdf_bookmark_import_verify(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
) -> Bool raise PdfError {
  if bookmarks.length() == 0 {
    true
  } else if bookmarks[0].level != 0 {
    false
  } else {
    let page_reference_numbers = self.page_reference_numbers()
    let page_number_lookup = pdf_page_number_lookup(page_reference_numbers)
    let end_page = self.endpage()
    let mut last_level = 0
    for index in 1..<bookmarks.length() {
      let bookmark = bookmarks[index]
      let page_number = self.pdf_destination_page_number_with_lookup(
        bookmark.target,
        page_number_lookup,
      )
      if bookmark.level >= last_level + 2 ||
        bookmark.level < 0 ||
        page_number > end_page ||
        page_number < 0 {
        break false
      }
      last_level = bookmark.level
    } nobreak {
      true
    }
  }
}

///|
/// Parse cpdf's plain text bookmark-file format.
///
/// The input is byte-oriented. Bookmark titles are double-quoted UTF-8 text
/// with cpdf's `\\`, `\"`, and `\n` escapes; optional destinations are
/// double-quoted PDF object snippets such as `[1 /Fit]`.
pub fn PdfDocument::parse_bookmark_text(
  self : PdfDocument,
  data : BytesView,
  verify? : Bool = true,
) -> Array[PdfBookmark] raise PdfError {
  let bookmarks : Array[PdfBookmark] = []
  let cursor = byte_cursor_of_view(data)
  for line_number, line in cursor.read_line_views() {
    match self.pdf_bookmark_import_parse_line(line, line_number + 1) {
      Some(bookmark) => bookmarks.push(bookmark)
      None => ()
    }
  }
  if verify && !self.pdf_bookmark_import_verify(bookmarks) {
    raise SoftError(
      "Bad bookmark file (References non-existant pages or is malformed)",
    )
  }
  bookmarks
}

///|
/// Return a copy of the document with bookmarks imported from cpdf text bytes.
pub fn PdfDocument::add_bookmarks_from_text(
  self : PdfDocument,
  data : BytesView,
  verify? : Bool = true,
) -> PdfDocument raise PdfError {
  self.add_bookmarks(self.parse_bookmark_text(data, verify~))
}

///|
/// Compatibility wrapper for `PdfDocument::parse_bookmark_text`.
pub fn pdf_parse_bookmark_text(
  verify : Bool,
  data : BytesView,
  document : PdfDocument,
) -> Array[PdfBookmark] raise PdfError {
  document.parse_bookmark_text(data, verify~)
}

///|
/// Compatibility wrapper matching cpdfbookmarks' plain `parse_bookmark_file`.
pub fn pdf_parse_bookmark_file(
  verify : Bool,
  document : PdfDocument,
  data : BytesView,
) -> Array[PdfBookmark] raise PdfError {
  document.parse_bookmark_text(data, verify~)
}

///|
/// Compatibility wrapper for `PdfDocument::add_bookmarks_from_text`.
pub fn pdf_add_bookmarks_from_text(
  verify : Bool,
  data : BytesView,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.add_bookmarks_from_text(data, verify~)
}

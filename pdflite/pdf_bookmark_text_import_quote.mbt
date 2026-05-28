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

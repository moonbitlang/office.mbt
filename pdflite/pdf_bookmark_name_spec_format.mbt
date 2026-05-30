///|
fn pdf_bookmark_name_spec_padded_number(
  width : Int,
  value : Int,
) -> String raise @core.PdfError {
  if width > 8 {
    raise SoftError("width of field too broad")
  }
  let text = value.to_string()
  if width <= 1 || text.length() >= width {
    text
  } else {
    "0".repeat(width - text.length()) + text
  }
}

///|
fn pdf_bookmark_name_spec_percent_number(width : Int, value : Int) -> String {
  let text = value.to_string()
  if text.length() > width {
    text[text.length() - width:].to_owned()
  } else {
    "0".repeat(width - text.length()) + text
  }
}

///|
fn pdf_bookmark_name_spec_expand_percent(
  spec : String,
  sequence : Int,
) -> String {
  let bytes = @utf8.encode(spec)
  let mut first = -1
  for index in 0..<bytes.length() {
    if bytes[index].to_int() == 37 {
      first = index
      break
    }
  }
  if first < 0 {
    spec
  } else {
    let mut end = first
    while end < bytes.length() && bytes[end].to_int() == 37 {
      end = end + 1
    }
    let before = @utf8.decode(bytes[:first]) catch { _ => "" }
    let after = @utf8.decode(bytes[end:]) catch { _ => "" }
    before +
    pdf_bookmark_name_spec_percent_number(end - first, sequence) +
    after
  }
}

///|
fn pdf_bookmark_name_spec_utf8_prefix(
  text : String,
  byte_length : Int,
) -> String {
  let bytes = @utf8.encode(text)
  let mut end = if byte_length < bytes.length() {
    byte_length
  } else {
    bytes.length()
  }
  while end > 0 {
    try @utf8.decode(bytes[:end]) catch {
      _ => end = end - 1
    } noraise {
      value => return value
    }
  }
  ""
}

///|
fn pdf_bookmark_name_spec_decimal(
  bytes : BytesView,
  start : Int,
  end : Int,
) -> Int raise @core.PdfError {
  if start == end {
    raise SoftError("Bad @b spec")
  }
  let mut value = 0
  for index in start..<end {
    let digit = bytes[index].to_int()
    if digit < 48 || digit > 57 {
      raise SoftError("Bad @b spec")
    }
    value = value * 10 + digit - 48
  }
  value
}

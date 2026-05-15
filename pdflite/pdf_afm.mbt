///|
/// Parsed Adobe Font Metrics data used by standard-font helpers.
///
/// Headers preserve raw key/value bytes. Character metrics store character
/// codes and widths, kerns store pair adjustments, and `char_name_widths`
/// preserves name-based widths for encodings that refer to glyph names.
pub(all) struct PdfAfmData {
  headers : Array[(PdfBytes, PdfBytes)]
  char_metrics : Array[(Int, Int)]
  kerns : Array[(Int, Int, Int)]
  char_name_widths : Array[(PdfBytes, Int)]
} derive(Debug, Eq, ToJson)

///|
fn pdf_afm_view_equals(left : BytesView, right : BytesView) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    for index in 0..<left.length() {
      if left[index] != right[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_afm_view_equals_ascii(view : BytesView, text : String) -> Bool {
  let bytes = @ascii.encode(text)
  pdf_afm_view_equals(view, bytes)
}

///|
fn pdf_afm_line_starts_with_ascii(line : BytesView, text : String) -> Bool {
  let prefix = @ascii.encode(text)
  if line.length() < prefix.length() {
    false
  } else {
    pdf_afm_view_equals(line[:prefix.length()], prefix)
  }
}

///|
fn pdf_afm_trim_line_end(line : BytesView) -> BytesView {
  let mut end = line.length()
  while end > 0 &&
        (line[end - 1].to_int() == 0x0A || line[end - 1].to_int() == 0x0D) {
    end -= 1
  }
  line[:end]
}

///|
fn pdf_afm_parse_int(token : BytesView) -> Int raise PdfError {
  if token.length() == 0 {
    raise PdfError::NumberExpected
  }
  let mut sign = 1
  let mut index = 0
  if token[0].to_int() == 0x2D {
    sign = -1
    index = 1
  } else if token[0].to_int() == 0x2B {
    index = 1
  }
  if index >= token.length() {
    raise PdfError::NumberExpected
  }
  let mut value = 0
  while index < token.length() {
    let byte = token[index].to_int()
    if !pdf_is_digit_byte(byte) {
      raise PdfError::NumberExpected
    }
    value = value * 10 + byte - 0x30
    index += 1
  }
  sign * value
}

///|
fn pdf_afm_header_entry(line : BytesView) -> (PdfBytes, PdfBytes)? {
  let trimmed = pdf_afm_trim_line_end(line)
  let mut index = 0
  while index < trimmed.length() &&
        !pdf_is_whitespace_byte(trimmed[index].to_int()) {
    index += 1
  }
  if index == 0 {
    None
  } else {
    let key = trimmed[:index].to_owned()
    while index < trimmed.length() &&
          pdf_is_whitespace_byte(trimmed[index].to_int()) {
      index += 1
    }
    Some((key, trimmed[index:].to_owned()))
  }
}

///|
fn pdf_afm_section_lines(
  lines : ArrayView[BytesView],
  start_marker : String,
  end_marker : String,
) -> Array[BytesView] {
  let output : Array[BytesView] = []
  let mut collecting = false
  let mut done = false
  for line in lines {
    if !done {
      if collecting {
        if pdf_afm_line_starts_with_ascii(line, end_marker) {
          done = true
        } else {
          output.push(line)
        }
      } else if pdf_afm_line_starts_with_ascii(line, start_marker) {
        collecting = true
      }
    }
  }
  output
}

///|
fn pdf_afm_char_metric(line : BytesView) -> (PdfBytes, Int, Int) raise PdfError {
  let tokens = pdf_split_whitespace_tokens(line)
  if tokens.length() >= 7 &&
    pdf_afm_view_equals_ascii(tokens[0], "C") &&
    pdf_afm_view_equals_ascii(tokens[2], ";") &&
    pdf_afm_view_equals_ascii(tokens[3], "WX") &&
    pdf_afm_view_equals_ascii(tokens[5], ";") &&
    pdf_afm_view_equals_ascii(tokens[6], "N") {
    let char_number = pdf_afm_parse_int(tokens[1])
    let width = pdf_afm_parse_int(tokens[4])
    if tokens.length() < 8 {
      raise PdfError::AfmExpected
    }
    (tokens[7].to_owned(), char_number, width)
  } else {
    raise PdfError::AfmExpected
  }
}

///|
fn pdf_afm_lookup_char_number(
  metrics : ArrayView[(PdfBytes, Int, Int)],
  name : BytesView,
) -> Int raise PdfError {
  for metric in metrics {
    let (candidate, char_number, _) = metric
    if pdf_afm_view_equals(candidate, name) {
      break char_number
    }
  } nobreak {
    raise PdfError::AfmExpected
  }
}

///|
fn pdf_afm_kern(
  line : BytesView,
  metrics : ArrayView[(PdfBytes, Int, Int)],
) -> (Int, Int, Int)? raise PdfError {
  let tokens = pdf_split_whitespace_tokens(line)
  if tokens.length() >= 4 && pdf_afm_view_equals_ascii(tokens[0], "KPX") {
    let first = pdf_afm_lookup_char_number(metrics, tokens[1])
    let second = pdf_afm_lookup_char_number(metrics, tokens[2])
    let kern = pdf_afm_parse_int(tokens[3])
    if first > -1 && second > -1 {
      Some((first, second, kern))
    } else {
      None
    }
  } else {
    raise PdfError::AfmExpected
  }
}

///|
/// Parses Adobe Font Metrics data from bytes.
///
/// The parser extracts top-level headers, character widths, name-width pairs,
/// and kerning pairs. Raises `PdfError::AfmExpected` or
/// `PdfError::NumberExpected` for malformed metric sections.
pub fn pdf_read_afm(data : BytesView) -> PdfAfmData raise PdfError {
  let lines = byte_cursor_of_view(data).read_line_views()
  let headers : Array[(PdfBytes, PdfBytes)] = []
  for line in lines {
    if pdf_afm_line_starts_with_ascii(line, "C ") {
      break
    }
    match pdf_afm_header_entry(line) {
      Some(entry) => headers.push(entry)
      None => ()
    }
  }
  let raw_metrics : Array[(PdfBytes, Int, Int)] = []
  for line in pdf_afm_section_lines(lines, "StartCharMetrics", "EndCharMetrics") {
    if pdf_afm_trim_line_end(line).length() >= 5 {
      raw_metrics.push(pdf_afm_char_metric(line))
    }
  }
  let char_metrics : Array[(Int, Int)] = []
  let char_name_widths : Array[(PdfBytes, Int)] = []
  for metric in raw_metrics {
    let (name, char_number, width) = metric
    if char_number > -1 {
      char_metrics.push((char_number, width))
    }
    char_name_widths.push((name, width))
  }
  let kerns : Array[(Int, Int, Int)] = []
  for line in pdf_afm_section_lines(lines, "StartKernPairs", "EndKernPairs") {
    if pdf_afm_trim_line_end(line).length() >= 5 {
      match pdf_afm_kern(line, raw_metrics) {
        Some(kern) => kerns.push(kern)
        None => ()
      }
    }
  }
  { headers, char_metrics, kerns, char_name_widths }
}

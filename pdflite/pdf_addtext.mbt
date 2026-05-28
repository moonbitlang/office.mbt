///|
fn pdf_addtext_validate_page_numbers(
  page_numbers : ArrayView[Int],
  end_page : Int,
  context : String,
) -> Unit raise PdfError {
  for page_number in page_numbers {
    if page_number < 1 || page_number > end_page {
      raise BadPageSpecification(
        context + ": range contains pages not present in pdf",
      )
    }
  }
}

///|
fn pdf_addtext_afm_header_value(data : PdfAfmData, key : String) -> String? {
  let key_bytes = @ascii.encode(key)
  for entry in data.headers {
    if pdf_afm_view_equals(entry.0, key_bytes) {
      return Some(@ascii.decode_lossy(entry.1))
    }
  }
  None
}

///|
fn pdf_addtext_parse_double(text : String) -> Double? {
  let parsed : Result[Double, Error] = try? @strconv.from_str(text)
  match parsed {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn pdf_addtext_standard_cap_height(fontname : String) -> Double? {
  match pdf_standard_font_of_name("/" + fontname) {
    Some(font) => {
      let data = font.afm_data()
      match pdf_addtext_afm_header_value(data, "CapHeight") {
        Some(value) =>
          match pdf_addtext_parse_double(value) {
            Some(parsed) => Some(parsed)
            None => Some(0.0)
          }
        None => Some(0.0)
      }
    }
    None => None
  }
}

///|
/// Return the cap height used by cpdf add-text URL link rectangles.
///
/// Explicit simple-font descriptors win. Otherwise `fontname` is resolved as a
/// Standard 14 font name without a leading slash, matching cpdf's fallback.
pub fn pdf_addtext_cap_height(font : PdfFont?, fontname : String) -> Double? {
  match font {
    Some(PdfFontSimple({ fontdescriptor: Some(descriptor), .. })) =>
      Some(descriptor.capheight)
    _ => pdf_addtext_standard_cap_height(fontname)
  }
}

///|
fn pdf_addtext_find_byte(bytes : BytesView, start : Int, value : Int) -> Int? {
  let mut index = start
  while index < bytes.length() {
    if bytes[index].to_int() == value {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn pdf_addtext_require_byte(
  bytes : BytesView,
  start : Int,
  value : Int,
) -> Int raise PdfError {
  match pdf_addtext_find_byte(bytes, start, value) {
    Some(index) => index
    None => raise SoftError("bad URL syntax in text")
  }
}

///|
fn pdf_addtext_is_url_marker(bytes : BytesView, index : Int) -> Bool {
  index + 4 < bytes.length() &&
  bytes[index].to_int() == 37 &&
  bytes[index + 1].to_int() == 85 &&
  bytes[index + 2].to_int() == 82 &&
  bytes[index + 3].to_int() == 76 &&
  bytes[index + 4].to_int() == 91
}

///|
fn pdf_addtext_utf8_string(bytes : BytesView) -> String raise PdfError {
  @utf8.decode(bytes) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_addtext_url_visible_length(bytes : BytesView) -> Int raise PdfError {
  let mut index = 0
  let mut length = 0
  while index < bytes.length() {
    if pdf_addtext_is_url_marker(bytes, index) {
      let text_start = index + 5
      let pipe = pdf_addtext_require_byte(bytes, text_start, 124)
      let close = pdf_addtext_require_byte(bytes, pipe + 1, 93)
      length += pipe - text_start
      index = close + 1
    } else {
      length += 1
      index += 1
    }
  }
  length
}

///|
/// Strip cpdf add-text `%URL[text|url]` markup from one line.
///
/// The returned URL spans use byte offsets in the stripped visible text, as in
/// cpdf's `get_urls_line` helper.
pub fn pdf_addtext_get_urls_line(
  line : String,
) -> PdfAddTextUrlLine raise PdfError {
  let bytes = @utf8.encode(line)
  let output = Array::make(pdf_addtext_url_visible_length(bytes), b'\x00')
  let urls : Array[PdfAddTextUrl] = Array::new(capacity=bytes.length() / 5)
  let mut index = 0
  let mut position = 0
  while index < bytes.length() {
    if pdf_addtext_is_url_marker(bytes, index) {
      let text_start = index + 5
      let pipe = pdf_addtext_require_byte(bytes, text_start, 124)
      let close = pdf_addtext_require_byte(bytes, pipe + 1, 93)
      let start = position
      for byte in bytes[text_start:pipe] {
        output[position] = byte
        position += 1
      }
      let url = pdf_addtext_utf8_string(bytes[pipe + 1:close])
      let end = position
      urls.push({ url, start, end })
      index = close + 1
    } else {
      output[position] = bytes[index]
      position += 1
      index += 1
    }
  }
  { text: pdf_addtext_utf8_string(Bytes::from_array(output)), urls }
}

///|
/// Expand add-text lines and strip URL markup before line measurement.
///
/// This mirrors cpdf's `expand_lines` behavior after callers have supplied the
/// document-specific replacement callbacks.
pub fn pdf_addtext_expand_lines_with_time(
  time : PdfStrftimeTime,
  lines : ArrayView[String],
  replacements : ArrayView[(String, () -> String)],
) -> Array[String] raise PdfError {
  let output : Array[String] = Array::new(capacity=lines.length())
  for line in lines {
    let processed = pdf_addtext_process_text_with_time(time, line, replacements)
    output.push(pdf_addtext_get_urls_line(processed).text)
  }
  output
}

///|
fn pdf_addtext_codepoints_contains(
  codepoints : ArrayView[Int],
  codepoint : Int,
) -> Bool {
  for existing in codepoints {
    if existing == codepoint {
      return true
    }
  }
  false
}

///|
/// Return the unique Unicode codepoints used by expanded add-text lines.
///
/// This mirrors cpdf's pre-embedding `used` scan after replacement expansion
/// and URL stripping. The returned order is first occurrence for deterministic
/// callers and tests.
pub fn pdf_addtext_used_codepoints(
  lines : ArrayView[String],
) -> Array[Int] raise PdfError {
  let used : Array[Int] = Array::new(capacity=lines.length())
  for line in lines {
    for codepoint in pdf_codepoints_of_utf8(@utf8.encode(line)) {
      if !pdf_addtext_codepoints_contains(used, codepoint) {
        used.push(codepoint)
      }
    }
  }
  used
}

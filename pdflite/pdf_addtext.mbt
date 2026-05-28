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
fn pdf_addtext_roman_upper(number : Int) -> String {
  @ascii.decode_lossy(pdf_page_label_roman_upper(number))
}

///|
fn pdf_addtext_roman_lower(number : Int) -> String {
  @ascii.decode_lossy(
    pdf_page_label_lowercase(pdf_page_label_roman_upper(number)),
  )
}

///|
/// Format cpdf add-text's `%Bates` replacement for one page.
pub fn pdf_addtext_bates_number(
  bates : Int,
  page_number : Int,
  bates_pad : Int?,
) -> String {
  let number_text = (bates + page_number - 1).to_string()
  match bates_pad {
    None => number_text
    Some(width) =>
      if number_text.length() >= width {
        number_text
      } else {
        let mut output = number_text
        for _ in 0..<(width - number_text.length()) {
          output = "0" + output
        }
        output
      }
  }
}

///|
fn pdf_addtext_bookmark_replacement(
  values : PdfAddTextReplacementValues,
  level : Int,
) -> String {
  if level >= 0 && level < values.bookmarks.length() {
    values.bookmarks[level]
  } else {
    ""
  }
}

///|
/// Build cpdf add-text replacement callbacks for page-local fields.
///
/// Page labels and bookmark strings are supplied by the caller; this helper
/// preserves cpdf's marker names and Bates/roman/page-number formatting.
pub fn pdf_addtext_replacement_pairs(
  values : PdfAddTextReplacementValues,
) -> Array[(String, () -> String)] {
  [
    ("%PageDiv2", fn() { ((values.page_number + 1) / 2).to_string() }),
    ("%Page", fn() { values.page_number.to_string() }),
    ("%Roman", fn() { pdf_addtext_roman_upper(values.page_number) }),
    ("%roman", fn() { pdf_addtext_roman_lower(values.page_number) }),
    ("%filename", fn() { values.filename }),
    ("%Label", fn() { values.page_label }),
    ("%EndPage", fn() { values.end_page.to_string() }),
    ("%EndLabel", fn() { values.end_label }),
    ("%Bookmark0", fn() { pdf_addtext_bookmark_replacement(values, 0) }),
    ("%Bookmark1", fn() { pdf_addtext_bookmark_replacement(values, 1) }),
    ("%Bookmark2", fn() { pdf_addtext_bookmark_replacement(values, 2) }),
    ("%Bookmark3", fn() { pdf_addtext_bookmark_replacement(values, 3) }),
    ("%Bookmark4", fn() { pdf_addtext_bookmark_replacement(values, 4) }),
    (
      "%Bates",
      fn() {
        pdf_addtext_bates_number(
          values.bates,
          values.page_number,
          values.bates_pad,
        )
      },
    ),
  ]
}

///|
fn pdf_addtext_pdfdocstring_to_string(
  bytes : BytesView,
) -> String raise PdfError {
  @utf8.decode(pdf_utf8_of_pdfdocstring(bytes)) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_addtext_page_label_prefix(label : PdfPageLabel) -> String raise PdfError {
  match label.label_prefix {
    Some(prefix) => pdf_addtext_pdfdocstring_to_string(prefix)
    None => ""
  }
}

///|
fn pdf_addtext_page_label_number(label : PdfPageLabel) -> String {
  @ascii.decode_lossy(
    pdf_page_label_number_bytes(label.start_value, label.label_style),
  )
}

///|
/// Return cpdf add-text's visible page label for a 1-based page number.
///
/// Documents without page labels fall back to decimal page numbers.
pub fn PdfDocument::addtext_page_label(
  self : PdfDocument,
  page_number : Int,
) -> String raise PdfError {
  let labels = pdf_page_label_complete(self.read_page_labels())
  match pdf_page_label_of_page_number(page_number, labels) {
    Some(label) =>
      pdf_addtext_page_label_prefix(label) +
      pdf_addtext_page_label_number(label)
    None => page_number.to_string()
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_page_label`.
pub fn pdf_addtext_page_label(
  document : PdfDocument,
  page_number : Int,
) -> String raise PdfError {
  document.addtext_page_label(page_number)
}

///|
fn pdf_addtext_bookmark_text(bookmark : PdfBookmark) -> String raise PdfError {
  pdf_addtext_pdfdocstring_to_string(bookmark.text)
}

///|
/// Return cpdf add-text's current bookmark text at `level` for `page_number`.
///
/// The search is constrained to the current bookmark branch so section
/// bookmarks from a previous chapter do not leak into a later chapter.
pub fn PdfDocument::addtext_bookmark_for_page(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  level : Int,
  page_number : Int,
) -> String raise PdfError {
  let before : Array[PdfBookmark] = Array::new(capacity=bookmarks.length())
  for bookmark in bookmarks {
    if self.page_number_of_target(bookmark.target) <= page_number {
      before.push(bookmark)
    } else {
      break
    }
  }
  let branch : Array[PdfBookmark] = Array::new(capacity=before.length())
  let mut before_index = before.length()
  while before_index > 0 {
    before_index -= 1
    let bookmark = before[before_index]
    if bookmark.level >= level {
      branch.push(bookmark)
    } else {
      break
    }
  }
  let pickfrom : Array[PdfBookmark] = Array::new(capacity=branch.length())
  let mut branch_index = branch.length()
  while branch_index > 0 {
    branch_index -= 1
    let bookmark = branch[branch_index]
    if bookmark.level == level {
      pickfrom.push(bookmark)
    }
  }
  let mut fallback : PdfBookmark? = None
  for bookmark in pickfrom {
    if self.page_number_of_target(bookmark.target) == page_number {
      return pdf_addtext_bookmark_text(bookmark)
    }
    fallback = Some(bookmark)
  }
  match fallback {
    Some(bookmark) => pdf_addtext_bookmark_text(bookmark)
    None => ""
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_bookmark_for_page`.
pub fn pdf_addtext_bookmark_for_page(
  document : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  level : Int,
  page_number : Int,
) -> String raise PdfError {
  document.addtext_bookmark_for_page(bookmarks, level, page_number)
}

///|
/// Build cpdf add-text replacement values from document-local state.
pub fn PdfDocument::addtext_replacement_values(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  page_number : Int,
  end_page : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
) -> PdfAddTextReplacementValues raise PdfError {
  let bookmark_values : Array[String] = Array::new(capacity=5)
  for level in 0..<5 {
    bookmark_values.push(
      self.addtext_bookmark_for_page(bookmarks, level, page_number),
    )
  }
  {
    page_number,
    end_page,
    filename,
    page_label: self.addtext_page_label(page_number),
    end_label: self.addtext_page_label(end_page),
    bates,
    bates_pad,
    bookmarks: bookmark_values,
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_replacement_values`.
pub fn pdf_addtext_replacement_values(
  document : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  page_number : Int,
  end_page : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
) -> PdfAddTextReplacementValues raise PdfError {
  document.addtext_replacement_values(
    bookmarks, page_number, end_page, filename, bates, bates_pad,
  )
}

///|
/// Source-spelled compatibility wrapper matching cpdfaddtext's `replace_pairs`.
///
/// The OCaml API receives precomputed page-reference lookup state and the page
/// record; this wrapper derives the same page-local values from `document`.
pub fn pdf_replace_pairs(
  bookmarks : ArrayView[PdfBookmark],
  document : PdfDocument,
  end_page : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
  page_number : Int,
) -> Array[(String, () -> String)] raise PdfError {
  let values = document.addtext_replacement_values(
    bookmarks, page_number, end_page, filename, bates, bates_pad,
  )
  pdf_addtext_replacement_pairs(values)
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

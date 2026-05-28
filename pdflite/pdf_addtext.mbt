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
fn pdf_addtext_vertical_justification(
  rotation : PdfAddTextRotation,
  justification : PdfAddTextJustification,
) -> PdfAddTextJustification {
  match justification {
    PdfAddTextCentreJustify => PdfAddTextCentreJustify
    PdfAddTextLeftJustify =>
      if rotation == PdfAddTextRot270 {
        PdfAddTextRightJustify
      } else {
        PdfAddTextLeftJustify
      }
    PdfAddTextRightJustify =>
      if rotation == PdfAddTextRot270 {
        PdfAddTextLeftJustify
      } else {
        PdfAddTextRightJustify
      }
  }
}

///|
fn pdf_addtext_horizontal_justification(
  rotation : PdfAddTextRotation,
  justification : PdfAddTextJustification,
) -> PdfAddTextJustification {
  match justification {
    PdfAddTextCentreJustify => PdfAddTextCentreJustify
    PdfAddTextLeftJustify =>
      if rotation == PdfAddTextRot180 {
        PdfAddTextRightJustify
      } else {
        PdfAddTextLeftJustify
      }
    PdfAddTextRightJustify =>
      if rotation == PdfAddTextRot180 {
        PdfAddTextLeftJustify
      } else {
        PdfAddTextRightJustify
      }
  }
}

///|
fn pdf_addtext_vertical_justification_offset(
  delta : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  match justification {
    PdfAddTextLeftJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta / 2.0
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _) => delta
      }
    PdfAddTextRightJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_) => -delta
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => -(delta / 2.0)
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
      }
    PdfAddTextCentreJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_) => -(delta / 2.0)
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _) => delta / 2.0
      }
  }
}

///|
fn pdf_addtext_horizontal_justification_offset(
  delta : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  match justification {
    PdfAddTextLeftJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre => delta / 2.0
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta
      }
    PdfAddTextRightJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _) => -delta
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre => -(delta / 2.0)
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
      }
    PdfAddTextCentreJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _) => -(delta / 2.0)
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta / 2.0
      }
  }
}

///|
/// Return cpdf's add-text justification offset for the current line.
///
/// `longest_width` is the maximum rendered width among the expanded text lines,
/// and `width` is the current line width.
pub fn pdf_addtext_justification_offset(
  rotation : PdfAddTextRotation,
  longest_width : Double,
  width : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  let delta = longest_width - width
  match rotation {
    PdfAddTextRot90 | PdfAddTextRot270 =>
      pdf_addtext_vertical_justification_offset(
        delta,
        position,
        pdf_addtext_vertical_justification(rotation, justification),
      )
    PdfAddTextRot0 | PdfAddTextRot180 =>
      pdf_addtext_horizontal_justification_offset(
        delta,
        position,
        pdf_addtext_horizontal_justification(rotation, justification),
      )
  }
}

///|
/// Apply cpdf's scalar justification offset to `(horizontal, vertical)`.
pub fn pdf_addtext_apply_justification_offset(
  rotation : PdfAddTextRotation,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
) -> (Double, Double) {
  match rotation {
    PdfAddTextRot90 | PdfAddTextRot270 =>
      (horizontal_offset, vertical_offset - justification_offset)
    PdfAddTextRot0 | PdfAddTextRot180 =>
      (horizontal_offset + justification_offset, vertical_offset)
  }
}

///|
/// Resolve cpdf add-text placement values for one line.
///
/// This combines cpdf's `calculate_position`, diagonal offset correction,
/// justification offset application, explicit text rotation, and
/// rotation-origin offset selection.
pub fn pdf_addtext_line_placement(
  bounds : PdfRectangle,
  position : PdfPosition,
  rotation : PdfAddTextRotation,
  text_width : Double,
  longest_width : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification : PdfAddTextJustification,
) -> PdfAddTextLinePlacement {
  let placed = pdf_calculate_position(false, text_width, bounds, position)
  let justification_offset = pdf_addtext_justification_offset(
    rotation, longest_width, text_width, position, justification,
  )
  let (diagonal_h_offset, diagonal_v_offset) = pdf_addtext_diagonal_offsets(
    bounds,
    position,
    rotation,
    text_width,
    horizontal_offset,
    vertical_offset,
    placed.rotation,
  )
  let (final_h_offset, final_v_offset) = pdf_addtext_apply_justification_offset(
    rotation, diagonal_h_offset, diagonal_v_offset, justification_offset,
  )
  let (rotation_h_offset, rotation_v_offset) = pdf_addtext_rotation_offsets(
    position, rotation, text_width,
  )
  {
    origin: point2(placed.x, placed.y),
    base_rotation: placed.rotation,
    text_rotation: pdf_addtext_rotation_radians(rotation),
    rotation_offset: point2(rotation_h_offset, rotation_v_offset),
    horizontal_offset: final_h_offset,
    vertical_offset: final_v_offset,
    justification_offset,
  }
}

///|
fn pdf_addtext_bytes_match_at(
  bytes : BytesView,
  index : Int,
  pattern : BytesView,
) -> Bool {
  if pattern.length() == 0 || index + pattern.length() > bytes.length() {
    false
  } else {
    for offset in 0..<pattern.length() {
      if bytes[index + offset].to_int() != pattern[offset].to_int() {
        return false
      }
    }
    true
  }
}

///|
fn pdf_addtext_copy_view(
  output : Array[Byte],
  position : Int,
  view : BytesView,
) -> Int {
  let mut position = position
  for byte in view {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn pdf_addtext_replace_all_lazy(
  text : String,
  search : String,
  replacement : () -> String,
) -> String {
  let search_bytes = @utf8.encode(search)
  if search_bytes.length() == 0 {
    text
  } else {
    let text_bytes = @utf8.encode(text)
    let replacements : Array[(Int, Int, PdfBytes)] = Array::new(
      capacity=text_bytes.length() / search_bytes.length(),
    )
    let mut index = 0
    let mut length = text_bytes.length()
    while index < text_bytes.length() {
      if pdf_addtext_bytes_match_at(text_bytes, index, search_bytes) {
        let replacement_bytes = @utf8.encode(replacement())
        replacements.push(
          (index, index + search_bytes.length(), replacement_bytes),
        )
        length = length - search_bytes.length() + replacement_bytes.length()
        index += search_bytes.length()
      } else {
        index += 1
      }
    }
    guard replacements.length() > 0 else { return text }
    let output = Array::make(length, b'\x00')
    let mut source_index = 0
    let mut position = 0
    for entry in replacements {
      position = pdf_addtext_copy_view(
        output,
        position,
        text_bytes[source_index:entry.0],
      )
      position = pdf_addtext_copy_view(output, position, entry.2)
      source_index = entry.1
    }
    let _ = pdf_addtext_copy_view(output, position, text_bytes[source_index:])
    @utf8.decode_lossy(Bytes::from_array(output))
  }
}

///|
/// Apply cpdf add-text replacements, then run the cpdf strftime pass.
///
/// Replacement callbacks are only evaluated for markers that occur in `text`,
/// matching cpdf's `string_replace_all_lazy` helper.
pub fn pdf_addtext_process_text_with_time(
  time : PdfStrftimeTime,
  text : String,
  replacements : ArrayView[(String, () -> String)],
) -> String {
  let mut output = text
  for replacement in replacements {
    output = pdf_addtext_replace_all_lazy(output, replacement.0, replacement.1)
  }
  pdf_strftime_with_time(time, output)
}

///|
/// Compatibility wrapper matching cpdfaddtext's `process_text`.
pub fn pdf_process_text(
  time : PdfStrftimeTime,
  text : String,
  replacements : ArrayView[(String, () -> String)],
) -> String {
  pdf_addtext_process_text_with_time(time, text, replacements)
}

///|
fn pdf_addtext_decode_lossy_view(bytes : BytesView) -> String {
  let output = Array::make(bytes.length(), b'\x00')
  for index, byte in bytes {
    output[index] = byte
  }
  @utf8.decode_lossy(Bytes::from_array(output))
}

///|
/// Split add-text input at cpdf's literal `\n` line marker.
///
/// A doubled backslash before `n` is preserved as text, matching cpdf's
/// `split_at_newline` helper.
pub fn pdf_addtext_split_at_newline(text : String) -> Array[String] {
  let bytes = @utf8.encode(text)
  let lines : Array[String] = Array::new(capacity=bytes.length())
  let mut line_start = 0
  let mut index = 0
  while index < bytes.length() {
    if index + 2 < bytes.length() &&
      bytes[index].to_int() == 92 &&
      bytes[index + 1].to_int() == 92 &&
      bytes[index + 2].to_int() == 110 {
      index += 3
    } else if index + 1 < bytes.length() &&
      bytes[index].to_int() == 92 &&
      bytes[index + 1].to_int() == 110 {
      lines.push(pdf_addtext_decode_lossy_view(bytes[line_start:index]))
      index += 2
      line_start = index
    } else {
      index += 1
    }
  }
  lines.push(pdf_addtext_decode_lossy_view(bytes[line_start:]))
  lines
}

///|
fn pdf_addtext_is_octal_digit(byte : Byte) -> Bool {
  let value = byte.to_int()
  value >= 48 && value <= 55
}

///|
fn pdf_addtext_octal_value(a : Byte, b : Byte, c : Byte) -> Int {
  (a.to_int() - 48) * 64 + (b.to_int() - 48) * 8 + c.to_int() - 48
}

///|
fn pdf_addtext_unescaped_length(bytes : BytesView) -> Int raise PdfError {
  let mut index = 0
  let mut length = 0
  while index < bytes.length() {
    if bytes[index].to_int() == 92 {
      if index + 3 < bytes.length() &&
        pdf_addtext_is_octal_digit(bytes[index + 1]) &&
        pdf_addtext_is_octal_digit(bytes[index + 2]) &&
        pdf_addtext_is_octal_digit(bytes[index + 3]) {
        let value = pdf_addtext_octal_value(
          bytes[index + 1],
          bytes[index + 2],
          bytes[index + 3],
        )
        if value > 255 {
          raise SoftError("bad add-text octal escape")
        }
        length += 1
        index += 4
      } else if index + 1 < bytes.length() && bytes[index + 1].to_int() == 92 {
        length += 1
        index += 2
      } else if index + 1 < bytes.length() && bytes[index + 1].to_int() != 110 {
        length += 1
        index += 2
      } else {
        length += 1
        index += 1
      }
    } else {
      length += 1
      index += 1
    }
  }
  length
}

///|
/// Decode cpdf add-text backslash escapes after line splitting.
///
/// Three-digit octal escapes emit one byte, doubled backslashes emit one
/// backslash, and other non-newline escapes drop the backslash.
pub fn pdf_addtext_unescape_string(text : String) -> String raise PdfError {
  let bytes = @utf8.encode(text)
  let output = Array::make(pdf_addtext_unescaped_length(bytes), b'\x00')
  let mut index = 0
  let mut position = 0
  while index < bytes.length() {
    if bytes[index].to_int() == 92 {
      if index + 3 < bytes.length() &&
        pdf_addtext_is_octal_digit(bytes[index + 1]) &&
        pdf_addtext_is_octal_digit(bytes[index + 2]) &&
        pdf_addtext_is_octal_digit(bytes[index + 3]) {
        let value = pdf_addtext_octal_value(
          bytes[index + 1],
          bytes[index + 2],
          bytes[index + 3],
        )
        if value > 255 {
          raise SoftError("bad add-text octal escape")
        }
        output[position] = value.to_byte()
        position += 1
        index += 4
      } else if index + 1 < bytes.length() && bytes[index + 1].to_int() == 92 {
        output[position] = (92).to_byte()
        position += 1
        index += 2
      } else if index + 1 < bytes.length() && bytes[index + 1].to_int() != 110 {
        output[position] = bytes[index + 1]
        position += 1
        index += 2
      } else {
        output[position] = bytes[index]
        position += 1
        index += 1
      }
    } else {
      output[position] = bytes[index]
      position += 1
      index += 1
    }
  }
  @utf8.decode_lossy(Bytes::from_array(output))
}

///|
/// Split and unescape add-text lines, reversing them for upside-down rotations.
pub fn pdf_addtext_lines_for_rotation(
  text : String,
  rotation : PdfAddTextRotation,
) -> Array[String] raise PdfError {
  let lines = pdf_addtext_split_at_newline(text).map(line => {
    pdf_addtext_unescape_string(line)
  })
  match rotation {
    PdfAddTextRot180 | PdfAddTextRot270 => lines.rev()
    PdfAddTextRot0 | PdfAddTextRot90 => lines
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

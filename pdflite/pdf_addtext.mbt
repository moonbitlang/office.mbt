///|
/// Text rotation values used by cpdf's add-text positioning helpers.
pub(all) enum PdfAddTextRotation {
  PdfAddTextRot0
  PdfAddTextRot90
  PdfAddTextRot180
  PdfAddTextRot270
} derive(Debug, Eq, ToJson)

///|
/// Text justification values used by cpdf's add-text positioning helpers.
pub(all) enum PdfAddTextJustification {
  PdfAddTextLeftJustify
  PdfAddTextCentreJustify
  PdfAddTextRightJustify
} derive(Debug, Eq, ToJson)

///|
/// A URL span parsed from cpdf add-text `%URL[text|url]` markup.
///
/// `start` and `end` are byte offsets in the visible output line, matching
/// OCaml cpdf's `String.length` accounting.
pub(all) struct PdfAddTextUrl {
  url : String
  start : Int
  end : Int
} derive(Debug, Eq, ToJson)

///|
/// One add-text line after stripping `%URL[text|url]` markup.
pub(all) struct PdfAddTextUrlLine {
  text : String
  urls : Array[PdfAddTextUrl]
} derive(Debug, Eq, ToJson)

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
    let output : Array[Byte] = []
    let mut index = 0
    while index < text_bytes.length() {
      if pdf_addtext_bytes_match_at(text_bytes, index, search_bytes) {
        for byte in @utf8.encode(replacement()) {
          output.push(byte)
        }
        index += search_bytes.length()
      } else {
        output.push(text_bytes[index])
        index += 1
      }
    }
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
/// Strip cpdf add-text `%URL[text|url]` markup from one line.
///
/// The returned URL spans use byte offsets in the stripped visible text, as in
/// cpdf's `get_urls_line` helper.
pub fn pdf_addtext_get_urls_line(
  line : String,
) -> PdfAddTextUrlLine raise PdfError {
  let bytes = @utf8.encode(line)
  let output : Array[Byte] = []
  let urls : Array[PdfAddTextUrl] = []
  let mut index = 0
  let mut position = 0
  while index < bytes.length() {
    if pdf_addtext_is_url_marker(bytes, index) {
      let text_start = index + 5
      let pipe = pdf_addtext_require_byte(bytes, text_start, 124)
      let close = pdf_addtext_require_byte(bytes, pipe + 1, 93)
      for byte in bytes[text_start:pipe] {
        output.push(byte)
      }
      let url = pdf_addtext_utf8_string(bytes[pipe + 1:close])
      let start = position
      let end = position + pipe - text_start
      urls.push({ url, start, end })
      position = end
      index = close + 1
    } else {
      output.push(bytes[index])
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
  let output : Array[String] = []
  for line in lines {
    let processed = pdf_addtext_process_text_with_time(time, line, replacements)
    output.push(pdf_addtext_get_urls_line(processed).text)
  }
  output
}

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

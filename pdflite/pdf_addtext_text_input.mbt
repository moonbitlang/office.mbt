///|
fn pdf_addtext_replace_all_lazy(
  text : String,
  search : String,
  replacement : () -> String,
) -> String {
  let search_bytes = @utf8.encode(search)
  guard search_bytes.length() > 0 else { return text }
  let text_bytes = @utf8.encode(text)
  let output : Array[Byte] = Array::new(capacity=text_bytes.length())
  let mut replaced = false
  for index = 0; index < text_bytes.length(); {
    if text_bytes[index:].has_prefix(search_bytes) {
      for byte in @utf8.encode(replacement()) {
        output.push(byte)
      }
      replaced = true
      continue index + search_bytes.length()
    }
    output.push(text_bytes[index])
    continue index + 1
  }
  if replaced {
    @utf8.decode_lossy(Bytes::from_array(output))
  } else {
    text
  }
}

///|
/// Apply cpdf add-text replacements, then run the cpdf strftime pass.
///
/// Replacement callbacks are only evaluated for markers that occur in `text`,
/// matching cpdf's `string_replace_all_lazy` helper.
pub fn pdf_addtext_process_text_with_time(
  time : @date.PdfStrftimeTime,
  text : String,
  replacements : ArrayView[(String, () -> String)],
) -> String {
  let mut output = text
  for replacement in replacements {
    output = pdf_addtext_replace_all_lazy(output, replacement.0, replacement.1)
  }
  @date.pdf_strftime_with_time(time, output)
}

///|
/// Compatibility wrapper matching cpdfaddtext's `process_text`.
pub fn pdf_process_text(
  time : @date.PdfStrftimeTime,
  text : String,
  replacements : ArrayView[(String, () -> String)],
) -> String {
  pdf_addtext_process_text_with_time(time, text, replacements)
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
  for index = 0; index < bytes.length(); {
    match bytes[index:] {
      [b'\\', b'\\', b'n', ..] => continue index + 3
      [b'\\', b'n', ..] => {
        lines.push(@utf8.decode_lossy(bytes[line_start:index].to_owned()))
        line_start = index + 2
        continue index + 2
      }
      _ => continue index + 1
    }
  }
  lines.push(@utf8.decode_lossy(bytes[line_start:].to_owned()))
  lines
}

///|
fn pdf_addtext_octal_value(a : Byte, b : Byte, c : Byte) -> Int {
  (a.to_int() - '0') * 64 + (b.to_int() - '0') * 8 + c.to_int() - '0'
}

///|
/// Decode cpdf add-text backslash escapes after line splitting.
///
/// Three-digit octal escapes emit one byte, doubled backslashes emit one
/// backslash, and other non-newline escapes drop the backslash.
pub fn pdf_addtext_unescape_string(
  text : String,
) -> String raise @core.PdfError {
  let bytes = @utf8.encode(text)
  let output : Array[Byte] = Array::new(capacity=bytes.length())
  for index = 0; index < bytes.length(); {
    match bytes[index:] {
      [b'\\', b'0'..=b'7' as a, b'0'..=b'7' as b, b'0'..=b'7' as c, ..] => {
        let value = pdf_addtext_octal_value(a, b, c)
        if value > 255 {
          raise SoftError("bad add-text octal escape")
        }
        output.push(value.to_byte())
        continue index + 4
      }
      [b'\\', b'\\', ..] => {
        output.push(b'\\')
        continue index + 2
      }
      [b'\\', next, ..] if next != b'n' => {
        output.push(next)
        continue index + 2
      }
      [byte, ..] => {
        output.push(byte)
        continue index + 1
      }
      [] => break
    }
  }
  @utf8.decode_lossy(Bytes::from_array(output))
}

///|
/// Split and unescape add-text lines, reversing them for upside-down rotations.
pub fn pdf_addtext_lines_for_rotation(
  text : String,
  rotation : @addtext.PdfAddTextRotation,
) -> Array[String] raise @core.PdfError {
  let lines = pdf_addtext_split_at_newline(text).map(line => {
    pdf_addtext_unescape_string(line)
  })
  match rotation {
    PdfAddTextRot180 | PdfAddTextRot270 => lines.rev()
    PdfAddTextRot0 | PdfAddTextRot90 => lines
  }
}

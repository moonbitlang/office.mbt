///|
/// Expand add-text lines and strip URL markup before line measurement.
///
/// This mirrors cpdf's `expand_lines` behavior after callers have supplied the
/// document-specific replacement callbacks.
pub fn pdf_addtext_expand_lines_with_time(
  time : @date.PdfStrftimeTime,
  lines : ArrayView[String],
  replacements : ArrayView[(String, () -> String)],
) -> Array[String] raise @core.PdfError {
  let output : Array[String] = Array::new(capacity=lines.length())
  for line in lines {
    let processed = pdf_addtext_process_text_with_time(time, line, replacements)
    output.push(@addtext.pdf_addtext_get_urls_line(processed).text)
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
) -> Array[Int] raise @core.PdfError {
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

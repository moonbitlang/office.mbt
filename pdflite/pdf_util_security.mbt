///|
fn pdf_injectible_char(char : Char) -> Bool {
  char == '&' || char == '|' || char == '\n' || char == '`' || char == '$'
}

///|
/// Check that a path-like string is safe to pass through shell-style contexts.
///
/// This ports cpdf's injectible-character guard, but reports a checked
/// `@core.PdfError::InsecurePathName` instead of terminating the process.
pub fn pdf_check_injectible(text : String) -> Unit raise @core.PdfError {
  for char in text.iter() {
    if pdf_injectible_char(char) {
      raise InsecurePathName(text)
    }
  }
}

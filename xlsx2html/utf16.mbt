///|
/// Replaces unpaired UTF-16 surrogates with U+FFFD, returning the rewritten
/// text and the number of replaced units. Rendered documents can carry
/// isolated surrogates when a source file's stored strings decode to them;
/// UTF-8 encoding of such text traps, so publication paths sanitize first
/// and report the replacement count instead of crashing.
pub fn sanitize_utf16_lossy(text : String) -> (String, Int) {
  let mut replaced = 0
  let out = StringBuilder::new()
  let mut start = 0
  let mut index = 0
  while index < text.length() {
    let unit = text[index]
    if unit.is_leading_surrogate() {
      if index + 1 < text.length() && text[index + 1].is_trailing_surrogate() {
        index += 2
        continue
      }
    } else if !unit.is_trailing_surrogate() {
      index += 1
      continue
    }
    out.write_string(text.substring(start~, end=index))
    out.write_char('\u{FFFD}')
    replaced += 1
    index += 1
    start = index
  }
  if replaced == 0 {
    (text, 0)
  } else {
    out.write_string(text.substring(start~, end=text.length()))
    (out.to_string(), replaced)
  }
}

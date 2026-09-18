// HTML escaping, duplicated from docx2html/html (that module depends on
// mbtexcel, so importing it back would be a cycle). Chunked copies keep
// surrogate pairs intact.

///|
/// Escapes `&`, `<`, and `>` for HTML text content.
pub fn escape_html(text : String) -> String {
  escape_with(text, c => {
    match c {
      '&' => Some("&amp;")
      '<' => Some("&lt;")
      '>' => Some("&gt;")
      _ => None
    }
  })
}

///|
/// Escapes `&`, `<`, `>`, and `"` for double-quoted attribute values.
pub fn escape_html_attribute(text : String) -> String {
  escape_with(text, c => {
    match c {
      '&' => Some("&amp;")
      '<' => Some("&lt;")
      '>' => Some("&gt;")
      '"' => Some("&quot;")
      _ => None
    }
  })
}

///|
fn escape_with(text : String, replace : (UInt16) -> String?) -> String {
  let out = StringBuilder()
  let mut start = 0
  let mut changed = false
  for i in 0..<text.length() {
    match replace(text[i]) {
      Some(entity) => {
        changed = true
        out.write_string(text[start:i].to_owned())
        out.write_string(entity)
        start = i + 1
      }
      None => ()
    }
  }
  if !changed {
    return text
  }
  out.write_string(text[start:].to_owned())
  out.to_string()
}

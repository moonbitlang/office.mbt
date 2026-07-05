///|
/// Scan for characters that `escape_xml_text`/`escape_xml_attr` would rewrite,
/// so the escape functions can skip allocating when the input needs no
/// escaping. All escapable characters are single code units, so scanning
/// UTF-16 units directly is safe.
pub fn xml_needs_escape(value : StringView, attr~ : Bool) -> Bool {
  for i in 0..<value.length() {
    match value[i] {
      '&' | '<' | '>' => return true
      '"' | '\'' => if attr { return true }
      _ => ()
    }
  }
  false
}

///|
/// Escape XML text content (`&`, `<`, `>`). Returns the input unchanged when no
/// escaping is needed (a view over a whole string converts back without
/// copying).
pub fn escape_xml_text(value : StringView) -> String {
  if !xml_needs_escape(value, attr=false) {
    return value.to_owned()
  }
  let sb = StringBuilder::new()
  for c in value {
    match c {
      '&' => sb.write_view("&amp;")
      '<' => sb.write_view("&lt;")
      '>' => sb.write_view("&gt;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Escape an XML attribute value (`&`, `<`, `>`, `"`, `'`). Returns the input
/// unchanged when no escaping is needed.
pub fn escape_xml_attr(value : StringView) -> String {
  if !xml_needs_escape(value, attr=true) {
    return value.to_owned()
  }
  let sb = StringBuilder::new()
  for c in value {
    match c {
      '&' => sb.write_view("&amp;")
      '<' => sb.write_view("&lt;")
      '>' => sb.write_view("&gt;")
      '"' => sb.write_view("&quot;")
      '\'' => sb.write_view("&apos;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

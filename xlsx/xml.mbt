///|
fn escape_xml_text(value : StringView) -> String {
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
fn escape_xml_attr(value : StringView) -> String {
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

///|
fn unescape_xml_text(value : StringView) -> String {
  value
  .to_string()
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&apos;", new="'")
  .replace_all(old="&amp;", new="&")
}

///|
fn is_attr_space(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' => true
    _ => false
  }
}

///|
fn attr_value(tag : StringView, name : StringView) -> String? raise XlsxError {
  let chars = tag.to_array()
  let name_chars = name.to_array()
  let mut i = 0
  while i < chars.length() {
    while i < chars.length() && is_attr_space(chars[i]) {
      i = i + 1
    }
    if i >= chars.length() {
      break
    }
    let name_start = i
    while i < chars.length() && !is_attr_space(chars[i]) && chars[i] != '=' {
      i = i + 1
    }
    let name_end = i
    if name_end == name_start {
      i = i + 1
      continue
    }
    while i < chars.length() && is_attr_space(chars[i]) {
      i = i + 1
    }
    if i >= chars.length() || chars[i] != '=' {
      i = name_end
      continue
    }
    i = i + 1
    while i < chars.length() && is_attr_space(chars[i]) {
      i = i + 1
    }
    if i >= chars.length() || chars[i] != '"' {
      continue
    }
    i = i + 1
    let value_start = i
    while i < chars.length() && chars[i] != '"' {
      i = i + 1
    }
    if i >= chars.length() {
      raise XlsxError::InvalidXml(msg="attribute out of range")
    }
    if name_end - name_start == name_chars.length() {
      let mut matched = true
      for j in 0..<name_chars.length() {
        if chars[name_start + j] != name_chars[j] {
          matched = false
          break
        }
      }
      if matched {
        let sb = StringBuilder::new()
        for j in value_start..<i {
          sb.write_char(chars[j])
        }
        return Some(sb.to_string())
      }
    }
    i = i + 1
  }
  None
}

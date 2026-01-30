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
  let tag_len = tag.length()
  let name_len = name.length()
  let is_space = fn(u : UInt16) -> Bool {
    u == (' ' : UInt16) ||
    u == ('\t' : UInt16) ||
    u == ('\n' : UInt16) ||
    u == ('\r' : UInt16)
  }
  let mut i = 0
  while i < tag_len {
    while i < tag_len && is_space(tag[i]) {
      i = i + 1
    }
    if i >= tag_len {
      break
    }
    let name_start = i
    while i < tag_len && !is_space(tag[i]) && tag[i] != ('=' : UInt16) {
      i = i + 1
    }
    let name_end = i
    if name_end == name_start {
      i = i + 1
      continue
    }
    while i < tag_len && is_space(tag[i]) {
      i = i + 1
    }
    if i >= tag_len || tag[i] != ('=' : UInt16) {
      i = name_end
      continue
    }
    i = i + 1
    while i < tag_len && is_space(tag[i]) {
      i = i + 1
    }
    if i >= tag_len || tag[i] != ('"' : UInt16) {
      continue
    }
    i = i + 1
    let value_start = i
    while i < tag_len && tag[i] != ('"' : UInt16) {
      i = i + 1
    }
    if i >= tag_len {
      raise XlsxError::InvalidXml(msg="attribute out of range")
    }
    if name_end - name_start == name_len {
      let mut matched = true
      for j in 0..<name_len {
        if tag[name_start + j] != name[j] {
          matched = false
          break
        }
      }
      if matched {
        let value = tag[value_start:i] catch {
            _ => raise XlsxError::InvalidXml(msg="attribute out of range")
          }
        return Some(value.to_string())
      }
    }
    i = i + 1
  }
  None
}

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
fn attr_value(tag : StringView, name : StringView) -> String? raise XlsxError {
  let needle = name.to_string() + "=\""
  let tag_str = tag.to_string()
  match tag_str.find(needle) {
    Some(start) => {
      let value_start = start + needle.length()
      let rest = tag_str[value_start:] catch {
          _ => raise XlsxError::InvalidXml(msg="attribute out of range")
        }
      match rest.find("\"") {
        Some(end) => {
          let value = rest[:end] catch {
              _ => raise XlsxError::InvalidXml(msg="attribute slice invalid")
            }
          Some(value.to_string())
        }
        None => None
      }
    }
    None => None
  }
}

///|
/// Find the first occurrence of an opening tag `<tag_name ...>` and return the
/// tag text without the leading `<` and without the closing `>`.
///
/// Example: `<a b="c">` -> `a b="c"`.
fn tag_attributes_in(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let xml_str = xml.to_string()
  let needle = "<\{tag_name.to_string()}"
  let start = match xml_str.find(needle) {
    Some(pos) => pos
    None => return None
  }
  let rest = xml_str[start + 1:] catch {
      _ => raise XlsxError::InvalidXml(msg="tag attributes out of range")
    }
  let end = match rest.find(">") {
    Some(pos) => pos
    None => return None
  }
  let slice = rest[:end] catch {
      _ => raise XlsxError::InvalidXml(msg="tag attributes invalid")
    }
  Some(slice.to_string())
}

///|
/// Extract the body text from the first `<tag_name ...>...</tag_name>` pair.
fn extract_tag_body_from(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let xml_str = xml.to_string()
  let open_tag = "<\{tag_name.to_string()}"
  let close_tag = "</\{tag_name.to_string()}>"
  let start = match xml_str.find(open_tag) {
    Some(pos) => pos
    None => return None
  }
  let after_start = xml_str[start:] catch {
      _ => raise XlsxError::InvalidXml(msg="tag slice invalid")
    }
  let open_end_rel = match after_start.find(">") {
    Some(pos) => pos
    None => return None
  }
  let body_start = start + open_end_rel + 1
  let end = match xml_str.find(close_tag) {
    Some(pos) => pos
    None => return None
  }
  let body = xml_str[body_start:end] catch {
      _ => raise XlsxError::InvalidXml(msg="tag body invalid")
    }
  Some(body.to_string())
}

///|
/// Replace `attr_name="..."` inside the first open tag in `xml`.
fn replace_attr_value_in_open_tag(
  xml : StringView,
  attr_name : StringView,
  value : String,
) -> String? raise XlsxError {
  let text = xml.to_string()
  let tag_start = match text.find("<") {
    Some(pos) => pos
    None => return None
  }
  let tag_end = match text.find(">") {
    Some(pos) => pos
    None => return None
  }
  let open_tag = text[tag_start:tag_end] catch {
      _ => raise XlsxError::InvalidXml(msg="tag slice invalid")
    }
  let needle = "\{attr_name.to_string()}=\""
  let attr_pos = match open_tag.find(needle) {
    Some(pos) => pos
    None => return None
  }
  let value_start = tag_start + attr_pos + needle.length()
  let rest = text[value_start:] catch {
      _ => raise XlsxError::InvalidXml(msg="attribute slice invalid")
    }
  let value_end_rel = match rest.find("\"") {
    Some(pos) => pos
    None => return None
  }
  let value_end = value_start + value_end_rel
  let sb = StringBuilder::new()
  sb.write_view(
    text[:value_start] catch {
      _ => raise XlsxError::InvalidXml(msg="attribute start invalid")
    },
  )
  sb.write_view(escape_xml_attr(value))
  sb.write_view(
    text[value_end:] catch {
      _ => raise XlsxError::InvalidXml(msg="attribute end invalid")
    },
  )
  Some(sb.to_string())
}


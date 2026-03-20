///|
fn parse_theme_color(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let body = match extract_tag_body_from(xml, tag_name) {
    Some(value) => value
    None => return None
  }
  match tag_attributes_in(body, "a:srgbClr") {
    Some(attrs) =>
      match attr_value(attrs, "val") {
        Some(value) => return Some(normalize_rgb_hex(value))
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(body, "a:sysClr") {
    Some(attrs) =>
      match attr_value(attrs, "lastClr") {
        Some(value) => return Some(normalize_rgb_hex(value))
        None => ()
      }
    None => ()
  }
  None
}

///|
fn parse_theme_colors(xml : StringView) -> Array[String]? raise XlsxError {
  let tags = [
    "a:lt1", "a:dk1", "a:lt2", "a:dk2", "a:accent1", "a:accent2", "a:accent3", "a:accent4",
    "a:accent5", "a:accent6",
  ]
  let colors : Array[String] = []
  for tag in tags {
    match parse_theme_color(xml, tag) {
      Some(value) => colors.push(value)
      None => return None
    }
  }
  if colors.length() == 0 {
    None
  } else {
    Some(colors)
  }
}

///|
fn parse_indexed_colors(xml : StringView) -> Array[String]? raise XlsxError {
  let body = match extract_tag_body_from(xml, "indexedColors") {
    Some(value) => value
    None => return None
  }
  let colors : Array[String] = []
  let mut first = true
  for chunk in body.split("<rgbColor") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="indexedColors tag invalid")
        }
    }
    let tag = text[:end]
    match attr_value(tag, "rgb") {
      Some(value) => colors.push(normalize_rgb_hex(value))
      None => ()
    }
  }
  if colors.length() == 0 {
    None
  } else {
    Some(colors)
  }
}

///|
fn parse_mru_colors_xml(xml : StringView) -> String? {
  let body = match extract_tag_body_from(xml, "mruColors") {
    Some(value) => value
    None => return None
  }
  let text = body.to_string()
  if text == "" {
    None
  } else {
    Some(text)
  }
}

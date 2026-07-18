///|
priv struct SharedStringEntry {
  text : String
  runs : Array[RichTextRun]?
}

///|
priv struct InlineStringEntry {
  text : String
  runs : Array[RichTextRun]?
}

///|
fn remove_lexical_element_subtrees(
  xml : StringView,
  tag_name : StringView,
) -> String raise XlsxError {
  let first = match find_xml_open_tag_start(xml, tag_name) {
    Some(value) => value
    None => return xml.to_owned()
  }
  let output = StringBuilder::new(size_hint=xml.length())
  let mut cursor = 0
  let mut start = first
  for ;; {
    output.write_view(xml[cursor:start])
    let open_end = match xml_open_tag_end_from(xml, start + 1) {
      Some(value) => value
      None => raise InvalidXml(msg="\{tag_name.to_owned()} tag not closed")
    }
    if xml[start + 1:open_end].trim().has_suffix("/") {
      cursor = open_end + 1
    } else {
      let (close_start, close_end) = match
        find_xml_close_tag_from(xml, tag_name, open_end + 1) {
        Some(value) => value
        None => raise InvalidXml(msg="\{tag_name.to_owned()} close missing")
      }
      ignore(close_start)
      cursor = close_end + 1
    }
    match find_xml_open_tag_start_from(xml, tag_name, cursor) {
      Some(next) => start = next
      None => break
    }
  }
  output.write_view(xml[cursor:])
  output.to_string()
}

///|
fn parse_text_nodes(xml : StringView) -> String raise XlsxError {
  // Phonetic guides (`rPh`) are annotations, not displayed cell text.
  let semantic = remove_lexical_element_subtrees(xml, "rPh")
  let sb = StringBuilder::new()
  let mut cursor = 0
  while find_xml_open_tag_start_from(semantic, "t", cursor) is Some(start) {
    let open_end = match xml_open_tag_end_from(semantic, start + 1) {
      Some(value) => value
      None => raise InvalidXml(msg="shared string text tag not closed")
    }
    if semantic[start + 1:open_end].trim().has_suffix("/") {
      cursor = open_end + 1
      continue
    }
    let (close_start, close_end) = match
      find_xml_close_tag_from(semantic, "t", open_end + 1) {
      Some(value) => value
      None => raise InvalidXml(msg="shared string text close missing")
    }
    sb.write_view(unescape_xml_text(semantic[open_end + 1:close_start]))
    cursor = close_end + 1
  }
  sb.to_string()
}

///|
/// Read a boolean font flag from an `rPr` body: `true` if the `<tag ...>`
/// element is present and its `val` attribute (default `"1"`) is truthy,
/// `false` if the element is absent or `val` is falsy.
fn read_font_bool_flag(
  rpr_body : StringView,
  tag : StringView,
) -> Bool raise XlsxError {
  match tag_attributes_in(rpr_body, tag) {
    Some(attrs) =>
      match attr_value(attrs, "val") {
        Some(val) => parse_bool_attr(val)
        None => true
      }
    None => false
  }
}

///|
fn parse_rich_text_font(body : StringView) -> RichTextFont? raise XlsxError {
  let rpr_body = match extract_tag_body_from(body, "rPr") {
    Some(value) => value
    None => return None
  }
  let mut bold = false
  let mut italic = false
  let mut strike = false
  let mut outline = false
  let mut shadow = false
  let mut condense = false
  let mut extended = false
  let mut underline : String? = None
  let mut size : Double? = None
  let mut color : String? = None
  let mut color_theme : Int? = None
  let mut color_indexed : Int? = None
  let mut color_tint : Double? = None
  let mut charset : Int? = None
  let mut family_number : Int? = None
  let mut scheme : String? = None
  let mut vert_align : String? = None
  let mut family : String? = None
  let mut has_any = false
  // Each of these boolean font flags is present-with-optional-val="0"; a flag
  // that resolves true marks the font as non-default. `read_font_bool_flag`
  // centralizes that parse. (`extend` is the XML tag for the `extended` field.)
  bold = read_font_bool_flag(rpr_body, "b")
  if bold {
    has_any = true
  }
  italic = read_font_bool_flag(rpr_body, "i")
  if italic {
    has_any = true
  }
  strike = read_font_bool_flag(rpr_body, "strike")
  if strike {
    has_any = true
  }
  outline = read_font_bool_flag(rpr_body, "outline")
  if outline {
    has_any = true
  }
  shadow = read_font_bool_flag(rpr_body, "shadow")
  if shadow {
    has_any = true
  }
  condense = read_font_bool_flag(rpr_body, "condense")
  if condense {
    has_any = true
  }
  extended = read_font_bool_flag(rpr_body, "extend")
  if extended {
    has_any = true
  }
  match tag_attributes_in(rpr_body, "u") {
    Some(tag) => {
      let value = match attr_value(tag, "val") {
        Some(val) => val
        None => "single"
      }
      if value != "none" && value != "0" {
        underline = Some(value.to_string())
        has_any = true
      }
    }
    None => ()
  }
  match tag_attributes_in(rpr_body, "sz") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(val) =>
          try @string.parse_double(val) catch {
            _ => ()
          } noraise {
            value => {
              size = Some(value)
              has_any = true
            }
          }
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(rpr_body, "charset") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(val) =>
          try @string.parse_int(val, base=10) catch {
            _ => ()
          } noraise {
            value => {
              charset = Some(value)
              has_any = true
            }
          }
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(rpr_body, "family") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(val) =>
          try @string.parse_int(val, base=10) catch {
            _ => ()
          } noraise {
            value => {
              family_number = Some(value)
              has_any = true
            }
          }
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(rpr_body, "rFont") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(val) => {
          family = Some(val)
          has_any = true
        }
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(rpr_body, "color") {
    Some(tag) => {
      match attr_value(tag, "rgb") {
        Some(val) => {
          color = Some(val)
          has_any = true
        }
        None => ()
      }
      match attr_value(tag, "theme") {
        Some(val) =>
          try @string.parse_int(val, base=10) catch {
            _ => raise InvalidXml(msg="rich text color theme invalid")
          } noraise {
            value => {
              color_theme = Some(value)
              has_any = true
            }
          }
        None => ()
      }
      match attr_value(tag, "indexed") {
        Some(val) =>
          try @string.parse_int(val, base=10) catch {
            _ => raise InvalidXml(msg="rich text color indexed invalid")
          } noraise {
            value => {
              color_indexed = Some(value)
              has_any = true
            }
          }
        None => ()
      }
      match attr_value(tag, "tint") {
        Some(val) =>
          try @string.parse_double(val) catch {
            _ => raise InvalidXml(msg="rich text color tint invalid")
          } noraise {
            value => {
              color_tint = Some(value)
              has_any = true
            }
          }
        None => ()
      }
    }
    None => ()
  }
  match tag_attributes_in(rpr_body, "vertAlign") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(val) => {
          vert_align = Some(val.to_string())
          has_any = true
        }
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(rpr_body, "scheme") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(val) => {
          scheme = Some(val.to_string())
          has_any = true
        }
        None => ()
      }
    None => ()
  }
  if has_any {
    Some({
      bold,
      italic,
      strike,
      outline,
      shadow,
      condense,
      extended,
      underline,
      size,
      color,
      color_theme,
      color_indexed,
      color_tint,
      charset,
      family_number,
      scheme,
      vert_align,
      family,
    })
  } else {
    None
  }
}

///|
fn parse_rich_text_runs(xml : StringView) -> Array[RichTextRun] raise XlsxError {
  let runs : Array[RichTextRun] = []
  let xml_str = xml.to_owned()
  let mut index = 0
  while index < xml_str.length() {
    let rest = xml_str[index:]
    let rel = match rest.find("<r") {
      Some(pos) => pos
      None => break
    }
    let start = index + rel
    let after = start + 2
    if after >= xml_str.length() {
      break
    }
    let next = xml_str[after]
    if next != '>' &&
      next != ' ' &&
      next != '\t' &&
      next != '\n' &&
      next != '\r' {
      index = after
      continue
    }
    let tail = xml_str[after:]
    let open_end_rel = match tail.find(">") {
      Some(pos) => pos
      None => break
    }
    let body_start = after + open_end_rel + 1
    let body_rest = xml_str[body_start:]
    let (close_rel, close_end_rel) = match
      find_xml_close_tag_from(body_rest, "r", 0) {
      Some((pos, end)) => (pos, end)
      None => break
    }
    let body_end = body_start + close_rel
    let body = xml_str[body_start:body_end]
    let run_text = parse_text_nodes(body)
    let font = parse_rich_text_font(body)
    runs.push({ text: run_text, font })
    index = body_start + close_end_rel + 1
  }
  runs
}

///|
fn parse_shared_strings(
  xml : StringView,
  budget? : ReadBudget,
) -> Array[SharedStringEntry] raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(xml.length())
    }
    None => ()
  }
  let values : Array[SharedStringEntry] = []
  let mut cursor = 0
  while find_xml_open_tag_start_from(xml, "si", cursor) is Some(start) {
    match budget {
      Some(value) => value.checkpoint()
      None => ()
    }
    let open_end = match xml_open_tag_end_from(xml, start + 1) {
      Some(value) => value
      None => raise InvalidXml(msg="shared string item tag not closed")
    }
    let (close_start, close_end) = match
      find_xml_close_tag_from(xml, "si", open_end + 1) {
      Some(value) => value
      None => raise InvalidXml(msg="shared string item close missing")
    }
    let body = xml[open_end + 1:close_start]
    let runs = if body.contains("<r") {
      let parsed = parse_rich_text_runs(body) catch { _ => [] }
      if parsed.length() > 0 {
        Some(parsed)
      } else {
        None
      }
    } else {
      None
    }
    values.push({ text: parse_text_nodes(body), runs })
    cursor = close_end + 1
  }
  values
}

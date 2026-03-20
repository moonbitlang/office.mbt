///|
fn find_last_substring(text : StringView, needle : StringView) -> Int? {
  let text_str = text.to_string()
  let needle_str = needle.to_string()
  if needle_str == "" {
    return None
  }
  let mut i = 0
  let mut last : Int? = None
  while i < text_str.length() {
    let rest = text_str[i:]
    match rest.find(needle_str) {
      Some(pos) => {
        let abs = i + pos
        last = Some(abs)
        i = abs + 1
      }
      None => break
    }
  }
  last
}

///|
fn end_after_last_tag(xml : StringView, tag : StringView) -> Int? {
  let close_tag = "</\{tag.to_string()}>"
  match find_last_substring(xml, close_tag) {
    Some(pos) => Some(pos + close_tag.length())
    None => {
      let open_tag = "<\{tag.to_string()}"
      match find_last_substring(xml, open_tag) {
        Some(pos) => {
          let rest = xml.to_string()[pos:]
          match rest.find(">") {
            Some(rel) => Some(pos + rel + 1)
            None => None
          }
        }
        None => None
      }
    }
  }
}

///|
fn parse_styles_ext_lst_xml(xml : StringView) -> String? raise XlsxError {
  let xml_str = xml.to_string()
  let style_sheet_close = "</styleSheet>"
  let style_end = match xml_str.find(style_sheet_close) {
    Some(pos) => pos
    None => return None
  }
  let prefix = xml_str[:style_end]
  let mut search_start = 0
  for tag in ["colors", "tableStyles", "dxfs", "cellStyles", "cellXfs"] {
    match end_after_last_tag(prefix, tag) {
      Some(end) => if end > search_start { search_start = end }
      None => ()
    }
  }
  let tail = prefix[search_start:]
  let ext_rel = match tail.find("<extLst") {
    Some(pos) => pos
    None => return None
  }
  let ext_start = search_start + ext_rel
  let ext_rest = prefix[ext_start:]
  let open_end_rel = match ext_rest.find(">") {
    Some(pos) => pos
    None => raise InvalidXml(msg="styles.xml extLst tag not closed")
  }
  if open_end_rel > 0 && ext_rest[open_end_rel - 1] == '/' {
    return Some("")
  }
  let body_start = ext_start + open_end_rel + 1
  let body_rest = prefix[body_start:]
  let close_rel = match body_rest.find("</extLst>") {
    Some(pos) => pos
    None => raise InvalidXml(msg="styles.xml extLst close missing")
  }
  let body_end = body_start + close_rel
  Some(prefix[body_start:body_end].to_string())
}

///|
fn parse_table_styles_defaults(
  xml : StringView,
) -> (String, String) raise XlsxError {
  let mut table = "TableStyleMedium9"
  let mut pivot = "PivotStyleLight16"
  match tag_attributes_in(xml, "tableStyles") {
    Some(tag) => {
      match attr_value(tag, "defaultTableStyle") {
        Some(value) => table = unescape_xml_text(value)
        None => ()
      }
      match attr_value(tag, "defaultPivotStyle") {
        Some(value) => pivot = unescape_xml_text(value)
        None => ()
      }
    }
    None => ()
  }
  (table, pivot)
}

///|
pub(all) enum StyleNameMatcher {
  ExactStyleName(String)
  PrefixStyleName(String)
} derive(Debug, Eq)

///|
pub(all) enum DocumentMatcher {
  ParagraphMatcher(
    style_id~ : String?,
    style_name~ : StyleNameMatcher?,
    numbering~ : Numbering?
  )
  RunMatcher(style_id~ : String?, style_name~ : StyleNameMatcher?)
  RunPropertyMatcher(String)
  HighlightMatcher(String?)
  TableMatcher(style_id~ : String?, style_name~ : StyleNameMatcher?)
  BreakMatcher(BreakType)
  CommentReferenceMatcher
} derive(Debug, Eq)

///|
pub(all) struct HtmlPathElement {
  tag : String
  attributes : Map[String, String]
  fresh : Bool
} derive(Debug, Eq)

///|
pub(all) struct StyleMapping {
  from : DocumentMatcher
  to : Array[HtmlPathElement]
} derive(Debug, Eq)

///|
pub fn read_style_mapping(line : String) -> StyleMapping? {
  let parts = line.split("=>").collect()
  if parts.length() != 2 {
    None
  } else {
    let from_text = parts[0].trim().to_owned()
    let to_text = parts[1].trim().to_owned()
    match read_document_matcher(from_text) {
      Some(from) => Some({ from, to: read_html_path(to_text) })
      None => None
    }
  }
}

///|
pub fn read_style_map(lines : Array[String]) -> Array[StyleMapping] {
  let mappings : Array[StyleMapping] = []
  for line in lines {
    match read_style_mapping(line) {
      Some(mapping) => mappings.push(mapping)
      None => ()
    }
  }
  mappings
}

///|
pub fn read_style_map_string(style_map : String) -> Array[String] {
  let lines : Array[String] = []
  for line_view in style_map.split("\n") {
    let line = line_view.trim().to_owned()
    if line != "" && !line.has_prefix("#") {
      lines.push(line)
    }
  }
  lines
}

///|
fn read_document_matcher(value : String) -> DocumentMatcher? {
  if value == "b" {
    Some(RunPropertyMatcher("bold"))
  } else if value == "i" {
    Some(RunPropertyMatcher("italic"))
  } else if value == "u" {
    Some(RunPropertyMatcher("underline"))
  } else if value == "strike" {
    Some(RunPropertyMatcher("strikethrough"))
  } else if value == "all-caps" {
    Some(RunPropertyMatcher("allCaps"))
  } else if value == "small-caps" {
    Some(RunPropertyMatcher("smallCaps"))
  } else if value == "highlight" {
    Some(HighlightMatcher(None))
  } else if value.has_prefix("highlight[") {
    Some(HighlightMatcher(read_attribute_value(value, "color")))
  } else if value.has_prefix("table") {
    Some(read_table_matcher(value))
  } else if value.has_prefix("br") {
    Some(BreakMatcher(read_break_matcher_type(value)))
  } else if value == "comment-reference" {
    Some(CommentReferenceMatcher)
  } else if value.has_prefix("p") {
    Some(read_paragraph_matcher(value))
  } else if value.has_prefix("r") {
    Some(read_run_matcher(value))
  } else {
    None
  }
}

///|
fn read_break_matcher_type(value : String) -> BreakType {
  match read_attribute_value(value, "type") {
    Some("page") => Page
    Some("column") => Column
    _ => Line
  }
}

///|
fn read_paragraph_matcher(value : String) -> DocumentMatcher {
  let style_id = read_style_id(value, "p")
  let style_name = read_style_name_matcher(value)
  let numbering = if value.contains(":ordered-list(") {
    Some({ is_ordered: true, level: read_list_level(value) })
  } else if value.contains(":unordered-list(") {
    Some({ is_ordered: false, level: read_list_level(value) })
  } else {
    None
  }
  ParagraphMatcher(style_id~, style_name~, numbering~)
}

///|
fn read_run_matcher(value : String) -> DocumentMatcher {
  RunMatcher(
    style_id=read_style_id(value, "r"),
    style_name=read_style_name_matcher(value),
  )
}

///|
fn read_table_matcher(value : String) -> DocumentMatcher {
  TableMatcher(
    style_id=read_style_id(value, "table"),
    style_name=read_style_name_matcher(value),
  )
}

///|
fn read_style_id(value : String, prefix : String) -> String? {
  let prefix = prefix + "."
  if value.has_prefix(prefix) {
    let rest = value[prefix.length():].to_owned()
    match rest.find("[") {
      Some(index) => Some(rest[:index].to_owned())
      None => Some(rest)
    }
  } else {
    None
  }
}

///|
fn read_attribute_value(value : String, name : String) -> String? {
  let needle = name + "='"
  match value.find(needle) {
    Some(start) => {
      let value_start = start + needle.length()
      match value[value_start:].find("'") {
        Some(length) => Some(value[value_start:value_start + length].to_owned())
        None => None
      }
    }
    None => None
  }
}

///|
fn read_style_name_matcher(value : String) -> StyleNameMatcher? {
  match read_attribute_value(value, "style-name") {
    Some(name) => Some(ExactStyleName(name))
    None =>
      match read_prefix_attribute_value(value, "style-name") {
        Some(prefix) => Some(PrefixStyleName(prefix))
        None => None
      }
  }
}

///|
fn read_prefix_attribute_value(value : String, name : String) -> String? {
  let needle = name + "^='"
  match value.find(needle) {
    Some(start) => {
      let value_start = start + needle.length()
      match value[value_start:].find("'") {
        Some(length) => Some(value[value_start:value_start + length].to_owned())
        None => None
      }
    }
    None => None
  }
}

///|
fn read_list_level(value : String) -> Int {
  match value.find("(") {
    Some(start) =>
      match value[start + 1:].find(")") {
        Some(length) =>
          @string.parse_int(value[start + 1:start + 1 + length].to_owned()) catch {
            _ => 1
          }
        None => 1
      }
    None => 1
  }
}

///|
fn read_html_path(value : String) -> Array[HtmlPathElement] {
  let elements : Array[HtmlPathElement] = []
  if value == "" {
    return elements
  }
  for part_view in value.split(">") {
    let part = part_view.trim().to_owned()
    if part != "" {
      elements.push(read_html_path_element(part))
    }
  }
  elements
}

///|
fn read_html_path_element(value : String) -> HtmlPathElement {
  let (element_text, options_text) = split_html_path_options(value)
  let tag_choices = read_html_tag_choices(element_text)
  let tag = match tag_choices.split("|").next() {
    Some(first) => decode_style_escapes(first.trim().to_owned())
    None => decode_style_escapes(tag_choices)
  }
  let fresh = options_text.contains("fresh")
  let attributes = read_html_path_attributes(element_text)
  { tag, attributes, fresh }
}

///|
fn split_html_path_options(value : String) -> (String, String) {
  match find_unescaped_char(value, ':') {
    Some(index) =>
      (value[:index].trim().to_owned(), value[index + 1:].trim().to_owned())
    None => (value.trim().to_owned(), "")
  }
}

///|
fn read_html_tag_choices(value : String) -> String {
  let mut index = 0
  while index < value.length() {
    let char = value[index]
    if char == '.' || char == '[' {
      return value[:index].to_owned()
    }
    index = index + 1
  }
  value
}

///|
fn read_html_path_attributes(value : String) -> Map[String, String] {
  let attributes : Map[String, String] = {}
  let mut index = read_html_tag_choices(value).length()
  while index < value.length() {
    if value[index] == '.' {
      let (class_name, next_index) = read_html_class(value, index + 1)
      if class_name != "" {
        match attributes.get("class") {
          Some(existing) => attributes["class"] = existing + " " + class_name
          None => attributes["class"] = class_name
        }
      }
      index = next_index
    } else if value[index] == '[' {
      let (name, attr_value, next_index) = read_html_attribute(value, index + 1)
      if name != "" {
        attributes[name] = attr_value
      }
      index = next_index
    } else {
      index = index + 1
    }
  }
  attributes
}

///|
fn read_html_class(value : String, start : Int) -> (String, Int) {
  let mut index = start
  let builder = StringBuilder()
  while index < value.length() {
    let char = value[index]
    if char == '\\' && index + 1 < value.length() {
      builder.write_string(value[index + 1:index + 2].to_owned())
      index = index + 2
    } else if char == '.' || char == '[' {
      return (builder.to_string(), index)
    } else {
      builder.write_string(value[index:index + 1].to_owned())
      index = index + 1
    }
  }
  (builder.to_string(), index)
}

///|
fn read_html_attribute(value : String, start : Int) -> (String, String, Int) {
  match value[start:].find("='") {
    Some(equals_index) => {
      let name = value[start:start + equals_index].to_owned()
      let value_start = start + equals_index + 2
      let mut index = value_start
      let builder = StringBuilder()
      while index < value.length() {
        let char = value[index]
        if char == '\\' && index + 1 < value.length() {
          builder.write_string(value[index + 1:index + 2].to_owned())
          index = index + 2
        } else if char == '\'' {
          let close = if index + 1 < value.length() && value[index + 1] == ']' {
            index + 2
          } else {
            index + 1
          }
          return (name, builder.to_string(), close)
        } else {
          builder.write_string(value[index:index + 1].to_owned())
          index = index + 1
        }
      }
      (name, builder.to_string(), index)
    }
    None => ("", "", value.length())
  }
}

///|
fn find_unescaped_char(value : String, needle : UInt16) -> Int? {
  let mut index = 0
  while index < value.length() {
    if value[index] == '\\' {
      index = index + 2
    } else if value[index] == needle {
      return Some(index)
    } else {
      index = index + 1
    }
  }
  None
}

///|
fn decode_style_escapes(value : String) -> String {
  let builder = StringBuilder()
  let mut index = 0
  while index < value.length() {
    if value[index] == '\\' && index + 1 < value.length() {
      builder.write_string(value[index + 1:index + 2].to_owned())
      index = index + 2
    } else {
      builder.write_string(value[index:index + 1].to_owned())
      index = index + 1
    }
  }
  builder.to_string()
}

///|
fn DocumentMatcher::matches(
  self : DocumentMatcher,
  element : DocumentElement,
) -> Bool {
  match (self, element) {
    (
      ParagraphMatcher(style_id~, style_name~, numbering~),
      Paragraph(properties~, ..),
    ) =>
      option_matches(style_id, properties.style_id) &&
      style_name_matches(style_name, properties.style_name) &&
      option_matches(numbering, properties.numbering)
    (RunMatcher(style_id~, style_name~), Run(properties~, ..)) =>
      option_matches(style_id, properties.style_id) &&
      style_name_matches(style_name, properties.style_name)
    (TableMatcher(style_id~, style_name~), Table(properties~, ..)) =>
      option_matches(style_id, properties.style_id) &&
      style_name_matches(style_name, properties.style_name)
    (RunPropertyMatcher("bold"), Run(properties~, ..)) => properties.is_bold
    (RunPropertyMatcher("italic"), Run(properties~, ..)) => properties.is_italic
    (RunPropertyMatcher("underline"), Run(properties~, ..)) =>
      properties.is_underline
    (RunPropertyMatcher("strikethrough"), Run(properties~, ..)) =>
      properties.is_strikethrough
    (RunPropertyMatcher("allCaps"), Run(properties~, ..)) =>
      properties.is_all_caps
    (RunPropertyMatcher("smallCaps"), Run(properties~, ..)) =>
      properties.is_small_caps
    (HighlightMatcher(None), Run(properties~, ..)) =>
      properties.highlight != None
    (HighlightMatcher(Some(color)), Run(properties~, ..)) =>
      properties.highlight == Some(color)
    (BreakMatcher(expected), Break(actual)) => expected == actual
    (CommentReferenceMatcher, CommentReference(_)) => true
    _ => false
  }
}

///|
fn[T : Eq] option_matches(expected : T?, actual : T?) -> Bool {
  match expected {
    Some(value) => actual == Some(value)
    None => true
  }
}

///|
fn style_name_matches(expected : StyleNameMatcher?, actual : String?) -> Bool {
  match (expected, actual) {
    (Some(ExactStyleName(a)), Some(b)) => a.to_lower() == b.to_lower()
    (Some(PrefixStyleName(a)), Some(b)) => b.to_lower().has_prefix(a.to_lower())
    (Some(_), None) => false
    (None, _) => true
  }
}

///|
fn find_style_mapping(
  element : DocumentElement,
  style_map : Array[StyleMapping],
) -> StyleMapping? {
  for mapping in style_map {
    if mapping.from.matches(element) {
      return Some(mapping)
    }
  }
  None
}

///|
pub fn default_style_map_lines() -> Array[String] {
  [
    "p.Heading1 => h1:fresh", "p.Heading2 => h2:fresh", "p.Heading3 => h3:fresh",
    "p.Heading4 => h4:fresh", "p.Heading5 => h5:fresh", "p.Heading6 => h6:fresh",
    "p[style-name='Heading 1'] => h1:fresh", "p[style-name='Heading 2'] => h2:fresh",
    "p[style-name='Heading 3'] => h3:fresh", "p[style-name='Heading 4'] => h4:fresh",
    "p[style-name='Heading 5'] => h5:fresh", "p[style-name='Heading 6'] => h6:fresh",
    "p[style-name='heading 1'] => h1:fresh", "p[style-name='heading 2'] => h2:fresh",
    "p[style-name='heading 3'] => h3:fresh", "p[style-name='heading 4'] => h4:fresh",
    "p[style-name='heading 5'] => h5:fresh", "p[style-name='heading 6'] => h6:fresh",
    "p.Heading => h1:fresh", "p[style-name='Heading'] => h1:fresh", "r[style-name='Strong'] => strong",
    "p[style-name='footnote text'] => p:fresh", "r[style-name='footnote reference'] =>",
    "p[style-name='endnote text'] => p:fresh", "r[style-name='endnote reference'] =>",
    "p[style-name='annotation text'] => p:fresh", "r[style-name='annotation reference'] =>",
    "p[style-name='Footnote'] => p:fresh", "r[style-name='Footnote anchor'] =>",
    "p[style-name='Endnote'] => p:fresh", "r[style-name='Endnote anchor'] =>", "p:unordered-list(1) => ul > li:fresh",
    "p:unordered-list(2) => ul > li > ul > li:fresh", "p:unordered-list(3) => ul > li > ul > li > ul > li:fresh",
    "p:unordered-list(4) => ul > li > ul > li > ul > li > ul > li:fresh", "p:unordered-list(5) => ul > li > ul > li > ul > li > ul > li > ul > li:fresh",
    "p:ordered-list(1) => ol > li:fresh", "p:ordered-list(2) => ol > li > ol > li:fresh",
    "p:ordered-list(3) => ol > li > ol > li > ol > li:fresh", "p:ordered-list(4) => ol > li > ol > li > ol > li > ol > li:fresh",
    "p:ordered-list(5) => ol > li > ol > li > ol > li > ol > li > ol > li:fresh",
    "r[style-name='Hyperlink'] =>", "p[style-name='Normal'] => p:fresh", "p.Body => p:fresh",
    "p[style-name='Body'] => p:fresh",
  ]
}

///|
pub(all) enum DocumentMatcher {
  ParagraphMatcher(
    style_id~ : String?,
    style_name~ : String?,
    numbering~ : Numbering?
  )
  RunMatcher(style_id~ : String?, style_name~ : String?)
  RunPropertyMatcher(String)
  HighlightMatcher(String?)
  TableMatcher(style_id~ : String?, style_name~ : String?)
  BreakMatcher
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
  } else if value == "table" {
    Some(TableMatcher(style_id=None, style_name=None))
  } else if value == "br" {
    Some(BreakMatcher)
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
fn read_paragraph_matcher(value : String) -> DocumentMatcher {
  let style_id = read_style_id(value, "p")
  let style_name = read_attribute_value(value, "style-name")
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
    style_name=read_attribute_value(value, "style-name"),
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
  let segments = value.split(":").collect()
  let tag_choices = segments[0].trim().to_owned()
  let tag = match tag_choices.split("|").next() {
    Some(first) => first.trim().to_owned()
    None => tag_choices
  }
  let fresh = value.contains(":fresh")
  let attributes : Map[String, String] = {}
  { tag, attributes, fresh }
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
      option_matches_ci(style_name, properties.style_name) &&
      option_matches(numbering, properties.numbering)
    (RunMatcher(style_id~, style_name~), Run(properties~, ..)) =>
      option_matches(style_id, properties.style_id) &&
      option_matches_ci(style_name, properties.style_name)
    (TableMatcher(style_id~, style_name~), Table(properties~, ..)) =>
      option_matches(style_id, properties.style_id) &&
      option_matches_ci(style_name, properties.style_name)
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
    (BreakMatcher, Break(Line)) => true
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
fn option_matches_ci(expected : String?, actual : String?) -> Bool {
  match (expected, actual) {
    (Some(a), Some(b)) => a.to_lower() == b.to_lower()
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

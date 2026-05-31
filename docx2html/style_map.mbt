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
  separator : String?
} derive(Debug, Eq)

///|
pub(all) struct StyleMapping {
  from : DocumentMatcher
  to : Array[HtmlPathElement]
} derive(Debug, Eq)

///|
priv struct StyleMapReadResult {
  mappings : Array[StyleMapping]
  messages : Array[Message]
}

///|
priv struct ParsedMatcherSuffixes {
  style_id : String?
  style_name : StyleNameMatcher?
  numbering : Numbering?
}

///|
pub fn read_style_mapping(line : String) -> StyleMapping? {
  read_style_mapping_with_message(line).0
}

///|
pub fn read_style_map(lines : Array[String]) -> Array[StyleMapping] {
  read_style_map_with_messages(lines).mappings
}

///|
fn read_style_map_with_messages(lines : Array[String]) -> StyleMapReadResult {
  let mappings : Array[StyleMapping] = []
  let messages : Array[Message] = []
  for line in lines {
    let (mapping, message) = read_style_mapping_with_message(line)
    match mapping {
      Some(mapping) => mappings.push(mapping)
      None => ()
    }
    match message {
      Some(message) => messages.push(message)
      None => ()
    }
  }
  { mappings, messages }
}

///|
fn read_style_mapping_with_message(line : String) -> (StyleMapping?, Message?) {
  let end = line.length()
  let (from, first_index, error) = parse_style_document_matcher(line, 0, end)
  let mut index = first_index
  match error {
    Some(error) => return (None, Some(style_mapping_warning(line, error)))
    None => ()
  }
  let from = match from {
    Some(from) => from
    None =>
      return (
        None,
        Some(
          style_mapping_warning(
            line,
            style_parse_error(line, index, end, "element type"),
          ),
        ),
      )
  }
  if index >= end || !is_style_whitespace(line[index]) {
    return (
      None,
      Some(
        style_mapping_warning(
          line,
          style_parse_error(line, index, end, "whitespace"),
        ),
      ),
    )
  }
  while index < end && is_style_whitespace(line[index]) {
    index = index + 1
  }
  if !starts_with_at(line, index, end, "=>") {
    return (
      None,
      Some(
        style_mapping_warning(
          line,
          style_parse_error(line, index, end, "arrow"),
        ),
      ),
    )
  }
  let after_arrow = index + 2
  let to_raw = line[after_arrow:].to_owned()
  let to_text = to_raw.trim().to_owned()
  match validate_html_path_text(line, to_raw, after_arrow) {
    Some(error) => (None, Some(style_mapping_warning(line, error)))
    None => (Some({ from, to: read_html_path(to_text) }), None)
  }
}

///|
fn style_mapping_warning(line : String, error : String) -> Message {
  Warning(
    "Did not understand this style mapping, so ignored it: " +
    line +
    "\n" +
    error,
  )
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
fn parse_style_document_matcher(
  line : String,
  index : Int,
  end : Int,
) -> (DocumentMatcher?, Int, String?) {
  let (name, next, error) = parse_style_identifier(
    line, index, end, "element type",
  )
  match error {
    Some(error) => return (None, next, Some(error))
    None => ()
  }
  match name {
    "p" => {
      let (suffixes, next, error) = parse_style_matcher_suffixes(
        line,
        next,
        end,
        allow_list=true,
      )
      match error {
        Some(error) => (None, next, Some(error))
        None =>
          (
            Some(
              ParagraphMatcher(
                style_id=suffixes.style_id,
                style_name=suffixes.style_name,
                numbering=suffixes.numbering,
              ),
            ),
            next,
            None,
          )
      }
    }
    "r" => {
      let (suffixes, next, error) = parse_style_matcher_suffixes(
        line,
        next,
        end,
        allow_list=true,
      )
      match error {
        Some(error) => (None, next, Some(error))
        None =>
          (
            Some(
              RunMatcher(
                style_id=suffixes.style_id,
                style_name=suffixes.style_name,
              ),
            ),
            next,
            None,
          )
      }
    }
    "table" => parse_style_table_matcher(line, next, end)
    "b" => (Some(RunPropertyMatcher("bold")), next, None)
    "i" => (Some(RunPropertyMatcher("italic")), next, None)
    "u" => (Some(RunPropertyMatcher("underline")), next, None)
    "strike" => (Some(RunPropertyMatcher("strikethrough")), next, None)
    "all-caps" => (Some(RunPropertyMatcher("allCaps")), next, None)
    "small-caps" => (Some(RunPropertyMatcher("smallCaps")), next, None)
    "highlight" => parse_style_highlight_matcher(line, next, end)
    "comment-reference" => (Some(CommentReferenceMatcher), next, None)
    "br" => parse_style_break_matcher(line, next, end)
    _ =>
      (None, index, Some(style_parse_error(line, index, end, "element type")))
  }
}

///|
fn parse_style_matcher_suffixes(
  line : String,
  index : Int,
  end : Int,
  allow_list~ : Bool,
) -> (ParsedMatcherSuffixes, Int, String?) {
  let mut suffixes = ParsedMatcherSuffixes::{
    style_id: None,
    style_name: None,
    numbering: None,
  }
  let mut index = index
  while index < end {
    if line[index] == '.' {
      let (style_id, next, error) = parse_style_identifier(
        line,
        index + 1,
        end,
        "identifier",
      )
      match error {
        Some(error) => return (suffixes, next, Some(error))
        None => {
          suffixes = { ..suffixes, style_id: Some(style_id) }
          index = next
        }
      }
    } else if line[index] == '[' {
      let (style_name, next, error) = parse_style_name_suffix(
        line,
        index + 1,
        end,
      )
      match error {
        Some(error) => return (suffixes, next, Some(error))
        None => {
          suffixes = { ..suffixes, style_name, }
          index = next
        }
      }
    } else if allow_list && line[index] == ':' {
      let (numbering, next, consumed, error) = parse_style_list_suffix(
        line, index, end,
      )
      match error {
        Some(error) => return (suffixes, next, Some(error))
        None =>
          if consumed {
            suffixes = { ..suffixes, numbering, }
            index = next
          } else {
            return (suffixes, index, None)
          }
      }
    } else {
      return (suffixes, index, None)
    }
  }
  (suffixes, index, None)
}

///|
fn parse_style_table_matcher(
  line : String,
  index : Int,
  end : Int,
) -> (DocumentMatcher?, Int, String?) {
  let (suffixes, next, error) = parse_style_matcher_suffixes(
    line,
    index,
    end,
    allow_list=false,
  )
  match error {
    Some(error) => (None, next, Some(error))
    None =>
      (
        Some(
          TableMatcher(
            style_id=suffixes.style_id,
            style_name=suffixes.style_name,
          ),
        ),
        next,
        None,
      )
  }
}

///|
fn parse_style_name_suffix(
  line : String,
  index : Int,
  end : Int,
) -> (StyleNameMatcher?, Int, String?) {
  let (name, first_index, error) = parse_style_identifier(
    line, index, end, "identifier",
  )
  let mut index = first_index
  match error {
    Some(error) => return (None, index, Some(error))
    None => ()
  }
  if name != "style-name" {
    return (
      None,
      index,
      Some(style_parse_error(line, index, end, "style name matcher")),
    )
  }
  let mut is_prefix = false
  if starts_with_at(line, index, end, "^=") {
    is_prefix = true
    index = index + 2
  } else if index < end && line[index] == '=' {
    index = index + 1
  } else {
    return (
      None,
      index,
      Some(style_parse_error(line, index, end, "style name matcher")),
    )
  }
  let (value, next, error) = parse_style_string(line, index, end)
  match error {
    Some(error) => return (None, next, Some(error))
    None => index = next
  }
  if index >= end || line[index] != ']' {
    return (
      None,
      index,
      Some(style_parse_error(line, index, end, "close-square-bracket")),
    )
  }
  let matcher = if is_prefix {
    PrefixStyleName(value)
  } else {
    ExactStyleName(value)
  }
  (Some(matcher), index + 1, None)
}

///|
fn parse_style_list_suffix(
  line : String,
  index : Int,
  end : Int,
) -> (Numbering?, Int, Bool, String?) {
  if index >= end || line[index] != ':' {
    return (None, index, false, None)
  }
  let (name, first_next, error) = parse_style_identifier(
    line,
    index + 1,
    end,
    "identifier",
  )
  let mut next = first_next
  match error {
    Some(error) => return (None, next, true, Some(error))
    None => ()
  }
  let is_ordered = match name {
    "ordered-list" => true
    "unordered-list" => false
    _ => return (None, index, false, None)
  }
  if next >= end || line[next] != '(' {
    return (
      None,
      next,
      true,
      Some(style_parse_error(line, next, end, "open-paren")),
    )
  }
  let (level, after_level, error) = parse_style_integer(line, next + 1, end)
  match error {
    Some(error) => return (None, after_level, true, Some(error))
    None => next = after_level
  }
  if next >= end || line[next] != ')' {
    return (
      None,
      next,
      true,
      Some(style_parse_error(line, next, end, "close-paren")),
    )
  }
  (Some({ is_ordered, level }), next + 1, true, None)
}

///|
fn parse_style_highlight_matcher(
  line : String,
  index : Int,
  end : Int,
) -> (DocumentMatcher?, Int, String?) {
  if index >= end || line[index] != '[' {
    return (Some(HighlightMatcher(None)), index, None)
  }
  let (name, first_index, error) = parse_style_identifier(
    line,
    index + 1,
    end,
    "identifier",
  )
  let mut index = first_index
  match error {
    Some(error) => return (None, index, Some(error))
    None => ()
  }
  if name != "color" {
    return (None, index, Some(style_parse_error(line, index, end, "equals")))
  }
  if index >= end || line[index] != '=' {
    return (None, index, Some(style_parse_error(line, index, end, "equals")))
  }
  let (color, next, error) = parse_style_string(line, index + 1, end)
  match error {
    Some(error) => return (None, next, Some(error))
    None => index = next
  }
  if index >= end || line[index] != ']' {
    return (
      None,
      index,
      Some(style_parse_error(line, index, end, "close-square-bracket")),
    )
  }
  (Some(HighlightMatcher(Some(color))), index + 1, None)
}

///|
fn parse_style_break_matcher(
  line : String,
  index : Int,
  end : Int,
) -> (DocumentMatcher?, Int, String?) {
  if index >= end || line[index] != '[' {
    return (
      None,
      index,
      Some(style_parse_error(line, index, end, "open-square-bracket")),
    )
  }
  let (name, first_index, error) = parse_style_identifier(
    line,
    index + 1,
    end,
    "identifier",
  )
  let mut index = first_index
  match error {
    Some(error) => return (None, index, Some(error))
    None => ()
  }
  if name != "type" {
    return (None, index, Some(style_parse_error(line, index, end, "equals")))
  }
  if index >= end || line[index] != '=' {
    return (None, index, Some(style_parse_error(line, index, end, "equals")))
  }
  let (break_type, next, error) = parse_style_string(line, index + 1, end)
  match error {
    Some(error) => return (None, next, Some(error))
    None => index = next
  }
  if index >= end || line[index] != ']' {
    return (
      None,
      index,
      Some(style_parse_error(line, index, end, "close-square-bracket")),
    )
  }
  (
    Some(
      BreakMatcher(
        match break_type {
          "page" => Page
          "column" => Column
          _ => Line
        },
      ),
    ),
    index + 1,
    None,
  )
}

///|
fn read_html_path(value : String) -> Array[HtmlPathElement] {
  let elements : Array[HtmlPathElement] = []
  if value == "" {
    return elements
  }
  for part in split_html_path_parts(value) {
    if part != "" {
      elements.push(read_html_path_element(part))
    }
  }
  elements
}

///|
fn validate_html_path_text(
  line : String,
  to_raw : String,
  after_arrow : Int,
) -> String? {
  let end = after_arrow + to_raw.length()
  if after_arrow >= end {
    return None
  }
  if !is_style_whitespace(line[after_arrow]) {
    return Some(style_parse_error(line, after_arrow, end, "end"))
  }
  let mut index = after_arrow
  while index < end && is_style_whitespace(line[index]) {
    index = index + 1
  }
  if index >= end {
    return None
  }
  let (index, error) = parse_style_html_path(line, index, end)
  match error {
    Some(error) => Some(error)
    None =>
      if index == end {
        None
      } else {
        Some(style_parse_error(line, index, end, "end"))
      }
  }
}

///|
fn parse_style_html_path(
  line : String,
  index : Int,
  end : Int,
) -> (Int, String?) {
  if line[index] == '!' {
    return (index + 1, None)
  }
  let (first_index, error) = parse_style_html_path_element(line, index, end)
  let mut index = first_index
  match error {
    Some(error) => return (index, Some(error))
    None => ()
  }
  while index < end {
    let separator_start = index
    let mut after_space = index
    while after_space < end && is_style_whitespace(line[after_space]) {
      after_space = after_space + 1
    }
    if after_space == index {
      return (index, None)
    }
    if after_space < end && line[after_space] == '>' {
      let mut next = after_space + 1
      if next < end && is_style_whitespace(line[next]) {
        while next < end && is_style_whitespace(line[next]) {
          next = next + 1
        }
        let (next_index, error) = parse_style_html_path_element(line, next, end)
        match error {
          Some(error) => return (next_index, Some(error))
          None => index = next_index
        }
      } else {
        return (separator_start, None)
      }
    } else {
      return (separator_start, None)
    }
  }
  (index, None)
}

///|
fn parse_style_html_path_element(
  line : String,
  index : Int,
  end : Int,
) -> (Int, String?) {
  let (_, first_index, error) = parse_style_tag_choices(line, index, end)
  let mut index = first_index
  match error {
    Some(error) => return (index, Some(error))
    None => ()
  }
  while index < end {
    if line[index] == '.' {
      let (_, next, error) = parse_style_identifier(
        line,
        index + 1,
        end,
        "identifier",
      )
      match error {
        Some(error) => return (next, Some(error))
        None => index = next
      }
    } else if line[index] == '[' {
      let (_, next, error) = parse_style_attribute(line, index + 1, end)
      match error {
        Some(error) => return (next, Some(error))
        None => index = next
      }
    } else {
      break
    }
  }
  let (next, consumed) = consume_style_option_identifier(
    line, index, end, "fresh",
  )
  if consumed {
    index = next
  }
  let (next, consumed, error) = consume_style_separator_option(line, index, end)
  match error {
    Some(error) => (next, Some(error))
    None => (if consumed { next } else { index }, None)
  }
}

///|
fn parse_style_tag_choices(
  line : String,
  index : Int,
  end : Int,
) -> (String, Int, String?) {
  let builder = StringBuilder()
  let (tag, first_index, error) = parse_style_identifier(
    line, index, end, "identifier",
  )
  let mut index = first_index
  match error {
    Some(error) => return ("", index, Some(error))
    None => builder.write_string(tag)
  }
  while index < end && line[index] == '|' {
    builder.write_string("|")
    let (tag, next, error) = parse_style_identifier(
      line,
      index + 1,
      end,
      "identifier",
    )
    match error {
      Some(error) => return (builder.to_string(), next, Some(error))
      None => {
        builder.write_string(tag)
        index = next
      }
    }
  }
  (builder.to_string(), index, None)
}

///|
fn is_style_whitespace(char : UInt16) -> Bool {
  char == ' ' || char == '\t' || char == '\n' || char == '\r'
}

///|
fn parse_style_attribute(
  line : String,
  index : Int,
  end : Int,
) -> (String, Int, String?) {
  let (name, first_index, error) = parse_style_identifier(
    line, index, end, "identifier",
  )
  let mut index = first_index
  match error {
    Some(error) => return ("", index, Some(error))
    None => ()
  }
  if index >= end || line[index] != '=' {
    return (name, index, Some(style_parse_error(line, index, end, "equals")))
  }
  index = index + 1
  let (_, next, error) = parse_style_string(line, index, end)
  match error {
    Some(error) => return (name, next, Some(error))
    None => index = next
  }
  if index >= end || line[index] != ']' {
    return (
      name,
      index,
      Some(style_parse_error(line, index, end, "close-square-bracket")),
    )
  }
  (name, index + 1, None)
}

///|
fn consume_style_option_identifier(
  line : String,
  index : Int,
  end : Int,
  expected : String,
) -> (Int, Bool) {
  if index >= end || line[index] != ':' {
    return (index, false)
  }
  let (name, next, error) = parse_style_identifier(
    line,
    index + 1,
    end,
    "identifier",
  )
  match error {
    Some(_) => (index, false)
    None => if name == expected { (next, true) } else { (index, false) }
  }
}

///|
fn consume_style_separator_option(
  line : String,
  index : Int,
  end : Int,
) -> (Int, Bool, String?) {
  let (next, consumed) = consume_style_option_identifier(
    line, index, end, "separator",
  )
  if !consumed {
    return (index, false, None)
  }
  if next >= end || line[next] != '(' {
    return (next, true, Some(style_parse_error(line, next, end, "open-paren")))
  }
  let (_, value_end, error) = parse_style_string(line, next + 1, end)
  match error {
    Some(error) => return (value_end, true, Some(error))
    None => ()
  }
  if value_end >= end || line[value_end] != ')' {
    return (
      value_end,
      true,
      Some(style_parse_error(line, value_end, end, "close-paren")),
    )
  }
  (value_end + 1, true, None)
}

///|
fn parse_style_identifier(
  line : String,
  index : Int,
  end : Int,
  expected : String,
) -> (String, Int, String?) {
  if !is_style_identifier_start(line, index, end) {
    return ("", index, Some(style_parse_error(line, index, end, expected)))
  }
  let builder = StringBuilder()
  let mut index = index
  while index < end {
    if line[index] == '\\' && index + 1 < end {
      builder.write_string(line[index + 1:index + 2].to_owned())
      index = index + 2
    } else if is_style_identifier_part(line[index]) {
      builder.write_string(line[index:index + 1].to_owned())
      index = index + 1
    } else {
      break
    }
  }
  (builder.to_string(), index, None)
}

///|
fn parse_style_string(
  line : String,
  index : Int,
  end : Int,
) -> (String, Int, String?) {
  if index >= end || line[index] != '\'' {
    return ("", index, Some(style_parse_error(line, index, end, "string")))
  }
  let builder = StringBuilder()
  let mut cursor = index + 1
  while cursor < end {
    if line[cursor] == '\\' && cursor + 1 < end {
      write_style_escape(builder, line, cursor + 1)
      cursor = cursor + 2
    } else if line[cursor] == '\'' {
      return (builder.to_string(), cursor + 1, None)
    } else {
      builder.write_string(line[cursor:cursor + 1].to_owned())
      cursor = cursor + 1
    }
  }
  (
    "",
    index,
    Some(
      "Error was at character number " +
      (index + 1).to_string() +
      ": Expected string but got unterminated-string \"" +
      builder.to_string() +
      "\"",
    ),
  )
}

///|
fn parse_style_integer(
  line : String,
  index : Int,
  end : Int,
) -> (Int, Int, String?) {
  if index >= end || line[index] < '0' || line[index] > '9' {
    return (0, index, Some(style_parse_error(line, index, end, "integer")))
  }
  let value_text = read_style_integer_token(line, index, end)
  let next = index + value_text.length()
  let value = @string.parse_int(value_text) catch { _ => 0 }
  (value, next, None)
}

///|
fn starts_with_at(
  line : String,
  index : Int,
  end : Int,
  value : String,
) -> Bool {
  index + value.length() <= end &&
  line[index:index + value.length()].to_owned() == value
}

///|
fn is_style_identifier_start(line : String, index : Int, end : Int) -> Bool {
  if index >= end {
    false
  } else if line[index] == '\\' {
    index + 1 < end
  } else {
    is_style_identifier_start_char(line[index])
  }
}

///|
fn is_style_identifier_start_char(char : UInt16) -> Bool {
  (char >= 'a' && char <= 'z') ||
  (char >= 'A' && char <= 'Z') ||
  char == '-' ||
  char == '_'
}

///|
fn is_style_identifier_part(char : UInt16) -> Bool {
  is_style_identifier_start_char(char) || (char >= '0' && char <= '9')
}

///|
fn style_parse_error(
  line : String,
  index : Int,
  end : Int,
  expected : String,
) -> String {
  "Error was at character number " +
  (index + 1).to_string() +
  ": Expected " +
  expected +
  " but got " +
  describe_style_token(line, index, end)
}

///|
fn describe_style_token(line : String, index : Int, end : Int) -> String {
  if index >= end {
    return "end"
  }
  if starts_with_at(line, index, end, "=>") {
    return "arrow"
  }
  if starts_with_at(line, index, end, "^=") {
    return "startsWith"
  }
  match line[index] {
    ' ' | '\t' | '\n' | '\r' => "whitespace"
    '=' => "equals"
    '>' => "gt"
    ':' => "colon"
    '.' => "dot"
    '[' => "open-square-bracket"
    ']' => "close-square-bracket"
    '(' => "open-paren"
    ')' => "close-paren"
    '|' => "choice"
    '!' => "bang"
    '\'' => describe_unterminated_style_string(line, index, end)
    _ =>
      if is_style_identifier_start(line, index, end) {
        let (identifier, _, _) = parse_style_identifier(
          line, index, end, "identifier",
        )
        "identifier \"" + identifier + "\""
      } else if line[index] >= '0' && line[index] <= '9' {
        "integer \"" + read_style_integer_token(line, index, end) + "\""
      } else {
        "unrecognisedCharacter \"" + line[index:index + 1].to_owned() + "\""
      }
  }
}

///|
fn describe_unterminated_style_string(
  line : String,
  index : Int,
  end : Int,
) -> String {
  let builder = StringBuilder()
  let mut cursor = index + 1
  while cursor < end {
    if line[cursor] == '\\' && cursor + 1 < end {
      builder.write_string(line[cursor + 1:cursor + 2].to_owned())
      cursor = cursor + 2
    } else {
      builder.write_string(line[cursor:cursor + 1].to_owned())
      cursor = cursor + 1
    }
  }
  "unterminated-string \"" + builder.to_string() + "\""
}

///|
fn read_style_integer_token(line : String, index : Int, end : Int) -> String {
  let mut cursor = index
  while cursor < end && line[cursor] >= '0' && line[cursor] <= '9' {
    cursor = cursor + 1
  }
  line[index:cursor].to_owned()
}

///|
fn read_html_path_element(value : String) -> HtmlPathElement {
  let (element_text, options_text) = split_html_path_options(value)
  let tag_choices = read_html_tag_choices(element_text)
  let tag = decode_style_escapes(tag_choices)
  let fresh = options_text.contains("fresh")
  let separator = read_html_path_separator(options_text)
  let attributes = read_html_path_attributes(element_text)
  { tag, attributes, fresh, separator }
}

///|
fn read_html_path_separator(options_text : String) -> String? {
  let marker = "separator('"
  match options_text.find(marker) {
    Some(start) =>
      read_style_string_value(options_text, start + marker.length())
    None => None
  }
}

///|
fn read_style_string_value(value : String, start : Int) -> String? {
  let builder = StringBuilder()
  let mut index = start
  while index < value.length() {
    let char = value[index]
    if char == '\\' && index + 1 < value.length() {
      write_style_escape(builder, value, index + 1)
      index = index + 2
    } else if char == '\'' {
      return Some(builder.to_string())
    } else {
      builder.write_string(value[index:index + 1].to_owned())
      index = index + 1
    }
  }
  None
}

///|
fn write_style_escape(
  builder : StringBuilder,
  value : String,
  index : Int,
) -> Unit {
  let char = value[index]
  match char {
    'n' => builder.write_string("\n")
    'r' => builder.write_string("\r")
    't' => builder.write_string("\t")
    _ => builder.write_string(value[index:index + 1].to_owned())
  }
}

///|
fn split_html_path_options(value : String) -> (String, String) {
  match find_unescaped_char_outside_style_string(value, ':') {
    Some(index) =>
      (value[:index].trim().to_owned(), value[index + 1:].trim().to_owned())
    None => (value.trim().to_owned(), "")
  }
}

///|
fn split_html_path_parts(value : String) -> Array[String] {
  let parts : Array[String] = []
  let mut start = 0
  let mut index = 0
  let mut in_string = false
  while index < value.length() {
    let char = value[index]
    if char == '\\' {
      index = index + 2
    } else if char == '\'' {
      in_string = !in_string
      index = index + 1
    } else if !in_string && char == '>' {
      let part = value[start:index].trim().to_owned()
      if part != "" {
        parts.push(part)
      }
      start = index + 1
      index = index + 1
    } else {
      index = index + 1
    }
  }
  let part = value[start:].trim().to_owned()
  if part != "" {
    parts.push(part)
  }
  parts
}

///|
fn read_html_tag_choices(value : String) -> String {
  let mut index = 0
  while index < value.length() {
    let char = value[index]
    if char == '\\' {
      index = index + 2
    } else if char == '.' || char == '[' {
      return value[:index].to_owned()
    } else {
      index = index + 1
    }
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
      let name = decode_style_escapes(
        value[start:start + equals_index].to_owned(),
      )
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
fn find_unescaped_char_outside_style_string(
  value : String,
  needle : UInt16,
) -> Int? {
  let mut index = 0
  let mut in_string = false
  while index < value.length() {
    if value[index] == '\\' {
      index = index + 2
    } else if value[index] == '\'' {
      in_string = !in_string
      index = index + 1
    } else if !in_string && value[index] == needle {
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
    "p:unordered-list(2) => ul|ol > li > ul > li:fresh", "p:unordered-list(3) => ul|ol > li > ul|ol > li > ul > li:fresh",
    "p:unordered-list(4) => ul|ol > li > ul|ol > li > ul|ol > li > ul > li:fresh",
    "p:unordered-list(5) => ul|ol > li > ul|ol > li > ul|ol > li > ul|ol > li > ul > li:fresh",
    "p:ordered-list(1) => ol > li:fresh", "p:ordered-list(2) => ul|ol > li > ol > li:fresh",
    "p:ordered-list(3) => ul|ol > li > ul|ol > li > ol > li:fresh", "p:ordered-list(4) => ul|ol > li > ul|ol > li > ul|ol > li > ol > li:fresh",
    "p:ordered-list(5) => ul|ol > li > ul|ol > li > ul|ol > li > ul|ol > li > ol > li:fresh",
    "r[style-name='Hyperlink'] =>", "p[style-name='Normal'] => p:fresh", "p.Body => p:fresh",
    "p[style-name='Body'] => p:fresh",
  ]
}

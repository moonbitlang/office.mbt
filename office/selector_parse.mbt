///|
/// Maximum canonical selector length in Unicode scalar values.
pub const SELECTOR_MAX_LENGTH : Int = 2048

///|
/// Maximum number of segments after the format root.
pub const SELECTOR_MAX_DEPTH : Int = 32

///|
/// Maximum number of bracketed selectors, including an XLSX coordinate leaf.
pub const SELECTOR_MAX_SELECTIONS : Int = 32

///|
/// Maximum segment or key name length.
pub const SELECTOR_MAX_NAME_LENGTH : Int = 32

///|
/// Maximum decoded named-selector value length in Unicode scalar values.
pub const SELECTOR_MAX_VALUE_LENGTH : Int = 256

///|
let selector_max_echo_length = 160

///|
let selector_max_message_length = 320

///|
let selector_max_index_digits = 9

///|
let selector_max_column = 16384

///|
let selector_max_row = 1048576

///|
priv enum ParsedSelectorSegment {
  Regular(SelectorSegment)
  Coordinate(SelectorCoordinate)
}

///|
priv enum SelectorUnicodeScan {
  Valid
  TooLong
  Invalid(Int)
}

///|
priv struct SelectorParser {
  source : String
  chars : Array[Char]
  mut position : Int
  mut selection_count : Int
}

///|
fn scan_selector_unicode(text : String, limit : Int) -> SelectorUnicodeScan {
  let unit_length = text.length()
  let mut unit_offset = 0
  let mut scalar_offset = 0
  while unit_offset < unit_length {
    let unit = text[unit_offset]
    if unit.is_leading_surrogate() {
      if unit_offset + 1 >= unit_length ||
        !text[unit_offset + 1].is_trailing_surrogate() {
        return Invalid(scalar_offset)
      }
      unit_offset = unit_offset + 2
    } else if unit.is_trailing_surrogate() {
      return Invalid(scalar_offset)
    } else {
      unit_offset = unit_offset + 1
    }
    scalar_offset = scalar_offset + 1
    if scalar_offset > limit {
      return TooLong
    }
  }
  Valid
}

///|
fn bounded_selector_text(text : String, limit : Int) -> String {
  let output = StringBuilder::new()
  let mut length = 0
  let mut truncated = false
  for character in text {
    if length == limit {
      truncated = true
      break
    }
    output.write_char(character) |> ignore
    length = length + 1
  }
  if truncated {
    output.write_char('…') |> ignore
  }
  output.to_string()
}

///|
fn SelectorParser::new(source : String) -> SelectorParser {
  { source, chars: source.to_array(), position: 0, selection_count: 0 }
}

///|
fn SelectorParser::at_end(self : SelectorParser) -> Bool {
  self.position >= self.chars.length()
}

///|
fn SelectorParser::peek(self : SelectorParser) -> Char? {
  if self.at_end() {
    None
  } else {
    Some(self.chars[self.position])
  }
}

///|
fn SelectorParser::advance(self : SelectorParser) -> Char? {
  let value = self.peek()
  if value is Some(_) {
    self.position = self.position + 1
  }
  value
}

///|
fn SelectorParser::fail_at(
  self : SelectorParser,
  code : String,
  offset : Int,
  message : String,
) -> SelectorError {
  SelectorError(
    code~,
    offset~,
    input=bounded_selector_text(self.source, selector_max_echo_length),
    message=bounded_selector_text(message, selector_max_message_length),
  )
}

///|
fn SelectorParser::fail(
  self : SelectorParser,
  code : String,
  message : String,
) -> SelectorError {
  self.fail_at(code, self.position, message)
}

///|
fn SelectorParser::expect(
  self : SelectorParser,
  expected : Char,
  code : String,
  message : String,
) -> Unit raise SelectorError {
  match self.peek() {
    Some(actual) if actual == expected => self.advance() |> ignore
    _ => raise self.fail(code, message)
  }
}

///|
fn selector_name_start(character : Char) -> Bool {
  character is ('a'..='z')
}

///|
fn selector_name_continue(character : Char) -> Bool {
  selector_name_start(character) ||
  character.is_ascii_digit() ||
  character == '-' ||
  character == '_'
}

///|
fn SelectorParser::parse_name(
  self : SelectorParser,
  role : String,
) -> String raise SelectorError {
  let start = self.position
  guard self.peek() is Some(first) && selector_name_start(first) else {
    raise self.fail(
      "office.selector.invalid_name",
      "expected a lowercase ASCII \{role} name",
    )
  }
  self.advance() |> ignore
  while self.peek() is Some(character) && selector_name_continue(character) {
    self.advance() |> ignore
  }
  let length = self.position - start
  if length > SELECTOR_MAX_NAME_LENGTH {
    raise self.fail_at(
      "office.selector.name_too_long",
      start,
      "\{role} name exceeds \{SELECTOR_MAX_NAME_LENGTH} characters",
    )
  }
  let output = StringBuilder::new()
  for index in start..<self.position {
    output.write_char(self.chars[index]) |> ignore
  }
  output.to_string()
}

///|
fn SelectorParser::count_selection(
  self : SelectorParser,
) -> Unit raise SelectorError {
  self.selection_count = self.selection_count + 1
  if self.selection_count > SELECTOR_MAX_SELECTIONS {
    raise self.fail(
      "office.selector.selection_limit",
      "selector has more than \{SELECTOR_MAX_SELECTIONS} bracketed selections",
    )
  }
}

///|
fn SelectorParser::parse_positive_index(
  self : SelectorParser,
  start : Int,
) -> Int raise SelectorError {
  let mut value = 0
  let mut digits = 0
  while self.peek() is Some(character) && character.is_ascii_digit() {
    digits = digits + 1
    if digits > selector_max_index_digits {
      raise self.fail_at(
        "office.selector.index_overflow",
        start,
        "positional index exceeds \{selector_max_index_digits} digits",
      )
    }
    value = value * 10 + (character.to_int() - '0'.to_int())
    self.advance() |> ignore
  }
  if digits == 0 {
    raise self.fail_at(
      "office.selector.invalid_index", start, "expected a positive positional index",
    )
  }
  if value == 0 {
    raise self.fail_at(
      "office.selector.zero_index", start, "positional selectors are 1-based",
    )
  }
  value
}

///|
fn SelectorParser::parse_json_string(
  self : SelectorParser,
) -> String raise SelectorError {
  let start = self.position
  guard self.peek() == Some('"') else {
    raise self.fail(
      "office.selector.unsupported_predicate", "named selectors require a JSON string value",
    )
  }
  let raw = StringBuilder::new()
  raw.write_char('"') |> ignore
  self.advance() |> ignore
  let mut closed = false
  while !self.at_end() {
    guard self.advance() is Some(character) else { break }
    raw.write_char(character) |> ignore
    if character == '\\' {
      guard self.advance() is Some(escaped) else {
        raise self.fail_at(
          "office.selector.invalid_string", start, "unterminated JSON escape in named selector",
        )
      }
      raw.write_char(escaped) |> ignore
    } else if character == '"' {
      closed = true
      break
    }
  }
  if !closed {
    raise self.fail_at(
      "office.selector.unclosed_string", start, "unterminated JSON string in named selector",
    )
  }
  let decoded = @json.parse(raw.to_string()) catch {
    _ =>
      raise self.fail_at(
        "office.selector.invalid_string", start, "invalid JSON string escape in named selector",
      )
  }
  guard decoded is String(value) else {
    raise self.fail_at(
      "office.selector.invalid_string", start, "named selector value must be a JSON string",
    )
  }
  match scan_selector_unicode(value, SELECTOR_MAX_VALUE_LENGTH) {
    Invalid(_) =>
      raise self.fail_at(
        "office.selector.invalid_string", start, "named selector value contains an isolated UTF-16 surrogate",
      )
    TooLong =>
      raise self.fail_at(
        "office.selector.value_too_long",
        start,
        "named selector value exceeds \{SELECTOR_MAX_VALUE_LENGTH} characters",
      )
    Valid => ()
  }
  if value == "" {
    raise self.fail_at(
      "office.selector.empty_value", start, "named selector values cannot be empty",
    )
  }
  value
}

///|
fn SelectorParser::parse_regular_selection(
  self : SelectorParser,
) -> SegmentSelection raise SelectorError {
  self.expect(
    '[', "office.selector.invalid_selection", "expected '[' to start a segment selection",
  )
  self.count_selection()
  let selection_start = self.position
  let selection = if self.peek() is Some(character) &&
    character.is_ascii_digit() {
    Position(self.parse_positive_index(selection_start))
  } else if self.peek() is Some(character) && selector_name_start(character) {
    let key = self.parse_name("selector key")
    self.expect(
      '=', "office.selector.unsupported_predicate", "only key=\"value\" named selectors are supported",
    )
    Key(key, self.parse_json_string())
  } else {
    raise self.fail(
      "office.selector.unsupported_predicate", "expected a positive index or key=\"value\" selection",
    )
  }
  self.expect(
    ']', "office.selector.unclosed_selection", "expected ']' after segment selection",
  )
  selection
}

///|
fn SelectorParser::parse_coordinate_token(
  self : SelectorParser,
) -> (String, Int) raise SelectorError {
  self.expect(
    '[', "office.selector.invalid_coordinate", "expected '[' before XLSX coordinate",
  )
  self.count_selection()
  let start = self.position
  let value = StringBuilder::new()
  while self.peek() is Some(character) && character != ']' {
    if character == '[' || character == '/' || character == '"' {
      raise self.fail(
        "office.selector.invalid_coordinate", "XLSX coordinates contain only A1 letters, digits, and ':'",
      )
    }
    value.write_char(character) |> ignore
    self.advance() |> ignore
  }
  if self.at_end() {
    raise self.fail_at(
      "office.selector.unclosed_selection", start, "expected ']' after XLSX coordinate",
    )
  }
  self.advance() |> ignore
  (value.to_string(), start)
}

///|
fn parse_a1_address(
  parser : SelectorParser,
  value : String,
  offset : Int,
) -> CellAddress raise SelectorError {
  let chars = value.to_array()
  let mut split = 0
  while split < chars.length() &&
        (chars[split] is ('A'..='Z') || chars[split] is ('a'..='z')) {
    split = split + 1
  }
  if split == 0 || split == chars.length() || split > 3 {
    raise parser.fail_at(
      "office.selector.invalid_coordinate",
      offset,
      "invalid A1 coordinate '\{bounded_selector_text(value, 32)}'",
    )
  }
  let mut column = 0
  for index in 0..<split {
    let character = chars[index].to_ascii_uppercase()
    column = column * 26 + (character.to_int() - 'A'.to_int() + 1)
  }
  if column < 1 || column > selector_max_column {
    raise parser.fail_at(
      "office.selector.invalid_coordinate", offset, "A1 column is outside A:XFD",
    )
  }
  if chars[split] == '0' {
    raise parser.fail_at(
      "office.selector.invalid_coordinate",
      offset + split,
      "A1 rows are 1-based and cannot have leading zeroes",
    )
  }
  let mut row = 0
  for index in split..<chars.length() {
    let character = chars[index]
    if !character.is_ascii_digit() {
      raise parser.fail_at(
        "office.selector.invalid_coordinate",
        offset + index,
        "invalid character in A1 row",
      )
    }
    row = row * 10 + (character.to_int() - '0'.to_int())
    if row > selector_max_row {
      raise parser.fail_at(
        "office.selector.invalid_coordinate",
        offset + split,
        "A1 row is outside 1:\{selector_max_row}",
      )
    }
  }
  { column, row }
}

///|
fn parse_xlsx_coordinate(
  parser : SelectorParser,
  name : String,
) -> SelectorCoordinate raise SelectorError {
  let (token, offset) = parser.parse_coordinate_token()
  if name == "cell" {
    if token.contains(":") {
      raise parser.fail_at(
        "office.selector.invalid_coordinate", offset, "cell selectors accept exactly one A1 coordinate",
      )
    }
    return Cell(parse_a1_address(parser, token, offset))
  }
  let parts = token.split(":").map(part => part.to_owned()).collect()
  if parts.length() != 2 || parts[0] == "" || parts[1] == "" {
    raise parser.fail_at(
      "office.selector.invalid_coordinate", offset, "range selectors require two A1 coordinates separated by ':'",
    )
  }
  let second_offset = offset + parts[0].to_array().length() + 1
  let first = parse_a1_address(parser, parts[0], offset)
  let second = parse_a1_address(parser, parts[1], second_offset)
  let start : CellAddress = {
    column: first.column.min(second.column),
    row: first.row.min(second.row),
  }
  let finish : CellAddress = {
    column: first.column.max(second.column),
    row: first.row.max(second.row),
  }
  Range(start, finish)
}

///|
fn SelectorParser::parse_segment(
  self : SelectorParser,
  format : DocumentFormat,
) -> ParsedSelectorSegment raise SelectorError {
  let name = self.parse_name("segment")
  if format == Xlsx && (name == "cell" || name == "range") {
    if self.peek() != Some('[') {
      raise self.fail(
        "office.selector.invalid_coordinate",
        "XLSX \{name} leaves require a bracketed A1 coordinate",
      )
    }
    return Coordinate(parse_xlsx_coordinate(self, name))
  }
  let selection = if self.peek() == Some('[') {
    Some(self.parse_regular_selection())
  } else {
    None
  }
  Regular({ name, selection })
}

///|
fn validate_docx_selector(
  parser : SelectorParser,
  segments : Array[SelectorSegment],
  coordinate : SelectorCoordinate?,
) -> SelectorStability raise SelectorError {
  if coordinate is Some(_) {
    raise parser.fail(
      "office.selector.format_mismatch", "DOCX selectors cannot contain XLSX coordinate leaves",
    )
  }
  guard segments.get(0) is Some(story) else {
    raise parser.fail(
      "office.selector.invalid_shape", "DOCX selectors require a story root such as body or header[1]",
    )
  }
  match story.name {
    "body" | "footnotes" | "endnotes" | "comments" =>
      if story.selection is Some(_) {
        raise parser.fail_at(
          "office.selector.invalid_shape",
          6,
          "DOCX story '\{story.name}' does not take a selector",
        )
      }
    "header" | "footer" =>
      if !(story.selection is Some(Position(_))) {
        raise parser.fail_at(
          "office.selector.invalid_shape",
          6,
          "DOCX story '\{story.name}' requires a 1-based positional selector",
        )
      }
    _ =>
      raise parser.fail_at(
        "office.selector.invalid_shape",
        6,
        "unknown DOCX story '\{story.name}'",
      )
  }
  let mut stability = Stable
  for index, segment in segments {
    if index > 0 && segment.selection is None {
      raise parser.fail(
        "office.selector.invalid_shape",
        "DOCX descendant '\{segment.name}' requires [index] or [id=\"value\"]",
      )
    }
    match segment.selection {
      Some(Position(_)) => stability = SnapshotRelative
      Some(Key(key, _)) if key != "id" =>
        raise parser.fail(
          "office.selector.unsupported_predicate",
          "DOCX named selectors use the 'id' key, not '\{key}'",
        )
      _ => ()
    }
  }
  stability
}

///|
fn validate_xlsx_selector(
  parser : SelectorParser,
  segments : Array[SelectorSegment],
  coordinate : SelectorCoordinate?,
) -> SelectorStability raise SelectorError {
  if segments.length() == 1 && segments[0].name == "workbook" {
    if segments[0].selection is Some(_) || coordinate is Some(_) {
      raise parser.fail(
        "office.selector.invalid_shape", "XLSX workbook is a singleton and cannot take a selection or coordinate leaf",
      )
    }
    return Stable
  }
  if segments.length() != 1 || segments[0].name != "sheet" {
    raise parser.fail(
      "office.selector.invalid_shape", "XLSX selectors require workbook or exactly one sheet segment before an optional cell/range leaf",
    )
  }
  match segments[0].selection {
    Some(Position(_)) => SnapshotRelative
    Some(Key("name", _)) if coordinate is None => Stable
    Some(Key("name", _)) => SnapshotRelative
    Some(Key(key, _)) =>
      raise parser.fail(
        "office.selector.unsupported_predicate",
        "XLSX sheet selectors use the 'name' key, not '\{key}'",
      )
    None =>
      raise parser.fail(
        "office.selector.invalid_shape", "XLSX sheet requires [index] or [name=\"value\"]",
      )
  }
}

///|
/// Parses and validates one bounded, format-explicit `office.selector/1`
/// address. The returned AST is the adapter boundary for later resolvers.
pub fn parse_selector(source : String) -> OfficeSelector raise SelectorError {
  match scan_selector_unicode(source, SELECTOR_MAX_LENGTH) {
    Invalid(offset) =>
      raise SelectorError(
        code="office.selector.invalid_unicode",
        offset~,
        input="<invalid UTF-16>",
        message="selector contains an isolated UTF-16 surrogate",
      )
    TooLong =>
      raise SelectorError(
        code="office.selector.too_long",
        offset=SELECTOR_MAX_LENGTH,
        input=bounded_selector_text(source, selector_max_echo_length),
        message="selector exceeds \{SELECTOR_MAX_LENGTH} characters",
      )
    Valid => ()
  }
  let parser = SelectorParser::new(source)
  parser.expect(
    '/', "office.selector.invalid_root", "selector must start with '/docx/' or '/xlsx/'",
  )
  let format_offset = parser.position
  let format_name = parser.parse_name("format")
  let format = match format_name {
    "docx" => Docx
    "xlsx" => Xlsx
    _ =>
      raise parser.fail_at(
        "office.selector.invalid_format",
        format_offset,
        "unsupported selector format '\{format_name}' (expected docx or xlsx)",
      )
  }
  parser.expect(
    '/', "office.selector.invalid_root", "format root must be followed by '/' and a segment",
  )
  if parser.at_end() || parser.peek() == Some('/') {
    raise parser.fail(
      "office.selector.empty_segment", "selector contains an empty segment",
    )
  }
  let segments : Array[SelectorSegment] = []
  let mut coordinate : SelectorCoordinate? = None
  let mut depth = 0
  while !parser.at_end() {
    let start = parser.position
    depth = depth + 1
    if depth > SELECTOR_MAX_DEPTH {
      raise parser.fail_at(
        "office.selector.depth_limit",
        start,
        "selector exceeds \{SELECTOR_MAX_DEPTH} segments",
      )
    }
    match parser.parse_segment(format) {
      Regular(segment) => {
        if coordinate is Some(_) {
          raise parser.fail_at(
            "office.selector.invalid_shape", start, "XLSX coordinate leaves must be final",
          )
        }
        segments.push(segment)
      }
      Coordinate(value) => {
        if coordinate is Some(_) {
          raise parser.fail_at(
            "office.selector.invalid_shape", start, "selector contains more than one coordinate leaf",
          )
        }
        coordinate = Some(value)
      }
    }
    if parser.at_end() {
      break
    }
    parser.expect(
      '/', "office.selector.unexpected_character", "expected '/' between selector segments",
    )
    if parser.at_end() || parser.peek() == Some('/') {
      raise parser.fail(
        "office.selector.empty_segment", "selector contains an empty segment",
      )
    }
  }
  let stability = match format {
    Docx => validate_docx_selector(parser, segments, coordinate)
    Xlsx => validate_xlsx_selector(parser, segments, coordinate)
  }
  {
    format,
    segments: ReadOnlyArray::from_array(segments),
    coordinate,
    stability,
  }
}

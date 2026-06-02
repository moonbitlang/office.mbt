///|
pub type StyleNameMatcher = @style_map.StyleNameMatcher

///|
pub type DocumentMatcher = @style_map.DocumentMatcher

///|
pub type HtmlPathElement = @style_map.HtmlPathElement

///|
pub type StyleMapping = @style_map.StyleMapping

///|
pub type StyleMapParseResult = @style_map.StyleMapParseResult

///|
pub fn read_style_mapping(line : String) -> StyleMapping? {
  @style_map.read_style_mapping(line)
}

///|
pub fn read_style_map(lines : Array[String]) -> Array[StyleMapping] {
  @style_map.read_style_map(lines)
}

///|
pub fn parse_style_map(lines : Array[String]) -> StyleMapParseResult {
  @style_map.parse_style_map(lines)
}

///|
pub fn read_style_map_string(style_map : String) -> Array[String] {
  @style_map.read_style_map_string(style_map)
}

///|
pub fn parse_style_map_string(style_map : String) -> StyleMapParseResult {
  @style_map.parse_style_map_string(style_map)
}

///|
pub fn default_style_map_lines() -> Array[String] {
  @style_map.default_style_map_lines()
}

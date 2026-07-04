///|
/// Matcher for style names in style-map rules.
pub type StyleNameMatcher = @style_map.StyleNameMatcher

///|
/// Matcher for document elements in style-map rules.
pub type DocumentMatcher = @style_map.DocumentMatcher

///|
/// One element in a parsed style-map HTML path.
pub type HtmlPathElement = @style_map.HtmlPathElement

///|
/// Parsed mapping from a document matcher to an HTML path.
pub type StyleMapping = @style_map.StyleMapping

///|
/// Parsed style mappings together with style-map diagnostics.
pub type StyleMapParseResult = @style_map.StyleMapParseResult

///|
/// Parses one style-map line into a mapping, if valid.
pub fn read_style_mapping(line : String) -> StyleMapping? {
  @style_map.read_style_mapping(line)
}

///|
/// Parses style-map lines and returns valid mappings.
pub fn read_style_map(lines : Array[String]) -> Array[StyleMapping] {
  @style_map.read_style_map(lines)
}

///|
/// Parses style-map lines and preserves diagnostics.
pub fn parse_style_map(lines : Array[String]) -> StyleMapParseResult {
  @style_map.parse_style_map(lines)
}

///|
/// Splits a style-map string into meaningful lines.
pub fn read_style_map_string(style_map : String) -> Array[String] {
  @style_map.read_style_map_string(style_map)
}

///|
/// Parses a style-map string and preserves diagnostics.
pub fn parse_style_map_string(style_map : String) -> StyleMapParseResult {
  @style_map.parse_style_map_string(style_map)
}

///|
/// Returns Mammoth-compatible default style-map lines.
pub fn default_style_map_lines() -> Array[String] {
  @style_map.default_style_map_lines()
}

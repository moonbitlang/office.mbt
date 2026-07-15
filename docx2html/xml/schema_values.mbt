///|
/// Applies the XML Schema `whiteSpace=collapse` facet: XML whitespace runs
/// become one ASCII space, and leading/trailing runs are removed.
pub fn collapse_xml_schema_whitespace(value : StringView) -> String {
  let output = StringBuilder::new(size_hint=value.length())
  let mut wrote_value = false
  let mut pending_space = false
  for character in value {
    let whitespace = character == ' ' ||
      character == '\t' ||
      character == '\n' ||
      character == '\r'
    if whitespace {
      if wrote_value {
        pending_space = true
      }
    } else {
      if pending_space {
        output.write_char(' ') |> ignore
        pending_space = false
      }
      output.write_char(character) |> ignore
      wrote_value = true
    }
  }
  output.to_string()
}

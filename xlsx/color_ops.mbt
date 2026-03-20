///|
let indexed_color_mapping : Array[String] = [
  "000000", "FFFFFF", "FF0000", "00FF00", "0000FF", "FFFF00", "FF00FF", "00FFFF",
  "000000", "FFFFFF", "FF0000", "00FF00", "0000FF", "FFFF00", "FF00FF", "00FFFF",
  "800000", "008000", "000080", "808000", "800080", "008080", "C0C0C0", "808080",
  "9999FF", "993366", "FFFFCC", "CCFFFF", "660066", "FF8080", "0066CC", "CCCCFF",
  "000080", "FF00FF", "FFFF00", "00FFFF", "800080", "800000", "008080", "0000FF",
  "00CCFF", "CCFFFF", "CCFFCC", "FFFF99", "99CCFF", "FF99CC", "CC99FF", "FFCC99",
  "3366FF", "33CCCC", "99CC00", "FFCC00", "FF9900", "FF6600", "666699", "969696",
  "003366", "339966", "003300", "333300", "993300", "993366", "333399", "333333",
  "000000", "FFFFFF",
]

///|
let default_theme_colors : Array[String] = [
  "FFFFFF", "000000", "EEECE1", "1F497D", "4F81BD", "C0504D", "9BBB59", "8064A2",
  "4BACC6", "F79646",
]

///|
fn normalize_rgb_hex(value : StringView) -> String {
  let text = value.to_string()
  if text.length() == 8 && text.has_prefix("FF") {
    let view = text[2:]
    view.to_string()
  } else {
    text
  }
}

///|
pub fn Workbook::get_base_color(
  self : Workbook,
  hex_color : String,
  indexed_color : Int,
  theme_color? : Int,
) -> String {
  let theme_colors = match self.theme_colors {
    Some(colors) => colors
    None => default_theme_colors
  }
  match theme_color {
    Some(value) =>
      if value >= 0 && value < theme_colors.length() {
        return theme_colors[value]
      }
    None => ()
  }
  let normalized_hex = normalize_rgb_hex(hex_color)
  if normalized_hex.length() == 6 {
    return normalized_hex
  }
  match self.indexed_colors {
    Some(colors) =>
      if indexed_color >= 0 && indexed_color < colors.length() {
        return colors[indexed_color]
      }
    None => ()
  }
  if indexed_color >= 0 && indexed_color < indexed_color_mapping.length() {
    return indexed_color_mapping[indexed_color]
  }
  normalized_hex
}

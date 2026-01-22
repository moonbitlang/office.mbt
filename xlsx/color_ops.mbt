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
pub fn Workbook::get_base_color(
  self : Workbook,
  hex_color : String,
  indexed_color : Int,
  theme_color? : Int,
) -> String {
  ignore(self)
  match theme_color {
    Some(value) =>
      if value >= 0 && value < default_theme_colors.length() {
        return default_theme_colors[value]
      }
    None => ()
  }
  if hex_color.length() == 6 {
    return hex_color
  }
  if hex_color.length() == 8 {
    if hex_color.has_prefix("FF") {
      let view = hex_color[2:] catch { _ => return hex_color }
      return view.to_string()
    }
    return hex_color
  }
  if indexed_color >= 0 && indexed_color < indexed_color_mapping.length() {
    return indexed_color_mapping[indexed_color]
  }
  hex_color
}

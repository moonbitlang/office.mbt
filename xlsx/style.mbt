///|
/// Number format specification for cell values.
///
/// Excel supports both built-in formats (by index) and custom format strings.
///
/// # Built-in Format IDs
/// - 0: General
/// - 1: 0
/// - 2: 0.00
/// - 3: #,##0
/// - 4: #,##0.00
/// - 9: 0%
/// - 10: 0.00%
/// - 11: 0.00E+00
/// - 12: # ?/?
/// - 13: # ??/??
/// - 14: mm-dd-yy
/// - 15: d-mmm-yy
/// - 16: d-mmm
/// - 17: mmm-yy
/// - 18: h:mm AM/PM
/// - 19: h:mm:ss AM/PM
/// - 20: h:mm
/// - 21: h:mm:ss
/// - 22: m/d/yy h:mm
pub enum NumberFormat {
  Builtin(Int)
  Custom(String)
} derive(Eq, Show)

///|
/// Font styling for cell text.
///
/// All fields are optional; only set fields affect the cell's appearance.
///
/// # Example
/// ```mbt nocheck
/// let font = Font::with_values(
///   bold=true,
///   size=12.0,
///   color="FF0000",  // Red
///   underline="single",
/// )
/// ```
pub struct Font {
  mut bold : Bool?
  mut italic : Bool?
  mut strike : Bool?
  mut outline : Bool?
  mut shadow : Bool?
  mut condense : Bool?
  mut extend : Bool?
  mut underline : String?
  mut size : Double?
  mut color : String?
  mut color_theme : Int?
  mut color_indexed : Int?
  mut color_tint : Double?
  mut charset : Int?
  mut family_number : Int?
  mut scheme : String?
  mut vert_align : String?
  mut family : String?
} derive(Eq, Show)

///|
/// Creates a new Font with all fields set to None (default styling).
pub fn Font::new() -> Font {
  {
    bold: None,
    italic: None,
    strike: None,
    outline: None,
    shadow: None,
    condense: None,
    extend: None,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
}

///|
/// Creates a new Font with specified values.
///
/// # Parameters
/// - `bold`: Bold text
/// - `italic`: Italic text
/// - `strike`: Strikethrough
/// - `underline`: Underline style ("single", "double", "singleAccounting", "doubleAccounting")
/// - `size`: Font size in points
/// - `color`: Hex color code like "FF0000" for red
/// - `color_theme`: Theme color index (0-9)
/// - `color_tint`: Tint value for theme color (-1.0 to 1.0)
/// - `vert_align`: Vertical alignment ("superscript", "subscript")
/// - `family`: Font family name
pub fn Font::with_values(
  bold? : Bool,
  italic? : Bool,
  strike? : Bool,
  outline? : Bool,
  shadow? : Bool,
  condense? : Bool,
  extend? : Bool,
  underline? : String,
  size? : Double,
  color? : String,
  color_theme? : Int,
  color_indexed? : Int,
  color_tint? : Double,
  charset? : Int,
  family_number? : Int,
  scheme? : String,
  vert_align? : String,
  family? : String,
) -> Font {
  let font = Font::new()
  match bold {
    Some(v) => font.bold = Some(v)
    None => ()
  }
  match italic {
    Some(v) => font.italic = Some(v)
    None => ()
  }
  match strike {
    Some(v) => font.strike = Some(v)
    None => ()
  }
  match outline {
    Some(v) => font.outline = Some(v)
    None => ()
  }
  match shadow {
    Some(v) => font.shadow = Some(v)
    None => ()
  }
  match condense {
    Some(v) => font.condense = Some(v)
    None => ()
  }
  match extend {
    Some(v) => font.extend = Some(v)
    None => ()
  }
  match underline {
    Some(v) => font.underline = Some(v)
    None => ()
  }
  match size {
    Some(v) => font.size = Some(v)
    None => ()
  }
  match color {
    Some(v) => font.color = Some(v)
    None => ()
  }
  match color_theme {
    Some(v) => font.color_theme = Some(v)
    None => ()
  }
  match color_indexed {
    Some(v) => font.color_indexed = Some(v)
    None => ()
  }
  match color_tint {
    Some(v) => font.color_tint = Some(v)
    None => ()
  }
  match charset {
    Some(v) => font.charset = Some(v)
    None => ()
  }
  match family_number {
    Some(v) => font.family_number = Some(v)
    None => ()
  }
  match scheme {
    Some(v) => font.scheme = Some(v)
    None => ()
  }
  match vert_align {
    Some(v) => font.vert_align = Some(v)
    None => ()
  }
  match family {
    Some(v) => font.family = Some(v)
    None => ()
  }
  font
}

///|
/// Fill (background) styling for cells.
///
/// Supports solid colors, patterns, and gradients.
///
/// # Example
/// ```mbt nocheck
/// // Solid yellow fill
/// let fill = Fill::solid("FFFF00")
///
/// // Gradient fill
/// let gradient = Fill::gradient("FF0000", "0000FF", shading=1)
/// ```
pub struct Fill {
  mut typ : String?
  mut pattern : Int?
  mut shading : Int?
  mut colors : Array[String]?
  mut transparency : Int?
  mut fg_theme : Int?
  mut fg_indexed : Int?
  mut fg_tint : Double?
  mut bg_theme : Int?
  mut bg_indexed : Int?
  mut bg_tint : Double?
} derive(Eq, Show)

///|
pub fn Fill::new() -> Fill {
  {
    typ: None,
    pattern: None,
    shading: None,
    colors: None,
    transparency: None,
    fg_theme: None,
    fg_indexed: None,
    fg_tint: None,
    bg_theme: None,
    bg_indexed: None,
    bg_tint: None,
  }
}

///|
pub fn Fill::pattern(
  pattern? : Int,
  color? : String,
  transparency? : Int,
) -> Fill {
  let fill = Fill::new()
  fill.typ = Some("pattern")
  match pattern {
    Some(v) => fill.pattern = Some(v)
    None => ()
  }
  match color {
    Some(v) => fill.colors = Some([v])
    None => ()
  }
  match transparency {
    Some(v) => fill.transparency = Some(v)
    None => ()
  }
  fill
}

///|
/// Creates a solid color fill.
///
/// # Parameters
/// - `color`: Hex color code like "FFFF00" for yellow
/// - `transparency`: Transparency percentage (0-100)
///
/// # Example
/// ```mbt nocheck
/// let yellow = Fill::solid("FFFF00")
/// let semi_transparent = Fill::solid("FF0000", transparency=50)
/// ```
pub fn Fill::solid(color : String, transparency? : Int) -> Fill {
  Fill::pattern(pattern=1, color~, transparency?)
}

///|
priv struct GradientVariant {
  bottom : Double
  degree : Double
  left : Double
  right : Double
  top : Double
  typ : String
  stops : Array[Double]
}

///|
let fill_gradient_variants : Array[GradientVariant] = [
  {
    bottom: 0.0,
    degree: 90.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 270.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 90.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 0.5, 1.0],
  },
  {
    bottom: 0.0,
    degree: 0.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 180.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 0.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 0.5, 1.0],
  },
  {
    bottom: 0.0,
    degree: 45.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 255.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 45.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 0.5, 1.0],
  },
  {
    bottom: 0.0,
    degree: 135.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 315.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 135.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "",
    stops: [0.0, 0.5, 1.0],
  },
  {
    bottom: 0.0,
    degree: 0.0,
    left: 0.0,
    right: 0.0,
    top: 0.0,
    typ: "path",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.0,
    degree: 0.0,
    left: 1.0,
    right: 1.0,
    top: 0.0,
    typ: "path",
    stops: [0.0, 1.0],
  },
  {
    bottom: 1.0,
    degree: 0.0,
    left: 0.0,
    right: 0.0,
    top: 1.0,
    typ: "path",
    stops: [0.0, 1.0],
  },
  {
    bottom: 1.0,
    degree: 0.0,
    left: 1.0,
    right: 1.0,
    top: 1.0,
    typ: "path",
    stops: [0.0, 1.0],
  },
  {
    bottom: 0.5,
    degree: 0.0,
    left: 0.5,
    right: 0.5,
    top: 0.5,
    typ: "path",
    stops: [0.0, 1.0],
  },
]

///|
/// Creates a gradient fill between two colors.
///
/// # Parameters
/// - `color1`: Start color (hex code)
/// - `color2`: End color (hex code)
/// - `shading`: Gradient shading variant (0-15)
/// - `transparency`: Transparency percentage (0-100)
///
/// # Example
/// ```mbt nocheck
/// let gradient = Fill::gradient("FF0000", "0000FF") // Red to blue
/// ```
pub fn Fill::gradient(
  color1 : String,
  color2 : String,
  shading? : Int = 0,
  transparency? : Int,
) -> Fill {
  let fill = Fill::new()
  fill.typ = Some("gradient")
  fill.shading = Some(shading)
  fill.colors = Some([color1, color2])
  match transparency {
    Some(v) => fill.transparency = Some(v)
    None => ()
  }
  fill
}

///|
pub fn Fill::solid_theme(theme : Int, tint? : Double) -> Fill {
  let fill = Fill::new()
  fill.typ = Some("pattern")
  fill.pattern = Some(1)
  fill.fg_theme = Some(theme)
  match tint {
    Some(v) => fill.fg_tint = Some(v)
    None => ()
  }
  fill
}

///|
pub fn Fill::solid_indexed(indexed : Int, tint? : Double) -> Fill {
  let fill = Fill::new()
  fill.typ = Some("pattern")
  fill.pattern = Some(1)
  fill.fg_indexed = Some(indexed)
  match tint {
    Some(v) => fill.fg_tint = Some(v)
    None => ()
  }
  fill
}

///|
pub fn Fill::solid_bg_theme(theme : Int, tint? : Double) -> Fill {
  let fill = Fill::new()
  fill.typ = Some("pattern")
  fill.pattern = Some(1)
  fill.bg_theme = Some(theme)
  match tint {
    Some(v) => fill.bg_tint = Some(v)
    None => ()
  }
  fill
}

///|
pub fn Fill::solid_bg_indexed(indexed : Int, tint? : Double) -> Fill {
  let fill = Fill::new()
  fill.typ = Some("pattern")
  fill.pattern = Some(1)
  fill.bg_indexed = Some(indexed)
  match tint {
    Some(v) => fill.bg_tint = Some(v)
    None => ()
  }
  fill
}

///|
/// Border styling for a cell edge.
///
/// # Border Types
/// - "left", "right", "top", "bottom": Cell edges
/// - "diagonalUp", "diagonalDown": Diagonal lines
///
/// # Border Styles
/// - 0: None
/// - 1: Thin
/// - 2: Medium
/// - 3: Dashed
/// - 4: Dotted
/// - 5: Thick
/// - 6: Double
/// - 7: Hair
/// - 8: MediumDashed
/// - 9: DashDot
/// - 10: MediumDashDot
/// - 11: DashDotDot
/// - 12: MediumDashDotDot
/// - 13: SlantDashDot
pub struct Border {
  typ : String
  mut color : String?
  mut style : Int?
} derive(Eq, Show)

///|
priv struct BorderXmlEntry {
  diagonal_up : Bool
  diagonal_down : Bool
  lines : Array[(String, Int, String?)]
}

///|
pub fn Border::new(typ : String) -> Border {
  { typ, color: None, style: None }
}

///|
/// Creates a Border with specified values.
///
/// # Parameters
/// - `typ`: Border type ("left", "right", "top", "bottom")
/// - `color`: Hex color code
/// - `style`: Border style (1=thin, 2=medium, 5=thick, etc.)
///
/// # Example
/// ```mbt nocheck
/// let thin_black = Border::with_values("left", color="000000", style=1)
/// let thick_red = Border::with_values("bottom", color="FF0000", style=5)
/// ```
pub fn Border::with_values(
  typ : String,
  color? : String,
  style? : Int,
) -> Border {
  let border = Border::new(typ)
  match color {
    Some(v) => border.color = Some(v)
    None => ()
  }
  match style {
    Some(v) => border.style = Some(v)
    None => ()
  }
  border
}

///|
pub struct Protection {
  mut hidden : Bool?
  mut locked : Bool?
} derive(Eq, Show)

///|
pub fn Protection::new() -> Protection {
  { hidden: None, locked: None }
}

///|
pub fn Protection::with_values(hidden? : Bool, locked? : Bool) -> Protection {
  let protection = Protection::new()
  match hidden {
    Some(v) => protection.hidden = Some(v)
    None => ()
  }
  match locked {
    Some(v) => protection.locked = Some(v)
    None => ()
  }
  protection
}

///|
/// Text alignment settings for cells.
///
/// # Horizontal Values
/// - "left", "center", "right", "fill", "justify", "centerContinuous", "distributed"
///
/// # Vertical Values
/// - "top", "center", "bottom", "justify", "distributed"
pub struct Alignment {
  mut horizontal : String?
  mut vertical : String?
  mut wrap_text : Bool?
  mut text_rotation : Int?
  mut indent : Int?
  mut shrink_to_fit : Bool?
  mut justify_last_line : Bool?
  mut reading_order : Int?
  mut relative_indent : Int?
} derive(Eq, Show)

///|
pub fn Alignment::new() -> Alignment {
  {
    horizontal: None,
    vertical: None,
    wrap_text: None,
    text_rotation: None,
    indent: None,
    shrink_to_fit: None,
    justify_last_line: None,
    reading_order: None,
    relative_indent: None,
  }
}

///|
/// Creates an Alignment with specified values.
///
/// # Parameters
/// - `horizontal`: Horizontal alignment ("left", "center", "right", etc.)
/// - `vertical`: Vertical alignment ("top", "center", "bottom", etc.)
/// - `wrap_text`: Enable text wrapping
/// - `text_rotation`: Rotation angle in degrees (0-180, or 255 for vertical)
/// - `indent`: Indentation level
/// - `shrink_to_fit`: Shrink text to fit cell width
pub fn Alignment::with_values(
  horizontal? : String,
  vertical? : String,
  wrap_text? : Bool,
  text_rotation? : Int,
  indent? : Int,
  shrink_to_fit? : Bool,
  justify_last_line? : Bool,
  reading_order? : Int,
  relative_indent? : Int,
) -> Alignment {
  let align = Alignment::new()
  match horizontal {
    Some(v) => align.horizontal = Some(v)
    None => ()
  }
  match vertical {
    Some(v) => align.vertical = Some(v)
    None => ()
  }
  match wrap_text {
    Some(v) => align.wrap_text = Some(v)
    None => ()
  }
  match text_rotation {
    Some(v) => align.text_rotation = Some(v)
    None => ()
  }
  match indent {
    Some(v) => align.indent = Some(v)
    None => ()
  }
  match shrink_to_fit {
    Some(v) => align.shrink_to_fit = Some(v)
    None => ()
  }
  match justify_last_line {
    Some(v) => align.justify_last_line = Some(v)
    None => ()
  }
  match reading_order {
    Some(v) => align.reading_order = Some(v)
    None => ()
  }
  match relative_indent {
    Some(v) => align.relative_indent = Some(v)
    None => ()
  }
  align
}

///|
/// Complete cell style specification.
///
/// A Style combines font, fill, border, alignment, number format, and protection
/// settings. Styles are registered with a workbook and referenced by ID in cells.
///
/// # Example
/// ```mbt nocheck
/// // Create a style with multiple elements
/// let style = Style::new()
///   .with_font(Font::with_values(bold=true, size=12.0))
///   .with_fill(Fill::solid("FFFF00"))
///   .with_alignment(Alignment::with_values(horizontal="center"))
///
/// // Register with workbook and apply to cell
/// let style_id = workbook.add_style(style)
/// sheet.set_cell_style("A1", style_id)
/// ```
pub struct Style {
  number_format : NumberFormat?
  font : Font?
  fill : Fill?
  border : Array[Border]?
  protection : Protection?
  alignment : Alignment?
} derive(Eq, Show)

///|
/// Creates a new empty Style with all fields set to None.
pub fn Style::new() -> Style {
  {
    number_format: None,
    font: None,
    fill: None,
    border: None,
    protection: None,
    alignment: None,
  }
}

///|
/// Creates a Style with a custom number format.
///
/// # Parameters
/// - `format_code`: Excel number format string like "#,##0.00", "0%", "yyyy-mm-dd"
///
/// # Example
/// ```mbt nocheck
/// let currency = Style::number_format("$#,##0.00")
/// let percent = Style::number_format("0.0%")
/// let date = Style::number_format("yyyy-mm-dd")
/// ```
pub fn Style::number_format(format_code : String) -> Style {
  {
    number_format: Some(NumberFormat::Custom(format_code)),
    font: None,
    fill: None,
    border: None,
    protection: None,
    alignment: None,
  }
}

///|
/// Creates a Style with a built-in number format.
///
/// # Parameters
/// - `id`: Built-in format ID (see NumberFormat for common IDs)
///
/// # Common IDs
/// - 1: 0
/// - 2: 0.00
/// - 3: #,##0
/// - 4: #,##0.00
/// - 9: 0%
/// - 10: 0.00%
/// - 14: mm-dd-yy
pub fn Style::builtin_number_format(id : Int) -> Style {
  {
    number_format: Some(NumberFormat::Builtin(id)),
    font: None,
    fill: None,
    border: None,
    protection: None,
    alignment: None,
  }
}

///|
pub fn Style::excelize_custom_num_fmt(
  format_code : StringView,
) -> Style raise XlsxError {
  if format_code == "" {
    raise XlsxError::InvalidOptions(msg="custom number format can not be empty")
  }
  Style::number_format(format_code.to_string())
}

///|
pub fn Style::excelize_currency_num_fmt(
  num_fmt : Int,
  decimal_places? : Int = 2,
  neg_red? : Bool = false,
) -> Style raise XlsxError {
  if decimal_places < 0 || decimal_places > 30 {
    raise XlsxError::InvalidOptions(msg="decimal places must be in [0, 30]")
  }
  let base = match excelize_currency_num_fmt_code(num_fmt) {
    Some(v) => v
    None =>
      raise XlsxError::InvalidOptions(
        msg="unknown excelize currency number format",
      )
  }
  let code = if decimal_places == 2 {
    base
  } else {
    let mut dp = "0"
    if decimal_places > 0 {
      dp += "."
      for _ in 0..<decimal_places {
        dp += "0"
      }
    }
    base.replace_all(old="0.00", new=dp)
  }
  let full = if neg_red { code + ";[Red]" + code } else { code }
  Style::number_format(full)
}

///|
/// Creates a Style with only font settings.
pub fn Style::font(font : Font) -> Style {
  {
    number_format: None,
    font: Some(font),
    fill: None,
    border: None,
    protection: None,
    alignment: None,
  }
}

///|
/// Returns a new Style with font settings added/replaced.
pub fn Style::with_font(self : Style, font : Font) -> Style {
  {
    number_format: self.number_format,
    font: Some(font),
    fill: self.fill,
    border: self.border,
    protection: self.protection,
    alignment: self.alignment,
  }
}

///|
/// Creates a Style with only fill settings.
pub fn Style::fill(fill : Fill) -> Style {
  {
    number_format: None,
    font: None,
    fill: Some(fill),
    border: None,
    protection: None,
    alignment: None,
  }
}

///|
/// Returns a new Style with fill settings added/replaced.
pub fn Style::with_fill(self : Style, fill : Fill) -> Style {
  {
    number_format: self.number_format,
    font: self.font,
    fill: Some(fill),
    border: self.border,
    protection: self.protection,
    alignment: self.alignment,
  }
}

///|
/// Creates a Style with only border settings.
///
/// # Example
/// ```mbt nocheck
/// let box_border = Style::border([
///   Border::with_values("left", color="000000", style=1),
///   Border::with_values("right", color="000000", style=1),
///   Border::with_values("top", color="000000", style=1),
///   Border::with_values("bottom", color="000000", style=1),
/// ])
/// ```
pub fn Style::border(border : Array[Border]) -> Style {
  {
    number_format: None,
    font: None,
    fill: None,
    border: Some(border),
    protection: None,
    alignment: None,
  }
}

///|
/// Returns a new Style with border settings added/replaced.
pub fn Style::with_border(self : Style, border : Array[Border]) -> Style {
  {
    number_format: self.number_format,
    font: self.font,
    fill: self.fill,
    border: Some(border),
    protection: self.protection,
    alignment: self.alignment,
  }
}

///|
/// Creates a Style with only protection settings.
pub fn Style::protection(protection : Protection) -> Style {
  {
    number_format: None,
    font: None,
    fill: None,
    border: None,
    protection: Some(protection),
    alignment: None,
  }
}

///|
pub fn Style::with_protection(self : Style, protection : Protection) -> Style {
  {
    number_format: self.number_format,
    font: self.font,
    fill: self.fill,
    border: self.border,
    protection: Some(protection),
    alignment: self.alignment,
  }
}

///|
pub fn Style::alignment(alignment : Alignment) -> Style {
  {
    number_format: None,
    font: None,
    fill: None,
    border: None,
    protection: None,
    alignment: Some(alignment),
  }
}

///|
pub fn Style::with_alignment(self : Style, alignment : Alignment) -> Style {
  {
    number_format: self.number_format,
    font: self.font,
    fill: self.fill,
    border: self.border,
    protection: self.protection,
    alignment: Some(alignment),
  }
}

///|
fn write_styles_xml(
  styles : ArrayView[Style],
  conditional_styles : ArrayView[Style],
  default_font : StringView,
  default_table_style : StringView,
  default_pivot_style : StringView,
  indexed_colors : Array[String]?,
  mru_colors_xml : String?,
  styles_ext_lst_xml : String?,
) -> String {
  let style_list : Array[Style] = []
  for style in styles {
    style_list.push(style)
  }
  if style_list.length() == 0 {
    style_list.push(Style::new())
  }
  let dxf_list : Array[Style] = []
  for style in conditional_styles {
    dxf_list.push(style)
  }
  let num_fmt_entries : Array[(Int, String)] = []
  let num_fmt_ids : Map[String, Int] = {}
  let mut next_id = 164
  for style in style_list {
    match style.number_format {
      Some(NumberFormat::Custom(code)) =>
        match num_fmt_ids.get(code) {
          Some(_) => ()
          None => {
            num_fmt_ids[code] = next_id
            num_fmt_entries.push((next_id, code))
            next_id = next_id + 1
          }
        }
      _ => ()
    }
  }
  for style in dxf_list {
    match style.number_format {
      Some(NumberFormat::Custom(code)) =>
        match num_fmt_ids.get(code) {
          Some(_) => ()
          None => {
            num_fmt_ids[code] = next_id
            num_fmt_entries.push((next_id, code))
            next_id = next_id + 1
          }
        }
      _ => ()
    }
  }
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n",
  )
  if num_fmt_entries.length() > 0 {
    sb.write_view("  <numFmts count=\"\{num_fmt_entries.length()}\">\n")
    for entry in num_fmt_entries {
      let (id, code) = entry
      sb.write_view("    <numFmt numFmtId=\"\{id}\" formatCode=\"")
      sb.write_view(escape_xml_attr(code))
      sb.write_view("\"/>\n")
    }
    sb.write_view("  </numFmts>\n")
  }
  let font_name = if default_font == "" {
    "Calibri"
  } else {
    default_font.to_string()
  }
  // Font collection: id 0 is the workbook default font.
  let fonts : Array[Font] = [Font::with_values(size=11.0, family=font_name)]
  let font_ids : Map[String, Int] = {}
  fn normalize_font_key(font : Font, default_family : StringView) -> String {
    let family = match font.family {
      Some(v) => v.to_string()
      None => default_family.to_string()
    }
    let size = match font.size {
      Some(v) => v.to_string()
      None => "11"
    }
    let bold = match font.bold {
      Some(v) => if v { "1" } else { "0" }
      None => "0"
    }
    let italic = match font.italic {
      Some(v) => if v { "1" } else { "0" }
      None => "0"
    }
    let strike = match font.strike {
      Some(v) => if v { "1" } else { "0" }
      None => "0"
    }
    let outline = match font.outline {
      Some(v) => if v { "1" } else { "0" }
      None => "0"
    }
    let shadow = match font.shadow {
      Some(v) => if v { "1" } else { "0" }
      None => "0"
    }
    let condense = match font.condense {
      Some(v) => if v { "1" } else { "0" }
      None => "0"
    }
    let extend = match font.extend {
      Some(v) => if v { "1" } else { "0" }
      None => "0"
    }
    let underline = match font.underline {
      Some(v) => v.to_string()
      None => ""
    }
    let color = match font.color {
      Some(v) => v.to_string()
      None => ""
    }
    let color_theme = match font.color_theme {
      Some(v) => v.to_string()
      None => ""
    }
    let color_indexed = match font.color_indexed {
      Some(v) => v.to_string()
      None => ""
    }
    let color_tint = match font.color_tint {
      Some(v) => v.to_string()
      None => ""
    }
    let charset = match font.charset {
      Some(v) => v.to_string()
      None => ""
    }
    let family_number = match font.family_number {
      Some(v) => v.to_string()
      None => "2"
    }
    let scheme = match font.scheme {
      Some(v) => v.to_string()
      None => ""
    }
    let vert_align = match font.vert_align {
      Some(v) => v.to_string()
      None => ""
    }
    "\{family}|\{size}|\{bold}|\{italic}|\{strike}|\{outline}|\{shadow}|\{condense}|\{extend}|\{underline}|\{color}|\{color_theme}|\{color_indexed}|\{color_tint}|\{charset}|\{family_number}|\{scheme}|\{vert_align}"
  }

  fn write_font_color(sb : StringBuilder, font : Font) -> Unit {
    let tint = match font.color_tint {
      Some(v) => if v == 0.0 { None } else { Some(v) }
      None => None
    }
    match font.color_theme {
      Some(value) => {
        sb.write_view("      <color theme=\"\{value}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>\n")
        return
      }
      None => ()
    }
    match font.color_indexed {
      Some(value) => {
        sb.write_view("      <color indexed=\"\{value}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>\n")
        return
      }
      None => ()
    }
    match font.color {
      Some(value) => {
        let normalized = value.replace_all(old="#", new="")
        let rgb = if normalized.length() == 6 {
          "FF" + normalized
        } else {
          normalized
        }
        sb.write_view("      <color rgb=\"\{escape_xml_attr(rgb)}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>\n")
      }
      None => sb.write_view("      <color theme=\"1\"/>\n")
    }
  }

  let default_key = normalize_font_key(fonts[0], font_name)
  font_ids[default_key] = 0
  for style in style_list {
    match style.font {
      Some(font) => {
        let key = normalize_font_key(font, font_name)
        if !font_ids.contains(key) {
          font_ids[key] = fonts.length()
          fonts.push(font)
        }
      }
      None => ()
    }
  }
  sb.write_view("  <fonts count=\"\{fonts.length()}\">\n")
  for font in fonts {
    sb.write_view("    <font>\n")
    match font.bold {
      Some(true) => sb.write_view("      <b/>\n")
      _ => ()
    }
    match font.italic {
      Some(true) => sb.write_view("      <i/>\n")
      _ => ()
    }
    match font.strike {
      Some(true) => sb.write_view("      <strike/>\n")
      _ => ()
    }
    match font.outline {
      Some(true) => sb.write_view("      <outline/>\n")
      _ => ()
    }
    match font.shadow {
      Some(true) => sb.write_view("      <shadow/>\n")
      _ => ()
    }
    match font.condense {
      Some(true) => sb.write_view("      <condense/>\n")
      _ => ()
    }
    match font.extend {
      Some(true) => sb.write_view("      <extend/>\n")
      _ => ()
    }
    match font.underline {
      Some(value) =>
        sb.write_view("      <u val=\"\{escape_xml_attr(value)}\"/>\n")
      None => ()
    }
    match font.size {
      Some(value) => sb.write_view("      <sz val=\"\{value}\"/>\n")
      None => sb.write_view("      <sz val=\"11\"/>\n")
    }
    write_font_color(sb, font)
    match font.charset {
      Some(value) => sb.write_view("      <charset val=\"\{value}\"/>\n")
      None => ()
    }
    let family = match font.family {
      Some(v) => v.to_string()
      None => font_name
    }
    sb.write_view("      <name val=\"")
    sb.write_view(escape_xml_attr(family))
    sb.write_view("\"/>\n")
    let family_number = match font.family_number {
      Some(value) => value
      None => 2
    }
    sb.write_view("      <family val=\"\{family_number}\"/>\n")
    match font.vert_align {
      Some(value) =>
        sb.write_view("      <vertAlign val=\"\{escape_xml_attr(value)}\"/>\n")
      None => ()
    }
    match font.scheme {
      Some(value) =>
        sb.write_view("      <scheme val=\"\{escape_xml_attr(value)}\"/>\n")
      None => ()
    }
    sb.write_view("    </font>\n")
  }
  sb.write_view("  </fonts>\n")

  // Fill collection: id 0/1 are the workbook default fills.
  let fill_patterns : Array[String] = [
    "none", "solid", "mediumGray", "darkGray", "lightGray", "darkHorizontal", "darkVertical",
    "darkDown", "darkUp", "darkGrid", "darkTrellis", "lightHorizontal", "lightVertical",
    "lightDown", "lightUp", "lightGrid", "lightTrellis", "gray125", "gray0625",
  ]
  let fills : Array[String] = [
    "    <fill><patternFill patternType=\"none\"/></fill>\n", "    <fill><patternFill patternType=\"gray125\"/></fill>\n",
  ]
  let fill_ids : Map[String, Int] = {}
  fn normalize_pattern_fill_key(
    pattern : Int,
    fg_attrs : String,
    bg_attrs : String,
  ) -> String {
    "pattern|\{pattern}|\{fg_attrs}|\{bg_attrs}"
  }

  fn normalize_gradient_fill_key(
    shading : Int,
    c1 : String,
    c2 : String,
  ) -> String {
    "gradient|\{shading}|\{c1}|\{c2}"
  }

  fill_ids[normalize_pattern_fill_key(0, "", "")] = 0
  fill_ids[normalize_pattern_fill_key(17, "", "")] = 1
  fn clamp_transparency(v : Int) -> Int {
    if v < 0 {
      0
    } else if v > 100 {
      100
    } else {
      v
    }
  }

  fn fill_rgb(color : String, transparency : Int) -> String {
    let normalized = color.replace_all(old="#", new="")
    let base = if normalized.length() == 8 {
      (normalized[2:] catch { _ => normalized }).to_string()
    } else {
      normalized
    }
    let t = clamp_transparency(transparency)
    if t <= 0 && normalized.length() == 8 {
      normalized
    } else {
      let opacity = 100 - t
      let alpha = (opacity * 255 + 50) / 100
      let a = hex_byte(alpha.to_byte())
      a + base
    }
  }

  fn fill_color_attrs(
    theme : Int?,
    indexed : Int?,
    tint : Double?,
    rgb : String?,
    transparency : Int,
  ) -> String {
    match theme {
      Some(value) => {
        let sb = StringBuilder::new()
        sb.write_view("theme=\"\{value}\"")
        match tint {
          Some(v) => if v != 0.0 { sb.write_view(" tint=\"\{v}\"") }
          None => ()
        }
        return sb.to_string()
      }
      None => ()
    }
    match indexed {
      Some(value) => {
        let sb = StringBuilder::new()
        sb.write_view("indexed=\"\{value}\"")
        match tint {
          Some(v) => if v != 0.0 { sb.write_view(" tint=\"\{v}\"") }
          None => ()
        }
        return sb.to_string()
      }
      None => ()
    }
    match rgb {
      Some(value) => "rgb=\"\{escape_xml_attr(fill_rgb(value, transparency))}\""
      None => ""
    }
  }

  fn pattern_fill_xml(
    pattern : Int,
    fg_attrs : String,
    bg_attrs : String,
  ) -> String {
    let pattern_type = fill_patterns[pattern]
    if fg_attrs == "" && bg_attrs == "" {
      return "    <fill><patternFill patternType=\"\{escape_xml_attr(pattern_type)}\"/></fill>\n"
    }
    let sb = StringBuilder::new()
    sb.write_view("    <fill><patternFill patternType=\"")
    sb.write_view(escape_xml_attr(pattern_type))
    sb.write_view("\">")
    if fg_attrs != "" {
      sb.write_view("<fgColor \{fg_attrs}/>")
    }
    if bg_attrs != "" {
      sb.write_view("<bgColor \{bg_attrs}/>")
    }
    sb.write_view("</patternFill></fill>\n")
    sb.to_string()
  }

  fn gradient_fill_xml(
    variant : GradientVariant,
    c1 : String,
    c2 : String,
    indent : StringView,
    newline : Bool,
  ) -> String {
    let sb = StringBuilder::new()
    sb.write_view(indent)
    sb.write_view("<fill><gradientFill")
    if variant.bottom != 0.0 {
      sb.write_view(" bottom=\"\{variant.bottom}\"")
    }
    if variant.degree != 0.0 {
      sb.write_view(" degree=\"\{variant.degree}\"")
    }
    if variant.left != 0.0 {
      sb.write_view(" left=\"\{variant.left}\"")
    }
    if variant.right != 0.0 {
      sb.write_view(" right=\"\{variant.right}\"")
    }
    if variant.top != 0.0 {
      sb.write_view(" top=\"\{variant.top}\"")
    }
    if variant.typ != "" {
      sb.write_view(" type=\"\{escape_xml_attr(variant.typ)}\"")
    }
    sb.write_view(">")
    for i in 0..<variant.stops.length() {
      let pos = variant.stops[i]
      let color = if i == 1 { c2 } else { c1 }
      sb.write_view("<stop position=\"\{pos}\"><color rgb=\"")
      sb.write_view(escape_xml_attr(color))
      sb.write_view("\"/></stop>")
    }
    sb.write_view("</gradientFill></fill>")
    if newline {
      sb.write_char('\n')
    }
    sb.to_string()
  }

  for style in style_list {
    match style.fill {
      Some(fill) =>
        match fill.typ {
          Some(t) =>
            if t == "pattern" {
              let pattern = match fill.pattern {
                Some(v) => v
                None => 1
              }
              if pattern >= 0 && pattern < fill_patterns.length() {
                let fg_rgb = match fill.colors {
                  Some(colors) => colors.get(0)
                  None => None
                }
                let bg_rgb = match fill.colors {
                  Some(colors) => colors.get(1)
                  None => None
                }
                let transparency = match fill.transparency {
                  Some(v) => clamp_transparency(v)
                  None => 0
                }
                let fg_attrs = fill_color_attrs(
                  fill.fg_theme,
                  fill.fg_indexed,
                  fill.fg_tint,
                  fg_rgb,
                  transparency,
                )
                let bg_attrs = fill_color_attrs(
                  fill.bg_theme,
                  fill.bg_indexed,
                  fill.bg_tint,
                  bg_rgb,
                  transparency,
                )
                let key = normalize_pattern_fill_key(
                  pattern, fg_attrs, bg_attrs,
                )
                if !fill_ids.contains(key) {
                  fill_ids[key] = fills.length()
                  fills.push(pattern_fill_xml(pattern, fg_attrs, bg_attrs))
                }
              }
            } else if t == "gradient" {
              let shading = match fill.shading {
                Some(v) => v
                None => 0
              }
              if shading >= 0 && shading < fill_gradient_variants.length() {
                match fill.colors {
                  Some(colors) =>
                    match (colors.get(0), colors.get(1)) {
                      (Some(color1), Some(color2)) => {
                        let transparency = match fill.transparency {
                          Some(v) => clamp_transparency(v)
                          None => 0
                        }
                        let c1 = fill_rgb(color1, transparency)
                        let c2 = fill_rgb(color2, transparency)
                        let key = normalize_gradient_fill_key(shading, c1, c2)
                        if !fill_ids.contains(key) {
                          fill_ids[key] = fills.length()
                          fills.push(
                            gradient_fill_xml(
                              fill_gradient_variants[shading],
                              c1,
                              c2,
                              "    ",
                              true,
                            ),
                          )
                        }
                      }
                      _ => ()
                    }
                  None => ()
                }
              }
            }
          None => ()
        }
      None => ()
    }
  }
  sb.write_view("  <fills count=\"\{fills.length()}\">\n")
  for entry in fills {
    sb.write_view(entry)
  }
  sb.write_view("  </fills>\n")

  // Border collection: id 0 is the workbook default border.
  let border_styles : Array[String] = [
    "none", "thin", "medium", "dashed", "dotted", "thick", "double", "hair", "mediumDashed",
    "dashDot", "mediumDashDot", "dashDotDot", "mediumDashDotDot", "slantDashDot",
  ]
  let borders : Array[BorderXmlEntry] = [
    {
      diagonal_up: false,
      diagonal_down: false,
      lines: [
        ("left", 0, None),
        ("right", 0, None),
        ("top", 0, None),
        ("bottom", 0, None),
        ("diagonal", 0, None),
        ("vertical", 0, None),
        ("horizontal", 0, None),
      ],
    },
  ]
  let border_ids : Map[String, Int] = {}
  fn normalize_border_key(entry : BorderXmlEntry) -> String {
    let sb = StringBuilder::new()
    sb.write_view(if entry.diagonal_up { "1" } else { "0" })
    sb.write_char(',')
    sb.write_view(if entry.diagonal_down { "1" } else { "0" })
    for line in entry.lines {
      let (side, style, color) = line
      sb.write_char('|')
      sb.write_view(side)
      sb.write_char('=')
      sb.write_view(style.to_string())
      sb.write_char(',')
      match color {
        Some(v) => sb.write_view(v)
        None => ()
      }
    }
    sb.to_string()
  }

  border_ids[normalize_border_key(borders[0])] = 0
  fn border_lines_for_style(borders : ArrayView[Border]) -> BorderXmlEntry {
    let sides : Array[String] = [
      "left", "right", "top", "bottom", "vertical", "horizontal",
    ]
    let lines : Array[(String, Int, String?)] = []
    for side in sides {
      let mut style = 0
      let mut color : String? = None
      for b in borders {
        if b.typ == side {
          style = match b.style {
            Some(v) => v
            None => 0
          }
          color = b.color
        }
      }
      if style < 0 || style >= border_styles.length() {
        style = 0
      }
      lines.push((side, style, color))
    }
    let mut diagonal_up = false
    let mut diagonal_down = false
    for b in borders {
      if b.typ == "diagonalUp" {
        diagonal_up = true
      }
      if b.typ == "diagonalDown" {
        diagonal_down = true
      }
    }
    let mut diagonal_style = 0
    let mut diagonal_color : String? = None
    for b in borders {
      if b.typ == "diagonalUp" || b.typ == "diagonalDown" || b.typ == "diagonal" {
        diagonal_style = match b.style {
          Some(v) => v
          None => 0
        }
        diagonal_color = b.color
        break
      }
    }
    if diagonal_style < 0 || diagonal_style >= border_styles.length() {
      diagonal_style = 0
    }
    lines.push(("diagonal", diagonal_style, diagonal_color))
    { diagonal_up, diagonal_down, lines }
  }

  for style in style_list {
    match style.border {
      Some(border) => {
        let entry = border_lines_for_style(border)
        let key = normalize_border_key(entry)
        if !border_ids.contains(key) {
          border_ids[key] = borders.length()
          borders.push(entry)
        }
      }
      None => ()
    }
  }
  sb.write_view("  <borders count=\"\{borders.length()}\">\n")
  for entry in borders {
    sb.write_view("    <border")
    if entry.diagonal_up {
      sb.write_view(" diagonalUp=\"1\"")
    }
    if entry.diagonal_down {
      sb.write_view(" diagonalDown=\"1\"")
    }
    sb.write_view(">")
    for line in entry.lines {
      let (side, style, color) = line
      if (side == "vertical" || side == "horizontal") &&
        style <= 0 &&
        color == None {
        continue
      }
      if style <= 0 {
        sb.write_view("<\{side}/>")
        continue
      }
      let style_name = border_styles[style]
      sb.write_view("<\{side} style=\"")
      sb.write_view(escape_xml_attr(style_name))
      sb.write_view("\">")
      match color {
        Some(value) => {
          let normalized = value.replace_all(old="#", new="")
          let rgb = if normalized.length() == 6 {
            "FF" + normalized
          } else {
            normalized
          }
          sb.write_view("<color rgb=\"")
          sb.write_view(escape_xml_attr(rgb))
          sb.write_view("\"/>")
        }
        None => ()
      }
      sb.write_view("</\{side}>")
    }
    sb.write_view("</border>\n")
  }
  sb.write_view("  </borders>\n")
  let base_block =
    #|  <cellStyleXfs count="1">
    #|    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
    #|  </cellStyleXfs>
  sb.write_view(base_block)
  sb.write_view("  <cellXfs count=\"\{style_list.length()}\">\n")
  for style in style_list {
    let (num_fmt_id, apply) = match style.number_format {
      None => (0, false)
      Some(NumberFormat::Builtin(id)) => (id, true)
      Some(NumberFormat::Custom(code)) =>
        match num_fmt_ids.get(code) {
          Some(id) => (id, true)
          None => (0, false)
        }
    }
    let font_id = match style.font {
      Some(font) =>
        match font_ids.get(normalize_font_key(font, font_name)) {
          Some(id) => id
          None => 0
        }
      None => 0
    }
    let apply_font = font_id != 0
    let fill_id = match style.fill {
      Some(fill) =>
        match fill.typ {
          Some(t) =>
            if t == "pattern" {
              let pattern = match fill.pattern {
                Some(v) => v
                None => 1
              }
              let fg_rgb = match fill.colors {
                Some(colors) => colors.get(0)
                None => None
              }
              let bg_rgb = match fill.colors {
                Some(colors) => colors.get(1)
                None => None
              }
              let transparency = match fill.transparency {
                Some(v) => clamp_transparency(v)
                None => 0
              }
              let fg_attrs = fill_color_attrs(
                fill.fg_theme,
                fill.fg_indexed,
                fill.fg_tint,
                fg_rgb,
                transparency,
              )
              let bg_attrs = fill_color_attrs(
                fill.bg_theme,
                fill.bg_indexed,
                fill.bg_tint,
                bg_rgb,
                transparency,
              )
              match
                fill_ids.get(
                  normalize_pattern_fill_key(pattern, fg_attrs, bg_attrs),
                ) {
                Some(id) => id
                None => 0
              }
            } else if t == "gradient" {
              let shading = match fill.shading {
                Some(v) => v
                None => 0
              }
              if shading < 0 || shading >= fill_gradient_variants.length() {
                0
              } else {
                match fill.colors {
                  Some(colors) =>
                    match (colors.get(0), colors.get(1)) {
                      (Some(color1), Some(color2)) => {
                        let transparency = match fill.transparency {
                          Some(v) => clamp_transparency(v)
                          None => 0
                        }
                        let c1 = fill_rgb(color1, transparency)
                        let c2 = fill_rgb(color2, transparency)
                        match
                          fill_ids.get(
                            normalize_gradient_fill_key(shading, c1, c2),
                          ) {
                          Some(id) => id
                          None => 0
                        }
                      }
                      _ => 0
                    }
                  None => 0
                }
              }
            } else {
              0
            }
          None => 0
        }
      None => 0
    }
    let apply_fill = fill_id != 0
    let border_id = match style.border {
      Some(border) =>
        match
          border_ids.get(normalize_border_key(border_lines_for_style(border))) {
          Some(id) => id
          None => 0
        }
      None => 0
    }
    let apply_border = border_id != 0
    let protection = style.protection
    let apply_protection = match protection {
      Some(p) =>
        match (p.hidden, p.locked) {
          (None, None) => false
          _ => true
        }
      None => false
    }
    let alignment = style.alignment
    let apply_alignment = match alignment {
      Some(a) =>
        match
          (
            a.horizontal,
            a.vertical,
            a.wrap_text,
            a.text_rotation,
            a.indent,
            a.shrink_to_fit,
            a.justify_last_line,
            a.reading_order,
            a.relative_indent,
          ) {
          (None, None, None, None, None, None, None, None, None) => false
          _ => true
        }
      None => false
    }
    sb.write_view(
      "    <xf numFmtId=\"\{num_fmt_id}\" fontId=\"\{font_id}\" fillId=\"\{fill_id}\" borderId=\"\{border_id}\" xfId=\"0\"",
    )
    if apply {
      sb.write_view(" applyNumberFormat=\"1\"")
    }
    if apply_font {
      sb.write_view(" applyFont=\"1\"")
    }
    if apply_fill {
      sb.write_view(" applyFill=\"1\"")
    }
    if apply_border {
      sb.write_view(" applyBorder=\"1\"")
    }
    if apply_alignment {
      sb.write_view(" applyAlignment=\"1\"")
    }
    if apply_protection {
      sb.write_view(" applyProtection=\"1\"")
    }
    let needs_children = apply_alignment || apply_protection
    if !needs_children {
      sb.write_view("/>\n")
    } else {
      sb.write_view(">")
      match alignment {
        Some(a) =>
          if apply_alignment {
            sb.write_view("<alignment")
            match a.horizontal {
              Some(v) => sb.write_view(" horizontal=\"\{escape_xml_attr(v)}\"")
              None => ()
            }
            match a.vertical {
              Some(v) => sb.write_view(" vertical=\"\{escape_xml_attr(v)}\"")
              None => ()
            }
            match a.wrap_text {
              Some(v) => {
                sb.write_view(" wrapText=\"")
                sb.write_view(if v { "1" } else { "0" })
                sb.write_view("\"")
              }
              None => ()
            }
            match a.text_rotation {
              Some(v) => sb.write_view(" textRotation=\"\{v}\"")
              None => ()
            }
            match a.indent {
              Some(v) => sb.write_view(" indent=\"\{v}\"")
              None => ()
            }
            match a.shrink_to_fit {
              Some(v) => {
                sb.write_view(" shrinkToFit=\"")
                sb.write_view(if v { "1" } else { "0" })
                sb.write_view("\"")
              }
              None => ()
            }
            match a.justify_last_line {
              Some(v) => {
                sb.write_view(" justifyLastLine=\"")
                sb.write_view(if v { "1" } else { "0" })
                sb.write_view("\"")
              }
              None => ()
            }
            match a.reading_order {
              Some(v) => sb.write_view(" readingOrder=\"\{v}\"")
              None => ()
            }
            match a.relative_indent {
              Some(v) => sb.write_view(" relativeIndent=\"\{v}\"")
              None => ()
            }
            sb.write_view("/>")
          }
        None => ()
      }
      match protection {
        Some(p) => {
          sb.write_view("<protection")
          match p.locked {
            Some(v) => {
              sb.write_view(" locked=\"")
              sb.write_view(if v { "1" } else { "0" })
              sb.write_view("\"")
            }
            None => ()
          }
          match p.hidden {
            Some(v) => {
              sb.write_view(" hidden=\"")
              sb.write_view(if v { "1" } else { "0" })
              sb.write_view("\"")
            }
            None => ()
          }
          sb.write_view("/>")
        }
        None => ()
      }
      sb.write_view("</xf>\n")
    }
  }
  sb.write_view("  </cellXfs>\n")
  sb.write_view("  <cellStyles count=\"1\">\n")
  sb.write_view("    <cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/>\n")
  sb.write_view("  </cellStyles>\n")
  if dxf_list.length() == 0 {
    sb.write_view("  <dxfs count=\"0\"></dxfs>\n")
  } else {
    sb.write_view("  <dxfs count=\"\{dxf_list.length()}\">\n")
    for style in dxf_list {
      let has_font = match style.font {
        Some(font) =>
          match
            (
              font.bold,
              font.italic,
              font.underline,
              font.size,
              font.color,
              font.family,
            ) {
            (None, None, None, None, None, None) => false
            _ => true
          }
        None => false
      }
      let has_fill = match style.fill {
        Some(fill) =>
          match fill.typ {
            Some(t) => t == "pattern" || t == "gradient"
            None => false
          }
        None => false
      }
      let has_border = match style.border {
        Some(border) => {
          let entry = border_lines_for_style(border)
          let mut any = false
          for line in entry.lines {
            let (_, s, c) = line
            if s > 0 || c != None {
              any = true
            }
          }
          any
        }
        None => false
      }
      let has_protection = match style.protection {
        Some(p) =>
          match (p.hidden, p.locked) {
            (None, None) => false
            _ => true
          }
        None => false
      }
      let has_alignment = match style.alignment {
        Some(a) =>
          match
            (
              a.horizontal,
              a.vertical,
              a.wrap_text,
              a.text_rotation,
              a.indent,
              a.shrink_to_fit,
              a.justify_last_line,
              a.reading_order,
              a.relative_indent,
            ) {
            (None, None, None, None, None, None, None, None, None) => false
            _ => true
          }
        None => false
      }
      let has_num_fmt = match style.number_format {
        Some(_) => true
        None => false
      }
      if !has_num_fmt &&
        !has_font &&
        !has_fill &&
        !has_border &&
        !has_protection &&
        !has_alignment {
        sb.write_view("    <dxf/>\n")
        continue
      }
      sb.write_view("    <dxf>")
      match style.number_format {
        Some(NumberFormat::Builtin(id)) =>
          sb.write_view("<numFmt numFmtId=\"\{id}\"/>")
        Some(NumberFormat::Custom(code)) =>
          match num_fmt_ids.get(code) {
            Some(id) => {
              sb.write_view("<numFmt numFmtId=\"\{id}\" formatCode=\"")
              sb.write_view(escape_xml_attr(code))
              sb.write_view("\"/>")
            }
            None => ()
          }
        None => ()
      }
      match style.font {
        Some(font) =>
          if has_font {
            sb.write_view("<font>")
            match font.bold {
              Some(true) => sb.write_view("<b/>")
              _ => ()
            }
            match font.italic {
              Some(true) => sb.write_view("<i/>")
              _ => ()
            }
            match font.strike {
              Some(true) => sb.write_view("<strike/>")
              _ => ()
            }
            match font.outline {
              Some(true) => sb.write_view("<outline/>")
              _ => ()
            }
            match font.shadow {
              Some(true) => sb.write_view("<shadow/>")
              _ => ()
            }
            match font.condense {
              Some(true) => sb.write_view("<condense/>")
              _ => ()
            }
            match font.extend {
              Some(true) => sb.write_view("<extend/>")
              _ => ()
            }
            match font.underline {
              Some(value) =>
                sb.write_view("<u val=\"\{escape_xml_attr(value)}\"/>")
              None => ()
            }
            match font.size {
              Some(value) => sb.write_view("<sz val=\"\{value}\"/>")
              None => ()
            }
            let tint = match font.color_tint {
              Some(v) => if v == 0.0 { None } else { Some(v) }
              None => None
            }
            match font.color_theme {
              Some(value) => {
                sb.write_view("<color theme=\"\{value}\"")
                match tint {
                  Some(v) => sb.write_view(" tint=\"\{v}\"")
                  None => ()
                }
                sb.write_view("/>")
              }
              None =>
                match font.color_indexed {
                  Some(value) => {
                    sb.write_view("<color indexed=\"\{value}\"")
                    match tint {
                      Some(v) => sb.write_view(" tint=\"\{v}\"")
                      None => ()
                    }
                    sb.write_view("/>")
                  }
                  None =>
                    match font.color {
                      Some(value) => {
                        let normalized = value.replace_all(old="#", new="")
                        let rgb = if normalized.length() == 6 {
                          "FF" + normalized
                        } else {
                          normalized
                        }
                        sb.write_view("<color rgb=\"\{escape_xml_attr(rgb)}\"")
                        match tint {
                          Some(v) => sb.write_view(" tint=\"\{v}\"")
                          None => ()
                        }
                        sb.write_view("/>")
                      }
                      None => ()
                    }
                }
            }
            match font.charset {
              Some(value) => sb.write_view("<charset val=\"\{value}\"/>")
              None => ()
            }
            match font.family {
              Some(value) => {
                sb.write_view("<name val=\"")
                sb.write_view(escape_xml_attr(value))
                sb.write_view("\"/>")
              }
              None => ()
            }
            let family_number = match font.family_number {
              Some(value) => value
              None => 2
            }
            sb.write_view("<family val=\"\{family_number}\"/>")
            match font.vert_align {
              Some(value) =>
                sb.write_view("<vertAlign val=\"\{escape_xml_attr(value)}\"/>")
              None => ()
            }
            match font.scheme {
              Some(value) =>
                sb.write_view("<scheme val=\"\{escape_xml_attr(value)}\"/>")
              None => ()
            }
            sb.write_view("</font>")
          }
        None => ()
      }
      match style.fill {
        Some(fill) =>
          if has_fill {
            match fill.typ {
              Some(t) =>
                if t == "pattern" {
                  let pattern = match fill.pattern {
                    Some(v) => v
                    None => 1
                  }
                  if pattern >= 0 && pattern < fill_patterns.length() {
                    let pattern_type = fill_patterns[pattern]
                    let transparency = match fill.transparency {
                      Some(v) => clamp_transparency(v)
                      None => 0
                    }
                    let bg_rgb = match fill.colors {
                      Some(colors) =>
                        match colors.get(1) {
                          Some(v) => Some(v)
                          None => colors.get(0)
                        }
                      None => None
                    }
                    let bg_theme = match fill.bg_theme {
                      Some(v) => Some(v)
                      None => fill.fg_theme
                    }
                    let bg_indexed = match fill.bg_indexed {
                      Some(v) => Some(v)
                      None => fill.fg_indexed
                    }
                    let bg_tint = match fill.bg_tint {
                      Some(v) => Some(v)
                      None => fill.fg_tint
                    }
                    let bg_attrs = fill_color_attrs(
                      bg_theme, bg_indexed, bg_tint, bg_rgb, transparency,
                    )
                    sb.write_view("<fill><patternFill patternType=\"")
                    sb.write_view(escape_xml_attr(pattern_type))
                    sb.write_view("\">")
                    if bg_attrs != "" {
                      sb.write_view("<bgColor \{bg_attrs}/>")
                    }
                    sb.write_view("</patternFill></fill>")
                  }
                } else if t == "gradient" {
                  let shading = match fill.shading {
                    Some(v) => v
                    None => 0
                  }
                  if shading >= 0 && shading < fill_gradient_variants.length() {
                    match fill.colors {
                      Some(colors) =>
                        match (colors.get(0), colors.get(1)) {
                          (Some(color1), Some(color2)) => {
                            let transparency = match fill.transparency {
                              Some(v) => clamp_transparency(v)
                              None => 0
                            }
                            let c1 = fill_rgb(color1, transparency)
                            let c2 = fill_rgb(color2, transparency)
                            sb.write_view(
                              gradient_fill_xml(
                                fill_gradient_variants[shading],
                                c1,
                                c2,
                                "",
                                false,
                              ),
                            )
                          }
                          _ => ()
                        }
                      None => ()
                    }
                  }
                }
              None => ()
            }
          }
        None => ()
      }
      match style.border {
        Some(border) =>
          if has_border {
            let entry = border_lines_for_style(border)
            sb.write_view("<border")
            if entry.diagonal_up {
              sb.write_view(" diagonalUp=\"1\"")
            }
            if entry.diagonal_down {
              sb.write_view(" diagonalDown=\"1\"")
            }
            sb.write_view(">")
            for line in entry.lines {
              let (side, style, color) = line
              if (side == "vertical" || side == "horizontal") &&
                style <= 0 &&
                color == None {
                continue
              }
              if style <= 0 {
                sb.write_view("<\{side}/>")
                continue
              }
              let style_name = border_styles[style]
              sb.write_view("<\{side} style=\"")
              sb.write_view(escape_xml_attr(style_name))
              sb.write_view("\">")
              match color {
                Some(value) => {
                  let normalized = value.replace_all(old="#", new="")
                  let rgb = if normalized.length() == 6 {
                    "FF" + normalized
                  } else {
                    normalized
                  }
                  sb.write_view("<color rgb=\"")
                  sb.write_view(escape_xml_attr(rgb))
                  sb.write_view("\"/>")
                }
                None => ()
              }
              sb.write_view("</\{side}>")
            }
            sb.write_view("</border>")
          }
        None => ()
      }
      match style.alignment {
        Some(a) =>
          if has_alignment {
            sb.write_view("<alignment")
            match a.horizontal {
              Some(v) => sb.write_view(" horizontal=\"\{escape_xml_attr(v)}\"")
              None => ()
            }
            match a.vertical {
              Some(v) => sb.write_view(" vertical=\"\{escape_xml_attr(v)}\"")
              None => ()
            }
            match a.wrap_text {
              Some(v) => {
                sb.write_view(" wrapText=\"")
                sb.write_view(if v { "1" } else { "0" })
                sb.write_view("\"")
              }
              None => ()
            }
            match a.text_rotation {
              Some(v) => sb.write_view(" textRotation=\"\{v}\"")
              None => ()
            }
            match a.indent {
              Some(v) => sb.write_view(" indent=\"\{v}\"")
              None => ()
            }
            match a.shrink_to_fit {
              Some(v) => {
                sb.write_view(" shrinkToFit=\"")
                sb.write_view(if v { "1" } else { "0" })
                sb.write_view("\"")
              }
              None => ()
            }
            match a.justify_last_line {
              Some(v) => {
                sb.write_view(" justifyLastLine=\"")
                sb.write_view(if v { "1" } else { "0" })
                sb.write_view("\"")
              }
              None => ()
            }
            match a.reading_order {
              Some(v) => sb.write_view(" readingOrder=\"\{v}\"")
              None => ()
            }
            match a.relative_indent {
              Some(v) => sb.write_view(" relativeIndent=\"\{v}\"")
              None => ()
            }
            sb.write_view("/>")
          }
        None => ()
      }
      match style.protection {
        Some(p) =>
          if has_protection {
            sb.write_view("<protection")
            match p.locked {
              Some(v) => {
                sb.write_view(" locked=\"")
                sb.write_view(if v { "1" } else { "0" })
                sb.write_view("\"")
              }
              None => ()
            }
            match p.hidden {
              Some(v) => {
                sb.write_view(" hidden=\"")
                sb.write_view(if v { "1" } else { "0" })
                sb.write_view("\"")
              }
              None => ()
            }
            sb.write_view("/>")
          }
        None => ()
      }
      sb.write_view("</dxf>\n")
    }
    sb.write_view("  </dxfs>\n")
  }
  sb.write_view("  <tableStyles count=\"0\" defaultTableStyle=\"")
  sb.write_view(escape_xml_attr(default_table_style))
  sb.write_view("\" defaultPivotStyle=\"")
  sb.write_view(escape_xml_attr(default_pivot_style))
  sb.write_view("\"/>\n")
  let has_indexed = match indexed_colors {
    Some(colors) => colors.length() > 0
    None => false
  }
  let has_mru = match mru_colors_xml {
    Some(value) => value != ""
    None => false
  }
  if has_indexed || has_mru {
    sb.write_view("  <colors>")
    match indexed_colors {
      Some(colors) =>
        if colors.length() > 0 {
          sb.write_view("<indexedColors>")
          for c in colors {
            let normalized = normalize_rgb_hex(c).replace_all(old="#", new="")
            let upper = normalized.to_upper()
            let rgb = if upper.length() == 6 { "FF" + upper } else { upper }
            sb.write_view("<rgbColor rgb=\"")
            sb.write_view(escape_xml_attr(rgb))
            sb.write_view("\"/>")
          }
          sb.write_view("</indexedColors>")
        }
      None => ()
    }
    match mru_colors_xml {
      Some(value) =>
        if value != "" {
          sb.write_view("<mruColors>")
          sb.write_view(value)
          sb.write_view("</mruColors>")
        }
      None => ()
    }
    sb.write_view("</colors>\n")
  }
  match styles_ext_lst_xml {
    Some(value) =>
      if value == "" {
        sb.write_view("  <extLst/>\n")
      } else {
        sb.write_view("  <extLst>")
        sb.write_view(value)
        sb.write_view("</extLst>\n")
      }
    None => ()
  }
  sb.write_view("</styleSheet>")
  sb.to_string()
}

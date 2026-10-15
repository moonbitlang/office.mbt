// Style-id -> CSS rule generation. Colors coming out of a workbook are
// unvalidated XML text; only a strict 6-hex value (after stripping an
// 8-hex ARGB alpha) may enter the stylesheet — anything else is omitted,
// never guessed, so `</style>` payloads cannot break out.

///|
/// The maximum digit width of the default font, per the Open XML stored
/// column-width formula (Calibri 11 at 96dpi).
const MAX_DIGIT_WIDTH : Double = 7.0

///|
/// Row height is in points; CSS pixels are pt * 4/3.
const ROW_HEIGHT_PT_TO_PX : Double = 4.0 / 3.0

///|
/// Open XML stored width -> pixels: Truncate(((256*width +
/// Truncate(128/MDW)) / 256) * MDW). Width 16 is 112px at MDW 7.
pub fn col_width_px(width : Double) -> Int32 {
  let fudge = (128.0 / MAX_DIGIT_WIDTH).floor()
  ((256.0 * width + fudge) / 256.0 * MAX_DIGIT_WIDTH).floor().to_int()
}

///|
pub fn row_height_px(points : Double) -> Int32 {
  (points * ROW_HEIGHT_PT_TO_PX + 0.5).to_int()
}

///|
/// Validates a workbook color into a `#RRGGBB` CSS literal: an 8-hex ARGB
/// drops its alpha, a 6-hex passes, anything else is `None`.
pub fn css_color(raw : String) -> String? {
  // The WHOLE value must be hex before any alpha stripping: "GG112233"
  // is malformed, not "#112233" with a funny alpha.
  if raw.length() != 6 && raw.length() != 8 {
    return None
  }
  for i in 0..<raw.length() {
    let c = raw[i].to_int()
    let ok = (c >= '0'.to_int() && c <= '9'.to_int()) ||
      (c >= 'a'.to_int() && c <= 'f'.to_int()) ||
      (c >= 'A'.to_int() && c <= 'F'.to_int())
    if !ok {
      return None
    }
  }
  let hex = if raw.length() == 8 { raw[2:].to_owned() } else { raw }
  Some("#" + hex)
}

///|
/// The CSS declarations for a resolved style, as `property: value;`
/// pairs, or `""` when nothing renderable is set. Pass `workbook` to resolve
/// theme and indexed colors; without it, only literal colors are emitted.
pub fn style_css(style : @xlsx.Style, workbook? : @xlsx.Workbook) -> String {
  let out = StringBuilder()
  match style.font {
    Some(font) => {
      if font.bold.unwrap_or(false) {
        out.write_string("font-weight:bold;")
      }
      if font.italic.unwrap_or(false) {
        out.write_string("font-style:italic;")
      }
      let decorations : Array[String] = []
      if font.strike.unwrap_or(false) {
        decorations.push("line-through")
      }
      if font.underline is Some(underline) && underline != "none" {
        decorations.push("underline")
      }
      if !decorations.is_empty() {
        let decoration = decorations.join(" ")
        out.write_string("text-decoration:\{decoration};")
      }
      match font.size {
        Some(size) if size > 0.0 => {
          let pt10 = (size * 10.0 + 0.5).to_int()
          out.write_string("font-size:\{pt10 / 10}.\{pt10 % 10}pt;")
        }
        _ => ()
      }
      match
        resolved_css_color(
          font.color,
          font.color_theme,
          font.color_indexed,
          font.color_tint,
          workbook,
        ) {
        Some(css) => out.write_string("color:\{css};")
        None => ()
      }
    }
    None => ()
  }
  match style.fill {
    Some(fill) =>
      if fill.typ == Some("gradient") {
        match gradient_css(fill) {
          Some(css) => out.write_string("background-image:\{css};")
          None => ()
        }
      } else if fill.typ.unwrap_or("pattern") == "pattern" &&
        fill.pattern.unwrap_or(1) == 1 {
        let raw = fill.colors.bind(colors => colors.get(0))
        match
          resolved_css_color(
            raw,
            fill.fg_theme,
            fill.fg_indexed,
            fill.fg_tint,
            workbook,
          ) {
          Some(css) => out.write_string("background-color:\{css};")
          _ => ()
        }
      }
    None => ()
  }
  match style.alignment {
    Some(alignment) => {
      match alignment.horizontal {
        Some("left") => out.write_string("text-align:left;")
        Some("center") => out.write_string("text-align:center;")
        Some("right") => out.write_string("text-align:right;")
        _ => ()
      }
      match alignment.vertical {
        Some("top") => out.write_string("vertical-align:top;")
        Some("center") => out.write_string("vertical-align:middle;")
        Some("bottom") => out.write_string("vertical-align:bottom;")
        _ => ()
      }
      if alignment.wrap_text.unwrap_or(false) {
        out.write_string("white-space:normal;")
      }
    }
    None => ()
  }
  match style.border {
    Some(borders) =>
      for border in borders {
        // An omitted OOXML border style means no border: a color-only
        // entry (style absent or zero) draws nothing.
        if border.style.unwrap_or(0) == 0 {
          continue
        }
        let side = match border.typ {
          "left" => "border-left"
          "right" => "border-right"
          "top" => "border-top"
          "bottom" => "border-bottom"
          _ => continue
        }
        // An unset color is Excel's default ink; malformed colors are omitted.
        let color = match border.color {
          Some(raw) =>
            match css_color(raw) {
              Some(css) => css
              None => continue
            }
          None => "#000000"
        }
        let line = match border.style.unwrap_or(0) {
          1 => "1px solid"
          2 => "2px solid"
          3 | 9 | 11 => "1px dashed"
          4 => "1px dotted"
          5 => "3px solid"
          6 => "3px double"
          7 => "0.5px solid"
          8 | 10 | 12 | 13 => "2px dashed"
          _ => continue
        }
        out.write_string("\{side}:\{line} \{color};")
      }
    None => ()
  }
  out.to_string()
}

///|
// Resolve only colors explicitly present in the source. Workbook context is
// optional so existing callers that supply literal colors remain supported.
fn resolved_css_color(
  raw : String?,
  theme : Int32?,
  indexed : Int32?,
  tint : Double?,
  workbook : @xlsx.Workbook?,
) -> String? {
  let theme_count = workbook
    .map(book => book.theme_colors.map(colors => colors.length()).unwrap_or(10))
    .unwrap_or(0)
  let color = match (raw, theme, indexed, workbook) {
    (_, Some(value), _, Some(book)) if value >= 0 && value < theme_count =>
      Some(book.get_base_color("", 0, theme_color=value))
    (Some(value), _, _, _) => Some(value)
    (_, _, Some(value), Some(book)) if value >= 0 && value < 64 =>
      Some(book.get_base_color("", value))
    _ => None
  }
  color.bind(value => {
    guard css_color(value) is Some(valid) else { return None }
    match tint {
      Some(t) if t >= -1.0 && t <= 1.0 =>
        css_color(@xlsx.theme_color(valid[1:].to_owned(), t))
      Some(_) => None
      None => Some(valid)
    }
  })
}

///|
// OOXML linear gradient degrees run clockwise from left to right; CSS degrees
// start at the upward direction. Symmetric variants repeat the first color.
fn gradient_css(fill : @xlsx.Fill) -> String? {
  guard fill.colors is Some(colors) && colors.length() == 2 else { return None }
  guard gradient_color(colors[0]) is Some(first) &&
    gradient_color(colors[1]) is Some(last) else {
    return None
  }
  let shading = fill.shading.unwrap_or(0)
  let degree = match shading {
    0 | 2 => 180
    1 => 0
    3 | 5 => 90
    4 => 270
    6 | 8 => 135
    7 => 345
    9 | 11 => 225
    10 => 45
    // Path gradients have different geometry and are not approximated here.
    _ => return None
  }
  let stops = if shading is (2 | 5 | 8 | 11) {
    "\{first} 0%,\{last} 50%,\{first} 100%"
  } else {
    "\{first} 0%,\{last} 100%"
  }
  Some("linear-gradient(\{degree}deg,\{stops})")
}

///|
// The fill API accepts one leading hash; validate the whole remaining value.
fn gradient_color(raw : String) -> String? {
  css_color(
    if raw.has_prefix("#") && (raw.length() == 7 || raw.length() == 9) {
      raw[1:].to_owned()
    } else {
      raw
    },
  )
}

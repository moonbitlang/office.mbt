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
pub fn col_width_px(width : Double) -> Int {
  let fudge = (128.0 / MAX_DIGIT_WIDTH).floor()
  ((256.0 * width + fudge) / 256.0 * MAX_DIGIT_WIDTH).floor().to_int()
}

///|
pub fn row_height_px(points : Double) -> Int {
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
/// pairs, or `""` when nothing renderable is set. Theme/indexed colors
/// have no literal value here and are omitted (never guessed).
pub fn style_css(style : @xlsx.Style) -> String {
  let out = StringBuilder()
  match style.font {
    Some(font) => {
      if font.bold.unwrap_or(false) {
        out.write_string("font-weight:bold;")
      }
      if font.italic.unwrap_or(false) {
        out.write_string("font-style:italic;")
      }
      if font.strike.unwrap_or(false) {
        out.write_string("text-decoration:line-through;")
      }
      match font.size {
        Some(size) if size > 0.0 => {
          let pt10 = (size * 10.0 + 0.5).to_int()
          out.write_string("font-size:\{pt10 / 10}.\{pt10 % 10}pt;")
        }
        _ => ()
      }
      match font.color {
        Some(color) =>
          match css_color(color) {
            Some(css) => out.write_string("color:\{css};")
            None => ()
          }
        None => ()
      }
    }
    None => ()
  }
  match style.fill {
    // Only a solid pattern fill renders (typ "pattern", patternType
    // solid = 1, matching what Fill::solid writes); gradients and other
    // pattern types are omitted per the documented fidelity limits.
    Some(fill) =>
      if fill.typ.unwrap_or("pattern") == "pattern" &&
        fill.pattern.unwrap_or(1) == 1 {
        match fill.colors {
          Some(colors) if colors.length() > 0 =>
            match css_color(colors[0]) {
              Some(css) => out.write_string("background-color:\{css};")
              None => ()
            }
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
        let side = match border.typ {
          "left" => "border-left"
          "right" => "border-right"
          "top" => "border-top"
          "bottom" => "border-bottom"
          _ => continue
        }
        // An unset color is Excel's default ink; a malformed color means
        // the side is omitted, never guessed. Border line styles are all
        // rendered as thin solid in v1 (documented limitation).
        let color = match border.color {
          Some(raw) =>
            match css_color(raw) {
              Some(css) => css
              None => continue
            }
          None => "#000000"
        }
        out.write_string("\{side}:1px solid \{color};")
      }
    None => ()
  }
  out.to_string()
}

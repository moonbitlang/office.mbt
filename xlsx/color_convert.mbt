///|
fn clamp_byte(value : Int) -> Byte {
  let clamped = if value < 0 { 0 } else if value > 255 { 255 } else { value }
  clamped.to_byte()
}

///|
fn hex_byte(value : Byte) -> String {
  let text = value.to_int().to_string(radix=16).to_upper()
  if text.length() == 1 {
    "0\{text}"
  } else if text.length() == 0 {
    "00"
  } else {
    text
  }
}

///|
fn parse_hex_byte(text : StringView, start : Int) -> Int {
  let end = start + 2
  if start < 0 || text.length() < end {
    return 0
  }
  let view = text[start:end]
  @string.parse_int(view, base=16) catch {
    _ => 0
  }
}

///|
pub fn rgb_to_hsl(r : Byte, g : Byte, b : Byte) -> (Double, Double, Double) {
  let fr = r.to_double() / 255.0
  let fg = g.to_double() / 255.0
  let fb = b.to_double() / 255.0
  let max_val = if fr > fg {
    if fr > fb {
      fr
    } else {
      fb
    }
  } else if fg > fb {
    fg
  } else {
    fb
  }
  let min_val = if fr < fg {
    if fr < fb {
      fr
    } else {
      fb
    }
  } else if fg < fb {
    fg
  } else {
    fb
  }
  let l = (max_val + min_val) / 2.0
  if max_val == min_val {
    return (0.0, 0.0, l)
  }
  let d = max_val - min_val
  let s = if l > 0.5 {
    d / (2.0 - max_val - min_val)
  } else {
    d / (max_val + min_val)
  }
  let mut h = if max_val == fr {
    let mut value = (fg - fb) / d
    if fg < fb {
      value = value + 6.0
    }
    value
  } else if max_val == fg {
    (fb - fr) / d + 2.0
  } else {
    (fr - fg) / d + 4.0
  }
  h = h / 6.0
  (h, s, l)
}

///|
fn hue_to_rgb(p : Double, q : Double, t : Double) -> Double {
  let mut value = t
  if value < 0.0 {
    value = value + 1.0
  }
  if value > 1.0 {
    value = value - 1.0
  }
  if value < 1.0 / 6.0 {
    return p + (q - p) * 6.0 * value
  }
  if value < 0.5 {
    return q
  }
  if value < 2.0 / 3.0 {
    return p + (q - p) * (2.0 / 3.0 - value) * 6.0
  }
  p
}

///|
pub fn hsl_to_rgb(h : Double, s : Double, l : Double) -> (Byte, Byte, Byte) {
  let (fr, fg, fb) = if s == 0.0 {
    (l, l, l)
  } else {
    let q = if l < 0.5 { l * (1.0 + s) } else { l + s - s * l }
    let p = 2.0 * l - q
    (
      hue_to_rgb(p, q, h + 1.0 / 3.0),
      hue_to_rgb(p, q, h),
      hue_to_rgb(p, q, h - 1.0 / 3.0),
    )
  }
  let r = clamp_byte((fr * 255.0 + 0.5).to_int())
  let g = clamp_byte((fg * 255.0 + 0.5).to_int())
  let b = clamp_byte((fb * 255.0 + 0.5).to_int())
  (r, g, b)
}

///|
pub fn theme_color(base_color : String, tint : Double) -> String {
  if tint == 0.0 {
    return "FF\{base_color}"
  }
  let view = base_color[:]
  let r_val = parse_hex_byte(view, 0)
  let g_val = parse_hex_byte(view, 2)
  let b_val = parse_hex_byte(view, 4)
  let (h, s, l) = rgb_to_hsl(
    clamp_byte(r_val),
    clamp_byte(g_val),
    clamp_byte(b_val),
  )
  let adjusted_l = if tint < 0.0 {
    l * (1.0 + tint)
  } else {
    l * (1.0 - tint) + (1.0 - (1.0 - tint))
  }
  let (r, g, b) = hsl_to_rgb(h, s, adjusted_l)
  "FF\{hex_byte(r)}\{hex_byte(g)}\{hex_byte(b)}"
}

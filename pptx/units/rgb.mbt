// RGB color (8 bits per channel).
//
// OOXML's `ST_HexColorRGB` is six uppercase-or-lowercase hex digits, e.g.
// `"FF0000"` for red. We accept an optional leading `#` for ergonomic input
// but always emit without it.

///|
/// 24-bit RGB color. Each channel is 0–255 (unchecked at construction;
/// values outside that range round-trip but render undefined behaviour).
#derive(Eq, Debug)
pub struct RgbColor {
  r : Int32
  g : Int32
  b : Int32
}

///|
pub extend RgbColor with @debug.Debug::{to_repr}

///|
pub extend RgbColor with Eq::{not_equal, equal}

///|
pub extend RgbColor with Show::{to_string, output}

///|
/// Construct an `RgbColor` from three 0–255 channel values.
/// Each channel is clamped to `[0, 255]`.
pub fn RgbColor::new(r : Int32, g : Int32, b : Int32) -> RgbColor {
  { r, g, b, }
}

///|
/// Parse a six-hex-digit color string with optional leading `#`.
/// Raises `UnitsError::InvalidHexColor` for any other shape.
pub fn RgbColor::parse_hex(s : String) -> RgbColor raise UnitsError {
  let stripped = match s {
    ['#', .. rest] => rest
    rest => rest
  }
  guard stripped is [r_hi, r_lo, g_hi, g_lo, b_hi, b_lo] else {
    raise InvalidHexColor(s)
  }
  let r = parse_hex_byte(r_hi, r_lo, s)
  let g = parse_hex_byte(g_hi, g_lo, s)
  let b = parse_hex_byte(b_hi, b_lo, s)
  { r, g, b, }
}

///|
/// Render as an uppercase six-hex-digit string with no leading `#`,
/// matching OOXML's `ST_HexColorRGB` wire format.
pub fn RgbColor::to_hex(self : RgbColor) -> String {
  hex_byte(self.r) + hex_byte(self.g) + hex_byte(self.b)
}

// --- internal helpers ---

///|
fn parse_hex_byte(
  hi : Char,
  lo : Char,
  original : String,
) -> Int32 raise UnitsError {
  let h = hex_digit(hi)
  let l = hex_digit(lo)
  match (h, l) {
    (Some(h), Some(l)) => h * 16 + l
    _ => raise InvalidHexColor(original)
  }
}

///|
fn hex_digit(c : Char) -> Int32? {
  let code = c.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    Some(code - '0'.to_int())
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    Some(code - 'a'.to_int() + 10)
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    Some(code - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn hex_byte(n : Int32) -> String {
  // Mask to a byte so over/underflows still produce two hex digits without
  // panicking; OOXML callers should keep values in 0–255 anyway.
  let v = n.land(0xFF)
  "\{hex_char(v / 16)}\{hex_char(v % 16)}"
}

///|
fn hex_char(n : Int32) -> Char {
  let n = n.land(0xF)
  // Safe: n is masked to 0-15 and the resulting code points are ASCII '0'-'9' / 'A'-'F'.
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('A'.to_int() + (n - 10)).unsafe_to_char()
  }
}

///|
pub impl Show for RgbColor with fn output(self, logger) {
  logger.write_string("RgbColor(#")
  logger.write_string(self.to_hex())
  logger.write_string(")")
}

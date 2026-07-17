///|
fn is_utf8_encoding(value : StringView) -> Bool {
  let normalized = value.to_owned().to_lower()
  normalized == "utf-8" || normalized == "utf8"
}

///|
fn is_encoding_char(value : Byte) -> Bool {
  (value >= b'a' && value <= b'z') ||
  (value >= b'A' && value <= b'Z') ||
  (value >= b'0' && value <= b'9') ||
  value == b'-' ||
  value == b'_' ||
  value == b'.'
}

///|
fn xml_encoding(bytes : BytesView) -> String? {
  let len = bytes.length()
  if len < 5 {
    return None
  }
  let prefix_len = if len < 256 { len } else { 256 }
  let prefix = bytes[:prefix_len]
  let start = if prefix_len >= 3 && prefix[:3].equal(b"\xEF\xBB\xBF") {
    3
  } else {
    0
  }
  if prefix_len < start + 5 || !prefix[start:start + 5].equal(b"<?xml") {
    return None
  }
  let (needle, quote) = match prefix.find(b"encoding=\"") {
    Some(pos) => (pos + b"encoding=\"".length(), b'"')
    None =>
      match prefix.find(b"encoding='") {
        Some(pos) => (pos + b"encoding='".length(), b'\'')
        None => return None
      }
  }
  let mut i = needle
  while i < prefix_len && prefix[i] != quote {
    if !is_encoding_char(prefix[i]) {
      return None
    }
    i = i + 1
  }
  if i <= needle || i >= prefix_len {
    return None
  }
  let slice = prefix[needle:i]
  let value = @encoding/utf8.decode(slice) catch { _ => return None }
  Some(value)
}

///|
fn decode_utf8(
  bytes : BytesView,
  transcoder : ((String, Bytes) -> String raise XlsxError)?,
) -> String raise XlsxError {
  // A UTF-16 byte-order mark is authoritative: a UTF-16 document's
  // <?xml?> declaration is itself UTF-16 bytes, so the ASCII scan below
  // cannot detect it. Fall back to the declared encoding otherwise.
  let declared = match utf16_bom_label(bytes) {
    Some(label) => Some(label)
    None =>
      match xml_encoding(bytes) {
        Some(encoding) =>
          if is_utf8_encoding(encoding) {
            None
          } else {
            Some(encoding)
          }
        None => None
      }
  }
  match declared {
    Some(encoding) =>
      match transcoder {
        // A caller-supplied transcoder replaces the default entirely,
        // like Go's SetCharsetReader.
        Some(value) => return value(encoding, bytes.to_owned())
        None =>
          match builtin_charset_decode(encoding, bytes) {
            Some(text) => return text
            None =>
              raise InvalidXml(
                msg="xml encoding \{encoding} requires charset transcoder",
              )
          }
      }
    None => ()
  }
  @encoding/utf8.decode(bytes) catch {
    _ => raise InvalidXml(msg="invalid utf8")
  }
}

///|
/// OOXML numeric attributes must be finite before they enter the workbook
/// model. MoonBit's parser accepts IEEE NaN and infinities, but those values
/// cannot be represented by JSON and make comparisons in layout/style logic
/// non-deterministic.
fn parse_finite_double_for_read(
  value : StringView,
  message : String,
) -> Double raise XlsxError {
  let parsed = @string.parse_double(value) catch {
    _ => raise InvalidXml(msg=message)
  }
  if parsed.is_nan() || parsed.is_inf() {
    raise InvalidXml(msg=message)
  }
  parsed
}

///|
fn parse_default_font(xml : StringView) -> String {
  let xml_str = xml.to_owned()
  let marker = "<fonts"
  match xml_str.find(marker) {
    None => "Calibri"
    Some(start) => {
      let rest = xml_str[start + marker.length():]
      match rest.find("<name") {
        None => "Calibri"
        Some(name_start) => {
          let name_rest = rest[name_start + 5:]
          match name_rest.find(">") {
            None => "Calibri"
            Some(end) => {
              let tag = name_rest[:end]
              let value_result : Result[String?, Error] = Ok(
                attr_value(tag, "val"),
              ) catch {
                e => Err(e)
              }
              match value_result {
                Ok(value) =>
                  match value {
                    Some(text) => unescape_xml_text(text)
                    None => "Calibri"
                  }
                Err(_) => "Calibri"
              }
            }
          }
        }
      }
    }
  }
}

///|
fn parse_font_entry(xml : StringView) -> Font raise XlsxError {
  let font = Font::new()
  match tag_attributes_in(xml, "b") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => if parse_bool_attr(value) { font.bold = Some(true) }
        None => font.bold = Some(true)
      }
    None => ()
  }
  match tag_attributes_in(xml, "i") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => if parse_bool_attr(value) { font.italic = Some(true) }
        None => font.italic = Some(true)
      }
    None => ()
  }
  match tag_attributes_in(xml, "strike") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => if parse_bool_attr(value) { font.strike = Some(true) }
        None => font.strike = Some(true)
      }
    None => ()
  }
  match tag_attributes_in(xml, "outline") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => if parse_bool_attr(value) { font.outline = Some(true) }
        None => font.outline = Some(true)
      }
    None => ()
  }
  match tag_attributes_in(xml, "shadow") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => if parse_bool_attr(value) { font.shadow = Some(true) }
        None => font.shadow = Some(true)
      }
    None => ()
  }
  match tag_attributes_in(xml, "condense") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => if parse_bool_attr(value) { font.condense = Some(true) }
        None => font.condense = Some(true)
      }
    None => ()
  }
  match tag_attributes_in(xml, "extend") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => if parse_bool_attr(value) { font.extended = Some(true) }
        None => font.extended = Some(true)
      }
    None => ()
  }
  match tag_attributes_in(xml, "u") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => font.underline = Some(unescape_xml_text(value))
        None => font.underline = Some("single")
      }
    None => ()
  }
  match tag_attributes_in(xml, "sz") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) =>
          font.size = Some(
            parse_finite_double_for_read(value, "font sz invalid"),
          )
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(xml, "charset") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) =>
          try @string.parse_int(value, base=10) catch {
            _ => raise InvalidXml(msg="font charset invalid")
          } noraise {
            val => font.charset = Some(val)
          }
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(xml, "name") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => font.family = Some(unescape_xml_text(value))
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(xml, "family") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) =>
          try @string.parse_int(value, base=10) catch {
            _ => raise InvalidXml(msg="font family invalid")
          } noraise {
            val => if val != 2 { font.family_number = Some(val) }
          }
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(xml, "vertAlign") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => font.vert_align = Some(unescape_xml_text(value))
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(xml, "scheme") {
    Some(tag) =>
      match attr_value(tag, "val") {
        Some(value) => font.scheme = Some(unescape_xml_text(value))
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(xml, "color") {
    Some(tag) => {
      match attr_value(tag, "rgb") {
        Some(value) => {
          let rgb = unescape_xml_text(value)
          font.color = Some(normalize_rgb_hex(rgb))
        }
        None => ()
      }
      match attr_value(tag, "theme") {
        Some(value) =>
          try @string.parse_int(value, base=10) catch {
            _ => raise InvalidXml(msg="font color theme invalid")
          } noraise {
            val => font.color_theme = Some(val)
          }
        None => ()
      }
      match attr_value(tag, "indexed") {
        Some(value) =>
          try @string.parse_int(value, base=10) catch {
            _ => raise InvalidXml(msg="font color indexed invalid")
          } noraise {
            val => font.color_indexed = Some(val)
          }
        None => ()
      }
      match attr_value(tag, "tint") {
        Some(value) =>
          font.color_tint = Some(
            parse_finite_double_for_read(value, "font color tint invalid"),
          )
        None => ()
      }
    }
    None => ()
  }
  font
}

///|
fn parse_fonts(xml : StringView) -> Array[Font] raise XlsxError {
  let fonts : Array[Font] = []
  let body = match extract_tag_body(xml, "fonts") {
    Some(value) => value
    None => {
      fonts.push(Font::new())
      return fonts
    }
  }
  let mut first = true
  for chunk in body.split("<font") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let open_end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let rest = text[open_end + 1:]
    let end = match rest.find("</font>") {
      Some(pos) => pos
      None => continue
    }
    let content = rest[:end]
    fonts.push(parse_font_entry(content))
  }
  if fonts.length() == 0 {
    fonts.push(Font::new())
  }
  fonts
}

///|
fn parse_fill_entry(xml : StringView) -> Fill raise XlsxError {
  let fill = Fill::new()
  let patterns : Array[String] = [
    "none", "solid", "mediumGray", "darkGray", "lightGray", "darkHorizontal", "darkVertical",
    "darkDown", "darkUp", "darkGrid", "darkTrellis", "lightHorizontal", "lightVertical",
    "lightDown", "lightUp", "lightGrid", "lightTrellis", "gray125", "gray0625",
  ]
  fn parse_rgb_color(rgb : StringView) -> (String, Int?) {
    // Strip an 8-char value's alpha only when the alpha really is hex —
    // a malformed value must stay malformed (GG112233 is not #112233).
    // Char-level, since parse_int would accept a signed "+1"/"-1".
    fn is_hex(c : Int) -> Bool {
      (c >= '0'.to_int() && c <= '9'.to_int()) ||
      (c >= 'a'.to_int() && c <= 'f'.to_int()) ||
      (c >= 'A'.to_int() && c <= 'F'.to_int())
    }

    let alpha_is_hex = rgb.length() == 8 &&
      is_hex(rgb[0].to_int()) &&
      is_hex(rgb[1].to_int())
    if alpha_is_hex {
      let alpha = parse_hex_byte(rgb, 0)
      let opacity = (alpha * 100 + 127) / 255
      let t = 100 - opacity
      let transparency = if t <= 0 { None } else { Some(t) }
      let color = rgb[2:].to_owned()
      (color, transparency)
    } else {
      (rgb.to_owned(), None)
    }
  }

  match tag_attributes_in(xml, "gradientFill") {
    Some(tag) => {
      fill.typ = Some("gradient")
      let bottom = match attr_value(tag, "bottom") {
        Some(value) =>
          parse_finite_double_for_read(value, "gradientFill bottom invalid")
        None => 0.0
      }
      let degree = match attr_value(tag, "degree") {
        Some(value) =>
          parse_finite_double_for_read(value, "gradientFill degree invalid")
        None => 0.0
      }
      let left = match attr_value(tag, "left") {
        Some(value) =>
          parse_finite_double_for_read(value, "gradientFill left invalid")
        None => 0.0
      }
      let right = match attr_value(tag, "right") {
        Some(value) =>
          parse_finite_double_for_read(value, "gradientFill right invalid")
        None => 0.0
      }
      let top = match attr_value(tag, "top") {
        Some(value) =>
          parse_finite_double_for_read(value, "gradientFill top invalid")
        None => 0.0
      }
      let typ = match attr_value(tag, "type") {
        Some(value) => unescape_xml_text(value)
        None => ""
      }
      let mut transparency : Int? = None
      let stop_positions : Array[Double] = []
      let stop_colors : Array[String] = []
      match extract_tag_body(xml, "gradientFill") {
        Some(body) => {
          let mut first = true
          for chunk in body.split("<stop") {
            if first {
              first = false
              continue
            }
            let text = chunk.to_owned()
            let open_end = match text.find(">") {
              Some(pos) => pos
              None => continue
            }
            let open_tag = text[:open_end]
            match attr_value(open_tag, "position") {
              Some(value) =>
                stop_positions.push(
                  parse_finite_double_for_read(
                    value, "gradientFill stop position invalid",
                  ),
                )
              None => stop_positions.push(0.0)
            }
            let rest = text[open_end + 1:]
            let end = match rest.find("</stop>") {
              Some(pos) => pos
              None => continue
            }
            let content = rest[:end]
            match tag_attributes_in(content, "color") {
              Some(color_tag) =>
                match attr_value(color_tag, "rgb") {
                  Some(value) => {
                    let rgb = unescape_xml_text(value)
                    let (c, t) = parse_rgb_color(rgb)
                    stop_colors.push(c)
                    match (transparency, t) {
                      (None, Some(v)) => transparency = Some(v)
                      _ => ()
                    }
                  }
                  None => ()
                }
              None => ()
            }
          }
        }
        None => ()
      }
      let mut shading = 0
      for i in 0..<fill_gradient_variants.length() {
        let v = fill_gradient_variants[i]
        if v.bottom == bottom &&
          v.degree == degree &&
          v.left == left &&
          v.right == right &&
          v.top == top &&
          v.typ == typ &&
          v.stops == stop_positions {
          shading = i
          break
        }
      }
      fill.shading = Some(shading)
      match (stop_colors.get(0), stop_colors.get(1)) {
        (Some(c1), Some(c2)) => fill.colors = Some([c1, c2])
        _ => ()
      }
      match transparency {
        Some(v) => fill.transparency = Some(v)
        None => ()
      }
    }
    None => ()
  }
  match tag_attributes_in(xml, "patternFill") {
    Some(tag) => {
      let pattern_type = match attr_value(tag, "patternType") {
        Some(value) => unescape_xml_text(value)
        None => "none"
      }
      let mut pattern = 0
      let mut found = false
      for i in 0..<patterns.length() {
        if patterns[i] == pattern_type {
          pattern = i
          found = true
        }
      }
      fill.typ = Some("pattern")
      if found {
        fill.pattern = Some(pattern)
      } else {
        fill.pattern = Some(0)
      }
      let mut fg_color : String? = None
      let mut bg_color : String? = None
      let mut transparency : Int? = None
      match tag_attributes_in(xml, "fgColor") {
        Some(color_tag) => {
          match attr_value(color_tag, "theme") {
            Some(value) =>
              try @string.parse_int(value, base=10) catch {
                _ => raise InvalidXml(msg="fill fgColor theme invalid")
              } noraise {
                val => fill.fg_theme = Some(val)
              }
            None => ()
          }
          match attr_value(color_tag, "indexed") {
            Some(value) =>
              try @string.parse_int(value, base=10) catch {
                _ => raise InvalidXml(msg="fill fgColor indexed invalid")
              } noraise {
                val => fill.fg_indexed = Some(val)
              }
            None => ()
          }
          match attr_value(color_tag, "tint") {
            Some(value) =>
              fill.fg_tint = Some(
                parse_finite_double_for_read(value, "fill fgColor tint invalid"),
              )
            None => ()
          }
          match attr_value(color_tag, "rgb") {
            Some(value) => {
              let rgb = unescape_xml_text(value)
              let (c, t) = parse_rgb_color(rgb)
              fg_color = Some(c)
              match t {
                Some(v) => transparency = Some(v)
                None => ()
              }
            }
            None => ()
          }
        }
        None => ()
      }
      match tag_attributes_in(xml, "bgColor") {
        Some(color_tag) => {
          match attr_value(color_tag, "theme") {
            Some(value) =>
              try @string.parse_int(value, base=10) catch {
                _ => raise InvalidXml(msg="fill bgColor theme invalid")
              } noraise {
                val => fill.bg_theme = Some(val)
              }
            None => ()
          }
          match attr_value(color_tag, "indexed") {
            Some(value) =>
              try @string.parse_int(value, base=10) catch {
                _ => raise InvalidXml(msg="fill bgColor indexed invalid")
              } noraise {
                val => fill.bg_indexed = Some(val)
              }
            None => ()
          }
          match attr_value(color_tag, "tint") {
            Some(value) =>
              fill.bg_tint = Some(
                parse_finite_double_for_read(value, "fill bgColor tint invalid"),
              )
            None => ()
          }
          match attr_value(color_tag, "rgb") {
            Some(value) => {
              let rgb = unescape_xml_text(value)
              let (c, t) = parse_rgb_color(rgb)
              bg_color = Some(c)
              match t {
                Some(v) => transparency = Some(v)
                None => ()
              }
            }
            None => ()
          }
        }
        None => ()
      }
      let colors : Array[String] = []
      match fg_color {
        Some(c) => colors.push(c)
        None => ()
      }
      match bg_color {
        Some(c) => colors.push(c)
        None => ()
      }
      if colors.length() > 0 {
        fill.colors = Some(colors)
      }
      match transparency {
        Some(v) => fill.transparency = Some(v)
        None => ()
      }
      fill
    }
    None => fill
  }
}

///|
fn parse_fills(xml : StringView) -> Array[Fill] raise XlsxError {
  let fills : Array[Fill] = []
  let body = match extract_tag_body(xml, "fills") {
    Some(value) => value
    None => return fills
  }
  let mut first = true
  for chunk in body.split("<fill") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let open_end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let open_tag = text[:open_end]
    if open_tag.has_suffix("/") {
      fills.push(Fill::new())
      continue
    }
    let rest = text[open_end + 1:]
    let end = match rest.find("</fill>") {
      Some(pos) => pos
      None => continue
    }
    let content = rest[:end]
    fills.push(parse_fill_entry(content))
  }
  fills
}

///|
fn parse_border_entry(
  border_tag : StringView,
  xml : StringView,
) -> Array[Border] raise XlsxError {
  let border_styles : Array[String] = [
    "none", "thin", "medium", "dashed", "dotted", "thick", "double", "hair", "mediumDashed",
    "dashDot", "mediumDashDot", "dashDotDot", "mediumDashDotDot", "slantDashDot",
  ]
  fn parse_side(
    xml : StringView,
    side : StringView,
  ) -> Border? raise XlsxError {
    let tag = match tag_attributes_in(xml, side) {
      Some(value) => value
      None => return None
    }
    let style_name = match attr_value(tag, "style") {
      Some(value) => unescape_xml_text(value)
      None => "none"
    }
    let mut style = 0
    for i in 0..<border_styles.length() {
      if border_styles[i] == style_name {
        style = i
      }
    }
    let mut color : String? = None
    match extract_tag_body_from(xml, side) {
      Some(body) =>
        match tag_attributes_in(body, "color") {
          Some(color_tag) =>
            match attr_value(color_tag, "rgb") {
              Some(value) => color = Some(unescape_xml_text(value))
              None => ()
            }
          None => ()
        }
      None => ()
    }
    match color {
      Some(rgb) =>
        Some(
          Border::with_values(
            side.to_owned(),
            color=normalize_rgb_hex(rgb),
            style~,
          ),
        )
      None =>
        if style > 0 {
          Some(Border::with_values(side.to_owned(), style~))
        } else {
          None
        }
    }
  }

  let diagonal_up = match attr_value(border_tag, "diagonalUp") {
    Some(value) => parse_bool_attr(value)
    None => false
  }
  let diagonal_down = match attr_value(border_tag, "diagonalDown") {
    Some(value) => parse_bool_attr(value)
    None => false
  }
  let borders : Array[Border] = []
  match parse_side(xml, "left") {
    Some(b) => borders.push(b)
    None => ()
  }
  match parse_side(xml, "right") {
    Some(b) => borders.push(b)
    None => ()
  }
  match parse_side(xml, "top") {
    Some(b) => borders.push(b)
    None => ()
  }
  match parse_side(xml, "bottom") {
    Some(b) => borders.push(b)
    None => ()
  }
  let diagonal = parse_side(xml, "diagonal")
  match diagonal {
    Some(b) =>
      if diagonal_up || diagonal_down {
        let diagonal_style = match b.style {
          Some(value) => value
          None => 0
        }
        if diagonal_up {
          match b.color {
            Some(color) =>
              borders.push(
                Border::with_values("diagonalUp", color~, style=diagonal_style),
              )
            None =>
              borders.push(
                Border::with_values("diagonalUp", style=diagonal_style),
              )
          }
        }
        if diagonal_down {
          match b.color {
            Some(color) =>
              borders.push(
                Border::with_values(
                  "diagonalDown",
                  color~,
                  style=diagonal_style,
                ),
              )
            None =>
              borders.push(
                Border::with_values("diagonalDown", style=diagonal_style),
              )
          }
        }
      } else {
        borders.push(b)
      }
    None => ()
  }
  match parse_side(xml, "vertical") {
    Some(b) => borders.push(b)
    None => ()
  }
  match parse_side(xml, "horizontal") {
    Some(b) => borders.push(b)
    None => ()
  }
  borders
}

///|
fn parse_borders(xml : StringView) -> Array[Array[Border]] raise XlsxError {
  let borders : Array[Array[Border]] = []
  let body = match extract_tag_body(xml, "borders") {
    Some(value) => value
    None => {
      borders.push([])
      return borders
    }
  }
  let mut first = true
  for chunk in body.split("<border") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let open_end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let open_tag = text[:open_end]
    if open_tag.has_suffix("/") {
      borders.push([])
      continue
    }
    let rest = text[open_end + 1:]
    let end = match rest.find("</border>") {
      Some(pos) => pos
      None => continue
    }
    let content = rest[:end]
    borders.push(parse_border_entry(open_tag, content))
  }
  if borders.length() == 0 {
    borders.push([])
  }
  borders
}

///|
fn parse_protection_entry(xml : StringView) -> Protection? raise XlsxError {
  let tag = match tag_attributes_in(xml, "protection") {
    Some(value) => value
    None => return None
  }
  let protection = Protection::new()
  match attr_value(tag, "hidden") {
    Some(value) => protection.hidden = Some(parse_bool_attr(value))
    None => ()
  }
  match attr_value(tag, "locked") {
    Some(value) => protection.locked = Some(parse_bool_attr(value))
    None => ()
  }
  match (protection.hidden, protection.locked) {
    (None, None) => None
    _ => Some(protection)
  }
}

///|
fn parse_alignment_entry(xml : StringView) -> Alignment? raise XlsxError {
  let tag = match tag_attributes_in(xml, "alignment") {
    Some(value) => value
    None => return None
  }
  let alignment = Alignment::new()
  match attr_value(tag, "horizontal") {
    Some(value) => alignment.horizontal = Some(unescape_xml_text(value))
    None => ()
  }
  match attr_value(tag, "vertical") {
    Some(value) => alignment.vertical = Some(unescape_xml_text(value))
    None => ()
  }
  match attr_value(tag, "wrapText") {
    Some(value) => alignment.wrap_text = Some(parse_bool_attr(value))
    None => ()
  }
  match attr_value(tag, "textRotation") {
    Some(value) =>
      alignment.text_rotation = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="textRotation invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "indent") {
    Some(value) =>
      alignment.indent = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="indent invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "shrinkToFit") {
    Some(value) => alignment.shrink_to_fit = Some(parse_bool_attr(value))
    None => ()
  }
  match attr_value(tag, "justifyLastLine") {
    Some(value) => alignment.justify_last_line = Some(parse_bool_attr(value))
    None => ()
  }
  match attr_value(tag, "readingOrder") {
    Some(value) =>
      alignment.reading_order = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="readingOrder invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "relativeIndent") {
    Some(value) =>
      alignment.relative_indent = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="relativeIndent invalid")
        },
      )
    None => ()
  }
  match
    (
      alignment.horizontal,
      alignment.vertical,
      alignment.wrap_text,
      alignment.text_rotation,
      alignment.indent,
      alignment.shrink_to_fit,
      alignment.justify_last_line,
      alignment.reading_order,
      alignment.relative_indent,
    ) {
    (None, None, None, None, None, None, None, None, None) => None
    _ => Some(alignment)
  }
}

///|
fn parse_pivot_table_name(xml : StringView) -> String raise XlsxError {
  match tag_attributes_in(xml, "pivotTableDefinition") {
    Some(tag) =>
      match attr_value(tag, "name") {
        Some(value) => unescape_xml_text(value)
        None => ""
      }
    None => ""
  }
}

///|
fn parse_defined_names(
  xml : StringView,
  sheet_names : Array[String],
) -> Array[DefinedName] raise XlsxError {
  let names : Array[DefinedName] = []
  let body = match extract_tag_body(xml, "definedNames") {
    Some(value) => value
    None => return names
  }
  let mut first = true
  for chunk in body.split("<definedName ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="definedName tag not closed")
    }
    let tag = text[:end]
    let name = match attr_value(tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="definedName name missing")
    }
    let comment = match attr_value(tag, "comment") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let local_id = match attr_value(tag, "localSheetId") {
      Some(value) =>
        Some(
          @string.parse_int(value, base=10) catch {
            _ => raise InvalidXml(msg="definedName localSheetId invalid")
          },
        )
      None => None
    }
    let rest = text[end + 1:]
    let data_end = match rest.find("</definedName>") {
      Some(pos) => pos
      None => raise InvalidXml(msg="definedName close missing")
    }
    let data = rest[:data_end]
    let scope = match local_id {
      Some(id) =>
        if id >= 0 && id < sheet_names.length() {
          sheet_names[id]
        } else {
          raise InvalidXml(msg="definedName localSheetId missing")
        }
      None => "Workbook"
    }
    names.push({ name, refers_to: unescape_xml_text(data), scope, comment })
  }
  names
}

///|
fn parse_merge_cells(xml : StringView) -> Array[String] raise XlsxError {
  let merged : Array[String] = []
  let body = match extract_tag_body(xml, "mergeCells") {
    Some(value) => value
    None => return merged
  }
  let mut first = true
  for chunk in body.split("<mergeCell ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="mergeCell tag not closed")
        }
    }
    let tag = text[:end]
    let ref_value = match attr_value(tag, "ref") {
      Some(value) => value
      None => raise InvalidXml(msg="mergeCell ref missing")
    }
    let normalized = if ref_value.contains(":") {
      normalize_range_ref(ref_value)
    } else {
      let (row, col) = cell_ref_to_rc(ref_value)
      let cell_ref = cell_ref_from(row, col)
      "\{cell_ref}:\{cell_ref}"
    }
    merged.push(normalized)
  }
  merged
}

///|
fn parse_data_validations(
  xml : StringView,
  budget? : ReadBudget,
) -> Array[String] raise XlsxError {
  let validations : Array[String] = []
  let body = match extract_tag_body(xml, "dataValidations") {
    Some(value) => value
    None => return validations
  }
  let mut first = true
  for chunk in body.split("<dataValidation ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let close_tag = "</dataValidation>"
    let full = match text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = text[:end]
        "<dataValidation \{slice.to_owned()}"
      }
      None => {
        let end = match text.find("/>") {
          Some(pos) => pos + 2
          None => raise InvalidXml(msg="dataValidation tag not closed")
        }
        let slice = text[:end]
        "<dataValidation \{slice.to_owned()}"
      }
    }
    validations.push(
      normalize_xml_sqref_attr_for_read(
        full,
        "dataValidation",
        "data validation",
        budget?,
      ),
    )
  }
  validations
}

///|
fn parse_data_validations_x14(
  xml : StringView,
  budget? : ReadBudget,
) -> Array[String] raise XlsxError {
  let validations : Array[String] = []
  let xml_str = xml.to_owned()
  if !xml_str.contains("<x14:dataValidation") {
    return validations
  }
  let mut first = true
  for chunk in xml_str.split("<x14:dataValidation ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let close_tag = "</x14:dataValidation>"
    let end = match text.find(close_tag) {
      Some(pos) => pos + close_tag.length()
      None => raise InvalidXml(msg="x14:dataValidation tag not closed")
    }
    let slice = text[:end]
    let full = "<x14:dataValidation \{slice.to_owned()}"
    let open_end = match full.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="x14:dataValidation open tag missing")
    }
    let attrs = full["<x14:dataValidation ".length():open_end]
    let allow_blank = match attr_value(attrs, "allowBlank") {
      Some(value) => value
      None => "0"
    }
    let typ = match attr_value(attrs, "type") {
      Some(value) => value
      None => ""
    }
    let sqref = match extract_tag_body_from(full, "xm:sqref") {
      Some(value) =>
        normalize_sqref_for_read(
          unescape_xml_text(value),
          "x14 data validation",
          budget?,
        )
      None => raise InvalidXml(msg="x14:dataValidation sqref missing")
    }
    let mut formula1 = ""
    match extract_tag_body_from(full, "x14:formula1") {
      Some(value) => {
        let body = value.to_string()
        match extract_tag_body_from(body, "xm:f") {
          Some(f) => formula1 = unescape_xml_text(f)
          None => formula1 = unescape_xml_text(value)
        }
      }
      None => ()
    }
    let mut formula2 = ""
    match extract_tag_body_from(full, "x14:formula2") {
      Some(value) => {
        let body = value.to_string()
        match extract_tag_body_from(body, "xm:f") {
          Some(f) => formula2 = unescape_xml_text(f)
          None => formula2 = unescape_xml_text(value)
        }
      }
      None => ()
    }
    let sb = StringBuilder::new()
    sb.write_view("<dataValidation allowBlank=\"")
    sb.write_view(escape_xml_attr(allow_blank))
    sb.write_view("\"")
    if typ != "" {
      sb.write_view(" type=\"")
      sb.write_view(escape_xml_attr(typ))
      sb.write_view("\"")
    }
    sb.write_view(" sqref=\"")
    sb.write_view(escape_xml_attr(sqref))
    sb.write_view("\">")
    if formula1 != "" {
      sb.write_view("<formula1>")
      sb.write_view(escape_xml_text(formula1))
      sb.write_view("</formula1>")
    }
    if formula2 != "" {
      sb.write_view("<formula2>")
      sb.write_view(escape_xml_text(formula2))
      sb.write_view("</formula2>")
    }
    sb.write_view("</dataValidation>")
    validations.push(sb.to_string())
  }
  validations
}

///|
fn parse_conditional_formats(
  xml : StringView,
  budget? : ReadBudget,
) -> Array[String] raise XlsxError {
  let formats : Array[String] = []
  let xml_str = xml.to_owned()
  if !xml_str.contains("<conditionalFormatting") {
    return formats
  }
  let mut first = true
  for chunk in xml_str.split("<conditionalFormatting") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let close_tag = "</conditionalFormatting>"
    let full = match text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = text[:end]
        "<conditionalFormatting\{slice.to_owned()}"
      }
      None => {
        let end = match text.find("/>") {
          Some(pos) => pos + 2
          None => raise InvalidXml(msg="conditionalFormatting tag not closed")
        }
        let slice = text[:end]
        "<conditionalFormatting\{slice.to_owned()}"
      }
    }
    formats.push(
      normalize_xml_sqref_attr_for_read(
        full,
        "conditionalFormatting",
        "conditional formatting",
        budget?,
      ),
    )
  }
  formats
}

///|
fn build_icon_set_rule_xml_from_x14(
  opt : ConditionalFormatOptions,
  priority : Int,
  cfvos : ArrayView[String],
) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"iconSet\"")
  sb.write_view(" priority=\"\{priority}\"")
  write_stop_if_true(sb, opt)
  sb.write_view(">")
  let show_value = if opt.icons_only { "0" } else { "1" }
  sb.write_view(
    "<iconSet iconSet=\"\{escape_xml_attr(opt.icon_style)}\" showValue=\"\{show_value}\"",
  )
  if opt.reverse_icons {
    sb.write_view(" reverse=\"1\"")
  }
  if opt.percent {
    sb.write_view(" percent=\"1\"")
  }
  sb.write_view(">")
  if cfvos.length() > 0 {
    for cfvo in cfvos {
      sb.write_view(cfvo)
    }
  } else {
    match icon_set_steps(opt.icon_style) {
      Some(steps) =>
        for step in steps {
          sb.write_view("<cfvo type=\"percent\" val=\"\{step}\"/>")
        }
      None => ()
    }
  }
  sb.write_view("</iconSet>")
  sb.write_view("</cfRule>")
  sb.to_string()
}

///|
fn parse_x14_cfvo_values(xml : StringView) -> Array[String] raise XlsxError {
  let cfvos : Array[String] = []
  let xml_str = xml.to_owned()
  if !xml_str.contains("<x14:cfvo") {
    return cfvos
  }
  let mut first = true
  for chunk in xml_str.split("<x14:cfvo") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let close_tag = "</x14:cfvo>"
    let full = match text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = text[:end]
        "<x14:cfvo\{slice.to_owned()}"
      }
      None => {
        let end = match text.find("/>") {
          Some(pos) => pos + 2
          None => raise InvalidXml(msg="x14:cfvo tag not closed")
        }
        let slice = text[:end]
        "<x14:cfvo\{slice.to_owned()}"
      }
    }
    let open_end = match full.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="x14:cfvo open tag missing")
    }
    let attrs = full["<x14:cfvo".length():open_end]
    let typ = match attr_value(attrs, "type") {
      Some(value) => value.to_string()
      None => ""
    }
    let value = match extract_tag_body_from(full, "xm:f") {
      Some(v) => unescape_xml_text(v)
      None =>
        match extract_tag_body_from(full, "f") {
          Some(v) => unescape_xml_text(v)
          None => ""
        }
    }
    if typ == "" {
      continue
    }
    let sb = StringBuilder::new()
    sb.write_view("<cfvo type=\"")
    sb.write_view(escape_xml_attr(typ))
    sb.write_view("\"")
    if value != "" {
      sb.write_view(" val=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    sb.write_view("/>")
    cfvos.push(sb.to_string())
  }
  cfvos
}

///|
fn color_text_from_rgb_x14(rgb : StringView) -> String {
  let text = rgb.to_owned()
  match text.strip_prefix("FF") {
    Some(rest) if text.length() == 8 => "#\{rest}"
    _ => "#\{text}"
  }
}

///|
fn parse_x14_conditional_formatting_blocks(
  xml : StringView,
) -> Array[String] raise XlsxError {
  let blocks : Array[String] = []
  let xml_str = xml.to_owned()
  if xml_str.contains("<x14:conditionalFormattings") &&
    !xml_str.contains("</x14:conditionalFormattings>") {
    raise InvalidXml(msg="x14:conditionalFormattings tag not closed")
  }
  let mut open_pos : Int? = None
  let mut open_search_from = 0
  let open_needle = "<x14:conditionalFormatting"
  while open_search_from < xml_str.length() {
    let rest = xml_str[open_search_from:]
    let rel_start = match rest.find(open_needle) {
      Some(pos) => pos
      None => break
    }
    let start = open_search_from + rel_start
    let after_needle = start + open_needle.length()
    let next_char = xml_str[after_needle:after_needle + 1]
    if next_char == "s" {
      open_search_from = after_needle
      continue
    }
    open_pos = Some(start)
    break
  }
  match xml_str.find("</x14:conditionalFormatting>") {
    Some(close_pos) =>
      match open_pos {
        Some(pos) =>
          if pos > close_pos {
            raise InvalidXml(msg="x14:conditionalFormatting close before open")
          }
        None =>
          raise InvalidXml(msg="x14:conditionalFormatting close without open")
      }
    None => ()
  }
  let needle = "<x14:conditionalFormatting"
  if !xml_str.contains(needle) {
    return blocks
  }
  let close_tag = "</x14:conditionalFormatting>"
  let mut search_from = 0
  while search_from < xml_str.length() {
    let rest = xml_str[search_from:]
    let rel_start = match rest.find(needle) {
      Some(pos) => pos
      None => break
    }
    let start = search_from + rel_start
    let after_needle = start + needle.length()
    let next_char = xml_str[after_needle:after_needle + 1]
    if next_char == "s" {
      search_from = after_needle
      continue
    }
    let after_start = xml_str[start:]
    let after_text = after_start.to_owned()
    let (full, consumed) = match after_text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = after_text[:end]
        (slice.to_owned(), end)
      }
      None => {
        let end = match after_text.find("/>") {
          Some(pos) => pos + 2
          None =>
            raise InvalidXml(msg="x14:conditionalFormatting tag not closed")
        }
        let slice = after_text[:end]
        (slice.to_owned(), end)
      }
    }
    blocks.push(full)
    search_from = start + consumed
  }
  blocks
}

///|
fn parse_x14_data_bars(
  xml : StringView,
  budget? : ReadBudget,
) -> Map[String, X14DataBarProps] raise XlsxError {
  let bars : Map[String, X14DataBarProps] = Map([])
  let blocks = parse_x14_conditional_formatting_blocks(xml)
  if blocks.length() == 0 {
    return bars
  }
  for full in blocks {
    let sqref = match extract_tag_body_from(full, "xm:sqref") {
      Some(value) =>
        normalize_sqref_for_read(
          unescape_xml_text(value),
          "x14 conditional formatting",
          budget?,
        )
      None =>
        match extract_tag_body_from(full, "sqref") {
          Some(value) =>
            normalize_sqref_for_read(
              unescape_xml_text(value),
              "x14 conditional formatting",
              budget?,
            )
          None => continue
        }
    }
    if !full.contains("<x14:cfRule") {
      continue
    }
    let mut rule_first = true
    for rule_chunk in full.split("<x14:cfRule") {
      if rule_first {
        rule_first = false
        continue
      }
      let rule_text = rule_chunk.to_owned()
      let rule_close = "</x14:cfRule>"
      let rule_full = match rule_text.find(rule_close) {
        Some(pos) => {
          let end = pos + rule_close.length()
          let slice = rule_text[:end]
          "<x14:cfRule\{slice.to_owned()}"
        }
        None => {
          let end = match rule_text.find("/>") {
            Some(pos) => pos + 2
            None => raise InvalidXml(msg="x14:cfRule tag not closed")
          }
          let slice = rule_text[:end]
          "<x14:cfRule\{slice.to_owned()}"
        }
      }
      let open_end = match rule_full.find(">") {
        Some(pos) => pos
        None => continue
      }
      let attrs = rule_full["<x14:cfRule".length():open_end]
      let typ = match attr_value(attrs, "type") {
        Some(value) => value.to_string()
        None => ""
      }
      if typ != "dataBar" {
        continue
      }
      let id = match attr_value(attrs, "id") {
        Some(value) => value.to_string()
        None => continue
      }
      let mut bar_direction = ""
      let mut bar_solid = false
      let mut bar_border_color = ""
      match tag_attributes_in(rule_full, "x14:dataBar") {
        Some(tag) => {
          match attr_value(tag, "direction") {
            Some(value) => bar_direction = value.to_string()
            None => ()
          }
          match attr_value(tag, "gradient") {
            Some(value) => bar_solid = !parse_xml_bool(value)
            None => ()
          }
        }
        None => ()
      }
      match tag_attributes_in(rule_full, "x14:borderColor") {
        Some(tag) =>
          match attr_value(tag, "rgb") {
            Some(value) => bar_border_color = color_text_from_rgb_x14(value)
            None => ()
          }
        None => ()
      }
      bars[id] = { sqref, bar_direction, bar_solid, bar_border_color }
    }
  }
  bars
}

///|
fn worksheet_ext_uri_is_known(uri : StringView) -> Bool {
  match uri.to_owned() {
    "{78C0D931-6437-407d-A8EE-F0AAD7539E65}" => true
    "{05C60535-1F16-4fd2-B633-F4F36F0B64E0}" => true
    "{A8765BA9-456A-4dab-B4F3-ACF838C121DE}" => true
    "{3A4CF648-6AED-40f4-86FF-DC5316D8AED3}" => true
    _ => false
  }
}

///|
fn parse_unknown_worksheet_ext_blocks(
  xml : StringView,
) -> Array[String] raise XlsxError {
  let unknown : Array[String] = []
  let text = xml.to_owned()
  let ext_start = match text.rev_find("<extLst") {
    Some(pos) => pos
    None => return unknown
  }
  let ext_tail = text[ext_start:]
  let open_end = match ext_tail.find(">") {
    Some(pos) => pos
    None => raise InvalidXml(msg="worksheet extLst open tag invalid")
  }
  let close_rel = match ext_tail.find("</extLst>") {
    Some(pos) => pos
    None => raise InvalidXml(msg="worksheet extLst close tag missing")
  }
  let body = ext_tail[open_end + 1:close_rel]
  let mut first = true
  for chunk in body.to_owned().split("<ext ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let full = "<ext " + text
    let end = match full.find("</ext>") {
      Some(pos) => pos + "</ext>".length()
      None =>
        match full.find("/>") {
          Some(pos) => pos + 2
          None => raise InvalidXml(msg="worksheet ext block not closed")
        }
    }
    let block = full[:end]
    let open_end = match block.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="worksheet ext open tag invalid")
    }
    let open_tag = block[:open_end]
    let uri = match attr_value(open_tag, "uri") {
      Some(value) => value.to_string()
      None => ""
    }
    if worksheet_ext_uri_is_known(uri) {
      continue
    }
    if block.contains("<x14:sparklineGroups") ||
      block.contains("<x14:conditionalFormattings") ||
      block.contains("<x14:slicerList") {
      continue
    }
    unknown.push(block.to_owned())
  }
  unknown
}

///|
fn parse_conditional_formats_x14(
  xml : StringView,
  budget? : ReadBudget,
) -> Array[String] raise XlsxError {
  let formats : Array[String] = []
  let blocks = parse_x14_conditional_formatting_blocks(xml)
  if blocks.length() == 0 {
    return formats
  }
  for full in blocks {
    let sqref = match extract_tag_body_from(full, "xm:sqref") {
      Some(value) =>
        normalize_sqref_for_read(
          unescape_xml_text(value),
          "x14 conditional formatting",
          budget?,
        )
      None =>
        match extract_tag_body_from(full, "sqref") {
          Some(value) =>
            normalize_sqref_for_read(
              unescape_xml_text(value),
              "x14 conditional formatting",
              budget?,
            )
          None =>
            raise InvalidXml(msg="x14:conditionalFormatting sqref missing")
        }
    }
    let rules : Array[String] = []
    if full.contains("<x14:cfRule") {
      let mut rule_first = true
      for rule_chunk in full.split("<x14:cfRule") {
        if rule_first {
          rule_first = false
          continue
        }
        let rule_text = rule_chunk.to_owned()
        let rule_close = "</x14:cfRule>"
        let rule_full = match rule_text.find(rule_close) {
          Some(pos) => {
            let end = pos + rule_close.length()
            let slice = rule_text[:end]
            "<x14:cfRule\{slice.to_owned()}"
          }
          None => {
            let end = match rule_text.find("/>") {
              Some(pos) => pos + 2
              None => raise InvalidXml(msg="x14:cfRule tag not closed")
            }
            let slice = rule_text[:end]
            "<x14:cfRule\{slice.to_owned()}"
          }
        }
        let open_end = match rule_full.find(">") {
          Some(pos) => pos
          None => continue
        }
        let attrs = rule_full["<x14:cfRule".length():open_end]
        let typ = match attr_value(attrs, "type") {
          Some(value) => value.to_string()
          None => ""
        }
        if typ != "iconSet" {
          continue
        }
        let mut priority = match attr_value(attrs, "priority") {
          Some(value) =>
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="x14:cfRule priority invalid")
            }
          None => 1
        }
        if priority <= 0 {
          priority = 1
        }
        let stop_if_true = match attr_value(attrs, "stopIfTrue") {
          Some(value) => parse_xml_bool(value)
          None => false
        }
        let opt = ConditionalFormatOptions::new("icon_set")
        opt.stop_if_true = stop_if_true
        match tag_attributes_in(rule_full, "x14:iconSet") {
          Some(tag) => {
            match attr_value(tag, "iconSet") {
              Some(value) => opt.icon_style = value.to_string()
              None => ()
            }
            match attr_value(tag, "reverse") {
              Some(value) => opt.reverse_icons = parse_xml_bool(value)
              None => ()
            }
            let show_value = match attr_value(tag, "showValue") {
              Some(value) => parse_xml_bool(value)
              None => true
            }
            opt.icons_only = !show_value
            match attr_value(tag, "percent") {
              Some(value) => opt.percent = parse_xml_bool(value)
              None =>
                match attr_value(attrs, "percent") {
                  Some(value) => opt.percent = parse_xml_bool(value)
                  None => ()
                }
            }
          }
          None => continue
        }
        let cfvos = parse_x14_cfvo_values(rule_full)
        rules.push(build_icon_set_rule_xml_from_x14(opt, priority, cfvos))
      }
    }
    if rules.length() > 0 {
      formats.push(conditional_format_xml(sqref, rules))
    }
  }
  formats
}

///|
fn parse_sheet_dimension(xml : StringView) -> String? raise XlsxError {
  let xml_str = xml.to_owned()
  let marker = "<dimension"
  match xml_str.find(marker) {
    None => None
    Some(start) => {
      let rest = xml_str[start + marker.length():]
      let end = match rest.find("/>") {
        Some(pos) => pos
        None =>
          match rest.find(">") {
            Some(pos) => pos
            None => raise InvalidXml(msg="dimension tag not closed")
          }
      }
      let tag = rest[:end]
      match attr_value(tag, "ref") {
        Some(value) =>
          Some(
            validate_cell_or_range_ref_for_read(
              unescape_xml_text(value),
              "dimension",
            ),
          )
        None => None
      }
    }
  }
}

///|
fn parse_sheet_view_pane(body : StringView) -> SheetPane? raise XlsxError {
  let mut first = true
  for chunk in body.split("<pane ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="pane tag not closed")
        }
    }
    let tag = text[:end]
    let pane = SheetPane::new()
    match attr_value(tag, "activePane") {
      Some(value) => pane.active_pane = unescape_xml_text(value)
      None => ()
    }
    match attr_value(tag, "state") {
      Some(value) => pane.state = unescape_xml_text(value)
      None => ()
    }
    match attr_value(tag, "topLeftCell") {
      Some(value) =>
        pane.top_left_cell = validate_cell_ref_for_read(
          unescape_xml_text(value),
          "pane topLeftCell",
        )
      None => ()
    }
    match attr_value(tag, "xSplit") {
      Some(value) =>
        pane.x_split = @string.parse_double(value) catch {
          _ => raise InvalidXml(msg="pane xSplit invalid")
        }
      None => ()
    }
    match attr_value(tag, "ySplit") {
      Some(value) =>
        pane.y_split = @string.parse_double(value) catch {
          _ => raise InvalidXml(msg="pane ySplit invalid")
        }
      None => ()
    }
    return Some(pane)
  }
  None
}

///|
fn parse_sheet_view_selections(
  body : StringView,
  budget? : ReadBudget,
) -> Array[Selection] raise XlsxError {
  let selections : Array[Selection] = []
  let mut first = true
  for chunk in body.split("<selection ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="selection tag not closed")
        }
    }
    let tag = text[:end]
    let selection = { sqref: "", active_cell: "", pane: "" }
    match attr_value(tag, "sqref") {
      Some(value) =>
        selection.sqref = normalize_sqref_for_read(
          unescape_xml_text(value),
          "selection",
          budget?,
        )
      None => ()
    }
    match attr_value(tag, "activeCell") {
      Some(value) =>
        selection.active_cell = validate_cell_ref_for_read(
          unescape_xml_text(value),
          "selection activeCell",
        )
      None => ()
    }
    match attr_value(tag, "pane") {
      Some(value) => selection.pane = unescape_xml_text(value)
      None => ()
    }
    selections.push(selection)
  }
  selections
}

///|
fn parse_sheet_views(
  xml : StringView,
  budget? : ReadBudget,
) -> Array[SheetView] raise XlsxError {
  let views : Array[SheetView] = []
  let body = match extract_tag_body(xml, "sheetViews") {
    Some(value) => value
    None => return views
  }
  let mut first = true
  for chunk in body.split("<sheetView ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="sheetView tag not closed")
    }
    let tag = text[:end]
    let view = SheetView::new()
    match attr_value(tag, "defaultGridColor") {
      Some(value) => view.default_grid_color = Some(parse_cell_bool(value))
      None => ()
    }
    match attr_value(tag, "rightToLeft") {
      Some(value) => view.right_to_left = Some(parse_cell_bool(value))
      None => ()
    }
    match attr_value(tag, "showFormulas") {
      Some(value) => view.show_formulas = Some(parse_cell_bool(value))
      None => ()
    }
    match attr_value(tag, "showGridLines") {
      Some(value) => view.show_grid_lines = Some(parse_cell_bool(value))
      None => ()
    }
    match attr_value(tag, "showRowColHeaders") {
      Some(value) => view.show_row_col_headers = Some(parse_cell_bool(value))
      None => ()
    }
    match attr_value(tag, "showRuler") {
      Some(value) => view.show_ruler = Some(parse_cell_bool(value))
      None => ()
    }
    match attr_value(tag, "showZeros") {
      Some(value) => view.show_zeros = Some(parse_cell_bool(value))
      None => ()
    }
    match attr_value(tag, "topLeftCell") {
      Some(value) =>
        view.top_left_cell = Some(
          validate_cell_ref_for_read(
            unescape_xml_text(value),
            "sheetView topLeftCell",
          ),
        )
      None => ()
    }
    match attr_value(tag, "view") {
      Some(value) => view.view = Some(unescape_xml_text(value))
      None => ()
    }
    match attr_value(tag, "zoomScale") {
      Some(value) =>
        view.zoom_scale = Some(
          @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="sheetView zoomScale invalid")
          },
        )
      None => ()
    }
    match attr_value(tag, "tabSelected") {
      Some(value) => view.tab_selected = parse_cell_bool(value)
      None => ()
    }
    match attr_value(tag, "workbookViewId") {
      Some(value) =>
        view.workbook_view_id = @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="sheetView workbookViewId invalid")
        }
      None => ()
    }
    let self_closing = tag.to_owned().trim().has_suffix("/")
    if !self_closing {
      let close = match text.find("</sheetView>") {
        Some(pos) => pos
        None => raise InvalidXml(msg="sheetView close missing")
      }
      let body_start = end + 1
      if close > body_start {
        let inner = text[body_start:close]
        view.pane = parse_sheet_view_pane(inner)
        let selections = parse_sheet_view_selections(inner, budget?)
        view.selection.clear()
        view.selection.append(selections)
      }
    }
    views.push(view)
  }
  views
}

///|
fn parse_sheet_props(xml : StringView) -> SheetPropsOptions? raise XlsxError {
  let mut options : SheetPropsOptions? = None
  match tag_attributes_in(xml, "sheetPr") {
    Some(tag) => {
      let opts = SheetPropsOptions::new()
      match attr_value(tag, "codeName") {
        Some(value) => opts.code_name = Some(unescape_xml_text(value))
        None => ()
      }
      match attr_value(tag, "enableFormatConditionsCalculation") {
        Some(value) =>
          opts.enable_format_conditions_calculation = Some(
            parse_bool_attr(value),
          )
        None => ()
      }
      match attr_value(tag, "published") {
        Some(value) => opts.published = Some(parse_bool_attr(value))
        None => ()
      }
      options = Some(opts)
    }
    None => ()
  }
  match tag_attributes_in(xml, "tabColor") {
    Some(tag) => {
      let opts = match options {
        Some(value) => value
        None => SheetPropsOptions::new()
      }
      match attr_value(tag, "indexed") {
        Some(value) =>
          opts.tab_color_indexed = Some(
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="tabColor indexed invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "rgb") {
        Some(value) => opts.tab_color_rgb = Some(value.to_string())
        None => ()
      }
      match attr_value(tag, "theme") {
        Some(value) =>
          opts.tab_color_theme = Some(
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="tabColor theme invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "tint") {
        Some(value) =>
          opts.tab_color_tint = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="tabColor tint invalid")
            },
          )
        None => ()
      }
      options = Some(opts)
    }
    None => ()
  }
  match tag_attributes_in(xml, "outlinePr") {
    Some(tag) => {
      let opts = match options {
        Some(value) => value
        None => SheetPropsOptions::new()
      }
      match attr_value(tag, "summaryBelow") {
        Some(value) => opts.outline_summary_below = Some(parse_bool_attr(value))
        None => ()
      }
      match attr_value(tag, "summaryRight") {
        Some(value) => opts.outline_summary_right = Some(parse_bool_attr(value))
        None => ()
      }
      options = Some(opts)
    }
    None => ()
  }
  match tag_attributes_in(xml, "pageSetUpPr") {
    Some(tag) => {
      let opts = match options {
        Some(value) => value
        None => SheetPropsOptions::new()
      }
      match attr_value(tag, "autoPageBreaks") {
        Some(value) => opts.auto_page_breaks = Some(parse_bool_attr(value))
        None => ()
      }
      match attr_value(tag, "fitToPage") {
        Some(value) => opts.fit_to_page = Some(parse_bool_attr(value))
        None => ()
      }
      options = Some(opts)
    }
    None => ()
  }
  match tag_attributes_in(xml, "sheetFormatPr") {
    Some(tag) => {
      let opts = match options {
        Some(value) => value
        None => SheetPropsOptions::new()
      }
      match attr_value(tag, "baseColWidth") {
        Some(value) =>
          opts.base_col_width = Some(
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="sheetFormatPr baseColWidth invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "defaultColWidth") {
        Some(value) =>
          opts.default_col_width = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="sheetFormatPr defaultColWidth invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "defaultRowHeight") {
        Some(value) =>
          opts.default_row_height = Some(
            @string.parse_double(value) catch {
              _ =>
                raise InvalidXml(msg="sheetFormatPr defaultRowHeight invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "customHeight") {
        Some(value) => opts.custom_height = Some(parse_bool_attr(value))
        None => ()
      }
      match attr_value(tag, "zeroHeight") {
        Some(value) => opts.zero_height = Some(parse_bool_attr(value))
        None => ()
      }
      match attr_value(tag, "thickTop") {
        Some(value) => opts.thick_top = Some(parse_bool_attr(value))
        None => ()
      }
      match attr_value(tag, "thickBottom") {
        Some(value) => opts.thick_bottom = Some(parse_bool_attr(value))
        None => ()
      }
      options = Some(opts)
    }
    None => ()
  }
  match options {
    Some(value) => if sheet_props_is_empty(value) { None } else { Some(value) }
    None => None
  }
}

///|
fn parse_page_margins(
  xml : StringView,
) -> PageLayoutMarginsOptions? raise XlsxError {
  let mut options : PageLayoutMarginsOptions? = None
  match tag_attributes_in(xml, "pageMargins") {
    Some(tag) => {
      let opts = PageLayoutMarginsOptions::new()
      match attr_value(tag, "left") {
        Some(value) =>
          opts.left = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="pageMargins left invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "right") {
        Some(value) =>
          opts.right = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="pageMargins right invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "top") {
        Some(value) =>
          opts.top = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="pageMargins top invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "bottom") {
        Some(value) =>
          opts.bottom = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="pageMargins bottom invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "header") {
        Some(value) =>
          opts.header = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="pageMargins header invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "footer") {
        Some(value) =>
          opts.footer = Some(
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="pageMargins footer invalid")
            },
          )
        None => ()
      }
      options = Some(opts)
    }
    None => ()
  }
  match tag_attributes_in(xml, "printOptions") {
    Some(tag) => {
      let opts = match options {
        Some(value) => value
        None => PageLayoutMarginsOptions::new()
      }
      match attr_value(tag, "horizontalCentered") {
        Some(value) => opts.horizontally = Some(parse_bool_attr(value))
        None => ()
      }
      match attr_value(tag, "verticalCentered") {
        Some(value) => opts.vertically = Some(parse_bool_attr(value))
        None => ()
      }
      options = Some(opts)
    }
    None => ()
  }
  options
}

///|
fn parse_page_layout(xml : StringView) -> PageLayoutOptions? raise XlsxError {
  let tag = match tag_attributes_in(xml, "pageSetup") {
    Some(value) => value
    None => return None
  }
  let opts = PageLayoutOptions::new()
  match attr_value(tag, "paperSize") {
    Some(value) =>
      opts.size = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="pageSetup paperSize invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "orientation") {
    Some(value) => opts.orientation = Some(value.to_string())
    None => ()
  }
  match attr_value(tag, "firstPageNumber") {
    Some(value) =>
      opts.first_page_number = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="pageSetup firstPageNumber invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "scale") {
    Some(value) =>
      opts.adjust_to = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="pageSetup scale invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "fitToHeight") {
    Some(value) =>
      opts.fit_to_height = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="pageSetup fitToHeight invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "fitToWidth") {
    Some(value) =>
      opts.fit_to_width = Some(
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="pageSetup fitToWidth invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "blackAndWhite") {
    Some(value) => opts.black_and_white = Some(parse_bool_attr(value))
    None => ()
  }
  match attr_value(tag, "pageOrder") {
    Some(value) => opts.page_order = Some(value.to_string())
    None => ()
  }
  Some(opts)
}

///|
fn parse_header_footer(
  xml : StringView,
) -> HeaderFooterOptions? raise XlsxError {
  let tag = match tag_attributes_in(xml, "headerFooter") {
    Some(value) => value
    None => return None
  }
  let options = HeaderFooterOptions::new()
  match attr_value(tag, "differentOddEven") {
    Some(value) => options.different_odd_even = parse_bool_attr(value)
    None => ()
  }
  match attr_value(tag, "differentFirst") {
    Some(value) => options.different_first = parse_bool_attr(value)
    None => ()
  }
  match attr_value(tag, "scaleWithDoc") {
    Some(value) => options.scale_with_doc = Some(parse_bool_attr(value))
    None => ()
  }
  match attr_value(tag, "alignWithMargins") {
    Some(value) => options.align_with_margins = Some(parse_bool_attr(value))
    None => ()
  }
  let body = match extract_tag_body(xml, "headerFooter") {
    Some(value) => value
    None => ""
  }
  match extract_tag_body_from(body, "oddHeader") {
    Some(value) => options.odd_header = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body_from(body, "oddFooter") {
    Some(value) => options.odd_footer = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body_from(body, "evenHeader") {
    Some(value) => options.even_header = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body_from(body, "evenFooter") {
    Some(value) => options.even_footer = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body_from(body, "firstHeader") {
    Some(value) => options.first_header = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body_from(body, "firstFooter") {
    Some(value) => options.first_footer = unescape_xml_text(value)
    None => ()
  }
  Some(options)
}

///|
fn parse_sheet_protection(xml : StringView) -> SheetProtection? raise XlsxError {
  let tag = match tag_attributes_in(xml, "sheetProtection") {
    Some(value) => value
    None => return None
  }
  let mut spin_count = 0
  match attr_value(tag, "spinCount") {
    Some(value) =>
      spin_count = @string.parse_int(value, base=10) catch {
        _ => raise InvalidXml(msg="sheetProtection spinCount invalid")
      }
    None => ()
  }
  Some({
    algorithm_name: match attr_value(tag, "algorithmName") {
      Some(value) => value.to_string()
      None => ""
    },
    password: match attr_value(tag, "password") {
      Some(value) => value.to_string()
      None => ""
    },
    hash_value: match attr_value(tag, "hashValue") {
      Some(value) => value.to_string()
      None => ""
    },
    salt_value: match attr_value(tag, "saltValue") {
      Some(value) => value.to_string()
      None => ""
    },
    spin_count,
    sheet: match attr_value(tag, "sheet") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    objects: match attr_value(tag, "objects") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    scenarios: match attr_value(tag, "scenarios") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    format_cells: match attr_value(tag, "formatCells") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    format_columns: match attr_value(tag, "formatColumns") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    format_rows: match attr_value(tag, "formatRows") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    insert_columns: match attr_value(tag, "insertColumns") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    insert_rows: match attr_value(tag, "insertRows") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    insert_hyperlinks: match attr_value(tag, "insertHyperlinks") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    delete_columns: match attr_value(tag, "deleteColumns") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    delete_rows: match attr_value(tag, "deleteRows") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    select_locked_cells: match attr_value(tag, "selectLockedCells") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    sort: match attr_value(tag, "sort") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    auto_filter: match attr_value(tag, "autoFilter") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    pivot_tables: match attr_value(tag, "pivotTables") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
    select_unlocked_cells: match attr_value(tag, "selectUnlockedCells") {
      Some(value) => parse_bool_attr(value)
      None => false
    },
  })
}

///|
fn parse_page_breaks(
  xml : StringView,
  tag_name : StringView,
) -> Array[PageBreak] raise XlsxError {
  let breaks : Array[PageBreak] = []
  let body = match extract_tag_body(xml, tag_name) {
    Some(value) => value
    None => return breaks
  }
  let mut first = true
  for chunk in body.split("<brk ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="brk tag not closed")
        }
    }
    let tag = text[:end]
    let id = match attr_value(tag, "id") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="brk id invalid")
        }
      None => raise InvalidXml(msg="brk id missing")
    }
    let min = match attr_value(tag, "min") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="brk min invalid")
        }
      None => 0
    }
    let max = match attr_value(tag, "max") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="brk max invalid")
        }
      None => 0
    }
    let (id_limit, span_limit) = match tag_name.to_owned() {
      "rowBreaks" => (max_page_break_rows, max_page_break_cols)
      "colBreaks" => (max_page_break_cols, max_page_break_rows)
      _ => raise InvalidXml(msg="page break axis invalid")
    }
    if id < 0 ||
      id > id_limit ||
      min < 0 ||
      min > span_limit ||
      max < 0 ||
      max > span_limit ||
      min > max {
      raise InvalidXml(msg="brk coordinate invalid")
    }
    let manual = match attr_value(tag, "man") {
      Some(value) => parse_bool_attr(value)
      None => false
    }
    breaks.push({ id, min, max, manual })
  }
  breaks
}

///|
fn parse_picture_rel_id(xml : StringView) -> String? raise XlsxError {
  let tag = match tag_attributes_in(xml, "picture") {
    Some(value) => value
    None => return None
  }
  match attr_value(tag, "r:id") {
    Some(value) => Some(value.to_string())
    None => raise InvalidXml(msg="picture relationship missing")
  }
}

///|
fn parse_auto_filter_columns(
  body : StringView,
  min_col : Int,
  max_col : Int,
) -> Array[AutoFilterColumn] raise XlsxError {
  let columns : Array[AutoFilterColumn] = []
  let mut first = true
  for chunk in body.split("<filterColumn ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="filterColumn tag not closed")
    }
    let tag = text[:end]
    let col_id = match attr_value(tag, "colId") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="filterColumn colId invalid")
        }
      None => raise InvalidXml(msg="filterColumn colId missing")
    }
    if col_id < 0 || col_id > max_col - min_col {
      raise InvalidXml(msg="filterColumn colId out of range")
    }
    let col = min_col + col_id
    let mut filters : Array[String]? = None
    let mut custom_filters : AutoFilterCustomFilters? = None
    if !tag.has_suffix("/") {
      let rest = text[end + 1:]
      let body_end = match rest.find("</filterColumn>") {
        Some(pos) => pos
        None => 0
      }
      let column_body = if body_end > 0 { rest[:body_end] } else { "" }
      match extract_tag_body_from(column_body, "filters") {
        Some(filters_body) => {
          let values : Array[String] = []
          let mut first_filter = true
          for part in filters_body.split("<filter ") {
            if first_filter {
              first_filter = false
              continue
            }
            let filter_text = part.to_owned()
            let filter_end = match filter_text.find("/>") {
              Some(pos) => pos
              None =>
                match filter_text.find(">") {
                  Some(pos) => pos
                  None => raise InvalidXml(msg="filter tag not closed")
                }
            }
            let filter_tag = filter_text[:filter_end]
            match attr_value(filter_tag, "val") {
              Some(value) => values.push(unescape_xml_text(value))
              None => values.push("")
            }
          }
          filters = Some(values)
        }
        None => ()
      }
      match extract_tag_body_from(column_body, "customFilters") {
        Some(custom_body) => {
          let and_value = match
            tag_attributes_in(column_body, "customFilters") {
            Some(custom_tag) =>
              match attr_value(custom_tag, "and") {
                Some(value) => parse_bool_attr(value)
                None => false
              }
            None => false
          }
          let entries : Array[AutoFilterCustomFilter] = []
          let mut first_custom = true
          for part in custom_body.split("<customFilter ") {
            if first_custom {
              first_custom = false
              continue
            }
            let custom_text = part.to_owned()
            let custom_end = match custom_text.find("/>") {
              Some(pos) => pos
              None =>
                match custom_text.find(">") {
                  Some(pos) => pos
                  None => raise InvalidXml(msg="customFilter tag not closed")
                }
            }
            let custom_tag = custom_text[:custom_end]
            let operator = match attr_value(custom_tag, "operator") {
              Some(value) => value
              None => "equal"
            }
            let val = match attr_value(custom_tag, "val") {
              Some(value) => unescape_xml_text(value)
              None => ""
            }
            entries.push({ operator, value: val })
          }
          custom_filters = Some({ and_filter: and_value, filters: entries })
        }
        None => ()
      }
    }
    columns.push({ col, filters, custom_filters })
  }
  columns
}

///|
fn parse_auto_filter(xml : StringView) -> AutoFilter? raise XlsxError {
  let tag = match tag_attributes_in(xml, "autoFilter") {
    Some(value) => value
    None => return None
  }
  let ref_value = match attr_value(tag, "ref") {
    Some(value) => value
    None => raise InvalidXml(msg="autoFilter ref missing")
  }
  let range_ref = normalize_range_ref(ref_value)
  let (_min_row, min_col, _max_row, max_col) = parse_range_ref(range_ref)
  let self_closing = tag.trim().has_suffix("/")
  let columns = if self_closing {
    []
  } else {
    match extract_tag_body(xml, "autoFilter") {
      Some(body) => parse_auto_filter_columns(body, min_col, max_col)
      None => []
    }
  }
  Some({ range_ref, columns })
}

///|
priv struct HyperlinkElement {
  reference : String
  r_id : String?
  location : String?
  display : String?
  tooltip : String?
}

///|
fn parse_hyperlink_elements(
  xml : StringView,
) -> Array[HyperlinkElement] raise XlsxError {
  let links : Array[HyperlinkElement] = []
  let body = match extract_tag_body(xml, "hyperlinks") {
    Some(value) => value
    None => return links
  }
  let mut first = true
  for chunk in body.split("<hyperlink ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match xml_open_tag_end_from(text, 0) {
      Some(pos) => pos
      None => raise InvalidXml(msg="hyperlink tag not closed")
    }
    let tag = text[:end]
    let raw_ref = match attr_value(tag, "ref") {
      Some(value) => value
      None => raise InvalidXml(msg="hyperlink ref missing")
    }
    let reference = normalize_cell_or_range_ref(unescape_xml_text(raw_ref)) catch {
      _ => raise InvalidXml(msg="hyperlink reference invalid")
    }
    let location = match attr_value(tag, "location") {
      Some(value) => Some(unescape_xml_text(value))
      None => None
    }
    let display = match attr_value(tag, "display") {
      Some(value) => Some(unescape_xml_text(value))
      None => None
    }
    let tooltip = match attr_value(tag, "tooltip") {
      Some(value) => Some(unescape_xml_text(value))
      None => None
    }
    let r_id = match attr_value(tag, "r:id") {
      Some(value) => Some(value.to_string())
      None => None
    }
    links.push({ reference, r_id, location, display, tooltip })
  }
  links
}

///|
fn parse_legacy_drawing_rel_id(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let xml_str = xml.to_owned()
  let marker = "<\{tag_name.to_owned()}"
  let chars = xml_str.to_array()
  let mut pos = 0
  while pos < xml_str.length() {
    let tail = xml_str[pos:]
    let rel = match tail.find(marker) {
      Some(value) => value
      None => break
    }
    let start = pos + rel
    let after = start + marker.length()
    if after < chars.length() {
      let ch = chars[after]
      if ch != ' ' &&
        ch != '\t' &&
        ch != '\n' &&
        ch != '\r' &&
        ch != '>' &&
        ch != '/' {
        pos = after
        continue
      }
    }
    let text = xml_str[start + 1:]
    let end = match text.find("/>") {
      Some(value) => value
      None =>
        match text.find(">") {
          Some(value) => value
          None => raise InvalidXml(msg="\{tag_name.to_owned()} tag not closed")
        }
    }
    let tag = text[:end]
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise InvalidXml(msg="\{tag_name.to_owned()} id missing")
    }
    return Some(id)
  }
  None
}

///|
fn parse_bool_attr(value : StringView) -> Bool {
  match value.to_owned() {
    "1" | "true" | "TRUE" => true
    _ => false
  }
}

///|
fn parse_inline_string(rest : StringView) -> InlineStringEntry raise XlsxError {
  let text = rest.to_owned()
  let start = match text.find("<is") {
    Some(pos) => pos
    None => return { text: "", runs: None }
  }
  let after_start = text[start:]
  let open_end = match after_start.find(">") {
    Some(pos) => pos
    None => raise InvalidXml(msg="inline string not closed")
  }
  let body_start = start + open_end + 1
  let end = match text.find("</is>") {
    Some(pos) => pos
    None => raise InvalidXml(msg="inline string end missing")
  }
  let body = text[body_start:end]
  let runs = if body.contains("<r") {
    let parsed = parse_rich_text_runs(body) catch { _ => [] }
    if parsed.length() > 0 {
      Some(parsed)
    } else {
      None
    }
  } else {
    None
  }
  { text: parse_text_nodes(body), runs }
}

///|
fn parse_row_dimensions(
  xml : StringView,
  style_count : Int,
) -> Map[Int, RowDimension] raise XlsxError {
  let dims : Map[Int, RowDimension] = Map([])
  let mut first = true
  for chunk in xml.split("<row ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="row tag not closed")
    }
    let tag = text[:end]
    let row_text = match attr_value(tag, "r") {
      Some(value) => value
      None => raise InvalidXml(msg="row index missing")
    }
    let row = @string.parse_int(row_text, base=10) catch {
      _ => raise InvalidXml(msg="row index invalid")
    }
    if row <= 0 || row > cell_ref_max_rows {
      raise InvalidXml(msg="row index invalid")
    }
    let height = match attr_value(tag, "ht") {
      Some(value) =>
        Some(
          @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="row height invalid")
          },
        )
      None => None
    }
    let hidden = match attr_value(tag, "hidden") {
      Some(value) => parse_bool_attr(value)
      None => false
    }
    let outline_level = match attr_value(tag, "outlineLevel") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="row outline level invalid")
        }
      None => 0
    }
    let style_id = match attr_value(tag, "s") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="row style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise InvalidStyleId(index=style_id)
    }
    let style = if style_id > 0 { Some(style_id) } else { None }
    if height is None && !hidden && outline_level == 0 && style is None {
      continue
    }
    dims[row] = { height, hidden, outline_level, style_id: style }
  }
  dims
}

///|
fn parse_col_dimensions(
  xml : StringView,
  style_count : Int,
) -> Map[Int, ColDimension] raise XlsxError {
  let dims : Map[Int, ColDimension] = Map([])
  let mut first = true
  for chunk in xml.split("<col ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="col tag not closed")
    }
    let tag = text[:end]
    let min_text = match attr_value(tag, "min") {
      Some(value) => value
      None => raise InvalidXml(msg="col min missing")
    }
    let max_text = match attr_value(tag, "max") {
      Some(value) => value
      None => raise InvalidXml(msg="col max missing")
    }
    let min_col = @string.parse_int(min_text, base=10) catch {
      _ => raise InvalidXml(msg="col min invalid")
    }
    let max_col = @string.parse_int(max_text, base=10) catch {
      _ => raise InvalidXml(msg="col max invalid")
    }
    if min_col <= 0 ||
      max_col <= 0 ||
      max_col < min_col ||
      min_col > cell_ref_max_cols ||
      max_col > cell_ref_max_cols {
      raise InvalidXml(msg="col range invalid")
    }
    let width = match attr_value(tag, "width") {
      Some(value) =>
        Some(
          @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="col width invalid")
          },
        )
      None => None
    }
    let hidden = match attr_value(tag, "hidden") {
      Some(value) => parse_bool_attr(value)
      None => false
    }
    let outline_level = match attr_value(tag, "outlineLevel") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="col outline level invalid")
        }
      None => 0
    }
    let style_id = match attr_value(tag, "style") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="col style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise InvalidStyleId(index=style_id)
    }
    let style = if style_id > 0 { Some(style_id) } else { None }
    if width is None && !hidden && outline_level == 0 && style is None {
      continue
    }
    let dim = { width, hidden, outline_level, style_id: style }
    let mut col = min_col
    while col <= max_col {
      dims[col] = dim
      col = col + 1
    }
  }
  dims
}

///|
fn is_xml_package_part(name : StringView) -> Bool {
  let lower = name.to_owned().to_lower()
  lower.has_suffix(".xml") ||
  lower.has_suffix(".rels") ||
  lower.has_suffix(".vml")
}

///|
fn enforce_archive_limits(
  archive : @zip.Archive,
  limits : ReadLimits,
) -> Unit raise XlsxError {
  let mut total_size = 0
  for entry in archive.entries() {
    let size = entry.data().length()
    if size > limits.max_entry_uncompressed_bytes {
      raise ResourceLimitExceeded(
        kind="entry_uncompressed_bytes",
        limit=limits.max_entry_uncompressed_bytes,
        actual=size,
      )
    }
    total_size = total_size + size
    if total_size > limits.max_total_uncompressed_bytes {
      raise ResourceLimitExceeded(
        kind="total_uncompressed_bytes",
        limit=limits.max_total_uncompressed_bytes,
        actual=total_size,
      )
    }
    if is_xml_package_part(entry.name()) && size > limits.max_xml_part_bytes {
      raise ResourceLimitExceeded(
        kind="xml_part_bytes",
        limit=limits.max_xml_part_bytes,
        actual=size,
      )
    }
    if @zip.crc32(entry.data()) != entry.crc32() {
      raise InvalidPackage(msg="ZIP entry CRC mismatch")
    }
  }
}

///|
fn require_bounded_archive(
  archive : @zip.Archive,
  limits : ReadLimits,
) -> Unit raise XlsxError {
  match
    archive.bounded_source_package_size(
      max_entries=limits.max_archive_entries,
      max_entry_uncompressed_bytes=limits.max_entry_uncompressed_bytes,
      max_total_uncompressed_bytes=limits.max_total_uncompressed_bytes,
      max_total_preserved_source_bytes=limits.max_total_preserved_source_bytes,
    ) {
    Some(package_bytes) =>
      if package_bytes > limits.max_package_bytes {
        raise ResourceLimitExceeded(
          kind="package_bytes",
          limit=limits.max_package_bytes,
          actual=package_bytes,
        )
      }
    None => raise UnboundedArchive
  }
  if archive.entries().length() > limits.max_archive_entries {
    raise ResourceLimitExceeded(
      kind="entry_count",
      limit=limits.max_archive_entries,
      actual=archive.entries().length(),
    )
  }
  enforce_archive_limits(archive, limits)
}

///|
fn read_limited_archive(
  bytes : BytesView,
  limits : ReadLimits,
) -> @zip.Archive raise XlsxError {
  @zip.read_limited(
    bytes,
    max_package_bytes=limits.max_package_bytes,
    max_entries=limits.max_archive_entries,
    max_entry_uncompressed_bytes=limits.max_entry_uncompressed_bytes,
    max_total_uncompressed_bytes=limits.max_total_uncompressed_bytes,
    // The ZIP package preserves exact source records for lossless rewrites.
    // Bound that second compressed representation independently from inflation.
    max_total_preserved_source_bytes=limits.max_total_preserved_source_bytes,
  ) catch {
    ResourceLimitExceeded(kind~, limit~, actual~) =>
      raise ResourceLimitExceeded(kind~, limit~, actual~)
    _ => raise InvalidPackage(msg="unreadable ZIP package")
  }
}

///|
fn check_source_package_size(
  bytes : BytesView,
  limits : ReadLimits,
) -> Unit raise XlsxError {
  if bytes.length() > limits.max_package_bytes {
    raise ResourceLimitExceeded(
      kind="package_bytes",
      limit=limits.max_package_bytes,
      actual=bytes.length(),
    )
  }
}

///|
fn first_existing_rel_target_path(
  targets : Map[String, String],
  source_part : StringView,
  part_names : Map[String, String],
) -> String? raise XlsxError {
  for _, target in targets {
    let path = actual_relationship_target_path(source_part, target, part_names)
    if part_names.contains(path.to_lower()) {
      return Some(path)
    }
  }
  None
}

///|
fn first_existing_workbook_rel_target_path(
  targets : Map[String, String],
  workbook_part : StringView,
  part_names : Map[String, String],
) -> String? raise XlsxError {
  for _, target in targets {
    let path = resolve_part_rel_target(workbook_part, target)
    match part_names.get(path.to_lower()) {
      Some(actual) => return Some(actual)
      None => ()
    }
  }
  None
}

///|
fn archive_part_name_index(
  archive : @zip.Archive,
) -> Map[String, String] raise XlsxError {
  let names : Map[String, String] = Map([])
  for entry in archive.entries() {
    let name = entry.name()
    let key = name.to_lower()
    match names.get(key) {
      Some(existing) if existing != name =>
        raise InvalidPackage(msg="case-insensitive ZIP part name collision")
      Some(_) => ()
      None => names[key] = name
    }
  }
  names
}

///|
fn actual_archive_part_path(
  part_names : Map[String, String],
  requested : String,
) -> String {
  part_names.get(requested.to_lower()).unwrap_or(requested)
}

///|
fn actual_relationship_part_path(
  source_part : StringView,
  part_names : Map[String, String],
) -> String raise XlsxError {
  actual_archive_part_path(part_names, rels_path_for_part(source_part))
}

///|
fn actual_relationship_target_path(
  source_part : StringView,
  target : StringView,
  part_names : Map[String, String],
) -> String raise XlsxError {
  let source_relative = resolve_part_rel_target(source_part, target)
  match part_names.get(source_relative.to_lower()) {
    Some(actual) => actual
    None => {
      // Some producers emit package-root paths without the leading slash.
      // Standards-compliant source-relative lookup wins when both exist; this
      // fallback retains tolerant reads only when the root spelling names an
      // actual archive part.
      let package_root = try normalize_rel_part_path(target) catch {
        _ => None
      } noraise {
        path => part_names.get(path.to_lower())
      }
      package_root.unwrap_or(source_relative)
    }
  }
}

///|
fn workbook_related_part_path(
  workbook_rels : StringView,
  relationship_type : StringView,
  workbook_part : StringView,
  fallback : StringView,
  part_names : Map[String, String],
) -> String? raise XlsxError {
  let targets = parse_relationship_targets(workbook_rels, relationship_type)
  match
    first_existing_workbook_rel_target_path(targets, workbook_part, part_names) {
    Some(path) => Some(path)
    None =>
      match first_relationship_target(targets) {
        Some(target) =>
          Some(
            actual_archive_part_path(
              part_names,
              resolve_part_rel_target(workbook_part, target),
            ),
          )
        None => part_names.get(fallback.to_owned().to_lower())
      }
  }
}

///|
fn read_zip_archive_core_unchecked(
  archive : @zip.Archive,
  options : Options,
  limits : ReadLimits,
  cancelled : () -> Bool,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let part_names = archive_part_name_index(archive)
  let read_budget = ReadBudget::new(limits, cancelled~)
  let decode_source = (value : BytesView) => {
    if value.length() > limits.max_xml_part_bytes {
      raise ResourceLimitExceeded(
        kind="xml_part_bytes",
        limit=limits.max_xml_part_bytes,
        actual=value.length(),
      )
    }
    let decoded = decode_utf8(value, transcoder)
    read_budget.scan_xml(decoded)
    decoded
  }
  let decode = (value : BytesView) => {
    let decoded = decode_source(value)
    read_budget.charge_work(decoded.length())
    canonicalize_xlsx_xml(decoded)
  }
  let workbook_xml_part_path = actual_archive_part_path(
    part_names,
    resolve_workbook_xml_part_path(archive, part_names, decode),
  )
  let workbook_bytes = match archive.get(workbook_xml_part_path) {
    Some(value) => value
    None => raise MissingPart(path=workbook_xml_part_path)
  }
  let workbook_source_xml = decode_source(workbook_bytes)
  read_budget.charge_work(workbook_source_xml.length())
  let workbook_xml = canonicalize_xlsx_xml(workbook_source_xml)
  let workbook_rels_path = actual_archive_part_path(
    part_names,
    rels_path_for_part(workbook_xml_part_path),
  )
  let workbook_rels = match archive.get(workbook_rels_path) {
    Some(value) => decode(value)
    None => raise MissingPart(path=workbook_rels_path)
  }
  let sheets = parse_workbook_sheets(
    workbook_source_xml,
    limits.max_workbook_sheets,
  )
  let sheet_names : Array[String] = []
  for entry in sheets {
    sheet_names.push(entry.name)
  }
  let defined_names = parse_defined_names(workbook_xml, sheet_names)
  let active_index = match parse_active_sheet_index(workbook_xml) {
    Some(value) => value
    None => 0
  }
  let safe_active_index = if active_index < 0 || active_index >= sheets.length() {
    0
  } else {
    active_index
  }
  let shared_strings_path = workbook_related_part_path(
    workbook_rels, rel_shared_strings, workbook_xml_part_path, shared_strings_part_path,
    part_names,
  )
  let shared_strings = match shared_strings_path {
    Some(path) =>
      match archive.get(path) {
        Some(value) => parse_shared_strings(decode(value))
        None => raise MissingPart(path~)
      }
    None => []
  }
  let styles_path = workbook_related_part_path(
    workbook_rels, rel_styles, workbook_xml_part_path, styles_part_path, part_names,
  )
  let (
    styles,
    conditional_styles,
    default_font,
    default_table_style,
    default_pivot_style,
    indexed_colors,
    mru_colors_xml,
    styles_ext_lst_xml,
  ) = match styles_path {
    Some(path) => {
      let value = match archive.get(path) {
        Some(value) => value
        None => raise MissingPart(path~)
      }
      let styles_xml = decode(value)
      let (styles, conditional_styles) = parse_styles(styles_xml)
      let (default_table_style, default_pivot_style) = parse_table_styles_defaults(
        styles_xml,
      )
      let indexed_colors = parse_indexed_colors(styles_xml)
      let mru_colors_xml = parse_mru_colors_xml(styles_xml)
      let styles_ext_lst_xml = parse_styles_ext_lst_xml(styles_xml)
      (
        styles,
        conditional_styles,
        parse_default_font(styles_xml),
        default_table_style,
        default_pivot_style,
        indexed_colors,
        mru_colors_xml,
        styles_ext_lst_xml,
      )
    }
    None =>
      (
        [Style::new()],
        [],
        "Calibri",
        "TableStyleMedium9",
        "PivotStyleLight16",
        None,
        None,
        None,
      )
  }
  let theme_path = workbook_related_part_path(
    workbook_rels, rel_theme, workbook_xml_part_path, theme_part_path, part_names,
  )
  let theme_xml = match theme_path {
    Some(path) =>
      match archive.get(path) {
        Some(value) => Some(decode(value))
        None => raise MissingPart(path~)
      }
    None => None
  }
  let theme_colors = match theme_xml {
    Some(xml) => parse_theme_colors(xml)
    None => None
  }
  let core_properties = match archive.get("docProps/core.xml") {
    Some(value) => parse_core_properties(decode(value))
    None => CoreProperties::new()
  }
  let app_properties = match archive.get("docProps/app.xml") {
    Some(value) => parse_app_properties(decode(value))
    None => AppProperties::new()
  }
  let custom_properties = match archive.get("docProps/custom.xml") {
    Some(value) => parse_custom_properties(decode(value))
    None => []
  }
  let workbook_props = parse_workbook_props(workbook_xml)
  let calc_props = parse_calc_props(workbook_xml)
  let workbook_protection = parse_workbook_protection(workbook_xml)
  let style_count = styles.length()
  let cell_images = match archive.get("xl/cellimages.xml") {
    Some(value) => {
      let rels_xml = match archive.get("xl/_rels/cellimages.xml.rels") {
        Some(rels) => decode(rels)
        None => ""
      }
      parse_cell_images(decode(value), rels_xml, archive)
    }
    None => []
  }
  let rich_value_images = parse_rich_value_images(archive, decode)
  let rich_value_media : Map[String, Bytes] = Map([])
  match rich_value_images {
    Some(data) => {
      for _, target in data.rel_targets {
        let path = normalize_cell_image_target(target)
        match archive.get(path) {
          Some(bytes) => rich_value_media[path] = bytes.to_owned()
          None => ()
        }
      }
      for _, target in data.web_rel_targets {
        let path = normalize_cell_image_target(target)
        match archive.get(path) {
          Some(bytes) => rich_value_media[path] = bytes.to_owned()
          None => ()
        }
      }
    }
    None => ()
  }
  let workbook : Workbook = {
    sheets: [],
    chart_sheets: [],
    sheet_order: [],
    styles,
    conditional_styles,
    defined_names,
    core_properties,
    app_properties,
    custom_properties,
    vba_project: None,
    workbook_props,
    calc_props,
    default_font,
    default_table_style,
    default_pivot_style,
    theme_colors,
    theme_xml,
    indexed_colors,
    mru_colors_xml,
    styles_ext_lst_xml,
    io_context: workbook_io_context_with_transcoder(
      empty_workbook_io_context(),
      transcoder,
    ),
    options,
    workbook_protection,
    active_sheet_index: safe_active_index,
    cell_images,
    rich_value_images,
    rich_value_media,
  }
  let slicer_cache_defs = parse_slicer_cache_definitions(
    workbook_rels, workbook_xml_part_path, part_names, archive, decode,
  )
  let vba_targets = parse_relationship_targets(workbook_rels, rel_vba_project)
  let vba_path = match
    first_existing_workbook_rel_target_path(
      vba_targets, workbook_xml_part_path, part_names,
    ) {
    Some(path) => Some(path)
    None =>
      match first_relationship_target(vba_targets) {
        Some(target) =>
          Some(
            actual_archive_part_path(
              part_names,
              resolve_part_rel_target(workbook_xml_part_path, target),
            ),
          )
        None => None
      }
  }
  match vba_path {
    Some(path) => {
      let vba_bytes = match archive.get(path) {
        Some(value) => value
        None => raise MissingPart(path~)
      }
      workbook.vba_project = Some(vba_bytes.to_owned())
    }
    None => ()
  }
  let worksheet_targets = parse_relationship_targets(
    workbook_rels, rel_worksheet,
  )
  let chartsheet_targets = parse_relationship_targets(
    workbook_rels, rel_chartsheet,
  )
  let seen_sheet_parts : Set[String] = Set([])
  let resolved_sheet_parts : Map[String, String] = Map([])
  for entry in sheets {
    let rel_id = entry.rel_id
    let is_worksheet = worksheet_targets.contains(rel_id)
    let is_chartsheet = chartsheet_targets.contains(rel_id)
    if is_worksheet == is_chartsheet {
      raise InvalidXml(msg="sheet relationship missing or ambiguous")
    }
    let target = if is_worksheet {
      match worksheet_targets.get(rel_id) {
        Some(value) => value
        None => raise InvalidXml(msg="worksheet target missing")
      }
    } else {
      match chartsheet_targets.get(rel_id) {
        Some(value) => value
        None => raise InvalidXml(msg="chartsheet target missing")
      }
    }
    let path = actual_archive_part_path(
      part_names,
      resolve_part_rel_target(workbook_xml_part_path, target),
    )
    let part_key = path.to_lower()
    if seen_sheet_parts.contains(part_key) {
      raise InvalidXml(msg="sheet part referenced more than once")
    }
    seen_sheet_parts.add(part_key)
    resolved_sheet_parts[rel_id] = path
  }
  for entry in sheets {
    let name = entry.name
    let state = entry.state
    let rel_id = entry.rel_id
    let is_worksheet = worksheet_targets.contains(rel_id)
    if is_worksheet {
      let sheet_path = match resolved_sheet_parts.get(rel_id) {
        Some(value) => value
        None => raise InvalidXml(msg="worksheet target missing")
      }
      let sheet_bytes = match archive.get(sheet_path) {
        Some(value) => value
        None => raise MissingPart(path=sheet_path)
      }
      let sheet_xml = decode(sheet_bytes)
      let (
        cells,
        merged_cells,
        auto_filter,
        row_dimensions,
        col_dimensions,
        page_margins,
        page_layout,
        header_footer,
        sheet_protection,
        row_breaks,
        col_breaks,
        sheet_views,
        sheet_props,
        dimension_ref,
        picture_rel_id,
      ) = parse_worksheet(
        sheet_xml,
        shared_strings,
        style_count,
        budget=read_budget,
      )
      let hyperlink_elements = parse_hyperlink_elements(sheet_xml)
      let table_part_ids = parse_table_part_ids(sheet_xml)
      let pivot_part_ids = parse_pivot_table_part_ids(sheet_xml)
      let slicer_rel_ids = parse_sheet_slicer_rel_ids(sheet_xml)
      let drawing_rel_id = parse_legacy_drawing_rel_id(sheet_xml, "drawing")
      let legacy_drawing_rel_id = parse_legacy_drawing_rel_id(
        sheet_xml, "legacyDrawing",
      )
      let legacy_drawing_hf_rel_id = parse_legacy_drawing_rel_id(
        sheet_xml, "legacyDrawingHF",
      )
      let sparkline_groups = parse_sparkline_groups(sheet_xml)
      let data_validations = parse_data_validations(
        sheet_xml,
        budget=read_budget,
      )
      for dv in parse_data_validations_x14(sheet_xml, budget=read_budget) {
        data_validations.push(dv)
      }
      let conditional_formats = parse_conditional_formats(
        sheet_xml,
        budget=read_budget,
      )
      for cf in parse_conditional_formats_x14(sheet_xml, budget=read_budget) {
        conditional_formats.push(cf)
      }
      let x14_data_bars = parse_x14_data_bars(sheet_xml, budget=read_budget)
      let unknown_ext_blocks = parse_unknown_worksheet_ext_blocks(sheet_xml)
      let ignored_errors = parse_ignored_errors(sheet_xml, budget=read_budget)
      let mut needs_hyperlink_rels = false
      for link in hyperlink_elements {
        if link.r_id is Some(_) {
          needs_hyperlink_rels = true
          break
        }
      }
      let needs_rels = table_part_ids.length() > 0 ||
        pivot_part_ids.length() > 0 ||
        slicer_rel_ids.length() > 0 ||
        needs_hyperlink_rels ||
        drawing_rel_id is Some(_) ||
        legacy_drawing_rel_id is Some(_) ||
        legacy_drawing_hf_rel_id is Some(_) ||
        picture_rel_id is Some(_)
      let rels_path = actual_relationship_part_path(sheet_path, part_names)
      let rels_xml = match archive.get(rels_path) {
        Some(rels_bytes) => decode(rels_bytes)
        None => if needs_rels { raise MissingPart(path=rels_path) } else { "" }
      }
      let slicer_part_entries = if slicer_rel_ids.length() == 0 {
        []
      } else {
        if rels_xml == "" {
          raise InvalidXml(msg="slicer relationship missing")
        }
        let rel_targets = parse_relationship_targets(rels_xml, rel_slicer)
        let parsed : Array[ParsedSlicerPartEntry] = []
        let seen_paths : Map[String, Bool] = Map([])
        for rel_id in slicer_rel_ids {
          let target = match rel_targets.get(rel_id) {
            Some(value) => value
            None => raise InvalidXml(msg="slicer relationship missing")
          }
          let slicer_path = actual_relationship_target_path(
            sheet_path, target, part_names,
          )
          if seen_paths.contains(slicer_path) {
            continue
          }
          seen_paths[slicer_path] = true
          let slicer_bytes = match archive.get(slicer_path) {
            Some(value) => value
            None => raise MissingPart(path=slicer_path)
          }
          let slicer_xml = decode(slicer_bytes)
          parsed.append(parse_slicer_part_entries(slicer_xml))
        }
        parsed
      }
      let sheet_background = match picture_rel_id {
        Some(rel_id) => {
          if rels_xml == "" {
            raise InvalidXml(msg="picture relationship missing")
          }
          let image_targets = parse_relationship_targets(rels_xml, rel_image)
          let target = match image_targets.get(rel_id) {
            Some(value) => value
            None => raise InvalidXml(msg="picture target missing")
          }
          let image_path = actual_relationship_target_path(
            sheet_path, target, part_names,
          )
          let image_bytes = match archive.get(image_path) {
            Some(value) => value
            None => raise MissingPart(path=image_path)
          }
          let path_text = target.to_string()
          let extension = match path_text.rev_find(".") {
            Some(pos) =>
              if pos + 1 < path_text.length() {
                let view = path_text[pos + 1:]
                view.to_owned().to_lower()
              } else {
                raise InvalidSheetBackground(msg="image extension missing")
              }
            None => raise InvalidSheetBackground(msg="image extension missing")
          }
          let content_type = match image_content_type(extension) {
            Some(value) => value
            None =>
              raise InvalidSheetBackground(msg="unsupported image extension")
          }
          Some({ data: image_bytes.to_owned(), extension, content_type })
        }
        None => None
      }
      let hyperlinks = if hyperlink_elements.length() == 0 {
        []
      } else {
        let rel_targets = if needs_hyperlink_rels {
          parse_relationship_targets(rels_xml, rel_hyperlink)
        } else {
          Map([])
        }
        let parsed_links : Array[Hyperlink] = []
        for link in hyperlink_elements {
          match link.r_id {
            Some(rel_id) => {
              let target = match rel_targets.get(rel_id) {
                Some(value) => value
                None => raise InvalidXml(msg="hyperlink relationship missing")
              }
              parsed_links.push({
                reference: link.reference,
                target,
                link_type: External,
                location: link.location,
                display: link.display,
                tooltip: link.tooltip,
              })
            }
            None =>
              match link.location {
                Some(location) =>
                  parsed_links.push({
                    reference: link.reference,
                    target: location,
                    link_type: Location,
                    location: Some(location),
                    display: link.display,
                    tooltip: link.tooltip,
                  })
                None => raise InvalidXml(msg="hyperlink target missing")
              }
          }
        }
        parsed_links
      }
      let tables = if table_part_ids.length() == 0 {
        []
      } else {
        let rel_targets = parse_relationship_targets(rels_xml, rel_table)
        let parsed_tables : Array[Table] = []
        for rel_id in table_part_ids {
          let target = match rel_targets.get(rel_id) {
            Some(value) => value
            None => raise InvalidXml(msg="table relationship missing")
          }
          let table_path = actual_relationship_target_path(
            sheet_path, target, part_names,
          )
          let table_bytes = match archive.get(table_path) {
            Some(value) => value
            None => raise MissingPart(path=table_path)
          }
          let table_xml = decode(table_bytes)
          parsed_tables.push(parse_table_xml(table_xml))
        }
        parsed_tables
      }
      let pivot_tables = {
        let rel_targets = if rels_xml == "" {
          Map([])
        } else {
          parse_relationship_targets(rels_xml, rel_pivot_table)
        }
        let pivot_rel_ids : Array[String] = []
        if pivot_part_ids.length() > 0 {
          for rel_id in pivot_part_ids {
            pivot_rel_ids.push(rel_id)
          }
        } else {
          for rel_id, _target in rel_targets {
            pivot_rel_ids.push(rel_id)
          }
        }
        if pivot_rel_ids.length() == 0 {
          []
        } else {
          let parsed_pivots : Array[PivotTable] = []
          for rel_id in pivot_rel_ids {
            let target = match rel_targets.get(rel_id) {
              Some(value) => value
              None => raise InvalidXml(msg="pivot table relationship missing")
            }
            let pivot_path = actual_relationship_target_path(
              sheet_path, target, part_names,
            )
            let pivot_bytes = match archive.get(pivot_path) {
              Some(value) => value
              None => raise MissingPart(path=pivot_path)
            }
            let pivot_xml = decode(pivot_bytes)
            let pivot_rels_path = actual_relationship_part_path(
              pivot_path, part_names,
            )
            let pivot_rels_bytes = match archive.get(pivot_rels_path) {
              Some(value) => value
              None => raise MissingPart(path=pivot_rels_path)
            }
            let pivot_rels_xml = decode(pivot_rels_bytes)
            let cache_targets = parse_relationship_targets(
              pivot_rels_xml, rel_pivot_cache,
            )
            let cache_path = match
              first_existing_rel_target_path(
                cache_targets, pivot_path, part_names,
              ) {
              Some(path) => path
              None => {
                let cache_target = match
                  first_relationship_target(cache_targets) {
                  Some(value) => value
                  None =>
                    raise InvalidXml(msg="pivot cache relationship missing")
                }
                actual_relationship_target_path(
                  pivot_path, cache_target, part_names,
                )
              }
            }
            let cache_bytes = match archive.get(cache_path) {
              Some(value) => value
              None => raise MissingPart(path=cache_path)
            }
            let cache_xml = decode(cache_bytes)
            let cache_id = parse_id_from_path(
              cache_path, "xl/pivotCache/pivotCacheDefinition",
            )
            let pivot_id = parse_id_from_path(
              pivot_path, "xl/pivotTables/pivotTable",
            )
            let cache_records_xml = match
              archive.get(actual_relationship_part_path(cache_path, part_names)) {
              Some(value) => {
                let cache_rels_xml = decode(value)
                let record_targets = parse_relationship_targets(
                  cache_rels_xml, rel_pivot_cache_records,
                )
                let record_path = match
                  first_existing_rel_target_path(
                    record_targets, cache_path, part_names,
                  ) {
                  Some(path) => Some(path)
                  None =>
                    match first_relationship_target(record_targets) {
                      Some(record_target) =>
                        Some(
                          actual_relationship_target_path(
                            cache_path, record_target, part_names,
                          ),
                        )
                      None => None
                    }
                }
                match record_path {
                  Some(path) => {
                    let record_bytes = match archive.get(path) {
                      Some(value) => value
                      None => raise MissingPart(path~)
                    }
                    Some(decode(record_bytes))
                  }
                  None => None
                }
              }
              None => None
            }
            parsed_pivots.push({
              name: parse_pivot_table_name(pivot_xml),
              table_id: pivot_id,
              cache_id,
              table_xml: pivot_xml,
              cache_definition_xml: cache_xml,
              cache_records_xml,
            })
          }
          parsed_pivots
        }
      }
      let vml_targets = if legacy_drawing_rel_id is Some(_) ||
        legacy_drawing_hf_rel_id is Some(_) {
        parse_relationship_targets(rels_xml, rel_vml)
      } else {
        Map([])
      }
      let vml_drawing_xml = match legacy_drawing_rel_id {
        Some(rel_id) => {
          let target = match vml_targets.get(rel_id) {
            Some(value) => value
            None => raise InvalidXml(msg="vml drawing relationship missing")
          }
          let vml_path = actual_relationship_target_path(
            sheet_path, target, part_names,
          )
          let vml_bytes = match archive.get(vml_path) {
            Some(value) => value
            None => raise MissingPart(path=vml_path)
          }
          Some(decode(vml_bytes))
        }
        None => None
      }
      let vml_drawing_hf_xml = match legacy_drawing_hf_rel_id {
        Some(rel_id) => {
          let target = match vml_targets.get(rel_id) {
            Some(value) => value
            None => raise InvalidXml(msg="vml drawing hf relationship missing")
          }
          let vml_path = actual_relationship_target_path(
            sheet_path, target, part_names,
          )
          let vml_bytes = match archive.get(vml_path) {
            Some(value) => value
            None => raise MissingPart(path=vml_path)
          }
          Some((decode(vml_bytes), vml_path))
        }
        None => None
      }
      let (vml_drawing_hf_xml, vml_drawing_hf_path) = match vml_drawing_hf_xml {
        Some((xml, path)) => (Some(xml), Some(path))
        None => (None, None)
      }
      let header_footer_images = match
        (vml_drawing_hf_xml, vml_drawing_hf_path) {
        (Some(xml), Some(path)) => {
          let vml_rels_xml = match
            archive.get(actual_relationship_part_path(path, part_names)) {
            Some(value) => Some(decode(value))
            None => None
          }
          parse_header_footer_images_from_vml(
            xml, vml_rels_xml, path, part_names, archive,
          )
        }
        _ => []
      }
      let comments = if rels_xml == "" {
        []
      } else {
        let comment_targets = parse_relationship_targets(rels_xml, rel_comments)
        let parsed_comments : Array[Comment] = []
        for _rel_id, target in comment_targets {
          let comment_path = actual_relationship_target_path(
            sheet_path, target, part_names,
          )
          let comment_bytes = match archive.get(comment_path) {
            Some(value) => value
            None => raise MissingPart(path=comment_path)
          }
          let comment_xml = decode(comment_bytes)
          let entries = parse_comments_xml(comment_xml)
          parsed_comments.append(entries)
        }
        parsed_comments
      }
      let form_controls = match vml_drawing_xml {
        Some(xml) => parse_form_controls_vml(xml)
        None => []
      }
      let sheet = {
        name,
        sheet_views,
        dimension_ref,
        cells,
        cell_index: Map([]),
        cell_index_valid: false,
        merged_cells,
        auto_filter,
        page_margins,
        page_layout,
        header_footer,
        sheet_protection,
        sheet_props,
        sheet_background,
        row_breaks,
        col_breaks,
        hyperlinks,
        tables,
        sparkline_groups,
        pivot_tables,
        vml_drawing_xml,
        vml_drawing_hf_xml,
        images: [],
        header_footer_images,
        charts: [],
        shapes: [],
        form_controls,
        slicers: [],
        data_validations,
        conditional_formats,
        x14_data_bars,
        unknown_ext_blocks,
        x14_cf_rule_id_counter: 1,
        ignored_errors,
        comments,
        row_dimensions,
        col_dimensions,
        state,
        stream_state: Idle,
        cell_vm: if rich_value_images is Some(_) {
          parse_cell_vm_map(sheet_xml)
        } else {
          Map([])
        },
      }
      let mut slicer_anchor_info : Map[String, SlicerAnchorInfo] = Map([])
      match drawing_rel_id {
        Some(rel_id) => {
          if rels_xml == "" {
            raise InvalidXml(msg="drawing relationship missing")
          }
          let drawing_targets = parse_relationship_targets(
            rels_xml, rel_drawing,
          )
          let drawing_target = match drawing_targets.get(rel_id) {
            Some(value) => value
            None => raise InvalidXml(msg="drawing target missing")
          }
          let drawing_path = actual_relationship_target_path(
            sheet_path, drawing_target, part_names,
          )
          let drawing_bytes = match archive.get(drawing_path) {
            Some(value) => value
            None => raise MissingPart(path=drawing_path)
          }
          let drawing_xml = decode(drawing_bytes)
          let drawing_metrics = drawing_metrics_for_sheet(sheet)
          if slicer_part_entries.length() > 0 {
            slicer_anchor_info = parse_drawing_slicer_anchors(
              drawing_xml, drawing_metrics,
            )
          }
          let drawing_rels_xml = match
            archive.get(actual_relationship_part_path(drawing_path, part_names)) {
            Some(value) => decode(value)
            None => ""
          }
          let drawing_images = parse_drawing_images(
            drawing_xml, drawing_rels_xml, drawing_path, part_names, drawing_metrics,
            archive,
          )
          sheet.images.append(drawing_images)
          let drawing_charts = parse_drawing_charts(
            drawing_xml, drawing_rels_xml, drawing_path, part_names, drawing_metrics,
            archive, decode,
          )
          sheet.charts.append(drawing_charts)
          let drawing_shapes = parse_drawing_shapes(drawing_xml)
          sheet.shapes.append(drawing_shapes)
        }
        None => ()
      }
      for entry in slicer_part_entries {
        let cache_def = slicer_cache_defs.get(entry.cache)
        let source_name = match cache_def {
          Some(def) =>
            if def.source_name != "" {
              def.source_name
            } else {
              entry.name
            }
          None => entry.name
        }
        let item_desc = match cache_def {
          Some(def) => def.item_desc
          None => false
        }
        let mut cell = ""
        let mut width = 200
        let mut height = 200
        let mut macro_name = ""
        let format = GraphicOptions::new()
        match slicer_anchor_info.get(entry.name) {
          Some(info) => {
            cell = info.cell
            if info.width > 0 {
              width = info.width
            }
            if info.height > 0 {
              height = info.height
            }
            macro_name = info.macro_name
            if info.offset_x != 0 {
              format.offset_x = Some(info.offset_x)
            }
            if info.offset_y != 0 {
              format.offset_y = Some(info.offset_y)
            }
            if info.alt_text != "" {
              format.alt_text = Some(info.alt_text)
            }
            format.positioning = Some(info.positioning)
            format.locked = Some(info.locked)
            format.print_object = Some(info.print_object)
          }
          None => {
            format.positioning = Some(TwoCell)
            format.locked = Some(true)
            format.print_object = Some(true)
          }
        }
        sheet.slicers.push({
          name: entry.name,
          cache: entry.cache,
          source_name,
          cell,
          table_sheet: "",
          table_name: "",
          caption: entry.caption,
          macro_name,
          width,
          height,
          display_header: entry.display_header,
          item_desc,
          format,
        })
      }
      workbook.sheets.push(sheet)
      workbook.sheet_order.push(Worksheet(workbook.sheets.length() - 1))
    } else {
      let chartsheet_path = match resolved_sheet_parts.get(rel_id) {
        Some(value) => value
        None => raise InvalidXml(msg="chartsheet target missing")
      }
      let chartsheet_bytes = match archive.get(chartsheet_path) {
        Some(value) => value
        None => raise MissingPart(path=chartsheet_path)
      }
      let chartsheet_xml = decode(chartsheet_bytes)
      let drawing_rel_id = parse_legacy_drawing_rel_id(
        chartsheet_xml, "drawing",
      )
      let drawing_rel = match drawing_rel_id {
        Some(value) => value
        None => raise InvalidXml(msg="chartsheet drawing missing")
      }
      let chartsheet_rels_path = actual_relationship_part_path(
        chartsheet_path, part_names,
      )
      let chartsheet_rels_bytes = match archive.get(chartsheet_rels_path) {
        Some(value) => value
        None => raise MissingPart(path=chartsheet_rels_path)
      }
      let chartsheet_rels_xml = decode(chartsheet_rels_bytes)
      let drawing_targets = parse_relationship_targets(
        chartsheet_rels_xml, rel_drawing,
      )
      let drawing_target = match drawing_targets.get(drawing_rel) {
        Some(value) => value
        None => raise InvalidXml(msg="drawing target missing")
      }
      let drawing_path = actual_relationship_target_path(
        chartsheet_path, drawing_target, part_names,
      )
      let drawing_rels_path = actual_relationship_part_path(
        drawing_path, part_names,
      )
      let drawing_rels_bytes = match archive.get(drawing_rels_path) {
        Some(value) => value
        None => raise MissingPart(path=drawing_rels_path)
      }
      let drawing_rels_xml = decode(drawing_rels_bytes)
      let chart_targets = parse_relationship_targets(
        drawing_rels_xml, rel_chart,
      )
      let chart_path = match
        first_existing_rel_target_path(chart_targets, drawing_path, part_names) {
        Some(path) => path
        None => {
          let chart_target = match first_relationship_target(chart_targets) {
            Some(value) => value
            None => raise InvalidXml(msg="chart target missing")
          }
          actual_relationship_target_path(
            drawing_path, chart_target, part_names,
          )
        }
      }
      let chart_bytes = match archive.get(chart_path) {
        Some(value) => value
        None => raise MissingPart(path=chart_path)
      }
      let chart_xml = decode(chart_bytes)
      let chart_sheet = ChartSheet::new(name, chart_xml)
      chart_sheet.state = state
      workbook.chart_sheets.push(chart_sheet)
      workbook.sheet_order.push(ChartSheet(workbook.chart_sheets.length() - 1))
    }
  }
  resolve_slicer_sources_after_read(workbook, slicer_cache_defs)
  workbook
}

///|
fn read_zip_archive_core(
  archive : @zip.Archive,
  options : Options,
  limits : ReadLimits,
  cancelled : () -> Bool,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  match transcoder {
    Some(decode) =>
      read_zip_archive_core_unchecked(
        archive,
        options,
        limits,
        cancelled,
        transcoder=decode,
      ) catch {
        InvalidCellRef(value~) =>
          raise InvalidXml(msg="coordinate reference invalid: \{value}")
        other => raise other
      }
    None =>
      read_zip_archive_core_unchecked(archive, options, limits, cancelled) catch {
        InvalidCellRef(value~) =>
          raise InvalidXml(msg="coordinate reference invalid: \{value}")
        other => raise other
      }
  }
}

///|
fn read_zip_bytes(
  bytes : BytesView,
  options? : Options = Options::new(),
  limits? : ReadLimits = ReadLimits::new(),
  cancelled? : () -> Bool = () => false,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let archive = read_limited_archive(bytes, limits)
  require_bounded_archive(archive, limits)
  match transcoder {
    Some(value) =>
      read_zip_archive_core(
        archive,
        options,
        limits,
        cancelled,
        transcoder=value,
      )
    None => read_zip_archive_core(archive, options, limits, cancelled)
  }
}

///|
/// Reads a workbook from an already-inflated ZIP archive without a second
/// decompression pass. The archive must be pristine and carry non-forgeable
/// `zip.read_limited` provenance at least as strict as `limits`; constructed,
/// compatibility-read, or mutated archives fail with `UnboundedArchive`.
pub fn read_bounded_archive(
  archive : @zip.Archive,
  options? : Options = Options::new(),
  limits? : ReadLimits = ReadLimits::new(),
  cancelled? : () -> Bool = () => false,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  require_bounded_archive(archive, limits)
  match transcoder {
    Some(value) =>
      read_zip_archive_core(
        archive,
        options,
        limits,
        cancelled,
        transcoder=value,
      )
    None => read_zip_archive_core(archive, options, limits, cancelled)
  }
}

///|
/// Reads an XLSX package under a fail-closed resource policy.
///
/// `limits` applies to the compressed source, ZIP structure and expansion, and
/// individual XML-like OOXML parts. Encrypted packages require
/// `read_with_password` or an `Options` value containing a password.
pub fn read(
  bytes : BytesView,
  options? : Options = Options::new(),
  limits? : ReadLimits = ReadLimits::new(),
  cancelled? : () -> Bool = () => false,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  check_source_package_size(bytes, limits)
  if options.password != "" {
    match transcoder {
      Some(value) =>
        return read_with_password(
          bytes,
          options.password,
          options~,
          limits~,
          cancelled~,
          transcoder=value,
        )
      None =>
        return read_with_password(
          bytes,
          options.password,
          options~,
          limits~,
          cancelled~,
        )
    }
  }
  if is_encrypted_package(bytes) {
    raise EncryptedPackage
  }
  match transcoder {
    Some(value) =>
      read_zip_bytes(bytes, options~, limits~, cancelled~, transcoder=value)
    None => read_zip_bytes(bytes, options~, limits~, cancelled~)
  }
}

///|
/// Reads an XLSX package with an explicit password under a fail-closed resource
/// policy. Resource failures remain `ResourceLimitExceeded`; a verified
/// password preserves malformed-package errors, while an unverified payload
/// that is not a valid ZIP is classified as `InvalidPassword`.
pub fn read_with_password(
  bytes : BytesView,
  password : String,
  options? : Options = Options::new(),
  limits? : ReadLimits = ReadLimits::new(),
  cancelled? : () -> Bool = () => false,
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  check_source_package_size(bytes, limits)
  let resolved_options = options_with_password(options, password)
  if is_encrypted_package(bytes) {
    let archive = decrypt_encrypted_archive(bytes, password, limits~)
    require_bounded_archive(archive, limits)
    match transcoder {
      Some(value) =>
        read_zip_archive_core(
          archive,
          resolved_options,
          limits,
          cancelled,
          transcoder=value,
        )
      None =>
        read_zip_archive_core(archive, resolved_options, limits, cancelled)
    }
  } else {
    match transcoder {
      Some(value) =>
        read_zip_bytes(
          bytes,
          options=resolved_options,
          limits~,
          cancelled~,
          transcoder=value,
        )
      None =>
        read_zip_bytes(bytes, options=resolved_options, limits~, cancelled~)
    }
  }
}

///|
fn is_invalid_xml_error(
  result : Result[Font, XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
fn is_invalid_xml_fill_error(
  result : Result[Fill, XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
fn is_invalid_xml_alignment_error(
  result : Result[Alignment?, XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
fn has_border_type(borders : Array[Border], typ : String) -> Bool {
  for border in borders {
    if border.typ == typ {
      return true
    }
  }
  false
}

///|
fn border_color_by_type(borders : Array[Border], typ : String) -> String? {
  for border in borders {
    if border.typ == typ {
      return border.color
    }
  }
  None
}

///|
fn is_invalid_xml_string_array_error(
  result : Result[Array[String], XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
fn is_invalid_xml_defined_name_error(
  result : Result[Array[DefinedName], XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
test "read wb: xml encoding parser guard paths" {
  inspect(xml_encoding(b"abc") is None, content="true")
  inspect(xml_encoding(b"<?xml version=\"1.0\"?><x/>") is None, content="true")
  inspect(
    xml_encoding(b"<?xml version=\"1.0\" encoding=\"\"?><x/>") is None,
    content="true",
  )

  let with_bom_single_quote = b"\xEF\xBB\xBF<?xml version='1.0' encoding='UTF-16'?><x/>"
  inspect(
    match xml_encoding(with_bom_single_quote) {
      Some(value) => value == "UTF-16"
      None => false
    },
    content="true",
  )

  inspect(
    xml_encoding(b"<?xml version=\"1.0\" encoding=\"UT@8\"?><x/>") is None,
    content="true",
  )
  inspect(
    xml_encoding(b"<?xml version=\"1.0\" encoding=\"UTF-8?><x/>") is None,
    content="true",
  )
}

///|
test "read wb: decode_utf8 invalid paths" {
  let requires_transcoder = Ok(
    decode_utf8(b"<?xml version=\"1.0\" encoding=\"Shift_JIS\"?><x/>", None),
  ) catch {
    e => Err(e)
  }
  inspect(
    match requires_transcoder {
      Err(InvalidXml(msg~)) => msg.contains("requires charset transcoder")
      _ => false
    },
    content="true",
  )

  let invalid_utf8 = Ok(decode_utf8(b"\xFF\xFF\xFF", None)) catch {
    e => Err(e)
  }
  inspect(
    match invalid_utf8 {
      Err(InvalidXml(msg~)) => msg == "invalid utf8"
      _ => false
    },
    content="true",
  )
}

///|
test "read wb: parse_default_font fallback matrix" {
  inspect(parse_default_font("<styleSheet/>"), content="Calibri")
  inspect(parse_default_font("<fonts></fonts>"), content="Calibri")
  inspect(parse_default_font("<fonts><name"), content="Calibri")
  inspect(
    parse_default_font("<fonts><name val='Calibri\"></name></fonts>"),
    content="Calibri",
  )
  inspect(
    parse_default_font("<fonts><name val=\"Aptos\"/></fonts>"),
    content="Aptos",
  )
}

///|
test "read wb: parse_font_entry attributes and invalid numerics" {
  let font = parse_font_entry(
    (
      #|<font>
      #|  <b val="1"/><i val="1"/><strike val="1"/><outline val="1"/>
      #|  <shadow val="1"/><condense val="1"/><extend val="1"/>
      #|  <u val="double"/><sz val="11"/><charset val="1"/>
      #|  <name val="Aptos"/><family val="3"/><vertAlign val="superscript"/>
      #|  <scheme val="minor"/><color rgb="ABCDEF12" theme="1" indexed="2" tint="0.5"/>
      #|</font>
      #|,
    ),
  )
  inspect(font.bold is Some(true), content="true")
  inspect(font.italic is Some(true), content="true")
  inspect(font.strike is Some(true), content="true")
  inspect(font.outline is Some(true), content="true")
  inspect(font.shadow is Some(true), content="true")
  inspect(font.condense is Some(true), content="true")
  inspect(font.extended is Some(true), content="true")
  debug_inspect(font.underline, content="Some(\"double\")")
  debug_inspect(font.size, content="Some(11)")
  debug_inspect(font.charset, content="Some(1)")
  debug_inspect(font.family, content="Some(\"Aptos\")")
  debug_inspect(font.family_number, content="Some(3)")
  debug_inspect(font.vert_align, content="Some(\"superscript\")")
  debug_inspect(font.scheme, content="Some(\"minor\")")
  debug_inspect(font.color, content="Some(\"ABCDEF12\")")
  debug_inspect(font.color_theme, content="Some(1)")
  debug_inspect(font.color_indexed, content="Some(2)")
  debug_inspect(font.color_tint, content="Some(0.5)")

  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><sz val=\"bad\"/></font>")) catch {
        e => Err(e)
      },
      "font sz invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><charset val=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font charset invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><family val=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font family invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><color theme=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font color theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><color indexed=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font color indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><color tint=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font color tint invalid",
    ),
    content="true",
  )
}

///|
test "read wb: parse_fonts fallback and malformed font chunks" {
  let no_fonts = parse_fonts("<styleSheet/>")
  inspect(no_fonts.length(), content="1")

  let empty_fonts = parse_fonts("<fonts></fonts>")
  inspect(empty_fonts.length(), content="1")

  let missing_open_end = parse_fonts("<fonts><font</fonts>")
  inspect(missing_open_end.length(), content="1")

  let missing_close_tag = parse_fonts("<fonts><font><b/></fonts>")
  inspect(missing_close_tag.length(), content="1")
}

///|
test "read wb: parse_font_entry implicit default and none-attr branches" {
  let font = parse_font_entry(
    (
      #|<font>
      #|  <i/><outline/><condense/><extend/><u/>
      #|  <sz/><charset/><name/><family/><vertAlign/><scheme/>
      #|</font>
      #|,
    ),
  )
  inspect(font.italic is Some(true), content="true")
  inspect(font.outline is Some(true), content="true")
  inspect(font.condense is Some(true), content="true")
  inspect(font.extended is Some(true), content="true")
  debug_inspect(font.underline, content="Some(\"single\")")
  debug_inspect(font.size, content="None")
  debug_inspect(font.charset, content="None")
  debug_inspect(font.family, content="None")
  debug_inspect(font.family_number, content="None")
  debug_inspect(font.vert_align, content="None")
  debug_inspect(font.scheme, content="None")
}

///|
test "read wb: parse_fill_entry gradient and pattern guard branches" {
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill bottom=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill bottom invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill degree=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill degree invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill left=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill left invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill right=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill right invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill top=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill top invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(
        parse_fill_entry(
          "<gradientFill><stop position=\"bad\"><color rgb=\"FF112233\"/></stop></gradientFill>",
        ),
      ) catch {
        e => Err(e)
      },
      "gradientFill stop position invalid",
    ),
    content="true",
  )

  let gradient = parse_fill_entry(
    (
      #|<gradientFill type="path" bottom="0.1" degree="20" left="0.2" right="0.3" top="0.4">
      #|  <stop position="0"><color rgb="112233"/></stop>
      #|  <stop position="1"><color rgb="80112233"/></stop>
      #|</gradientFill>
      #|,
    ),
  )
  debug_inspect(gradient.typ, content="Some(\"gradient\")")
  inspect(gradient.shading is Some(_), content="true")
  inspect(gradient.colors is Some(_), content="true")
  inspect(gradient.transparency is Some(_), content="true")

  let gradient_single_stop = parse_fill_entry(
    "<gradientFill><stop position=\"0\"><color rgb=\"FF112233\"/></stop></gradientFill>",
  )
  debug_inspect(gradient_single_stop.colors, content="None")
  debug_inspect(gradient_single_stop.transparency, content="None")

  let pattern_default = parse_fill_entry(
    "<patternFill><fgColor rgb=\"112233\"/></patternFill>",
  )
  debug_inspect(pattern_default.typ, content="Some(\"pattern\")")
  debug_inspect(pattern_default.pattern, content="Some(0)")
  inspect(pattern_default.colors is Some(_), content="true")

  let pattern_unknown = parse_fill_entry(
    "<patternFill patternType=\"unknown\"><fgColor rgb=\"112233\"/></patternFill>",
  )
  debug_inspect(pattern_unknown.pattern, content="Some(0)")

  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<patternFill><fgColor theme=\"x\"/></patternFill>")) catch {
        e => Err(e)
      },
      "fill fgColor theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(
        parse_fill_entry("<patternFill><fgColor indexed=\"x\"/></patternFill>"),
      ) catch {
        e => Err(e)
      },
      "fill fgColor indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<patternFill><fgColor tint=\"x\"/></patternFill>")) catch {
        e => Err(e)
      },
      "fill fgColor tint invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<patternFill><bgColor theme=\"x\"/></patternFill>")) catch {
        e => Err(e)
      },
      "fill bgColor theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(
        parse_fill_entry("<patternFill><bgColor indexed=\"x\"/></patternFill>"),
      ) catch {
        e => Err(e)
      },
      "fill bgColor indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<patternFill><bgColor tint=\"x\"/></patternFill>")) catch {
        e => Err(e)
      },
      "fill bgColor tint invalid",
    ),
    content="true",
  )
}

///|
test "read wb: parse_fills and borders structural guard branches" {
  let no_fills = parse_fills("<styleSheet/>")
  inspect(no_fills.length(), content="0")

  let malformed_fill_open = parse_fills("<fills><fill</fills>")
  inspect(malformed_fill_open.length(), content="0")

  let self_closing_fill = parse_fills("<fills><fill/></fills>")
  inspect(self_closing_fill.length(), content="1")

  let missing_fill_close = parse_fills("<fills><fill><patternFill/></fills>")
  inspect(missing_fill_close.length(), content="0")

  let parsed_fill = parse_fills(
    (
      #|<fills>
      #|  <fill><patternFill patternType="solid"><fgColor rgb="FF112233"/></patternFill></fill>
      #|</fills>
      #|,
    ),
  )
  inspect(parsed_fill.length(), content="1")
  debug_inspect(parsed_fill[0].typ, content="Some(\"pattern\")")

  let no_borders = parse_borders("<styleSheet/>")
  inspect(no_borders.length(), content="1")
  inspect(no_borders[0].length(), content="0")

  let empty_borders = parse_borders("<borders></borders>")
  inspect(empty_borders.length(), content="1")
  inspect(empty_borders[0].length(), content="0")

  let malformed_border_open = parse_borders("<borders><border</borders>")
  inspect(malformed_border_open.length(), content="1")
  inspect(malformed_border_open[0].length(), content="0")

  let self_closing_border = parse_borders("<borders><border/></borders>")
  inspect(self_closing_border.length(), content="1")
  inspect(self_closing_border[0].length(), content="0")

  let missing_border_close = parse_borders("<borders><border><left/></borders>")
  inspect(missing_border_close.length(), content="1")
  inspect(missing_border_close[0].length(), content="0")

  let parsed_borders = parse_borders(
    (
      #|<borders>
      #|  <border diagonalUp="1" diagonalDown="1">
      #|    <left style="thin"><foo/></left>
      #|    <right style="thin"><color rgb="80112233"/></right>
      #|    <top style="thin"><color/></top>
      #|    <bottom style="thin"/>
      #|    <diagonal style="thin"/>
      #|    <vertical style="thin"/>
      #|    <horizontal style="thin"/>
      #|  </border>
      #|  <border><diagonal style="thin"/></border>
      #|</borders>
      #|,
    ),
  )
  inspect(parsed_borders.length(), content="2")
  inspect(parsed_borders[0].length(), content="8")
  inspect(parsed_borders[1].length(), content="1")
  inspect(has_border_type(parsed_borders[0], "diagonalUp"), content="true")
  inspect(has_border_type(parsed_borders[0], "diagonalDown"), content="true")
  inspect(has_border_type(parsed_borders[0], "vertical"), content="true")
  inspect(has_border_type(parsed_borders[0], "horizontal"), content="true")
  inspect(has_border_type(parsed_borders[1], "diagonal"), content="true")
  debug_inspect(
    border_color_by_type(parsed_borders[0], "right"),
    content="Some(\"80112233\")",
  )
}

///|
test "read wb: protection alignment and pivot parser guard branches" {
  inspect(
    parse_protection_entry("<xf><protection/></xf>") is None,
    content="true",
  )
  inspect(
    match parse_protection_entry("<xf><protection hidden=\"1\"/></xf>") {
      Some(value) => value.hidden == Some(true) && value.locked is None
      None => false
    },
    content="true",
  )

  inspect(
    parse_alignment_entry("<xf><alignment/></xf>") is None,
    content="true",
  )
  inspect(
    is_invalid_xml_alignment_error(
      Ok(parse_alignment_entry("<xf><alignment textRotation=\"bad\"/></xf>")) catch {
        e => Err(e)
      },
      "textRotation invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_alignment_error(
      Ok(parse_alignment_entry("<xf><alignment indent=\"bad\"/></xf>")) catch {
        e => Err(e)
      },
      "indent invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_alignment_error(
      Ok(parse_alignment_entry("<xf><alignment readingOrder=\"bad\"/></xf>")) catch {
        e => Err(e)
      },
      "readingOrder invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_alignment_error(
      Ok(parse_alignment_entry("<xf><alignment relativeIndent=\"bad\"/></xf>")) catch {
        e => Err(e)
      },
      "relativeIndent invalid",
    ),
    content="true",
  )
  inspect(
    match parse_alignment_entry("<xf><alignment horizontal=\"center\"/></xf>") {
      Some(value) => value.horizontal == Some("center")
      None => false
    },
    content="true",
  )

  inspect(
    parse_pivot_table_name("<pivotTableDefinition cacheId=\"1\"/>"),
    content="",
  )
  inspect(parse_pivot_table_name("<worksheet/>"), content="")
}

///|
test "read wb: defined names merge cells and classic validation guards" {
  let sheet_names : Array[String] = ["Sheet1"]

  let defined_names = parse_defined_names(
    (
      #|<definedNames>
      #|  <definedName name="WBName" comment="note">Sheet1!$A$1</definedName>
      #|  <definedName name="LocalName" localSheetId="0">Sheet1!$B$1</definedName>
      #|</definedNames>
      #|,
    ),
    sheet_names,
  )
  inspect(defined_names.length(), content="2")
  inspect(defined_names[0].name, content="WBName")
  inspect(defined_names[0].comment, content="note")
  inspect(defined_names[0].scope, content="Workbook")
  inspect(defined_names[1].scope, content="Sheet1")

  inspect(
    is_invalid_xml_defined_name_error(
      Ok(
        parse_defined_names(
          "<definedNames><definedName >Sheet1!$A$1</definedName></definedNames>",
          sheet_names,
        ),
      ) catch {
        e => Err(e)
      },
      "definedName name missing",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_defined_name_error(
      Ok(
        parse_defined_names(
          "<definedNames><definedName name=\"A\" localSheetId=\"bad\">Sheet1!$A$1</definedName></definedNames>",
          sheet_names,
        ),
      ) catch {
        e => Err(e)
      },
      "definedName localSheetId invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_defined_name_error(
      Ok(
        parse_defined_names(
          "<definedNames><definedName name=\"A\">Sheet1!$A$1</definedNames>", sheet_names,
        ),
      ) catch {
        e => Err(e)
      },
      "definedName close missing",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_defined_name_error(
      Ok(
        parse_defined_names(
          "<definedNames><definedName name=\"A\" localSheetId=\"5\">Sheet1!$A$1</definedName></definedNames>",
          sheet_names,
        ),
      ) catch {
        e => Err(e)
      },
      "definedName localSheetId missing",
    ),
    content="true",
  )

  let merged = parse_merge_cells(
    "<mergeCells><mergeCell ref=\"A1\"/></mergeCells>",
  )
  inspect(merged.length(), content="1")
  inspect(merged[0], content="A1:A1")
  inspect(
    is_invalid_xml_string_array_error(
      Ok(parse_merge_cells("<mergeCells><mergeCell /></mergeCells>")) catch {
        e => Err(e)
      },
      "mergeCell ref missing",
    ),
    content="true",
  )

  let validations = parse_data_validations(
    "<dataValidations><dataValidation type=\"whole\" sqref=\"A1\"/></dataValidations>",
  )
  inspect(validations.length(), content="1")
  inspect(validations[0].contains("sqref=\"A1\""), content="true")
  inspect(
    is_invalid_xml_string_array_error(
      Ok(
        parse_data_validations(
          "<dataValidations><dataValidation type=\"whole\"></dataValidations>",
        ),
      ) catch {
        e => Err(e)
      },
      "dataValidation tag not closed",
    ),
    content="true",
  )

  let cf_self_close = parse_conditional_formats(
    "<worksheet><conditionalFormatting sqref=\"A1\"/></worksheet>",
  )
  inspect(cf_self_close.length(), content="1")
  inspect(cf_self_close[0].contains("sqref=\"A1\""), content="true")
}

///|
test "read wb: x14 validation and icon-set helper guard branches" {
  let x14_validations_default = parse_data_validations_x14(
    (
      #|<worksheet>
      #|  <x14:dataValidation >
      #|    <xm:sqref>A1</xm:sqref>
      #|    <x14:formula1>PlainText</x14:formula1>
      #|    <x14:formula2><xm:f>7</xm:f></x14:formula2>
      #|  </x14:dataValidation>
      #|</worksheet>
      #|,
    ),
  )
  inspect(x14_validations_default.length(), content="1")
  inspect(
    x14_validations_default[0].contains("<dataValidation allowBlank=\"0\""),
    content="true",
  )
  inspect(
    x14_validations_default[0].contains("<formula1>PlainText</formula1>"),
    content="true",
  )
  inspect(
    x14_validations_default[0].contains("<formula2>7</formula2>"),
    content="true",
  )

  let x14_validations_no_formula = parse_data_validations_x14(
    (
      #|<worksheet>
      #|  <x14:dataValidation allowBlank="1" type="list">
      #|    <xm:sqref>B1</xm:sqref>
      #|  </x14:dataValidation>
      #|</worksheet>
      #|,
    ),
  )
  inspect(x14_validations_no_formula.length(), content="1")
  inspect(
    x14_validations_no_formula[0].contains("type=\"list\""),
    content="true",
  )
  inspect(!x14_validations_no_formula[0].contains("<formula1>"), content="true")

  inspect(
    is_invalid_xml_string_array_error(
      Ok(
        parse_data_validations_x14(
          "<worksheet><x14:dataValidation allowBlank=\"1\"></x14:dataValidation></worksheet>",
        ),
      ) catch {
        e => Err(e)
      },
      "x14:dataValidation sqref missing",
    ),
    content="true",
  )

  let opt_percent = ConditionalFormatOptions::new("icon_set")
  opt_percent.icon_style = "3Arrows"
  opt_percent.percent = true
  let icon_rule_with_cfvo = build_icon_set_rule_xml_from_x14(opt_percent, 3, [
    "<cfvo type=\"num\" val=\"1\"/>",
  ])
  inspect(icon_rule_with_cfvo.contains("percent=\"1\""), content="true")
  inspect(
    icon_rule_with_cfvo.contains("<cfvo type=\"num\" val=\"1\"/>"),
    content="true",
  )

  let opt_unknown = ConditionalFormatOptions::new("icon_set")
  opt_unknown.icon_style = "unknown-style"
  let empty_cfvos : Array[String] = []
  let icon_rule_unknown = build_icon_set_rule_xml_from_x14(
    opt_unknown, 1, empty_cfvos,
  )
  inspect(!icon_rule_unknown.contains("<cfvo"), content="true")

  let x14_cfvos = parse_x14_cfvo_values(
    (
      #|<worksheet>
      #|  <x14:cfvo type="num"><xm:f>5</xm:f></x14:cfvo>
      #|  <x14:cfvo type="num"><f>9</f></x14:cfvo>
      #|  <x14:cfvo type="percent"/>
      #|  <x14:cfvo><xm:f>1</xm:f></x14:cfvo>
      #|</worksheet>
      #|,
    ),
  )
  inspect(x14_cfvos.length(), content="3")
  inspect(x14_cfvos[0], content="<cfvo type=\"num\" val=\"5\"/>")
  inspect(x14_cfvos[1], content="<cfvo type=\"num\" val=\"9\"/>")
  inspect(x14_cfvos[2], content="<cfvo type=\"percent\"/>")

  inspect(color_text_from_rgb_x14("FF112233"), content="#112233")
  inspect(color_text_from_rgb_x14("00112233"), content="#00112233")

  debug_inspect(
    parse_sheet_dimension(
      "<worksheet><dimension ref=\"A1:B2\"></dimension></worksheet>",
    ),
    content="Some(\"A1:B2\")",
  )
  debug_inspect(
    parse_sheet_dimension("<worksheet><dimension/></worksheet>"),
    content="None",
  )
}

///|
test "read wb: sheet views and sheet props parser guard branches part 5" {
  let dimension_err = Ok(
    parse_sheet_dimension("<worksheet><dimension ref=\"A1\""),
  ) catch {
    e => Err(e)
  }
  inspect(
    match dimension_err {
      Err(InvalidXml(msg~)) => msg == "dimension tag not closed"
      _ => false
    },
    content="true",
  )

  let pane_not_closed = Ok(parse_sheet_view_pane("<pane ")) catch {
    e => Err(e)
  }
  inspect(
    match pane_not_closed {
      Err(InvalidXml(msg~)) => msg == "pane tag not closed"
      _ => false
    },
    content="true",
  )
  let pane_bad_xsplit = Ok(parse_sheet_view_pane("<pane xSplit=\"x\"/>")) catch {
    e => Err(e)
  }
  inspect(
    match pane_bad_xsplit {
      Err(InvalidXml(msg~)) => msg == "pane xSplit invalid"
      _ => false
    },
    content="true",
  )
  let pane_bad_ysplit = Ok(parse_sheet_view_pane("<pane ySplit=\"x\"/>")) catch {
    e => Err(e)
  }
  inspect(
    match pane_bad_ysplit {
      Err(InvalidXml(msg~)) => msg == "pane ySplit invalid"
      _ => false
    },
    content="true",
  )
  inspect(
    match parse_sheet_view_pane("<pane />") {
      Some(pane) =>
        pane.active_pane == "" &&
        pane.state == "" &&
        pane.top_left_cell == "" &&
        pane.x_split == 0.0 &&
        pane.y_split == 0.0
      None => false
    },
    content="true",
  )
  inspect(
    match
      parse_sheet_view_pane(
        "<pane activePane=\"bottomRight\" state=\"frozen\" topLeftCell=\"C3\" xSplit=\"1.5\" ySplit=\"2\"/>",
      ) {
      Some(pane) =>
        pane.active_pane == "bottomRight" &&
        pane.state == "frozen" &&
        pane.top_left_cell == "C3" &&
        pane.x_split == 1.5 &&
        pane.y_split == 2.0
      None => false
    },
    content="true",
  )

  let selection_not_closed = Ok(parse_sheet_view_selections("<selection ")) catch {
    e => Err(e)
  }
  inspect(
    match selection_not_closed {
      Err(InvalidXml(msg~)) => msg == "selection tag not closed"
      _ => false
    },
    content="true",
  )
  let selection_defaults = parse_sheet_view_selections("<selection />")
  inspect(selection_defaults.length(), content="1")
  inspect(
    selection_defaults[0].sqref == "" &&
    selection_defaults[0].active_cell == "" &&
    selection_defaults[0].pane == "",
    content="true",
  )
  let selections = parse_sheet_view_selections(
    "<selection sqref=\"B2\" activeCell=\"B2\" pane=\"topRight\"/>",
  )
  inspect(selections.length(), content="1")
  inspect(
    selections[0].sqref == "B2" &&
    selections[0].active_cell == "B2" &&
    selections[0].pane == "topRight",
    content="true",
  )

  let sheet_view_bad_zoom = Ok(
    parse_sheet_views("<sheetViews><sheetView zoomScale=\"x\"/></sheetViews>"),
  ) catch {
    e => Err(e)
  }
  inspect(
    match sheet_view_bad_zoom {
      Err(InvalidXml(msg~)) => msg == "sheetView zoomScale invalid"
      _ => false
    },
    content="true",
  )
  let sheet_view_bad_id = Ok(
    parse_sheet_views(
      "<sheetViews><sheetView workbookViewId=\"x\"/></sheetViews>",
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    match sheet_view_bad_id {
      Err(InvalidXml(msg~)) => msg == "sheetView workbookViewId invalid"
      _ => false
    },
    content="true",
  )
  let sheet_view_missing_close = Ok(
    parse_sheet_views(
      "<sheetViews><sheetView workbookViewId=\"0\"></sheetViews>",
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    match sheet_view_missing_close {
      Err(InvalidXml(msg~)) => msg == "sheetView close missing"
      _ => false
    },
    content="true",
  )

  let parsed_views = parse_sheet_views(
    (
      #|<sheetViews>
      #|  <sheetView workbookViewId="2" showRuler="1" view="pageLayout">
      #|    <pane activePane="topRight" state="frozen" topLeftCell="B2" xSplit="1" ySplit="0"/>
      #|    <selection sqref="B2" activeCell="B2" pane="topRight"/>
      #|  </sheetView>
      #|</sheetViews>
      #|,
    ),
  )
  inspect(parsed_views.length(), content="1")
  inspect(
    match parsed_views[0].show_ruler {
      Some(v) => v == true
      None => false
    },
    content="true",
  )
  inspect(
    match parsed_views[0].view {
      Some(v) => v == "pageLayout"
      None => false
    },
    content="true",
  )
  inspect(parsed_views[0].workbook_view_id, content="2")
  inspect(parsed_views[0].pane is Some(_), content="true")
  inspect(parsed_views[0].selection.length(), content="1")

  let parsed_views_default_id = parse_sheet_views(
    "<sheetViews><sheetView showRuler=\"1\"/></sheetViews>",
  )
  inspect(parsed_views_default_id.length(), content="1")
  inspect(parsed_views_default_id[0].workbook_view_id, content="0")

  let props_from_tab_color = parse_sheet_props(
    "<worksheet><tabColor indexed=\"3\" rgb=\"FF112233\" theme=\"4\" tint=\"0.5\"/></worksheet>",
  )
  inspect(props_from_tab_color is Some(_), content="true")
  inspect(
    match props_from_tab_color {
      Some(opts) =>
        opts.tab_color_indexed == Some(3) &&
        opts.tab_color_rgb == Some("FF112233") &&
        opts.tab_color_theme == Some(4) &&
        opts.tab_color_tint == Some(0.5)
      None => false
    },
    content="true",
  )
  let tab_color_bad_indexed = Ok(
    parse_sheet_props("<worksheet><tabColor indexed=\"x\"/></worksheet>"),
  ) catch {
    e => Err(e)
  }
  inspect(
    match tab_color_bad_indexed {
      Err(InvalidXml(msg~)) => msg == "tabColor indexed invalid"
      _ => false
    },
    content="true",
  )
  inspect(
    match
      parse_sheet_props("<worksheet><sheetPr published=\"1\"/></worksheet>") {
      Some(opts) => opts.code_name is None && opts.published == Some(true)
      None => false
    },
    content="true",
  )
}

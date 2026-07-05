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
fn xml_encoding(bytes : Bytes) -> String? {
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
  bytes : Bytes,
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
        Some(value) => return value(encoding, bytes)
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
            @string.parse_double(value) catch {
              _ => raise InvalidXml(msg="font sz invalid")
            },
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
          try @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="font color tint invalid")
          } noraise {
            val => font.color_tint = Some(val)
          }
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
    if rgb.length() == 8 {
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
          try @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="gradientFill bottom invalid")
          } noraise {
            v => v
          }
        None => 0.0
      }
      let degree = match attr_value(tag, "degree") {
        Some(value) =>
          try @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="gradientFill degree invalid")
          } noraise {
            v => v
          }
        None => 0.0
      }
      let left = match attr_value(tag, "left") {
        Some(value) =>
          try @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="gradientFill left invalid")
          } noraise {
            v => v
          }
        None => 0.0
      }
      let right = match attr_value(tag, "right") {
        Some(value) =>
          try @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="gradientFill right invalid")
          } noraise {
            v => v
          }
        None => 0.0
      }
      let top = match attr_value(tag, "top") {
        Some(value) =>
          try @string.parse_double(value) catch {
            _ => raise InvalidXml(msg="gradientFill top invalid")
          } noraise {
            v => v
          }
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
                try @string.parse_double(value) catch {
                  _ =>
                    raise InvalidXml(msg="gradientFill stop position invalid")
                } noraise {
                  v => stop_positions.push(v)
                }
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
              try @string.parse_double(value) catch {
                _ => raise InvalidXml(msg="fill fgColor tint invalid")
              } noraise {
                val => fill.fg_tint = Some(val)
              }
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
              try @string.parse_double(value) catch {
                _ => raise InvalidXml(msg="fill bgColor tint invalid")
              } noraise {
                val => fill.bg_tint = Some(val)
              }
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
fn parse_data_validations(xml : StringView) -> Array[String] raise XlsxError {
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
    match text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = text[:end]
        validations.push("<dataValidation \{slice.to_owned()}")
      }
      None => {
        let end = match text.find("/>") {
          Some(pos) => pos + 2
          None => raise InvalidXml(msg="dataValidation tag not closed")
        }
        let slice = text[:end]
        validations.push("<dataValidation \{slice.to_owned()}")
      }
    }
  }
  validations
}

///|
fn parse_data_validations_x14(
  xml : StringView,
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
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="x14:dataValidation sqref missing")
    }
    let mut formula1 = ""
    match extract_tag_body_from(full, "x14:formula1") {
      Some(value) => {
        let body = value.to_string()
        match extract_tag_body_from(body[:], "xm:f") {
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
        match extract_tag_body_from(body[:], "xm:f") {
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
fn parse_conditional_formats(xml : StringView) -> Array[String] raise XlsxError {
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
    match text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = text[:end]
        formats.push("<conditionalFormatting\{slice.to_owned()}")
      }
      None => {
        let end = match text.find("/>") {
          Some(pos) => pos + 2
          None => raise InvalidXml(msg="conditionalFormatting tag not closed")
        }
        let slice = text[:end]
        formats.push("<conditionalFormatting\{slice.to_owned()}")
      }
    }
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
) -> Map[String, X14DataBarProps] raise XlsxError {
  let bars : Map[String, X14DataBarProps] = {}
  let blocks = parse_x14_conditional_formatting_blocks(xml)
  if blocks.length() == 0 {
    return bars
  }
  for full in blocks {
    let sqref = match extract_tag_body_from(full, "xm:sqref") {
      Some(value) => unescape_xml_text(value)
      None =>
        match extract_tag_body_from(full, "sqref") {
          Some(value) => unescape_xml_text(value)
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
) -> Array[String] raise XlsxError {
  let formats : Array[String] = []
  let blocks = parse_x14_conditional_formatting_blocks(xml)
  if blocks.length() == 0 {
    return formats
  }
  for full in blocks {
    let sqref = match extract_tag_body_from(full, "xm:sqref") {
      Some(value) => unescape_xml_text(value)
      None =>
        match extract_tag_body_from(full, "sqref") {
          Some(value) => unescape_xml_text(value)
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
        Some(value) => Some(unescape_xml_text(value))
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
      Some(value) => pane.top_left_cell = unescape_xml_text(value)
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
      Some(value) => selection.sqref = unescape_xml_text(value)
      None => ()
    }
    match attr_value(tag, "activeCell") {
      Some(value) => selection.active_cell = unescape_xml_text(value)
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
fn parse_sheet_views(xml : StringView) -> Array[SheetView] raise XlsxError {
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
      Some(value) => view.top_left_cell = Some(unescape_xml_text(value))
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
        let selections = parse_sheet_view_selections(inner)
        view.selection.clear()
        view.selection.append(selections[:])
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
  let (_min_row, min_col, _max_row, _max_col) = parse_range_ref(range_ref)
  let self_closing = tag.trim().has_suffix("/")
  let columns = if self_closing {
    []
  } else {
    match extract_tag_body(xml, "autoFilter") {
      Some(body) => parse_auto_filter_columns(body, min_col)
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
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="hyperlink tag not closed")
    }
    let tag = text[:end]
    let raw_ref = match attr_value(tag, "ref") {
      Some(value) => value
      None => raise InvalidXml(msg="hyperlink ref missing")
    }
    let reference = try normalize_cell_or_range_ref(raw_ref) catch {
      _ => raw_ref.to_string()
    } noraise {
      value => value
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
    let rel = match tail.find(marker[:]) {
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
  let dims : Map[Int, RowDimension] = {}
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
    if row <= 0 {
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
  let dims : Map[Int, ColDimension] = {}
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
    if min_col <= 0 || max_col <= 0 || max_col < min_col {
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
fn enforce_unzip_limits(
  archive : @zip.Archive,
  options : Options,
) -> Unit raise XlsxError {
  let mut total_size = 0
  for entry in archive.entries() {
    let size = entry.data().length()
    total_size = total_size + size
    if options.unzip_size_limit > 0 && total_size > options.unzip_size_limit {
      raise InvalidOptions(msg="unzip size limit exceeded")
    }
    if options.unzip_xml_size_limit > 0 {
      let name = entry.name().to_lower()
      if name.has_suffix(".xml") && size > options.unzip_xml_size_limit {
        raise InvalidOptions(msg="unzip xml size limit exceeded")
      }
    }
  }
}

///|
fn first_existing_rel_target_path(
  targets : Map[String, String],
  base_folder : StringView,
  archive : @zip.Archive,
) -> String? raise XlsxError {
  for _, target in targets {
    let path = resolve_rel_target(target, base_folder)
    if archive.get(path) is Some(_) {
      return Some(path)
    }
  }
  None
}

///|
fn first_existing_workbook_rel_target_path(
  targets : Map[String, String],
  archive : @zip.Archive,
) -> String? raise XlsxError {
  for _, target in targets {
    let path = resolve_workbook_rel_target(target)
    if archive.get(path) is Some(_) {
      return Some(path)
    }
  }
  None
}

///|
fn read_zip_bytes(
  bytes : BytesView,
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let resolved_options = normalize_unzip_limits(options)
  let archive = @zip.read(bytes) catch {
    err => raise UnsupportedFeature(msg=repr(err))
  }
  enforce_unzip_limits(archive, resolved_options)
  let decode = (value : Bytes) => decode_utf8(value, transcoder)
  let workbook_xml_part_path = resolve_workbook_xml_part_path(archive, decode)
  let workbook_bytes = match archive.get(workbook_xml_part_path) {
    Some(value) => value
    None => raise MissingPart(path=workbook_xml_part_path)
  }
  let workbook_xml = decode(workbook_bytes)
  let sheets = parse_workbook_sheets(workbook_xml)
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
  let shared_strings = match archive.get("xl/sharedStrings.xml") {
    Some(value) => parse_shared_strings(decode(value))
    None => []
  }
  let (
    styles,
    conditional_styles,
    default_font,
    default_table_style,
    default_pivot_style,
    indexed_colors,
    mru_colors_xml,
    styles_ext_lst_xml,
  ) = match archive.get("xl/styles.xml") {
    Some(value) => {
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
  let theme_xml = match archive.get("xl/theme/theme1.xml") {
    Some(value) => Some(decode(value))
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
  let rich_value_media : Map[String, Bytes] = {}
  match rich_value_images {
    Some(data) => {
      for _, target in data.rel_targets {
        let path = normalize_cell_image_target(target)
        match archive.get(path) {
          Some(bytes) => rich_value_media[path] = bytes
          None => ()
        }
      }
      for _, target in data.web_rel_targets {
        let path = normalize_cell_image_target(target)
        match archive.get(path) {
          Some(bytes) => rich_value_media[path] = bytes
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
    options: resolved_options,
    workbook_protection,
    active_sheet_index: safe_active_index,
    cell_images,
    rich_value_images,
    rich_value_media,
  }
  let workbook_rels_path = rels_path_for_part(workbook_xml_part_path)
  let workbook_rels = match archive.get(workbook_rels_path) {
    Some(value) => decode(value)
    None => raise MissingPart(path=workbook_rels_path)
  }
  let slicer_cache_defs = parse_slicer_cache_definitions(
    workbook_rels, archive, decode,
  )
  let vba_targets = parse_relationship_targets(workbook_rels, rel_vba_project)
  let vba_path = match
    first_existing_workbook_rel_target_path(vba_targets, archive) {
    Some(path) => Some(path)
    None =>
      match first_relationship_target(vba_targets) {
        Some(target) => Some(resolve_workbook_rel_target(target))
        None => None
      }
  }
  match vba_path {
    Some(path) => {
      let vba_bytes = match archive.get(path) {
        Some(value) => value
        None => raise MissingPart(path~)
      }
      workbook.vba_project = Some(vba_bytes)
    }
    None => ()
  }
  let worksheet_targets = parse_relationship_targets(
    workbook_rels, rel_worksheet,
  )
  let chartsheet_targets = parse_relationship_targets(
    workbook_rels, rel_chartsheet,
  )
  for entry in sheets {
    let name = entry.name
    let state = entry.state
    let rel_id = entry.rel_id
    let is_worksheet = worksheet_targets.contains(rel_id)
    let is_chartsheet = chartsheet_targets.contains(rel_id)
    if !is_worksheet && !is_chartsheet {
      raise InvalidXml(msg="sheet relationship missing")
    }
    if is_worksheet {
      let target = match worksheet_targets.get(rel_id) {
        Some(value) => value
        None => raise InvalidXml(msg="worksheet target missing")
      }
      let sheet_path = resolve_workbook_rel_target(target)
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
      ) = parse_worksheet(sheet_xml, shared_strings, style_count)
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
      let data_validations = parse_data_validations(sheet_xml)
      for dv in parse_data_validations_x14(sheet_xml) {
        data_validations.push(dv)
      }
      let conditional_formats = parse_conditional_formats(sheet_xml)
      for cf in parse_conditional_formats_x14(sheet_xml) {
        conditional_formats.push(cf)
      }
      let x14_data_bars = parse_x14_data_bars(sheet_xml)
      let unknown_ext_blocks = parse_unknown_worksheet_ext_blocks(sheet_xml)
      let ignored_errors = parse_ignored_errors(sheet_xml)
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
      let rels_path = rels_path_for(sheet_path, "worksheets")
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
        let seen_paths : Map[String, Bool] = {}
        for rel_id in slicer_rel_ids {
          let target = match rel_targets.get(rel_id) {
            Some(value) => value
            None => raise InvalidXml(msg="slicer relationship missing")
          }
          let slicer_path = resolve_rel_target(target, "worksheets")
          if seen_paths.contains(slicer_path) {
            continue
          }
          seen_paths[slicer_path] = true
          let slicer_bytes = match archive.get(slicer_path) {
            Some(value) => value
            None => raise MissingPart(path=slicer_path)
          }
          let slicer_xml = decode(slicer_bytes)
          parsed.append(parse_slicer_part_entries(slicer_xml)[:])
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
          let image_path = resolve_rel_target(target, "worksheets")
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
          Some({ data: image_bytes, extension, content_type })
        }
        None => None
      }
      let hyperlinks = if hyperlink_elements.length() == 0 {
        []
      } else {
        let rel_targets = if needs_hyperlink_rels {
          parse_relationship_targets(rels_xml, rel_hyperlink)
        } else {
          {}
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
          let table_path = resolve_rel_target(target, "worksheets")
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
          {}
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
            let pivot_path = resolve_rel_target(target, "worksheets")
            let pivot_bytes = match archive.get(pivot_path) {
              Some(value) => value
              None => raise MissingPart(path=pivot_path)
            }
            let pivot_xml = decode(pivot_bytes)
            let pivot_rels_path = rels_path_for(pivot_path, "pivotTables")
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
                cache_targets, "pivotTables", archive,
              ) {
              Some(path) => path
              None => {
                let cache_target = match
                  first_relationship_target(cache_targets) {
                  Some(value) => value
                  None =>
                    raise InvalidXml(msg="pivot cache relationship missing")
                }
                resolve_rel_target(cache_target, "pivotTables")
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
              archive.get(rels_path_for(cache_path, "pivotCache")) {
              Some(value) => {
                let cache_rels_xml = decode(value)
                let record_targets = parse_relationship_targets(
                  cache_rels_xml, rel_pivot_cache_records,
                )
                let record_path = match
                  first_existing_rel_target_path(
                    record_targets, "pivotCache", archive,
                  ) {
                  Some(path) => Some(path)
                  None =>
                    match first_relationship_target(record_targets) {
                      Some(record_target) =>
                        Some(resolve_rel_target(record_target, "pivotCache"))
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
        {}
      }
      let vml_drawing_xml = match legacy_drawing_rel_id {
        Some(rel_id) => {
          let target = match vml_targets.get(rel_id) {
            Some(value) => value
            None => raise InvalidXml(msg="vml drawing relationship missing")
          }
          let vml_path = resolve_rel_target(target, "worksheets")
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
          let vml_path = resolve_rel_target(target, "worksheets")
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
      let header_footer_images = match vml_drawing_hf_xml {
        Some(xml) => {
          let vml_rels_xml = match vml_drawing_hf_path {
            Some(path) =>
              match archive.get(rels_path_for(path, "drawings")) {
                Some(value) => Some(decode(value))
                None => None
              }
            None => None
          }
          parse_header_footer_images_from_vml(xml, vml_rels_xml, archive)
        }
        None => []
      }
      let comments = if rels_xml == "" {
        []
      } else {
        let comment_targets = parse_relationship_targets(rels_xml, rel_comments)
        let parsed_comments : Array[Comment] = []
        for _rel_id, target in comment_targets {
          let comment_path = resolve_rel_target(target, "worksheets")
          let comment_bytes = match archive.get(comment_path) {
            Some(value) => value
            None => raise MissingPart(path=comment_path)
          }
          let comment_xml = decode(comment_bytes)
          let entries = parse_comments_xml(comment_xml)
          parsed_comments.append(entries[:])
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
        cell_index: {},
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
          {}
        },
      }
      let mut slicer_anchor_info : Map[String, SlicerAnchorInfo] = {}
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
          let drawing_path = resolve_rel_target(drawing_target, "worksheets")
          let drawing_bytes = match archive.get(drawing_path) {
            Some(value) => value
            None => raise MissingPart(path=drawing_path)
          }
          let drawing_xml = decode(drawing_bytes)
          if slicer_part_entries.length() > 0 {
            slicer_anchor_info = parse_drawing_slicer_anchors(
              drawing_xml, sheet,
            )
          }
          let drawing_rels_xml = match
            archive.get(rels_path_for(drawing_path, "drawings")) {
            Some(value) => decode(value)
            None => ""
          }
          let drawing_images = parse_drawing_images(
            drawing_xml, drawing_rels_xml, sheet, archive,
          )
          sheet.images.append(drawing_images[:])
          let drawing_charts = parse_drawing_charts(
            drawing_xml, drawing_rels_xml, sheet, archive,
          )
          sheet.charts.append(drawing_charts[:])
          let drawing_shapes = parse_drawing_shapes(drawing_xml)
          sheet.shapes.append(drawing_shapes[:])
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
      let target = match chartsheet_targets.get(rel_id) {
        Some(value) => value
        None => raise InvalidXml(msg="chartsheet target missing")
      }
      let chartsheet_path = resolve_workbook_rel_target(target)
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
      let chartsheet_rels_path = rels_path_for(chartsheet_path, "chartsheets")
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
      let drawing_path = resolve_rel_target(drawing_target, "chartsheets")
      let drawing_rels_path = rels_path_for(drawing_path, "drawings")
      let drawing_rels_bytes = match archive.get(drawing_rels_path) {
        Some(value) => value
        None => raise MissingPart(path=drawing_rels_path)
      }
      let drawing_rels_xml = decode(drawing_rels_bytes)
      let chart_targets = parse_relationship_targets(
        drawing_rels_xml, rel_chart,
      )
      let chart_path = match
        first_existing_rel_target_path(chart_targets, "drawings", archive) {
        Some(path) => path
        None => {
          let chart_target = match first_relationship_target(chart_targets) {
            Some(value) => value
            None => raise InvalidXml(msg="chart target missing")
          }
          resolve_rel_target(chart_target, "drawings")
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
pub fn read(
  bytes : BytesView,
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  if options.password != "" {
    match transcoder {
      Some(value) =>
        return read_with_password(
          bytes,
          options.password,
          options~,
          transcoder=value,
        )
      None => return read_with_password(bytes, options.password, options~)
    }
  }
  if is_encrypted_package(bytes) {
    raise EncryptedPackage
  }
  match transcoder {
    Some(value) => read_zip_bytes(bytes, options~, transcoder=value)
    None => read_zip_bytes(bytes, options~)
  }
}

///|
pub fn read_with_password(
  bytes : BytesView,
  password : String,
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let resolved_options = options_with_password(options, password)
  if is_encrypted_package(bytes) {
    let decrypted = decrypt_encrypted_package(bytes, password)
    let result : Result[Workbook, Error] = Ok(
      match transcoder {
        Some(value) =>
          read_zip_bytes(decrypted, options=resolved_options, transcoder=value)
        None => read_zip_bytes(decrypted, options=resolved_options)
      },
    ) catch {
      e => Err(e)
    }
    match result {
      Ok(workbook) => workbook
      Err(_) => raise InvalidPassword
    }
  } else {
    match transcoder {
      Some(value) =>
        read_zip_bytes(bytes, options=resolved_options, transcoder=value)
      None => read_zip_bytes(bytes, options=resolved_options)
    }
  }
}

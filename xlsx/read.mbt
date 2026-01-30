///|
fn is_utf8_encoding(value : StringView) -> Bool {
  let normalized = value.to_string().to_lower()
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
  match xml_encoding(bytes) {
    Some(encoding) =>
      if !is_utf8_encoding(encoding) {
        match transcoder {
          Some(value) => return value(encoding, bytes)
          None =>
            raise XlsxError::InvalidXml(
              msg="xml encoding \{encoding} requires charset transcoder",
            )
        }
      }
    None => ()
  }
  @encoding/utf8.decode(bytes) catch {
    _ => raise XlsxError::InvalidXml(msg="invalid utf8")
  }
}

///|
priv struct WorkbookSheetInfo {
  name : String
  state : SheetState
  rel_id : String
}

///|
fn parse_workbook_sheets(
  xml : StringView,
) -> Array[WorkbookSheetInfo] raise XlsxError {
  let sheets : Array[WorkbookSheetInfo] = []
  let mut first = true
  for chunk in xml.to_string().split("<sheet ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="sheet tag not closed")
    }
    let tag = try! text[:end]
    let name = match attr_value(tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => raise XlsxError::InvalidXml(msg="sheet name missing")
    }
    let rel_id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="sheet relationship missing")
    }
    let state = match attr_value(tag, "state") {
      Some(value) =>
        match value.to_lower() {
          "hidden" => SheetState::Hidden
          "veryhidden" => SheetState::VeryHidden
          _ => SheetState::Visible
        }
      None => SheetState::Visible
    }
    sheets.push({ name, state, rel_id })
  }
  sheets
}

///|
fn parse_active_sheet_index(xml : StringView) -> Int? raise XlsxError {
  let xml_str = xml.to_string()
  let marker = "<workbookView"
  match xml_str.find(marker) {
    None => None
    Some(start) => {
      let rest = xml_str[start + marker.length():] catch {
          _ => raise XlsxError::InvalidXml(msg="workbookView slice invalid")
        }
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise XlsxError::InvalidXml(msg="workbookView tag not closed")
      }
      let tag = rest[:end] catch {
          _ => raise XlsxError::InvalidXml(msg="workbookView tag invalid")
        }
      match attr_value(tag, "activeTab") {
        Some(value) =>
          Some(
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="activeTab invalid")
            },
          )
        None => None
      }
    }
  }
}

///|
fn parse_workbook_props(
  xml : StringView,
) -> WorkbookPropsOptions raise XlsxError {
  let xml_str = xml.to_string()
  let marker = "<workbookPr"
  match xml_str.find(marker) {
    None => WorkbookPropsOptions::new()
    Some(start) => {
      let rest = xml_str[start + marker.length():] catch {
          _ => raise XlsxError::InvalidXml(msg="workbookPr slice invalid")
        }
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise XlsxError::InvalidXml(msg="workbookPr tag not closed")
      }
      let tag = rest[:end] catch {
          _ => raise XlsxError::InvalidXml(msg="workbookPr tag invalid")
        }
      let props = WorkbookPropsOptions::new()
      match attr_value(tag, "date1904") {
        Some(value) => props.date_1904 = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "filterPrivacy") {
        Some(value) => props.filter_privacy = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "codeName") {
        Some(value) => props.code_name = Some(unescape_xml_text(value))
        None => ()
      }
      props
    }
  }
}

///|
fn parse_calc_props(xml : StringView) -> CalcPropsOptions raise XlsxError {
  let xml_str = xml.to_string()
  let marker = "<calcPr"
  match xml_str.find(marker) {
    None => CalcPropsOptions::new()
    Some(start) => {
      let rest = xml_str[start + marker.length():] catch {
          _ => raise XlsxError::InvalidXml(msg="calcPr slice invalid")
        }
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise XlsxError::InvalidXml(msg="calcPr tag not closed")
      }
      let tag = rest[:end] catch {
          _ => raise XlsxError::InvalidXml(msg="calcPr tag invalid")
        }
      let props = CalcPropsOptions::new()
      match attr_value(tag, "calcId") {
        Some(value) =>
          props.calc_id = Some(
            @strconv.parse_uint(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="calcId invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "calcMode") {
        Some(value) =>
          match normalize_calc_mode(value) {
            Some(mode) => props.calc_mode = Some(mode)
            None => raise XlsxError::InvalidXml(msg="calcMode invalid")
          }
        None => ()
      }
      match attr_value(tag, "fullCalcOnLoad") {
        Some(value) => props.full_calc_on_load = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "refMode") {
        Some(value) =>
          match normalize_ref_mode(value) {
            Some(mode) => props.ref_mode = Some(mode)
            None => raise XlsxError::InvalidXml(msg="refMode invalid")
          }
        None => ()
      }
      match attr_value(tag, "iterate") {
        Some(value) => props.iterate = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "iterateCount") {
        Some(value) =>
          props.iterate_count = Some(
            @strconv.parse_uint(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="iterateCount invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "iterateDelta") {
        Some(value) =>
          props.iterate_delta = Some(
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="iterateDelta invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "fullPrecision") {
        Some(value) => props.full_precision = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "calcCompleted") {
        Some(value) => props.calc_completed = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "calcOnSave") {
        Some(value) => props.calc_on_save = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "concurrentCalc") {
        Some(value) => props.concurrent_calc = Some(parse_cell_bool(value))
        None => ()
      }
      match attr_value(tag, "concurrentManualCount") {
        Some(value) =>
          props.concurrent_manual_count = Some(
            @strconv.parse_uint(value, base=10) catch {
              _ =>
                raise XlsxError::InvalidXml(msg="concurrentManualCount invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "forceFullCalc") {
        Some(value) => props.force_full_calc = Some(parse_cell_bool(value))
        None => ()
      }
      props
    }
  }
}

///|
fn parse_workbook_protection(
  xml : StringView,
) -> WorkbookProtection? raise XlsxError {
  let xml_str = xml.to_string()
  let marker = "<workbookProtection"
  match xml_str.find(marker) {
    None => None
    Some(start) => {
      let rest = xml_str[start + marker.length():] catch {
          _ =>
            raise XlsxError::InvalidXml(msg="workbookProtection slice invalid")
        }
      let end = match rest.find(">") {
        Some(pos) => pos
        None =>
          raise XlsxError::InvalidXml(msg="workbookProtection tag not closed")
      }
      let tag = rest[:end] catch {
          _ => raise XlsxError::InvalidXml(msg="workbookProtection tag invalid")
        }
      let protection : WorkbookProtection = {
        lock_structure: false,
        lock_windows: false,
        algorithm_name: "",
        hash_value: "",
        salt_value: "",
        spin_count: 0,
      }
      match attr_value(tag, "lockStructure") {
        Some(value) => protection.lock_structure = parse_cell_bool(value)
        None => ()
      }
      match attr_value(tag, "lockWindows") {
        Some(value) => protection.lock_windows = parse_cell_bool(value)
        None => ()
      }
      match attr_value(tag, "workbookAlgorithmName") {
        Some(value) => protection.algorithm_name = value.to_string()
        None => ()
      }
      match attr_value(tag, "workbookHashValue") {
        Some(value) => protection.hash_value = value.to_string()
        None => ()
      }
      match attr_value(tag, "workbookSaltValue") {
        Some(value) => protection.salt_value = value.to_string()
        None => ()
      }
      match attr_value(tag, "workbookSpinCount") {
        Some(value) =>
          protection.spin_count = @strconv.parse_int(value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="workbookSpinCount invalid")
          }
        None => ()
      }
      Some(protection)
    }
  }
}

///|
fn parse_default_font(xml : StringView) -> String {
  let xml_str = xml.to_string()
  let marker = "<fonts"
  match xml_str.find(marker) {
    None => "Calibri"
    Some(start) => {
      let rest = xml_str[start + marker.length():] catch { _ => "" }
      match rest.find("<name") {
        None => "Calibri"
        Some(name_start) => {
          let name_rest = rest[name_start + 5:] catch { _ => "" }
          match name_rest.find(">") {
            None => "Calibri"
            Some(end) => {
              let tag = name_rest[:end] catch { _ => "" }
              let value_result : Result[String?, Error] = try? attr_value(
                tag, "val",
              )
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
        Some(value) => if parse_bool_attr(value) { font.extend = Some(true) }
        None => font.extend = Some(true)
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
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="font sz invalid")
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
          try @strconv.parse_int(value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="font charset invalid")
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
          try @strconv.parse_int(value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="font family invalid")
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
          let normalized = if rgb.length() == 8 && rgb.has_prefix("FF") {
            (rgb[2:] catch { _ => rgb }).to_string()
          } else {
            rgb.to_string()
          }
          font.color = Some(normalized)
        }
        None => ()
      }
      match attr_value(tag, "theme") {
        Some(value) =>
          try @strconv.parse_int(value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="font color theme invalid")
          } noraise {
            val => font.color_theme = Some(val)
          }
        None => ()
      }
      match attr_value(tag, "indexed") {
        Some(value) =>
          try @strconv.parse_int(value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="font color indexed invalid")
          } noraise {
            val => font.color_indexed = Some(val)
          }
        None => ()
      }
      match attr_value(tag, "tint") {
        Some(value) =>
          try @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="font color tint invalid")
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
    let text = chunk.to_string()
    let open_end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let rest = text[open_end + 1:] catch { _ => "" }
    let end = match rest.find("</font>") {
      Some(pos) => pos
      None => continue
    }
    let content = rest[:end] catch { _ => "" }
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
      let color = (rgb[2:] catch { _ => rgb }).to_string()
      (color, transparency)
    } else {
      (rgb.to_string(), None)
    }
  }

  match tag_attributes_in(xml, "gradientFill") {
    Some(tag) => {
      fill.typ = Some("gradient")
      let bottom = match attr_value(tag, "bottom") {
        Some(value) =>
          try @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="gradientFill bottom invalid")
          } noraise {
            v => v
          }
        None => 0.0
      }
      let degree = match attr_value(tag, "degree") {
        Some(value) =>
          try @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="gradientFill degree invalid")
          } noraise {
            v => v
          }
        None => 0.0
      }
      let left = match attr_value(tag, "left") {
        Some(value) =>
          try @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="gradientFill left invalid")
          } noraise {
            v => v
          }
        None => 0.0
      }
      let right = match attr_value(tag, "right") {
        Some(value) =>
          try @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="gradientFill right invalid")
          } noraise {
            v => v
          }
        None => 0.0
      }
      let top = match attr_value(tag, "top") {
        Some(value) =>
          try @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="gradientFill top invalid")
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
          for chunk in body.to_string().split("<stop") {
            if first {
              first = false
              continue
            }
            let text = chunk.to_string()
            let open_end = match text.find(">") {
              Some(pos) => pos
              None => continue
            }
            let open_tag = text[:open_end] catch { _ => "" }
            match attr_value(open_tag, "position") {
              Some(value) =>
                try @strconv.parse_double(value) catch {
                  _ =>
                    raise XlsxError::InvalidXml(
                      msg="gradientFill stop position invalid",
                    )
                } noraise {
                  v => stop_positions.push(v)
                }
              None => stop_positions.push(0.0)
            }
            let rest = text[open_end + 1:] catch { _ => "" }
            let end = match rest.find("</stop>") {
              Some(pos) => pos
              None => continue
            }
            let content = rest[:end] catch { _ => "" }
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
              try @strconv.parse_int(value, base=10) catch {
                _ =>
                  raise XlsxError::InvalidXml(msg="fill fgColor theme invalid")
              } noraise {
                val => fill.fg_theme = Some(val)
              }
            None => ()
          }
          match attr_value(color_tag, "indexed") {
            Some(value) =>
              try @strconv.parse_int(value, base=10) catch {
                _ =>
                  raise XlsxError::InvalidXml(
                    msg="fill fgColor indexed invalid",
                  )
              } noraise {
                val => fill.fg_indexed = Some(val)
              }
            None => ()
          }
          match attr_value(color_tag, "tint") {
            Some(value) =>
              try @strconv.parse_double(value) catch {
                _ =>
                  raise XlsxError::InvalidXml(msg="fill fgColor tint invalid")
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
              try @strconv.parse_int(value, base=10) catch {
                _ =>
                  raise XlsxError::InvalidXml(msg="fill bgColor theme invalid")
              } noraise {
                val => fill.bg_theme = Some(val)
              }
            None => ()
          }
          match attr_value(color_tag, "indexed") {
            Some(value) =>
              try @strconv.parse_int(value, base=10) catch {
                _ =>
                  raise XlsxError::InvalidXml(
                    msg="fill bgColor indexed invalid",
                  )
              } noraise {
                val => fill.bg_indexed = Some(val)
              }
            None => ()
          }
          match attr_value(color_tag, "tint") {
            Some(value) =>
              try @strconv.parse_double(value) catch {
                _ =>
                  raise XlsxError::InvalidXml(msg="fill bgColor tint invalid")
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
    let text = chunk.to_string()
    let open_end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let open_tag = text[:open_end] catch { _ => "" }
    if open_tag.has_suffix("/") {
      fills.push(Fill::new())
      continue
    }
    let rest = text[open_end + 1:] catch { _ => "" }
    let end = match rest.find("</fill>") {
      Some(pos) => pos
      None => continue
    }
    let content = rest[:end] catch { _ => "" }
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
      Some(rgb) => {
        let normalized = if rgb.length() == 8 && rgb.has_prefix("FF") {
          (rgb[2:] catch { _ => rgb }).to_string()
        } else {
          rgb.to_string()
        }
        Some(Border::with_values(side.to_string(), color=normalized, style~))
      }
      None =>
        if style > 0 {
          Some(Border::with_values(side.to_string(), style~))
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
    let text = chunk.to_string()
    let open_end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let open_tag = text[:open_end] catch { _ => "" }
    if open_tag.has_suffix("/") {
      borders.push([])
      continue
    }
    let rest = text[open_end + 1:] catch { _ => "" }
    let end = match rest.find("</border>") {
      Some(pos) => pos
      None => continue
    }
    let content = rest[:end] catch { _ => "" }
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
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="textRotation invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "indent") {
    Some(value) =>
      alignment.indent = Some(
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="indent invalid")
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
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="readingOrder invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "relativeIndent") {
    Some(value) =>
      alignment.relative_indent = Some(
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="relativeIndent invalid")
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
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="definedName tag not closed")
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="definedName tag invalid")
      }
    let name = match attr_value(tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => raise XlsxError::InvalidXml(msg="definedName name missing")
    }
    let comment = match attr_value(tag, "comment") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let local_id = match attr_value(tag, "localSheetId") {
      Some(value) =>
        Some(
          @strconv.parse_int(value, base=10) catch {
            _ =>
              raise XlsxError::InvalidXml(
                msg="definedName localSheetId invalid",
              )
          },
        )
      None => None
    }
    let rest = text[end + 1:] catch {
        _ => raise XlsxError::InvalidXml(msg="definedName body invalid")
      }
    let data_end = match rest.find("</definedName>") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="definedName close missing")
    }
    let data = rest[:data_end] catch {
        _ => raise XlsxError::InvalidXml(msg="definedName data invalid")
      }
    let scope = match local_id {
      Some(id) =>
        if id >= 0 && id < sheet_names.length() {
          sheet_names[id]
        } else {
          raise XlsxError::InvalidXml(msg="definedName localSheetId missing")
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
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="mergeCell tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="mergeCell tag invalid")
      }
    let ref_value = match attr_value(tag, "ref") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="mergeCell ref missing")
    }
    let normalized = if ref_value.to_string().contains(":") {
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
    let text = chunk.to_string()
    let close_tag = "</dataValidation>"
    match text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = text[:end] catch {
            _ => raise XlsxError::InvalidXml(msg="dataValidation tag invalid")
          }
        validations.push("<dataValidation \{slice.to_string()}")
      }
      None => {
        let end = match text.find("/>") {
          Some(pos) => pos + 2
          None =>
            raise XlsxError::InvalidXml(msg="dataValidation tag not closed")
        }
        let slice = text[:end] catch {
            _ => raise XlsxError::InvalidXml(msg="dataValidation tag invalid")
          }
        validations.push("<dataValidation \{slice.to_string()}")
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
  let xml_str = xml.to_string()
  if !xml_str.contains("<x14:dataValidation") {
    return validations
  }
  let mut first = true
  for chunk in xml_str.split("<x14:dataValidation ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let close_tag = "</x14:dataValidation>"
    let end = match text.find(close_tag) {
      Some(pos) => pos + close_tag.length()
      None =>
        raise XlsxError::InvalidXml(msg="x14:dataValidation tag not closed")
    }
    let slice = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="x14:dataValidation tag invalid")
      }
    let full = "<x14:dataValidation \{slice.to_string()}"
    let open_end = match full.find(">") {
      Some(pos) => pos
      None =>
        raise XlsxError::InvalidXml(msg="x14:dataValidation open tag missing")
    }
    let attrs = full["<x14:dataValidation ".length():open_end] catch {
        _ =>
          raise XlsxError::InvalidXml(msg="x14:dataValidation open tag invalid")
      }
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
      None =>
        raise XlsxError::InvalidXml(msg="x14:dataValidation sqref missing")
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
  let xml_str = xml.to_string()
  if !xml_str.contains("<conditionalFormatting") {
    return formats
  }
  let mut first = true
  for chunk in xml_str.split("<conditionalFormatting") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let close_tag = "</conditionalFormatting>"
    match text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = text[:end] catch {
            _ =>
              raise XlsxError::InvalidXml(
                msg="conditionalFormatting tag invalid",
              )
          }
        formats.push("<conditionalFormatting\{slice.to_string()}")
      }
      None => {
        let end = match text.find("/>") {
          Some(pos) => pos + 2
          None =>
            raise XlsxError::InvalidXml(
              msg="conditionalFormatting tag not closed",
            )
        }
        let slice = text[:end] catch {
            _ =>
              raise XlsxError::InvalidXml(
                msg="conditionalFormatting tag invalid",
              )
          }
        formats.push("<conditionalFormatting\{slice.to_string()}")
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
  let xml_str = xml.to_string()
  if !xml_str.contains("<x14:cfvo") {
    return cfvos
  }
  let mut first = true
  for chunk in xml_str.split("<x14:cfvo") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let close_tag = "</x14:cfvo>"
    let full = match text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = text[:end] catch {
            _ => raise XlsxError::InvalidXml(msg="x14:cfvo tag invalid")
          }
        "<x14:cfvo\{slice.to_string()}"
      }
      None => {
        let end = match text.find("/>") {
          Some(pos) => pos + 2
          None => raise XlsxError::InvalidXml(msg="x14:cfvo tag not closed")
        }
        let slice = text[:end] catch {
            _ => raise XlsxError::InvalidXml(msg="x14:cfvo tag invalid")
          }
        "<x14:cfvo\{slice.to_string()}"
      }
    }
    let open_end = match full.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="x14:cfvo open tag missing")
    }
    let attrs = full["<x14:cfvo".length():open_end] catch {
        _ => raise XlsxError::InvalidXml(msg="x14:cfvo open tag invalid")
      }
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
  let text = rgb.to_string()
  if text.has_prefix("FF") && text.length() == 8 {
    let rest = text[2:] catch { _ => text }
    "#\{rest}"
  } else {
    "#\{text}"
  }
}

///|
fn parse_x14_conditional_formatting_blocks(
  xml : StringView,
) -> Array[String] raise XlsxError {
  let blocks : Array[String] = []
  let xml_str = xml.to_string()
  if xml_str.contains("<x14:conditionalFormattings") &&
    !xml_str.contains("</x14:conditionalFormattings>") {
    raise XlsxError::InvalidXml(msg="x14:conditionalFormattings tag not closed")
  }
  let mut open_pos : Int? = None
  let mut open_search_from = 0
  let open_needle = "<x14:conditionalFormatting"
  while open_search_from < xml_str.length() {
    let rest = xml_str[open_search_from:] catch {
        _ =>
          raise XlsxError::InvalidXml(
            msg="x14:conditionalFormatting search slice invalid",
          )
      }
    let rel_start = match rest.find(open_needle) {
      Some(pos) => pos
      None => break
    }
    let start = open_search_from + rel_start
    let after_needle = start + open_needle.length()
    let next_char = xml_str[after_needle:after_needle + 1] catch { _ => "" }
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
            raise XlsxError::InvalidXml(
              msg="x14:conditionalFormatting close before open",
            )
          }
        None =>
          raise XlsxError::InvalidXml(
            msg="x14:conditionalFormatting close without open",
          )
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
    let rest = xml_str[search_from:] catch {
        _ =>
          raise XlsxError::InvalidXml(
            msg="x14:conditionalFormatting search slice invalid",
          )
      }
    let rel_start = match rest.find(needle) {
      Some(pos) => pos
      None => break
    }
    let start = search_from + rel_start
    let after_needle = start + needle.length()
    let next_char = xml_str[after_needle:after_needle + 1] catch { _ => "" }
    if next_char == "s" {
      search_from = after_needle
      continue
    }
    let after_start = xml_str[start:] catch {
        _ =>
          raise XlsxError::InvalidXml(
            msg="x14:conditionalFormatting slice invalid",
          )
      }
    let after_text = after_start.to_string()
    let (full, consumed) = match after_text.find(close_tag) {
      Some(pos) => {
        let end = pos + close_tag.length()
        let slice = after_text[:end] catch {
            _ =>
              raise XlsxError::InvalidXml(
                msg="x14:conditionalFormatting tag invalid",
              )
          }
        (slice.to_string(), end)
      }
      None => {
        let end = match after_text.find("/>") {
          Some(pos) => pos + 2
          None =>
            raise XlsxError::InvalidXml(
              msg="x14:conditionalFormatting tag not closed",
            )
        }
        let slice = after_text[:end] catch {
            _ =>
              raise XlsxError::InvalidXml(
                msg="x14:conditionalFormatting tag invalid",
              )
          }
        (slice.to_string(), end)
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
      let rule_text = rule_chunk.to_string()
      let rule_close = "</x14:cfRule>"
      let rule_full = match rule_text.find(rule_close) {
        Some(pos) => {
          let end = pos + rule_close.length()
          let slice = rule_text[:end] catch {
              _ => raise XlsxError::InvalidXml(msg="x14:cfRule tag invalid")
            }
          "<x14:cfRule\{slice.to_string()}"
        }
        None => {
          let end = match rule_text.find("/>") {
            Some(pos) => pos + 2
            None => raise XlsxError::InvalidXml(msg="x14:cfRule tag not closed")
          }
          let slice = rule_text[:end] catch {
              _ => raise XlsxError::InvalidXml(msg="x14:cfRule tag invalid")
            }
          "<x14:cfRule\{slice.to_string()}"
        }
      }
      let open_end = match rule_full.find(">") {
        Some(pos) => pos
        None => continue
      }
      let attrs = rule_full["<x14:cfRule".length():open_end] catch {
          _ => raise XlsxError::InvalidXml(msg="x14:cfRule open tag invalid")
        }
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
            raise XlsxError::InvalidXml(
              msg="x14:conditionalFormatting sqref missing",
            )
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
        let rule_text = rule_chunk.to_string()
        let rule_close = "</x14:cfRule>"
        let rule_full = match rule_text.find(rule_close) {
          Some(pos) => {
            let end = pos + rule_close.length()
            let slice = rule_text[:end] catch {
                _ => raise XlsxError::InvalidXml(msg="x14:cfRule tag invalid")
              }
            "<x14:cfRule\{slice.to_string()}"
          }
          None => {
            let end = match rule_text.find("/>") {
              Some(pos) => pos + 2
              None =>
                raise XlsxError::InvalidXml(msg="x14:cfRule tag not closed")
            }
            let slice = rule_text[:end] catch {
                _ => raise XlsxError::InvalidXml(msg="x14:cfRule tag invalid")
              }
            "<x14:cfRule\{slice.to_string()}"
          }
        }
        let open_end = match rule_full.find(">") {
          Some(pos) => pos
          None => continue
        }
        let attrs = rule_full["<x14:cfRule".length():open_end] catch {
            _ => raise XlsxError::InvalidXml(msg="x14:cfRule open tag invalid")
          }
        let typ = match attr_value(attrs, "type") {
          Some(value) => value.to_string()
          None => ""
        }
        if typ != "iconSet" {
          continue
        }
        let mut priority = match attr_value(attrs, "priority") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ =>
                raise XlsxError::InvalidXml(msg="x14:cfRule priority invalid")
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
  let xml_str = xml.to_string()
  let marker = "<dimension"
  match xml_str.find(marker) {
    None => None
    Some(start) => {
      let rest = xml_str[start + marker.length():] catch {
          _ => raise XlsxError::InvalidXml(msg="dimension slice invalid")
        }
      let end = match rest.find("/>") {
        Some(pos) => pos
        None =>
          match rest.find(">") {
            Some(pos) => pos
            None => raise XlsxError::InvalidXml(msg="dimension tag not closed")
          }
      }
      let tag = rest[:end] catch {
          _ => raise XlsxError::InvalidXml(msg="dimension tag invalid")
        }
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
  for chunk in body.to_string().split("<pane ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="pane tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="pane tag invalid")
      }
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
        pane.x_split = @strconv.parse_double(value) catch {
          _ => raise XlsxError::InvalidXml(msg="pane xSplit invalid")
        }
      None => ()
    }
    match attr_value(tag, "ySplit") {
      Some(value) =>
        pane.y_split = @strconv.parse_double(value) catch {
          _ => raise XlsxError::InvalidXml(msg="pane ySplit invalid")
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
  for chunk in body.to_string().split("<selection ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="selection tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="selection tag invalid")
      }
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
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="sheetView tag not closed")
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="sheetView tag invalid")
      }
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
          @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="sheetView zoomScale invalid")
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
        view.workbook_view_id = @strconv.parse_int(value, base=10) catch {
          _ =>
            raise XlsxError::InvalidXml(msg="sheetView workbookViewId invalid")
        }
      None => ()
    }
    let self_closing = tag.to_string().trim().has_suffix("/")
    if !self_closing {
      let close = match text.find("</sheetView>") {
        Some(pos) => pos
        None => raise XlsxError::InvalidXml(msg="sheetView close missing")
      }
      let body_start = end + 1
      if close > body_start {
        let inner = text[body_start:close] catch {
            _ => raise XlsxError::InvalidXml(msg="sheetView body invalid")
          }
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
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="tabColor indexed invalid")
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
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="tabColor theme invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "tint") {
        Some(value) =>
          opts.tab_color_tint = Some(
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="tabColor tint invalid")
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
            @strconv.parse_int(value, base=10) catch {
              _ =>
                raise XlsxError::InvalidXml(
                  msg="sheetFormatPr baseColWidth invalid",
                )
            },
          )
        None => ()
      }
      match attr_value(tag, "defaultColWidth") {
        Some(value) =>
          opts.default_col_width = Some(
            @strconv.parse_double(value) catch {
              _ =>
                raise XlsxError::InvalidXml(
                  msg="sheetFormatPr defaultColWidth invalid",
                )
            },
          )
        None => ()
      }
      match attr_value(tag, "defaultRowHeight") {
        Some(value) =>
          opts.default_row_height = Some(
            @strconv.parse_double(value) catch {
              _ =>
                raise XlsxError::InvalidXml(
                  msg="sheetFormatPr defaultRowHeight invalid",
                )
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
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="pageMargins left invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "right") {
        Some(value) =>
          opts.right = Some(
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="pageMargins right invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "top") {
        Some(value) =>
          opts.top = Some(
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="pageMargins top invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "bottom") {
        Some(value) =>
          opts.bottom = Some(
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="pageMargins bottom invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "header") {
        Some(value) =>
          opts.header = Some(
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="pageMargins header invalid")
            },
          )
        None => ()
      }
      match attr_value(tag, "footer") {
        Some(value) =>
          opts.footer = Some(
            @strconv.parse_double(value) catch {
              _ => raise XlsxError::InvalidXml(msg="pageMargins footer invalid")
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
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="pageSetup paperSize invalid")
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
        @strconv.parse_int(value, base=10) catch {
          _ =>
            raise XlsxError::InvalidXml(msg="pageSetup firstPageNumber invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "scale") {
    Some(value) =>
      opts.adjust_to = Some(
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="pageSetup scale invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "fitToHeight") {
    Some(value) =>
      opts.fit_to_height = Some(
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="pageSetup fitToHeight invalid")
        },
      )
    None => ()
  }
  match attr_value(tag, "fitToWidth") {
    Some(value) =>
      opts.fit_to_width = Some(
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="pageSetup fitToWidth invalid")
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
      spin_count = @strconv.parse_int(value, base=10) catch {
        _ =>
          raise XlsxError::InvalidXml(msg="sheetProtection spinCount invalid")
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
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="brk tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="brk tag invalid")
      }
    let id = match attr_value(tag, "id") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="brk id invalid")
        }
      None => raise XlsxError::InvalidXml(msg="brk id missing")
    }
    let min = match attr_value(tag, "min") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="brk min invalid")
        }
      None => 0
    }
    let max = match attr_value(tag, "max") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="brk max invalid")
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
    None => raise XlsxError::InvalidXml(msg="picture relationship missing")
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
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="filterColumn tag not closed")
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="filterColumn tag invalid")
      }
    let col_id = match attr_value(tag, "colId") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="filterColumn colId invalid")
        }
      None => raise XlsxError::InvalidXml(msg="filterColumn colId missing")
    }
    let col = min_col + col_id
    let mut filters : Array[String]? = None
    let mut custom_filters : AutoFilterCustomFilters? = None
    if !tag.has_suffix("/") {
      let rest = text[end + 1:] catch {
          _ => raise XlsxError::InvalidXml(msg="filterColumn body invalid")
        }
      let body_end = match rest.find("</filterColumn>") {
        Some(pos) => pos
        None => 0
      }
      let column_body = if body_end > 0 {
        rest[:body_end] catch {
          _ => raise XlsxError::InvalidXml(msg="filterColumn body invalid")
        }
      } else {
        ""
      }
      match extract_tag_body_from(column_body, "filters") {
        Some(filters_body) => {
          let values : Array[String] = []
          let mut first_filter = true
          for part in filters_body.split("<filter ") {
            if first_filter {
              first_filter = false
              continue
            }
            let filter_text = part.to_string()
            let filter_end = match filter_text.find("/>") {
              Some(pos) => pos
              None =>
                match filter_text.find(">") {
                  Some(pos) => pos
                  None =>
                    raise XlsxError::InvalidXml(msg="filter tag not closed")
                }
            }
            let filter_tag = filter_text[:filter_end] catch {
                _ => raise XlsxError::InvalidXml(msg="filter tag invalid")
              }
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
            let custom_text = part.to_string()
            let custom_end = match custom_text.find("/>") {
              Some(pos) => pos
              None =>
                match custom_text.find(">") {
                  Some(pos) => pos
                  None =>
                    raise XlsxError::InvalidXml(
                      msg="customFilter tag not closed",
                    )
                }
            }
            let custom_tag = custom_text[:custom_end] catch {
                _ => raise XlsxError::InvalidXml(msg="customFilter tag invalid")
              }
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
    None => raise XlsxError::InvalidXml(msg="autoFilter ref missing")
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
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="hyperlink tag not closed")
    }
    let tag = try! text[:end]
    let raw_ref = match attr_value(tag, "ref") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="hyperlink ref missing")
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
fn parse_comment_authors(xml : StringView) -> Array[String] raise XlsxError {
  let authors : Array[String] = []
  let body = match extract_tag_body(xml, "authors") {
    Some(value) => value
    None => return authors
  }
  let mut first = true
  for chunk in body.split("<author>") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("</author>") {
      Some(pos) => pos
      None => continue
    }
    let name = unescape_xml_text(try! text[:end])
    authors.push(name)
  }
  authors
}

///|
fn parse_comments_xml(xml : StringView) -> Array[Comment] raise XlsxError {
  let comments : Array[Comment] = []
  let authors = parse_comment_authors(xml)
  let body = match extract_tag_body(xml, "commentList") {
    Some(value) => value
    None => return comments
  }
  let mut first = true
  for chunk in body.split("<comment ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="comment tag not closed")
    }
    let tag = try! text[:end]
    let ref_value = match attr_value(tag, "ref") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="comment ref missing")
    }
    let (row, col) = cell_ref_to_rc(ref_value)
    let cell = cell_ref_from(row, col)
    let author_id = match attr_value(tag, "authorId") {
      Some(value) => @strconv.parse_int(value, base=10) catch { _ => 0 }
      None => 0
    }
    let author = if author_id >= 0 && author_id < authors.length() {
      authors[author_id]
    } else {
      ""
    }
    let rest = try! text[end + 1:]
    let text_body = match extract_tag_body_from(rest, "text") {
      Some(value) => value
      None => ""
    }
    let paragraph = if text_body.contains("<r") {
      parse_rich_text_runs(text_body) catch {
        _ => []
      }
    } else {
      []
    }
    let text_value = parse_text_nodes(text_body)
    comments.push({
      cell,
      author,
      text: text_value,
      paragraph,
      width: None,
      height: None,
    })
  }
  comments
}

///|
fn parse_table_part_ids(xml : StringView) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let body = match extract_tag_body(xml, "tableParts") {
    Some(value) => value
    None => return ids
  }
  let mut first = true
  for chunk in body.split("<tablePart ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="tablePart tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="tablePart tag invalid")
      }
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="tablePart id missing")
    }
    ids.push(id)
  }
  ids
}

///|
fn parse_pivot_table_part_ids(
  xml : StringView,
) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let body = match extract_tag_body(xml, "pivotTableParts") {
    Some(value) => value
    None => return ids
  }
  let mut first = true
  for chunk in body.split("<pivotTablePart ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None =>
            raise XlsxError::InvalidXml(msg="pivotTablePart tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="pivotTablePart tag invalid")
      }
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="pivotTablePart id missing")
    }
    ids.push(id)
  }
  ids
}

///|
fn parse_sheet_slicer_rel_ids(
  xml : StringView,
) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let xml_str = xml.to_string()
  let mut first = true
  for chunk in xml_str.split("<x14:slicer ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="x14:slicer tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="x14:slicer tag invalid")
      }
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="x14:slicer id missing")
    }
    ids.push(id)
  }
  ids
}

///|
priv struct ParsedSlicerPartEntry {
  name : String
  cache : String
  caption : String
  display_header : Bool?
}

///|
fn parse_slicer_part_entries(
  xml : StringView,
) -> Array[ParsedSlicerPartEntry] raise XlsxError {
  let entries : Array[ParsedSlicerPartEntry] = []
  let xml_str = xml.to_string()
  let mut first = true
  for chunk in xml_str.split("<slicer ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="slicer tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="slicer tag invalid")
      }
    let name = match attr_value(tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => raise XlsxError::InvalidXml(msg="slicer name missing")
    }
    let cache = match attr_value(tag, "cache") {
      Some(value) => unescape_xml_text(value)
      None => raise XlsxError::InvalidXml(msg="slicer cache missing")
    }
    let caption = match attr_value(tag, "caption") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let display_header = match attr_value(tag, "showCaption") {
      Some(value) => Some(parse_bool_attr(value))
      None => None
    }
    entries.push({ name, cache, caption, display_header })
  }
  entries
}

///|
priv struct SlicerCacheDef {
  name : String
  source_name : String
  item_desc : Bool
  table_id : Int?
  table_column : Int?
  pivot_tab_id : Int?
  pivot_table_name : String?
}

///|
fn parse_slicer_cache_definition(
  xml : StringView,
) -> SlicerCacheDef raise XlsxError {
  let tag = match tag_attributes_in(xml, "slicerCacheDefinition") {
    Some(value) => value
    None => raise XlsxError::InvalidXml(msg="slicerCacheDefinition missing")
  }
  let name = match attr_value(tag, "name") {
    Some(value) => unescape_xml_text(value)
    None => raise XlsxError::InvalidXml(msg="slicer cache name missing")
  }
  let source_name = match attr_value(tag, "sourceName") {
    Some(value) => unescape_xml_text(value)
    None => ""
  }
  let mut item_desc = false
  let mut table_id : Int? = None
  let mut table_column : Int? = None
  let mut pivot_tab_id : Int? = None
  let mut pivot_table_name : String? = None
  match tag_attributes_in(xml, "x15:tableSlicerCache") {
    Some(cache_tag) => {
      match attr_value(cache_tag, "tableId") {
        Some(value) =>
          try @strconv.parse_int(value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="slicer cache tableId invalid")
          } noraise {
            val => table_id = Some(val)
          }
        None => ()
      }
      match attr_value(cache_tag, "column") {
        Some(value) =>
          try @strconv.parse_int(value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="slicer cache column invalid")
          } noraise {
            val => table_column = Some(val)
          }
        None => ()
      }
      match attr_value(cache_tag, "sortOrder") {
        Some(value) =>
          if unescape_xml_text(value) == "descending" {
            item_desc = true
          }
        None => ()
      }
    }
    None => ()
  }
  match tag_attributes_in(xml, "tabular") {
    Some(tabular_tag) =>
      match attr_value(tabular_tag, "sortOrder") {
        Some(value) =>
          if unescape_xml_text(value) == "descending" {
            item_desc = true
          }
        None => ()
      }
    None => ()
  }
  match tag_attributes_in(xml, "pivotTable") {
    Some(pivot_tag) => {
      match attr_value(pivot_tag, "tabId") {
        Some(value) =>
          try @strconv.parse_int(value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="slicer cache tabId invalid")
          } noraise {
            val => pivot_tab_id = Some(val)
          }
        None => ()
      }
      match attr_value(pivot_tag, "name") {
        Some(value) => pivot_table_name = Some(unescape_xml_text(value))
        None => ()
      }
    }
    None => ()
  }
  {
    name,
    source_name,
    item_desc,
    table_id,
    table_column,
    pivot_tab_id,
    pivot_table_name,
  }
}

///|
fn parse_slicer_cache_definitions(
  workbook_rels_xml : StringView,
  archive : @zip.Archive,
  decode : (Bytes) -> String raise XlsxError,
) -> Map[String, SlicerCacheDef] raise XlsxError {
  let defs : Map[String, SlicerCacheDef] = {}
  let targets = parse_relationship_targets(workbook_rels_xml, rel_slicer_cache)
  for _rel_id, target in targets {
    let cache_path = resolve_workbook_rel_target(target)
    let cache_bytes = match archive.get(cache_path) {
      Some(value) => value
      None => raise XlsxError::MissingPart(path=cache_path)
    }
    let cache_xml = decode(cache_bytes)
    let def = parse_slicer_cache_definition(cache_xml)
    defs[def.name] = def
  }
  defs
}

///|
fn resolve_slicer_sources_after_read(
  workbook : Workbook,
  slicer_cache_defs : Map[String, SlicerCacheDef],
) -> Unit {
  fn worksheet_name_from_tab_id(workbook : Workbook, tab_id : Int) -> String? {
    let count = workbook.sheets.length()
    if count == 0 {
      return None
    }
    let candidates : Array[Int] = []
    candidates.push(tab_id)
    candidates.push(tab_id + 1)
    candidates.push(tab_id - 1)
    for id in candidates {
      if id >= 1 && id <= count {
        return Some(workbook.sheets[id - 1].name)
      }
    }
    None
  }

  let table_by_id : Map[Int, (String, Table)] = {}
  for sheet in workbook.sheets {
    for table in sheet.tables() {
      if table.id > 0 {
        table_by_id[table.id] = (sheet.name, table)
      }
    }
  }
  for sheet in workbook.sheets {
    let slicers = sheet.slicers
    let mut i = 0
    while i < slicers.length() {
      let slicer = slicers[i]
      match slicer_cache_defs.get(slicer.cache) {
        Some(def) => {
          let mut table_sheet = slicer.table_sheet
          let mut table_name = slicer.table_name
          let mut source_name = slicer.source_name
          let mut item_desc = slicer.item_desc
          if def.source_name != "" {
            source_name = def.source_name
          }
          item_desc = def.item_desc
          match def.table_id {
            Some(table_id) =>
              match table_by_id.get(table_id) {
                Some((sheet_name, table)) => {
                  table_sheet = sheet_name
                  table_name = table.name
                  match def.table_column {
                    Some(col) => {
                      let idx = col - 1
                      if idx >= 0 && idx < table.columns.length() {
                        source_name = table.columns[idx]
                      }
                    }
                    None => ()
                  }
                }
                None => ()
              }
            None => ()
          }
          match def.pivot_table_name {
            Some(pivot_name) => if table_name == "" { table_name = pivot_name }
            None => ()
          }
          match def.pivot_tab_id {
            Some(tab_id) =>
              match worksheet_name_from_tab_id(workbook, tab_id) {
                Some(sheet_name) =>
                  if table_sheet == "" {
                    table_sheet = sheet_name
                  }
                None => ()
              }
            None => ()
          }
          if table_sheet != slicer.table_sheet ||
            table_name != slicer.table_name ||
            source_name != slicer.source_name ||
            item_desc != slicer.item_desc {
            slicers[i] = {
              name: slicer.name,
              cache: slicer.cache,
              source_name,
              cell: slicer.cell,
              table_sheet,
              table_name,
              caption: slicer.caption,
              macro_name: slicer.macro_name,
              width: slicer.width,
              height: slicer.height,
              display_header: slicer.display_header,
              item_desc,
              format: slicer.format,
            }
          }
        }
        None => ()
      }
      i = i + 1
    }
  }
}

///|
fn parse_legacy_drawing_rel_id(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let marker = "<\{tag_name.to_string()}"
  let mut first = true
  for chunk in xml.to_string().split(marker) {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None =>
            raise XlsxError::InvalidXml(
              msg="\{tag_name.to_string()} tag not closed",
            )
        }
    }
    let tag = text[:end] catch {
        _ =>
          raise XlsxError::InvalidXml(msg="\{tag_name.to_string()} tag invalid")
      }
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None =>
        raise XlsxError::InvalidXml(msg="\{tag_name.to_string()} id missing")
    }
    return Some(id)
  }
  None
}

///|
fn parse_xml_int_tag(
  xml : StringView,
  tag_name : StringView,
  msg : String,
) -> Int raise XlsxError {
  let body = match extract_tag_body_from(xml, tag_name) {
    Some(value) => value
    None => raise XlsxError::InvalidXml(msg~)
  }
  @strconv.parse_int(body, base=10) catch {
    _ => raise XlsxError::InvalidXml(msg~)
  }
}

///|
fn drawing_axis_span_emu(
  sheet : Worksheet,
  axis : StringView,
  from_idx0 : Int,
  from_off_emu : Int,
  to_idx0 : Int,
  to_off_emu : Int,
) -> Int {
  let mut start_idx0 = from_idx0
  let mut start_off = from_off_emu
  let mut end_idx0 = to_idx0
  let mut end_off = to_off_emu
  if end_idx0 < start_idx0 || (end_idx0 == start_idx0 && end_off < start_off) {
    start_idx0 = to_idx0
    start_off = to_off_emu
    end_idx0 = from_idx0
    end_off = from_off_emu
  }
  if start_idx0 == end_idx0 {
    return end_off - start_off
  }
  let mut total = 0
  let start_idx1 = start_idx0 + 1
  let start_cell_px = if axis == "col" {
    sheet.col_width_pixels(start_idx1)
  } else {
    sheet.row_height_pixels(start_idx1)
  }
  total = total + (start_cell_px * picture_emu_per_pixel - start_off)
  let mut idx0 = start_idx0 + 1
  while idx0 < end_idx0 {
    let idx1 = idx0 + 1
    let cell_px = if axis == "col" {
      sheet.col_width_pixels(idx1)
    } else {
      sheet.row_height_pixels(idx1)
    }
    total = total + cell_px * picture_emu_per_pixel
    idx0 = idx0 + 1
  }
  total + end_off
}

///|
fn parse_drawing_anchors(
  drawing_xml : StringView,
) -> Array[(String, PicturePositioning)] raise XlsxError {
  let xml_str = drawing_xml.to_string()
  let anchors : Array[(String, PicturePositioning)] = []
  let mut first_one = true
  for chunk in xml_str.split("<xdr:oneCellAnchor") {
    if first_one {
      first_one = false
      continue
    }
    let text = chunk.to_string()
    let close_tag = "</xdr:oneCellAnchor>"
    let end = match text.find(close_tag) {
      Some(pos) => pos + close_tag.length()
      None => raise XlsxError::InvalidXml(msg="oneCellAnchor close missing")
    }
    let slice = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="oneCellAnchor body invalid")
      }
    anchors.push(
      ("<xdr:oneCellAnchor\{slice.to_string()}", PicturePositioning::OneCell),
    )
  }
  let mut first_two = true
  for chunk in xml_str.split("<xdr:twoCellAnchor") {
    if first_two {
      first_two = false
      continue
    }
    let text = chunk.to_string()
    let close_tag = "</xdr:twoCellAnchor>"
    let end = match text.find(close_tag) {
      Some(pos) => pos + close_tag.length()
      None => raise XlsxError::InvalidXml(msg="twoCellAnchor close missing")
    }
    let slice = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="twoCellAnchor body invalid")
      }
    let full = "<xdr:twoCellAnchor\{slice.to_string()}"
    let positioning = match tag_attributes_in(full[:], "xdr:twoCellAnchor") {
      Some(tag) =>
        match attr_value(tag, "editAs") {
          Some(value) =>
            if value.to_string() == "absolute" {
              PicturePositioning::Absolute
            } else {
              PicturePositioning::TwoCell
            }
          None => PicturePositioning::TwoCell
        }
      None => PicturePositioning::TwoCell
    }
    anchors.push((full, positioning))
  }
  anchors
}

///|
fn parse_drawing_images(
  drawing_xml : StringView,
  drawing_rels_xml : StringView,
  sheet : Worksheet,
  archive : @zip.Archive,
) -> Array[Image] raise XlsxError {
  let images : Array[Image] = []
  let image_targets = if drawing_rels_xml.to_string() == "" {
    {}
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_image)
  }
  let hyperlink_targets = if drawing_rels_xml.to_string() == "" {
    {}
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_hyperlink)
  }
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    let pic_body = match extract_tag_body_from(anchor_xml[:], "xdr:pic") {
      Some(value) => value
      None => continue
    }
    let from_body = match extract_tag_body_from(anchor_xml[:], "xdr:from") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing anchor from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:col",
      "drawing col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:row",
      "drawing row invalid",
    )
    let col_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:colOff",
      "drawing colOff invalid",
    )
    let row_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:rowOff",
      "drawing rowOff invalid",
    )
    let reference = cell_ref_from(row_idx0 + 1, col_idx0 + 1)
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      PicturePositioning::OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml[:], "xdr:ext") {
          Some(value) => value
          None => raise XlsxError::InvalidXml(msg="drawing ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="drawing cx invalid")
            }
          None => raise XlsxError::InvalidXml(msg="drawing cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="drawing cy invalid")
            }
          None => raise XlsxError::InvalidXml(msg="drawing cy missing")
        }
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml[:], "xdr:to") {
          Some(value) => value
          None => raise XlsxError::InvalidXml(msg="drawing anchor to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:col",
          "drawing to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:row",
          "drawing to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body[:],
          "xdr:colOff",
          "drawing to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body[:],
          "xdr:rowOff",
          "drawing to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          sheet, "col", col_idx0, col_off_emu, to_col_idx0, to_col_off,
        )
        let cy = drawing_axis_span_emu(
          sheet, "row", row_idx0, row_off_emu, to_row_idx0, to_row_off,
        )
        (cx, cy)
      }
    }
    let c_nv_pr_tag = match tag_attributes_in(pic_body[:], "xdr:cNvPr") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing cNvPr missing")
    }
    let name = match attr_value(c_nv_pr_tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let alt_text = match attr_value(c_nv_pr_tag, "descr") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let lock_aspect_ratio = pic_body.contains("noChangeAspect=\"1\"")
    let client_tag = match tag_attributes_in(anchor_xml[:], "xdr:clientData") {
      Some(value) => value
      None => ""
    }
    let locked = match attr_value(client_tag, "fLocksWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let print_object = match attr_value(client_tag, "fPrintsWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let blip_tag = match tag_attributes_in(pic_body[:], "a:blip") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing blip missing")
    }
    let embed_id = match attr_value(blip_tag, "r:embed") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing embed missing")
    }
    let target = match image_targets.get(embed_id.to_string()) {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing image target missing")
    }
    let media_path = resolve_rel_target(target, "drawings")
    let data = match archive.get(media_path) {
      Some(value) => value
      None => raise XlsxError::MissingPart(path=media_path)
    }
    let ext = match media_path.to_string().rev_find(".") {
      Some(pos) =>
        if pos + 1 < media_path.length() {
          media_path[pos + 1:] catch {
            _ => ""
          }
        } else {
          ""
        }
      None => ""
    }
    let extension = ext.to_string().to_lower()
    let content_type = match image_content_type(extension) {
      Some(value) => value
      None => "application/octet-stream"
    }
    let mut hyperlink = ""
    let mut hyperlink_type = HyperlinkType::Unset
    match tag_attributes_in(pic_body[:], "a:hlinkClick") {
      Some(tag) =>
        match attr_value(tag, "r:id") {
          Some(rel_id) =>
            match hyperlink_targets.get(rel_id.to_string()) {
              Some(value) => {
                hyperlink = value
                if hyperlink.contains("://") {
                  hyperlink_type = HyperlinkType::External
                } else {
                  hyperlink_type = HyperlinkType::Location
                }
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
    images.push({
      reference,
      data,
      extension,
      content_type,
      offset_x,
      offset_y,
      scale_x: 1.0,
      scale_y: 1.0,
      width_emu,
      height_emu,
      print_object,
      locked,
      hyperlink,
      hyperlink_type,
      name,
      alt_text,
      lock_aspect_ratio,
      positioning,
    })
  }
  images
}

///|
fn parse_drawing_charts(
  drawing_xml : StringView,
  drawing_rels_xml : StringView,
  sheet : Worksheet,
  archive : @zip.Archive,
) -> Array[Chart] raise XlsxError {
  let charts : Array[Chart] = []
  let chart_targets = if drawing_rels_xml.to_string() == "" {
    {}
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_chart)
  }
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    let chart_tag = match tag_attributes_in(anchor_xml[:], "c:chart") {
      Some(value) => value
      None => continue
    }
    let rel_id = match attr_value(chart_tag, "r:id") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing chart rel id missing")
    }
    let target = match chart_targets.get(rel_id.to_string()) {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing chart target missing")
    }
    let chart_path = resolve_rel_target(target, "drawings")
    let chart_bytes = match archive.get(chart_path) {
      Some(value) => value
      None => raise XlsxError::MissingPart(path=chart_path)
    }
    let xml = @encoding/utf8.decode(chart_bytes) catch {
      _ => raise XlsxError::InvalidXml(msg="drawing chart xml decode failed")
    }
    let from_body = match extract_tag_body_from(anchor_xml[:], "xdr:from") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing anchor from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:col",
      "drawing col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:row",
      "drawing row invalid",
    )
    let col_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:colOff",
      "drawing colOff invalid",
    )
    let row_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:rowOff",
      "drawing rowOff invalid",
    )
    let reference = cell_ref_from(row_idx0 + 1, col_idx0 + 1)
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      PicturePositioning::OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml[:], "xdr:ext") {
          Some(value) => value
          None => raise XlsxError::InvalidXml(msg="drawing ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="drawing cx invalid")
            }
          None => raise XlsxError::InvalidXml(msg="drawing cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="drawing cy invalid")
            }
          None => raise XlsxError::InvalidXml(msg="drawing cy missing")
        }
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml[:], "xdr:to") {
          Some(value) => value
          None => raise XlsxError::InvalidXml(msg="drawing anchor to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:col",
          "drawing to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:row",
          "drawing to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body[:],
          "xdr:colOff",
          "drawing to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body[:],
          "xdr:rowOff",
          "drawing to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          sheet, "col", col_idx0, col_off_emu, to_col_idx0, to_col_off,
        )
        let cy = drawing_axis_span_emu(
          sheet, "row", row_idx0, row_off_emu, to_row_idx0, to_row_off,
        )
        (cx, cy)
      }
    }
    let client_tag = match tag_attributes_in(anchor_xml[:], "xdr:clientData") {
      Some(value) => value
      None => ""
    }
    let locked = match attr_value(client_tag, "fLocksWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let print_object = match attr_value(client_tag, "fPrintsWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    charts.push({
      reference,
      xml,
      offset_x,
      offset_y,
      width_emu,
      height_emu,
      print_object,
      locked,
      positioning,
    })
  }
  charts
}

///|
fn parse_drawing_shapes(
  drawing_xml : StringView,
) -> Array[Shape] raise XlsxError {
  let shapes : Array[Shape] = []
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    if anchor_xml.contains("<mc:AlternateContent") {
      continue
    }
    let sp_body = match extract_tag_body_from(anchor_xml[:], "xdr:sp") {
      Some(value) => value
      None => continue
    }
    if !sp_body.contains("<a:prstGeom") {
      continue
    }
    let from_body = match extract_tag_body_from(anchor_xml[:], "xdr:from") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing anchor from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:col",
      "drawing col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:row",
      "drawing row invalid",
    )
    let reference = cell_ref_from(row_idx0 + 1, col_idx0 + 1)
    let c_nv_pr_tag = match tag_attributes_in(sp_body[:], "xdr:cNvPr") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing shape cNvPr missing")
    }
    let name = match attr_value(c_nv_pr_tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let alt_text = match attr_value(c_nv_pr_tag, "descr") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let macro_name = match attr_value(c_nv_pr_tag, "macro") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let client_tag = match tag_attributes_in(anchor_xml[:], "xdr:clientData") {
      Some(value) => value
      None => ""
    }
    let locked = match attr_value(client_tag, "fLocksWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let print_object = match attr_value(client_tag, "fPrintsWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let sppr_body = match extract_tag_body_from(sp_body[:], "xdr:spPr") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing shape spPr missing")
    }
    let xfrm_body = match extract_tag_body_from(sppr_body[:], "a:xfrm") {
      Some(value) => value
      None => sppr_body
    }
    let ext_tag = match tag_attributes_in(xfrm_body[:], "a:ext") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing shape ext missing")
    }
    let cx = match attr_value(ext_tag, "cx") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="drawing shape cx invalid")
        }
      None => raise XlsxError::InvalidXml(msg="drawing shape cx missing")
    }
    let cy = match attr_value(ext_tag, "cy") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="drawing shape cy invalid")
        }
      None => raise XlsxError::InvalidXml(msg="drawing shape cy missing")
    }
    let width = (cx.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let height = (cy.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let geom_tag = match tag_attributes_in(sppr_body[:], "a:prstGeom") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing shape prstGeom missing")
    }
    let shape_type = match attr_value(geom_tag, "prst") {
      Some(value) => unescape_xml_text(value)
      None => raise XlsxError::InvalidXml(msg="drawing shape prst missing")
    }
    let mut fill_color = ""
    let mut fill_transparency = 0
    match extract_tag_body_from(sppr_body[:], "a:solidFill") {
      Some(fill_body) =>
        match tag_attributes_in(fill_body[:], "a:srgbClr") {
          Some(tag) =>
            match attr_value(tag, "val") {
              Some(value) => {
                fill_color = unescape_xml_text(value)
                match tag_attributes_in(fill_body[:], "a:alpha") {
                  Some(alpha_tag) =>
                    match attr_value(alpha_tag, "val") {
                      Some(alpha) =>
                        try @strconv.parse_int(alpha, base=10) catch {
                          _ => ()
                        } noraise {
                          value => {
                            let visible = value / 1000
                            let transparency = 100 - visible
                            if transparency >= 0 && transparency <= 100 {
                              fill_transparency = transparency
                            }
                          }
                        }
                      None => ()
                    }
                  None => ()
                }
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
    let mut line_color = ""
    let mut line_width = 1.0
    match tag_attributes_in(sppr_body[:], "a:ln") {
      Some(tag) => {
        match attr_value(tag, "w") {
          Some(value) =>
            try @strconv.parse_int(value, base=10) catch {
              _ => ()
            } noraise {
              value => line_width = value.to_double() / 12700.0
            }
          None => ()
        }
        match extract_tag_body_from(sppr_body[:], "a:ln") {
          Some(ln_body) =>
            match tag_attributes_in(ln_body[:], "a:srgbClr") {
              Some(color_tag) =>
                match attr_value(color_tag, "val") {
                  Some(value) => line_color = unescape_xml_text(value)
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      }
      None => ()
    }
    let paragraph : Array[RichTextRun] = []
    match extract_tag_body_from(sp_body[:], "xdr:txBody") {
      Some(tx_body) => {
        let tx = tx_body.to_string()
        let mut first = true
        for chunk in tx.split("<a:t>") {
          if first {
            first = false
            continue
          }
          let part = chunk.to_string()
          let end = match part.find("</a:t>") {
            Some(pos) => pos
            None => continue
          }
          let text = part[:end] catch { _ => "" }
          paragraph.push({ text: unescape_xml_text(text), font: None })
        }
      }
      None => ()
    }
    let text = ""
    shapes.push({
      reference,
      shape_type,
      macro_name,
      text,
      paragraph,
      width,
      height,
      scale_x: 1.0,
      scale_y: 1.0,
      fill_color,
      fill_transparency,
      line_color,
      line_width,
      name,
      alt_text,
      print_object,
      locked,
      positioning,
    })
  }
  shapes
}

///|
priv struct SlicerAnchorInfo {
  cell : String
  offset_x : Int
  offset_y : Int
  width : Int
  height : Int
  positioning : PicturePositioning
  macro_name : String
  alt_text : String
  locked : Bool
  print_object : Bool
}

///|
fn parse_drawing_slicer_anchors(
  drawing_xml : StringView,
  sheet : Worksheet,
) -> Map[String, SlicerAnchorInfo] raise XlsxError {
  let out : Map[String, SlicerAnchorInfo] = {}
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    let slicer_tag = match tag_attributes_in(anchor_xml[:], "sle:slicer") {
      Some(value) => value
      None => continue
    }
    let slicer_name = match attr_value(slicer_tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => continue
    }
    let from_body = match extract_tag_body_from(anchor_xml[:], "xdr:from") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="drawing slicer from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:col",
      "drawing slicer col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:row",
      "drawing slicer row invalid",
    )
    let col_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:colOff",
      "drawing slicer colOff invalid",
    )
    let row_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:rowOff",
      "drawing slicer rowOff invalid",
    )
    let cell = cell_ref_from(row_idx0 + 1, col_idx0 + 1)
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      PicturePositioning::OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml[:], "xdr:ext") {
          Some(value) => value
          None => raise XlsxError::InvalidXml(msg="drawing slicer ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="drawing slicer cx invalid")
            }
          None => raise XlsxError::InvalidXml(msg="drawing slicer cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="drawing slicer cy invalid")
            }
          None => raise XlsxError::InvalidXml(msg="drawing slicer cy missing")
        }
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml[:], "xdr:to") {
          Some(value) => value
          None => raise XlsxError::InvalidXml(msg="drawing slicer to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:col",
          "drawing slicer to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:row",
          "drawing slicer to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body[:],
          "xdr:colOff",
          "drawing slicer to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body[:],
          "xdr:rowOff",
          "drawing slicer to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          sheet, "col", col_idx0, col_off_emu, to_col_idx0, to_col_off,
        )
        let cy = drawing_axis_span_emu(
          sheet, "row", row_idx0, row_off_emu, to_row_idx0, to_row_off,
        )
        (cx, cy)
      }
    }
    let width = (width_emu.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let height = (height_emu.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let graphic_frame_tag = match
      tag_attributes_in(anchor_xml[:], "xdr:graphicFrame") {
      Some(value) => value
      None => ""
    }
    let macro_name = match attr_value(graphic_frame_tag, "macro") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let c_nv_pr_tag = match tag_attributes_in(anchor_xml[:], "xdr:cNvPr") {
      Some(value) => value
      None => ""
    }
    let alt_text = match attr_value(c_nv_pr_tag, "descr") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let client_tag = match tag_attributes_in(anchor_xml[:], "xdr:clientData") {
      Some(value) => value
      None => ""
    }
    let locked = match attr_value(client_tag, "fLocksWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let print_object = match attr_value(client_tag, "fPrintsWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    out[slicer_name] = {
      cell,
      offset_x,
      offset_y,
      width,
      height,
      positioning,
      macro_name,
      alt_text,
      locked,
      print_object,
    }
  }
  out
}

///|
///|
fn parse_bool_attr(value : StringView) -> Bool {
  match value.to_string() {
    "1" => true
    "true" => true
    "TRUE" => true
    _ => false
  }
}

///|
fn parse_inline_string(rest : StringView) -> InlineStringEntry raise XlsxError {
  let text = rest.to_string()
  let start = match text.find("<is") {
    Some(pos) => pos
    None => return { text: "", runs: None }
  }
  let after_start = text[start:] catch {
      _ => raise XlsxError::InvalidXml(msg="inline string tag invalid")
    }
  let open_end = match after_start.find(">") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="inline string not closed")
  }
  let body_start = start + open_end + 1
  let end = match text.find("</is>") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="inline string end missing")
  }
  let body = text[body_start:end] catch {
      _ => raise XlsxError::InvalidXml(msg="inline string body invalid")
    }
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
  for chunk in xml.to_string().split("<row ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="row tag not closed")
    }
    let tag = try! text[:end]
    let row_text = match attr_value(tag, "r") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="row index missing")
    }
    let row = @strconv.parse_int(row_text, base=10) catch {
      _ => raise XlsxError::InvalidXml(msg="row index invalid")
    }
    if row <= 0 {
      raise XlsxError::InvalidXml(msg="row index invalid")
    }
    let height = match attr_value(tag, "ht") {
      Some(value) =>
        Some(
          @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="row height invalid")
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
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="row outline level invalid")
        }
      None => 0
    }
    let style_id = match attr_value(tag, "s") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="row style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise XlsxError::InvalidStyleId(index=style_id)
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
  for chunk in xml.to_string().split("<col ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="col tag not closed")
    }
    let tag = try! text[:end]
    let min_text = match attr_value(tag, "min") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="col min missing")
    }
    let max_text = match attr_value(tag, "max") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="col max missing")
    }
    let min_col = @strconv.parse_int(min_text, base=10) catch {
      _ => raise XlsxError::InvalidXml(msg="col min invalid")
    }
    let max_col = @strconv.parse_int(max_text, base=10) catch {
      _ => raise XlsxError::InvalidXml(msg="col max invalid")
    }
    if min_col <= 0 || max_col <= 0 || max_col < min_col {
      raise XlsxError::InvalidXml(msg="col range invalid")
    }
    let width = match attr_value(tag, "width") {
      Some(value) =>
        Some(
          @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="col width invalid")
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
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="col outline level invalid")
        }
      None => 0
    }
    let style_id = match attr_value(tag, "style") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="col style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise XlsxError::InvalidStyleId(index=style_id)
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
fn parse_worksheet(
  xml : StringView,
  shared_strings : Array[SharedStringEntry],
  style_count : Int,
) -> (
  Array[Cell],
  Array[String],
  AutoFilter?,
  Map[Int, RowDimension],
  Map[Int, ColDimension],
  PageLayoutMarginsOptions?,
  PageLayoutOptions?,
  HeaderFooterOptions?,
  SheetProtection?,
  Array[PageBreak],
  Array[PageBreak],
  Array[SheetView],
  SheetPropsOptions?,
  String?,
  String?,
) raise XlsxError {
  let cells : Array[Cell] = []
  let mut first = true
  for chunk in xml.to_string().split("<c ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="cell tag not closed")
    }
    let tag = try! text[:end]
    let ref_value = match attr_value(tag, "r") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="cell reference missing")
    }
    let style_id = match attr_value(tag, "s") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise XlsxError::InvalidStyleId(index=style_id)
    }
    let cell_type = attr_value(tag, "t")
    let rest = try! text[end + 1:]
    let formula_start = match rest.find("<f>") {
      Some(pos) => Some(pos)
      None =>
        match rest.find("<f ") {
          Some(pos) => Some(pos)
          None =>
            match rest.find("<f/") {
              Some(pos) => Some(pos)
              None => None
            }
        }
    }
    let (formula, formula_type, formula_ref, formula_shared_index) = match
      formula_start {
      Some(pos) => {
        let f_rest = try! rest[pos:]
        let open_end = match f_rest.find(">") {
          Some(value) => value
          None => raise XlsxError::InvalidXml(msg="formula tag not closed")
        }
        let open_tag = try! f_rest[:open_end]
        let open_chars = open_tag.to_array()
        let mut last = open_chars.length() - 1
        while last >= 0 && is_attr_space(open_chars[last]) {
          last = last - 1
        }
        let is_self_closing = last >= 0 && open_chars[last] == '/'
        let kind = match attr_value(open_tag, "t") {
          Some(value) =>
            match formula_type_from_ooxml(value) {
              Some(parsed) => Some(parsed)
              None => raise XlsxError::InvalidXml(msg="formula type invalid")
            }
          None => None
        }
        let ref_value = match attr_value(open_tag, "ref") {
          Some(value) => Some(unescape_xml_text(value))
          None => None
        }
        let si_value = match attr_value(open_tag, "si") {
          Some(value) =>
            Some(
              @strconv.parse_int(value, base=10) catch {
                _ => raise XlsxError::InvalidXml(msg="formula si invalid")
              },
            )
          None => None
        }
        if is_self_closing {
          (Some(""), kind, ref_value, si_value)
        } else {
          let after_open = try! f_rest[open_end + 1:]
          let close_end = match after_open.find("</f>") {
            Some(value) => value
            None => raise XlsxError::InvalidXml(msg="formula not closed")
          }
          let content = unescape_xml_text(try! after_open[:close_end])
          (Some(content), kind, ref_value, si_value)
        }
      }
      None => (None, None, None, None)
    }
    let raw_value_opt = match rest.find("<v>") {
      Some(pos) => {
        let v_rest = try! rest[pos + 3:]
        let v_end = match v_rest.find("</v>") {
          Some(end) => end
          None => raise XlsxError::InvalidXml(msg="cell value not closed")
        }
        Some(try! v_rest[:v_end].to_string())
      }
      None => None
    }
    let raw_value = match raw_value_opt {
      Some(value) => value
      None => ""
    }
    let inline_entry = match cell_type {
      Some(kind) if kind == "inlineStr" => Some(parse_inline_string(rest))
      _ => None
    }
    let force_string = raw_value_opt is None &&
      formula is Some(_) &&
      !(cell_type is Some("inlineStr"))
    let mut value = ""
    let mut value_type = CellValueType::String
    let mut rich_text : Array[RichTextRun]? = None
    if force_string {
      value = ""
      value_type = CellValueType::String
    } else {
      match cell_type {
        Some(kind) if kind == "s" => {
          let index = @strconv.parse_int(raw_value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="shared string index invalid")
          }
          if index < 0 || index >= shared_strings.length() {
            raise XlsxError::InvalidSharedString(index~)
          }
          let entry = shared_strings[index]
          value = entry.text
          rich_text = entry.runs
          value_type = CellValueType::String
        }
        Some(kind) if kind == "b" => {
          if raw_value != "0" && raw_value != "1" {
            raise XlsxError::InvalidXml(msg="cell boolean invalid")
          }
          value = raw_value
          value_type = CellValueType::Bool
        }
        Some(kind) if kind == "e" => {
          value = unescape_xml_text(raw_value)
          value_type = CellValueType::Error
        }
        Some(kind) if kind == "str" => {
          value = unescape_xml_text(raw_value)
          value_type = CellValueType::String
        }
        Some(kind) if kind == "inlineStr" =>
          match inline_entry {
            Some(entry) => {
              value = entry.text
              rich_text = entry.runs
              value_type = CellValueType::String
            }
            None => {
              value = ""
              value_type = CellValueType::String
            }
          }
        Some(kind) if kind == "d" => {
          value = unescape_xml_text(raw_value)
          value_type = CellValueType::String
        }
        Some(kind) if kind == "n" =>
          if raw_value == "" {
            value = ""
            value_type = CellValueType::String
          } else {
            ignore(
              @strconv.parse_double(raw_value) catch {
                _ => raise XlsxError::InvalidXml(msg="cell number invalid")
              },
            )
            value = raw_value
            value_type = CellValueType::Number
          }
        Some(_) => {
          value = unescape_xml_text(raw_value)
          value_type = CellValueType::String
        }
        None =>
          if raw_value == "" {
            value = ""
            value_type = CellValueType::String
          } else {
            ignore(
              @strconv.parse_double(raw_value) catch {
                _ => raise XlsxError::InvalidXml(msg="cell number invalid")
              },
            )
            value = raw_value
            value_type = CellValueType::Number
          }
      }
    }
    let (row, col) = cell_ref_to_rc(ref_value)
    let canonical = cell_ref_from(row, col)
    cells.push({
      reference: canonical,
      row,
      col,
      value,
      value_type,
      rich_text,
      formula,
      formula_type,
      formula_ref,
      formula_shared_index,
      style_id,
    })
  }
  let merged_cells = parse_merge_cells(xml)
  let auto_filter = parse_auto_filter(xml)
  let row_dimensions = parse_row_dimensions(xml, style_count)
  let col_dimensions = parse_col_dimensions(xml, style_count)
  let page_margins = parse_page_margins(xml)
  let page_layout = parse_page_layout(xml)
  let header_footer = parse_header_footer(xml)
  let sheet_protection = parse_sheet_protection(xml)
  let row_breaks = parse_page_breaks(xml, "rowBreaks")
  let col_breaks = parse_page_breaks(xml, "colBreaks")
  let sheet_views = parse_sheet_views(xml)
  let sheet_props = parse_sheet_props(xml)
  let dimension_ref = parse_sheet_dimension(xml)
  let picture_rel_id = parse_picture_rel_id(xml)
  (
    cells, merged_cells, auto_filter, row_dimensions, col_dimensions, page_margins,
    page_layout, header_footer, sheet_protection, row_breaks, col_breaks, sheet_views,
    sheet_props, dimension_ref, picture_rel_id,
  )
}

///|
fn enforce_unzip_limits(
  archive : @zip.Archive,
  options : Options,
) -> Unit raise XlsxError {
  let mut total_size = 0
  for entry in archive.entries() {
    let size = entry.data.length()
    total_size = total_size + size
    if options.unzip_size_limit > 0 && total_size > options.unzip_size_limit {
      raise XlsxError::InvalidOptions(msg="unzip size limit exceeded")
    }
    if options.unzip_xml_size_limit > 0 {
      let name = entry.name.to_lower()
      if name.has_suffix(".xml") && size > options.unzip_xml_size_limit {
        raise XlsxError::InvalidOptions(msg="unzip xml size limit exceeded")
      }
    }
  }
}

///|
fn read_zip_bytes(
  bytes : BytesView,
  options? : Options = Options::new(),
  transcoder? : (String, Bytes) -> String raise XlsxError,
) -> Workbook raise XlsxError {
  let resolved_options = normalize_unzip_limits(options)
  let archive = @zip.read(bytes) catch {
    err => raise XlsxError::UnsupportedFeature(msg=err.to_string())
  }
  enforce_unzip_limits(archive, resolved_options)
  let decode = (value : Bytes) => decode_utf8(value, transcoder)
  let workbook_bytes = match archive.get("xl/workbook.xml") {
    Some(value) => value
    None => raise XlsxError::MissingPart(path="xl/workbook.xml")
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
    file_path: None,
    zip_writer: None,
    charset_transcoder: transcoder,
    options: resolved_options,
    workbook_protection,
    active_sheet_index: safe_active_index,
  }
  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => decode(value)
    None => raise XlsxError::MissingPart(path="xl/_rels/workbook.xml.rels")
  }
  let slicer_cache_defs = parse_slicer_cache_definitions(
    workbook_rels, archive, decode,
  )
  let vba_targets = parse_relationship_targets(workbook_rels, rel_vba_project)
  match first_relationship_target(vba_targets) {
    Some(target) => {
      let vba_path = resolve_workbook_rel_target(target)
      let vba_bytes = match archive.get(vba_path) {
        Some(value) => value
        None => raise XlsxError::MissingPart(path=vba_path)
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
      raise XlsxError::InvalidXml(msg="sheet relationship missing")
    }
    if is_worksheet {
      let target = match worksheet_targets.get(rel_id) {
        Some(value) => value
        None => raise XlsxError::InvalidXml(msg="worksheet target missing")
      }
      let sheet_path = resolve_workbook_rel_target(target)
      let sheet_bytes = match archive.get(sheet_path) {
        Some(value) => value
        None => raise XlsxError::MissingPart(path=sheet_path)
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
      let rels_xml = if needs_rels {
        let rels_path = rels_path_for(sheet_path, "worksheets")
        let rels_bytes = match archive.get(rels_path) {
          Some(value) => value
          None => raise XlsxError::MissingPart(path=rels_path)
        }
        decode(rels_bytes)
      } else {
        ""
      }
      let slicer_part_entries = if slicer_rel_ids.length() == 0 {
        []
      } else {
        if rels_xml == "" {
          raise XlsxError::InvalidXml(msg="slicer relationship missing")
        }
        let rel_targets = parse_relationship_targets(rels_xml, rel_slicer)
        let parsed : Array[ParsedSlicerPartEntry] = []
        let seen_paths : Map[String, Bool] = {}
        for rel_id in slicer_rel_ids {
          let target = match rel_targets.get(rel_id) {
            Some(value) => value
            None =>
              raise XlsxError::InvalidXml(msg="slicer relationship missing")
          }
          let slicer_path = resolve_rel_target(target, "worksheets")
          if seen_paths.contains(slicer_path) {
            continue
          }
          seen_paths[slicer_path] = true
          let slicer_bytes = match archive.get(slicer_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=slicer_path)
          }
          let slicer_xml = decode(slicer_bytes)
          parsed.append(parse_slicer_part_entries(slicer_xml)[:])
        }
        parsed
      }
      let sheet_background = match picture_rel_id {
        Some(rel_id) => {
          if rels_xml == "" {
            raise XlsxError::InvalidXml(msg="picture relationship missing")
          }
          let image_targets = parse_relationship_targets(rels_xml, rel_image)
          let target = match image_targets.get(rel_id) {
            Some(value) => value
            None => raise XlsxError::InvalidXml(msg="picture target missing")
          }
          let image_path = resolve_rel_target(target, "worksheets")
          let image_bytes = match archive.get(image_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=image_path)
          }
          let path_text = target.to_string()
          let extension = match path_text.rev_find(".") {
            Some(pos) =>
              if pos + 1 < path_text.length() {
                let view = path_text[pos + 1:] catch {
                    _ =>
                      raise XlsxError::InvalidSheetBackground(
                        msg="image extension missing",
                      )
                  }
                view.to_string().to_lower()
              } else {
                raise XlsxError::InvalidSheetBackground(
                  msg="image extension missing",
                )
              }
            None =>
              raise XlsxError::InvalidSheetBackground(
                msg="image extension missing",
              )
          }
          let content_type = match image_content_type(extension) {
            Some(value) => value
            None =>
              raise XlsxError::InvalidSheetBackground(
                msg="unsupported image extension",
              )
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
                None =>
                  raise XlsxError::InvalidXml(
                    msg="hyperlink relationship missing",
                  )
              }
              parsed_links.push({
                reference: link.reference,
                target,
                link_type: HyperlinkType::External,
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
                    link_type: HyperlinkType::Location,
                    display: link.display,
                    tooltip: link.tooltip,
                  })
                None =>
                  raise XlsxError::InvalidXml(msg="hyperlink target missing")
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
            None =>
              raise XlsxError::InvalidXml(msg="table relationship missing")
          }
          let table_path = resolve_rel_target(target, "worksheets")
          let table_bytes = match archive.get(table_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=table_path)
          }
          let table_xml = decode(table_bytes)
          parsed_tables.push(parse_table_xml(table_xml))
        }
        parsed_tables
      }
      let pivot_tables = if pivot_part_ids.length() == 0 {
        []
      } else {
        let rel_targets = parse_relationship_targets(rels_xml, rel_pivot_table)
        let parsed_pivots : Array[PivotTable] = []
        for rel_id in pivot_part_ids {
          let target = match rel_targets.get(rel_id) {
            Some(value) => value
            None =>
              raise XlsxError::InvalidXml(
                msg="pivot table relationship missing",
              )
          }
          let pivot_path = resolve_rel_target(target, "worksheets")
          let pivot_bytes = match archive.get(pivot_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=pivot_path)
          }
          let pivot_xml = decode(pivot_bytes)
          let pivot_rels_path = rels_path_for(pivot_path, "pivotTables")
          let pivot_rels_bytes = match archive.get(pivot_rels_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=pivot_rels_path)
          }
          let pivot_rels_xml = decode(pivot_rels_bytes)
          let cache_targets = parse_relationship_targets(
            pivot_rels_xml, rel_pivot_cache,
          )
          let cache_target = match first_relationship_target(cache_targets) {
            Some(value) => value
            None =>
              raise XlsxError::InvalidXml(
                msg="pivot cache relationship missing",
              )
          }
          let cache_path = resolve_rel_target(cache_target, "pivotTables")
          let cache_bytes = match archive.get(cache_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=cache_path)
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
              match first_relationship_target(record_targets) {
                Some(record_target) => {
                  let record_path = resolve_rel_target(
                    record_target, "pivotCache",
                  )
                  let record_bytes = match archive.get(record_path) {
                    Some(value) => value
                    None => raise XlsxError::MissingPart(path=record_path)
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
            None =>
              raise XlsxError::InvalidXml(
                msg="vml drawing relationship missing",
              )
          }
          let vml_path = resolve_rel_target(target, "worksheets")
          let vml_bytes = match archive.get(vml_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=vml_path)
          }
          Some(decode(vml_bytes))
        }
        None => None
      }
      let vml_drawing_hf_xml = match legacy_drawing_hf_rel_id {
        Some(rel_id) => {
          let target = match vml_targets.get(rel_id) {
            Some(value) => value
            None =>
              raise XlsxError::InvalidXml(
                msg="vml drawing hf relationship missing",
              )
          }
          let vml_path = resolve_rel_target(target, "worksheets")
          let vml_bytes = match archive.get(vml_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=vml_path)
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
            None => raise XlsxError::MissingPart(path=comment_path)
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
        x14_cf_rule_id_counter: 1,
        ignored_errors,
        comments,
        row_dimensions,
        col_dimensions,
        state,
        stream_state: StreamState::Idle,
      }
      let mut slicer_anchor_info : Map[String, SlicerAnchorInfo] = {}
      match drawing_rel_id {
        Some(rel_id) => {
          if rels_xml == "" {
            raise XlsxError::InvalidXml(msg="drawing relationship missing")
          }
          let drawing_targets = parse_relationship_targets(
            rels_xml, rel_drawing,
          )
          let drawing_target = match drawing_targets.get(rel_id) {
            Some(value) => value
            None => raise XlsxError::InvalidXml(msg="drawing target missing")
          }
          let drawing_path = resolve_rel_target(drawing_target, "worksheets")
          let drawing_bytes = match archive.get(drawing_path) {
            Some(value) => value
            None => raise XlsxError::MissingPart(path=drawing_path)
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
            format.positioning = Some(PicturePositioning::TwoCell)
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
      workbook.sheet_order.push(
        SheetEntry::Worksheet(workbook.sheets.length() - 1),
      )
    } else {
      let target = match chartsheet_targets.get(rel_id) {
        Some(value) => value
        None => raise XlsxError::InvalidXml(msg="chartsheet target missing")
      }
      let chartsheet_path = resolve_workbook_rel_target(target)
      let chartsheet_bytes = match archive.get(chartsheet_path) {
        Some(value) => value
        None => raise XlsxError::MissingPart(path=chartsheet_path)
      }
      let chartsheet_xml = decode(chartsheet_bytes)
      let drawing_rel_id = parse_legacy_drawing_rel_id(
        chartsheet_xml, "drawing",
      )
      let drawing_rel = match drawing_rel_id {
        Some(value) => value
        None => raise XlsxError::InvalidXml(msg="chartsheet drawing missing")
      }
      let chartsheet_rels_path = rels_path_for(chartsheet_path, "chartsheets")
      let chartsheet_rels_bytes = match archive.get(chartsheet_rels_path) {
        Some(value) => value
        None => raise XlsxError::MissingPart(path=chartsheet_rels_path)
      }
      let chartsheet_rels_xml = decode(chartsheet_rels_bytes)
      let drawing_targets = parse_relationship_targets(
        chartsheet_rels_xml, rel_drawing,
      )
      let drawing_target = match drawing_targets.get(drawing_rel) {
        Some(value) => value
        None => raise XlsxError::InvalidXml(msg="drawing target missing")
      }
      let drawing_path = resolve_rel_target(drawing_target, "chartsheets")
      let drawing_rels_path = rels_path_for(drawing_path, "drawings")
      let drawing_rels_bytes = match archive.get(drawing_rels_path) {
        Some(value) => value
        None => raise XlsxError::MissingPart(path=drawing_rels_path)
      }
      let drawing_rels_xml = decode(drawing_rels_bytes)
      let chart_targets = parse_relationship_targets(
        drawing_rels_xml, rel_chart,
      )
      let chart_target = match first_relationship_target(chart_targets) {
        Some(value) => value
        None => raise XlsxError::InvalidXml(msg="chart target missing")
      }
      let chart_path = resolve_rel_target(chart_target, "drawings")
      let chart_bytes = match archive.get(chart_path) {
        Some(value) => value
        None => raise XlsxError::MissingPart(path=chart_path)
      }
      let chart_xml = decode(chart_bytes)
      let chart_sheet = ChartSheet::new(name, chart_xml)
      chart_sheet.state = state
      workbook.chart_sheets.push(chart_sheet)
      workbook.sheet_order.push(
        SheetEntry::ChartSheet(workbook.chart_sheets.length() - 1),
      )
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
    raise XlsxError::EncryptedPackage
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
    let result : Result[Workbook, Error] = try? (match transcoder {
      Some(value) =>
        read_zip_bytes(decrypted, options=resolved_options, transcoder=value)
      None => read_zip_bytes(decrypted, options=resolved_options)
    })
    match result {
      Ok(workbook) => workbook
      Err(_) => raise XlsxError::InvalidPassword
    }
  } else {
    match transcoder {
      Some(value) =>
        read_zip_bytes(bytes, options=resolved_options, transcoder=value)
      None => read_zip_bytes(bytes, options=resolved_options)
    }
  }
}

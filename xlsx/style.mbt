///|
pub enum NumberFormat {
  Builtin(Int)
  Custom(String)
} derive(Eq, Show)

///|
pub struct Font {
  mut bold : Bool?
  mut italic : Bool?
  mut underline : String?
  mut size : Double?
  mut color : String?
  mut family : String?
} derive(Eq, Show)

///|
pub fn Font::new() -> Font {
  {
    bold: None,
    italic: None,
    underline: None,
    size: None,
    color: None,
    family: None,
  }
}

///|
pub fn Font::with_values(
  bold? : Bool,
  italic? : Bool,
  underline? : String,
  size? : Double,
  color? : String,
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
  match family {
    Some(v) => font.family = Some(v)
    None => ()
  }
  font
}

///|
pub struct Style {
  number_format : NumberFormat?
  font : Font?
} derive(Eq, Show)

///|
pub fn Style::new() -> Style {
  { number_format: None, font: None }
}

///|
pub fn Style::number_format(format_code : String) -> Style {
  { number_format: Some(NumberFormat::Custom(format_code)), font: None }
}

///|
pub fn Style::builtin_number_format(id : Int) -> Style {
  { number_format: Some(NumberFormat::Builtin(id)), font: None }
}

///|
pub fn Style::font(font : Font) -> Style {
  { number_format: None, font: Some(font) }
}

///|
pub fn Style::with_font(self : Style, font : Font) -> Style {
  { number_format: self.number_format, font: Some(font) }
}

///|
fn write_styles_xml(
  styles : ArrayView[Style],
  conditional_styles : ArrayView[Style],
  default_font : StringView,
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
    let underline = match font.underline {
      Some(v) => v.to_string()
      None => ""
    }
    let color = match font.color {
      Some(v) => v.to_string()
      None => ""
    }
    "\{family}|\{size}|\{bold}|\{italic}|\{underline}|\{color}"
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
    match font.underline {
      Some(value) =>
        sb.write_view("      <u val=\"\{escape_xml_attr(value)}\"/>\n")
      None => ()
    }
    match font.size {
      Some(value) => sb.write_view("      <sz val=\"\{value}\"/>\n")
      None => sb.write_view("      <sz val=\"11\"/>\n")
    }
    match font.color {
      Some(value) => {
        let normalized = value.replace_all(old="#", new="")
        let rgb = if normalized.length() == 6 {
          "FF" + normalized
        } else {
          normalized
        }
        sb.write_view("      <color rgb=\"\{escape_xml_attr(rgb)}\"/>\n")
      }
      None => sb.write_view("      <color theme=\"1\"/>\n")
    }
    let family = match font.family {
      Some(v) => v.to_string()
      None => font_name
    }
    sb.write_view("      <name val=\"")
    sb.write_view(escape_xml_attr(family))
    sb.write_view("\"/>\n")
    sb.write_view("      <family val=\"2\"/>\n")
    sb.write_view("    </font>\n")
  }
  sb.write_view("  </fonts>\n")
  let base_block =
    #|  <fills count="2">
    #|    <fill><patternFill patternType="none"/></fill>
    #|    <fill><patternFill patternType="gray125"/></fill>
    #|  </fills>
    #|  <borders count="1">
    #|    <border><left/><right/><top/><bottom/><diagonal/></border>
    #|  </borders>
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
    sb.write_view(
      "    <xf numFmtId=\"\{num_fmt_id}\" fontId=\"\{font_id}\" fillId=\"0\" borderId=\"0\" xfId=\"0\"",
    )
    if apply {
      sb.write_view(" applyNumberFormat=\"1\"")
    }
    if apply_font {
      sb.write_view(" applyFont=\"1\"")
    }
    sb.write_view("/>\n")
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
      let has_num_fmt = match style.number_format {
        Some(_) => true
        None => false
      }
      if !has_num_fmt && !has_font {
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
            match font.underline {
              Some(value) =>
                sb.write_view("<u val=\"\{escape_xml_attr(value)}\"/>")
              None => ()
            }
            match font.size {
              Some(value) => sb.write_view("<sz val=\"\{value}\"/>")
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
                sb.write_view("<color rgb=\"\{escape_xml_attr(rgb)}\"/>")
              }
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
            sb.write_view("<family val=\"2\"/>")
            sb.write_view("</font>")
          }
        None => ()
      }
      sb.write_view("</dxf>\n")
    }
    sb.write_view("  </dxfs>\n")
  }
  sb.write_view(
    "  <tableStyles count=\"0\" defaultTableStyle=\"TableStyleMedium9\" defaultPivotStyle=\"PivotStyleLight16\"/>\n",
  )
  sb.write_view("</styleSheet>")
  sb.to_string()
}

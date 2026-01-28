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
pub struct Fill {
  mut typ : String?
  mut pattern : Int?
  mut colors : Array[String]?
} derive(Eq, Show)

///|
pub fn Fill::new() -> Fill {
  { typ: None, pattern: None, colors: None }
}

///|
pub fn Fill::pattern(pattern? : Int, color? : String) -> Fill {
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
  fill
}

///|
pub fn Fill::solid(color : String) -> Fill {
  Fill::pattern(pattern=1, color~)
}

///|
pub struct Border {
  typ : String
  mut color : String?
  mut style : Int?
} derive(Eq, Show)

///|
pub fn Border::new(typ : String) -> Border {
  { typ, color: None, style: None }
}

///|
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
pub struct Style {
  number_format : NumberFormat?
  font : Font?
  fill : Fill?
  border : Array[Border]?
} derive(Eq, Show)

///|
pub fn Style::new() -> Style {
  { number_format: None, font: None, fill: None, border: None }
}

///|
pub fn Style::number_format(format_code : String) -> Style {
  {
    number_format: Some(NumberFormat::Custom(format_code)),
    font: None,
    fill: None,
    border: None,
  }
}

///|
pub fn Style::builtin_number_format(id : Int) -> Style {
  {
    number_format: Some(NumberFormat::Builtin(id)),
    font: None,
    fill: None,
    border: None,
  }
}

///|
pub fn Style::font(font : Font) -> Style {
  { number_format: None, font: Some(font), fill: None, border: None }
}

///|
pub fn Style::with_font(self : Style, font : Font) -> Style {
  {
    number_format: self.number_format,
    font: Some(font),
    fill: self.fill,
    border: self.border,
  }
}

///|
pub fn Style::fill(fill : Fill) -> Style {
  { number_format: None, font: None, fill: Some(fill), border: None }
}

///|
pub fn Style::with_fill(self : Style, fill : Fill) -> Style {
  {
    number_format: self.number_format,
    font: self.font,
    fill: Some(fill),
    border: self.border,
  }
}

///|
pub fn Style::border(border : Array[Border]) -> Style {
  { number_format: None, font: None, fill: None, border: Some(border) }
}

///|
pub fn Style::with_border(self : Style, border : Array[Border]) -> Style {
  {
    number_format: self.number_format,
    font: self.font,
    fill: self.fill,
    border: Some(border),
  }
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

  // Fill collection: id 0/1 are the workbook default fills.
  let fill_patterns : Array[String] = [
    "none", "solid", "mediumGray", "darkGray", "lightGray", "darkHorizontal", "darkVertical",
    "darkDown", "darkUp", "darkGrid", "darkTrellis", "lightHorizontal", "lightVertical",
    "lightDown", "lightUp", "lightGrid", "lightTrellis", "gray125", "gray0625",
  ]
  let fills : Array[(Int, String?)] = [(0, None), (17, None)]
  let fill_ids : Map[String, Int] = {}
  fn normalize_fill_key(pattern : Int, color : String?) -> String {
    let c = match color {
      Some(v) => v
      None => ""
    }
    "\{pattern}|\{c}"
  }

  fill_ids[normalize_fill_key(0, None)] = 0
  fill_ids[normalize_fill_key(17, None)] = 1
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
                let color = match fill.colors {
                  Some(colors) => colors.get(0)
                  None => None
                }
                let key = normalize_fill_key(pattern, color)
                if !fill_ids.contains(key) {
                  fill_ids[key] = fills.length()
                  fills.push((pattern, color))
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
    let (pattern, color) = entry
    let pattern_type = fill_patterns[pattern]
    match color {
      Some(value) => {
        let normalized = value.replace_all(old="#", new="")
        let rgb = if normalized.length() == 6 {
          "FF" + normalized
        } else {
          normalized
        }
        sb.write_view("    <fill><patternFill patternType=\"")
        sb.write_view(escape_xml_attr(pattern_type))
        sb.write_view("\"><fgColor rgb=\"")
        sb.write_view(escape_xml_attr(rgb))
        sb.write_view("\"/></patternFill></fill>\n")
      }
      None => {
        sb.write_view("    <fill><patternFill patternType=\"")
        sb.write_view(escape_xml_attr(pattern_type))
        sb.write_view("\"/></fill>\n")
      }
    }
  }
  sb.write_view("  </fills>\n")

  // Border collection: id 0 is the workbook default border.
  let border_styles : Array[String] = [
    "none", "thin", "medium", "dashed", "dotted", "thick", "double", "hair", "mediumDashed",
    "dashDot", "mediumDashDot", "dashDotDot", "mediumDashDotDot", "slantDashDot",
  ]
  let borders : Array[Array[(String, Int, String?)]] = [
    [
      ("left", 0, None),
      ("right", 0, None),
      ("top", 0, None),
      ("bottom", 0, None),
      ("diagonal", 0, None),
    ],
  ]
  let border_ids : Map[String, Int] = {}
  fn normalize_border_key(lines : ArrayView[(String, Int, String?)]) -> String {
    let sb = StringBuilder::new()
    let mut first = true
    for line in lines {
      let (_, style, color) = line
      if first {
        first = false
      } else {
        sb.write_char('|')
      }
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
  fn border_lines_for_style(
    borders : ArrayView[Border],
  ) -> Array[(String, Int, String?)] {
    let sides : Array[String] = ["left", "right", "top", "bottom"]
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
    lines.push(("diagonal", 0, None))
    lines
  }

  for style in style_list {
    match style.border {
      Some(border) => {
        let lines = border_lines_for_style(border)
        let key = normalize_border_key(lines)
        if !border_ids.contains(key) {
          border_ids[key] = borders.length()
          borders.push(lines)
        }
      }
      None => ()
    }
  }
  sb.write_view("  <borders count=\"\{borders.length()}\">\n")
  for entry in borders {
    sb.write_view("    <border>")
    for line in entry {
      let (side, style, color) = line
      if side == "diagonal" {
        sb.write_view("<diagonal/>")
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
              let color = match fill.colors {
                Some(colors) => colors.get(0)
                None => None
              }
              match fill_ids.get(normalize_fill_key(pattern, color)) {
                Some(id) => id
                None => 0
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
      let has_fill = match style.fill {
        Some(fill) =>
          match fill.typ {
            Some(t) => t == "pattern"
            None => false
          }
        None => false
      }
      let has_border = match style.border {
        Some(border) => {
          let lines = border_lines_for_style(border)
          let mut any = false
          for line in lines {
            let (_, s, c) = line
            if s > 0 || c != None {
              any = true
            }
          }
          any
        }
        None => false
      }
      let has_num_fmt = match style.number_format {
        Some(_) => true
        None => false
      }
      if !has_num_fmt && !has_font && !has_fill && !has_border {
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
      match style.fill {
        Some(fill) =>
          if has_fill {
            let pattern = match fill.pattern {
              Some(v) => v
              None => 1
            }
            if pattern >= 0 && pattern < fill_patterns.length() {
              let pattern_type = fill_patterns[pattern]
              let color = match fill.colors {
                Some(colors) => colors.get(0)
                None => None
              }
              sb.write_view("<fill><patternFill patternType=\"")
              sb.write_view(escape_xml_attr(pattern_type))
              sb.write_view("\">")
              match color {
                Some(value) => {
                  let normalized = value.replace_all(old="#", new="")
                  let rgb = if normalized.length() == 6 {
                    "FF" + normalized
                  } else {
                    normalized
                  }
                  sb.write_view("<bgColor rgb=\"")
                  sb.write_view(escape_xml_attr(rgb))
                  sb.write_view("\"/>")
                }
                None => ()
              }
              sb.write_view("</patternFill></fill>")
            }
          }
        None => ()
      }
      match style.border {
        Some(border) =>
          if has_border {
            let lines = border_lines_for_style(border)
            sb.write_view("<border>")
            for line in lines {
              let (side, style, color) = line
              if side == "diagonal" {
                sb.write_view("<diagonal/>")
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

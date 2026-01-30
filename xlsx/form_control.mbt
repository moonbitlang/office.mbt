///|
pub struct FormControl {
  cell : String
  control_type : String
  text : String
  mut macro_name : String?
  mut checked : Bool?
  mut cell_link : String?
  mut width : Int?
  mut height : Int?
  mut current_val : Int?
  mut min_val : Int?
  mut max_val : Int?
  mut inc_change : Int?
  mut page_change : Int?
  mut horizontally : Bool?
  mut format : GraphicOptions
  mut paragraph : Array[RichTextRun]
} derive(Eq, Show)

///|
let max_form_control_value = 30000

///|
fn normalize_form_control_type(
  control_type : StringView,
) -> (String, String) raise XlsxError {
  let lower = control_type.to_string().to_lower()
  let normalized = lower
    .replace_all(old=" ", new="")
    .replace_all(old="_", new="")
  match normalized {
    "button" => ("Button", "Button")
    "checkbox" => ("CheckBox", "Checkbox")
    "radiobutton" | "optionbutton" | "radio" => ("OptionButton", "Radio")
    "scroll" | "scrollbar" => ("ScrollBar", "Scroll")
    "spin" | "spinbutton" | "spinner" => ("SpinButton", "Spin")
    "gbox" | "groupbox" => ("GroupBox", "GBox")
    "label" => ("Label", "Label")
    _ =>
      raise XlsxError::InvalidSheetOperation(
        msg="unsupported form control type",
      )
  }
}

///|
pub fn FormControl::new(
  cell : String,
  control_type : String,
  text? : String = "",
) -> FormControl raise XlsxError {
  if cell == "" {
    raise XlsxError::InvalidSheetOperation(msg="form control cell empty")
  }
  if control_type == "" {
    raise XlsxError::InvalidSheetOperation(msg="form control type empty")
  }
  let (canonical_type, _) = normalize_form_control_type(control_type)
  ignore(cell_ref_to_rc(cell))
  {
    cell,
    control_type: canonical_type,
    text,
    macro_name: None,
    checked: None,
    cell_link: None,
    width: None,
    height: None,
    current_val: None,
    min_val: None,
    max_val: None,
    inc_change: None,
    page_change: None,
    horizontally: None,
    format: GraphicOptions::new(),
    paragraph: [],
  }
}

///|
pub fn FormControl::set_macro_name(
  self : FormControl,
  value : StringView,
) -> Unit {
  let v = value.to_string()
  self.macro_name = if v == "" { None } else { Some(v) }
}

///|
pub fn FormControl::clear_macro_name(self : FormControl) -> Unit {
  self.macro_name = None
}

///|
pub fn FormControl::set_checked(self : FormControl, checked : Bool) -> Unit {
  self.checked = Some(checked)
}

///|
pub fn FormControl::clear_checked(self : FormControl) -> Unit {
  self.checked = None
}

///|
pub fn FormControl::set_cell_link(
  self : FormControl,
  cell_link : StringView,
) -> Unit raise XlsxError {
  let value = cell_link.to_string()
  if value == "" {
    self.cell_link = None
    return
  }
  ignore(cell_ref_to_rc(value))
  self.cell_link = Some(value)
}

///|
pub fn FormControl::clear_cell_link(self : FormControl) -> Unit {
  self.cell_link = None
}

///|
pub fn FormControl::set_width(
  self : FormControl,
  width : Int,
) -> Unit raise XlsxError {
  if width <= 0 {
    raise XlsxError::InvalidSheetOperation(msg="form control width invalid")
  }
  self.width = Some(width)
}

///|
pub fn FormControl::clear_width(self : FormControl) -> Unit {
  self.width = None
}

///|
pub fn FormControl::set_height(
  self : FormControl,
  height : Int,
) -> Unit raise XlsxError {
  if height <= 0 {
    raise XlsxError::InvalidSheetOperation(msg="form control height invalid")
  }
  self.height = Some(height)
}

///|
pub fn FormControl::clear_height(self : FormControl) -> Unit {
  self.height = None
}

///|
pub fn FormControl::set_current_val(
  self : FormControl,
  value : Int,
) -> Unit raise XlsxError {
  if value < 0 || value > max_form_control_value {
    raise XlsxError::InvalidSheetOperation(
      msg="form control current value invalid",
    )
  }
  self.current_val = Some(value)
}

///|
pub fn FormControl::clear_current_val(self : FormControl) -> Unit {
  self.current_val = None
}

///|
pub fn FormControl::set_min_val(
  self : FormControl,
  value : Int,
) -> Unit raise XlsxError {
  if value < 0 || value > max_form_control_value {
    raise XlsxError::InvalidSheetOperation(msg="form control min value invalid")
  }
  self.min_val = Some(value)
}

///|
pub fn FormControl::clear_min_val(self : FormControl) -> Unit {
  self.min_val = None
}

///|
pub fn FormControl::set_max_val(
  self : FormControl,
  value : Int,
) -> Unit raise XlsxError {
  if value < 0 || value > max_form_control_value {
    raise XlsxError::InvalidSheetOperation(msg="form control max value invalid")
  }
  self.max_val = Some(value)
}

///|
pub fn FormControl::clear_max_val(self : FormControl) -> Unit {
  self.max_val = None
}

///|
pub fn FormControl::set_inc_change(
  self : FormControl,
  value : Int,
) -> Unit raise XlsxError {
  if value < 0 || value > max_form_control_value {
    raise XlsxError::InvalidSheetOperation(
      msg="form control inc change invalid",
    )
  }
  self.inc_change = Some(value)
}

///|
pub fn FormControl::clear_inc_change(self : FormControl) -> Unit {
  self.inc_change = None
}

///|
pub fn FormControl::set_page_change(
  self : FormControl,
  value : Int,
) -> Unit raise XlsxError {
  if value < 0 || value > max_form_control_value {
    raise XlsxError::InvalidSheetOperation(
      msg="form control page change invalid",
    )
  }
  self.page_change = Some(value)
}

///|
pub fn FormControl::clear_page_change(self : FormControl) -> Unit {
  self.page_change = None
}

///|
pub fn FormControl::set_horizontally(self : FormControl, value : Bool) -> Unit {
  self.horizontally = Some(value)
}

///|
pub fn FormControl::clear_horizontally(self : FormControl) -> Unit {
  self.horizontally = None
}

///|
pub fn FormControl::set_format(
  self : FormControl,
  format : GraphicOptions,
) -> Unit {
  self.format = format
}

///|
pub fn FormControl::set_paragraph(
  self : FormControl,
  paragraph : Array[RichTextRun],
) -> Unit {
  self.paragraph = paragraph
}

///|
pub fn FormControl::clear_paragraph(self : FormControl) -> Unit {
  self.paragraph.clear()
}

///|
struct FormControlVmlPreset {
  filled : String?
  fill_color : String?
  stroked : String?
  stroke_color : String?
  button : String?
  fill_xml : String?
  auto_fill : String?
  text_h_align : String?
  text_v_align : String?
  no_three_d : Bool
  first_button : Bool
} derive(Eq, Show)

///|
fn form_control_vml_preset(control_type : StringView) -> FormControlVmlPreset? {
  let lower = control_type.to_string().to_lower()
  let normalized = lower
    .replace_all(old=" ", new="")
    .replace_all(old="_", new="")
  match normalized {
    "button" =>
      Some({
        filled: None,
        fill_color: Some("buttonFace [67]"),
        stroked: None,
        stroke_color: Some("windowText [64]"),
        button: Some("t"),
        fill_xml: Some(
          "<v:fill color2=\"buttonFace [67]\" angle=\"-180\" type=\"gradient\"><o:fill v:ext=\"view\" type=\"gradientUnscaled\"/></v:fill>\n",
        ),
        auto_fill: Some("True"),
        text_h_align: Some("Center"),
        text_v_align: Some("Center"),
        no_three_d: false,
        first_button: false,
      })
    "checkbox" =>
      Some({
        filled: Some("f"),
        fill_color: Some("window [65]"),
        stroked: Some("f"),
        stroke_color: Some("windowText [64]"),
        button: None,
        fill_xml: None,
        auto_fill: Some("True"),
        text_h_align: None,
        text_v_align: Some("Center"),
        no_three_d: true,
        first_button: false,
      })
    "radiobutton" | "optionbutton" | "radio" =>
      Some({
        filled: Some("f"),
        fill_color: Some("window [65]"),
        stroked: Some("f"),
        stroke_color: Some("windowText [64]"),
        button: None,
        fill_xml: None,
        auto_fill: Some("False"),
        text_h_align: None,
        text_v_align: Some("Center"),
        no_three_d: true,
        first_button: true,
      })
    "scroll" | "scrollbar" =>
      Some({
        filled: None,
        fill_color: None,
        stroked: Some("f"),
        stroke_color: Some("windowText [64]"),
        button: None,
        fill_xml: None,
        auto_fill: None,
        text_h_align: None,
        text_v_align: None,
        no_three_d: false,
        first_button: false,
      })
    "spin" | "spinbutton" | "spinner" =>
      Some({
        filled: None,
        fill_color: None,
        stroked: Some("f"),
        stroke_color: Some("windowText [64]"),
        button: None,
        fill_xml: None,
        auto_fill: Some("False"),
        text_h_align: None,
        text_v_align: None,
        no_three_d: false,
        first_button: false,
      })
    "gbox" | "groupbox" =>
      Some({
        filled: Some("f"),
        fill_color: None,
        stroked: Some("f"),
        stroke_color: Some("windowText [64]"),
        button: None,
        fill_xml: None,
        auto_fill: Some("False"),
        text_h_align: None,
        text_v_align: None,
        no_three_d: true,
        first_button: false,
      })
    "label" =>
      Some({
        filled: Some("f"),
        fill_color: Some("window [65]"),
        stroked: Some("f"),
        stroke_color: Some("windowText [64]"),
        button: None,
        fill_xml: None,
        auto_fill: Some("False"),
        text_h_align: None,
        text_v_align: None,
        no_three_d: false,
        first_button: false,
      })
    _ => None
  }
}

///|
fn write_form_controls_vml(
  sheet_id : Int,
  sheet : Worksheet,
  controls : ArrayView[FormControl],
) -> String raise XlsxError {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\">\n",
  )
  sb.write_view("  <o:shapelayout v:ext=\"edit\">\n")
  sb.write_view("    <o:idmap v:ext=\"edit\" data=\"\{sheet_id}\"/>\n")
  sb.write_view("  </o:shapelayout>\n")
  sb.write_view(
    "  <v:shapetype id=\"_x0000_t201\" coordsize=\"21600,21600\" o:spt=\"202\" path=\"m0,0l0,21600,21600,21600,21600,0xe\">\n",
  )
  sb.write_view("    <v:stroke joinstyle=\"miter\"/>\n")
  sb.write_view("    <v:path o:connecttype=\"rect\"/>\n")
  sb.write_view("  </v:shapetype>\n")
  let mut shape_id = 2048
  for control in controls {
    let (_, object_type) = normalize_form_control_type(control.control_type)
    let (row, col) = cell_ref_to_rc(control.cell)
    let row0 = row - 1
    let col0 = col - 1
    let base_width_px = match control.width {
      Some(v) => v
      None => 140
    }
    let base_height_px = match control.height {
      Some(v) => v
      None => 60
    }
    let scale_x = match control.format.scale_x {
      Some(v) => if v <= 0.0 { 1.0 } else { v }
      None => 1.0
    }
    let scale_y = match control.format.scale_y {
      Some(v) => if v <= 0.0 { 1.0 } else { v }
      None => 1.0
    }
    let width_px = (Double::from_int(base_width_px) * scale_x).to_int()
    let height_px = (Double::from_int(base_height_px) * scale_y).to_int()
    let mut col_end0 = col0
    let mut x2 = width_px
    let mut cur_col = col
    while x2 >= sheet.col_width_pixels(cur_col) {
      x2 = x2 - sheet.col_width_pixels(cur_col)
      cur_col = cur_col + 1
      col_end0 = col_end0 + 1
    }
    let mut row_end0 = row0
    let mut y2 = height_px
    let mut cur_row = row
    while y2 >= sheet.row_height_pixels(cur_row) {
      y2 = y2 - sheet.row_height_pixels(cur_row)
      cur_row = cur_row + 1
      row_end0 = row_end0 + 1
    }
    let anchor = "\{col0}, 0, \{row0}, 0, \{col_end0}, \{x2}, \{row_end0}, \{y2}"
    let preset = form_control_vml_preset(control.control_type)
    sb.write_view("  <v:shape id=\"_x0000_s\{shape_id}\" type=\"#_x0000_t201\"")
    match preset {
      Some(p) => {
        match p.button {
          Some(v) => sb.write_view(" o:button=\"\{escape_xml_attr(v)}\"")
          None => ()
        }
        match p.filled {
          Some(v) => sb.write_view(" filled=\"\{escape_xml_attr(v)}\"")
          None => ()
        }
        match p.fill_color {
          Some(v) => sb.write_view(" fillcolor=\"\{escape_xml_attr(v)}\"")
          None => ()
        }
        match p.stroked {
          Some(v) => sb.write_view(" stroked=\"\{escape_xml_attr(v)}\"")
          None => ()
        }
        match p.stroke_color {
          Some(v) => sb.write_view(" strokecolor=\"\{escape_xml_attr(v)}\"")
          None => ()
        }
      }
      None => ()
    }
    sb.write_view(
      " style=\"position:absolute;73.5pt;width:108pt;height:59.25pt;z-index:1;mso-wrap-style:tight\" o:insetmode=\"auto\">\n",
    )
    sb.write_view("    <v:path o:connecttype=\"none\"/>\n")
    match preset {
      Some(p) =>
        match p.fill_xml {
          Some(v) => sb.write_view("    \{v}")
          None => ()
        }
      None => ()
    }
    if control.text != "" || control.paragraph.length() > 0 {
      sb.write_view("    <v:textbox style=\"mso-direction-alt:auto\">\n")
      sb.write_view("      <div style=\"text-align:left\">")
      if control.text != "" {
        sb.write_view("<font>")
        sb.write_view(escape_xml_text(control.text))
        sb.write_view("</font>")
      }
      for run in control.paragraph {
        sb.write_view("<font")
        match run.font {
          Some(font) => {
            match font.family {
              Some(face) => {
                sb.write_view(" face=\"")
                sb.write_view(escape_xml_attr(face))
                sb.write_view("\"")
              }
              None => ()
            }
            match font.size {
              Some(sz) => {
                let v = (sz * 20.0).to_int()
                if v > 0 {
                  sb.write_view(" size=\"\{v}\"")
                }
              }
              None => ()
            }
            match font.color {
              Some(color) => {
                let normalized = if color.has_prefix("#") {
                  color
                } else {
                  "#\{color}"
                }
                sb.write_view(" color=\"")
                sb.write_view(escape_xml_attr(normalized))
                sb.write_view("\"")
              }
              None => ()
            }
          }
          None => ()
        }
        sb.write_view(">")
        let mut content = escape_xml_text(run.text) + "<br></br>\r\n"
        match run.font {
          Some(font) => {
            match font.underline {
              Some("double") => content = "<u class=\"font1\">\{content}</u>"
              Some("single") => content = "<u>\{content}</u>"
              Some(_) => ()
              None => ()
            }
            if font.italic {
              content = "<i>\{content}</i>"
            }
            if font.bold {
              content = "<b>\{content}</b>"
            }
          }
          None => ()
        }
        sb.write_view(content)
        sb.write_view("</font>")
      }
      sb.write_view("</div>\n")
      sb.write_view("    </v:textbox>\n")
    }
    sb.write_view("    <x:ClientData ObjectType=\"")
    sb.write_view(escape_xml_attr(object_type))
    sb.write_view("\">\n")
    sb.write_view("      <x:Anchor>\{anchor}</x:Anchor>\n")
    match preset {
      Some(p) => {
        match p.auto_fill {
          Some(v) =>
            sb.write_view(
              "      <x:AutoFill>\{escape_xml_text(v)}</x:AutoFill>\n",
            )
          None => ()
        }
        match p.text_h_align {
          Some(v) =>
            sb.write_view(
              "      <x:TextHAlign>\{escape_xml_text(v)}</x:TextHAlign>\n",
            )
          None => ()
        }
        match p.text_v_align {
          Some(v) =>
            sb.write_view(
              "      <x:TextVAlign>\{escape_xml_text(v)}</x:TextVAlign>\n",
            )
          None => ()
        }
        if p.no_three_d {
          sb.write_view("      <x:NoThreeD/>\n")
        }
        if p.first_button {
          sb.write_view("      <x:FirstButton/>\n")
        }
      }
      None => ()
    }
    match control.format.positioning {
      Some(PicturePositioning::Absolute) => {
        sb.write_view("      <x:MoveWithCells/>\n")
        sb.write_view("      <x:SizeWithCells/>\n")
      }
      Some(PicturePositioning::OneCell) =>
        sb.write_view("      <x:SizeWithCells/>\n")
      Some(PicturePositioning::TwoCell) => ()
      None => ()
    }
    match control.format.print_object {
      Some(false) =>
        sb.write_view("      <x:PrintObject>False</x:PrintObject>\n")
      _ => ()
    }
    match control.macro_name {
      Some(name) => {
        sb.write_view("      <x:FmlaMacro>")
        sb.write_view(escape_xml_text(name))
        sb.write_view("</x:FmlaMacro>\n")
      }
      None => ()
    }
    if control.text != "" {
      sb.write_view("      <x:Text>")
      sb.write_view(escape_xml_text(control.text))
      sb.write_view("</x:Text>\n")
    }
    match control.cell_link {
      Some(link) => {
        sb.write_view("      <x:FmlaLink>")
        sb.write_view(escape_xml_text(link))
        sb.write_view("</x:FmlaLink>\n")
      }
      None => ()
    }
    match control.current_val {
      Some(v) => sb.write_view("      <x:Val>\{v}</x:Val>\n")
      None => ()
    }
    match control.min_val {
      Some(v) => sb.write_view("      <x:Min>\{v}</x:Min>\n")
      None => ()
    }
    match control.max_val {
      Some(v) => sb.write_view("      <x:Max>\{v}</x:Max>\n")
      None => ()
    }
    match control.inc_change {
      Some(v) => sb.write_view("      <x:Inc>\{v}</x:Inc>\n")
      None => ()
    }
    match control.page_change {
      Some(v) => sb.write_view("      <x:Page>\{v}</x:Page>\n")
      None => ()
    }
    match control.horizontally {
      Some(true) => sb.write_view("      <x:Horiz/>\n")
      _ => ()
    }
    if control.control_type == "ScrollBar" {
      sb.write_view("      <x:Dx>15</x:Dx>\n")
    }
    match control.checked {
      Some(true) => sb.write_view("      <x:Checked>1</x:Checked>\n")
      Some(false) => sb.write_view("      <x:Checked>0</x:Checked>\n")
      None => ()
    }
    sb.write_view("      <x:Row>\{row0}</x:Row>\n")
    sb.write_view("      <x:Column>\{col0}</x:Column>\n")
    sb.write_view("    </x:ClientData>\n")
    sb.write_view("  </v:shape>\n")
    shape_id = shape_id + 1
  }
  sb.write_view("</xml>")
  sb.to_string()
}

///|
fn xml_has_tag(body : StringView, tag : StringView) -> Bool {
  let t = tag.to_string()
  body.contains("<\{t}/>") ||
  body.contains("<\{t} />") ||
  body.contains("<\{t}></\{t}>") ||
  body.contains("<\{t}>")
}

///|
fn extract_xml_text_tag(body : StringView, tag : StringView) -> String? {
  let open = "<\{tag.to_string()}>"
  let close = "</\{tag.to_string()}>"
  match body.find(open) {
    Some(start) => {
      let rest = body[start + open.length():] catch { _ => return None }
      let end = match rest.find(close) {
        Some(v) => v
        None => return None
      }
      let value = rest[:end] catch { _ => return None }
      Some(unescape_xml_text(value))
    }
    None => None
  }
}

///|
fn strip_vml_font_markup(text : StringView) -> String {
  let mut s = text.to_string()
  s = s.replace(old="<b>", new="")
  s = s.replace(old="</b>", new="")
  s = s.replace(old="<i>", new="")
  s = s.replace(old="</i>", new="")
  s = s.replace(old="<u>", new="")
  s = s.replace(old="<u class=\"font1\">", new="")
  s = s.replace(old="</u>", new="")
  s = s.replace(old="<br></br>\r\n", new="")
  s = s.replace(old="<br></br>", new="")
  s = s.replace(old="<br />", new="")
  s = s.replace(old="<br/>", new="")
  s = s.replace(old="<br>", new="")
  s
}

///|
fn vml_rich_text_font(
  bold : Bool,
  italic : Bool,
  underline : String?,
  family : String?,
  size : Double?,
  color : String?,
) -> RichTextFont {
  {
    bold,
    italic,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline,
    size,
    color,
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family,
  }
}

///|
fn parse_vml_textbox(
  shape : StringView,
) -> (String, Array[RichTextRun]) raise XlsxError {
  let empty : Array[RichTextRun] = []
  let start = match shape.find("<v:textbox") {
    Some(v) => v
    None => return ("", empty)
  }
  let after_textbox = shape[start:] catch { _ => return ("", empty) }
  let div_start = match after_textbox.find("<div") {
    Some(v) => v
    None => return ("", empty)
  }
  let div_after = after_textbox[div_start:] catch { _ => return ("", empty) }
  let div_open_end = match div_after.find(">") {
    Some(v) => v
    None => return ("", empty)
  }
  let div_body = div_after[div_open_end + 1:] catch { _ => return ("", empty) }
  let div_close = match div_body.find("</div>") {
    Some(v) => v
    None => return ("", empty)
  }
  let inner = div_body[:div_close] catch { _ => return ("", empty) }
  if !inner.contains("<font") {
    return (unescape_xml_text(inner), empty)
  }
  let inner_s = inner.to_string()
  let mut i = 0
  let runs : Array[RichTextRun] = []
  while true {
    let rest = inner_s[i:] catch { _ => break }
    let font_rel = match rest.find("<font") {
      Some(v) => v
      None => break
    }
    let font_start = i + font_rel
    let font_open = inner_s[font_start:] catch { _ => break }
    let open_end_rel = match font_open.find(">") {
      Some(v) => v
      None => break
    }
    let attrs = font_open[5:open_end_rel] catch { _ => "" }
    let content_start = font_start + open_end_rel + 1
    let after_open = inner_s[content_start:] catch { _ => break }
    let close_rel = match after_open.find("</font>") {
      Some(v) => v
      None => break
    }
    let raw_inner = after_open[:close_rel] catch { _ => "" }
    let bold = raw_inner.contains("<b>")
    let italic = raw_inner.contains("<i>")
    let underline = if raw_inner.contains("<u class=\"font1\">") {
      Some("double")
    } else if raw_inner.contains("<u>") {
      Some("single")
    } else {
      None
    }
    let face = attr_value(attrs, "face")
    let size = match attr_value(attrs, "size") {
      Some(v) => {
        let n = @strconv.parse_int(v.trim(), base=10) catch { _ => 0 }
        if n > 0 {
          Some(Double::from_int(n) / 20.0)
        } else {
          None
        }
      }
      None => None
    }
    let color = match attr_value(attrs, "color") {
      Some(v) => if v.trim() == "" { None } else { Some(v) }
      None => None
    }
    let stripped = strip_vml_font_markup(raw_inner)
    let text = unescape_xml_text(stripped)
    let has_style = bold ||
      italic ||
      underline is Some(_) ||
      face is Some(_) ||
      size is Some(_) ||
      color is Some(_)
    let font = if has_style {
      Some(vml_rich_text_font(bold, italic, underline, face, size, color))
    } else {
      None
    }
    runs.push({ text, font })
    i = content_start + close_rel + "</font>".length()
  }
  if runs.length() > 0 {
    match runs[0].font {
      None => {
        let base_text = runs[0].text
        let paragraph : Array[RichTextRun] = []
        for run in runs[1:] {
          paragraph.push(run)
        }
        return (base_text, paragraph)
      }
      Some(_) => return ("", runs)
    }
  }
  ("", empty)
}

///|
fn parse_form_controls_vml(
  xml : StringView,
) -> Array[FormControl] raise XlsxError {
  let out : Array[FormControl] = []
  for chunk in xml.to_string().split("<v:shape") {
    if chunk == "" || !chunk.contains("<x:ClientData") {
      continue
    }
    let cd_start = match chunk.find("<x:ClientData") {
      Some(v) => v
      None => continue
    }
    let cd = chunk[cd_start + "<x:ClientData".length():] catch { _ => continue }
    let end_tag = match cd.find(">") {
      Some(v) => v
      None => continue
    }
    let tag = cd[:end_tag] catch { _ => continue }
    let object_type = match attr_value(tag, "ObjectType") {
      Some(v) => v
      None => continue
    }
    if object_type == "Note" {
      continue
    }
    let body = cd[end_tag + 1:] catch { _ => continue }
    let mut row0_opt : Int? = None
    let mut col0_opt : Int? = None
    match extract_xml_text_tag(body, "x:Row") {
      Some(v) =>
        try @strconv.parse_int(v, base=10) catch {
          _ => ()
        } noraise {
          value => row0_opt = Some(value)
        }
      None => ()
    }
    match extract_xml_text_tag(body, "x:Column") {
      Some(v) =>
        try @strconv.parse_int(v, base=10) catch {
          _ => ()
        } noraise {
          value => col0_opt = Some(value)
        }
      None => ()
    }
    let (row0, col0) = match (row0_opt, col0_opt) {
      (Some(r), Some(c)) => (r, c)
      _ =>
        match extract_xml_text_tag(body, "x:Anchor") {
          Some(anchor) => {
            let parts : Array[StringView] = []
            for part in anchor.split(",") {
              parts.push(part)
            }
            if parts.length() < 4 {
              continue
            }
            let col0 = try @strconv.parse_int(parts[0].trim(), base=10) catch {
              _ => continue
            } noraise {
              value => value
            }
            let row0 = try @strconv.parse_int(parts[2].trim(), base=10) catch {
              _ => continue
            } noraise {
              value => value
            }
            (row0, col0)
          }
          None => continue
        }
    }
    let cell = cell_ref_from(row0 + 1, col0 + 1)
    let (textbox_text, paragraph) = parse_vml_textbox(chunk)
    let text = if textbox_text != "" {
      textbox_text
    } else {
      match extract_xml_text_tag(body, "x:Text") {
        Some(v) => v
        None => ""
      }
    }
    let control = FormControl::new(cell, object_type, text~) catch {
      _ => continue
    }
    control.paragraph = paragraph
    match extract_xml_text_tag(body, "x:FmlaMacro") {
      Some(v) => control.macro_name = if v == "" { None } else { Some(v) }
      None => ()
    }
    match extract_xml_text_tag(body, "x:FmlaLink") {
      Some(v) => control.cell_link = if v == "" { None } else { Some(v) }
      None => ()
    }
    match extract_xml_text_tag(body, "x:Val") {
      Some(v) => {
        let n = @strconv.parse_int(v.trim(), base=10) catch { _ => 0 }
        if n >= 0 && n <= max_form_control_value {
          control.current_val = Some(n)
        }
      }
      None => ()
    }
    match extract_xml_text_tag(body, "x:Min") {
      Some(v) => {
        let n = @strconv.parse_int(v.trim(), base=10) catch { _ => 0 }
        if n >= 0 && n <= max_form_control_value {
          control.min_val = Some(n)
        }
      }
      None => ()
    }
    match extract_xml_text_tag(body, "x:Max") {
      Some(v) => {
        let n = @strconv.parse_int(v.trim(), base=10) catch { _ => 0 }
        if n >= 0 && n <= max_form_control_value {
          control.max_val = Some(n)
        }
      }
      None => ()
    }
    match extract_xml_text_tag(body, "x:Inc") {
      Some(v) => {
        let n = @strconv.parse_int(v.trim(), base=10) catch { _ => 0 }
        if n >= 0 && n <= max_form_control_value {
          control.inc_change = Some(n)
        }
      }
      None => ()
    }
    match extract_xml_text_tag(body, "x:Page") {
      Some(v) => {
        let n = @strconv.parse_int(v.trim(), base=10) catch { _ => 0 }
        if n >= 0 && n <= max_form_control_value {
          control.page_change = Some(n)
        }
      }
      None => ()
    }
    if xml_has_tag(body, "x:Horiz") {
      control.horizontally = Some(true)
    }
    match extract_xml_text_tag(body, "x:PrintObject") {
      Some(v) => {
        let s = v.trim().to_lower()
        if s == "false" || s == "0" {
          control.format.print_object = Some(false)
        } else if s == "true" || s == "1" {
          control.format.print_object = Some(true)
        }
      }
      None => ()
    }
    if xml_has_tag(body, "x:MoveWithCells") &&
      xml_has_tag(body, "x:SizeWithCells") {
      control.format.positioning = Some(PicturePositioning::Absolute)
    } else if xml_has_tag(body, "x:SizeWithCells") {
      control.format.positioning = Some(PicturePositioning::OneCell)
    }
    match extract_xml_text_tag(body, "x:Checked") {
      Some(v) => control.checked = Some(v.trim() != "" && v.trim() != "0")
      None => ()
    }
    out.push(control)
  }
  out
}

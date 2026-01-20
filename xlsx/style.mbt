///|
pub enum NumberFormat {
  Builtin(Int)
  Custom(String)
}

///|
pub struct Style {
  number_format : NumberFormat?
}

///|
pub fn Style::new() -> Style {
  { number_format: None }
}

///|
pub fn Style::number_format(format_code : String) -> Style {
  { number_format: Some(NumberFormat::Custom(format_code)) }
}

///|
pub fn Style::builtin_number_format(id : Int) -> Style {
  { number_format: Some(NumberFormat::Builtin(id)) }
}

///|
fn write_styles_xml(styles : ArrayView[Style]) -> String {
  let style_list : Array[Style] = []
  for style in styles {
    style_list.push(style)
  }
  if style_list.length() == 0 {
    style_list.push(Style::new())
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
  let base_block =
    #|  <fonts count="1">
    #|    <font>
    #|      <sz val="11"/>
    #|      <color theme="1"/>
    #|      <name val="Calibri"/>
    #|      <family val="2"/>
    #|      <scheme val="minor"/>
    #|    </font>
    #|  </fonts>
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
    sb.write_view(
      "    <xf numFmtId=\"\{num_fmt_id}\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"",
    )
    if apply {
      sb.write_view(" applyNumberFormat=\"1\"")
    }
    sb.write_view("/>\n")
  }
  let tail_block =
    #|  </cellXfs>
    #|  <cellStyles count="1">
    #|    <cellStyle name="Normal" xfId="0" builtinId="0"/>
    #|  </cellStyles>
    #|  <dxfs count="0"/>
    #|  <tableStyles count="0" defaultTableStyle="TableStyleMedium9" defaultPivotStyle="PivotStyleLight16"/>
    #|</styleSheet>
  sb.write_view(tail_block)
  sb.to_string()
}

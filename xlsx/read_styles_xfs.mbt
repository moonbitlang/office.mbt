///|
fn parse_num_fmts(xml : StringView) -> Map[Int, String] raise XlsxError {
  let num_fmts : Map[Int, String] = {}
  let body = match extract_tag_body(xml, "numFmts") {
    Some(value) => value
    None => return num_fmts
  }
  let mut first = true
  for chunk in body.split("<numFmt ") {
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
          None => raise XlsxError::InvalidXml(msg="numFmt tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="numFmt tag invalid")
      }
    let id_text = match attr_value(tag, "numFmtId") {
      Some(value) => value
      None => continue
    }
    let fmt_text = match attr_value(tag, "formatCode") {
      Some(value) => value
      None => continue
    }
    let id = @strconv.parse_int(id_text, base=10) catch {
      _ => raise XlsxError::InvalidXml(msg="numFmtId invalid")
    }
    num_fmts[id] = unescape_xml_text(fmt_text)
  }
  num_fmts
}

///|
fn parse_cell_xfs(
  xml : StringView,
  num_fmts : Map[Int, String],
  fonts : ArrayView[Font],
  fills : ArrayView[Fill],
  borders : ArrayView[Array[Border]],
) -> Array[Style] raise XlsxError {
  let styles : Array[Style] = []
  let body = match extract_tag_body(xml, "cellXfs") {
    Some(value) => value
    None => {
      styles.push(Style::new())
      return styles
    }
  }
  let mut first = true
  for chunk in body.split("<xf ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let open_end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="xf tag not closed")
    }
    let open_tag = text[:open_end] catch {
        _ => raise XlsxError::InvalidXml(msg="xf tag invalid")
      }
    let self_closing = open_tag.has_suffix("/")
    let tag = if self_closing {
      open_tag[:open_tag.length() - 1] catch {
        _ => raise XlsxError::InvalidXml(msg="xf tag invalid")
      }
    } else {
      open_tag
    }
    let xf_body = if self_closing {
      ""
    } else {
      let rest = text[open_end + 1:] catch {
          _ => raise XlsxError::InvalidXml(msg="xf body invalid")
        }
      let close = match rest.find("</xf>") {
        Some(pos) => pos
        None => raise XlsxError::InvalidXml(msg="xf close missing")
      }
      (rest[:close] catch {
        _ => raise XlsxError::InvalidXml(msg="xf body invalid")
      }).to_string()
    }
    let num_fmt_id = match attr_value(tag, "numFmtId") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="numFmtId invalid")
        }
      None => 0
    }
    let mut style = match num_fmts.get(num_fmt_id) {
      Some(code) => Style::number_format(code)
      None =>
        if num_fmt_id == 0 {
          Style::new()
        } else {
          Style::builtin_number_format(num_fmt_id)
        }
    }
    let font_id = match attr_value(tag, "fontId") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="fontId invalid")
        }
      None => 0
    }
    if font_id > 0 && font_id < fonts.length() {
      style = style.with_font(fonts[font_id])
    }
    let fill_id = match attr_value(tag, "fillId") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="fillId invalid")
        }
      None => 0
    }
    if fill_id > 1 && fill_id < fills.length() {
      style = style.with_fill(fills[fill_id])
    }
    let border_id = match attr_value(tag, "borderId") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="borderId invalid")
        }
      None => 0
    }
    if border_id > 0 && border_id < borders.length() {
      let border = borders[border_id]
      if border.length() > 0 {
        style = style.with_border(border)
      }
    }
    if !self_closing {
      match parse_protection_entry(xf_body) {
        Some(protection) => style = style.with_protection(protection)
        None => ()
      }
      match parse_alignment_entry(xf_body) {
        Some(alignment) => style = style.with_alignment(alignment)
        None => ()
      }
    }
    styles.push(style)
  }
  if styles.length() == 0 {
    styles.push(Style::new())
  }
  styles
}

///|
fn parse_dxfs(
  xml : StringView,
  num_fmts : Map[Int, String],
  fonts : ArrayView[Font],
) -> Array[Style] raise XlsxError {
  let styles : Array[Style] = []
  let xml_str = xml.to_string()
  let open_tag = "<dxfs"
  let start = match xml_str.find(open_tag) {
    Some(pos) => pos
    None => return styles
  }
  let after_start = xml_str[start:] catch {
      _ => raise XlsxError::InvalidXml(msg="dxfs tag out of range")
    }
  let tag_end = match after_start.find(">") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="dxfs tag close missing")
  }
  let tag_text = after_start[:tag_end] catch {
      _ => raise XlsxError::InvalidXml(msg="dxfs tag invalid")
    }
  if tag_text.has_suffix("/") {
    return styles
  }
  let close_tag = "</dxfs>"
  let close_start = match after_start.find(close_tag) {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="dxfs close missing")
  }
  let body = after_start[tag_end + 1:close_start] catch {
      _ => raise XlsxError::InvalidXml(msg="dxfs body invalid")
    }
  let mut first = true
  for chunk in body.split("<dxf") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("</dxf>") {
      Some(pos) => pos
      None =>
        match text.find("/>") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="dxf tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="dxf tag invalid")
      }
    let mut style = match tag_attributes_in(tag, "numFmt") {
      Some(num_fmt_tag) => {
        let num_fmt_id = match attr_value(num_fmt_tag, "numFmtId") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="numFmtId invalid")
            }
          None => 0
        }
        match attr_value(num_fmt_tag, "formatCode") {
          Some(value) => Style::number_format(unescape_xml_text(value))
          None =>
            match num_fmts.get(num_fmt_id) {
              Some(code) => Style::number_format(code)
              None =>
                if num_fmt_id == 0 {
                  Style::new()
                } else {
                  Style::builtin_number_format(num_fmt_id)
                }
            }
        }
      }
      None => Style::new()
    }
    match extract_tag_body(tag, "font") {
      Some(font_body) => {
        let font = parse_font_entry(font_body)
        // Only attach a non-default font. A default font in a dxf is typically redundant.
        if fonts.length() == 0 || font != fonts[0] {
          style = style.with_font(font)
        }
      }
      None => ()
    }
    match extract_tag_body(tag, "fill") {
      Some(fill_body) => {
        let fill = parse_fill_entry(fill_body)
        match fill.typ {
          Some(_) => style = style.with_fill(fill)
          None => ()
        }
      }
      None => ()
    }
    match extract_tag_body(tag, "border") {
      Some(border_body) => {
        let border_tag = match tag_attributes_in(tag, "border") {
          Some(value) => value
          None => "border"
        }
        let border = parse_border_entry(border_tag, border_body)
        if border.length() > 0 {
          style = style.with_border(border)
        }
      }
      None => ()
    }
    match parse_protection_entry(tag) {
      Some(protection) => style = style.with_protection(protection)
      None => ()
    }
    match parse_alignment_entry(tag) {
      Some(alignment) => style = style.with_alignment(alignment)
      None => ()
    }
    styles.push(style)
  }
  styles
}

///|
fn parse_styles(
  xml : StringView,
) -> (Array[Style], Array[Style]) raise XlsxError {
  let num_fmts = parse_num_fmts(xml)
  let fonts = parse_fonts(xml)
  let fills = parse_fills(xml)
  let borders = parse_borders(xml)
  let styles = parse_cell_xfs(xml, num_fmts, fonts, fills, borders)
  let conditional_styles = parse_dxfs(xml, num_fmts, fonts)
  (styles, conditional_styles)
}


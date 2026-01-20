///|
fn decode_utf8(bytes : Bytes) -> String raise XlsxError {
  @encoding/utf8.decode(bytes) catch {
    _ => raise XlsxError::InvalidXml(msg="invalid utf8")
  }
}

///|
fn parse_workbook_sheets(xml : StringView) -> Array[String] raise XlsxError {
  let names : Array[String] = []
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
    match attr_value(tag, "name") {
      Some(value) => names.push(unescape_xml_text(value))
      None => raise XlsxError::InvalidXml(msg="sheet name missing")
    }
  }
  names
}

///|
fn parse_shared_strings(xml : StringView) -> Array[String] {
  let values : Array[String] = []
  let mut first = true
  for chunk in xml.to_string().split("<t>") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    match text.find("</t>") {
      Some(end) => values.push(unescape_xml_text(try! text[:end]))
      None => ()
    }
  }
  values
}

///|
fn extract_tag_body(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let xml_str = xml.to_string()
  let open_tag = "<\{tag_name.to_string()}"
  let close_tag = "</\{tag_name.to_string()}>"
  let start = match xml_str.find(open_tag) {
    Some(pos) => pos
    None => return None
  }
  let after_start = xml_str[start:] catch {
      _ => raise XlsxError::InvalidXml(msg="tag slice invalid")
    }
  let open_end_rel = match after_start.find(">") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="tag open not closed")
  }
  let body_start = start + open_end_rel + 1
  let end = match xml_str.find(close_tag) {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="tag close missing")
  }
  let body = xml_str[body_start:end] catch {
      _ => raise XlsxError::InvalidXml(msg="tag body invalid")
    }
  Some(body.to_string())
}

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
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="xf tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="xf tag invalid")
      }
    let num_fmt_id = match attr_value(tag, "numFmtId") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="numFmtId invalid")
        }
      None => 0
    }
    let style = match num_fmts.get(num_fmt_id) {
      Some(code) => Style::number_format(code)
      None =>
        if num_fmt_id == 0 {
          Style::new()
        } else {
          Style::builtin_number_format(num_fmt_id)
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
fn parse_styles(xml : StringView) -> Array[Style] raise XlsxError {
  let num_fmts = parse_num_fmts(xml)
  parse_cell_xfs(xml, num_fmts)
}

///|
fn parse_worksheet(
  xml : StringView,
  shared_strings : Array[String],
  style_count : Int,
) -> Array[Cell] raise XlsxError {
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
    let formula = match rest.find("<f>") {
      Some(pos) => {
        let f_rest = try! rest[pos + 3:]
        let f_end = match f_rest.find("</f>") {
          Some(end) => end
          None => raise XlsxError::InvalidXml(msg="formula not closed")
        }
        Some(unescape_xml_text(try! f_rest[:f_end]))
      }
      None => None
    }
    let raw_value = match rest.find("<v>") {
      Some(pos) => {
        let v_rest = try! rest[pos + 3:]
        let v_end = match v_rest.find("</v>") {
          Some(end) => end
          None => raise XlsxError::InvalidXml(msg="cell value not closed")
        }
        try! v_rest[:v_end]
      }
      None =>
        match formula {
          Some(_) => ""
          None => raise XlsxError::InvalidXml(msg="cell value missing")
        }
    }
    let value = match cell_type {
      Some(kind) if kind == "s" && formula is None => {
        let index = @strconv.parse_int(raw_value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="shared string index invalid")
        }
        if index < 0 || index >= shared_strings.length() {
          raise XlsxError::InvalidSharedString(index~)
        }
        shared_strings[index]
      }
      _ => unescape_xml_text(raw_value)
    }
    let (row, col) = cell_ref_to_rc(ref_value)
    let canonical = cell_ref_from(row, col)
    cells.push({ reference: canonical, row, col, value, formula, style_id })
  }
  cells
}

///|
pub fn read(bytes : BytesView) -> Workbook raise XlsxError {
  let archive = @zip.read(bytes) catch {
    err => raise XlsxError::UnsupportedFeature(msg=err.to_string())
  }
  let workbook_bytes = match archive.get("xl/workbook.xml") {
    Some(value) => value
    None => raise XlsxError::MissingPart(path="xl/workbook.xml")
  }
  let workbook_xml = decode_utf8(workbook_bytes)
  let sheet_names = parse_workbook_sheets(workbook_xml)
  let shared_strings = match archive.get("xl/sharedStrings.xml") {
    Some(value) => parse_shared_strings(decode_utf8(value))
    None => []
  }
  let styles = match archive.get("xl/styles.xml") {
    Some(value) => parse_styles(decode_utf8(value))
    None => [Style::new()]
  }
  let style_count = styles.length()
  let workbook : Workbook = { sheets: [], styles }
  for i, name in sheet_names {
    let sheet_path = "xl/worksheets/sheet\{i + 1}.xml"
    let sheet_bytes = match archive.get(sheet_path) {
      Some(value) => value
      None => raise XlsxError::MissingPart(path=sheet_path)
    }
    let sheet_xml = decode_utf8(sheet_bytes)
    let cells = parse_worksheet(sheet_xml, shared_strings, style_count)
    workbook.sheets.push({
      name,
      cells,
      images: [],
      charts: [],
      data_validations: [],
      conditional_formats: [],
    })
  }
  workbook
}

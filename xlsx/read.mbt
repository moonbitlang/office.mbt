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
fn parse_worksheet(
  xml : StringView,
  shared_strings : Array[String],
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
    cells.push({ reference: canonical, row, col, value, formula })
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
  let workbook = Workbook::new()
  for i, name in sheet_names {
    let sheet_path = "xl/worksheets/sheet\{i + 1}.xml"
    let sheet_bytes = match archive.get(sheet_path) {
      Some(value) => value
      None => raise XlsxError::MissingPart(path=sheet_path)
    }
    let sheet_xml = decode_utf8(sheet_bytes)
    let cells = parse_worksheet(sheet_xml, shared_strings)
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

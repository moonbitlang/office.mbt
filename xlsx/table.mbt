///|
pub struct Table {
  id : Int
  name : String
  display_name : String
  range_ref : String
  columns : Array[String]
  style_name : String
}

///|
pub fn Table::new(
  name : String,
  range_ref : String,
  columns : ArrayView[String],
  display_name? : String = "",
  style_name? : String = "TableStyleMedium9",
) -> Table raise XlsxError {
  if name == "" {
    raise XlsxError::InvalidTable(msg="table name is empty")
  }
  let display = if display_name == "" { name } else { display_name }
  let style = if style_name == "" { "TableStyleMedium9" } else { style_name }
  let normalized_ref = normalize_range_ref(range_ref)
  let (_min_row, min_col, _max_row, max_col) = parse_range_ref(range_ref)
  let expected_cols = max_col - min_col + 1
  let column_names : Array[String] = []
  for column in columns {
    column_names.push(column)
  }
  if column_names.length() == 0 {
    raise XlsxError::InvalidTable(msg="table columns empty")
  }
  if column_names.length() != expected_cols {
    raise XlsxError::InvalidTable(msg="table columns do not match range")
  }
  {
    id: 0,
    name,
    display_name: display,
    range_ref: normalized_ref,
    columns: column_names,
    style_name: style,
  }
}

///|
fn write_table_xml(table_id : Int, table : Table) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<table xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" id=\"\{table_id}\" name=\"",
  )
  sb.write_view(escape_xml_attr(table.name))
  sb.write_view("\" displayName=\"")
  sb.write_view(escape_xml_attr(table.display_name))
  sb.write_view("\" ref=\"")
  sb.write_view(escape_xml_attr(table.range_ref))
  sb.write_view("\" totalsRowShown=\"0\">\n")
  sb.write_view("  <autoFilter ref=\"")
  sb.write_view(escape_xml_attr(table.range_ref))
  sb.write_view("\"/>\n")
  sb.write_view("  <tableColumns count=\"\{table.columns.length()}\">\n")
  for i, name in table.columns {
    let id = i + 1
    sb.write_view("    <tableColumn id=\"\{id}\" name=\"")
    sb.write_view(escape_xml_attr(name))
    sb.write_view("\"/>\n")
  }
  sb.write_view("  </tableColumns>\n")
  sb.write_view("  <tableStyleInfo name=\"")
  sb.write_view(escape_xml_attr(table.style_name))
  sb.write_view(
    "\" showFirstColumn=\"0\" showLastColumn=\"0\" showRowStripes=\"1\" showColumnStripes=\"0\"/>\n",
  )
  sb.write_view("</table>")
  sb.to_string()
}

///|
fn parse_table_columns(xml : StringView) -> Array[String] raise XlsxError {
  let columns : Array[String] = []
  let body = match extract_tag_body(xml, "tableColumns") {
    Some(value) => value
    None => raise XlsxError::InvalidTable(msg="table columns missing")
  }
  let mut first = true
  for chunk in body.split("<tableColumn ") {
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
          None => raise XlsxError::InvalidXml(msg="tableColumn tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="tableColumn tag invalid")
      }
    let name = match attr_value(tag, "name") {
      Some(value) => value
      None => raise XlsxError::InvalidTable(msg="table column name missing")
    }
    columns.push(unescape_xml_text(name))
  }
  columns
}

///|
fn parse_table_style(xml : StringView) -> String raise XlsxError {
  let text = xml.to_string()
  let start = match text.find("<tableStyleInfo ") {
    Some(pos) => pos
    None => return "TableStyleMedium9"
  }
  let rest = text[start:] catch { _ => return "TableStyleMedium9" }
  let end = match rest.find("/>") {
    Some(pos) => pos
    None =>
      match rest.find(">") {
        Some(pos) => pos
        None => return "TableStyleMedium9"
      }
  }
  let tag = rest[:end] catch { _ => return "TableStyleMedium9" }
  match attr_value(tag, "name") {
    Some(value) => unescape_xml_text(value)
    None => "TableStyleMedium9"
  }
}

///|
fn parse_table_xml(xml : StringView) -> Table raise XlsxError {
  let text = xml.to_string()
  let start = match text.find("<table ") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="table tag missing")
  }
  let rest = text[start:] catch {
      _ => raise XlsxError::InvalidXml(msg="table tag invalid")
    }
  let end = match rest.find(">") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="table tag not closed")
  }
  let tag = rest[:end] catch {
      _ => raise XlsxError::InvalidXml(msg="table tag invalid")
    }
  let id = match attr_value(tag, "id") {
    Some(value) =>
      @strconv.parse_int(value, base=10) catch {
        _ => raise XlsxError::InvalidXml(msg="table id invalid")
      }
    None => raise XlsxError::InvalidXml(msg="table id missing")
  }
  let name = match attr_value(tag, "name") {
    Some(value) => unescape_xml_text(value)
    None =>
      match attr_value(tag, "displayName") {
        Some(value) => unescape_xml_text(value)
        None => raise XlsxError::InvalidXml(msg="table name missing")
      }
  }
  let display_name = match attr_value(tag, "displayName") {
    Some(value) => unescape_xml_text(value)
    None => name
  }
  let ref_value = match attr_value(tag, "ref") {
    Some(value) => unescape_xml_text(value)
    None => raise XlsxError::InvalidXml(msg="table ref missing")
  }
  let columns = parse_table_columns(xml)
  let (_min_row, min_col, _max_row, max_col) = parse_range_ref(ref_value)
  let expected_cols = max_col - min_col + 1
  if columns.length() != expected_cols {
    raise XlsxError::InvalidTable(msg="table columns do not match range")
  }
  {
    id,
    name,
    display_name,
    range_ref: normalize_range_ref(ref_value),
    columns,
    style_name: parse_table_style(xml),
  }
}

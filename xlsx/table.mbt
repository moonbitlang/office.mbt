///|
pub struct Table {
  id : Int
  name : String
  display_name : String
  range_ref : String
  columns : Array[String]
  style_name : String
  show_first_column : Bool
  show_last_column : Bool
  show_row_stripes : Bool
  show_column_stripes : Bool
  show_header_row : Bool
}

///|
pub(all) struct TableOptions {
  range_ref : String
  mut name : String
  mut style_name : String
  mut show_first_column : Bool
  mut show_last_column : Bool
  mut show_row_stripes : Bool?
  mut show_column_stripes : Bool
  mut show_header_row : Bool?
} derive(Eq, Show)

///|
pub fn TableOptions::new(range_ref : String) -> TableOptions raise XlsxError {
  if range_ref == "" {
    raise XlsxError::InvalidTable(msg="table range empty")
  }
  ignore(parse_range_ref(normalize_range_ref(range_ref)))
  {
    range_ref: normalize_range_ref(range_ref),
    name: "",
    style_name: "",
    show_first_column: false,
    show_last_column: false,
    show_row_stripes: None,
    show_column_stripes: false,
    show_header_row: None,
  }
}

///|
pub fn TableOptions::set_name(self : TableOptions, name : String) -> Unit {
  self.name = name
}

///|
pub fn TableOptions::set_style_name(
  self : TableOptions,
  style_name : String,
) -> Unit {
  self.style_name = style_name
}

///|
pub fn TableOptions::set_show_first_column(
  self : TableOptions,
  value : Bool,
) -> Unit {
  self.show_first_column = value
}

///|
pub fn TableOptions::set_show_last_column(
  self : TableOptions,
  value : Bool,
) -> Unit {
  self.show_last_column = value
}

///|
pub fn TableOptions::set_show_row_stripes(
  self : TableOptions,
  value : Bool?,
) -> Unit {
  self.show_row_stripes = value
}

///|
pub fn TableOptions::set_show_column_stripes(
  self : TableOptions,
  value : Bool,
) -> Unit {
  self.show_column_stripes = value
}

///|
pub fn TableOptions::set_show_header_row(
  self : TableOptions,
  value : Bool?,
) -> Unit {
  self.show_header_row = value
}

///|
pub fn Table::new(
  name : String,
  range_ref : String,
  columns : ArrayView[String],
  display_name? : String = "",
  style_name? : String = "TableStyleMedium9",
  show_first_column? : Bool = false,
  show_last_column? : Bool = false,
  show_row_stripes? : Bool = true,
  show_column_stripes? : Bool = false,
  show_header_row? : Bool = true,
) -> Table raise XlsxError {
  if name == "" {
    raise XlsxError::InvalidTable(msg="table name is empty")
  }
  let display = if display_name == "" { name } else { display_name }
  let style = if style_name == "" { "TableStyleMedium9" } else { style_name }
  let normalized_input_ref = normalize_range_ref(range_ref)
  let (min_row, min_col, max_row, max_col) = parse_range_ref(
    normalized_input_ref,
  )
  let normalized_ref = if show_header_row {
    normalized_input_ref
  } else {
    let adjusted_max_row = if min_row == max_row {
      max_row + 1
    } else {
      max_row
    }
    normalize_range_ref(
      "\{cell_ref_from(min_row + 1, min_col)}:\{cell_ref_from(adjusted_max_row, max_col)}",
    )
  }
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
    show_first_column,
    show_last_column,
    show_row_stripes,
    show_column_stripes,
    show_header_row,
  }
}

///|
fn write_table_xml(table_id : Int, table : Table) -> String {
  fn bool_attr(value : Bool) -> String {
    if value {
      "1"
    } else {
      "0"
    }
  }

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
  if !table.show_header_row {
    sb.write_view("\" headerRowCount=\"0\" totalsRowShown=\"0\">\n")
  } else {
    sb.write_view("\" totalsRowShown=\"0\">\n")
    sb.write_view("  <autoFilter ref=\"")
    sb.write_view(escape_xml_attr(table.range_ref))
    sb.write_view("\"/>\n")
  }
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
    "\" showFirstColumn=\"\{bool_attr(table.show_first_column)}\" showLastColumn=\"\{bool_attr(table.show_last_column)}\" showRowStripes=\"\{bool_attr(table.show_row_stripes)}\" showColumnStripes=\"\{bool_attr(table.show_column_stripes)}\"/>\n",
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
fn parse_table_style(
  xml : StringView,
) -> (String, Bool, Bool, Bool, Bool) raise XlsxError {
  fn parse_bool_attr(value : StringView) -> Bool {
    match value.to_string() {
      "1" => true
      "true" => true
      "TRUE" => true
      _ => false
    }
  }

  let text = xml.to_string()
  let start = match text.find("<tableStyleInfo ") {
    Some(pos) => pos
    None => return ("TableStyleMedium9", false, false, true, false)
  }
  let rest = text[start:] catch {
      _ => return ("TableStyleMedium9", false, false, true, false)
    }
  let end = match rest.find("/>") {
    Some(pos) => pos
    None =>
      match rest.find(">") {
        Some(pos) => pos
        None => return ("TableStyleMedium9", false, false, true, false)
      }
  }
  let tag = rest[:end] catch {
      _ => return ("TableStyleMedium9", false, false, true, false)
    }
  let style_name = match attr_value(tag, "name") {
    Some(value) => unescape_xml_text(value)
    None => "TableStyleMedium9"
  }
  let show_first_column = match attr_value(tag, "showFirstColumn") {
    Some(value) => parse_bool_attr(value)
    None => false
  }
  let show_last_column = match attr_value(tag, "showLastColumn") {
    Some(value) => parse_bool_attr(value)
    None => false
  }
  let show_row_stripes = match attr_value(tag, "showRowStripes") {
    Some(value) => parse_bool_attr(value)
    None => true
  }
  let show_column_stripes = match attr_value(tag, "showColumnStripes") {
    Some(value) => parse_bool_attr(value)
    None => false
  }
  (
    style_name, show_first_column, show_last_column, show_row_stripes, show_column_stripes,
  )
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
  let show_header_row = match attr_value(tag, "headerRowCount") {
    Some(value) => value.to_string() != "0"
    None => true
  }
  let columns = parse_table_columns(xml)
  let (_min_row, min_col, _max_row, max_col) = parse_range_ref(ref_value)
  let expected_cols = max_col - min_col + 1
  if columns.length() != expected_cols {
    raise XlsxError::InvalidTable(msg="table columns do not match range")
  }
  let (
    style_name,
    show_first_column,
    show_last_column,
    show_row_stripes,
    show_column_stripes,
  ) = parse_table_style(xml)
  {
    id,
    name,
    display_name,
    range_ref: normalize_range_ref(ref_value),
    columns,
    style_name,
    show_first_column,
    show_last_column,
    show_row_stripes,
    show_column_stripes,
    show_header_row,
  }
}

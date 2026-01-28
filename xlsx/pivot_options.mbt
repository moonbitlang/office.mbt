///|
pub(all) struct PivotTableField {
  data : String
  name : String
  subtotal : String
  num_fmt : Int
  compact : Bool
  outline : Bool
  show_all : Bool
  insert_blank_row : Bool
  default_subtotal : Bool
} derive(Eq, Show)

///|
pub fn PivotTableField::new(data : String) -> PivotTableField raise XlsxError {
  if data == "" {
    raise XlsxError::InvalidPivotTable(msg="pivot field data empty")
  }
  {
    data,
    name: "",
    subtotal: "Sum",
    num_fmt: 0,
    compact: false,
    outline: false,
    show_all: false,
    insert_blank_row: false,
    default_subtotal: false,
  }
}

///|
pub(all) struct PivotTableOptions {
  data_range : String
  pivot_table_range : String
  name : String
  rows : Array[PivotTableField]
  columns : Array[PivotTableField]
  data : Array[PivotTableField]
  filter : Array[PivotTableField]
  row_grand_totals : Bool
  col_grand_totals : Bool
  show_drill : Bool
  classic_layout : Bool
  show_row_headers : Bool
  show_col_headers : Bool
  show_row_stripes : Bool
  show_col_stripes : Bool
  show_last_column : Bool
  pivot_table_style_name : String
} derive(Eq, Show)

///|
pub fn PivotTableOptions::new(
  data_range : String,
  pivot_table_range : String,
) -> PivotTableOptions raise XlsxError {
  if data_range == "" {
    raise XlsxError::InvalidPivotTable(msg="pivot data range empty")
  }
  if pivot_table_range == "" {
    raise XlsxError::InvalidPivotTable(msg="pivot table range empty")
  }
  {
    data_range,
    pivot_table_range,
    name: "",
    rows: [],
    columns: [],
    data: [],
    filter: [],
    row_grand_totals: true,
    col_grand_totals: true,
    show_drill: true,
    classic_layout: false,
    show_row_headers: true,
    show_col_headers: true,
    show_row_stripes: true,
    show_col_stripes: false,
    show_last_column: false,
    pivot_table_style_name: "PivotStyleLight16",
  }
}

///|
fn split_sheet_range(value : StringView) -> (String, String) raise XlsxError {
  let text = value.to_string()
  match text.find("!") {
    Some(pos) => {
      if pos <= 0 || pos + 1 >= text.length() {
        raise XlsxError::InvalidPivotTable(msg="range must be Sheet!A1:B2")
      }
      let sheet = text[:pos] catch {
          _ => raise XlsxError::InvalidPivotTable(msg="range sheet invalid")
        }
      let range_ref = text[pos + 1:] catch {
          _ => raise XlsxError::InvalidPivotTable(msg="range ref invalid")
        }
      (sheet.to_string(), range_ref.to_string())
    }
    None => raise XlsxError::InvalidPivotTable(msg="range must be Sheet!A1:B2")
  }
}

///|
fn write_pivot_cache_definition_xml(
  data_sheet : String,
  data_ref : String,
  fields : ArrayView[String],
) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<pivotCacheDefinition xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" refreshOnLoad=\"1\" saveData=\"0\">\n",
  )
  sb.write_view("  <cacheSource type=\"worksheet\">\n")
  sb.write_view("    <worksheetSource ref=\"")
  sb.write_view(escape_xml_attr(data_ref))
  sb.write_view("\" sheet=\"")
  sb.write_view(escape_xml_attr(data_sheet))
  sb.write_view("\"/>\n")
  sb.write_view("  </cacheSource>\n")
  sb.write_view("  <cacheFields count=\"\{fields.length()}\">\n")
  for name in fields {
    sb.write_view("    <cacheField name=\"")
    sb.write_view(escape_xml_attr(name))
    sb.write_view("\">\n")
    sb.write_view("      <sharedItems containsBlank=\"1\"><m/></sharedItems>\n")
    sb.write_view("    </cacheField>\n")
  }
  sb.write_view("  </cacheFields>\n")
  sb.write_view("</pivotCacheDefinition>")
  sb.to_string()
}

///|
fn write_pivot_table_definition_xml(
  name : String,
  cache_id : Int,
  pivot_ref : String,
  field_names : ArrayView[String],
  row_fields : ArrayView[Int],
  col_fields : ArrayView[Int],
  page_fields : ArrayView[Int],
  data_fields : ArrayView[(Int, PivotTableField)],
  opts : PivotTableOptions,
) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<pivotTableDefinition xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" name=\"",
  )
  sb.write_view(escape_xml_attr(name))
  sb.write_view("\" cacheId=\"\{cache_id}\"")
  sb.write_view(">\n")
  sb.write_view("  <location ref=\"")
  sb.write_view(escape_xml_attr(pivot_ref))
  sb.write_view(
    "\" firstHeaderRow=\"1\" firstDataRow=\"2\" firstDataCol=\"1\"/>\n",
  )
  sb.write_view("  <pivotFields count=\"\{field_names.length()}\">\n")
  for i, _fname in field_names {
    sb.write_view("    <pivotField")
    if row_fields.contains(i) {
      sb.write_view(" axis=\"axisRow\"")
    } else if col_fields.contains(i) {
      sb.write_view(" axis=\"axisCol\"")
    } else if page_fields.contains(i) {
      sb.write_view(" axis=\"axisPage\"")
    }
    sb.write_view(" showAll=\"0\"/>\n")
  }
  sb.write_view("  </pivotFields>\n")
  sb.write_view("  <rowFields count=\"\{row_fields.length()}\">\n")
  for idx in row_fields {
    sb.write_view("    <field x=\"\{idx}\"/>\n")
  }
  sb.write_view("  </rowFields>\n")
  sb.write_view("  <colFields count=\"\{col_fields.length()}\">\n")
  for idx in col_fields {
    sb.write_view("    <field x=\"\{idx}\"/>\n")
  }
  sb.write_view("  </colFields>\n")
  sb.write_view("  <pageFields count=\"\{page_fields.length()}\">\n")
  for idx in page_fields {
    sb.write_view("    <pageField fld=\"\{idx}\"/>\n")
  }
  sb.write_view("  </pageFields>\n")
  sb.write_view("  <dataFields count=\"\{data_fields.length()}\">\n")
  for entry in data_fields {
    let (idx, field) = entry
    sb.write_view("    <dataField fld=\"\{idx}\"")
    let data_name = if field.name == "" { field.data } else { field.name }
    sb.write_view(" name=\"")
    sb.write_view(escape_xml_attr(data_name))
    sb.write_view("\" subtotal=\"")
    sb.write_view(escape_xml_attr(field.subtotal.to_lower()))
    sb.write_view("\"/>\n")
  }
  sb.write_view("  </dataFields>\n")
  sb.write_view("  <pivotTableStyleInfo name=\"")
  sb.write_view(escape_xml_attr(opts.pivot_table_style_name))
  sb.write_view("\" showRowHeaders=\"\{bool_attr(opts.show_row_headers)}\"")
  sb.write_view(" showColHeaders=\"\{bool_attr(opts.show_col_headers)}\"")
  sb.write_view(" showRowStripes=\"\{bool_attr(opts.show_row_stripes)}\"")
  sb.write_view(" showColStripes=\"\{bool_attr(opts.show_col_stripes)}\"")
  sb.write_view(" showLastColumn=\"\{bool_attr(opts.show_last_column)}\"/>\n")
  sb.write_view("</pivotTableDefinition>")
  sb.to_string()
}

///|
pub(all) struct PivotTableField {
  data : String
  mut name : String
  mut subtotal : String
  mut num_fmt : Int
  mut compact : Bool
  mut outline : Bool
  mut show_all : Bool
  mut insert_blank_row : Bool
  mut default_subtotal : Bool
} derive(Eq, Show)

///|
pub fn PivotTableField::new(data : String) -> PivotTableField raise XlsxError {
  if data == "" {
    raise InvalidPivotTable(msg="pivot field data empty")
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
  mut name : String
  rows : Array[PivotTableField]
  columns : Array[PivotTableField]
  data : Array[PivotTableField]
  filter : Array[PivotTableField]
  mut row_grand_totals : Bool
  mut col_grand_totals : Bool
  mut show_drill : Bool
  mut use_auto_formatting : Bool
  mut page_over_then_down : Bool
  mut merge_item : Bool
  mut classic_layout : Bool
  mut compact_data : Bool
  mut show_error : Bool
  mut show_row_headers : Bool
  mut show_col_headers : Bool
  mut show_row_stripes : Bool
  mut show_col_stripes : Bool
  mut show_last_column : Bool
  mut field_print_titles : Bool
  mut item_print_titles : Bool
  mut pivot_table_style_name : String
} derive(Eq, Show)

///|
pub fn PivotTableOptions::new(
  data_range : String,
  pivot_table_range : String,
) -> PivotTableOptions raise XlsxError {
  if data_range == "" {
    raise InvalidPivotTable(msg="pivot data range empty")
  }
  if pivot_table_range == "" {
    raise InvalidPivotTable(msg="pivot table range empty")
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
    use_auto_formatting: false,
    page_over_then_down: false,
    merge_item: false,
    classic_layout: false,
    compact_data: false,
    show_error: false,
    show_row_headers: true,
    show_col_headers: true,
    show_row_stripes: true,
    show_col_stripes: false,
    show_last_column: false,
    field_print_titles: false,
    item_print_titles: false,
    pivot_table_style_name: "PivotStyleLight16",
  }
}

///|
fn split_sheet_range(value : StringView) -> (String, String) raise XlsxError {
  let text = value.to_string()
  match text.find("!") {
    Some(pos) => {
      if pos <= 0 || pos + 1 >= text.length() {
        raise InvalidPivotTable(msg="range must be Sheet!A1:B2")
      }
      let sheet = text[:pos] catch {
          _ => raise InvalidPivotTable(msg="range sheet invalid")
        }
      let range_ref = text[pos + 1:] catch {
          _ => raise InvalidPivotTable(msg="range ref invalid")
        }
      (sheet.to_string(), range_ref.to_string())
    }
    None => raise InvalidPivotTable(msg="range must be Sheet!A1:B2")
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
  row_fields : ArrayView[(Int, PivotTableField)],
  col_fields : ArrayView[(Int, PivotTableField)],
  page_fields : ArrayView[(Int, PivotTableField)],
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
  sb.write_view(" dataCaption=\"Values\"")
  sb.write_view(" rowGrandTotals=\"\{bool_attr(opts.row_grand_totals)}\"")
  sb.write_view(" colGrandTotals=\"\{bool_attr(opts.col_grand_totals)}\"")
  sb.write_view(" showDrill=\"\{bool_attr(opts.show_drill)}\"")
  sb.write_view(" useAutoFormatting=\"\{bool_attr(opts.use_auto_formatting)}\"")
  sb.write_view(" pageOverThenDown=\"\{bool_attr(opts.page_over_then_down)}\"")
  sb.write_view(" mergeItem=\"\{bool_attr(opts.merge_item)}\"")
  sb.write_view(" compactData=\"\{bool_attr(opts.compact_data)}\"")
  sb.write_view(" gridDropZones=\"\{bool_attr(opts.classic_layout)}\"")
  sb.write_view(" showError=\"\{bool_attr(opts.show_error)}\"")
  sb.write_view(" fieldPrintTitles=\"\{bool_attr(opts.field_print_titles)}\"")
  sb.write_view(" itemPrintTitles=\"\{bool_attr(opts.item_print_titles)}\"")
  sb.write_view(
    " createdVersion=\"3\" updatedVersion=\"3\" minRefreshableVersion=\"3\"",
  )
  sb.write_view(">\n")
  sb.write_view("  <location ref=\"")
  sb.write_view(escape_xml_attr(pivot_ref))
  sb.write_view(
    "\" firstHeaderRow=\"1\" firstDataRow=\"2\" firstDataCol=\"1\"/>\n",
  )
  let row_opts : Map[Int, PivotTableField] = {}
  for entry in row_fields {
    let (idx, field) = entry
    row_opts[idx] = field
  }
  let col_opts : Map[Int, PivotTableField] = {}
  for entry in col_fields {
    let (idx, field) = entry
    col_opts[idx] = field
  }
  let page_opts : Map[Int, PivotTableField] = {}
  for entry in page_fields {
    let (idx, field) = entry
    page_opts[idx] = field
  }
  let data_opts : Map[Int, PivotTableField] = {}
  for entry in data_fields {
    let (idx, field) = entry
    data_opts[idx] = field
  }
  sb.write_view("  <pivotFields count=\"\{field_names.length()}\">\n")
  for i, _fname in field_names {
    sb.write_view("    <pivotField")
    match row_opts.get(i) {
      Some(field) => {
        let pivot_name = if field.name == "" { field.data } else { field.name }
        sb.write_view(" name=\"")
        sb.write_view(escape_xml_attr(pivot_name))
        sb.write_view("\" axis=\"axisRow\"")
        let compact = if opts.classic_layout { false } else { field.compact }
        let outline = if opts.classic_layout { false } else { field.outline }
        sb.write_view(" compact=\"")
        sb.write_view(bool_attr(compact))
        sb.write_view("\" outline=\"")
        sb.write_view(bool_attr(outline))
        sb.write_view("\" showAll=\"")
        sb.write_view(bool_attr(field.show_all))
        sb.write_view("\" defaultSubtotal=\"")
        sb.write_view(bool_attr(field.default_subtotal))
        sb.write_view("\"")
        if field.insert_blank_row {
          sb.write_view(" insertBlankRow=\"1\"")
        }
        match data_opts.get(i) {
          Some(_) => sb.write_view(" dataField=\"1\"")
          None => ()
        }
        sb.write_view(">")
        if field.default_subtotal {
          sb.write_view("<items count=\"1\"><item t=\"default\"/></items>")
        } else {
          sb.write_view("<items count=\"1\"><item x=\"0\"/></items>")
        }
        sb.write_view("</pivotField>\n")
        continue
      }
      None => ()
    }
    match col_opts.get(i) {
      Some(field) => {
        let pivot_name = if field.name == "" { field.data } else { field.name }
        sb.write_view(" name=\"")
        sb.write_view(escape_xml_attr(pivot_name))
        sb.write_view("\" axis=\"axisCol\"")
        let compact = if opts.classic_layout { false } else { field.compact }
        let outline = if opts.classic_layout { false } else { field.outline }
        sb.write_view(" compact=\"")
        sb.write_view(bool_attr(compact))
        sb.write_view("\" outline=\"")
        sb.write_view(bool_attr(outline))
        sb.write_view("\" showAll=\"")
        sb.write_view(bool_attr(field.show_all))
        sb.write_view("\" defaultSubtotal=\"")
        sb.write_view(bool_attr(field.default_subtotal))
        sb.write_view("\"")
        if field.insert_blank_row {
          sb.write_view(" insertBlankRow=\"1\"")
        }
        match data_opts.get(i) {
          Some(_) => sb.write_view(" dataField=\"1\"")
          None => ()
        }
        sb.write_view(">")
        if field.default_subtotal {
          sb.write_view("<items count=\"1\"><item t=\"default\"/></items>")
        } else {
          sb.write_view("<items count=\"1\"><item x=\"0\"/></items>")
        }
        sb.write_view("</pivotField>\n")
        continue
      }
      None => ()
    }
    match page_opts.get(i) {
      Some(field) => {
        let pivot_name = if field.name == "" { field.data } else { field.name }
        sb.write_view(" name=\"")
        sb.write_view(escape_xml_attr(pivot_name))
        sb.write_view("\" axis=\"axisPage\"")
        sb.write_view(" showAll=\"")
        sb.write_view(bool_attr(field.show_all))
        sb.write_view("\"")
        match data_opts.get(i) {
          Some(_) => sb.write_view(" dataField=\"1\"")
          None => ()
        }
        sb.write_view(
          "><items count=\"1\"><item t=\"default\"/></items></pivotField>\n",
        )
        continue
      }
      None => ()
    }
    match data_opts.get(i) {
      Some(_) => {
        if opts.classic_layout {
          sb.write_view(" compact=\"0\" outline=\"0\"")
        }
        sb.write_view(" dataField=\"1\" showAll=\"0\"/>\n")
        continue
      }
      None => ()
    }
    if opts.classic_layout {
      sb.write_view(" compact=\"0\" outline=\"0\"")
    }
    sb.write_view(" showAll=\"0\"/>\n")
  }
  sb.write_view("  </pivotFields>\n")
  sb.write_view("  <rowFields count=\"\{row_fields.length()}\">\n")
  for entry in row_fields {
    let (idx, _field) = entry
    sb.write_view("    <field x=\"\{idx}\"/>\n")
  }
  sb.write_view("  </rowFields>\n")
  sb.write_view("  <colFields count=\"\{col_fields.length()}\">\n")
  for entry in col_fields {
    let (idx, _field) = entry
    sb.write_view("    <field x=\"\{idx}\"/>\n")
  }
  sb.write_view("  </colFields>\n")
  sb.write_view("  <pageFields count=\"\{page_fields.length()}\">\n")
  for entry in page_fields {
    let (idx, _field) = entry
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
  sb.write_view("  <rowItems count=\"1\"><i><x/></i></rowItems>\n")
  sb.write_view("  <colItems count=\"1\"><i/></colItems>\n")
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

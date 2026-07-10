// Builds the `xlsx.outline/1` payload: a workbook structure map an agent can
// read before editing — sheets (worksheets and chart sheets, in tab order),
// live extents, and per-sheet object inventories. Deliberately avoids
// materializing cell grids (`get_rows`): everything here is metadata-priced.

///|
/// Builds the `xlsx.outline/1` JSON payload for a workbook. `file~` is
/// echoed into the payload so an agent can correlate output with input.
pub fn outline(
  workbook : @xlsx.Workbook,
  file~ : String,
) -> Json raise @xlsx.XlsxError {
  let names = workbook.get_sheet_list()
  let sheets = []
  for index, name in names {
    sheets.push(sheet_json(workbook, name, index))
  }
  let out : Map[String, Json] = {
    "schema": Json::string(SCHEMA_OUTLINE),
    "file": Json::string(file),
    "sheet_count": Json::number(names.length().to_double()),
  }
  let active_index = workbook.get_active_sheet_index()
  match workbook.get_sheet_name(active_index) {
    Some(active_name) =>
      out["active_sheet"] = Json::object({
        "name": Json::string(active_name),
        "index": Json::number(active_index.to_double()),
      })
    None => ()
  }
  let defined_names = []
  for defined in workbook.get_defined_names() {
    let d : Map[String, Json] = {
      "name": Json::string(defined.name),
      "refers_to": Json::string(defined.refers_to),
    }
    if defined.scope != "" {
      d["scope"] = Json::string(defined.scope)
    }
    if defined.comment != "" {
      d["comment"] = Json::string(defined.comment)
    }
    defined_names.push(Json::object(d))
  }
  out["defined_names"] = Json::array(defined_names)
  out["sheets"] = Json::array(sheets)
  Json::object(out)
}

///|
fn sheet_json(
  workbook : @xlsx.Workbook,
  name : String,
  index : Int,
) -> Json raise @xlsx.XlsxError {
  match find_worksheet(workbook, name) {
    Some(worksheet) => worksheet_json(workbook, worksheet, name, index)
    None =>
      match find_chart_sheet(workbook, name) {
        Some(chart_sheet) => chart_sheet_json(chart_sheet, name, index)
        // A name in the tab order that is neither kind (should not happen);
        // keep the entry so sheet indexes stay aligned with the tab order.
        None =>
          Json::object({
            "kind": Json::string("unknown"),
            "name": Json::string(name),
            "index": Json::number(index.to_double()),
          })
      }
  }
}

///|
fn find_worksheet(workbook : @xlsx.Workbook, name : String) -> @xlsx.Worksheet? {
  for worksheet in workbook.sheets() {
    if worksheet.name() == name {
      return Some(worksheet)
    }
  }
  None
}

///|
fn find_chart_sheet(
  workbook : @xlsx.Workbook,
  name : String,
) -> @xlsx.ChartSheet? {
  for chart_sheet in workbook.chart_sheets {
    if chart_sheet.name() == name {
      return Some(chart_sheet)
    }
  }
  None
}

///|
fn sheet_state_json(state : @xlsx.SheetState) -> Json {
  match state {
    Visible => Json::string("visible")
    Hidden => Json::string("hidden")
    VeryHidden => Json::string("very_hidden")
  }
}

///|
fn worksheet_json(
  workbook : @xlsx.Workbook,
  worksheet : @xlsx.Worksheet,
  name : String,
  index : Int,
) -> Json raise @xlsx.XlsxError {
  let out : Map[String, Json] = {
    "kind": Json::string("worksheet"),
    "name": Json::string(name),
    "index": Json::number(index.to_double()),
    "state": sheet_state_json(worksheet.state),
  }
  // Extents: the retained <dimension> may be stale after mutations (writes
  // prefer the retained value), so live max_row/max_col are authoritative.
  let declared = workbook.get_sheet_dimension(name)
  if declared != "" {
    out["declared_dimension"] = Json::string(declared)
  }
  let max_row = worksheet.max_row()
  let max_col = worksheet.max_col()
  out["max_row"] = Json::number(max_row.to_double())
  out["max_col"] = Json::number(max_col.to_double())
  if max_row > 0 && max_col > 0 {
    out["used_range"] = Json::string(
      "A1:" + @xlsx.coordinates_to_cell_name(max_col, max_row),
    )
  }
  let panes = workbook.get_panes(name)
  if panes.freeze {
    let frozen : Map[String, Json] = {
      "x_split": Json::number(panes.x_split.to_double()),
      "y_split": Json::number(panes.y_split.to_double()),
    }
    if panes.top_left_cell != "" {
      frozen["top_left_cell"] = Json::string(panes.top_left_cell)
    }
    out["frozen"] = Json::object(frozen)
  }
  match workbook.get_auto_filter(name) {
    Some(auto_filter) =>
      out["auto_filter"] = Json::string(auto_filter.range_ref)
    None => ()
  }
  out["merges"] = Json::array(workbook.get_merge_cells(name).map(Json::string))
  let tables = []
  for table in workbook.get_tables(name) {
    tables.push(
      Json::object({
        "name": Json::string(table.name),
        "range": Json::string(table.range_ref),
        "columns": Json::array(table.columns.map(Json::string)),
      }),
    )
  }
  out["tables"] = Json::array(tables)
  let charts = []
  for chart in worksheet.charts() {
    charts.push(chart_json(chart))
  }
  out["charts"] = Json::array(charts)
  let images = []
  for cell in workbook.get_picture_cells(name) {
    for image in workbook.get_pictures(name, cell) {
      let entry : Map[String, Json] = {
        "anchor": Json::string(cell),
        "extension": Json::string(image.extension),
        "content_type": Json::string(image.content_type),
        "width_emu": Json::number(image.width_emu.to_double()),
        "height_emu": Json::number(image.height_emu.to_double()),
      }
      images.push(Json::object(entry))
    }
  }
  out["images"] = Json::array(images)
  let pivot_tables = []
  for pivot in workbook.get_pivot_tables(name) {
    pivot_tables.push(Json::object({ "name": Json::string(pivot.name) }))
  }
  out["pivot_tables"] = Json::array(pivot_tables)
  out["counts"] = Json::object({
    "data_validations": Json::number(
      workbook.get_data_validations(name).length().to_double(),
    ),
    "conditional_format_ranges": Json::number(
      conditional_format_range_count(workbook, name).to_double(),
    ),
    "comments": Json::number(workbook.get_comments(name).length().to_double()),
    "hyperlinks": Json::number(
      workbook.get_hyperlink_cells(name).length().to_double(),
    ),
    "slicers": Json::number(workbook.get_slicers(name).length().to_double()),
  })
  Json::object(out)
}

///|
/// A conditional-format map key is an OOXML `sqref`: one or more
/// space-separated ranges. Count ranges, not keys.
fn conditional_format_range_count(
  workbook : @xlsx.Workbook,
  name : String,
) -> Int raise @xlsx.XlsxError {
  let mut count = 0
  for sqref, _ in workbook.get_conditional_formats(name) {
    for part in sqref.split(" ") {
      if part.length() > 0 {
        count += 1
      }
    }
  }
  count
}

///|
fn chart_sheet_json(
  chart_sheet : @xlsx.ChartSheet,
  name : String,
  index : Int,
) -> Json {
  let chart : Map[String, Json] = {}
  chart_meta_into(chart, chart_sheet.chart_xml())
  Json::object({
    "kind": Json::string("chart_sheet"),
    "name": Json::string(name),
    "index": Json::number(index.to_double()),
    "state": sheet_state_json(chart_sheet.state()),
    "charts": Json::array([Json::object(chart)]),
  })
}

///|
fn chart_json(chart : @xlsx.Chart) -> Json {
  let out : Map[String, Json] = {
    "anchor": Json::string(chart.reference),
    "width_emu": Json::number(chart.width_emu.to_double()),
    "height_emu": Json::number(chart.height_emu.to_double()),
  }
  chart_meta_into(out, chart.xml)
  Json::object(out)
}

///|
/// Adds the scanned `kinds` and `series` keys from chart XML to `out`.
fn chart_meta_into(out : Map[String, Json], xml : String) -> Unit {
  out["kinds"] = Json::array(chart_kinds(xml).map(Json::string))
  let series = []
  for meta in chart_series(xml) {
    let s : Map[String, Json] = {}
    set_string(s, "name", meta.name)
    set_string(s, "categories", meta.categories)
    set_string(s, "values", meta.values)
    series.push(Json::object(s))
  }
  out["series"] = Json::array(series)
}

// Workbook -> self-contained HTML. The renderer walks a BOUNDED window of
// each sheet (never `get_rows`, which materializes whole sheets including
// gap rows), applies effective styles as deduplicated classes, and appends
// non-cell objects (images, chart placeholders, frozen-pane hints) per
// sheet. Every workbook-derived string is escaped; colors enter CSS only
// through strict hex validation (css.mbt).

///|
/// Hard ceiling on rendered cells per sheet; when rows x cols exceeds it,
/// rows are reduced and a truncation marker is emitted.
const MAX_RENDER_CELLS : Int = 262_144

///|
/// Raised when `--sheet` names a sheet the workbook does not have.
pub suberror RenderError {
  SheetNotFound(name~ : String)
} derive(@debug.Debug)

///|
pub impl Show for RenderError with fn output(self, logger) {
  match self {
    SheetNotFound(name~) => logger.write_string("sheet '\{name}' not found")
  }
}

///|
/// Renders the workbook (or one sheet, case-insensitively) to a complete
/// HTML document. `max_rows`/`max_cols` bound the per-sheet window;
/// `calc` evaluates uncached formulas (otherwise they render as their
/// formula text, visually marked).
pub fn render_workbook(
  workbook : @xlsx.Workbook,
  title~ : String,
  sheet? : String = "",
  max_rows? : Int = 1000,
  max_cols? : Int = 256,
  include_images? : Bool = true,
  calc? : Bool = false,
) -> String raise {
  let style_order : Array[Int] = []
  let style_seen : Map[Int, Unit] = Map([])
  let body = StringBuilder()
  let wanted = sheet.to_lower()
  let mut matched = false
  for name in workbook.get_sheet_list() {
    if wanted != "" && name.to_lower() != wanted {
      continue
    }
    matched = true
    match find_worksheet(workbook, name) {
      Some(worksheet) =>
        render_worksheet(
          body, workbook, worksheet, name, max_rows, max_cols, include_images, calc,
          style_order, style_seen,
        )
      None =>
        match find_chart_sheet(workbook, name) {
          Some(chart_sheet) => render_chart_sheet(body, chart_sheet, name)
          None => ()
        }
    }
  }
  if wanted != "" && !matched {
    raise SheetNotFound(name=sheet)
  }
  let head = StringBuilder()
  head.write_string(
    "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n",
  )
  head.write_string("<title>\{escape_html(title)}</title>\n<style>\n")
  head.write_string(
    (
      #|body{font-family:Calibri,Arial,sans-serif;margin:16px}
      #|table{border-collapse:collapse;margin-bottom:8px}
      #|td{border:1px solid #d9d9d9;padding:2px 6px;white-space:pre;font-size:11pt}
      #|h2{font-size:13pt;margin:12px 0 4px}
      #|.formula-pending{color:#888;font-style:italic}
      #|.truncated,.frozen-hint{color:#888;font-size:9pt}
      #|.chart-placeholder{border:1px dashed #999;padding:8px;margin:4px 0;color:#555;font-size:10pt}
      #|figure{margin:4px 0}
    ),
  )
  head.write_string("\n")
  for style_id in style_order {
    let css = style_css(workbook.get_style(style_id))
    if css != "" {
      head.write_string(".s\{style_id}{\{css}}\n")
    }
  }
  head.write_string("</style>\n</head>\n<body>\n")
  head.write_string("<h1>\{escape_html(title)}</h1>\n")
  head.write_string(body.to_string())
  head.write_string("</body>\n</html>\n")
  head.to_string()
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
/// One merged-range anchor: the span to emit at the range's top-left.
priv struct MergeSpan {
  colspan : Int
  rowspan : Int
} derive(@debug.Debug)

///|
fn render_worksheet(
  body : StringBuilder,
  workbook : @xlsx.Workbook,
  worksheet : @xlsx.Worksheet,
  name : String,
  max_rows : Int,
  max_cols : Int,
  include_images : Bool,
  calc : Bool,
  style_order : Array[Int],
  style_seen : Map[Int, Unit],
) -> Unit raise {
  body.write_string("<section data-sheet=\"\{escape_html_attribute(name)}\">\n")
  body.write_string("<h2>\{escape_html(name)}</h2>\n")
  let mut sheet_rows = worksheet.max_row()
  let mut sheet_cols = worksheet.max_col()
  // Merged areas are part of the visible sheet even when they extend past
  // the last stored cell.
  for info in workbook.get_merge_cells_info(name, without_values=true) {
    let end = info.get_end_axis()
    let (c2, r2) = @xlsx.cell_name_to_coordinates(end) catch { _ => continue }
    if r2 > sheet_rows {
      sheet_rows = r2
    }
    if c2 > sheet_cols {
      sheet_cols = c2
    }
  }
  let mut rows = if sheet_rows < max_rows { sheet_rows } else { max_rows }
  let cols = if sheet_cols < max_cols { sheet_cols } else { max_cols }
  if cols > 0 && rows > MAX_RENDER_CELLS / cols {
    rows = MAX_RENDER_CELLS / cols
  }
  if rows == 0 || cols == 0 {
    body.write_string("<p>(empty sheet)</p>\n")
  } else {
    // Merge spans anchored inside the window; covered cells are skipped.
    let spans : Map[String, MergeSpan] = Map([])
    let covered : Map[String, Unit] = Map([])
    collect_merge_spans(workbook, name, rows, cols, spans, covered)
    body.write_string("<table>\n<colgroup>\n")
    for col in 1..<=cols {
      match workbook.get_col_width(name, col) {
        Some(width) =>
          body.write_string("<col style=\"width:\{col_width_px(width)}px\">\n")
        None => body.write_string("<col>\n")
      }
    }
    body.write_string("</colgroup>\n")
    for row in 1..<=rows {
      match workbook.get_row_height(name, row) {
        Some(height) =>
          body.write_string("<tr style=\"height:\{row_height_px(height)}px\">")
        None => body.write_string("<tr>")
      }
      for col in 1..<=cols {
        let key = "\{row}:\{col}"
        if covered.contains(key) {
          continue
        }
        let cell = @xlsx.coordinates_to_cell_name(col, row)
        let span_attrs = match spans.get(key) {
          Some(span) => {
            let mut attrs = ""
            if span.colspan > 1 {
              attrs = attrs + " colspan=\"\{span.colspan}\""
            }
            if span.rowspan > 1 {
              attrs = attrs + " rowspan=\"\{span.rowspan}\""
            }
            attrs
          }
          None => ""
        }
        let style_id = @inspect.effective_style_id(
          workbook,
          name,
          cell,
          row~,
          col~,
        )
        let (text, pending) = cell_text(workbook, name, cell, calc)
        let mut classes = ""
        if style_id != 0 {
          classes = "s\{style_id}"
          if !style_seen.contains(style_id) {
            style_seen[style_id] = ()
            style_order.push(style_id)
          }
        }
        if pending {
          classes = if classes == "" {
            "formula-pending"
          } else {
            classes + " formula-pending"
          }
        }
        let class_attr = if classes == "" {
          ""
        } else {
          " class=\"\{classes}\""
        }
        body.write_string(
          "<td\{class_attr}\{span_attrs}>\{escape_html(text)}</td>",
        )
      }
      body.write_string("</tr>\n")
    }
    body.write_string("</table>\n")
  }
  if sheet_rows > rows || sheet_cols > cols {
    body.write_string(
      "<p class=\"truncated\">showing \{rows} of \{sheet_rows} rows and \{cols} of \{sheet_cols} columns</p>\n",
    )
  }
  render_sheet_objects(body, workbook, worksheet, name, include_images)
  body.write_string("</section>\n")
}

///|
/// The display text of one cell plus whether it is an unevaluated
/// formula. Order: stored (cached, formatted) value; else the evaluated
/// result when `calc`; else the formula text, marked pending.
fn cell_text(
  workbook : @xlsx.Workbook,
  name : String,
  cell : String,
  calc : Bool,
) -> (String, Bool) raise {
  let cached = match workbook.get_cell_value_raw(name, cell) {
    Some(String("")) => None
    other => other
  }
  if cached is Some(_) {
    return (workbook.get_cell_value(name, cell).unwrap_or(""), false)
  }
  match workbook.get_cell_formula(name, cell) {
    Some(formula) => {
      if calc {
        let value = workbook.calc_cell_value(name, cell) catch {
          _ => return ("=" + formula, true)
        }
        return (value, false)
      }
      ("=" + formula, true)
    }
    None => ("", false)
  }
}

///|
fn collect_merge_spans(
  workbook : @xlsx.Workbook,
  name : String,
  rows : Int,
  cols : Int,
  spans : Map[String, MergeSpan],
  covered : Map[String, Unit],
) -> Unit raise {
  for info in workbook.get_merge_cells_info(name, without_values=true) {
    let start = info.get_start_axis()
    let end = info.get_end_axis()
    let (c1, r1) = @xlsx.cell_name_to_coordinates(start) catch { _ => continue }
    let (c2, r2) = @xlsx.cell_name_to_coordinates(end) catch { _ => continue }
    if r1 > rows || c1 > cols {
      continue
    }
    let r_hi = if r2 < rows { r2 } else { rows }
    let c_hi = if c2 < cols { c2 } else { cols }
    spans["\{r1}:\{c1}"] = { colspan: c_hi - c1 + 1, rowspan: r_hi - r1 + 1 }
    for r in r1..<=r_hi {
      for c in c1..<=c_hi {
        if r != r1 || c != c1 {
          covered["\{r}:\{c}"] = ()
        }
      }
    }
  }
}

///|
fn render_sheet_objects(
  body : StringBuilder,
  workbook : @xlsx.Workbook,
  worksheet : @xlsx.Worksheet,
  name : String,
  include_images : Bool,
) -> Unit raise {
  let objects = StringBuilder()
  if include_images {
    for cell in workbook.get_picture_cells(name) {
      for image in workbook.get_pictures(name, cell) {
        let mime = escape_html_attribute(image.content_type)
        let data = @base64.encode(image.data)
        objects.write_string(
          "<figure class=\"image\" data-anchor=\"\{escape_html_attribute(cell)}\"><img src=\"data:\{mime};base64,\{data}\" alt=\"\{escape_html_attribute(image.alt_text)}\"></figure>\n",
        )
      }
    }
  }
  for chart in worksheet.charts() {
    objects.write_string(chart_placeholder(chart.xml, anchor=chart.reference))
  }
  let panes = workbook.get_panes(name)
  if panes.freeze {
    objects.write_string(
      "<p class=\"frozen-hint\">frozen panes: \{panes.y_split} row(s), \{panes.x_split} column(s)</p>\n",
    )
  }
  let rendered = objects.to_string()
  if rendered != "" {
    body.write_string("<div class=\"sheet-objects\">\n\{rendered}</div>\n")
  }
}

///|
/// A visible stand-in for a chart: its plot kinds and series ranges (from
/// the metadata scanner) — enough for an agent to know what is there.
/// SVG rendering is deliberately out of scope.
fn chart_placeholder(xml : String, anchor~ : String) -> String {
  let kinds = @inspect.chart_kinds(xml)
  let kind_text = if kinds.length() == 0 { "chart" } else { kinds.join("+") }
  let series = StringBuilder()
  for meta in @inspect.chart_series(xml) {
    series.write_string("<br>series:")
    match meta.categories {
      Some(categories) =>
        series.write_string(" \{escape_html(categories)} \u{2192}")
      None => ()
    }
    match meta.values {
      Some(values) => series.write_string(" \{escape_html(values)}")
      None => ()
    }
  }
  "<figure class=\"chart-placeholder\" data-anchor=\"\{escape_html_attribute(anchor)}\">[\{escape_html(kind_text)}]\{series.to_string()}</figure>\n"
}

///|
fn render_chart_sheet(
  body : StringBuilder,
  chart_sheet : @xlsx.ChartSheet,
  name : String,
) -> Unit {
  body.write_string("<section data-sheet=\"\{escape_html_attribute(name)}\">\n")
  body.write_string("<h2>\{escape_html(name)}</h2>\n")
  body.write_string(chart_placeholder(chart_sheet.chart_xml(), anchor=""))
  body.write_string("</section>\n")
}

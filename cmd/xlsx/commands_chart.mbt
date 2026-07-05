// The `chart` subcommand — add a chart to a worksheet from a categories range
// and a values range, using the library's structured chart API.

///|
/// Maps a friendly `--type` name to a `ChartType`. Covers the common 2-D
/// chart kinds; an unknown name raises a `CliError` listing the choices.
fn parse_chart_type(name : String) -> @xl.ChartType raise CliError {
  match name {
    "col" | "column" => Col
    "bar" => Bar
    "line" => Line
    "pie" => Pie
    "area" => Area
    "scatter" => Scatter
    "doughnut" | "donut" => Doughnut
    "radar" => Radar
    _ =>
      raise CliError(
        "error: unknown chart type '\{name}' (expected one of: col, bar, line, pie, area, scatter, doughnut, radar)",
      )
  }
}

///|
/// Qualifies a cell range with its sheet for a chart series reference. A range
/// the caller already qualified (contains `!`) is left as-is; otherwise the
/// sheet name is prepended using the library's formula sheet-ref quoting —
/// wrapped in single quotes with embedded apostrophes doubled — so names with
/// spaces or punctuation (e.g. `O'Brien`, `R&D`) stay valid.
fn qualify_range(sheet : String, range : String) -> String {
  if range.contains("!") {
    range
  } else {
    "'" + sheet.replace_all(old="'", new="''") + "'!" + range
  }
}

///|
async fn run_chart(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let sheet = arg(m, "sheet")
  let anchor = arg(m, "anchor")
  let type_name = {
    let value = arg(m, "type")
    if value == "" {
      "col"
    } else {
      value
    }
  }
  let chart_type = parse_chart_type(type_name)
  // A chart needs both a categories range and a values range; without them
  // `qualify_range` would produce a sheet-only ref (`'Data'!`) and the library
  // would silently write a degenerate series, so require them explicitly.
  let raw_categories = arg(m, "categories")
  let raw_values = arg(m, "values")
  if raw_categories == "" || raw_values == "" {
    raise CliError(
      "error: chart requires --categories and --values (e.g. --categories A2:A6 --values B2:B6)",
    )
  }
  let categories = qualify_range(sheet, raw_categories)
  let values = qualify_range(sheet, raw_values)
  let workbook = @lib.open_file(file)
  let options = @xl.ChartOptions::new(chart_type)
  let series_name = arg(m, "name")
  options.series.push(
    if series_name == "" {
      @xl.ChartSeries::new(categories, values)
    } else {
      @xl.ChartSeries::new(categories, values, name=series_name)
    },
  )
  let title = arg(m, "title")
  if title != "" {
    options.title = title
  }
  workbook.add_chart_with_options(sheet, anchor, options)
  write_file(file, @lib.write(workbook))
  println("added \{type_name} chart to \{sheet}!\{anchor}")
}

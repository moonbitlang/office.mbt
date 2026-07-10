// The `chart` subcommand — add a chart to a worksheet from a categories range
// and a values range, using the library's structured chart API.

///|
/// Maps a friendly `--type` name to a `ChartType` via the shared batch
/// helper, re-raising its error in the CLI's format.
fn parse_chart_type(name : String) -> @xl.ChartType raise CliError {
  @batch.chart_type_of(name) catch {
    @batch.BatchError(message) => raise CliError("error: " + message)
  }
}

///|
/// Qualifies a cell range with its sheet for a chart series reference
/// (shared with the batch `chart` op).
fn qualify_range(sheet : String, range : String) -> String {
  @batch.qualify_range(sheet, range)
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

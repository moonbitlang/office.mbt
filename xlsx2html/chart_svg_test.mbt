///|
fn chart_svg_probe_workbook() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell("Data", "B1", "Sales")
  workbook.set_cell("Data", "A2", "East")
  workbook.set_cell("Data", "A3", "West")
  workbook.set_cell("Data", "A4", "North")
  sheet.set_cell_value("B2", Numeric(30.0))
  sheet.set_cell_value("B3", Numeric(70.0))
  sheet.set_cell_value("B4", Numeric(50.0))
  workbook
}

///|
fn chart_svg_probe_options(typ : @xlsx.ChartType) -> @xlsx.ChartOptions raise {
  let opts = @xlsx.ChartOptions::new(typ)
  opts.series.push(
    @xlsx.ChartSeries::new("Data!$A$2:$A$4", "Data!$B$2:$B$4", name="Data!$B$1"),
  )
  opts
}

///|
/// A supported bar chart renders as deterministic inline SVG with real
/// marks, axis labels, resolved series name, and accessible fallback text.
test "bar chart renders as inline SVG" {
  let workbook = chart_svg_probe_workbook()
  workbook.add_chart_with_options("Data", "D2", chart_svg_probe_options(Col))
  let html = render_workbook(workbook, title="chart probe")
  assert_true(html.contains("<figure class=\"chart\""))
  assert_true(html.contains("role=\"img\""))
  assert_true(
    html.contains("<desc>barChart with 1 series; Sales (3 points)</desc>"),
  )
  assert_true(html.contains("<rect fill=\"#4472c4\""))
  // axis ticks carry the deterministic value bounds and category labels
  assert_true(html.contains(">70.00</text>"))
  assert_true(html.contains(">East</text>"))
  assert_true(html.contains(">Sales</text>"))
  assert_false(html.contains("<figure class=\"chart-placeholder\""))
}

///|
/// Line and pie charts also render real marks.
test "line and pie charts render marks" {
  let line_workbook = chart_svg_probe_workbook()
  line_workbook.add_chart_with_options(
    "Data",
    "D2",
    chart_svg_probe_options(Line),
  )
  let line_html = render_workbook(line_workbook, title="line probe")
  assert_true(line_html.contains("<polyline fill=\"none\" stroke=\"#4472c4\""))
  let pie_workbook = chart_svg_probe_workbook()
  pie_workbook.add_chart_with_options(
    "Data",
    "D2",
    chart_svg_probe_options(Pie),
  )
  let pie_html = render_workbook(pie_workbook, title="pie probe")
  assert_true(pie_html.contains("<path fill=\"#4472c4\""))
  assert_true(pie_html.contains("<path fill=\"#ed7d31\""))
}

///|
/// Unsupported chart kinds keep the labeled placeholder instead of a
/// misleading SVG.
test "unsupported chart kinds keep the labeled placeholder" {
  let workbook = chart_svg_probe_workbook()
  workbook.add_chart_with_options("Data", "D2", chart_svg_probe_options(Radar))
  let html = render_workbook(workbook, title="radar probe")
  assert_true(html.contains("chart-placeholder"))
  assert_true(html.contains("[radarChart]"))
  assert_false(html.contains("<figure class=\"chart\""))
}

///|
/// Chart text is escaped: a series name cell carrying markup cannot inject
/// script into the SVG or caption.
test "chart series names cannot inject markup" {
  let workbook = chart_svg_probe_workbook()
  workbook.set_cell("Data", "B1", "<script>alert(1)</script>")
  workbook.add_chart_with_options("Data", "D2", chart_svg_probe_options(Col))
  let html = render_workbook(workbook, title="inject probe")
  assert_false(html.contains("<script>"))
  assert_true(html.contains("&lt;script&gt;"))
}

///|
/// Non-numeric cells inside a value range are skipped and reported in the
/// accessible description.
test "non-numeric chart values are skipped and reported" {
  let workbook = chart_svg_probe_workbook()
  workbook.set_cell("Data", "B3", "not a number")
  workbook.add_chart_with_options("Data", "D2", chart_svg_probe_options(Col))
  let html = render_workbook(workbook, title="gap probe")
  assert_true(html.contains("1 non-numeric values skipped"))
}

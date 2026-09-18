// Regression tests for the round-3 review findings: subtype honesty,
// single-point visibility, pie legend dimensions, numeric overflow, legend
// growth, and bounded descriptions.

///|
fn edge_probe_workbook(rows : Int) -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  for row in 1..<=rows {
    workbook.set_cell("Data", "A\{row}", "cat \{row}")
    workbook.set_cell_int("Data", "B\{row}", row * 10)
  }
  workbook
}

///|
fn edge_chart(
  workbook : @xlsx.Workbook,
  typ : @xlsx.ChartType,
  rows : Int,
  series? : Int = 1,
) -> Unit raise {
  let chart = @xlsx.ChartOptions::new(typ)
  for index in 0..<series {
    chart.series.push(
      @xlsx.ChartSeries::new(
        "Data!$A$1:$A$\{rows}",
        "Data!$B$1:$B$\{rows}",
        name="series name \{index + 1}",
      ),
    )
  }
  workbook.add_chart_with_options("Data", "D2", chart)
}

///|
test "stacked and horizontal bar subtypes keep the placeholder" {
  let stacked = edge_probe_workbook(3)
  edge_chart(stacked, ColStacked, 3)
  let stacked_html = @xlsx2html.render_workbook(stacked, title="s.xlsx")
  assert_true(stacked_html.contains("<figure class=\"chart-placeholder\""))
  assert_false(stacked_html.contains("<figure class=\"chart\" "))
  let horizontal = edge_probe_workbook(3)
  edge_chart(horizontal, Bar, 3)
  let horizontal_html = @xlsx2html.render_workbook(horizontal, title="h.xlsx")
  assert_true(horizontal_html.contains("<figure class=\"chart-placeholder\""))
  // plain clustered columns still render
  let plain = edge_probe_workbook(3)
  edge_chart(plain, Col, 3)
  assert_true(
    @xlsx2html.render_workbook(plain, title="p.xlsx").contains(
      "<figure class=\"chart\" ",
    ),
  )
}

///|
test "single-point line and pie charts draw visible marks" {
  let line = edge_probe_workbook(1)
  edge_chart(line, Line, 1)
  let line_html = @xlsx2html.render_workbook(line, title="l.xlsx")
  assert_true(line_html.contains("<circle fill=\"#4472c4\""))
  assert_false(line_html.contains("<polyline"))
  let pie = edge_probe_workbook(1)
  edge_chart(pie, Pie, 1)
  let pie_html = @xlsx2html.render_workbook(pie, title="pie.xlsx")
  // the whole disc, not a degenerate zero-area arc
  assert_true(pie_html.contains("<circle fill=\"#4472c4\""))
  assert_false(pie_html.contains("<path fill="))
}

///|
test "pie legends name slices with slice colors" {
  let workbook = edge_probe_workbook(3)
  edge_chart(workbook, Pie, 3)
  let html = @xlsx2html.render_workbook(workbook, title="pie3.xlsx")
  // three slices, three legend entries in slice colors, labeled by category
  assert_true(html.contains(">cat 1</text>"))
  assert_true(html.contains(">cat 2</text>"))
  assert_true(html.contains(">cat 3</text>"))
  assert_true(html.contains("<rect fill=\"#ed7d31\""))
  assert_true(html.contains("<rect fill=\"#a5a5a5\""))
  assert_false(html.contains(">series name 1</text>"))
}

///|
test "huge magnitudes keep axis labels and geometry finite" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "big")
  workbook.set_cell("Data", "A2", "small")
  workbook.set_cell_float("Data", "B1", 1.0e20)
  workbook.set_cell_float("Data", "B2", -1.0e20)
  let chart = @xlsx.ChartOptions::new(Col)
  chart.series.push(@xlsx.ChartSeries::new("Data!$A$1:$A$2", "Data!$B$1:$B$2"))
  workbook.add_chart_with_options("Data", "D2", chart)
  let html = @xlsx2html.render_workbook(workbook, title="big.xlsx")
  assert_true(html.contains("<figure class=\"chart\" "))
  assert_true(html.contains(">100000000000000000000</text>"))
  assert_false(html.contains("-92233720368547758"))
  // extreme spans stay finite through the halved-arithmetic scaler
  let extreme = @xlsx.Workbook::new()
  ignore(extreme.add_sheet("Data"))
  extreme.set_cell_float("Data", "B1", 1.0e308)
  extreme.set_cell_float("Data", "B2", -1.0e308)
  let chart2 = @xlsx.ChartOptions::new(Col)
  chart2.series.push(@xlsx.ChartSeries::new("Data!$A$1:$A$2", "Data!$B$1:$B$2"))
  extreme.add_chart_with_options("Data", "D2", chart2)
  let extreme_html = @xlsx2html.render_workbook(extreme, title="x.xlsx")
  assert_false(extreme_html.contains("NaN"))
  assert_false(extreme_html.contains("inf"))
}

///|
test "legends beyond one row grow the canvas instead of clipping" {
  let workbook = edge_probe_workbook(3)
  edge_chart(workbook, Col, 3, series=8)
  let html = @xlsx2html.render_workbook(workbook, title="eight.xlsx")
  // 8 series -> 4 legend rows -> last baseline y=306 needs height 318
  assert_true(html.contains("viewBox=\"0 0 480 318\""))
  assert_true(html.contains("height=\"318\""))
  assert_true(html.contains(">series name 8</text>"))
  // one series keeps the canonical 280 canvas
  let single = edge_probe_workbook(3)
  edge_chart(single, Col, 3)
  assert_true(
    @xlsx2html.render_workbook(single, title="one.xlsx").contains(
      "viewBox=\"0 0 480 280\"",
    ),
  )
}

///|
test "descriptions bound series names like every other label" {
  let workbook = edge_probe_workbook(2)
  let chart = @xlsx.ChartOptions::new(Col)
  chart.series.push(
    @xlsx.ChartSeries::new(
      "Data!$A$1:$A$2",
      "Data!$B$1:$B$2",
      name="an extremely long series name that keeps going well past the ceiling",
    ),
  )
  workbook.add_chart_with_options("Data", "D2", chart)
  let html = @xlsx2html.render_workbook(workbook, title="long.xlsx")
  assert_true(html.contains("an extremely long serie\u{2026}"))
  assert_false(html.contains("an extremely long series name that keeps going"))
}

///|
test "a stacked combo plot disqualifies the whole chart space" {
  // chart_kinds deduplicates: Col + ColStacked is still one barChart kind,
  // so the gate must inspect every plot's grouping, not just the first
  let workbook = edge_probe_workbook(3)
  let chart = @xlsx.ChartOptions::new(Col)
  chart.series.push(
    @xlsx.ChartSeries::new("Data!$A$1:$A$3", "Data!$B$1:$B$3", name="base"),
  )
  let stacked = @xlsx.ChartOptions::new(ColStacked)
  stacked.series.push(
    @xlsx.ChartSeries::new("Data!$A$1:$A$3", "Data!$B$1:$B$3", name="extra"),
  )
  chart.add_combo_chart(stacked)
  workbook.add_chart_with_options("Data", "D2", chart)
  let html = @xlsx2html.render_workbook(workbook, title="combo.xlsx")
  assert_true(html.contains("<figure class=\"chart-placeholder\""))
  assert_false(html.contains("<figure class=\"chart\" "))
}

///|
test "huge finite pie slices keep visible sweeps" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "half a")
  workbook.set_cell("Data", "A2", "half b")
  workbook.set_cell_float("Data", "B1", 1.0e308)
  workbook.set_cell_float("Data", "B2", 1.0e308)
  let chart = @xlsx.ChartOptions::new(Pie)
  chart.series.push(@xlsx.ChartSeries::new("Data!$A$1:$A$2", "Data!$B$1:$B$2"))
  workbook.add_chart_with_options("Data", "D2", chart)
  let html = @xlsx2html.render_workbook(workbook, title="halves.xlsx")
  // two equal slices: two wedge paths whose endpoints differ, both colors
  assert_true(html.contains("<path fill=\"#4472c4\""))
  assert_true(html.contains("<path fill=\"#ed7d31\""))
  // equal halves split at the vertical diameter: the shared endpoint of
  // both wedges is the bottom of the circle, not a zero-sweep collapse
  assert_true(html.contains("A 100.00 100.00 0 0 1 240.00 224.00"))
}

///|
test "non-finite values neither stretch bounds nor reach the page" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "ok")
  workbook.set_cell("Data", "A2", "runaway")
  workbook.set_cell_float("Data", "B1", 10.0)
  workbook.set_cell_float("Data", "B2", 1.0 / 0.0)
  let chart = @xlsx.ChartOptions::new(Col)
  chart.series.push(@xlsx.ChartSeries::new("Data!$A$1:$A$2", "Data!$B$1:$B$2"))
  workbook.add_chart_with_options("Data", "D2", chart)
  let html = @xlsx2html.render_workbook(workbook, title="inf.xlsx")
  assert_true(html.contains("<figure class=\"chart\" "))
  // the finite value sets the axis; the skipped value is reported
  assert_true(html.contains(">10.00</text>"))
  assert_false(html.contains("Infinity"))
  assert_false(html.contains("NaN"))
  assert_true(html.contains("1 non-numeric values skipped"))
}

///|
test "subnormal separations keep their midpoint geometry" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "mid")
  workbook.set_cell("Data", "A2", "top")
  workbook.set_cell_float("Data", "B1", 5.0e-324)
  workbook.set_cell_float("Data", "B2", 1.0e-323)
  let chart = @xlsx.ChartOptions::new(Line)
  chart.series.push(@xlsx.ChartSeries::new("Data!$A$1:$A$2", "Data!$B$1:$B$2"))
  workbook.add_chart_with_options("Data", "D2", chart)
  let html = @xlsx2html.render_workbook(workbook, title="tiny.xlsx")
  // 5e-324 is exactly half of 1e-323: the midpoint must sit mid-plot
  // (y=124), not collapse to the 224 baseline via underflowing halves
  assert_true(html.contains(",124.00 "))
}

///|
test "mixed-magnitude pies keep the dominant slice visible" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "trace")
  workbook.set_cell("Data", "A2", "bulk")
  workbook.set_cell_float("Data", "B1", 1.0e-300)
  workbook.set_cell_float("Data", "B2", 1.0e300)
  let chart = @xlsx.ChartOptions::new(Pie)
  chart.series.push(@xlsx.ChartSeries::new("Data!$A$1:$A$2", "Data!$B$1:$B$2"))
  workbook.add_chart_with_options("Data", "D2", chart)
  let html = @xlsx2html.render_workbook(workbook, title="mixed.xlsx")
  // the dominant slice sweeps (almost) the whole circle: a visible disc
  // in the second slice color, never a zero-area coincident-endpoint arc
  assert_true(html.contains("<circle fill=\"#ed7d31\""))
  // both slices stay in the legend
  assert_true(html.contains(">trace</text>"))
  assert_true(html.contains(">bulk</text>"))
}

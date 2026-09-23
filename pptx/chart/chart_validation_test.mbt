// Modified for office.mbt: follow the workspace warning conventions.
// Tests for chart-data validation.

// --- ChartData ---

///|
test "ChartData::validate: consistent data passes and returns self" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [100.0, 200.0])
    .with_series("Cost", [60.0, 110.0])
  let validated = data.validate()
  debug_inspect(validated == data, content="true")
  debug_inspect(data.is_consistent(), content="true")
}

///|
test "ChartData::validate: too few values raises Malformed" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_series("Revenue", [100.0, 200.0])
  debug_inspect(data.is_consistent(), content="false")
  try data.validate() |> ignore catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}

///|
test "ChartData::validate: too many values raises Malformed" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_series("Revenue", [100.0, 200.0, 300.0])
  debug_inspect(data.is_consistent(), content="false")
  try data.validate() |> ignore catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}

///|
test "ChartData::validate: composes into a chart builder" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [100.0, 200.0])
  // The validated value feeds straight into of_bar.
  let chart = @chart.Chart::of_bar(data.validate())
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => debug_inspect(b.series.length(), content="1")
    _ => fail("expected BarChart")
  }
}

///|
test "ChartData::validate: empty data (no categories, no series) is consistent" {
  let data = @chart.ChartData::new()
  debug_inspect(data.is_consistent(), content="true")
  let _ = data.validate()
}

// --- ScatterData ---

///|
test "ScatterData::validate: matching X/Y passes, mismatch raises" {
  let ok = @chart.ScatterData::new().with_series("s", [1.0, 2.0, 3.0], [
    10.0, 20.0, 30.0,
  ])
  debug_inspect(ok.is_consistent(), content="true")
  debug_inspect(ok.validate() == ok, content="true")
  let bad = @chart.ScatterData::new().with_series("s", [1.0, 2.0, 3.0], [
    10.0, 20.0,
  ])
  debug_inspect(bad.is_consistent(), content="false")
  try bad.validate() |> ignore catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}

// --- Chart (plot-type-aware data-label position) ---

///|
fn d8_data() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Revenue", [100.0, 200.0])
}

///|
test "Chart::validate: outEnd on a bar (clustered) chart is allowed" {
  let chart = @chart.Chart::of_bar(d8_data()).with_options([
    DataLabels(DLblOutEnd),
  ])
  debug_inspect(chart.is_consistent(), content="true")
  debug_inspect(chart.validate() == chart, content="true")
}

///|
test "Chart::validate: outEnd on a line chart raises Malformed naming the plot" {
  let chart = @chart.Chart::of_line(d8_data()).with_options([
    DataLabels(DLblOutEnd),
  ])
  debug_inspect(chart.is_consistent(), content="false")
  try chart.validate() |> ignore catch {
    Malformed(msg) => {
      // names the plot family and the offending position.
      debug_inspect(msg.contains("lineChart"), content="true")
      debug_inspect(msg.contains("outEnd"), content="true")
    }
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}

///|
test "Chart::validate: ctr on a line chart is allowed" {
  let chart = @chart.Chart::of_line(d8_data()).with_options([
    DataLabels(DLblCenter),
  ])
  debug_inspect(chart.is_consistent(), content="true")
}

///|
test "Chart::validate: outEnd on a pie chart is allowed, inBase is not" {
  let ok = @chart.Chart::of_pie(d8_data()).with_options([DataLabels(DLblOutEnd)])
  debug_inspect(ok.is_consistent(), content="true")
  let bad = @chart.Chart::of_pie(d8_data()).with_options([
    DataLabels(DLblInBase),
  ])
  debug_inspect(bad.is_consistent(), content="false")
}

///|
test "Chart::validate: stacked bar forbids outEnd (clustered allows it)" {
  let stacked = @chart.Chart::of_bar(d8_data(), grouping=Stacked).with_options([
    DataLabels(DLblOutEnd),
  ])
  debug_inspect(stacked.is_consistent(), content="false")
  let clustered = @chart.Chart::of_bar(d8_data(), grouping=Clustered).with_options([
      DataLabels(DLblOutEnd),
    ],
  )
  debug_inspect(clustered.is_consistent(), content="true")
}

///|
test "Chart::validate: area chart permits no explicit position" {
  let chart = @chart.Chart::of_area(d8_data()).with_options([
    DataLabels(DLblCenter),
  ])
  debug_inspect(chart.is_consistent(), content="false")
}

///|
test "Chart::validate: a chart with no data labels is consistent" {
  let chart = @chart.Chart::of_line(d8_data())
  debug_inspect(chart.is_consistent(), content="true")
  debug_inspect(chart.validate() == chart, content="true")
}

// --- BubbleData ---

///|
test "BubbleData::validate: matching X/Y/size passes, mismatch raises" {
  let ok = @chart.BubbleData::new().with_series("s", [1.0, 2.0], [10.0, 20.0], [
    3.0, 4.0,
  ])
  debug_inspect(ok.is_consistent(), content="true")
  debug_inspect(ok.validate() == ok, content="true")
  let bad = @chart.BubbleData::new().with_series(
    "s",
    [1.0, 2.0],
    [10.0, 20.0],
    [3.0],
  )
  debug_inspect(bad.is_consistent(), content="false")
  try bad.validate() |> ignore catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}

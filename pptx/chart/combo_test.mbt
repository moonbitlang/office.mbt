// Tests for combo charts.

///|
fn revenue() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Revenue", [100.0, 200.0])
  .with_series("Cost", [60.0, 110.0])
}

///|
fn margin_pct() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Margin %", [40.0, 45.0])
}

// --- shared-axis combo (default) ---

///|
test "of_combo: two plots on a shared cat/val axis pair" {
  let chart = @chart.Chart::of_combo(Bar(revenue()), Line(margin_pct()))
  let pa = chart.chart.plot_area
  debug_inspect(pa.plots.length(), content="2")
  debug_inspect(pa.plots[0].local_name(), content="\"barChart\"")
  debug_inspect(pa.plots[1].local_name(), content="\"lineChart\"")
  // Only the single 2-D axis pair.
  debug_inspect(pa.axes.length(), content="2")
  debug_inspect(pa.axes[0].local_name(), content="\"catAx\"")
  debug_inspect(pa.axes[1].local_name(), content="\"valAx\"")
  // Both plots reference the same axis ids.
  match pa.plots[0] {
    BarChart(b) => debug_inspect(b.ax_ids, content="[1, 2]")
    _ => fail("expected barChart")
  }
  match pa.plots[1] {
    LineChart(l) => debug_inspect(l.ax_ids, content="[1, 2]")
    _ => fail("expected lineChart")
  }
}

///|
test "of_combo: secondary series indices are offset past the primary's" {
  let chart = @chart.Chart::of_combo(Bar(revenue()), Line(margin_pct()))
  let pa = chart.chart.plot_area
  // Primary bar has 2 series → idx 0, 1.
  match pa.plots[0] {
    BarChart(b) => {
      debug_inspect(b.series.length(), content="2")
      debug_inspect(b.series[0].idx, content="0")
      debug_inspect(b.series[1].idx, content="1")
    }
    _ => fail("expected barChart")
  }
  // Secondary line has 1 series → idx continues at 2 (not a duplicate 0).
  match pa.plots[1] {
    LineChart(l) => {
      debug_inspect(l.series.length(), content="1")
      debug_inspect(l.series[0].idx, content="2")
      debug_inspect(l.series[0].order, content="2")
    }
    _ => fail("expected lineChart")
  }
}

// --- secondary-axis combo ---

///|
test "of_combo: secondary_axis adds a right value axis + hidden cat axis" {
  let chart = @chart.Chart::of_combo(
    Bar(revenue()),
    Line(margin_pct()),
    secondary_axis=true,
  )
  let pa = chart.chart.plot_area
  // Four axes: primary cat/val (1,2) + secondary val/cat (4,3).
  debug_inspect(pa.axes.length(), content="4")
  debug_inspect(pa.axes[0].local_name(), content="\"catAx\"")
  debug_inspect(pa.axes[1].local_name(), content="\"valAx\"")
  debug_inspect(pa.axes[2].local_name(), content="\"valAx\"")
  debug_inspect(pa.axes[3].local_name(), content="\"catAx\"")
  // Secondary value axis: id 4, drawn on the right, crossing at max.
  let sec_val = pa.axes[2].core()
  debug_inspect(sec_val.ax_id, content="4")
  debug_inspect(sec_val.ax_pos is Some(Right), content="true")
  debug_inspect(sec_val.crosses is Some(Max), content="true")
  debug_inspect(sec_val.cross_ax is Some(3), content="true")
  // Secondary category axis: id 3, deleted (not rendered).
  let sec_cat = pa.axes[3].core()
  debug_inspect(sec_cat.ax_id, content="3")
  debug_inspect(sec_cat.delete is Some(true), content="true")
  // The secondary plot binds to the secondary axis pair.
  match pa.plots[1] {
    LineChart(l) => debug_inspect(l.ax_ids, content="[3, 4]")
    _ => fail("expected lineChart")
  }
}

// --- round-trip ---

///|
test "of_combo: round-trips through serialize → parse (shared axis)" {
  let original = @chart.Chart::of_combo(Bar(revenue()), Area(margin_pct()))
  let reparsed = @chart.Chart::parse(original.serialize())
  debug_inspect(reparsed == original, content="true")
}

///|
test "of_combo: round-trips through serialize → parse (secondary axis)" {
  let original = @chart.Chart::of_combo(
    Bar(revenue()),
    Line(margin_pct()),
    secondary_axis=true,
  )
  let reparsed = @chart.Chart::parse(original.serialize())
  debug_inspect(reparsed == original, content="true")
}
